#include "stream_statistics.h"
#include <stdio.h>


// taken from:
// http://jonisalonen.com/2014/efficient-and-accurate-rolling-standard-deviation/
//
//
void stream_stats_init(stream_statistics_t *stats, double alpha) {
	stats->c       = 0;
	stats->alpha   = alpha;
	stats->average = 0.0;
}

double initial_average(stream_statistics_t *stats, int n) {
	double total = 0.0;
	for (int i = 0; i < n; ++i) {
		total += stats->initial[i];
	}
	return total/((double)n);
}

void stream_stats_reset(stream_statistics_t *stats) {
	stats->c = 0;
	stats->average = 0.0;
}

double stream_stats_update(stream_statistics_t *stats, double new_value) {
	if (isnan(new_value)) {
		return stats->average;
	}

	// collect a good first sample
	if (stats->c < INITIAL_SAMPLE_SIZE) {
		stats->initial[stats->c++] = new_value;
		stats->average = initial_average(stats, stats->c);
		return stats->average;
	}

	double oldavg = stats->average;
	// exponential avg https://en.wikipedia.org/wiki/Moving_average
	double newavg = (stats->alpha * new_value) + (1.0 - stats->alpha) * oldavg;
	stats->average = newavg;

	++stats->c;

	return stats->average;
}
