extends RigidBody2D

const Response = preload("res://modules/restaurant/domain/material_response.gd")
const Spring = preload("res://modules/restaurant/third_party/spring_damper/spring_damper.gd")
var board_velocity := Vector2.ZERO
var board_spin := 0.0
var board_height := 0.0
var board_vertical_speed := 0.0
var board_settling := false
var board_bounds := Rect2()
var response: Dictionary = {}
var compression := 0.0
var feedback_angle := 0.0
var impact_speed := 0.0
var _compression = Spring.new(0.0, 0.0, 23.0, 0.85)
var _slosh = Spring.new(0.0, 0.0, 12.0, 0.5)
var _previous_velocity := Vector2.ZERO
var _previous_position := Vector2.ZERO
var _sampled := false
var _impact_cooldown := 0.0
var _base_art_scale := Vector2.ZERO
var _flex = Spring.new(0.0, 0.0, 9.0, 0.72)
var _response_elapsed := 0.0

func _ready() -> void:
	# Construction used auto-generated child names, while phase transitions
	# looked for CollisionShape2D. Name the actual collider before any cooking.
	for child in get_children():
		if child is CollisionShape2D:
			child.name = "CollisionShape2D"
			break
	refresh_response()

func refresh_response() -> void:
	response = Response.effective(self)
	if get_meta("dispensed", false): return # the finite liquid state owns these bodies
	if physics_material_override == null or not physics_material_override.resource_local_to_scene:
		physics_material_override = PhysicsMaterial.new()
		physics_material_override.resource_local_to_scene = true
	# Reassigning unchanged contact properties repeatedly wakes settled bodies.
	if not is_equal_approx(physics_material_override.friction,response.friction): physics_material_override.friction = response.friction
	if not is_equal_approx(physics_material_override.bounce,response.bounce): physics_material_override.bounce = response.bounce
	if not is_equal_approx(linear_damp,response.linear_damp): linear_damp = response.linear_damp
	if not is_equal_approx(angular_damp,response.angular_damp): angular_damp = response.angular_damp
	if get_meta("is_container", false):
		var contents_mass := Response.container_mass(get_meta("definition", {}), float(get_meta("remaining_ml", 0.0)))
		if not is_equal_approx(mass,contents_mass): mass = contents_mass
	_compression.freq = response.spring_frequency
	_compression.damp = response.spring_damping

func reset_motion_sample() -> void:
	_sampled = false
	_previous_velocity = Vector2.ZERO
	_slosh.pos = 0.0
	_slosh.vel = 0.0
	feedback_angle = 0.0

func impact(speed: float) -> void:
	if _impact_cooldown > 0.0 or speed < 18.0: return
	_impact_cooldown = 0.12
	impact_speed = speed
	_compression.vel += minf(speed / 160.0, 1.5) * float(response.get("compliance", 0.0)) * 22.0
	var world = get_parent().get_parent() if get_parent() else null
	if is_instance_valid(world) and world.get("audio") != null and world.controls_enabled:
		world.audio.play_food_drop(self)

func begin_board_settle(bounds: Rect2, velocity: Vector2, spin: float, height := 5.0) -> void:
	freeze = true
	refresh_response()
	board_bounds = bounds
	board_velocity = velocity.limit_length(60.0)
	board_spin = clampf(spin, -3.0, 3.0)
	if bool(response.get("rolling",false)):
		board_spin = clampf(board_velocity.x / 27.0 + board_spin * 0.15, -2.2, 2.2)
	board_height = height
	board_vertical_speed = 0.0
	board_settling = true
	set_meta("on_board", true)

func stop_board_settle() -> void:
	board_settling = false
	board_height = 0.0
	var art := get_node_or_null("FoodArt") as Node2D
	if art: art.position = Vector2.ZERO

func advance_feedback(dt: float, velocity: Vector2, pressure: float) -> void:
	# Analytic MIT spring; simulation is on the fixed physics tick.
	_response_elapsed += dt
	if _response_elapsed >= 0.1:
		refresh_response()
		_response_elapsed = 0.0
	_impact_cooldown = maxf(0.0, _impact_cooldown - dt)
	var definition: Dictionary = get_meta("definition", {})
	var is_bottle := bool(get_meta("is_container", false))
	var target := 0.0
	if is_bottle and definition.get("dispense_mode", "") == "squeeze":
		var fill := clampf(float(get_meta("remaining_ml", 0.0)) / maxf(1.0, float(definition.get("container_ml", 240.0))), 0.0, 1.0)
		target = pressure * float(response.compliance) * lerpf(1.0, 0.65, fill)
	compression = clampf(float(_compression.update_spring_damper(target, dt)), 0.0, 0.26)
	if is_bottle:
		var viscosity := float(definition.get("viscosity", 0.3))
		_slosh.damp = lerpf(0.28, 1.25, viscosity)
		_slosh.freq = lerpf(13.0, 8.0, viscosity)
		var contents := maxf(0.0, mass - float(response.get("tare_kg", 0.05)))
		var acceleration := (velocity - _previous_velocity) / maxf(dt, 0.001)
		var slosh_target := clampf(-acceleration.x * 0.000022, -0.13, 0.13) * (contents / maxf(mass, 0.001))
		feedback_angle = clampf(float(_slosh.update_spring_damper(slosh_target, dt)), -0.13, 0.13)
	_previous_velocity = velocity
	var art := get_node_or_null("FoodArt") as Node2D
	if art:
		if "flex" in art and str(definition.get("id", "")) in ["noodles", "sock"]:
			art.flex = float(_flex.update_spring_damper(clampf(-velocity.x / 200.0, -1.0, 1.0), dt))
			var world = get_parent().get_parent()
			var held: bool = is_instance_valid(world) and (world.get("_held") == self or (world.has_method("utensil_holds") and world.utensil_holds(self)))
			art.dangling = move_toward(art.dangling, 1.0 if held else 0.0, dt * 4.5)
			art.motion_time += dt
			art.queue_redraw()
		if _base_art_scale == Vector2.ZERO: _base_art_scale = art.scale
		if is_bottle:
			art.set("compression", compression)
		else:
			var deform := Vector2.ONE
			if has_meta("thermal"): deform = preload("res://modules/restaurant/domain/food_thermal.gd").shape(get_meta("thermal"),definition)
			art.scale = _base_art_scale * deform * Vector2(1.0 + compression * 0.45, 1.0 - compression)

func _physics_process(delta: float) -> void:
	var world = get_parent().get_parent() if get_parent() else null
	if not is_instance_valid(world) or world.get("controls_enabled") == false:
		_sampled = false
		return
	var dt := minf(delta, 1.0 / 30.0)
	var held: bool = world.get("_held") == self
	var velocity := linear_velocity
	if held:
		velocity = ((global_position - _previous_position) / dt).limit_length(900.0) if _sampled else Vector2.ZERO
	_previous_position = global_position
	_sampled = true
	advance_feedback(dt, velocity, float(world.squeeze_pressure) if held and world._squeezing else 0.0)
	if not board_settling: return
	if not get_meta("on_board", false):
		stop_board_settle()
		return
	board_vertical_speed += 260.0 * dt # identical gravity for every mass
	board_height -= board_vertical_speed * dt
	if board_height <= 0.0:
		board_height = 0.0
		if board_vertical_speed > 20.0:
			impact(board_vertical_speed)
			board_vertical_speed = -board_vertical_speed * float(response.bounce)
		else: board_vertical_speed = 0.0
	position += board_velocity * dt
	var clamped := position.clamp(board_bounds.position, board_bounds.end)
	if clamped.x != position.x: board_velocity.x = 0.0
	if clamped.y != position.y: board_velocity.y = 0.0
	position = clamped
	rotation += board_spin * dt
	var grounded := board_height <= 0.0 and board_vertical_speed >= 0.0
	var rolling := bool(response.get("rolling",false))
	board_velocity = board_velocity.move_toward(Vector2.ZERO, (float(response.friction) * (48.0 if rolling else 180.0) if grounded else 2.0) * dt)
	if grounded and rolling:
		board_spin = board_velocity.x / 27.0
	else:
		board_spin = move_toward(board_spin, 0.0, (float(response.angular_damp) if grounded else 0.25) * dt)
	var art := get_node_or_null("FoodArt") as Node2D
	if art: art.position = Vector2(0, -board_height)
	if grounded and board_velocity.length() < 0.1 and absf(board_spin) < 0.01: stop_board_settle()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var speed := 0.0
	for i in state.get_contact_count():
		var relative := state.get_contact_local_velocity_at_position(i) - state.get_contact_collider_velocity_at_position(i)
		speed = maxf(speed, absf(relative.dot(state.get_contact_local_normal(i))))
	if speed > 18.0: impact.call_deferred(speed)
	state.linear_velocity = state.linear_velocity.limit_length(1100.0)
	state.angular_velocity = clampf(state.angular_velocity, -8.0, 8.0)
