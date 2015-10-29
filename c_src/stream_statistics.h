#include <inttypes.h>
#include <math.h>

#define INITIAL_SAMPLE_SIZE (50)


typedef struct {
	// where α is the smoothing factor, and 0 < α < 1. In other words, the smoothed
	// statistic st is a simple weighted average of the current observation xt and the
	// previous smoothed statistic st−1. The term smoothing factor applied to α here
	// is something of a misnomer, as larger values of α actually reduce the level of
	// smoothing, and in the limiting case with α = 1 the output series is just the
	// same as the original series
	double	  alpha;
	double  	average;
	uint64_t  c; //number of samples taken
	double    initial[INITIAL_SAMPLE_SIZE];
} stream_statistics_t;


void   stream_stats_init(stream_statistics_t *stats, double alpha);
void   stream_stats_reset(stream_statistics_t *stats);
double stream_stats_update(stream_statistics_t *stats, double new_value);
