#include <inttypes.h>
#include "utringbuffer.h"

#define STREAM_SAMPLE_SIZE 50

typedef struct {
    uint64_t t;
    int64_t  o; // this doesn't need to be 64 bit
} stream_sample_t;

typedef struct {
	double  ratio;
	double timestamp_delta;
} playback_state_t;

void sample_least_squares(UT_ringbuffer *playback_samples, playback_state_t *playback_state);

