/* ------------------------------------------------------------------------
 * FILE: least-squares.c
 * This program computes a linear model for a set of given data.
 *
 * PROBLEM DESCRIPTION:
 *  The method of least squares is a standard technique used to find
 *  the equation of a straight line from a set of data. Equation for a
 *  straight line is given by
 *	 y = mx + b
 *  where m is the slope of the line and b is the y-intercept.
 *
 *  Given a set of n points {(x1,y1), x2,y2),...,xn,yn)}, let
 *      sum_x = x1 + x2 + ... + xn
 *      sum_y = y1 + y2 + ... + yn
 *      sum_xy = x1*y1 + x2*y2 + ... + xn*yn
 *      sum_xx = x1*x1 + x2*x2 + ... + xn*xn
 *
 *  The slope and y-intercept for the least-squares line can be
 *  calculated using the following equations:
 *        slope (m) = ( sum_x*sum_y - n*sum_xy ) / ( sum_x*sum_x - n*sum_xx )
 *  y-intercept (b) = ( sum_y - slope*sum_x ) / n
 *
 * AUTHOR: Dora Abdullah (Fortran version, 11/96)
 * REVISED: RYL (converted to C, 12/11/96)
 * ---------------------------------------------------------------------- */
#include <stdlib.h>
#include <math.h>
#include <stdio.h>

#include "least_squares.h"

void sample_least_squares(UT_ringbuffer *playback_samples, playback_state_t *playback_state) {

  double sum_x, sum_y, sum_xy, sum_xx, slope, y_intercept, x;
  int n = 0;

  sum_x = 0.; sum_y = 0.; sum_xy = 0.; sum_xx = 0.;
	stream_sample_t *s;

	uint64_t offset = 0;

	for(s = (stream_sample_t*)utringbuffer_front(playback_samples);
			s != NULL;
			s = (stream_sample_t*)utringbuffer_next(playback_samples, s))
	{
		if (n == 0) {
			offset = s->t;
		}
		++n;
		x = (double)(s->t - offset);
		sum_x = sum_x + x;
		sum_y = sum_y + (double)s->o;
    sum_xy = sum_xy + (double)(x * s->o);
    sum_xx = sum_xx + (x * x);
  }
	double d = ( sum_x*sum_x - n*sum_xx );

	if (n == 0 || d == 0.0) {
		return;
	}

  slope = ( sum_x*sum_y - n*sum_xy ) / d;
  y_intercept = ( sum_y - slope*sum_x ) / n;


	playback_state->ratio = slope;
	playback_state->timestamp_delta = y_intercept;

  /* double res = 0., sum_res = 0., y_estimate; */
  /* for (i=0; i<n; i++) { */
  /*   y_estimate = slope*x[i] + y_intercept; */
  /*   res = y[i] - y_estimate; */
  /*   sum_res = sum_res + res*res; */
  /*   printf ("   (%6.2lf %6.2lf)      %6.2lf       %6.2lf\n", */
	/*     x[i], y[i], y_estimate, res); */
  /* } */
  /* printf("--------------------------------------------------\n"); */
  /* printf("Residual sum = %6.2lf\n", sum_res); */
}

