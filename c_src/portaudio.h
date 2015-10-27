#ifndef __JANIS__
#define __JANIS__ 1
// see http://man7.org/linux/man-pages/man3/endian.3.html
#define _BSD_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <inttypes.h>
#include <stdbool.h>
#include <assert.h>
#include <sys/time.h>
#include <sys/param.h>


#include <erl_driver.h>
#include <ei.h>

#include <portaudio.h>
#include <samplerate.h>

#include "endian.h"
#include "pa_ringbuffer.h"
#include "pa_util.h"
#include "monotonic_time.h"
#include "stream_statistics.h"
#include "pid.h"

// http://portaudio.com/docs/v19-doxydocs/compile_linux.html
#ifdef __linux__
#define __alsa__
#include <pa_linux_alsa.h>
#endif

#define PLAY_COMMAND  (1)
#define TIME_COMMAND  (2)
#define FLSH_COMMAND  (3)
#define GVOL_COMMAND  (4)
#define SVOL_COMMAND  (5)

#define USECONDS      (1000000.0)
#define PACKET_SIZE   (1764) // 3528 bytes = 1,764 shorts
#define PACKET_BUFFER_SIZE   (16)
#define SAMPLE_RATE   (44100.0)
#define SAMPLE_RATE_I   (44100)
#define CHANNEL_COUNT (2)
// the smaller this buffer is, the more accurately we can judge the playback
// position. It's functionally impossible to know exactly how many frames from
// the current packet have actually been played (as this is controlled by the
// libsamplerate code which is basically a black box).
// There can be at most 1 buffer's worth of discrepency between the actual
// playback position and the bytes sent to the resampler (since the resampler
// works in buffer-sized chunks).
#define OUTPUT_BUFFER_FRAMES (8)
#define OUTPUT_BUFFER_SIZE   ((OUTPUT_BUFFER_FRAMES) * (CHANNEL_COUNT))

#define SECONDS_PER_FRAME  (1.0 / SAMPLE_RATE)
#define USECONDS_PER_FRAME (USECONDS / SAMPLE_RATE)
#define FRAMES_PER_USECONDS (SAMPLE_RATE / USECONDS)
// used to work out the time offset of the active packet based on
// its offset, which is in individual floats, not frames. However
// the offset will always be a multiple of 2 so this is just a convenience
#define SECONDS_PER_FLOAT (1.0 / (SAMPLE_RATE * CHANNEL_COUNT))
#define USECONDS_PER_FLOAT (USECONDS * SECONDS_PER_FLOAT)

#define STREAM_STATS_WINDOW_SIZE 1000
#define MAX_RESAMPLE_RATIO       0.01

// http://stackoverflow.com/questions/3599160/unused-parameter-warnings-in-c-code
#define UNUSED(x) (void)(x)

#define CONTEXT_HAS_DATA(c) ((c->active_packet != NULL) && (c->active_packet->len > 0) && (c->active_packet->offset < c->active_packet->len))

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
	uint64_t            stream_start_time;

	uint64_t            frame_count;
	PaTime              latency;

	bool                playing;

	stream_statistics_t  *timestamp_offset_stats;

	SRC_STATE            *resampler;

	float                buffer[OUTPUT_BUFFER_SIZE];

	pid_state_t          pid;

	float                volume;
} audio_callback_context;

typedef struct portaudio_state {
	ErlDrvPort port;
	audio_callback_context *audio_context;
} portaudio_state;

#endif

