extends Node2D
const Tuning=preload("res://modules/restaurant/domain/physical_tuning.gd")

const SauceState = preload("res://modules/restaurant/domain/sauce_state.gd")
const HOME: = Vector2(600, 493)
const PAN: = Rect2(704, 550, 222, 100)
var world: Node2D
var active: = false
var releasing := false
var _release_elapsed := 0.0
var docked := true
var storing := false
var _store_elapsed := 0.0
var _store_origin := Vector2.ZERO
var _store_angle := 0.0
const CUP_MOUTH := Rect2(543, 480, 105, 151)
var kind: = "black"
var title: = "锅铲"
var home: = Vector2(458, 615)
var home_angle := 0.0
var _offset: = Vector2.ZERO
var _last_head: = Vector2.ZERO
var _contacts: Dictionary = {}
var _bowl_body: RigidBody2D
var _bowl_shapes: Array[CollisionShape2D] = []
var _rim_visual: Node2D
var rigid: RigidBody2D
var grip = preload("res://modules/restaurant/world/physical_grip.gd").new()
var _bowl_captured: Dictionary = {}
var _spoon_velocity: = Vector2.ZERO
var _residue: = {"volume_ml": 0.0, "composition_ml": {}, "mixedness": 0.0, "layered": false, "colour_model": "weighted_srgb_visual_approximation"}
var _pick_image: Image
var stir_feedback := 0.0
func cooking_angle() -> float:
	return -0.24 if kind == "spoon" else -0.52

func can_pick(point: Vector2) -> bool:
	if storing or releasing: return false
	var local := to_local(world.to_global(point))
	var exposed := Rect2(-44, -22, 69, 44) if docked else Rect2(-42, -20, 134, 40)
	var artwork := Rect2(-42, -20, 134, 40)
	if not exposed.has_point(local) or not artwork.has_point(local): return false
	if _pick_image == null:
		_pick_image = preload("res://modules/restaurant/assets/sprite_library.gd").gear({"black": 3, "wooden": 4, "spoon": 5}[kind]).get_image()
		if _pick_image.is_compressed(): _pick_image.decompress()
	# Small slots in the spatula head are not separate interaction targets.
	# A four-pixel tolerance bridges them without selecting the hidden handle
	# or the empty rectangular corners of the artwork.
	for offset in [Vector2.ZERO, Vector2(4,0), Vector2(-4,0), Vector2(0,4), Vector2(0,-4)]:
		var sample: Vector2 = local + offset
		if not exposed.has_point(sample) or not artwork.has_point(sample): continue
		var uv := (sample - artwork.position) / artwork.size
		if _pick_image.get_pixel(clampi(int(uv.x * _pick_image.get_width()), 0, _pick_image.get_width()-1), clampi(int(uv.y * _pick_image.get_height()), 0, _pick_image.get_height()-1)).a > 0.12: return true
	return false

func _ready() -> void :
	position = home
	rotation = home_angle
	z_index = 42
	rigid = RigidBody2D.new()
	rigid.mass = Tuning.number("spoon" if kind == "spoon" else "spatula","mass_kg")
	rigid.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	rigid.center_of_mass = Vector2(-25,2) if kind == "spoon" else Vector2(-15,9)
	rigid.inertia = rigid.mass * (520.0 if kind == "spoon" else 285.0)
	rigid.name = "Physical_" + kind
	rigid.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	rigid.contact_monitor = true
	rigid.max_contacts_reported = 12
	rigid.linear_damp = 1.0
	rigid.angular_damp = 2.0
	rigid.physics_material_override = PhysicsMaterial.new()
	rigid.physics_material_override.friction = 0.72
	rigid.physics_material_override.bounce = 0.04
	rigid.collision_layer = 0
	rigid.collision_mask = 0
	rigid.freeze = true
	world.add_child(rigid)
	rigid.position = position
	rigid.rotation = rotation
	if kind == "spoon": _build_spoon_bowl()
	else:
		var face := CollisionShape2D.new()
		face.shape = RectangleShape2D.new()
		face.shape.size = Vector2(58, 7)
		face.position = Vector2(-15, 9)
		rigid.add_child(face)
	var handle := CollisionShape2D.new()
	handle.shape = RectangleShape2D.new()
	handle.shape.size = Vector2(82, 6)
	handle.position = Vector2(49, 0)
	rigid.add_child(handle)
	queue_redraw()

func _build_spoon_bowl() -> void :


	_bowl_body = rigid
	_bowl_body.name = "SpoonBowlPhysics"
	_bowl_body.collision_layer = 0
	_bowl_body.collision_mask = 16 | 32
	for points in [[Vector2(-45, -12), Vector2(-39, 11)], [Vector2(-39, 11), Vector2(-12, 11)], [Vector2(-12, 11), Vector2(-5, -12)]]:
		var shape: = CollisionShape2D.new()
		var segment := RectangleShape2D.new()
		segment.size = Vector2(points[0].distance_to(points[1])+2,3)
		shape.position = (points[0]+points[1])*0.5
		shape.rotation = (points[1]-points[0]).angle()
		shape.shape = segment
		shape.disabled = true
		_bowl_body.add_child(shape)
		_bowl_shapes.append(shape)
	_rim_visual = preload("res://modules/restaurant/world/spoon_rim.gd").new()
	_rim_visual.name = "SpoonFrontRim"
	_rim_visual.tool = self
	_rim_visual.visible = false
	add_child(_rim_visual)

func _set_bowl_enabled(value: bool) -> void :
	if is_instance_valid(_bowl_body): _bowl_body.collision_mask = 1 | 16 | 64 | 512 if value else 0
	for shape in _bowl_shapes: shape.set_deferred("disabled", not value)
	if is_instance_valid(_rim_visual): _rim_visual.visible = value

func _draw() -> void :
	paint(self)

func paint(target: Node2D) -> void :
	var tex: = preload("res://modules/restaurant/assets/sprite_library.gd").gear({"black": 3, "wooden": 4, "spoon": 5}[kind])
	if tex: target.draw_texture_rect(tex, Rect2(-42, -20, 134, 40), false)
	if kind == "spoon" and float(_residue.get("volume_ml", 0.0)) > 0.01:
		target.draw_circle(Vector2(-25, 4), clampf(3.0 + sqrt(float(_residue.volume_ml)) * 1.6, 3.0, 10.0), Color("a75d3d").lerp(Color("d0965a"), float(_residue.get("mixedness", 0.0)) * 0.4))

func _input(event: InputEvent) -> void :
	if event is InputEventMouseButton and active and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		grip.target_angle = clampf(grip.target_angle + deg_to_rad(10) * (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), -2.45, 2.45)
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and active:
			var destination: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
			grip.target = world.to_global(destination.clamp(Vector2(80,140), Vector2(1530,785)))
			release_tool(true)
			get_viewport().set_input_as_handled()
		elif event.pressed and world.controls_enabled and not world._knife_held and not world.pan.active and not world.has_active_utensil() and not is_instance_valid(world._held):
			var point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
			# Hidden handles overlap inside the cup. Only the exposed end is
			# selectable at rest, otherwise the last tool steals its neighbour.
			if can_pick(point):
				active = true
				docked = false


				grip.begin(rigid, world.to_global(point))
				# Keep the pose at the grab point. Picking up must not command a
				# sudden half-turn; the wheel turns the player's wrist explicitly.
				grip.target_angle = cooking_angle()
				_offset = -grip.local_anchor
				rigid.collision_layer = 1 | 512
				rigid.collision_mask = 1 | 16 | 64 | 512
				_last_head = position
				_contacts.clear()
				world.held_changed.emit(title)
				world.focus_changed.emit(title, "轻移承托食物；滚轮倾勺。用完放回筒口。" if kind == "spoon" else "拖动翻拌，松手放下。用完放回筒口。")
				_set_bowl_enabled(true)
				queue_redraw()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and active:
		if not world.controls_enabled or not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			release_tool()
		else:
			var point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
			grip.target = world.to_global(point.clamp(Vector2(80,140),Vector2(1530,785)))
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and active:
		if event.pressed and event.physical_keycode in [KEY_Q, KEY_ESCAPE]: release_tool()

		if event.physical_keycode in [KEY_Q, KEY_E, KEY_G]: get_viewport().set_input_as_handled()

func release_tool(finish_motion := false) -> void :
	if not active and not releasing: return
	active = false
	if finish_motion and world.controls_enabled and rigid.to_global(grip.local_anchor).distance_to(grip.target) > 14.0:
		releasing = true
		_release_elapsed = 0.0
		return
	_finish_release()

func _finish_release() -> void:
	releasing = false
	grip.release()
	rigid.linear_velocity = rigid.linear_velocity.limit_length(180.0)
	rigid.angular_velocity = clampf(rigid.angular_velocity, -2.0, 2.0)
	# Only a release at the physical cup stores the utensil. Else it remains
	# an independent body on the worktop, including across menus/focus loss.
	# Use the player's release target as well as physical proximity. A quick
	# outward pull must not snap back just because the heavy tool is still lagging;
	# the small approach margin accepts the handle/head at the cup's open mouth.
	if CUP_MOUTH.has_point(world.to_local(grip.target)) and CUP_MOUTH.grow(50).has_point(rigid.position):
		_begin_storing()
	else:
		rigid.freeze = not world.controls_enabled
		rigid.collision_layer = 1 | 512
		rigid.collision_mask = 1 | 16 | 64 | 512
	for carried in _bowl_captured.values():
		if is_instance_valid(carried): carried.set_meta("container_location", "pan" if world.pan.contains(carried.position) else "worktop")
	_bowl_captured.clear()
	_spoon_velocity = Vector2.ZERO
	_contacts.clear()
	world.held_changed.emit("")
	world.focus_changed.emit(title, "慢慢放回筒里。" if storing else "放在这里了。")
	queue_redraw()

func _begin_storing() -> void:
	storing = true
	_store_elapsed = 0.0
	_store_origin = rigid.position
	_store_angle = rigid.rotation
	grip.begin(rigid, rigid.global_position)
	# The cup is a storage socket behind the work surface. Its approach uses
	# the same force controller; no position/rotation jump until fully settled.
	rigid.collision_layer = 0
	rigid.collision_mask = 0
	_set_bowl_enabled(false)

func _advance_storage(dt: float) -> void:
	_store_elapsed += dt
	var progress := clampf(_store_elapsed / 0.65, 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, progress)
	var approach := _store_origin.lerp(home, eased) - Vector2(0, sin(progress * PI) * 12.0)
	grip.target = world.to_global(approach)
	grip.target_angle = lerp_angle(_store_angle, home_angle, eased)
	grip.apply(rigid, dt)
	if progress >= 1.0 and rigid.position.distance_to(home) < 2.0 and absf(angle_difference(rigid.rotation, home_angle)) < 0.025 and rigid.linear_velocity.length() < 10.0:
		dock()
		world.audio.play_effect("stir_metal" if kind == "black" else "stir_wood", 0.24)
		world.focus_changed.emit(title, "放好了。")

func dock() -> void:
	releasing = false
	storing = false
	grip.release()
	docked = true
	rigid.freeze = true
	rigid.linear_velocity = Vector2.ZERO
	rigid.angular_velocity = 0.0
	rigid.collision_layer = 0
	rigid.collision_mask = 0
	_set_bowl_enabled(false)
	position = home
	rotation = home_angle
	rigid.position = home
	rigid.rotation = home_angle

func set_paused(value: bool) -> void:
	if value: release_tool()
	rigid.freeze = value or docked

func stir_sweep(from: Vector2, to: Vector2) -> int:
	if world.lid.covered: return 0
	if not active or not world.controls_enabled or from.distance_to(to) < 0.2:
		return 0
	var count: = 0
	var now: = Time.get_ticks_msec()
	for body in world._foods.get_children():
		if not body is RigidBody2D or body.is_queued_for_deletion() or body.freeze:
			continue
		if body == world._held or body.get_meta("is_container", false) or body.get_meta("plated", false):
			continue
		var center: Vector2 = world.to_local(body.global_position)
		if not world.pan.contains(center) and float(body.get_meta("stir_until", 0)) <= world._time: continue
		if body.get_meta("overflow", false): continue
		var head_offset: = Vector2(-24 if kind == "spoon" else -14, 0).rotated(rotation)
		var touch: Vector2 = Geometry2D.get_closest_point_to_segment(center, from + head_offset, to + head_offset)
		if touch.distance_to(center) > 35: continue
		var key: int = body.get_instance_id()
		if now - int(_contacts.get(key, -1000)) < 160: continue
		_contacts[key] = now
		# The painted pan has depth in the screen plane. Contact at the blade's
		# swept face transfers a small bounded impulse, including between ticks.
		if not body.has_meta("liquid_state"):
			var sweep := (to - from).limit_length(18.0)
			var desired := Vector2(sweep.x * 2.4, minf(-4.0, sweep.y * 2.0))
			body.apply_central_impulse(preload("res://modules/restaurant/domain/material_response.gd").utensil_impulse(body, desired, kind == "spoon") * 0.55)
			body.apply_torque_impulse(body.mass * sweep.x * 2.5)
		stir_feedback = 1.0
		body.set_meta("stir_until", world._time + 0.8)
		count += 1
		world.audio.play_food_stir(body, kind, from.distance_to(to))
		_exchange_liquid(body, from.distance_to(to))
		world.reactions.stir(body,from.distance_to(to),from.y-to.y>12.0)
	return count

func _exchange_liquid(body: RigidBody2D, speed: float) -> void :
	if body.has_meta("liquid_state"):
		var state: Dictionary = body.get_meta("liquid_state")
		SauceState.agitate(state, clampf(speed / 900.0, 0.01, 0.16))
		body.set_meta("liquid_state", state)
		var art = body.get_node_or_null("SauceBlob")
		if art: art.liquid_state = state;art.queue_redraw()
		return
	var coating: Dictionary = body.get_meta("surface_sauce", {"volume_ml": 0.0, "composition_ml": {}, "mixedness": 0.0, "layered": false})
	if kind == "spoon" and float(_residue.get("volume_ml", 0.0)) > 0.01:
		world.reactions.ensure_state(body)
		var density := float(_residue.get("mass_kg",0.0))/float(_residue.volume_ml)
		var moved := SauceState.transfer(_residue, coating, minf(0.24, float(_residue.volume_ml)))
		var mass_moved := moved*density
		_residue.mass_kg=maxf(0.0,float(_residue.get("mass_kg",0.0))-mass_moved)
		body.mass += mass_moved
		coating.mass_kg=float(coating.get("mass_kg",0.0))+mass_moved
	body.set_meta("surface_sauce",coating)
	for candidate in world._foods.get_children():
		if candidate == body or not candidate is RigidBody2D or candidate.is_queued_for_deletion() or candidate.get_meta("plated",false) or candidate.get_meta("overflow",false): continue
		if candidate.global_position.distance_to(body.global_position) > 42.0: continue
		if candidate.has_meta("liquid_state"): world.reactions.coat(candidate,body,clampf(speed/70.0,0.15,1.2))
		elif candidate.has_meta("thermal"): world.reactions.coat_phase(candidate,body,clampf(speed/70.0,0.15,1.2))
	queue_redraw()

func liquid_inventory() -> Dictionary:
	return _residue.duplicate(true)

func bowl_contains(body: RigidBody2D) -> bool:
	if kind != "spoon" or docked or not is_instance_valid(body): return false
	if _bowl_captured.has(body.get_instance_id()): return true
	var p: = to_local(body.global_position)
	return ((p - Vector2(-25, 1)) / Vector2(31, 20)).length() <= 1.0

func bowl_contents() -> Array:
	var result: Array = []
	if kind != "spoon" or docked: return result
	for body in world._foods.get_children():
		if body is RigidBody2D and bowl_contains(body): result.append(body)
	return result

func _physics_process(_delta: float) -> void:
	stir_feedback = move_toward(stir_feedback, 0.0, _delta * 4.0)
	if docked or not world.controls_enabled: return
	if storing: _advance_storage(_delta)
	elif active: grip.apply(rigid, _delta)
	elif releasing:
		_release_elapsed += _delta
		grip.apply(rigid, _delta)
		if rigid.to_global(grip.local_anchor).distance_to(grip.target) < 14.0 or _release_elapsed > 1.5:
			_finish_release()
	position = rigid.position
	rotation = rigid.rotation
	_spoon_velocity = rigid.linear_velocity
	stir_sweep(_last_head, position)
	_last_head = position
	if kind != "spoon": return
	var center: = to_global(Vector2(-25, 1))
	for body in world._foods.get_children():
		if not body is RigidBody2D or body.freeze or body == world._held or body.get_meta("is_container", false) or body.get_meta("plated", false): continue
		var key: int = body.get_instance_id()
		var normalized: = ((to_local(body.global_position) - Vector2(-25, 1)) / Vector2(31, 20)).length()
		if normalized <= 1.05:
			var first_capture: = not _bowl_captured.has(key)
			_bowl_captured[key] = body
			body.set_meta("container_location", "spoon")
			if first_capture and body.has_meta("liquid_state"):
				var liquid: Dictionary = body.get_meta("liquid_state")
				var density: float = body.mass/maxf(0.000001,float(liquid.get("volume_ml",0.0)))
				var moved := SauceState.transfer(liquid, _residue, minf(0.8, float(liquid.get("volume_ml", 0.0))))
				var mass_moved := moved*density
				_residue.mass_kg=float(_residue.get("mass_kg",0.0))+mass_moved
				body.mass=maxf(0.000000000001,body.mass-mass_moved)
				body.set_meta("liquid_state", liquid)
				body.set_meta("volume_ml", liquid.get("volume_ml", 0.0))
				queue_redraw()
		if not _bowl_captured.has(key): continue



		if normalized > 1.3:
			_bowl_captured.erase(key)
			body.set_meta("container_location", "pan" if world.pan.contains(body.position) else "worktop")
			continue
		# Support is solely the three bowl colliders. No magnetic centre attraction.

func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_instance_valid(world): release_tool()
