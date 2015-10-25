#include <inttypes.h>
#include <math.h>

#define INITIAL_SAMPLE_SIZE (1000)

typedef struct {
	uint64_t  c; //number of samples taken
	int	      n; // window size
	double    last_value;
	double  	average;
	double    initial[INITIAL_SAMPLE_SIZE];
	int       i;
} stream_statistics_t;


void stream_stats_init(stream_statistics_t *stats, int window_size);
void stream_stats_update(stream_statistics_t *stats, double new);
void stream_stats_reset(stream_statistics_t *stats);
