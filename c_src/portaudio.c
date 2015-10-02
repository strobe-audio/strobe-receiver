#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdbool.h>

#include "erl_driver.h"
#include "endian.h"
#include <portaudio.h>
#include "pa_ringbuffer.h"
#include "pa_util.h"

#include <samplerate.h>

#define PLAY_COMMAND  (1)
/*
 * 3528 bytes = 1,764 short
 */

#define PACKET_SIZE   (1764)
#define BUFFER_SIZE   (16)
#define SAMPLE_RATE   (44100.0)
#define CHANNEL_COUNT (2)

// http://stackoverflow.com/questions/3599160/unused-parameter-warnings-in-c-code
#define UNUSED(x) (void)(x)

// https://github.com/squidfunk/generic-linked-in-driver/blob/master/c_src/gen_driver.c

typedef struct timestamped_packet {
	uint64_t timestamp;
	uint16_t len; // number of floats, not byte size
	uint16_t offset;    // number of floats, not byte size
	float    data[PACKET_SIZE];
} timestamped_packet;

typedef struct audio_callback_context {
	PaStream*           audio_stream;
	int                 sample_size;
	PaUtilRingBuffer    audio_buffer;
	timestamped_packet *audio_buffer_data;
	timestamped_packet *active_packet;
} audio_callback_context;

typedef struct portaudio_state {
	ErlDrvPort port;
	audio_callback_context *audio_context;
} portaudio_state;


bool load_next_packet(audio_callback_context *context)
{
	if (PaUtil_GetRingBufferReadAvailable(&context->audio_buffer) > 0) {
		PaUtil_ReadRingBuffer(&context->audio_buffer, context->active_packet, 1);

		return true;
	}
	return false;
}

unsigned long send_packet_with_offset(timestamped_packet *packet,
		audio_callback_context *context,
		float *out,
		unsigned long requestedLen,
		unsigned long outOffset)
{
	unsigned long len = requestedLen;
	uint16_t offset = 0;
	if ((packet->offset + len) <= packet->len) {
		offset = packet->offset + len;
	} else {
		len = packet->len - packet->offset;
		offset = packet->len;
	}
	/* printf("\rsending packet %lu/%lu [ %u -> %u/%u ] [%f, %f]\r\n", len, requestedLen, packet->offset, offset, packet->len, *(packet->data + packet->offset), *(packet->data + packet->offset + 1)); */

	memcpy((out + outOffset), (float *)(packet->data + packet->offset), len * context->sample_size);

	packet->offset = offset;

	return len;
}

void send_packet(timestamped_packet *packet,
		audio_callback_context *context,
		float *out,
		unsigned long frameCount)
{
	unsigned long requestedLen = frameCount * CHANNEL_COUNT;
	unsigned long len = send_packet_with_offset(packet, context, out, requestedLen, 0);
	if (len < requestedLen) {
		// i've obviously used up the active_packet so it's safe to just load the next one
		if (load_next_packet(context)) {
			len = send_packet_with_offset(packet, context, out, requestedLen - len, len);
		}
	}
}

bool context_has_data(audio_callback_context *context)
{
	timestamped_packet* packet = context->active_packet;
	return (packet->len > 0) && (packet->offset < packet->len);
}
static int audio_callback(const void* _input,
		void*                             output,
		unsigned long                     frameCount,
		const PaStreamCallbackTimeInfo*   timeInfo,
		PaStreamCallbackFlags             statusFlags,
		void*                             userData)
{
	audio_callback_context* context = (audio_callback_context*)userData;
	float *out = (float*)output;
	timestamped_packet* packet = NULL;

	UNUSED(_input);

	/* Roughly what we have to do here, ignoring any timing/resampling stuff:
	**
	**   - if we don't have active data
	**     - if we have a packet in the ring buffer (playback starting)
	**     - retrieve packet
	**     - set it as active - try again...
	**   - with active data
	**     - get enough frames from the active packet to satisfy the request
	**       - update the packet pointer to keep track of position
	**       - if the current packet doesn't have enough frames left, get the next...
	**     - send frame data to output
	**/
	if (context_has_data(context)) {
		// printf("\rcontext has data\r\n");
		packet = context->active_packet;
	} else {
		if (load_next_packet(context)) {
			packet = context->active_packet;
		}
	}
	if (packet == NULL) {
		// printf("\rDRV: silence\r\n");
		memset(out, 0, frameCount * CHANNEL_COUNT * context->sample_size);
	} else {
		// printf("\rDRV: packet\r\n");
		send_packet(packet, context, out, frameCount);
	}
	return paContinue;
}

PaError initialize_audio_stream(audio_callback_context* context)
{
	PaStream*           stream;
	PaError             err;
	PaStreamParameters  outputParameters;

	printf("\rDRV: Pa_Initialize\r\n");

	err = Pa_Initialize();
	if (err != paNoError) { goto error; }

	outputParameters.device = Pa_GetDefaultOutputDevice(); //Take the default output device.

	if (outputParameters.device == paNoDevice) {
		fprintf(stderr,"\rError: No default output device.\r\n");
		goto error;
	}

	outputParameters.channelCount = CHANNEL_COUNT;                     /* Stereo output, most likely supported. */
	outputParameters.hostApiSpecificStreamInfo = NULL;
	outputParameters.sampleFormat = paFloat32;             /* 32 bit floating point output. */
	outputParameters.suggestedLatency = Pa_GetDeviceInfo(outputParameters.device)->defaultLowOutputLatency;

	err = Pa_OpenStream(&stream,
			NULL,                              // No input.
			&outputParameters,
			SAMPLE_RATE,                       // Sample rate.
			paFramesPerBufferUnspecified,      // Frames per buffer.
			paDitherOff,                       // Clip but don't dither
			audio_callback,
			context);

	if (err != paNoError) { goto error; }

	context->audio_stream = stream;

	err = Pa_GetSampleSize(outputParameters.sampleFormat);

	if (err == paSampleFormatNotSupported) { goto error; }

	context->sample_size = (int)err;

	err = Pa_StartStream( stream );

	if (err != paNoError) { goto error; }

	return paNoError;

error:
	Pa_Terminate();
	fprintf( stderr, "\rAn error occured while using the portaudio stream\r\n" );
	fprintf( stderr, "\rError number: %d\r\n", err );
	fprintf( stderr, "\rError message: %s\r\n", Pa_GetErrorText( err ) );

	return err;
}

static ErlDrvData portaudio_drv_start(ErlDrvPort port, char *buff)
{
	PaError             err;

	UNUSED(buff);

	portaudio_state* state          = (portaudio_state*)        driver_alloc(sizeof(portaudio_state));
	audio_callback_context* context = (audio_callback_context*) driver_alloc(sizeof(audio_callback_context));
	context->active_packet          = (timestamped_packet*)     driver_alloc(sizeof(timestamped_packet));
	context->audio_buffer_data      = (timestamped_packet*)     driver_alloc(sizeof(timestamped_packet) * BUFFER_SIZE);

	if (context->audio_buffer_data == NULL) {
		printf("\rDRV ERROR: problem allocating buffer\r\n");
		goto error;
	}

	PaUtil_InitializeRingBuffer(&context->audio_buffer, sizeof(timestamped_packet), BUFFER_SIZE, context->audio_buffer_data);

	err = initialize_audio_stream(context);

	if (err != paNoError) { goto error; }

	printf("\rDRV: driver start\r\n");
	state->port = port;
	state->audio_context = context;


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
	driver_free((char*)context->audio_buffer_data);
	driver_free((char*)context->active_packet);
	driver_free((char*)context);
	driver_free((char*)drv_data);
	printf("\rDRV: stopped\r\n");
}

static ErlDrvSSizeT portaudio_drv_control(
		ErlDrvData   drv_data,
		unsigned int cmd,
		char         *buf,
		ErlDrvSizeT  _len,
		char         **_rbuf,
		ErlDrvSizeT  _rlen)
{

	int index = 0;

	UNUSED(_len);
	UNUSED(_rbuf);
	UNUSED(_rlen);

	portaudio_state *state = (portaudio_state*)drv_data;
	audio_callback_context *context = state->audio_context;

	if (cmd == PLAY_COMMAND) {
		uint64_t time = le64toh(*(uint64_t *) buf);
		uint16_t len  = le16toh(*(uint16_t *) (buf + 8));
		struct timestamped_packet packet = {
			.offset = 0,
			.timestamp = time,
			.len = len / 2
		};
		// conversion to float needed by libsamplerate
		src_short_to_float_array((short*)(buf + 10), packet.data, len / 2);

		printf("\rDRV: play %" PRIu64 " %" PRIu16 " [%.10f,%.10f : %.10f,%.10f ...]\r\n", packet.timestamp, packet.len, packet.data[0], packet.data[1], packet.data[2], packet.data[3]);
		PaUtil_WriteRingBuffer(&context->audio_buffer, &packet, 1);

	}
	return index;
}

ErlDrvEntry example_driver_entry = {
	NULL,			/* F_PTR init, called when driver is loaded */
	portaudio_drv_start,		/* L_PTR start, called when port is opened */
	portaudio_drv_stop,		/* F_PTR stop, called when port is closed */
	NULL,		/* F_PTR output, called when erlang has sent */
	NULL,			/* F_PTR ready_input, called when input descriptor ready */
	NULL,			/* F_PTR ready_output, called when output descriptor ready */
	"portaudio",		/* char *driver_name, the argument to open_port */
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
