

typedef struct {
	double kp, ki, kd;
	double t;
	double previous_error;
	double integral;
} pid_state_t;

void pid_init(pid_state_t *pid, double kp, double ki, double kd);
void pid_reset(pid_state_t *pid);
double pid_control(pid_state_t *pid, double time, double measured_value, double setpoint);
