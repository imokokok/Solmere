extends RefCounted
# Local integration: reference-counted lifetime; no global class registration.

#Written by Hyphinett
#Implementation based on https://www.ryanjuckett.com/damped-springs/

var pos
var vel
var freq: float:
	set(val):
		if freq != val:
			freq = max(0, val)
			update_motion_params = true
var damp: float:
	set(val):
		if damp != val:
			damp = max(0, val)
			update_motion_params = true
var pos_pos_coef: float
var pos_vel_coef: float
var vel_pos_coef: float
var vel_vel_coef: float
var fixed_delta: float:
	set(val):
		if fixed_delta != val:
			fixed_delta = val
			update_motion_params = true
var update_motion_params: bool = false


func _init(init_pos, init_vel, init_freq: float, init_damp: float, init_delta: float = 0.0):
	pos = init_pos
	vel = init_vel
	freq = init_freq
	damp = init_damp
	fixed_delta = init_delta


func calc_damped_motion_params(delta: float):
	if is_equal_approx(freq, 0):
		pos_pos_coef = 1.0
		pos_vel_coef = 0.0
		vel_pos_coef = 0.0
		vel_vel_coef = 1.0
		return

	if is_equal_approx(damp, 1.0):
		var exp_term: float = exp(-freq * delta)
		var time_exp: float = delta * exp_term
		var time_exp_freq: float = time_exp * freq

		pos_pos_coef = time_exp_freq + exp_term
		pos_vel_coef = time_exp
		vel_pos_coef = -freq * time_exp_freq
		vel_vel_coef = -time_exp_freq + exp_term

	elif damp > 1.0:
		var za: float = -freq * damp
		var zb: float = freq * sqrt(damp * damp - 1.0)
		var z1: float = za - zb
		var z2: float = za + zb

		var e1: float = exp(z1 * delta)
		var e2: float = exp(z2 * delta)

		var inv_2zb: float = 1.0 / (2.0 * zb)

		var e1_over_2zb: float = e1 * inv_2zb
		var e2_over_2zb: float = e2 * inv_2zb

		var z1e1_over_2zb: float = z1 * e1_over_2zb
		var z2e2_over_2zb: float = z2 * e2_over_2zb

		pos_pos_coef = e1_over_2zb * z2 - z2e2_over_2zb + e2
		pos_vel_coef = -e1_over_2zb + e2_over_2zb
		vel_pos_coef = (z1e1_over_2zb - z2e2_over_2zb + e2) * z2
		vel_vel_coef = -z1e1_over_2zb + z2e2_over_2zb

	elif damp < 1.0:
		var omega_zeta: float = freq * damp
		var alpha: float = freq * sqrt(1.0 - damp * damp)

		var exp_term: float = exp(-omega_zeta * delta)
		var cos_term: float = cos(alpha * delta)
		var sin_term: float = sin(alpha * delta)

		var inv_alpha: float = 1.0 / alpha

		var exp_sin: float = exp_term * sin_term
		var exp_cos: float = exp_term * cos_term
		var exp_omega_zeta_sin_over_alpha: float = exp_term * omega_zeta * sin_term * inv_alpha

		pos_pos_coef = exp_cos + exp_omega_zeta_sin_over_alpha
		pos_vel_coef = exp_sin * inv_alpha

		vel_pos_coef = -exp_sin * alpha - omega_zeta * exp_omega_zeta_sin_over_alpha
		vel_vel_coef = exp_cos - exp_omega_zeta_sin_over_alpha


func update_spring_damper(targ, delta: float = 0):
	if delta <= 0:
		if fixed_delta <= 0:
			printerr("Failed to update spring damper. No fixed delta provided to constructor and a delta of zero was provided for the update")
			return null
	if delta > 0 and fixed_delta > 0:
		fixed_delta = delta
		update_motion_params = true
	if fixed_delta > 0 and update_motion_params:
		calc_damped_motion_params(fixed_delta)
		update_motion_params = false
	elif delta > 0:
		calc_damped_motion_params(delta)


	var old_pos = pos - targ
	var old_vel = vel

	pos = old_pos * pos_pos_coef + old_vel * pos_vel_coef + targ
	vel = old_pos * vel_pos_coef + old_vel * vel_vel_coef

	return pos
