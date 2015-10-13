#include <inttypes.h>
#include <math.h>

typedef struct {
	uint64_t  c; //number of samples taken
	int	      n; // window size
	double    last_value;
	double  	average;
	double  	variance;
	double  	stddev;    // sqrt(variance)
} stream_statistics_t;


void stream_stats_init(stream_statistics_t *stats, int window_size);
void stream_stats_update(stream_statistics_t *stats, double new);
