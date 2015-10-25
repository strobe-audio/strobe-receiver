#include "stream_statistics.h"
#include <stdio.h>


// taken from:
// http://jonisalonen.com/2014/efficient-and-accurate-rolling-standard-deviation/
//
void stream_stats_init(stream_statistics_t *stats, int window_size) {
	stats->c = 0;
	stats->i = 0;
	stats->n = window_size;
	stats->last_value = 0.;
	stats->average    = 0.;
}

double initial_average(stream_statistics_t *stats) {
	double total = 0.0;
	for (int i = 0; i < stats->i; ++i) {
		total += stats->initial[i];
	}
	return total/((double)(stats->i));
}

void stream_stats_reset(stream_statistics_t *stats) {
	stats->c = 0;
	stats->i = 0;
}

void stream_stats_update(stream_statistics_t *stats, double new) {
	if (isnan(new)) {
		return;
	}

	// collect a good first sample
	if (stats->i < INITIAL_SAMPLE_SIZE) {
		stats->initial[stats->i++] = new;
		stats->average    = initial_average(stats);
		stats->last_value = new;
		return;
	}
	//printf("update: %f\r\n", new);

	double oldavg = stats->average;
	// exponential avg https://en.wikipedia.org/wiki/Moving_average
	double newavg = (ALPHA * new) + (1.0 - ALPHA) * oldavg;
	stats->average = newavg;

	++stats->c;
	stats->last_value = new;
}
