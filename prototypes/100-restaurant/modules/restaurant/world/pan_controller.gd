extends Node2D

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
var overflowing := false
var faucet_amount: = 0.0
var faucet_on: bool:
	get: return faucet_amount >= 0.45
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
var _last_toss_msec := 0
var _last_motion_msec := 0
var pan_back: Node2D
var pan_front: Node2D
var pan_surface: Node2D
var faucet_art: Node2D
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

func on_stove() -> bool:
	return absf(offset.x - HOME.x) < 45 and absf(offset.y - HOME.y) < 4 and absf(angle) < 0.1 and not active and not falling

func under_tap() -> bool:
	return above_sink() and absf(angle) < 0.1 and not active and not falling

func above_sink() -> bool:
	return absf(809 + offset.x - SINK_X) < 70 and absf(offset.y - HOME.y) < 30

func _process(delta: float) -> void :
	var was_overflowing := overflowing
	overflowing = false
	if world.controls_enabled:
		if active and _tipping: set_angle(move_toward(angle, deg_to_rad(110), delta * 3.8))
		if faucet_on and under_tap() and not world.lid.covered:
			if is_empty_for_cleaning(): residue.waste_kg += residue.wipe(delta * 0.00018 * faucet_amount)
			var incoming := delta * 180.0 * faucet_amount
			var accepted: float = minf(incoming, world.pan_free_ml())
			if accepted > 0.0:
				water_heat = (water_heat * water_ml + 22.0 * accepted) / (water_ml + accepted)
				water_ml += accepted
			var runoff := incoming - accepted
			if runoff > 0.0001:
				overflowing = true
				overflow_water_ml += runoff
				world.receive_faucet_runoff(runoff)
				if not was_overflowing:
					world.interaction.emit("notice", "锅已经满了，继续流出的水正沿锅沿落进水槽。请关上水龙头。")
		elif faucet_on:
			world.receive_faucet_runoff(delta * 180.0 * faucet_amount)
		# Fixed-step CookingReactions owns heat exchange and evaporation.
	pan_back.queue_redraw()
	pan_front.queue_redraw()
	pan_surface.queue_redraw()
	faucet_art.queue_redraw()
	queue_redraw()

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
				world.receive_faucet_runoff(water_ml)
				water_ml = 0
				water_heat = 0
				overflow_water_ml = 0
				world.audio.play_effect("drain")
				world.interaction.emit("notice", "锅中的水倒入了水槽。")
				get_viewport().set_input_as_handled()
			elif can_grab(p):
				grab(p)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and active:
		var pointer: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
		var travel := pointer - _pointer
		var now := Time.get_ticks_msec()
		var quick := now - _last_motion_msec <= 150
		move_pointer(pointer)
		if quick and travel.y < -28.0 and absf(travel.x) < 100.0:
			_toss_contents(travel, now)
		_last_motion_msec = now
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
	if Rect2(925, 561, 173, 35).has_point(local): return true
	var geometry := preload("res://modules/restaurant/world/pan_geometry.gd")
	var rim: = (local - geometry.CENTER) / geometry.RADIUS
	return rim.length() > 0.86 and rim.length() < 1.12 and world._food_at(p) == null

func grab(p: Vector2) -> void :
	active = true
	falling = false
	_fall_speed = 0
	_tipping = false
	_pointer = p
	_last_motion_msec = Time.get_ticks_msec()
	_grab_point = local_point(p)
	_carried.clear()
	for body in world._foods.get_children():
		if body.get_meta("enrolled", false) and not body.get_meta("plated", false) and contains(body.position):
			_carried.append(body)
			body.set_meta("pan_origin", local_point(body.position))
			body.set_meta("pan_rotation", body.rotation - angle)
			body.freeze = true
	world.held_changed.emit("平底锅")
	world.focus_changed.emit("平底锅", "靠近炉灶向上轻甩可翻炒 · 右键倾倒 / 滚轮调角度 · 松手落下")

func move_pointer(p: Vector2) -> void :
	_pointer = p
	move_to(p - PIVOT - ((_grab_point - PIVOT) * ART_SCALE).rotated(angle))

func move_to(destination: Variant) -> void :

	var desired: Vector2 = destination if destination is Vector2 else Vector2(float(destination), 0)
	offset = desired.clamp(Vector2(-650, -520), Vector2(610, 150))
	_last_transport = Time.get_ticks_msec()
	var pose: = transform_pan()
	pan_back.transform = pose
	pan_front.transform = pose
	pan_surface.transform = pose
	world._pan_area.transform = Transform2D(angle, ART_SCALE, 0, point(PIVOT))
	for wall in world._pan_walls: wall.transform = pose
	for body in _carried:
		if is_instance_valid(body):
			var target: = point(body.get_meta("pan_origin"))
			body.position = target
			body.set_deferred("position", target)
			body.rotation = float(body.get_meta("pan_rotation", 0)) + angle
	world._stations["cook"] = pose * Rect2(677, 535, 265, 125)
	world._update_landed_seasoning()
	if is_instance_valid(world.lid): world.lid._sync_pose()

func set_angle(value: float) -> void :
	var was_below_pour_angle := absf(angle) < deg_to_rad(85)
	angle = clampf(value, deg_to_rad(-125), deg_to_rad(125))
	move_pointer(_pointer)
	if absf(angle) >= deg_to_rad(85) and world.lid.covered:
		world.lid.open_lid()
		world.lid.rest_lid()
		world.interaction.emit("notice", "锅倾斜太多，锅盖滑回了台面。")
	if absf(angle) >= deg_to_rad(85):
		if was_below_pour_angle and water_ml > 0.0:
			var poured_ml := water_ml
			water_ml = 0.0
			water_heat = 0.0
			if above_sink():
				world.receive_faucet_runoff(poured_ml)
				world.audio.play_effect("drain")
				world.interaction.emit("notice", "锅里的水顺着低侧锅沿倒进了水槽。")
			else:
				overflow_water_ml += poured_ml
				world.spill_pan_water(poured_ml, point(Vector2(810, 610)) + Vector2(0, 48))
				world.audio.play_effect("pour")
		for body in _carried:
			if not is_instance_valid(body): continue
			body.freeze = false
			body.sleeping = false
			body.linear_velocity = Vector2.ZERO
			body.set_meta("poured", true)
		_carried.clear()

func _toss_contents(travel: Vector2, now: int) -> int:
	if world.lid.covered:
		world.lid.agitate(travel.length())
		world.audio.play_effect("pan", 0.55)
		return 0
	# A short upward pan motion releases only food actually supported by the pan.
	# The rigid bodies then fly and land through Godot physics; no food is replaced.
	if not active or now - _last_toss_msec < 650 or absf(angle) > 0.16:
		return 0
	if absf(offset.x - HOME.x) > 85.0 or absf(offset.y - HOME.y) > 110.0 or water_ml > 120.0:
		return 0
	var launched := 0
	var still_carried: Array = []
	for body in _carried:
		if not is_instance_valid(body): continue
		if body.has_meta("liquid_state") or body.get_meta("plated", false):
			still_carried.append(body)
			continue
		body.freeze = false
		body.sleeping = false
		var sideways := clampf(travel.x * 5.0, -110.0, 110.0) + float((launched % 3) - 1) * 28.0
		var upward := clampf(-travel.y * 7.0, 220.0, 390.0) + float(launched % 3) * 17.0
		body.linear_velocity = Vector2(sideways, -upward)
		body.angular_velocity = (1.0 if sideways >= 0.0 else -1.0) * (2.2 + float(launched % 3) * 0.5)
		body.set_meta("stir_until", world._time + 0.9)
		world.reactions.stir(body, travel.length(), true)
		world.audio.play_food_stir(body, "black", travel.length())
		launched += 1
	_carried = still_carried
	if launched > 0:
		world.audio.play_effect("toss", clampf(float(launched) / 3.0, 0.45, 1.0))
		_last_toss_msec = now
		world.interaction.emit("notice", "轻甩翻炒：%d 块食材离锅、翻面，再落回锅中。" % launched)
	return launched

func release_pan() -> void :
	if not active: return
	active = false
	_tipping = false
	angle = 0
	move_to(Vector2(offset.x, minf(offset.y, HOME.y)))
	falling = offset.y < HOME.y
	_fall_speed = 0
	if not falling: _land()
	world.held_changed.emit("")

func _physics_process(delta: float) -> void :
	if not world.controls_enabled: return
	if active:
		for body in _carried:
			if is_instance_valid(body):
				body.position = point(body.get_meta("pan_origin"))
				body.set_deferred("position", body.position)
	if falling:
		_fall_speed += 1000 * delta
		move_to(offset + Vector2(0, _fall_speed * delta))
		if offset.y >= HOME.y:
			move_to(Vector2(offset.x, HOME.y))
			_land()

func _land() -> void :
	falling = false
	_last_transport = Time.get_ticks_msec()
	for body in _carried:
		if is_instance_valid(body):
			body.position = point(body.get_meta("pan_origin"))
			body.set_deferred("position", body.position)
			body.freeze = false
			body.sleeping = false
	_carried.clear()
	world.audio.play_effect("pan")

func is_carrying(body: Node) -> bool:
	return _carried.has(body)

func transporting() -> bool:
	return active or falling or Time.get_ticks_msec() - _last_transport < 100

func suspend() -> void :
	release_pan()
	if falling:
		move_to(Vector2(offset.x, HOME.y))
		_land()
	faucet_on = false
	overflowing = false
	faucet_dragging = false

func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_instance_valid(world): suspend()

func _draw() -> void :
	pass

func _box(color: Color) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	return style
