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
 *
 */

#define PACKET_SIZE   (1764)
#define BUFFER_SIZE   (16)
#define SAMPLE_RATE   (44100.0)
#define CHANNEL_COUNT (2)

// http://stackoverflow.com/questions/3599160/unused-parameter-warnings-in-c-code
#define UNUSED(x) (void)(x)

// https://github.com/squidfunk/generic-linked-in-driver/blob/master/c_src/gen_driver.c

typedef struct {
	uint64_t timestamp;
	uint16_t data_size;
	uint16_t offset;
	float    data[PACKET_SIZE*2];
} timestamped_packet;

typedef struct {
	PaStream*           audio_stream;
	int                 sample_size;
	PaUtilRingBuffer    audio_buffer;
	void						   *audio_buffer_data;
	timestamped_packet *active_packet;
} audio_callback_context;

typedef struct {
	ErlDrvPort port;
	audio_callback_context *audio_context;
} portaudio_state;


void send_packet(timestamped_packet *packet, audio_callback_context *context, float *out, unsigned long frameCount)
{
	unsigned long len = frameCount * CHANNEL_COUNT * context->sample_size;
	uint16_t offset = 0;
	if ((packet->offset + len) <= packet->data_size) {
		offset = packet->offset + len;
	} else {
		len = packet->data_size - packet->offset;
		offset = packet->data_size;
	}
	printf("sending packet %lu %u -> %u %u\n", len, packet->offset, offset, packet->data_size, context->sample_size);
	memcpy(out, (&packet->data) + packet->offset, len);
	packet->offset = offset;
}

bool context_has_data(audio_callback_context *context)
{
	timestamped_packet* packet = context->active_packet;
	return (packet->data_size > 0) && (packet->offset < packet->data_size);
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

	memset(out, 0, frameCount * CHANNEL_COUNT * context->sample_size);
	/* Roughly what we have to do here, ignoring any timing/resampling stuff:
	 *
	 *   - if we don't have active data
	 *     - if we have a packet in the ring buffer (playback starting)
	 *  		 - retrieve packet
	 *  		 - set it as active - try again...
	 *   - with active data
	 *     - get enough frames from the active packet to satisfy the request
	 *  		 - update the packet pointer to keep track of position
	 *  		 - if the current packet doesn't have enough frames left, get the next...
	 *  	 - send frame data to output
	 */
	if (context_has_data(context)) {
		packet = context->active_packet;
	} else {
		if (PaUtil_GetRingBufferReadAvailable(&context->audio_buffer) > 0) {
			// this works
			/* timestamped_packet* packet = (timestamped_packet*)driver_alloc(sizeof(timestamped_packet)); */
			/* PaUtil_ReadRingBuffer(&context->audio_buffer, packet, 1); */
			/* printf("packet addr %llu\n", packet->timestamp); */

			/* timestamped_packet* packet = (timestamped_packet*)driver_alloc(sizeof(timestamped_packet)); */

			packet = context->active_packet;
			PaUtil_ReadRingBuffer(&context->audio_buffer, packet, 1);
			/* printf("packet size %u %lu\n", packet->data_size, packet->timestamp); */
			printf("DRV: callback %" PRIu64 " %" PRIu16 " %f,%f\n", packet->timestamp, packet->data_size, packet->data[0], packet->data[1]);
			/* printf("packet addr %llu\n", packet->timestamp); */
			/* printf("callback has data %lu %lu %llu\r\n", frameCount, frameCount * CHANNEL_COUNT * context->sample_size, packet->timestamp); */
			// dst, src, len
			/* memcpy(out, &packet->data, frameCount * CHANNEL_COUNT * context->sample_size); */
		}
	}
	if (packet != NULL) {
		send_packet(packet, context, out, frameCount);
	}
	return paContinue;
}

PaError initialize_audio_stream(audio_callback_context* context)
{
	PaStream*           stream;
	PaError             err;
	PaStreamParameters  outputParameters;

	printf("DRV: Pa_Initialize\n");

	err = Pa_Initialize();
	if (err != paNoError) { goto error; }

	outputParameters.device = Pa_GetDefaultOutputDevice(); //Take the default output device.

	if (outputParameters.device == paNoDevice) {
		fprintf(stderr,"Error: No default output device.\n");
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
	fprintf( stderr, "An error occured while using the portaudio stream\n" );
	fprintf( stderr, "Error number: %d\n", err );
	fprintf( stderr, "Error message: %s\n", Pa_GetErrorText( err ) );

	return err;
}

static ErlDrvData portaudio_drv_start(ErlDrvPort port, char *buff)
{
	PaError             err;

	portaudio_state* state = (portaudio_state*)driver_alloc(sizeof(portaudio_state));
	audio_callback_context* context = (audio_callback_context*)driver_alloc(sizeof(audio_callback_context));
	context->active_packet = (timestamped_packet*)driver_alloc(sizeof(timestamped_packet));

	UNUSED(buff);

	context->audio_buffer_data = (timestamped_packet*)driver_alloc(sizeof(timestamped_packet*) * BUFFER_SIZE);

	if (context->audio_buffer_data == NULL) {
		printf("DRV ERROR: problem allocating buffer\n");
		goto error;
	}

	PaUtil_InitializeRingBuffer(&context->audio_buffer, sizeof(timestamped_packet), BUFFER_SIZE, context->audio_buffer_data);

	err = initialize_audio_stream(context);

	if (err != paNoError) { goto error; }

	printf("DRV: driver start\n");
	state->port = port;
	state->audio_context = context;


	return (ErlDrvData)state;

error:

	return (ErlDrvData)state;
}

void cleanup() {
	printf("\nDRV: stop\n");
	Pa_Terminate();
}

// static void portaudio_drv_finish(ErlDrvData handle) {
// 	cleanup();
// 	driver_free((char*)handle);
// }

static void portaudio_drv_stop(ErlDrvData handle) {
	cleanup();
	driver_free((char*)handle);
}

static ErlDrvSSizeT portaudio_drv_control(
		ErlDrvData   drv_data,
		unsigned int cmd,
		char         *buf,
		ErlDrvSizeT  _len,
		char         **_rbuf,
		ErlDrvSizeT  _rlen)
{

	UNUSED(_len);
	UNUSED(_rbuf);
	UNUSED(_rlen);

	portaudio_state *state = (portaudio_state*)drv_data;
	audio_callback_context *context = state->audio_context;

	if (cmd == PLAY_COMMAND) {
		timestamped_packet* packet = (timestamped_packet*)driver_alloc(sizeof(timestamped_packet));
		uint64_t time = le64toh(*(uint64_t *) buf);
		uint16_t len  = le16toh(*(uint16_t *) (buf + 8));
		packet->timestamp = time;
		packet->data_size = len;
		packet->offset    = 0;
		// conversion to float needed by libsamplerate
		src_short_to_float_array((short*)(buf + 10), packet->data, len);
		// memcpy(packet->data, (buf + 10), len);

		PaUtil_WriteRingBuffer(&context->audio_buffer, packet, 1);

		printf("DRV: play %" PRIu64 " %" PRIu16 " %f,%f\n", packet->timestamp, packet->data_size, packet->data[0], packet->data[1]);
	}
	int index = 0;
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
