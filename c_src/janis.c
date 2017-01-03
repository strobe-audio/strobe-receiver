#include "janis.h"


// Not worth making this work on os x..
#ifndef __APPLE__
// Have we set cpu affinity & scheduling for our audio thread yet?
static bool has_cpu_affinity = false;
#endif // __APPLE__

// configure these here because doing it in the header file breaks my make as I
// don't have dependency checks.
#define PID_P (2.0)
#define PID_I (0.05)
#define PID_D (0.05)
#define PID_DI_CUTOFF (100.0)

void playback_stopped(audio_callback_context *context) {
	printf("Playback stopped...\r\n");
	context->playing     = false;
	context->frame_count = (uint64_t)0;
	src_reset(context->resampler);
	pid_reset(&context->pid);
	stream_stats_reset(context->timestamp_offset_stats);
}

bool load_next_packet(audio_callback_context *context)
{
	if (PaUtil_GetRingBufferReadAvailable(&context->audio_buffer) > 0) {
		PaUtil_ReadRingBuffer(&context->audio_buffer, context->active_packet, 1);

		return true;
	}
	return false;
}

long copy_packet_with_offset(
		audio_callback_context *context,
		float *out,
		unsigned long total_len,
		unsigned long outOffset)
{
	timestamped_packet *packet = context->active_packet;

	unsigned long len = total_len - outOffset;
	uint16_t offset = 0;

	if ((packet->offset + len) <= packet->len) {
		offset = packet->offset + len;
	} else {
		len = packet->len - packet->offset;
		offset = packet->len;
	}

	if (context->volume == (float)0.0) {
		memset((out + outOffset), 0, len * context->sample_size);
	} else {
		for (unsigned long i = 0; i < len; i++ ) {
			*(out + outOffset + i) = context->volume * *(packet->data + packet->offset + i);
		}
	}

	packet->offset = offset;

	if (packet->offset == packet->len) {
		load_next_packet(context);
	}

	return len;
}

static long src_input_callback(void *cb_data, float **data) {
		audio_callback_context *context = (audio_callback_context*)cb_data;
		long sent = 0;
		while ((sent < OUTPUT_BUFFER_SIZE) && CONTEXT_HAS_DATA(context)) {
			sent += copy_packet_with_offset(context, context->buffer, OUTPUT_BUFFER_SIZE, sent);
		}
		*data = context->buffer;

		return sent / CHANNEL_COUNT;
}

static inline uint64_t stream_time_to_absolute_time(
		audio_callback_context *context,
		uint64_t current_time,
		const PaStreamCallbackTimeInfo*   timeInfo
		) {
	PaTime t = timeInfo->outputBufferDacTime - context->latency - timeInfo->currentTime;
	return current_time + (uint64_t)llround(t * USECONDS);
}


static inline uint64_t packet_output_absolute_time(timestamped_packet *packet) {
	return packet->timestamp + (uint64_t)llround(packet->offset * USECONDS_PER_FLOAT);
}

// returns +ve if the packet is ahead of where it's supposed to be i.e. the audio is playing too fast
//           0 if the packet is playing exactly at the right time
// and     -ve if the packet is behind where it's supposed to be i.e. the audio is playing too slowly
static inline int64_t packet_output_offset_absolute_time(
		uint64_t current_time,
		timestamped_packet *packet
		) {
	return (int64_t)(packet_output_absolute_time(packet) - current_time);
}


static inline void send_packet(audio_callback_context *context,
		float *out,
		unsigned long frameCount,
		const PaStreamCallbackTimeInfo*   timeInfo
		)
{

	uint64_t now = monotonic_microseconds();
	uint64_t output_time;
	uint64_t packet_time;

	output_time = stream_time_to_absolute_time(context, now, timeInfo);
	packet_time = packet_output_absolute_time(context->active_packet);

	if (context->playing == false) {
		// we want to wait for the right time to start playing the packet
		if (packet_time > output_time) {
			// not our time... wait
			printf("waiting %"PRIi64"\r\n", packet_time - output_time);
			memset(out, 0, frameCount * CHANNEL_COUNT * context->sample_size);
			return;
		}
		context->playing = true;
	}

	double resample_ratio = 1.0;

	/* int64_t packet_offset = packet_output_offset_absolute_time(now, context->active_packet); */
	int64_t packet_offset = packet_time - output_time;

	// only used for debugging, not for adjusting the stream playback
	double smoothed_timestamp_offset = stream_stats_update(context->timestamp_offset_stats, packet_offset);

	double control = 0.0;
	double time    = ((double)now)/USECONDS;

	control = pid_control(&context->pid, time, packet_offset, 0.0);
	control = MAX(control, -MAX_RESAMPLE_RATIO);
	control = MIN(control, MAX_RESAMPLE_RATIO);
	resample_ratio = 1.0 - control;

	// tell src not to smoothly transition to the new resample ratio
	src_set_ratio(context->resampler, resample_ratio);

	unsigned long frames = (unsigned long)src_callback_read(context->resampler, resample_ratio, frameCount, out);

	if (frames < frameCount) {
		memset(out+(frames*CHANNEL_COUNT), 0, (frameCount - frames) * CHANNEL_COUNT * context->sample_size);
	}

	if (!CONTEXT_HAS_DATA(context)) {
		playback_stopped(context);
	}

	context->frame_count += frames;

	if (frames == 0) {
		int error = src_error(context->resampler);
		if (error != 0) {
			printf("SRC ERROR: %d '%s'\r\n", error, src_strerror(error));
		}
	}

	// debug at most every ~1s & only then once an individual packet's offset >
	// this threshold.
	const int64_t debug_threshold_us = 50; // µs

	bool show_debug = false;
	const char* ok  = "   ";
	const char* bad = "!! ";
	char* pre;

	if (context->frame_count > (SAMPLE_RATE * 10)) {
		show_debug = true;
		pre = ok;
	}
	if (context->frame_count > SAMPLE_RATE && llabs(packet_offset) > debug_threshold_us) {
		show_debug = true;
		pre = bad;
	}
	if (show_debug) {
		context->frame_count = 0;
		double load = Pa_GetStreamCpuLoad(context->audio_stream) * 100;
		printf ("%s % 9.2f,% 6"PRIi64",% 8.6f,% 7.2f%% - {%.5f, %.5f, %.5f}\r\n", pre, smoothed_timestamp_offset, packet_offset, resample_ratio, load, context->pid.kp, context->pid.ki, context->pid.kd);
	}

}

static int audio_callback(const void* _input,
		void*                             output,
		unsigned long                     frameCount,
		const PaStreamCallbackTimeInfo*   timeInfo,
		PaStreamCallbackFlags             _statusFlags,
		void*                             userData)
{
	audio_callback_context* context = (audio_callback_context*)userData;
	float *out = (float*)output;
	timestamped_packet* packet = NULL;

	UNUSED(_input);
	UNUSED(_statusFlags);

#ifndef __APPLE__
	if (!has_cpu_affinity) {
		has_cpu_affinity = true;

		cpu_set_t cpus;
		struct sched_param sched_param;
		sched_param.sched_priority = sched_get_priority_max(SCHED_FIFO);

		int processor_count = sysconf(_SC_NPROCESSORS_ONLN);

		printf("=== Setting cpu affinity: CPU %d/%d SCHED_FIFO %d\r\n", processor_count, processor_count, sched_param.sched_priority);

		pthread_t current_thread = pthread_self();

		CPU_ZERO(&cpus);
		CPU_SET(processor_count - 1, &cpus);

		pthread_setaffinity_np(current_thread, sizeof(cpu_set_t), &cpus);
		pthread_setschedparam(current_thread, SCHED_FIFO, &sched_param);
	}
#endif // __APPLE__

	if (context->stopped) {
		// remove all things from the ring buffer
		timestamped_packet _packet;
		while (PaUtil_GetRingBufferReadAvailable(&context->audio_buffer) > 0) {
			printf("Popping %ld\n\r", (long)PaUtil_GetRingBufferReadAvailable(&context->audio_buffer));
			PaUtil_ReadRingBuffer(&context->audio_buffer, &_packet, 1);
		}
		playback_stopped(context);
		context->stopped = false;
	} else {
		if (CONTEXT_HAS_DATA(context)) {
			packet = context->active_packet;
		} else {
			if (load_next_packet(context)) {
				packet = context->active_packet;
			}
		}
	}
	if (packet == NULL) {
		memset(out, 0, frameCount * CHANNEL_COUNT * context->sample_size);
	} else {
		send_packet(context, out, frameCount, timeInfo);
	}
	return paContinue;
}

PaError initialize_audio_stream(audio_callback_context* context)
{
	PaStream*           stream;
	PaError             err;
	PaStreamParameters  outputParameters;
	bool has_initialized = false;

	printf("== Pa_Initialize...\r\n");

	err = Pa_Initialize();
	if (err != paNoError) { goto error; }

	printf("== Pa_Initialize complete\r\n");

	has_initialized = true;

	int numDevices, i;
	numDevices = Pa_GetDeviceCount();

	const   PaDeviceInfo *deviceInfo;
	for( i=0; i<numDevices; i++ ) {
		deviceInfo = Pa_GetDeviceInfo( i );
		printf("-- Available device %s\r\n", deviceInfo->name);
	}

	outputParameters.device = Pa_GetDefaultOutputDevice(); //Take the default output device.

	if (outputParameters.device == paNoDevice) {
		fprintf(stderr,"\rError: No default output device.\r\n");
		goto error;
	}

	deviceInfo = Pa_GetDeviceInfo(outputParameters.device);

	printf("== Using Device %s\r\n", deviceInfo->name);

	outputParameters.channelCount = CHANNEL_COUNT;                     /* Stereo output, most likely supported. */
	outputParameters.hostApiSpecificStreamInfo = NULL;
	outputParameters.sampleFormat = paFloat32;             /* 32 bit floating point output. */
	// I don't particularly need a low latency, I need a consistent latency
	// the two given options are 'defaultLowOutputLatency' and 'defaultHighOutputLatency'
	PaTime latency = Pa_GetDeviceInfo(outputParameters.device)->defaultLowOutputLatency;
	printf("Using latency %f\r\n", latency);
	outputParameters.suggestedLatency = latency;

	err = Pa_OpenStream(&stream,
			NULL,                              // No input.
			&outputParameters,
			SAMPLE_RATE,                       // Sample rate.
			paFramesPerBufferUnspecified,      // Frames per buffer.
			paDitherOff,                       // Clip but don't dither
			audio_callback,
			context);

	if (err != paNoError) { goto error; }

#ifdef __alsa__
	printf("== Enabling realtime scheduling...\r\n");
	PaAlsa_EnableRealtimeScheduling(&stream, 1);
#endif

	context->latency = latency;

	context->audio_stream = stream;

	err = Pa_GetSampleSize(outputParameters.sampleFormat);

	if (err == paSampleFormatNotSupported) { goto error; }

	context->sample_size = (int)err;

	err = Pa_StartStream( stream );

	if (err != paNoError) { goto error; }

	/* PaTime stream_time = Pa_GetStreamTime(stream); */
	/*  */
	/* if (stream_time == 0) { goto error; } */

	context->stream_start_time = monotonic_microseconds();

	printf("stream start at %" PRIu64 "\r\n", context->stream_start_time);

	return paNoError;

error:
	if (has_initialized) {
		Pa_Terminate();
	}
	fprintf( stderr, "\rAn error occured while using the portaudio stream\r\n" );
	fprintf( stderr, "\rError number: %d\r\n", err );
	fprintf( stderr, "\rError message: %s\r\n", Pa_GetErrorText( err ) );

	return err;
}

static ErlDrvData portaudio_drv_start(ErlDrvPort port, char *buff)
{
	PaError             err;

	UNUSED(buff);

	portaudio_state* state          = driver_alloc(sizeof(portaudio_state));
	audio_callback_context* context = driver_alloc(sizeof(audio_callback_context));
	context->active_packet          = driver_alloc(sizeof(timestamped_packet));
	context->audio_buffer_data      = driver_alloc(sizeof(timestamped_packet) * PACKET_BUFFER_SIZE);

	if (context->audio_buffer_data == NULL) {
		printf("\rDRV ERROR: problem allocating buffer\r\n");
		goto error;
	}

	memset(context->audio_buffer_data, 0, sizeof(timestamped_packet) * PACKET_BUFFER_SIZE);

	context->timestamp_offset_stats = driver_alloc(sizeof(stream_statistics_t));

	pid_init(&context->pid, PID_P, PID_I, PID_D, PID_DI_CUTOFF);

	stream_stats_init(context->timestamp_offset_stats, 0.0001);

	context->active_packet->timestamp = 0;
	context->active_packet->len       = 0;
	context->active_packet->offset    = 0;

	// initialize stats on context
	context->frame_count              = (uint64_t)0;
	context->playing                  = false;
	context->stopped                  = false;
	// start with the volume turned down so that if we get audio packets before
	// we get a volume command we don't play anything at the wrong volume --
	// it'll just take a little longer for the music to appear.
	// This initial setting has to mirror the initial state in
	// Otis.Receivers.ControlConnection.initial_settings/0
	context->volume                   = 0.0f;

	PaUtil_InitializeRingBuffer(&context->audio_buffer, sizeof(timestamped_packet), PACKET_BUFFER_SIZE, context->audio_buffer_data);

	err = initialize_audio_stream(context);

	if (err != paNoError) { goto error; }

	printf("\rDRV: driver start\r\n");
	state->port = port;
	state->audio_context = context;

	int src_error = 0;

	// SRC_SINC_FASTEST
	// SRC_SINC_MEDIUM_QUALITY
	// SRC_SINC_BEST_QUALITY
	context->resampler = src_callback_new(src_input_callback, SRC_SINC_MEDIUM_QUALITY, CHANNEL_COUNT, &src_error, context);

	if (context->resampler == NULL && (src_error != 0)) {
		printf("!! Error initializing resampler %d\r\n", src_error);
		goto error;
	}

	return (ErlDrvData)state;

error:

	return (ErlDrvData)state;
}

void stop_audio(audio_callback_context *context) {
	printf("\rDRV: stop audio\r\n");
	PaError err;
	err = Pa_AbortStream(context->audio_stream);
	if (err != paNoError) { goto error; }
	err = Pa_CloseStream(context->audio_stream);
	if (err != paNoError) { goto error; }
	Pa_Terminate();
	return;

error:
	Pa_Terminate();
	fprintf( stderr, "\rAn error occured while stopping the portaudio stream\r\n" );
	fprintf( stderr, "\rError number: %d\r\n", err );
	fprintf( stderr, "\rError message: %s\r\n", Pa_GetErrorText( err ) );
	return;
}

static void portaudio_drv_stop(ErlDrvData drv_data) {
	portaudio_state *state = (portaudio_state*)drv_data;
	audio_callback_context *context = state->audio_context;
	stop_audio(context);
	printf("\rDRV: free\r\n");

	src_delete(context->resampler);

	driver_free((char*)context->timestamp_offset_stats);
	driver_free((char*)context->audio_buffer_data);
	driver_free((char*)context->active_packet);
	driver_free((char*)context);
	driver_free((char*)drv_data);
	printf("\rDRV: stopped\r\n");
}

static void encode_response(char *rbuf, int *index, long buffer_size) {
	assert(rbuf && index);
	ei_encode_tuple_header(rbuf, index, 2);
	ei_encode_atom(rbuf, index, "ok");
	ei_encode_long(rbuf, index, buffer_size);
}

// based on src_short_to_float_array https://github.com/erikd/libsamplerate/blob/master/src/samplerate.c
static inline void short_to_float_array(const short *in, float *out, int len)
{
	while (len) {
		len--;
		out[len] = (float) ((in[len]) / (1.0 * 0x8000)) ;
	}

	return;
}

static ErlDrvSSizeT portaudio_drv_control(
		ErlDrvData   drv_data,
		unsigned int cmd,
		char         *buf,
		ErlDrvSizeT  _len,
		char         **rbuf,
		ErlDrvSizeT  _rlen)
{

	int index = 0;
	ei_encode_version(*rbuf, &index);

	UNUSED(_len);
	UNUSED(_rlen);

	portaudio_state *state = (portaudio_state*)drv_data;
	audio_callback_context *context = state->audio_context;

	if (cmd == PLAY_COMMAND) {
		if (!context->stopped) {
			uint64_t time = le64toh(*(uint64_t *) buf);
			uint16_t len  = le16toh(*(uint16_t *) (buf + 8));
			struct timestamped_packet packet = {
				.offset = 0,
				.timestamp = time,
				.len = len / 2
			};

			// conversion to float needed by libsamplerate
			short_to_float_array((short*)(buf + 10), packet.data, packet.len);

			PaUtil_WriteRingBuffer(&context->audio_buffer, &packet, 1);
		}

		long buffer_size = PaUtil_GetRingBufferReadAvailable(&context->audio_buffer);

		encode_response(*rbuf, &index, buffer_size);
	} else if (cmd == TIME_COMMAND) {
		uint64_t t = monotonic_microseconds();
		ei_encode_tuple_header(*rbuf, &index, 2);
		ei_encode_atom(*rbuf, &index, "ok");
		ei_encode_ulonglong(*rbuf, &index, t);
	} else if (cmd == GVOL_COMMAND) {
		ei_encode_tuple_header(*rbuf, &index, 2);
		ei_encode_atom(*rbuf, &index, "ok");
		ei_encode_double(*rbuf, &index, (double)context->volume);
	} else if (cmd == SVOL_COMMAND) {
		float volume = *((float *)buf);
		context->volume = MAX(MIN(volume, 1.0), 0.0);
		ei_encode_atom(*rbuf, &index, "ok");
	} else if (cmd == STOP_COMMAND) {
		context->stopped = true;
		ei_encode_atom(*rbuf, &index, "ok");
	}
	return (ErlDrvSSizeT)index;
}

ErlDrvEntry example_driver_entry = {
	NULL,			/* F_PTR init, called when driver is loaded */
	portaudio_drv_start,		/* L_PTR start, called when port is opened */
	portaudio_drv_stop,		/* F_PTR stop, called when port is closed */
	NULL,		/* F_PTR output, called when erlang has sent */
	NULL,			/* F_PTR ready_input, called when input descriptor ready */
	NULL,			/* F_PTR ready_output, called when output descriptor ready */
	"janis",		/* char *driver_name, the argument to open_port */
	NULL, //portaudio_drv_finish,			/* F_PTR finish, called when unloaded */
	NULL,                       /* void *handle, Reserved by VM */
	portaudio_drv_control,			/* F_PTR control, port_command callback */
	NULL,			/* F_PTR timeout, reserved */
	NULL,			/* F_PTR outputv, reserved */
	NULL,                       /* F_PTR ready_async, only for async drivers */
	NULL,                       /* F_PTR flush, called when port is about to be closed, but there is data in driver queue */
	NULL,                       /* F_PTR call, much like control, sync call to driver */
	NULL,                       /* F_PTR event, called when an event selected by driver_event() occurs. */
	ERL_DRV_EXTENDED_MARKER,    /* int extended marker, Should always be set to indicate driver versioning */
	ERL_DRV_EXTENDED_MAJOR_VERSION, /* int major_version, should always be set to this value */
	ERL_DRV_EXTENDED_MINOR_VERSION, /* int minor_version, should always be set to this value */
	0,                          /* int driver_flags, see documentation */
	NULL,                       /* void *handle2, reserved for VM use */
	NULL,                       /* F_PTR process_exit, called when a monitored process dies */
	NULL,                       /* F_PTR stop_select, called to close an event object */
	NULL                        /* emergency close */
};

DRIVER_INIT(example_drv) /* must match name in driver_entry */
{
	return &example_driver_entry;
}
