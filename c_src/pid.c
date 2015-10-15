#include "pid.h"

void pid_init(pid_state_t *pid, double kp, double ki, double kd) {
	pid->kp = kp;
	pid->ki = ki;
	pid->kd = kd;
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
	double integral = pid->integral + (error * dt);
	double derivative = (error - pid->previous_error) / dt;
	double output = pid->kp * error + pid->ki * integral + pid->kd * derivative;
	pid->integral = integral;
	pid->previous_error = error;
	pid->t = time;
	return output/1000000.0;
}
