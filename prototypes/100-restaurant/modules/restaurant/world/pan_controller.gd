extends Node2D
const Tuning=preload("res://modules/restaurant/domain/physical_tuning.gd")

const SINK_X: = 211.0
const HOME: = Vector2(-25, 110)
const ART_SCALE: = Vector2(1.30, 1.20)
const PIVOT: = Vector2(809, 599)
var world: Node2D
var active: = false
var offset: = Vector2.ZERO
var water_ml: = 0.0
var water_heat: = 22.0
var overflow_water_ml: = 0.0
var faucet_amount: = 0.0
var faucet_on: bool:
	get: return faucet_amount > 0.005
	set(value): faucet_amount = 1.0 if value else 0.0
var faucet_dragging: = false
var _faucet_drag_start_y: = 0.0
var _faucet_drag_start_amount: = 0.0
var _grab_point: = Vector2.ZERO
var _pointer: = Vector2.ZERO
var angle: = 0.0
var falling: = false
var _fall_speed: = 0.0
var _tipping: = false
var _carried: Array = []
var _last_transport: = 0
var pan_back: Node2D
var pan_front: Node2D
var pan_surface: Node2D
var faucet_art: Node2D
var rigid: RigidBody2D
var grip = preload("res://modules/restaurant/world/physical_grip.gd").new()
var _toss_sound_left := 0.0
var runoff: Node2D
var lid: Node2D:
	get: return world.lid
var overflowing := false
var slosh := 0.0
var slosh_velocity := 0.0
var _last_velocity := Vector2.ZERO
var water_input_ml := 0.0
var rim_water_ml := 0.0
var draining := false
var outflow_ml_s := 0.0
var _paused_velocity := Vector2.ZERO
var _paused_spin := 0.0
var residue = preload("res://modules/restaurant/world/pan_residue.gd").new()

func is_empty_for_cleaning() -> bool:
	for body in world._foods.get_children():
		if not body.is_queued_for_deletion() and not body.get_meta("plated", false) and (body.get_meta("enrolled", false) or body.get_meta("pending", false)) and contains(body.position): return false
	return true

func _ready() -> void :
	z_index = 3
	pan_back = preload("res://modules/restaurant/world/pan_art.gd").new()
	pan_back.controller = self
	pan_back.z_index = 4
	world.add_child(pan_back)
	pan_front = preload("res://modules/restaurant/world/kitchen_foreground.gd").new()
	pan_front.controller = self
	pan_front.z_index = 9
	world.add_child(pan_front)
	pan_surface = preload("res://modules/restaurant/world/pan_surface.gd").new()
	pan_surface.controller = self
	pan_surface.z_index = 7
	world.add_child(pan_surface)
	faucet_art = preload("res://modules/restaurant/world/sink_faucet.gd").new()
	faucet_art.controller = self
	faucet_art.z_index = 11
	world.add_child(faucet_art)
	_build_rigid_pan()
	runoff = preload("res://modules/restaurant/world/water_runoff.gd").new()
	runoff.world = world
	runoff.z_index = 10
	world.add_child(runoff)

func _build_rigid_pan() -> void:
	rigid = RigidBody2D.new()
	rigid.name = "PhysicalPan"
	rigid.mass = Tuning.number("pan","tare_kg")
	rigid.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	rigid.center_of_mass = Vector2(0,-18)
	rigid.inertia = rigid.mass * Tuning.number("pan","inertia_per_kg")
	rigid.collision_layer = 1 | 64
	rigid.collision_mask = 16 | 128 | 256 | 512
	rigid.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	rigid.contact_monitor = true
	rigid.max_contacts_reported = 12
	rigid.linear_damp = 1.2
	rigid.angular_damp = 3.5
	rigid.physics_material_override = PhysicsMaterial.new()
	rigid.physics_material_override.friction = 0.65
	rigid.physics_material_override.bounce = 0.025
	world.add_child(rigid)
	for segment in [[Vector2(695,566),Vector2(732,599)],[Vector2(732,599),Vector2(884,599)],[Vector2(884,599),Vector2(925,566)]]:
		var a: Vector2 = (segment[0] - PIVOT) * ART_SCALE
		var b: Vector2 = (segment[1] - PIVOT) * ART_SCALE
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(a.distance_to(b) + 4, 7)
		shape.position = (a + b) * 0.5
		shape.rotation = (b-a).angle()
		rigid.add_child(shape)
	for side in [-1.0,1.0]:
		var seat := CollisionShape2D.new()
		seat.shape = RectangleShape2D.new()
		seat.shape.size = Vector2(18,4)
		seat.position = Vector2(side*151, -15.4)
		rigid.add_child(seat)
	# A dedicated counter support avoids the food's perspective-plane collision.
	var support := StaticBody2D.new()
	support.collision_layer = 128
	support.collision_mask = 64 | 256
	var surface := CollisionShape2D.new()
	surface.shape = RectangleShape2D.new()
	surface.shape.size = Vector2(1580, 14)
	surface.position = Vector2(800, PIVOT.y + HOME.y + 10.5)
	support.add_child(surface)
	world.add_child(support)
	for wall in world._pan_walls:
		wall.collision_layer = 0
		wall.collision_mask = 0
	rigid.freeze = not world.controls_enabled

func on_stove() -> bool:
	return absf(offset.x - HOME.x) < 45 and absf(offset.y - HOME.y) < 8 and absf(angle) < 0.16 and not active and not falling

func under_tap() -> bool:
	return above_sink() and absf(angle) < 0.45 and point(Vector2(810,550)).y > 568 and (not is_instance_valid(lid) or not lid.covered)

func above_sink() -> bool:
	return absf(809 + offset.x - SINK_X) < 70 and absf(offset.y - HOME.y) < 30

func _process(_delta: float) -> void:
	pan_back.queue_redraw()
	pan_front.queue_redraw()
	pan_surface.queue_redraw()
	faucet_art.queue_redraw()

func _input(event: InputEvent) -> void :
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and faucet_dragging:
		faucet_dragging = false
		world.audio.play_effect("tap")
		world.interaction.emit("notice", "水龙头已转开，把锅放在水流下接水。" if faucet_on else "水龙头已回转关闭。")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and faucet_dragging:
		var faucet_pointer: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
		faucet_amount = clampf(_faucet_drag_start_amount + (faucet_pointer.y - _faucet_drag_start_y) / 62.0, 0.0, 1.0)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and active:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_tipping = event.pressed
			get_viewport().set_input_as_handled()
			return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			set_angle(angle + deg_to_rad(15) * (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1))
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
		if not event.pressed and active:
			move_pointer(p)
			release_pan()
			get_viewport().set_input_as_handled()
		elif event.pressed and world.controls_enabled and not is_instance_valid(world._held) and not world._knife_held and not world.has_active_utensil():
			if preload("res://modules/restaurant/world/sink_faucet.gd").HANDLE_RECT.has_point(p):
				faucet_dragging = true
				_faucet_drag_start_y = p.y
				_faucet_drag_start_amount = faucet_amount
				world.interaction.emit("notice", "按住把手向下转开，向上回转关闭。")
				get_viewport().set_input_as_handled()
			elif Rect2(80, 748, 270, 32).has_point(p) and under_tap():
				draining = not draining
				world.interaction.emit("notice", "正在缓缓倒水；再点一下停止。" if draining else "停止倒水。")
				get_viewport().set_input_as_handled()
			elif can_grab(p):
				grab(p)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and active:
		move_pointer(world.get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and active and event.pressed:
		if event.physical_keycode in [KEY_Q, KEY_ESCAPE]: release_pan()
		elif event.physical_keycode in [KEY_A, KEY_D]:
			set_angle(angle + deg_to_rad(15) * (1 if event.physical_keycode == KEY_D else -1))
			get_viewport().set_input_as_handled()

func transform_pan() -> Transform2D:
	var basis: = Transform2D(angle, ART_SCALE, 0, Vector2.ZERO)
	basis.origin = PIVOT + offset - basis * PIVOT
	return basis

func point(base_point: Vector2) -> Vector2:
	return transform_pan() * base_point

func local_point(p: Vector2) -> Vector2:
	return transform_pan().affine_inverse() * p

func contains(p: Vector2) -> bool:
	return Rect2(696, 546, 231, 102).has_point(local_point(p))

func can_grab(p: Vector2) -> bool:
	var local: = local_point(p)
	# The handle artwork is behind loose food. Its generous grab rectangle must
	# not intercept an opaque food pixel that the player can visibly pick up.
	if Rect2(925, 561, 173, 35).has_point(local): return world._food_at(p) == null
	var geometry := preload("res://modules/restaurant/world/pan_geometry.gd")
	var rim: = (local - geometry.CENTER) / geometry.RADIUS
	return rim.length() > 0.86 and rim.length() < 1.12 and world._food_at(p) == null

func grab(p: Vector2) -> void:
	active = true
	falling = false
	_tipping = false
	_pointer = p
	_grab_point = local_point(p)
	grip.begin(rigid, world.to_global(p))
	world.held_changed.emit("平底锅")
	world.focus_changed.emit("平底锅", "轻提锅柄再移动 · 右键缓缓倾倒 · 松手保留惯性")

func move_pointer(p: Vector2) -> void:
	_pointer = p
	grip.target = world.to_global(p.clamp(Vector2(35,150), Vector2(1565,775)))

func move_to(destination: Variant) -> void:
	# Explicit placement API for initialisation/fixtures, never pointer motion.
	var desired: Vector2 = destination if destination is Vector2 else Vector2(float(destination), 0)
	offset = desired.clamp(Vector2(-650,-520),Vector2(610,150))
	rigid.position = PIVOT + offset
	rigid.rotation = angle
	rigid.reset_physics_interpolation()
	_sync_pose()

func _sync_pose() -> void:
	var pose := transform_pan()
	pan_back.transform = pose
	pan_front.transform = pose
	pan_surface.transform = pose
	world._pan_area.transform = Transform2D(angle, ART_SCALE, 0, point(PIVOT))
	for wall in world._pan_walls: wall.transform = pose # inactive compatibility geometry
	world._stations["cook"] = pose * Rect2(677,535,265,125)
	world._update_landed_seasoning()

func set_angle(value: float) -> void:
	grip.target_angle = clampf(value, deg_to_rad(-125), deg_to_rad(125))

func release_pan() -> void:
	if not active: return
	active = false
	_tipping = false
	grip.release()
	falling = rigid.linear_velocity.length() > 8 or offset.y < HOME.y - 8
	world.held_changed.emit("")

func _physics_process(delta: float) -> void:
	if not world.controls_enabled:
		if not rigid.freeze:
			_paused_velocity = rigid.linear_velocity
			_paused_spin = rigid.angular_velocity
			rigid.freeze = true
		return
	if rigid.freeze:
		rigid.freeze = false
		rigid.linear_velocity = _paused_velocity
		rigid.angular_velocity = _paused_spin
	rigid.mass = Tuning.number("pan","tare_kg") + (water_ml + rim_water_ml) / 1000.0
	rigid.inertia = rigid.mass * Tuning.number("pan","inertia_per_kg")
	if active:
		if _tipping: set_angle(move_toward(grip.target_angle, deg_to_rad(110), delta * 0.85))
		grip.apply(rigid, delta)
	offset = rigid.position - PIVOT
	angle = rigid.rotation
	var was_falling := falling
	falling = not active and (rigid.linear_velocity.length() > 12.0 or offset.y < HOME.y - 8.0)
	if was_falling and not falling: world.audio.play_effect("pan", clampf(_last_velocity.length()/180.0,0.2,1.0))
	var acceleration := (rigid.linear_velocity - _last_velocity) / maxf(delta, 0.001)
	_last_velocity = rigid.linear_velocity
	var target_slosh := clampf(-acceleration.x / 980.0, -0.6, 0.6)
	slosh_velocity += (target_slosh - slosh) * 45.0 * delta - slosh_velocity * 8.0 * delta
	slosh += slosh_velocity * delta
	_sync_pose()
	advance_water(delta)
	_toss_sound_left = maxf(0.0, _toss_sound_left - delta)
	for food in world._foods.get_children():
		# A sound follows a real airborne relative velocity; it never launches food.
		if active and _toss_sound_left <= 0.0 and food.get_meta("enrolled", false) and food.linear_velocity.y - rigid.linear_velocity.y < -70.0 and food.get_contact_count() == 0:
			world.audio.play_effect("toss", clampf(absf(food.linear_velocity.y-rigid.linear_velocity.y)/280.0, 0.2, 0.8))
			_toss_sound_left = 0.4
		if food.get_meta("enrolled",false) and not contains(food.position) and absf(angle)>0.3: food.set_meta("poured",true)

func advance_water(dt: float) -> void:
	outflow_ml_s = 0.0
	if faucet_on and under_tap():
		if is_empty_for_cleaning(): residue.waste_kg += residue.wipe(dt * 0.00018 * faucet_amount)
		var incoming := dt * Tuning.number("liquid","tap_ml_s") * faucet_amount
		water_input_ml += incoming
		water_heat = (water_heat * water_ml + 22.0 * incoming) / maxf(water_ml + incoming,0.000001)
		water_ml += incoming
	elif faucet_on:
		var incoming := dt * Tuning.number("liquid","tap_ml_s") * faucet_amount
		water_input_ml += incoming
		runoff.emit_water(incoming, Vector2(200,700))
	var over_capacity: float = maxf(0.0, world.pan_contents_ml() - world.PAN_CAPACITY_ML)
	var displaced := minf(water_ml,over_capacity)
	water_ml -= displaced
	rim_water_ml += displaced
	# Tilt reduces the volume below the low rim continuously, not at one angle.
	var tilt := sin(clampf(absf(wrapf(angle, -PI, PI)) - 0.015, 0.0, PI * 0.5))
	var solid_ml: float = maxf(0.0, world.pan_contents_ml() - water_ml)
	var capacity: float = maxf(0.0, world.PAN_CAPACITY_ML * pow(maxf(0.0,1.0-tilt),1.35) - solid_ml)
	capacity *= 1.0 - minf(0.18, absf(slosh) * 0.12)
	var excess := maxf(0.0, water_ml - capacity)
	var flow := minf(water_ml, excess * (1.0 - exp(-dt * Tuning.number("liquid","rim_drain_rate"))))
	if draining:
		if above_sink(): flow = minf(water_ml, flow + 280.0 * dt)
		else: draining = false
	water_ml -= flow
	var rim_out := rim_water_ml * (1.0-exp(-dt*Tuning.number("liquid","rim_drain_rate")))
	rim_water_ml -= rim_out
	flow += rim_out
	if flow > 0.0:
		outflow_ml_s = flow / dt
		overflow_water_ml += flow
		var side := -1.0 if angle < -0.02 else 1.0
		var rim: Vector2 = faucet_art.overflow_path(side)[1]
		runoff.emit_water(flow, rim, rigid.linear_velocity * 0.35 + Vector2(side * 22, 0))
	overflowing = outflow_ml_s > 0.01
	if water_ml < 0.001: draining = false

func _land() -> void:
	falling = false

func is_carrying(body: Node) -> bool:
	return (active or falling) and is_instance_valid(body) and contains(body.position) and body.get_meta("enrolled",false)

func transporting() -> bool:
	return active or falling

func suspend() -> void:
	release_pan()
	faucet_dragging = false
	# Pause preserves water and velocities; no instantaneous landing/emptying.

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_instance_valid(world):
		suspend()
		faucet_on = false
