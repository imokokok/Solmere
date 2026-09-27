extends RefCounted
const Tuning=preload("res://modules/restaurant/domain/physical_tuning.gd")
## A bounded force controller. The physics engine still owns position and contacts.
## Screen units are pixels; 250 px corresponds to approximately one metre.
var target := Vector2.ZERO
var local_anchor := Vector2.ZERO
var target_angle := 0.0
var enabled := false
var last_force := Vector2.ZERO
var max_force := Tuning.number("grab","max_force")

func begin(body: RigidBody2D, pointer: Vector2) -> void:
	target = pointer
	local_anchor = body.to_local(pointer)
	target_angle = body.rotation
	enabled = true
	body.freeze = false
	body.sleeping = false

func apply(body: RigidBody2D, dt: float) -> void:
	if not enabled or dt <= 0.0: return
	var arm := local_anchor.rotated(body.rotation)
	var point := body.global_position + arm
	var point_velocity := body.linear_velocity + Vector2(-arm.y, arm.x) * body.angular_velocity
	# Implicit spring gains remain damped at both 60 and 120 Hz. Heavy loads lag.
	var omega := Tuning.number("grab","frequency") / pow(maxf(body.mass, 0.08) / 0.2, Tuning.number("grab","mass_exponent"))
	var denominator := 1.0 + 2.0 * omega * dt + omega * omega * dt * dt
	var accel := ((target - point) * omega * omega - point_velocity * (2.0 * omega + omega * omega * dt)) / denominator
	last_force = (body.mass * (accel - Vector2(0, 980.0 * body.gravity_scale))).limit_length(max_force)
	body.apply_force(last_force, arm)
	# Wrist support acts on orientation, not by locking rotation in the solver.
	var inertia := maxf(body.inertia if body.inertia > 0 else body.mass * 950.0, 0.1)
	var error := wrapf(target_angle - body.rotation, -PI, PI)
	var angular_accel := (error * 144.0 - body.angular_velocity * (24.0 + 144.0 * dt)) / (1.0 + 24.0 * dt + 144.0 * dt * dt)
	var torque := inertia * angular_accel - (arm - body.center_of_mass.rotated(body.rotation)).cross(last_force)
	body.apply_torque(clampf(torque, -max_force * 180.0, max_force * 180.0))
	body.sleeping = false

func release() -> void:
	enabled = false
	last_force = Vector2.ZERO
