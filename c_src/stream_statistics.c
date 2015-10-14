#include "stream_statistics.h"
#include <stdio.h>

// taken from:
// http://jonisalonen.com/2014/efficient-and-accurate-rolling-standard-deviation/
//
void stream_stats_init(stream_statistics_t *stats, int window_size) {
	stats->c = 0;
	stats->n = window_size;
	stats->last_value = 0.;
	stats->average    = 0.;
	/* stats->variance   = 0.; */
	/* stats->stddev     = 0.; */
}

void stream_stats_reset(stream_statistics_t *stats) {
	stats->c = 0;
}

void stream_stats_update(stream_statistics_t *stats, double new) {
	if (isnan(new)) {
		return;
	}
	//printf("update: %f\r\n", new);
	if (stats->c == 0) {
		stats->average    = new;
	} else if (stats->c < 2) {
		stats->average = (stats->last_value + new) / 2.0;
		//printf("update: %"PRIu64"; new: %f; avg: %f\r\n", stats->c, new, stats->average);
	} else {
		int n;

		if (stats->c >= (uint64_t)stats->n) {
			n = stats->n;
		} else {
			n = (int)stats->c;
		}
		double oldavg = stats->average;
		double d = new - stats->last_value;
	 	/* double newavg = oldavg + (d / n); */
		// exponential avg https://en.wikipedia.org/wiki/Moving_average
		double newavg = new + (0.999 * (oldavg - new));
		stats->average = newavg;
		/* stats->variance += d * ( new - newavg + stats->last_value - oldavg) / (n - 1); */
		/* stats->stddev = sqrt(stats->variance); */
		//printf("stats: c: %"PRIu64"; n: %d; old avg: %f; avg: %f\r\n", stats->c, stats->n, oldavg, stats->average);
	}


	++stats->c;
	stats->last_value = new;
}
