#include "pid.h"

void pid_init(pid_state_t *pid, double kp, double ki, double kd, double di_cutoff) {
	pid->kp = kp;
	pid->ki = ki;
	pid->kd = kd;
	pid->di_cutoff = di_cutoff;
	pid->t = 0.;
	pid->previous_error = 0.;
	pid->integral = 0.;
}

double pid_control(
		pid_state_t *pid,
		double time,
		double measured_value,
		double setpoint)
{
	if (pid->t == 0.0) {
		pid->t = time;
		return 0.0;
	}
	double dt = time - pid->t;
	double error = setpoint - measured_value;
  double integral, derivative;

  if (error > pid->di_cutoff) {
    integral = 0.0;
    derivative = 0.0;
  } else {
    integral = pid->integral + (error * dt);
    derivative = (error - pid->previous_error) / dt;
    pid->integral = integral;
  }
	double output = pid->kp * error + pid->ki * integral + pid->kd * derivative;
	pid->previous_error = error;
	pid->t = time;
	return output/1000000.0;
}

void pid_reset(pid_state_t *pid) {
	pid->t = 0.;
	pid->previous_error = 0.;
	pid->integral = 0.;
}
