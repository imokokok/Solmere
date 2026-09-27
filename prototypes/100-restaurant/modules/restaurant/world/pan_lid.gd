extends Node2D
const Tuning=preload("res://modules/restaurant/domain/physical_tuning.gd")
## A loose lid, not a sealed pressure vessel. Effective pressure/area are tuned
## 2D proxies; motion, contacts, angular inertia and gravity use native bodies.
const Geometry = preload("res://modules/restaurant/world/pan_geometry.gd")
const HOME := Vector2(1216,554)
const REST_ANGLE := -1.12
const REST_SCALE := Vector2(0.68,0.9)
var world: Node2D
var rigid: RigidBody2D
var grip = preload("res://modules/restaurant/world/physical_grip.gd").new()
var parked := true
var covered := false
var active := false
var pressure_pa := 0.0
var pressure: float:
	get: return pressure_pa / 300.0
	set(value): pressure_pa = maxf(0.0,value*300.0)
var gap := 0.0
var steam_ml := 0.0
var received_steam_ml := 0.0
var escaped_steam_ml := 0.0
var condensed_ml := 0.0
var burst_count := 0
var burst_left := 0.0
var burst_origin := Vector2.ZERO
var _flight := false
var _settling := 0.0
var _velocity := Vector2.ZERO
var _previous_velocity := Vector2.ZERO
var _step_seconds := 1.0/120.0
var _release_duration := 0.0
var _rattle_clock := 0.0
var _hot_seconds := 0.0
var _pop_cooldown := 0.0
var _paused := false
var _paused_spin := 0.0
var _vapor_rate := 0.0
var _stand: Node2D
var _atmosphere: Node2D
var _shadow: Node2D
var _paint_target: Node2D
var _shape: CollisionShape2D

func _ready() -> void:
	z_index = 34
	_stand = Node2D.new()
	_stand.position = HOME + Vector2(0,104)
	_stand.z_index = 33
	world.add_child(_stand)
	_stand.draw.connect(_draw_stand)
	_atmosphere = Node2D.new()
	_atmosphere.z_index = 32
	world.add_child(_atmosphere)
	_atmosphere.draw.connect(_paint_atmosphere)
	_shadow = Node2D.new()
	_shadow.z_index = 3
	world.add_child(_shadow)
	_shadow.draw.connect(_draw_flight_shadow)
	rigid = RigidBody2D.new()
	rigid.name = "PhysicalLid"
	rigid.mass = Tuning.number("lid","mass_kg")
	rigid.inertia = rigid.mass*Tuning.number("lid","inertia_per_kg")
	rigid.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	rigid.contact_monitor = true
	rigid.max_contacts_reported = 8
	rigid.linear_damp = 0.35
	rigid.angular_damp = 1.4
	rigid.physics_material_override = PhysicsMaterial.new()
	rigid.physics_material_override.friction = 0.5
	rigid.physics_material_override.bounce = 0.12
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	_shape.shape.size = Vector2(322,6)
	# Side-view collision sits on the rear upper lip; painted dome projects below it.
	_shape.position = Vector2(0,-25.0)
	rigid.add_child(_shape)
	world.add_child(rigid)
	rest_lid()

func hit(point: Vector2) -> bool:
	return ((to_local(world.to_global(point))-Vector2(0,-11))/Vector2(165,72)).length()<=1.0

func blocks(point: Vector2) -> bool:
	return covered and ((world.pan.local_point(point)-Geometry.CENTER)/(Geometry.RADIUS+Vector2(5,8))).length()<=1.12

func close_lid() -> bool:
	if world.pan.active or world.pan.falling or world.has_active_utensil() or is_instance_valid(world._held) or world._knife_held: return false
	# Placement helper for scripted setup. Mouse release never invokes this snap.
	parked=false
	active=false
	rigid.freeze=false
	rigid.position=world.pan.point(Geometry.CENTER)-Vector2(0,8)
	rigid.rotation=world.pan.angle
	rigid.linear_velocity=world.pan.rigid.linear_velocity
	rigid.angular_velocity=world.pan.rigid.angular_velocity
	covered=true
	_set_collision()
	_sync_pose()
	return true

func open_lid(vent := true) -> void:
	_vapor_rate = 0.0
	if not covered: return
	var had_steam := steam_ml > 0.0001 or pressure_pa > 20.0
	covered=false
	pressure_pa=0.0
	escaped_steam_ml+=steam_ml
	steam_ml=0.0
	_hot_seconds=0.0
	burst_origin=position
	if vent:
		if had_steam:
			_start_release(0.95)
			world.audio.play_effect("steam_release",0.35)
		else: world.audio.play_effect("lid_close",0.3)

func _start_release(seconds: float) -> void:
	_release_duration=seconds
	burst_left=seconds

func display_transform() -> Transform2D:
	return transform

func _sync_pose() -> void:
	position=rigid.position
	rotation=rigid.rotation
	scale=REST_SCALE if parked else Vector2.ONE
	queue_redraw()

func _set_collision() -> void:
	rigid.collision_layer=0 if parked else 256
	rigid.collision_mask=0 if parked else 64|128|16|512

func _process(_dt: float) -> void:
	_sync_pose()
	_atmosphere.queue_redraw()
	_shadow.queue_redraw()

func _physics_process(dt: float) -> void:
	if not world.controls_enabled:
		if not _paused:
			_velocity=rigid.linear_velocity
			_paused_spin=rigid.angular_velocity
			_paused=true
			rigid.freeze=true
		return
	if _paused:
		_paused=false
		rigid.freeze=parked
		rigid.linear_velocity=_velocity
		rigid.angular_velocity=_paused_spin
	_set_collision()
	if parked: return
	rigid.freeze=false
	if active: grip.apply(rigid,dt)
	var seat: Vector2=world.pan.point(Geometry.CENTER)
	gap=maxf(0.0,seat.y-rigid.position.y)
	var was_covered:=covered
	covered=not active and absf(seat.x-rigid.position.x)<45 and absf(wrapf(rigid.rotation-world.pan.angle,-PI,PI))<0.2 and absf(seat.y-rigid.position.y)<24
	var boiling: float=world.reactions.water_activity()
	_vapor_rate *= exp(-dt * 8.0)
	var source:=minf(1100.0,(_vapor_rate*180.0+boiling*1100.0)) if covered else 0.0
	var vent:=1.8+gap*2.4+(0.0 if covered else 35.0)
	pressure_pa=maxf(0.0,(pressure_pa+source*dt)/(1.0+vent*dt))
	if covered:
		var upward:=rigid.mass*980.0*pressure_pa/Tuning.number("lid","lift_pressure_proxy")
		rigid.apply_central_force(Vector2(0,-upward))
		rigid.apply_torque(sin(world._time*19.0)*upward*3.0)
		if pressure_pa>100: rigid.sleeping=false
		_hot_seconds+=dt if boiling>0.6 and pressure_pa>15 and world.cooking else -dt*0.5
	else: _hot_seconds=maxf(0.0,_hot_seconds-dt*0.5)
	_hot_seconds=maxf(0.0,_hot_seconds)
	_pop_cooldown=maxf(0.0,_pop_cooldown-dt)
	if _hot_seconds>Tuning.number("lid","pop_after_hot_seconds") and _pop_cooldown<=0.0: burst()
	_rattle_clock=maxf(0.0,_rattle_clock-dt)
	var contact:=rigid.get_contact_count()>0
	if contact and _previous_velocity.y>12 and rigid.linear_velocity.y<4 and _rattle_clock<=0:
		var sound := "lid_tick" if covered else ("lid_rebound" if world.audio.effects.lid_land.playing else "lid_land")
		world.audio.play_effect(sound,clampf(_previous_velocity.y/180.0,0.2,0.85))
		_rattle_clock=0.18
	if covered and not was_covered: world.audio.play_effect("lid_close",0.4)
	_previous_velocity=rigid.linear_velocity
	_velocity=rigid.linear_velocity
	_flight=not active and not contact and rigid.linear_velocity.length()>12
	_sync_pose()

func advance(dt: float, vapor_ml: float, _temperature: float, _moist_food: bool) -> void:
	# The thermal owner is the only source of captured/condensed water.
	_step_seconds=dt
	burst_left=maxf(0.0,burst_left-dt)
	_vapor_rate=lerpf(_vapor_rate,vapor_ml/maxf(dt,0.000001),1.0-exp(-dt*8.0))
	if covered:
		received_steam_ml+=vapor_ml
		steam_ml+=vapor_ml
	var condensed:=minf(steam_ml*(1.0-exp(-dt*0.08)),world.pan_free_ml()) if covered else 0.0
	steam_ml-=condensed
	condensed_ml+=condensed
	if condensed>0:
		world.pan.water_heat=(world.pan.water_heat*world.pan.water_ml+85*condensed)/(world.pan.water_ml+condensed)
		world.pan.water_ml+=condensed
	var vent:=0.045+gap*0.08+(0.0 if covered else 12.0)
	var escaped:=steam_ml*(1.0-exp(-dt*vent))
	steam_ml-=escaped
	escaped_steam_ml+=escaped

func agitate(_distance: float) -> void:
	# Pan contacts supply momentum. Shaking never creates pressure or water.
	pass

func burst() -> void:
	if not covered: return
	burst_count+=1
	var pressure_before:=pressure_pa
	open_lid(false)
	parked=false
	_pop_cooldown=8.0
	burst_origin=rigid.position
	_start_release(1.8)
	rigid.sleeping=false
	# Bounded steam surge acts on this lid only, without aiming for the rack.
	rigid.apply_central_impulse(Vector2(0,-rigid.mass*clampf(pressure_before*1.6,180,320)))
	rigid.apply_torque_impulse(rigid.inertia*0.32)
	_flight=true
	world.audio.play_effect("lid_pop",0.6)
	world.audio.play_effect("steam_release",0.65)
	world.interaction.emit("notice","蒸汽顶开了锅盖！调小火力，等盖子落稳再拿。")

func rest_lid() -> void:
	open_lid(false)
	parked=true
	active=false
	covered=false
	grip.release()
	rigid.freeze=true
	rigid.position=HOME
	rigid.rotation=REST_ANGLE
	rigid.linear_velocity=Vector2.ZERO
	rigid.angular_velocity=0.0
	_flight=false
	_set_collision()
	_sync_pose()

func suspend() -> void:
	if active:
		active=false
		grip.release()
		world.held_changed.emit("")

func _input(event: InputEvent) -> void:
	if not world.controls_enabled: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		var pointer: Vector2=world.get_global_transform_with_canvas().affine_inverse()*event.position
		if not event.pressed and active:
			active=false
			grip.release()
			world.held_changed.emit("")
			get_viewport().set_input_as_handled()
		elif event.pressed and hit(pointer) and not world.pan.active and not world.has_active_utensil() and not world._knife_held and not is_instance_valid(world._held):
			open_lid()
			parked=false
			active=true
			rigid.freeze=false
			grip.begin(rigid,world.to_global(pointer))
			grip.target_angle=0.0
			world.held_changed.emit("锅盖")
			world.focus_changed.emit("锅盖","提住盖钮，移到锅口轻放 · Q 收回架子")
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and active:
		grip.target=world.to_global((world.get_global_transform_with_canvas().affine_inverse()*event.position).clamp(Vector2(160,180),Vector2(1450,750)))
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and active and event.pressed and event.physical_keycode in [KEY_Q,KEY_ESCAPE]:
		rest_lid()
		world.held_changed.emit("")
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and active: suspend()

func _exit_tree() -> void:
	for node in [rigid,_stand,_atmosphere,_shadow]:
		if is_instance_valid(node): node.queue_free()

func _draw_stand() -> void:
	_stand.draw_style_box(_stand_style(), Rect2(-59, -8, 118, 15))
	_stand.draw_line(Vector2(-36, -3), Vector2(-18, -25), Color("788574"), 5.0, true)
	_stand.draw_line(Vector2(34, -3), Vector2(22, -25), Color("788574"), 5.0, true)

func _stand_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("7c8876")
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0.2, 0.23, 0.17, 0.22)
	style.shadow_size = 3
	return style

func _ellipse(center: Vector2, radius: Vector2, color: Color, line := false) -> void:
	var points := PackedVector2Array()
	for i in 65: points.append(center + Vector2(cos(i * TAU / 64.0), sin(i * TAU / 64.0)) * radius)
	if line: _paint_target.draw_polyline(points, color, 2.3, true)
	else: _paint_target.draw_colored_polygon(points, color)

func _draw() -> void:
	draw_set_transform_matrix(transform.affine_inverse() * display_transform())
	paint(self)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func paint(target: Node2D) -> void:
	_paint_target = target
	# Match the pan mouth projection and preserve the existing warm painted palette.
	_ellipse(Vector2(3, 9), Vector2(161, 54), Color(0.18, 0.21, 0.18, 0.19))
	_ellipse(Vector2.ZERO, Vector2(161, 53), Color("454f47"))
	_ellipse(Vector2(0, -8), Vector2(157, 54), Color("bbc2ad"))
	_ellipse(Vector2(0, -13), Vector2(150, 51), Color("d6dbc1"))
	_ellipse(Vector2(0, -15), Vector2(137, 44), Color("e8e7cf"))
	_ellipse(Vector2(0, -9), Vector2(155, 53), Color("657d6b"), true)
	for i in 7:
		var x := -92.0 + i * 28.0
		_paint_target.draw_line(Vector2(x, -20), Vector2(x + 10, -23), Color(0.95, 0.96, 0.88, 0.21), 1.0, true)
	_ellipse(Vector2(0, -18), Vector2(34, 11), Color(0.21, 0.28, 0.22, 0.18))
	_paint_target.draw_style_box(_knob_style(), Rect2(-27, -42, 54, 23))
	_paint_target.draw_line(Vector2(-17, -37), Vector2(14, -37), Color("879083"), 3.0, true)
	if covered:
		var fog := clampf(steam_ml / 4.0, 0.0, 1.0)
		for i in 9:
			var p := Vector2(sin(i * 4.1) * 113, cos(i * 5.3) * 28 - 8)
			_paint_target.draw_circle(p, 2.0 + fog * 1.2, Color(0.97, 0.98, 0.93, fog * 0.65))
		if pressure > 0.1:
			for side in [-1, 1]: _steam(Vector2(side * 149, -1), pressure, false)

func _paint_atmosphere() -> void:
	_paint_target = _atmosphere
	if burst_left > 0.0:
		var interpolation := _step_seconds * (1.0 - Engine.get_physics_interpolation_fraction()) if world.controls_enabled else 0.0
		var age := maxf(0.0, _release_duration - burst_left - interpolation)
		for i in 9:
			var t := maxf(0.0, age - float(i % 3) * 0.045)
			var life := _release_duration - float(i % 3) * 0.045
			var envelope := smoothstep(0.0, 0.11, t) * pow(maxf(0.0, 1.0 - t / life), 1.4)
			var spread := 1.0 - exp(-t * 4.5)
			var center := burst_origin + Vector2((i - 4) * (8.0 + spread * 25.0) + sin(t * 2.2 + i) * t * 6.0, -t * (56.0 + (i % 3) * 19.0))
			var radius := Vector2(9.0 + spread * 21.0 + t * 10.0, 7.0 + spread * 12.0 + t * 8.0)
			_world_puff(center + Vector2(3, 4), radius * 1.08, Color(0.76, 0.79, 0.67, envelope * 0.12), float(i))
			_world_puff(center, radius, Color(0.96, 0.94, 0.83, envelope * 0.34), float(i))
	# Smoke is driven by actual char/temperature, remains visible with the lid off.
	if world.reactions == null: return
	for body in world._foods.get_children():
		if not body is RigidBody2D or body.is_queued_for_deletion() or not body.get_meta("enrolled", false) or body.get_meta("plated", false) or not world.pan.contains(body.position): continue
		var s: Dictionary = body.get_meta("thermal", {})
		if s.is_empty(): continue
		var charred := maxf(float(s.char[0]), float(s.char[1]))
		var strength := smoothstep(0.12, 0.65, charred) * smoothstep(110.0, 180.0, maxf(float(s.faces_c[0]), float(s.faces_c[1])))
		if strength > 0.01:
			var source: Vector2 = world.pan.point(Vector2(930, 573)) if covered else body.position
			_smoke(source, strength)

func _draw_flight_shadow() -> void:
	if not _flight and _settling <= 0.0: return
	var height := clampf((714.0 - display_transform().origin.y) / 300.0, 0.0, 1.0)
	var center := Vector2(display_transform().origin.x + 8.0, 720.0)
	var points := PackedVector2Array()
	for i in 49:
		points.append(center + Vector2(cos(i * TAU / 48.0), sin(i * TAU / 48.0)) * Vector2(lerpf(54.0, 28.0, height), lerpf(8.0, 4.0, height)))
	_shadow.draw_colored_polygon(points, Color(0.25, 0.25, 0.18, lerpf(0.16, 0.035, height)))

func _knob_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("4d574c")
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.18, 0.23, 0.18, 0.25)
	style.shadow_size = 3
	return style

func _steam(origin: Vector2, strength: float, pop: bool) -> void:
	for i in 3:
		var rise := fmod(world._time * 0.6 + i / 3.0 + origin.x * 0.013, 1.0)
		var points := PackedVector2Array()
		for j in 12: points.append(origin + Vector2(sin(j * 0.55 + world._time * 2.0 + i) * (3.0 + rise * 7.0), -j * 3.0 - rise * 35.0))
		_paint_target.draw_polyline(points, Color(0.96, 0.94, 0.83, strength * pow(sin(rise * PI), 2.0) * 0.35), 2.0, true)

func _smoke(origin: Vector2, strength: float) -> void:
	for i in 3:
		var rise := fmod(world._time * 0.36 + i * 0.33, 1.0)
		var point := origin + Vector2(sin(rise * 5.0 + i) * 15.0, -12.0 - rise * 88.0)
		_world_puff(point, Vector2(9.0 + rise * 19.0, 5.0 + rise * 10.0), Color(0.27, 0.26, 0.23, strength * (1.0 - rise) * 0.28))

func _world_puff(center: Vector2, radius: Vector2, color: Color, seed := 0.0) -> void:
	var points := PackedVector2Array()
	for i in 49:
		var angle := i * TAU / 48.0
		var edge := 1.0 + sin(angle * 3.0 + seed) * 0.055 + cos(angle * 5.0 + seed * 1.7) * 0.035
		var p := center + Vector2(cos(angle), sin(angle)) * radius * edge
		points.append(_paint_target.to_local(world.to_global(p)))
	_paint_target.draw_colored_polygon(points, color)

