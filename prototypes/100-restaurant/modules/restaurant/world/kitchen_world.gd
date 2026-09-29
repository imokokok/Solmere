extends Node2D
const MaterialResponse = preload("res://modules/restaurant/domain/material_response.gd")


signal interaction(action: String, payload: String)
signal focus_changed(title: String, hint: String)
signal food_entered_pan(id: String, cut: bool, body: RigidBody2D)
signal food_removed_from_pan(body: RigidBody2D)
signal held_changed(title: String)

var controls_enabled: = false
var cooking: = false
var heat_level: = "medium"
var plated: = false
var camera: Camera2D
var _held: RigidBody2D
var held_grip = preload("res://modules/restaurant/world/physical_grip.gd").new()
var _pending_drop := false
var _pending_drop_elapsed := 0.0
var _foods: Node2D
var _egg_shells: Node2D
var shell_waste_kg := 0.0
var _pan_area: Area2D
var _pan_walls: Array = []
var lid: Node2D
var pan: Node2D
var plate: Node2D
var cutting_board: Node2D
var utensils: Array[Node2D] = []
var sponge: Node2D
var cloth: Node2D
var plate_presentation: Dictionary = {}
var audio: Node
var reactions: Node2D
var _customer: Dictionary = {}
var _backdrop: Node2D
var _font: Font
var _time: = 0.0
var _focus: = ""
var _dragging: = false
var storage_return_handler: Callable
const PAN_CAPACITY_ML := 1500.0
const SINK_HOLD_ML := 1200.0
const KITCHEN_FLOOD_ML := 7800.0
var sink_water_ml := 0.0
var flood_water_ml := 0.0
var drained_flood_ml := 0.0
var flood_art: Node2D
var material_play: Node2D
var _overflow_until := 0.0
var _overflow_color := Color("c68b57")

func pan_contents_ml() -> float:
	var volume: float = pan.water_ml
	for body in _foods.get_children():
		if body.is_queued_for_deletion() or body == _held or body.get_meta("is_container", false) or body.get_meta("overflow", false) or body.get_meta("plated", false): continue
		if not (body.get_meta("enrolled", false) or body.get_meta("pending", false) or (body.get_meta("dispensed", false) and body.get_meta("container_location", "") == "air")): continue
		if body.has_meta("liquid_state"):
			volume += float(body.get_meta("liquid_state").get("volume_ml", 0.0))
		else:
			# Displacement from mass / approximate bulk density, not piece count.
			var density := maxf(0.2, float(body.get_meta("definition", {}).get("density_g_ml", 1.0)))
			var coating: Dictionary = body.get_meta("surface_sauce", {})
			volume += maxf(0.0, body.mass - float(coating.get("mass_kg", 0.0))) * 1000.0 / density
			volume += float(coating.get("volume_ml", 0.0))
	return volume

func pan_free_ml() -> float:
	return maxf(0.0, PAN_CAPACITY_ML - pan_contents_ml())

func pan_fill_ratio() -> float:
	return clampf(pan_contents_ml() / PAN_CAPACITY_ML, 0.0, 1.0)

func flood_ratio() -> float:
	return clampf(flood_water_ml / KITCHEN_FLOOD_ML, 0.0, 1.0)

func receive_faucet_runoff(amount_ml: float) -> void:
	# External callers add water at the sink mouth, preserving flight time.
	if amount_ml > 0.0: pan.runoff.emit_water(amount_ml, Vector2(200, 700))

var _food_drag_offset: = Vector2.ZERO
var _food_drag_origin: = Vector2.ZERO
var _food_drag_moved: = false
var _food_drag_from_storage: = false
var _drag_group: Array[Dictionary] = []
var _food_art: Script
var _held_foreground: Node2D
var _held_proxy: Node2D
var _held_proxy_source: Node2D
var storage_pickup_view: Dictionary = {}
var _storage_lift_time := 0.0

func start_storage_lift(view: Dictionary) -> void:
	storage_pickup_view = view
	_storage_lift_time = 0.0
	_sync_held_foreground()
var _sound: AudioStreamPlayer
var _chop_flash: = 0.0
var _last_mouse: = Vector2.ZERO
var _mouse_velocity: = Vector2.ZERO
var _squeezing: = false
var _squeeze_elapsed: = 0.0
var _squeeze_dispensed: = false
var squeeze_pressure: = 0.0
var _squeeze_distance: = 0.0
var _squeeze_last_nozzle: = Vector2.ZERO
const SauceState = preload("res://modules/restaurant/domain/sauce_state.gd")
var _knife_held: = false
var _spatula: Node2D
var _knife_cutting: = false
var _knife_visual: Node2D
var _previous_blade_tip: = Vector2.ZERO
const KNIFE_BLADE_MID := Vector2(-50, -22)
var _knife_stroke_origin := Vector2.ZERO
const KNIFE_HOME := Vector2(1252, 731)
# The art itself is rotated 0.22 radians inside knife_tool.gd. Rest positions
# must contain that painted outline, not just the knife node's origin.
const KNIFE_REST_ART_BOUNDS := Rect2(-98, -44, 196, 92)
var _knife_rest_position: = KNIFE_HOME
var _knife_last_valid_rest: = KNIFE_HOME
var _knife_drag_offset: = Vector2.ZERO
var _poster_canvas: Control
var _stations: = {
	"pantry": Rect2(40, 190, 300, 310),
	"chop": Rect2(1030, 680, 390, 108),
	"cook": Rect2(677, 535, 265, 125),
	"plate": Rect2(1340, 535, 240, 95),

	"talk": Rect2(720, 210, 250, 205),

	"trash": Rect2(1440, 825, 130, 60)
}
var _titles: = {"pantry": "食材架", "chop": "料理台", "cook": "平底锅", "plate": "装盘台", "serve": "出餐窗口", "talk": "今日客人", "cookbook": "公共菜谱", "poster": "海报工作台", "trash": "回收桶"}
var _hints: = {"pantry": "挑选食材", "chop": "按住刀柄顺箭头压切；拿刀后按 R 横切成块", "cook": "空手点击开火 / 离火；食材拖入锅中", "plate": "放大餐盘，自由摆放、淋酱与拍照", "serve": "给客人上菜", "talk": "聊聊口味与忌口", "cookbook": "命名 · 署名 · 分享", "poster": "涂鸦 · 拼贴 · 招呼街坊", "trash": "丢弃手中食材 / 清空料理"}

func _ready() -> void :
	_backdrop = preload("res://modules/restaurant/world/kitchen_backdrop.gd").new()
	_backdrop.z_index = -5
	add_child(_backdrop)
	var bundled_font: = FontVariation.new()
	bundled_font.base_font = preload("res://modules/restaurant/assets/fonts/noto_sans_sc.ttf")
	bundled_font.variation_opentype = {2003265652: 500.0}
	_font = bundled_font
	if ResourceLoader.exists("res://modules/restaurant/assets/food_art.gd"):
		_food_art = load("res://modules/restaurant/assets/food_art.gd")
	_foods = Node2D.new()
	_foods.name = "PhysicalIngredients"
	_foods.z_index = 5
	add_child(_foods)
	_foods.child_entered_tree.connect(_connect_food_audio)
	var contact_shadows := preload("res://modules/restaurant/world/contact_shadows.gd").new()
	contact_shadows.world = self
	contact_shadows.z_index = 4
	add_child(contact_shadows)
	_egg_shells = Node2D.new()
	_egg_shells.name = "EggShells"
	_egg_shells.z_index = 8
	add_child(_egg_shells)
	var held_layer: = CanvasLayer.new()
	held_layer.name = "HeldIngredientForeground"
	held_layer.layer = 2
	add_child(held_layer)
	_held_foreground = preload("res://modules/restaurant/world/held_foreground.gd").new()
	_held_foreground.world = self
	_held_foreground.visible = false
	held_layer.add_child(_held_foreground)
	var stream := preload("res://modules/restaurant/world/dispensing_stream.gd").new()
	stream.world = self
	stream.z_index = 8
	add_child(stream)
	flood_art = preload("res://modules/restaurant/world/kitchen_flood.gd").new()
	flood_art.world = self
	flood_art.z_index = 60
	add_child(flood_art)
	material_play = preload("res://modules/restaurant/world/material_play.gd").new()
	material_play.world = self
	add_child(material_play)
	var surfaces: = preload("res://modules/restaurant/world/worktop_art.gd").new()
	surfaces.z_index = -1
	add_child(surfaces)
	cutting_board = preload("res://modules/restaurant/world/cutting_board.gd").new()
	cutting_board.world = self
	add_child(cutting_board)
	_build_physics()
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -17
	add_child(_sound)
	_knife_visual = preload("res://modules/restaurant/world/knife_tool.gd").new()
	_knife_visual.name = "ChefKnife"
	_knife_visual.z_index = 40
	_knife_visual.position = _knife_rest_position
	_knife_visual.visible = true
	add_child(_knife_visual)
	_spatula = preload("res://modules/restaurant/world/spatula_tool.gd").new()
	_spatula.name = "CookingSpatula"
	_spatula.world = self
	_spatula.home = Vector2(625, 505)
	_spatula.home_angle = 2.0
	add_child(_spatula)
	utensils.append(_spatula)
	for variant in [["wooden", "木铲", Vector2(552, 506), 1.15], ["spoon", "木勺", Vector2(584, 530), 1.46]]:
		var tool = preload("res://modules/restaurant/world/spatula_tool.gd").new()
		tool.world = self
		tool.kind = variant[0]
		tool.title = variant[1]
		tool.home = variant[2]
		tool.home_angle = variant[3]
		add_child(tool)
		utensils.append(tool)
	var cup_front := preload("res://modules/restaurant/world/utensil_cup_front.gd").new()
	add_child(cup_front)
	audio = preload("res://modules/restaurant/world/kitchen_audio.gd").new()
	add_child(audio)
	pan = preload("res://modules/restaurant/world/pan_controller.gd").new()
	pan.world = self
	add_child(pan)
	pan.move_to(pan.HOME)
	reactions = preload("res://modules/restaurant/world/cooking_reactions.gd").new()
	reactions.world = self
	reactions.z_index = 8
	add_child(reactions)
	lid = preload("res://modules/restaurant/world/pan_lid.gd").new()
	lid.world = self
	add_child(lid)
	plate = preload("res://modules/restaurant/world/plate_controller.gd").new()
	plate.world = self
	add_child(plate)
	sponge = preload("res://modules/restaurant/world/cleaning_sponge.gd").new()
	sponge.world = self
	add_child(sponge)
	cloth = preload("res://modules/restaurant/world/cleaning_cloth.gd").new()
	cloth.world = self
	add_child(cloth)
	var floating: = preload("res://modules/restaurant/world/floating_tools.gd").new()
	floating.name = "FloatingTools"
	floating.world = self
	add_child(floating)
	var plate_ink: = preload("res://modules/restaurant/world/plate_sauce.gd").new()
	plate_ink.world = self
	plate_ink.z_index = 5
	add_child(plate_ink)
	var inspector = preload("res://modules/restaurant/world/physics_inspector.gd").new()
	inspector.world = self
	add_child(inspector)
	_last_mouse = get_global_mouse_position()
	set_process(true)

func _build_physics() -> void :

	_static_box(Vector2(800, 870), Vector2(1600, 174))
	_static_box(Vector2(-18, 450), Vector2(32, 900))
	_static_box(Vector2(1608, 450), Vector2(32, 900))
	# The visible worktop is a real support surface.  Loose bottles and unused
	# ingredients settle here instead of falling behind the lower UI.
	_static_segment(Vector2(365, 718), Vector2(1590, 718), false)


	_static_segment(Vector2(12, 657), Vector2(40, 744), false)
	_static_segment(Vector2(40, 744), Vector2(342, 744), false)
	_static_segment(Vector2(342, 744), Vector2(418, 657), false)


	_static_segment(Vector2(695, 566), Vector2(732, 599))
	_static_segment(Vector2(732, 599), Vector2(884, 599))
	_static_segment(Vector2(884, 599), Vector2(925, 566))
	_pan_area = Area2D.new()
	_pan_area.name = "PanInterior"
	_pan_area.position = Vector2(809, 599)
	_pan_area.collision_layer = 0
	_pan_area.collision_mask = 16 | 32
	var shape: = RectangleShape2D.new()
	shape.size = Vector2(204, 62)
	var collision: = CollisionShape2D.new()
	collision.shape = shape
	_pan_area.add_child(collision)
	_pan_area.body_entered.connect(_on_pan_entered)
	_pan_area.body_exited.connect(_on_pan_exited)
	add_child(_pan_area)

func _draw() -> void :
	pass

func _update_held_motion(delta: float, mouse: Vector2) -> void:
	if is_instance_valid(_held) and controls_enabled:
		if _pending_drop: return # Release intent retains the last event target.
		# Keep a dispensing container visibly above the rear rim. Its nozzle and
		# stream still use the same transform as the held art.
		if _is_whole_egg(_held) and int(_held.get_meta("egg_taps", 0)) == 1:
			held_grip.target = to_global(_held.get_meta("egg_tap_point", _held.position))
		elif not _dragging:
			held_grip.target = Vector2(clampf(mouse.x, 727.0 + pan.offset.x, 895.0 + pan.offset.x), minf(mouse.y, 470.0 + pan.offset.y)) if _squeezing else mouse + (_food_drag_offset if _dragging else Vector2.ZERO)
		if _squeezing:
			var mode: = get_dispense_mode(_held.get_meta("definition", {}))
			# The art adapter owns mouth orientation; rotating here as well
			# previously turned top-opening authored bottles upright again.
			held_grip.target_angle = sin(_time * 25.0) * 0.1 if mode == "powder" else 0.0
			if not _squeeze_region().has_point(mouse):
				_stop_squeezing()
			else:
				_squeeze_elapsed += delta
				var nozzle_now: = _nozzle_world_position()
				_squeeze_distance += nozzle_now.distance_to(_squeeze_last_nozzle)
				_squeeze_last_nozzle = nozzle_now
				var interval: = lerpf(0.28, 0.075, squeeze_pressure)
				if _squeeze_elapsed >= interval:
					var elapsed_for_flow: = _squeeze_elapsed
					_squeeze_elapsed = 0.0
					var flow_rate := MaterialResponse.flow_rate(_held.get_meta("definition", {}), squeeze_pressure, float(_held.get_meta("remaining_ml", 0.0)))
					var volume_ml := flow_rate * elapsed_for_flow
					if is_instance_valid(_dispense_seasoning(volume_ml)):
						_squeeze_dispensed = true

func _process(delta: float) -> void :
	_storage_lift_time += delta
	if _storage_lift_time >= 0.24 and not storage_pickup_view.is_empty():
		var origin: Vector2 = storage_pickup_view.transform.origin
		# The near edge belongs to the box until the hand physically clears it.
		if not is_instance_valid(_held) or _held.get_global_transform_with_canvas().origin.distance_to(origin) > 65.0:
			storage_pickup_view.clear()
	_backdrop.set("cooking", cooking)
	_backdrop.set("customer", _customer)
	_backdrop.set("time", _time)
	_backdrop.set("knife_held", _knife_held)
	_time += delta
	_chop_flash = maxf(0, _chop_flash - delta)
	var mouse: = get_global_mouse_position()
	_mouse_velocity = (mouse - _last_mouse) / maxf(delta, 0.001)
	_last_mouse = mouse
	if _squeezing:
		squeeze_pressure = move_toward(squeeze_pressure, 1.0, delta * 3.2)
	else:
		squeeze_pressure = move_toward(squeeze_pressure, 0.0, delta * 5.0)
	_update_held_motion(delta, mouse)
	if controls_enabled:
		var next: = ""
		for action in _stations:
			if _stations[action].has_point(mouse):
				next = action
		if next != _focus:
			_focus = next
			if is_instance_valid(_spatula) and has_active_utensil():
				for utensil in utensils:
					if utensil.active:
						focus_changed.emit(utensil.title, "轻移承托，滚轮倾勺。用完放回筒口。" if utensil.kind == "spoon" else "拖动翻拌，松手放下。用完放回筒口。")
						break
			elif _knife_held:
				focus_changed.emit("主厨刀", "顺箭头划完整刀线；R 转刀 90°，滚轮微调角度，松手放刀")
			elif _held_is_sauce_bottle():
				focus_changed.emit(get_held_name(), get_held_operation_hint())
			else:
				focus_changed.emit(str(_titles.get(next, "")), str(_hints.get(next, "")))
	_sync_held_foreground()
	_update_landed_seasoning()
	_update_food_depth()
	audio.update_kitchen(self)
	queue_redraw()

func _apply_carry_grip(hand: RefCounted, body: RigidBody2D, dt: float) -> void:
	var requested: Vector2 = hand.target
	# Lift a handful over the near wall before crossing it horizontally. The
	# user still chooses the destination; collisions remain enabled throughout.
	if not body.get_meta("is_container",false):
		var target_local: Vector2 = pan.local_point(to_local(requested))
		var body_local: Vector2 = pan.local_point(body.position)
		# The visible near half of the bowl is a valid drop target too. First
		# lift above the wall, then cross at that height, then lower the food.
		# A diagonal chase toward the near rim used to shove the whole pan.
		if target_local.x > 700 and target_local.x < 920 and target_local.y < 620 and (body_local.x < 745 or body_local.x > 875):
			var crossing_x := body_local.x if body_local.y > 520 else clampf(target_local.x,755,865)
			hand.target = to_global(pan.point(Vector2(crossing_x,480)))
	hand.apply(body, dt)
	hand.target = requested

func _physics_process(_delta: float) -> void :
	if controls_enabled and is_instance_valid(_held): _apply_carry_grip(held_grip, _held, _delta)
	if controls_enabled and is_instance_valid(_held):
		for member in _drag_group:
			if not is_instance_valid(member.body): continue
			member.grip.target = held_grip.target - held_grip.local_anchor.rotated(_held.rotation) + member.offset
			_apply_carry_grip(member.grip, member.body, _delta)
	if _pending_drop and controls_enabled and is_instance_valid(_held):
		_pending_drop_elapsed += _delta
		var grip_point := _held.to_global(held_grip.local_anchor)
		var settled := grip_point.distance_to(held_grip.target) < 14.0 and _held.linear_velocity.length() < 90
		for member in _drag_group:
			if is_instance_valid(member.body) and (member.body.global_position.distance_to(member.grip.target) > 18 or member.body.linear_velocity.length() > 90): settled = false
		if settled or _pending_drop_elapsed > 2.2:
			_pending_drop = false
			_finish_food_drag(_pending_drop_elapsed > 2.2)
	if not controls_enabled or not is_instance_valid(_pan_area):
		return


	for body in _pan_area.get_overlapping_bodies():
		if is_instance_valid(body) and pan.contains(body.position):
			_on_pan_entered(body)
	for body in _foods.get_children():
		if body.is_queued_for_deletion() or body == _held or body.get_meta("plated", false): continue
		if body.get_meta("poured", false) and not pan.contains(body.position) and plate.hit_rect().has_point(body.position):
			_land_on_plate(body)
		elif body.get_meta("enrolled", false) and not pan.contains(body.position):
			_on_pan_exited(body)

func _land_on_plate(body: RigidBody2D) -> void :
	leave_pan_residue(body)
	if body.get_meta("overflow", false) or body.get_meta("is_container", false): return
	body.set_meta("plated", true)
	body.set_meta("pending", false)
	if not body.get_meta("enrolled", false):
		body.set_meta("pending", true)
		food_entered_pan.emit(str(body.get_meta("id")), bool(body.get_meta("cut", false)), body)
	if body.get_meta("enrolled", false):
		body.set_deferred("freeze", true)
		_update_plated_flag()
		interaction.emit("notice", "食物已经倒进盘中，可以继续倒菜或直接出餐。")
	else: body.set_meta("plated", false)

func _input(event: InputEvent) -> void :

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _knife_held:
			# Native rapid drags may coalesce the last motion. The release still
			# carries the final blade position and must complete that same stroke.
			_move_knife(get_global_transform_with_canvas().affine_inverse() * event.position)
			_release_knife()
			get_viewport().set_input_as_handled()
			return
		if _squeezing:
			_stop_squeezing()
			get_viewport().set_input_as_handled()
			return
		if _dragging:
			_move_dragged_food(get_global_transform_with_canvas().affine_inverse() * event.position)
			_finish_food_drag()
			get_viewport().set_input_as_handled()
			return
	if controls_enabled and _dragging and event is InputEventMouseMotion:
		_move_dragged_food(get_global_transform_with_canvas().affine_inverse() * event.position)
	if controls_enabled and _knife_held and event is InputEventMouseMotion:


		_move_knife(get_global_transform_with_canvas().affine_inverse() * event.position)

func _unhandled_input(event: InputEvent) -> void :
	if not controls_enabled or pan.active or plate.active or lid.active:
		return
	if event is InputEventMouseButton and event.pressed and _knife_held and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_rotate_knife_by(deg_to_rad(-15.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 15.0))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and _squeezing:
			_stop_squeezing()
			get_viewport().set_input_as_handled()
			return
		if event.pressed:
			if is_instance_valid(_held):
				var held_pointer: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
				if _pending_drop and food_hit(_held,held_pointer):
					# A release in transit is still the player's object. Regrip the
					# actual pose, retaining all sibling bodies and their hand forces.
					_pending_drop = false
					_pending_drop_elapsed = 0.0
					_dragging = true
					_food_drag_origin = held_pointer
					_food_drag_from_storage = false
					_food_drag_moved = false
					held_grip.begin(_held,to_global(held_pointer))
					get_viewport().set_input_as_handled()
					return
				if _is_whole_egg(_held) and _egg_tap_target(held_pointer):
					_tap_egg(held_pointer)
					get_viewport().set_input_as_handled()
					return
				if _held_is_sauce_bottle() and _squeeze_region().has_point(held_pointer):
					_squeezing = true
					_squeeze_elapsed = 0.0
					_squeeze_dispensed = false
					_squeeze_distance = 0.0
					_squeeze_last_nozzle = _nozzle_world_position()
					_dragging = false
					get_viewport().set_input_as_handled()
					return
				elif _stations.trash.has_point(held_pointer):
					discard_held()
				else:
					# Click-carried bottles need the same retained release destination
					# as dragged food. The OS pointer can arrive before the rigid body.
					held_grip.target = to_global(held_pointer)
					_food_drag_from_storage = false
					_food_drag_moved = true
					_finish_food_drag()
			else:
				var pointer: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
				var food: = _food_at(pointer)
				if _wipe_spill_at(pointer):
					get_viewport().set_input_as_handled()
				elif _knife_handle_rect().has_point(pointer):
					pickup_knife(pointer)
					get_viewport().set_input_as_handled()
				elif food:
					_pickup(food)
					begin_food_drag(pointer)
					get_viewport().set_input_as_handled()
				elif _knife_grab_rect().has_point(pointer):
					pickup_knife(pointer)
					get_viewport().set_input_as_handled()
				elif not _focus.is_empty():
					interaction.emit(_focus, "")
		elif _dragging:
			_dragging = false
			if is_instance_valid(_held):
				if _focus == "chop":
					chop_held()
					drop_held(false)
				elif _focus == "trash":
					discard_held()
				else:
					drop_held(false)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q:
			if _knife_held or ( not is_instance_valid(_held) and not _knife_rest_position.is_equal_approx(KNIFE_HOME)):
				put_knife_back()
			else:
				drop_held(false)
		elif event.physical_keycode == KEY_R and _knife_held:
			_rotate_knife()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_G:
			drop_held(true)
		elif event.physical_keycode == KEY_E and not _focus.is_empty():
			if _focus == "chop" and is_instance_valid(_held):
				chop_held()
			elif _focus == "cook" and is_instance_valid(_held):
				drop_into_pan()
			else:
				interaction.emit(_focus, "")

func set_poster(_data: Dictionary) -> void :

	if is_instance_valid(_poster_canvas):
		_poster_canvas.queue_free()
		_poster_canvas = null

func set_controls_enabled(value: bool) -> void :
	if not value and is_instance_valid(lid): lid.suspend()
	if not value and is_instance_valid(pan): pan.suspend()
	if not value and is_instance_valid(plate): plate.finish(false)
	if not value and (_dragging or _pending_drop): _finish_food_drag(true)
	controls_enabled = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for tool in utensils: tool.set_paused(not value)
	if is_instance_valid(_foods):
		for body in _foods.get_children():
			if not value:
				if not body.has_meta("modal_freeze"):
					body.set_meta("modal_freeze", body.freeze)
				body.freeze = true
			elif body.has_meta("modal_freeze"):
				body.freeze = bool(body.get_meta("plated", false)) or bool(body.get_meta("modal_freeze"))
				body.remove_meta("modal_freeze")
	if not value:
		if is_instance_valid(sponge): sponge.release_tool()
		if is_instance_valid(cloth): cloth.release_tool()
		for tool in utensils: tool.release_tool()
		_stop_squeezing()
		if _knife_held:
			_release_knife()
		_focus = ""
		focus_changed.emit("", "")
	_sync_held_foreground()

func spawn_ingredient(definition: Dictionary) -> bool:
	if is_instance_valid(_held) or _knife_held or has_active_utensil() or pan.active or _foods.get_child_count() >= 64:
		return false
	var body: = preload("res://modules/restaurant/world/food_body.gd").new()
	body.mass = clampf(float(definition.get("mass", 0.15)), 0.01, 3.0)
	body.collision_layer = 16
	body.collision_mask = 17
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.set_meta("id", str(definition.get("id", "tomato")))
	body.set_meta("title", str(definition.get("name", "食材")))
	body.set_meta("definition", definition.duplicate(true))
	body.set_meta("cut", false)
	body.set_meta("enrolled", false)
	body.set_meta("pending", false)
	body.set_meta("plated", false)
	body.set_meta("is_container", not get_dispense_mode(definition).is_empty())
	var instance_uid: = "food_%s_%s" % [Time.get_ticks_usec(), _foods.get_child_count()]
	body.set_meta("instance_uid", instance_uid)
	body.set_meta("batch_uid", instance_uid)
	body.set_meta("lineage", [])
	body.set_meta("surface_sauce", {"volume_ml": 0.0, "composition_ml": {}, "mixedness": 0.0, "layered": false})
	if body.get_meta("is_container", false): body.set_meta("remaining_ml", float(definition.get("container_ml", 240.0)))
	var source_polygon := preload("res://modules/restaurant/assets/sprite_library.gd").body_outline(str(definition.id))
	var authored_shape := not source_polygon.is_empty()
	if not authored_shape:
		for i in range(32): source_polygon.append(Vector2.from_angle(i * TAU / 32.0) * 24.0)
	body.set_meta("fragment_polygon", source_polygon)
	var collision: = CollisionShape2D.new()
	if authored_shape:
		var shape := ConvexPolygonShape2D.new()
		shape.points = source_polygon
		collision.shape = shape
	else:
		var shape := CircleShape2D.new()
		shape.radius = 18.0
		collision.shape = shape
	body.add_child(collision)
	_foods.add_child(body)
	_make_food_visual(body, definition)
	body.global_position = get_global_mouse_position()
	_pickup(body)
	return true

func _make_food_visual(body: RigidBody2D, definition: Dictionary) -> void :
	if _food_art:
		var visual: = Node2D.new()
		visual.name = "FoodArt"
		visual.set_script(_food_art)
		visual.set("definition", definition)
		visual.scale = Vector2.ONE * preload("res://modules/restaurant/assets/sprite_library.gd").physical_art_scale(str(definition.get("id", "")))
		body.add_child(visual)
	else:
		var sprite: = Polygon2D.new()
		var points: = PackedVector2Array()
		for i in range(20):
			points.append(Vector2.from_angle(i * TAU / 20.0) * 19)
		sprite.polygon = points
		sprite.color = Color(str(definition.get("color", "d95b40")))
		body.add_child(sprite)

func _food_at(pos: Vector2) -> RigidBody2D:
	if is_instance_valid(lid) and lid.blocks(pos): return null
	_update_food_depth()
	var bodies := _foods.get_children()
	bodies.sort_custom(func(a, b): return a.z_index < b.z_index or (a.z_index == b.z_index and a.get_index() < b.get_index()))
	bodies.reverse()
	for body in bodies:
		if body.is_queued_for_deletion() or body == _held or body.get_meta("overflow", false): continue
		if body.z_index + _foods.z_index < pan.pan_front.z_index and preload("res://modules/restaurant/world/pan_geometry.gd").front_occludes(pan.local_point(pos)): continue
		if food_hit(body, pos): return body
	return null

func food_hit(body: RigidBody2D, pos: Vector2) -> bool:
	var visual := body.get_node_or_null("FoodArt") as Node2D
	if visual:
		var p := visual.to_local(to_global(pos))
		if body.get_meta("cut", false):
			var polygon: PackedVector2Array = body.get_meta("fragment_polygon", PackedVector2Array())
			return Geometry2D.is_point_in_polygon(p, polygon)
		if str(body.get_meta("id", "")) == "noodles":
			return (p / Vector2(lerpf(27, 67, visual.softness) + 2, lerpf(18, 12, visual.softness) + 7)).length() <= 1.0
		var thermal: Dictionary = body.get_meta("thermal", {})
		if float(thermal.get("liquid_kg", 0.0)) > 0.000001:
			var initial := maxf(0.000001, float(thermal.initial_kg))
			var liquid := clampf(float(thermal.liquid_kg) / initial, 0.0, 1.0)
			if ((p - Vector2(0, 13)) / Vector2(22 + liquid * 19, 9 + liquid * 12)).length() <= 1.0: return true
			var solid := clampf(1.0 - (float(thermal.converted_kg) + float(thermal.evaporated_kg)) / initial, 0.0, 1.0)
			if solid < 0.025: return false
			p /= sqrt(solid)
		if str(body.get_meta("id", "")) == "egg" and bool(thermal.get("egg_opened", false)):
			return (p / Vector2(38, 24)).length() <= 1.0
		return preload("res://modules/restaurant/assets/sprite_library.gd").alpha_at(str(body.get_meta("id", "")), p) > 0.12
	visual = body.get_node_or_null("SauceBlob")
	if visual == null: return false
	var fullness := clampf(sqrt(float(visual.liquid_state.get("volume_ml", 3.0)) / 3.0), 0.55, 2.25)
	return (visual.to_local(to_global(pos)) / Vector2(13 * fullness, 11 * (0.72 + fullness * 0.28))).length() <= 1.0

func _update_food_depth() -> void:
	if not is_instance_valid(pan): return
	var bodies := _foods.get_children()
	# Stable painter order follows contact depth, never ingredient creation order.
	bodies.sort_custom(func(a, b): return a.position.y < b.position.y or (is_equal_approx(a.position.y, b.position.y) and a.get_instance_id() < b.get_instance_id()))
	for index in bodies.size():
		var body: Node2D = bodies[index]
		if body.get_index() != index: _foods.move_child(body, index)
		if body == _held or _dragging and body.collision_layer == 0: continue
		if body.get_meta("batch_carried", false):
			body.z_index = 20
			continue
		if body.get_meta("overflow", false): body.z_index = 6
		elif body.get_meta("plated", false): body.z_index = 0 if body.has_meta("liquid_state") else 1
		elif pan.contains(body.position): body.z_index = 0 if body.has_meta("liquid_state") else 1
		else: body.z_index = 6 if body.position.y > pan.point(Vector2(810, 617)).y else 1

func begin_food_drag(pointer: Vector2, from_storage: = false) -> void :
	_pending_drop = false
	if not controls_enabled or not is_instance_valid(_held): return
	_drag_group.clear()
	if from_storage:
		# A queued native drag can move the OS cursor before the press is handled.
		# Initialise a newly taken inventory body at the source press, not at that
		# later cursor position, so its grip does not acquire a huge false lever arm.
		_held.global_position = to_global(pointer)
		_held.linear_velocity = Vector2.ZERO
		_held.angular_velocity = 0.0
		_held.reset_physics_interpolation()
	# Carry the cut portion as a handful, retaining every fragment's own mass,
	# coating and collider. Shift deliberately selects a single slice.
	if not from_storage and bool(_held.get_meta("cut", false)) and _stations.chop.grow(12).has_point(_held.position) and not Input.is_key_pressed(KEY_SHIFT):
		var batch: String = str(_held.get_meta("batch_uid", ""))
		for part in _foods.get_children():
			if part == _held or part.is_queued_for_deletion() or not part.get_meta("on_board", false): continue
			if batch.is_empty() or str(part.get_meta("batch_uid", "")) != batch: continue
			part.stop_board_settle()
			_set_hand_support(part, true)
			part.set_meta("on_board", false)
			part.set_meta("batch_carried", true)
			part.freeze = false
			part.collision_layer = 0
			part.collision_mask = 1
			var hand = preload("res://modules/restaurant/world/physical_grip.gd").new()
			hand.begin(part, part.global_position)
			_drag_group.append({"body":part,"grip":hand,"offset":(part.position - _held.position).limit_length(65)})
		if not _drag_group.is_empty(): focus_changed.emit("切好的食材", "这一份一起拿起了。移到锅里松手；按住 Shift 可只拿一片。")
	_dragging = true
	_food_drag_origin = pointer
	_food_drag_from_storage = from_storage
	_food_drag_moved = false
	_food_drag_offset = Vector2.ZERO if from_storage else _held.global_position - to_global(pointer)
	held_grip.begin(_held, to_global(pointer))
	_move_dragged_food(pointer)

func _move_dragged_food(pointer: Vector2) -> void :
	if not _dragging or not is_instance_valid(_held): return
	if pointer.distance_to(_food_drag_origin) > 6: _food_drag_moved = true
	held_grip.target = to_global(pointer)
	_sync_held_foreground()

func _finish_food_drag(force: = false) -> void :
	var keep_carried: = _food_drag_from_storage and not _food_drag_moved and not force
	_dragging = false
	_food_drag_offset = Vector2.ZERO
	_food_drag_from_storage = false
	if not is_instance_valid(_held) or keep_carried: return
	if force: _pending_drop = false
	var hand_unsettled := _held.to_global(held_grip.local_anchor).distance_to(held_grip.target) > 35.0
	for member in _drag_group:
		var part: RigidBody2D = member.body
		if is_instance_valid(part) and (part.global_position.distance_to(member.grip.target) > 18.0 or part.linear_velocity.length() > 90.0):
			hand_unsettled = true
	if not force and hand_unsettled:
		# A fast queued drag may reach its end before the heavy body catches up.
		# Finish the bounded physical hand motion, never teleport or drop halfway.
		_pending_drop = true
		_pending_drop_elapsed = 0.0
		return
	if not force and _held.global_position.distance_to(held_grip.target)<35.0 and storage_return_handler.is_valid() and storage_return_handler.call(_held):
		_stop_squeezing()
		_drag_group.clear()
		return
	var point: = to_local(_held.global_position)
	if lid.covered and (pan.contains(point) or lid.blocks(point)):
		interaction.emit("notice", "先揭开锅盖，再放入食材或调味。")
		return
	if not force and _held_is_sauce_bottle() and _squeeze_region().has_point(point):
		interaction.emit("notice", "调料已拿到锅边。" + get_held_operation_hint())
		return
	if _is_whole_egg(_held) and _egg_tap_target(to_local(held_grip.target)) and _food_drag_moved:
		_tap_egg(to_local(held_grip.target))
		_drag_group.clear()
		return

	# Release the touched fragment at its contact pose and velocity.
	drop_held(false, false)
	_release_drag_group()

func _release_drag_group() -> void :
	for member in _drag_group:
		var body: RigidBody2D = member.get("body")
		if not is_instance_valid(body): continue
		member.grip.release()
		_set_hand_support(body, false)
		body.set_meta("batch_carried", false)
		body.collision_layer = 32 if bool(body.get_meta("dispensed", false)) else 16
		body.collision_mask = 17
		body.freeze = false
		body.sleeping = false
		body.z_index = 0
		body.linear_velocity = body.linear_velocity.limit_length(120) + Vector2(0, 12)
		body.angular_velocity = clampf(body.angular_velocity, -2, 2)
		if _stations.chop.has_point(body.position):
			body.position = body.position.clamp(_board_food_min(), _board_food_max())
			body.freeze = true
			body.set_meta("on_board", true)
			body.linear_velocity = Vector2.ZERO
		elif is_instance_valid(plate) and plate.hit_rect().has_point(body.position):
			_land_on_plate(body)
		else:
			body.set_meta("on_board", false)
	_drag_group.clear()

func _pickup(body: RigidBody2D) -> void :
	if is_instance_valid(_held) or _knife_held or has_active_utensil() or pan.active:
		return
	body.stop_board_settle()
	_set_hand_support(body, true)
	body.reset_motion_sample()
	if bool(body.get_meta("enrolled", false)):
		food_removed_from_pan.emit(body)
		body.set_meta("enrolled", false)
	body.set_meta("plated", false)
	body.set_meta("on_board", false)
	_update_plated_flag()
	body.set_meta("pending", false)
	body.freeze = false
	body.collision_layer = 16
	body.collision_mask = 1 if bool(body.get_meta("dispensed", false)) else 17
	body.z_index = 20
	_held = body
	held_grip.begin(body, body.global_position)
	var sauce = body.get_node_or_null("SauceBlob")
	if is_instance_valid(sauce):
		sauce.position = Vector2.ZERO
		sauce.scale = Vector2.ONE
		sauce.rotation = 0
	_sync_held_foreground()
	held_changed.emit(str(body.get_meta("title", "食材")))
	if _held_is_sauce_bottle():
		focus_changed.emit(get_held_name(), get_held_operation_hint())

func drop_held(throw_item: = false, allow_storage_return := true) -> void :
	_pending_drop = false
	_dragging = false
	_food_drag_offset = Vector2.ZERO
	if not is_instance_valid(_held):
		return
	if lid.covered and (pan.contains(_held.position) or lid.blocks(_held.position)):
		interaction.emit("notice", "锅盖挡住了锅口，先把盖子拖开。")
		return
	_stop_squeezing()
	if allow_storage_return and storage_return_handler.is_valid() and storage_return_handler.call(_held): return
	var body: = _held
	_set_hand_support(body, false)
	_held = null
	_sync_held_foreground()
	body.collision_layer = 32 if bool(body.get_meta("dispensed", false)) else 16
	body.freeze = false
	body.sleeping = false
	body.z_index = 0
	held_grip.release()
	body.set_deferred("global_position", body.global_position)
	if _stations.chop.has_point(body.position) and not body.get_meta("is_container", false):
		body.position = body.position.clamp(_board_food_min(), _board_food_max())
		body.set_deferred("position", body.position)
		body.freeze = true
		body.set_meta("on_board", true)
		# Keep the hand's bounded release momentum on the board's perspective
		# support plane. Previously every board drop discarded all velocity.
		var release_velocity := body.linear_velocity.limit_length(180.0) * 0.26
		var release_spin := body.angular_velocity
		body.linear_velocity = Vector2.ZERO
		body.begin_board_settle(Rect2(_board_food_min(), _board_food_max() - _board_food_min()), release_velocity, release_spin, 10.0)
	if is_instance_valid(plate) and plate.hit_rect().has_point(body.position) and not body.get_meta("is_container", false):
		_land_on_plate(body)
	if throw_item:
		body.linear_velocity += _mouse_velocity.limit_length(260.0) * 0.35
	_release_drag_group()
	held_changed.emit("")

func drop_into_pan() -> void :
	if lid.covered:
		interaction.emit("notice", "先揭开锅盖，再往锅里放食材。")
		return
	if not is_instance_valid(_held):
		return
	# Pick a clear part of the pan for the keyboard shortcut. Random releases
	# near its center can make two whole ingredients collide before landing.
	var drop_x := 770.0
	var clearance := -1.0
	for candidate in [770.0, 850.0, 810.0]:
		var nearest := INF
		for body in _foods.get_children():
			if body == _held or body.is_queued_for_deletion() or body.get_meta("plated", false) or body.get_meta("is_container", false) or not pan.contains(body.position): continue
			nearest = minf(nearest, absf(pan.local_point(body.position).x - candidate))
		if nearest > clearance:
			clearance = nearest
			drop_x = candidate
	if not _drag_group.is_empty():
		held_grip.target = to_global(pan.point(Vector2(810, 520)))
		_finish_food_drag()
		return
	_held.global_position = pan.point(Vector2(drop_x, 521))
	drop_held(false)

func _is_whole_egg(body: RigidBody2D) -> bool:
	return is_instance_valid(body) and str(body.get_meta("id", "")) == "egg" and not bool(body.get_meta("thermal", {}).get("egg_opened", false))

func _egg_tap_target(point: Vector2) -> bool:
	# Cracking uses the open upright rim, independently of the burner beneath it.
	if lid.covered or pan.active or pan.falling or absf(wrapf(pan.angle,-PI,PI))>0.35: return false
	var local: Vector2 = pan.local_point(point)
	# The visible opening, including its rim, accepts an intentional egg gesture.
	# No hidden 39-pixel back-edge target or second-click timing requirement.
	var geometry = preload("res://modules/restaurant/world/pan_geometry.gd")
	return ((local - geometry.CENTER) / (geometry.RADIUS + Vector2(12,18))).length() <= 1.0

func _tap_egg(point: Vector2) -> void:
	if not _is_whole_egg(_held) or not _egg_tap_target(point): return
	if _held.get_meta("egg_opening", false): return
	var egg: RigidBody2D = _held
	egg.set_meta("egg_opening", true)
	egg.set_meta("egg_taps", 1)
	_dragging = false
	_pending_drop = false
	var strike: Vector2 = pan.point(Vector2(clampf(pan.local_point(point).x,754,865),542))
	egg.set_meta("egg_tap_point", strike)
	held_grip.target = to_global(strike)
	var art := egg.get_node_or_null("FoodArt")
	if art: art.set("crack_progress", 1.0)
	audio.play_effect("egg_crack")
	_sync_held_foreground()
	interaction.emit("notice", "敲开了，蛋液落进锅里。")
	# A single deliberate tap has a visible fissure, then opens automatically.
	get_tree().create_timer(0.18).timeout.connect(func():
		if is_instance_valid(egg) and not egg.is_queued_for_deletion() and _held == egg:
			_crack_egg(egg.position)
	)

func _crack_egg(point: Vector2) -> void:
	var body: RigidBody2D = _held
	if not is_instance_valid(body): return
	var total_mass := body.mass
	var shell_mass := total_mass * 0.12
	var edible_mass := total_mass - shell_mass
	var source_uid := str(body.get_meta("instance_uid", ""))
	var state: Dictionary = reactions.ensure_state(body)
	state = preload("res://modules/restaurant/domain/food_thermal.gd").split_state(state, edible_mass / total_mass)
	state["egg_opened"] = true
	state["egg_white_set"] = 0.0
	state["egg_yolk_set"] = 0.0
	body.mass = edible_mass
	body.set_meta("source_egg_mass_kg", total_mass)
	body.set_meta("shell_mass_kg", shell_mass)
	body.set_meta("egg_taps", 1)
	body.set_meta("thermal", state)
	for side in [-1, 1]:
		var shell := preload("res://modules/restaurant/world/egg_shell_piece.gd").new()
		shell.mass = shell_mass * 0.5
		shell.side = side
		shell.set_meta("source_uid", source_uid)
		shell.set_meta("source_egg_mass_kg", total_mass)
		_egg_shells.add_child(shell)
		# Flick the emptied halves onto the spare counter to the left of the
		# skillet. Their flight is animated; the same mass-bearing bodies settle
		# under gravity once they clear the pan rim.
		shell.launch(point + Vector2(side * 8.0, -8.0), Vector2(557.0 if side < 0 else 584.0, 690.0))
	_dragging = false
	_held = null
	held_grip.release()
	_sync_held_foreground()
	held_changed.emit("")
	body.position = pan.point(Vector2(809, 583))
	body.set_deferred("position", body.position)
	body.freeze = true
	body.set_meta("egg_cracking", true)
	body.collision_layer = 0
	body.collision_mask = 0
	body.rotation = 0
	body.angular_velocity = 0
	body.linear_velocity = Vector2.ZERO
	# The opened egg uses its spreading white's support shape, never the old
	# upright shell collider which buried the yolk behind the pan front.
	var egg_shape := ConvexPolygonShape2D.new()
	var egg_outline := PackedVector2Array()
	for i in 24: egg_outline.append(Vector2.from_angle(i * TAU / 24.0) * Vector2(38,17))
	egg_shape.points = egg_outline
	body.get_node("CollisionShape2D").set_deferred("shape", egg_shape)
	body.set_meta("fragment_polygon", egg_outline)
	body.set_meta("thermal_shape", Vector2.ONE)
	body.z_index = 6
	var art := body.get_node_or_null("FoodArt")
	if art: art.visible = false
	var effect := preload("res://modules/restaurant/world/egg_crack_effect.gd").new()
	effect.origin = point
	effect.target = body.position
	effect.z_index = 12
	add_child(effect)
	effect.finished.connect(func() -> void:
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			body.set_meta("egg_cracking", false)
			reactions._apply(body, state)
			if is_instance_valid(art): art.visible = true
			body.collision_layer = 16
			body.collision_mask = 17
			body.freeze = not controls_enabled
			if not controls_enabled: body.set_meta("modal_freeze", false)
			body.sleeping = false
			body.linear_velocity = Vector2(0, 20)
			body.z_index = 0
			if pan.contains(body.position): _on_pan_entered(body)
			audio.play_food_drop(body)
	)
	interaction.emit("notice", "蛋白还透明，开中火慢慢煎。")

func chop_held() -> void :

	if not is_instance_valid(_held): return
	_held.position = Vector2(1210, 735)
	drop_held(false)
	interaction.emit("notice", "食材已完整放在菜板上，请拿刀切开。")

func _on_pan_entered(body: Node2D) -> void :
	if body.is_queued_for_deletion(): return
	if body.get_meta("batch_carried", false) or body.get_meta("egg_cracking", false): return
	if body.get_meta("overflow", false): return
	if body is RigidBody2D and body != _held and bool(body.get_meta("is_container", false)):
		if not body.get_meta("container_notice", false):
			body.set_meta("container_notice", true)
			interaction.emit("notice", "容器里还没出料。拿起后移到锅上方，按住左键撒、倒或挤。")
		return
	if body is RigidBody2D and body.has_meta("id") and body != _held and not bool(body.get_meta("plated", false)) and not bool(body.get_meta("is_container", false)):
		if not bool(body.get_meta("enrolled", false)) and not bool(body.get_meta("pending", false)):
			body.set_meta("pending", true)
			food_entered_pan.emit(str(body.get_meta("id")), bool(body.get_meta("cut", false)), body)

func _on_pan_exited(body: Node2D) -> void :
	if body.get_meta("enrolled", false) and absf(pan.angle) > 0.3: body.set_meta("poured", true)
	if pan.is_carrying(body): return
	# The pan and rigid bodies update in different physics phases. Area exit
	# signals can arrive while a carried body still has its previous pose.
	# Recheck once transport settles; a genuinely spilled body is removed then.
	if pan.transporting() and not bool(body.get_meta("poured", false)): return
	if pan.contains(body.position): return
	if body is RigidBody2D and utensil_holds(body):
		body.set_meta("container_location", "spoon")
		return
	if float(body.get_meta("stir_until", 0)) > _time and absf(body.position.x - pan.point(Vector2(809, 599)).x) < 135: return
	if body is RigidBody2D and bool(body.get_meta("enrolled", false)) and not bool(body.get_meta("plated", false)):
		body.set_meta("enrolled", false)
		body.set_meta("pending", false)
		body.collision_mask = 1 if bool(body.get_meta("dispensed", false)) else 17
		food_removed_from_pan.emit(body)

func accept_food(body: RigidBody2D, accepted: bool) -> void :
	if not is_instance_valid(body):
		return
	body.set_meta("pending", false)
	body.set_meta("enrolled", accepted)
	if accepted:
		if not body.get_meta("plated", false):
			pan.residue.transfer_to_food(body)
			body.set_meta("residue_deposited", false)
		body.set_meta("container_location", "pan")
		# Independent solids contact one another; liquid batches stay non-solid.
		# Cut batches use distinct starting positions to avoid coincident contacts.
		body.collision_mask = 1 if body.has_meta("liquid_state") else 17
	if not accepted:
		body.set_meta("rejected", true)
		if bool(body.get_meta("dispensed", false)):
			_stop_squeezing()
		body.set_deferred("global_position", Vector2(620, 680))
		body.set_deferred("linear_velocity", Vector2(-40, -20))

func _board_food_min() -> Vector2:
	return _stations.chop.position + Vector2(28, 24)

func _board_food_max() -> Vector2:
	return _stations.chop.end - Vector2(28, 24)

func set_dish(entries: Array, _ingredient_defs: Array) -> void :
	for entry in entries:
		if not entry is Dictionary:
			continue
		var physics_id: = int(entry.get("physics_id", 0))
		if physics_id > 0 and is_instance_id_valid(physics_id):
			var body = instance_from_id(physics_id)
			if is_instance_valid(body):
				if body.has_meta("thermal"):
					entry["heat"] = preload("res://modules/restaurant/domain/food_thermal.gd").legacy_heat(body.get_meta("thermal"))
					entry["softness"] = float(body.get_meta("softness",0.0))
				body.set_meta("cooking_heat", float(entry.get("heat", 0.0)))
				var art = body.get_node_or_null("FoodArt")
				if art:
					art.set("heat", float(entry.get("heat", 0)))
					art.set("cut", bool(entry.get("cut", false)))
					art.set("softness", float(entry.get("softness", 0.0)))
				if str(entry.get("id", "")) == "noodles":
					body.set_meta("hydration", float(entry.get("hydration", 0.0)))
					body.set_meta("softness", float(entry.get("softness", 0.0)))
					_apply_noodle_collision(body, float(entry.get("softness", 0.0)))
				if body.has_meta("liquid_state") and body.get_node_or_null("SauceBlob"):
					body.get_node("SauceBlob").set("liquid_state", body.get_meta("liquid_state"))

func describe_body(body: RigidBody2D) -> Dictionary:
	var state: = {
		"instance_uid": str(body.get_meta("instance_uid", "food_%s" % body.get_instance_id())),
		"batch_uid": str(body.get_meta("batch_uid", body.get_meta("instance_uid", "food_%s" % body.get_instance_id()))),
		"mass_kg": body.mass,
		"lineage": body.get_meta("lineage", []).duplicate(true),
		"container": str(body.get_meta("container_location", "worktop")),
		"surface_sauce": body.get_meta("surface_sauce", {}).duplicate(true)
	}
	state["pan_carryover"] = body.get_meta("pan_carryover", {}).duplicate(true)
	if body.has_meta("thermal"): state["thermal"] = body.get_meta("thermal").duplicate(true)
	state["cut_style"] = str(body.get_meta("cut_style", "whole"))
	state["source_fraction"] = float(body.get_meta("source_fraction", 1.0))
	var polygon: PackedVector2Array = body.get_meta("fragment_polygon", PackedVector2Array())
	var encoded: Array = []
	for point in polygon: encoded.append([snappedf(point.x, 0.01), snappedf(point.y, 0.01)])
	state["geometry"] = encoded
	if str(body.get_meta("definition", {}).get("id", "")) == "noodles":
		state["hydration"] = float(body.get_meta("hydration", 0.0))
		state["softness"] = float(body.get_meta("softness", 0.0))
	if body.has_meta("liquid_state"):
		state["liquid_state"] = body.get_meta("liquid_state").duplicate(true)
		state["volume_ml"] = float(body.get_meta("liquid_state", {}).get("volume_ml", 0.0))
	return state

func synchronize_body_state(body: RigidBody2D, entry: Dictionary) -> void :
	if not is_instance_valid(body): return

	var hydration: = float(entry.get("hydration", body.get_meta("hydration", 0.0)))
	var softness: = float(entry.get("softness", body.get_meta("softness", 0.0)))
	entry.merge(describe_body(body), true)
	entry["cut"] = bool(body.get_meta("cut", false))
	entry["heat"] = float(entry.get("heat", body.get_meta("saved_heat", 0.0)))
	if body.has_meta("thermal"):
		entry["heat"] = preload("res://modules/restaurant/domain/food_thermal.gd").legacy_heat(body.get_meta("thermal"))
		hydration = float(body.get_meta("hydration",0.0))
		softness = float(body.get_meta("softness",0.0))
	entry["hydration"] = hydration
	entry["softness"] = softness
	body.set_meta("hydration", hydration)
	body.set_meta("softness", softness)

func _apply_noodle_collision(body: RigidBody2D, softness: float) -> void :
	softness = clampf(softness, 0.0, 1.0)
	if absf(softness - float(body.get_meta("collision_softness", -1.0))) < 0.04:
		return
	var collision: = body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not is_instance_valid(collision): return
	var shape: = ConvexPolygonShape2D.new()
	var points: = PackedVector2Array()
	var radius: = Vector2(lerpf(18.0, 50.0, softness), lerpf(18.0, 11.0, softness))
	for index in 16:
		var phase: = float(index) * TAU / 16.0
		points.append(Vector2(cos(phase) * radius.x, sin(phase) * radius.y))
	shape.points = points
	collision.set_deferred("shape", shape)
	body.set_meta("collision_softness", softness)

func utensil_holds(body: RigidBody2D) -> bool:
	for utensil in utensils:
		if utensil.kind == "spoon" and utensil.bowl_contains(body): return true
	return false

func set_plated(value: bool) -> void :
	if not value:
		return_to_pan()
		return
	var index: = 0
	for body in _foods.get_children():
		if bool(body.get_meta("enrolled", false)):
			leave_pan_residue(body)
			body.set_meta("plated", true)
			body.freeze = true
			body.global_position = plate.center + Vector2(-60 + float(index % 4) * 40, - float(index / 4) * 15)
			index += 1
	_update_plated_flag()

func return_to_pan() -> void :

	cooking = false
	var index: = 0
	for body in _foods.get_children():
		if not bool(body.get_meta("plated", false)):
			continue
		if bool(body.get_meta("enrolled", false)):

			food_removed_from_pan.emit(body)
		body.set_meta("enrolled", false)
		body.set_meta("pending", false)
		body.set_meta("plated", false)
		body.collision_layer = 32 if bool(body.get_meta("dispensed", false)) else 16
		body.global_position = pan.point(Vector2(760 + float(index % 3) * 49, 521 - float(index / 3) * 48))
		body.set_deferred("position", body.position)
		body.linear_velocity = Vector2(0, 20)
		body.angular_velocity = 0
		body.freeze = false
		body.sleeping = false

		if not controls_enabled:
			body.set_meta("modal_freeze", false)
			body.freeze = true
		elif body.has_meta("modal_freeze"):
			body.remove_meta("modal_freeze")
		index += 1
	_update_plated_flag()

func _update_plated_flag() -> void :
	plated = false
	for body in _foods.get_children():
		if bool(body.get_meta("plated", false)) and bool(body.get_meta("enrolled", false)):
			plated = true
			return

func set_cooking(value: bool) -> void :
	if value and is_instance_valid(material_play) and material_play.power_out: value = false
	if cooking != value and is_instance_valid(audio) and controls_enabled: audio.play_effect("ignite" if value else "tap")
	cooking = value

func set_heat_level(value: String) -> void :
	if value in ["low", "medium", "high"]:
		heat_level = value

func set_customer(customer: Dictionary) -> void :
	_customer = customer.duplicate()

func clear_food() -> void :
	pan.water_ml = 0
	pan.water_heat = 0
	pan.overflow_water_ml = 0
	for body in _foods.get_children():
		if bool(body.get_meta("enrolled", false)):
			body.set_meta("enrolled", false)
			body.queue_free()
	plated = false

func clear_workspace() -> void:
	_pending_drop = false
	_dragging = false
	held_grip.release()
	_drag_group.clear()
	if is_instance_valid(material_play): material_play.reset_effects()
	pan.water_ml = 0
	pan.water_heat = 0
	pan.overflow_water_ml = 0
	pan._carried.clear()
	pan.rim_water_ml = 0.0
	pan.runoff.clear()
	if is_instance_valid(sponge): sponge.absorbed_ml = 0.0
	for body in _foods.get_children():
		if body == _held:
			_held = null
		body.set_meta("enrolled", false)
		body.queue_free()
	for shell in _egg_shells.get_children():
		shell_waste_kg += shell.mass
		shell.queue_free()
	plated = false
	held_changed.emit("")

func discard_held() -> bool:
	_pending_drop = false
	if not is_instance_valid(_held):
		return false
	_stop_squeezing()
	_dragging = false
	held_grip.release()
	for member in _drag_group:
		member.grip.release()
		if is_instance_valid(member.body): member.body.queue_free()
	_drag_group.clear()
	audio.play_effect("drop")
	_held.queue_free()
	_held = null
	_sync_held_foreground()
	held_changed.emit("")
	return true

func get_held_name() -> String:
	if is_instance_valid(lid) and lid.active: return "锅盖"
	if is_instance_valid(sponge) and sponge.active: return "清洁海绵"
	if is_instance_valid(cloth) and cloth.active: return "抹布"
	for utensil in utensils:
		if utensil.active: return utensil.title
	if _knife_held:
		return "主厨刀 · 顺箭头拖动切菜；R 转刀，滚轮微调；Q 归位"
	return str(_held.get_meta("title", "")) if is_instance_valid(_held) else ""

func show_notice(_message: String) -> void :
	pass

func get_station_position(action: String) -> Vector2:
	return _stations[action].get_center() if _stations.has(action) else Vector2.ZERO

func aim_at_station(_action: String) -> void :
	pass

func _static_box(pos: Vector2, dimensions: Vector2) -> void :
	var body: = StaticBody2D.new()
	body.position = pos
	var collision: = CollisionShape2D.new()
	var shape: = RectangleShape2D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _static_segment(from: Vector2, to: Vector2, pan_wall: = true) -> void :
	var body: = StaticBody2D.new()
	if not pan_wall and is_equal_approx(from.y, 718.0) and is_equal_approx(to.y, 718.0): body.set_meta("counter_support", true)
	var collision: = CollisionShape2D.new()
	var shape: = SegmentShape2D.new()
	shape.a = from
	shape.b = to
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	if pan_wall: _pan_walls.append(body)

func _set_hand_support(body: RigidBody2D, carried: bool) -> void:
	# The board lies on a projected work surface below the counter's front lip.
	# A lifted hand is above that plane, so its slices must not strike its underside.
	for support in get_children():
		if support is StaticBody2D and support.get_meta("counter_support", false):
			if carried: body.add_collision_exception_with(support)
			else: body.remove_collision_exception_with(support)

func pan_rect() -> Rect2:
	return pan.transform_pan() * Rect2(704, 551, 222, 103)

func _held_is_sauce_bottle() -> bool:

	return is_instance_valid(_held) and bool(_held.get_meta("is_container", false))

func get_dispense_mode(definition: Dictionary) -> String:
	var mode: = str(definition.get("dispense_mode", ""))
	if mode in ["powder", "pour", "squeeze"]:
		return mode

	return "squeeze" if str(definition.get("id", "")) == "ketchup" else ""

func ingredient_operation_hint(definition: Dictionary) -> String:
	if str(definition.get("id", "")) == "egg":
		return "把鸡蛋移到锅口，松手敲开；蛋液入锅，壳留在台面"
	var mode: = get_dispense_mode(definition)
	if mode.is_empty():
		if not bool(definition.get("cuttable", true)):
			return "硬质奇物，菜刀切不开；可以整件放入锅中实验"
		return "拖到砧板切配，或拖入锅中；松手放下"
	var action: String = {"powder": "撒粉", "pour": "倾倒", "squeeze": "挤酱"}[mode]
	return "移到锅上方，按住左键持续%s；松开停止" % action

func get_held_operation_hint() -> String:
	if _knife_held:
		return "顺箭头让刀刃标记划过食材；R 转刀，滚轮微调；松手放下"
	if is_instance_valid(_held) and _is_whole_egg(_held) and int(_held.get_meta("egg_taps", 0)) == 1:
		return "蛋壳裂开了，正在流入锅里"
	return ingredient_operation_hint(_held.get_meta("definition", {})) if is_instance_valid(_held) else ""

func _sync_held_foreground() -> void :
	if not is_instance_valid(_held_foreground):
		return
	var source: Node2D
	if is_instance_valid(_held):
		source = _held.get_node_or_null("FoodArt")
		if not is_instance_valid(source):
			source = _held.get_node_or_null("SauceBlob")
	if not is_instance_valid(source):
		storage_pickup_view.clear()


		if is_instance_valid(_held_proxy_source):
			_held_proxy_source.visible = true
		if is_instance_valid(_held_proxy):
			_held_foreground.remove_child(_held_proxy)
			_held_proxy.queue_free()
		_held_proxy = null
		_held_proxy_source = null
		_held_foreground.visible = false
		if not is_instance_valid(_held):
			_held = null
			_stop_squeezing()
		_held_foreground.queue_redraw()
		return
	if source != _held_proxy_source:
		if is_instance_valid(_held_proxy_source):
			_held_proxy_source.visible = true
		if is_instance_valid(_held_proxy):
			_held_foreground.remove_child(_held_proxy)
			_held_proxy.queue_free()
			_held_proxy = null
		_held_proxy_source = source
		if is_instance_valid(source):
			_held_proxy = Node2D.new()
			_held_proxy.set_script(source.get_script())

			for property in source.get_property_list():
				var property_name: = str(property.name)
				if property_name in ["definition", "cut", "heat", "softness", "thermal", "coating", "shadows", "polygon", "art_offset", "dispense_mode", "liquid_state", "cut_style", "cut_variant", "source_fraction", "crack_progress", "flex", "dangling", "motion_time"]:
					_held_proxy.set(property_name, source.get(property_name))
			_held_proxy.z_index = 1
			_held_foreground.add_child(_held_proxy)
	if is_instance_valid(source) and is_instance_valid(_held_proxy):
		source.visible = false
		_held_proxy.transform = source.get_global_transform_with_canvas() * _container_art_transform()
		if "storage_clip" in _held_proxy:
			_held_proxy.storage_clip = Rect2(-10000, -10000, 20000, 20000)
			if not storage_pickup_view.is_empty():
				var progress := smoothstep(0.0, 0.24, _storage_lift_time)
				_held_proxy.transform = (storage_pickup_view.transform as Transform2D).interpolate_with(_held_proxy.transform, progress)
				var aperture: Rect2 = storage_pickup_view.opening
				# Width opens as the object is drawn toward the player, but the front
				# lip must not retreat downward just because an animation timer passed.
				aperture = aperture.grow_individual(100.0 * progress, 150.0 * progress, 100.0 * progress, 0.0)
				_held_proxy.storage_clip = _held_proxy.transform.affine_inverse() * aperture

		for property_name in ["cut", "heat", "softness", "compression", "thermal", "coating", "crack_progress", "flex", "dangling", "motion_time"]:
			if property_name in source:
				_held_proxy.set(property_name, source.get(property_name))
	_held_foreground.visible = controls_enabled and is_instance_valid(source)
	_held_foreground.queue_redraw()

func _draw_dispensing_stream(target: Node2D, in_world := false) -> void :
	if not controls_enabled or not _squeezing or not is_instance_valid(_held):
		return
	var definition: Dictionary = _held.get_meta("definition", {})
	var mode: = get_dispense_mode(definition)
	var color: = Color.from_string(str(definition.get("color", "d96143")), Color("d96143"))
	var nozzle_world: = _nozzle_world_position()
	var canvas_transform: = Transform2D.IDENTITY if in_world else get_global_transform_with_canvas()
	var nozzle: = canvas_transform * to_local(nozzle_world)
	var surface: Vector2 = pan.point(Vector2(810, lerpf(597, 574, pan_fill_ratio())))
	var endpoint := Vector2(to_local(nozzle_world).x, surface.y)
	var start := to_local(nozzle_world)
	# Terminate the visible stream at the first solid surface, not through it.
	for body in _foods.get_children():
		if body == _held or body.is_queued_for_deletion() or body.has_meta("liquid_state") or not body.get_meta("enrolled", false) or body.get_meta("plated", false): continue
		var polygon: PackedVector2Array = body.get_meta("fragment_polygon", PackedVector2Array())
		var deform: Vector2 = body.get_meta("thermal_shape", Vector2.ONE)
		for i in polygon.size():
			var a := to_local(body.to_global(polygon[i] * deform))
			var b := to_local(body.to_global(polygon[(i + 1) % polygon.size()] * deform))
			var crossing = Geometry2D.segment_intersects_segment(start, endpoint, a, b)
			if crossing != null: endpoint = crossing
	var end := canvas_transform * endpoint
	var drawing_scale: = canvas_transform.get_scale().abs().x
	if nozzle.y >= end.y:
		return
	if mode != "powder":
		target.draw_line(nozzle, end, color.darkened(0.12), (3.0 if mode == "pour" else lerpf(1.5, 6.5, squeeze_pressure)) * drawing_scale, false)
	var count: = 18 if mode == "powder" else 5
	for index in range(count):
		var phase: = fmod(_time * 2.5 + float(index) / float(count), 1.0)
		var point: = nozzle.lerp(end, phase)
		if mode == "powder":
			point.x += sin(index * 13.37) * (3.0 + 17.0 * phase) * drawing_scale
			target.draw_rect(Rect2(point, Vector2(2.0 + index % 2, 2.0) * drawing_scale), color.lightened(float(index % 3) * 0.08))
		else:
			var width: = 3.0 if mode == "pour" else 5.0
			target.draw_colored_polygon(PackedVector2Array([point + Vector2(0, -5) * drawing_scale, point + Vector2(width, 2) * drawing_scale, point + Vector2(0, 5) * drawing_scale, point + Vector2( - width, 2) * drawing_scale]), color.lightened(0.12))

func _squeeze_region() -> Rect2:
	return pan.transform_pan() * Rect2(692, 420, 238, 215)

func _nozzle_world_position() -> Vector2:
	if not is_instance_valid(_held): return Vector2.ZERO
	var def: Dictionary = _held.get_meta("definition", {})
	var art = preload("res://modules/restaurant/assets/sprite_library.gd")
	var entry: Dictionary = art.handdrawn_manifest().get(str(def.get("id", "")), {})
	var source := _held.get_node_or_null("FoodArt") as Node2D
	var displayed := source.global_transform * _container_art_transform() if source != null else Transform2D.IDENTITY
	if not storage_pickup_view.is_empty() and is_instance_valid(_held_proxy):
		displayed = get_canvas_transform().affine_inverse() * _held_proxy.transform
	if entry.has("nozzle_uv") and source != null:
		var texture: Texture2D = art.food(str(def.id))
		var rect: Rect2 = art.fit(texture, Vector2.ZERO, Vector2(78, 78))
		var uv: Array = entry.nozzle_uv
		return displayed * (rect.position + rect.size * Vector2(uv[0], uv[1]))
	if source != null:
		var texture: Texture2D = art.food(str(def.get("id", "")))
		if texture != null:
			var rect: Rect2 = art.fit(texture, Vector2.ZERO, Vector2(78,78))
			return displayed * Vector2(rect.get_center().x, rect.position.y)
	return _held.global_position

func _container_art_transform() -> Transform2D:
	if not is_instance_valid(_held): return Transform2D.IDENTITY
	if not _squeezing: return Transform2D(_held.feedback_angle, Vector2.ZERO)
	var definition: Dictionary = _held.get_meta("definition", {})
	var entry: Dictionary = preload("res://modules/restaurant/assets/sprite_library.gd").handdrawn_manifest().get(str(definition.get("id", "")), {})
	# Top-opening bottles turn toward the pan; the authored mustard tube is
	# already cap-down. The stream uses this exact same visual transform.
	var angle := PI if not entry.has("nozzle_uv") or float(entry.nozzle_uv[1]) < 0.5 else 0.0
	# Side-opening authored tubes need their own calibrated mouth direction.
	if entry.has("dispense_rotation_degrees"): angle = deg_to_rad(float(entry.dispense_rotation_degrees))
	# Local grip mesh deformation happens inside FoodArt; nozzle/cap stay fixed.
	return Transform2D(angle + _held.feedback_angle, Vector2.ZERO)

func _stop_squeezing() -> void :
	_squeezing = false
	_squeeze_elapsed = 0.0
	_squeeze_dispensed = false
	_squeeze_distance = 0.0
	if is_instance_valid(_held): held_grip.target_angle = 0.0

func _dispense_ketchup() -> void :

	_dispense_seasoning()

func _pan_capacity_used() -> int:
	var count: = 0
	for body in _foods.get_children():
		if body.is_queued_for_deletion() or body == _held or bool(body.get_meta("is_container", false)) or body.get_meta("overflow", false):
			continue
		if bool(body.get_meta("enrolled", false)) or bool(body.get_meta("pending", false)):
			count += 1
		elif bool(body.get_meta("dispensed", false)) and not bool(body.get_meta("rejected", false)) and Rect2(Vector2(704, 400) + pan.offset, Vector2(222, 245)).has_point(body.global_position):

			count += 1
	return count

func _dispense_seasoning(requested_ml: float = -1.0) -> RigidBody2D:
	if lid.covered:
		_stop_squeezing()
		interaction.emit("notice", "先揭开锅盖，再加入调味料。")
		return null
	if not _held_is_sauce_bottle() or not controls_enabled:
		return null
	if is_zero_approx(requested_ml): return null
	if _foods.get_child_count() >= 64:
		_stop_squeezing()
		interaction.emit("notice", "台面太满了，先清理一些食材。")
		return null
	var definition: Dictionary = _held.get_meta("definition", {}).duplicate(true)
	var id: = str(definition.get("id", "ketchup"))
	var mode: = get_dispense_mode(definition)
	var default_ml: = maxf(0.2, float(definition.get("dispense_mass", 0.035)) * 1000.0)
	var volume_ml: = default_ml if requested_ml < 0.0 else requested_ml
	var remaining_ml: = float(_held.get_meta("remaining_ml", definition.get("container_ml", 240.0)))
	volume_ml = minf(volume_ml, remaining_ml)
	if volume_ml <= 0.001:
		_stop_squeezing()
		interaction.emit("notice", "%s已经挤空了。" % definition.get("name", "容器"))
		return null
	_held.set_meta("remaining_ml", maxf(0.0, remaining_ml - volume_ml))
	_held.refresh_response()
	var source_uid: = str(_held.get_meta("instance_uid", id + "_container"))
	var liquid_state: = SauceState.make_batch(definition, volume_ml, source_uid, squeeze_pressure)
	var excess := maxf(0.0, volume_ml - pan_free_ml())
	var spill: RigidBody2D
	if excess > 0.001:
		var overflow_state := SauceState.make_batch(definition, 0.0, source_uid, squeeze_pressure)
		SauceState.transfer(liquid_state, overflow_state, excess)
		spill = _add_overflow(definition, overflow_state, pan.point(Vector2(920, 643)))
		_overflow_until = _time + 0.35
		_overflow_color = Color(str(definition.get("color", "c68b57")))
	volume_ml = float(liquid_state.get("volume_ml", 0.0))
	if volume_ml <= 0.001: return spill
	var matching: Array = []
	for existing in _foods.get_children():
		if not existing.is_queued_for_deletion() and existing.get_meta("dispensed", false) and not existing.get_meta("overflow", false) and not existing.get_meta("rejected", false) and not existing.get_meta("plated", false) and existing.get_meta("id", "") == id and (existing.get_meta("enrolled", false) or existing.get_meta("container_location", "") == "air"): matching.append(existing)
	if matching.size() >= 6:
		matching.sort_custom(func(a, b): return absf(a.position.x - _nozzle_world_position().x) < absf(b.position.x - _nozzle_world_position().x))
		var target: RigidBody2D = matching[0]
		target.visible=true
		target.collision_layer=32
		target.collision_mask=1
		var state: Dictionary = target.get_meta("liquid_state")
		SauceState.merge_into(state, liquid_state, 0.0)
		target.set_meta("volume_ml", state.volume_ml)
		target.mass += volume_ml * float(definition.get("density_g_ml", 1.03)) / 1000.0
		target.get_node("SauceBlob").liquid_state = state
		target.get_node("SauceBlob").queue_redraw()
		return target
	var body: = preload("res://modules/restaurant/world/food_body.gd").new()
	body.name = id.capitalize().replace("_", "") + "Portion"
	body.mass = maxf(0.000000000001, volume_ml * float(definition.get("density_g_ml", 1.03)) / 1000.0)


	body.collision_layer = 32
	body.collision_mask = 1
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.linear_damp = 1.5
	body.angular_damp = 2.0
	var material: = PhysicsMaterial.new()
	material.friction = 0.55 if mode == "pour" else 0.95
	material.bounce = 0.0
	body.physics_material_override = material
	body.set_meta("id", id)
	var action: String = {"powder": "撒出", "pour": "倒出", "squeeze": "挤出"}[mode]
	body.set_meta("title", str(definition.get("name", "调料")) + " · 已" + action)
	body.set_meta("definition", definition)
	body.set_meta("cut", false)
	body.set_meta("enrolled", false)
	body.set_meta("pending", false)
	body.set_meta("plated", false)
	body.set_meta("is_container", false)
	body.set_meta("dispensed", true)
	body.set_meta("dispense_mode", mode)
	body.set_meta("surface_slot", _pan_capacity_used())
	body.set_meta("instance_uid", "liquid_%s_%s" % [Time.get_ticks_usec(), _foods.get_child_count()])
	body.set_meta("batch_uid", source_uid)
	body.set_meta("liquid_state", liquid_state)
	body.set_meta("volume_ml", volume_ml)
	body.set_meta("container_location", "air")
	var collision: = CollisionShape2D.new()
	var shape: = CircleShape2D.new()
	shape.radius = 9.0
	collision.shape = shape
	body.add_child(collision)
	var sauce: = preload("res://modules/restaurant/world/sauce_blob.gd").new()
	sauce.name = "SauceBlob"
	sauce.definition = definition
	sauce.dispense_mode = mode
	sauce.liquid_state = liquid_state
	body.add_child(sauce)
	_foods.add_child(body)
	body.global_position = Vector2(clampf(_nozzle_world_position().x, 735 + pan.offset.x, 886 + pan.offset.x), minf(_nozzle_world_position().y, 554 + pan.offset.y))
	body.linear_velocity = Vector2(0, 100)
	interaction.emit("notice", "%s一份%s，实际落锅后计入料理；松开左键停止。" % [action, definition.get("name", "调料")])
	return body

func _update_landed_seasoning() -> void :


	for body in _foods.get_children():
		if body.is_queued_for_deletion() or body.get_meta("overflow", false): continue
		var visual: = body.get_node_or_null("SauceBlob") as Node2D
		if not is_instance_valid(visual): continue
		var landed: bool = body != _held and body.get_meta("enrolled", false) and not body.get_meta("plated", false) and pan.local_point(to_local(body.global_position)).y > 575 and absf(pan.angle) < 0.1
		if landed:
			var slot: = int(body.get_meta("surface_slot", 0)) % 6
			var local_body: Vector2 = pan.local_point(to_local(body.global_position))
			var surface: Vector2 = pan.point(Vector2(clampf(local_body.x + (slot % 3 - 1) * 25, 752, 865), lerpf(592, 578, pan_fill_ratio()) + (slot / 3) * 8))
			visual.global_position = to_global(surface)
			visual.global_rotation = global_rotation
			visual.scale = Vector2(1.6, 0.85)
			# Pan floor sauce is below solids and the wall, never over the rim.
			visual.z_index = 0
		else:
			visual.position = Vector2.ZERO
			visual.rotation = 0
			visual.scale = Vector2.ONE
			visual.z_index = 0

func spill_pan_water(volume_ml: float, spill_position: Vector2) -> void:
	if volume_ml <= 0.0: return
	pan.runoff.emit_water(volume_ml, spill_position, pan.rigid.linear_velocity * 0.35)

func _add_overflow(definition: Dictionary, incoming_state: Dictionary = {}, spill_position: Vector2 = Vector2.INF) -> RigidBody2D:
	var id: = str(definition.get("id", "ketchup"))
	var spill: RigidBody2D
	for body in _foods.get_children():
		if not body.is_queued_for_deletion() and body.get_meta("overflow", false) and body.get_meta("id", "") == id:
			spill = body
			break
	if not is_instance_valid(spill):
		if _foods.get_child_count() >= 64:
			_stop_squeezing()
			return null
		spill = RigidBody2D.new()
		spill.name = "CounterSpill"
		spill.mass = maxf(0.000000000001, float(incoming_state.get("volume_ml", 0.0)) * float(definition.get("density_g_ml", 1.03)) / 1000.0)
		spill.collision_layer = 32
		spill.collision_mask = 1
		spill.set_meta("id", id)
		spill.set_meta("definition", definition.duplicate(true))
		spill.set_meta("overflow", true)
		spill.set_meta("enrolled", false)
		spill.set_meta("dispensed", true)
		spill.set_meta("spilled_portions", 0)
		spill.set_meta("liquid_state", SauceState.make_batch(definition, 0.0, str(incoming_state.get("source_id", "unknown")), float(incoming_state.get("pressure", 0.0))))
		var shape: = CollisionShape2D.new()
		shape.shape = CircleShape2D.new()
		shape.shape.radius = 5
		spill.add_child(shape)
		var art: = preload("res://modules/restaurant/world/sauce_blob.gd").new()
		art.name = "SauceBlob"
		art.definition = definition.duplicate(true)
		art.dispense_mode = get_dispense_mode(definition)
		art.liquid_state = spill.get_meta("liquid_state")
		spill.add_child(art)
		_foods.add_child(spill)
		spill.position = spill_position if spill_position != Vector2.INF else Vector2(minf(951 + pan.offset.x + (_foods.get_child_count() % 3) * 8, 1550), 754)
		spill.z_index = 6
		interaction.emit("notice", "锅里的水洒到了台面，点击水渍可以擦掉。" if id == "water" else "锅满了，调料正在溢到台面！松手停止；放下容器后点击洒出的调料擦掉。")
	var amount: = mini(int(spill.get_meta("spilled_portions", 0)) + 1, 10000)
	spill.set_meta("spilled_portions", amount)
	if not incoming_state.is_empty():
		var spill_state: Dictionary = spill.get_meta("liquid_state", {})
		SauceState.merge_into(spill_state, incoming_state, 0.0)
		spill.set_meta("liquid_state", spill_state)
		spill.set_meta("volume_ml", float(spill_state.get("volume_ml", 0.0)))
		spill.mass = maxf(0.000000000001, float(spill_state.get("volume_ml", 0.0)) * float(definition.get("density_g_ml", 1.03)) / 1000.0)
		spill.get_node("SauceBlob").liquid_state = spill_state
	spill.get_node("SauceBlob").scale = Vector2(minf(1.4 + sqrt(amount) * 0.55, 4.2), minf(0.65 + sqrt(amount) * 0.16, 1.5))
	return spill

func _wipe_spill_at(pointer: Vector2, using_sponge := false) -> bool:
	if not using_sponge and (_knife_held or has_active_utensil()): return false
	for body in _foods.get_children():
		if body.is_queued_for_deletion() or not body.get_meta("overflow", false): continue
		var visual: = body.get_node("SauceBlob") as Node2D
		if visual.to_local(to_global(pointer)).length() <= 16:
			if str(body.get_meta("id", "")) == "water":
				pan.overflow_water_ml = maxf(0.0, pan.overflow_water_ml - float(body.get_meta("volume_ml", 0.0)))
			body.queue_free()
			audio.play_effect("wipe")
			interaction.emit("notice", "擦干净了。水渍和溢到台面的调料都不会计入料理。")
			return true
	return false

func pickup_knife(pointer: = Vector2.INF) -> bool:
	if is_instance_valid(_held) or _knife_held or has_active_utensil() or pan.active:
		return false
	_knife_held = true
	_knife_cutting = true
	_knife_visual.visible = true
	_knife_visual.cutting_guide = true
	var grab_point: = get_global_mouse_position() if pointer == Vector2.INF else pointer
	_knife_drag_offset = _knife_visual.global_position - grab_point
	_knife_last_valid_rest = _knife_rest_position
	_previous_blade_tip = _knife_visual.to_global(KNIFE_BLADE_MID)
	_knife_stroke_origin = _previous_blade_tip
	held_changed.emit("主厨刀")
	focus_changed.emit("主厨刀", "顺箭头划完整刀线；R 转刀 90°，滚轮微调角度，松手放刀")
	return true

func _rotate_knife() -> void:
	_rotate_knife_by(-PI / 2.0)

func _rotate_knife_by(amount: float) -> void:
	_knife_visual.rotation = wrapf(_knife_visual.rotation + amount, -PI, PI)
	# Rotation alone never cuts. The next stroke starts at the new edge position.
	_previous_blade_tip = _knife_visual.to_global(KNIFE_BLADE_MID)
	_knife_stroke_origin = _previous_blade_tip

func put_knife_back() -> void :
	_knife_last_valid_rest = KNIFE_HOME
	_release_knife()

func _release_knife() -> void :
	_knife_held = false
	_knife_cutting = false
	_knife_visual.cutting_guide = false
	_knife_visual.rotation = 0.0
	_knife_rest_position = _knife_last_valid_rest
	_knife_visual.global_position = _knife_rest_position
	_knife_visual.visible = true
	held_changed.emit("")
	focus_changed.emit("料理台", "食材先放在砧板；按住刀柄拖动切开，松手放下")

func _move_knife(pointer: Vector2) -> void :
	if not _knife_held or not _knife_cutting or not controls_enabled:
		return
	_knife_visual.global_position = pointer + _knife_drag_offset
	var blade_tip: = _knife_visual.to_global(KNIFE_BLADE_MID)
	if blade_tip.distance_to(_previous_blade_tip) > 2.0:
		var forward := Vector2.DOWN.rotated(_knife_visual.rotation)
		var motion := blade_tip - _previous_blade_tip
		if motion.normalized().dot(forward) >= 0.7:
			_perform_knife_sweep(_knife_stroke_origin, blade_tip)
		else:
			_knife_stroke_origin = blade_tip
	_previous_blade_tip = blade_tip
	if _knife_rest_center_bounds().has_point(_knife_visual.global_position):
		_knife_last_valid_rest = _knife_visual.global_position

func _knife_rest_center_bounds() -> Rect2:
	var board: Rect2 = cutting_board.rect()
	return Rect2(board.position - KNIFE_REST_ART_BOUNDS.position, board.size - KNIFE_REST_ART_BOUNDS.size)

func _knife_handle_rect() -> Rect2:
	return Rect2(_knife_visual.global_position + Vector2(5, 8), Vector2(91, 51))

func _knife_grab_rect() -> Rect2:
	return Rect2(_knife_visual.global_position + Vector2(-96, -47), Vector2(192, 110))

func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if _dragging: _finish_food_drag(true)
		_stop_squeezing()
		if _knife_held and is_instance_valid(_knife_visual):
			_release_knife()

func _exit_tree() -> void :
	if is_instance_valid(_sound):
		_sound.stop()
		_sound.stream = null

func _perform_knife_sweep(from: Vector2, to: Vector2) -> void :
	if not _knife_held or not _knife_cutting or from.distance_to(to) < 2.0:
		return
	var direction := (to - from).normalized()
	var normal := Vector2(-direction.y, direction.x)
	# The blade marker traces the player's cut line. It must travel forward;
	# lifting the knife or sweeping its handle never creates a second cut.
	if direction.dot(Vector2.DOWN.rotated(_knife_visual.rotation)) < 0.7:
		return
	for body in _foods.get_children():
		if body.is_queued_for_deletion() or body == _held or bool(body.get_meta("is_container", false)) or bool(body.get_meta("dispensed", false)):
			continue
		if not _stations.chop.grow(8.0).has_point(body.global_position):
			continue
		if _time - float(body.get_meta("last_cut_time", -100.0)) < 0.3:
			continue
		var polygon: PackedVector2Array = body.get_meta("fragment_polygon", PackedVector2Array())
		if polygon.size() < 3:
			continue
		var local_from: Vector2 = body.to_local(from)
		var local_to: Vector2 = body.to_local(to)
		var local_direction := (local_to - local_from).normalized()
		var path_length := local_from.distance_to(local_to)
		var first_contact := INF
		var last_contact := -INF
		for vertex in polygon:
			var along: float = (vertex - local_from).dot(local_direction)
			first_contact = minf(first_contact, along)
			last_contact = maxf(last_contact, along)
		# A full edge-to-edge stroke is needed. split_food checks whether this
		# exact line leaves two usable pieces, including narrow off-centre slices.
		if first_contact >= -2.0 and last_contact <= path_length + 2.0:
			split_food(body, normal, from, 6)

func split_food(body: RigidBody2D, normal: = Vector2.RIGHT, world_cut: = Vector2.INF, max_depth: = 2) -> Array[RigidBody2D]:
	var result: Array[RigidBody2D] = []
	if not is_instance_valid(body) or body.is_queued_for_deletion() or body == _held:
		return result
	if bool(body.get_meta("is_container", false)) or bool(body.get_meta("dispensed", false)):
		return result
	if not bool(body.get_meta("definition", {}).get("cuttable", true)):
		interaction.emit("notice", "%s是硬质奇物，菜刀切不开；可以整件入锅。" % body.get_meta("title", "这件材料"))
		return result
	if int(body.get_meta("cut_depth", 0)) >= max_depth or _foods.get_child_count() >= 63:
		return result
	if not _stations.chop.grow(8.0).has_point(body.global_position):
		return result

	var polygon: PackedVector2Array = body.get_meta("fragment_polygon", PackedVector2Array())
	if polygon.is_empty():
		for i in range(32):
			polygon.append(Vector2.from_angle(i * TAU / 32.0) * 24.0)
	var local_normal: = normal.normalized().rotated( - body.rotation)
	var cut_origin: = _polygon_centroid(polygon) if world_cut == Vector2.INF else body.to_local(world_cut)
	var first: = _clip_half(polygon, local_normal, cut_origin.dot(local_normal))
	var second: = _clip_half(polygon, - local_normal, - cut_origin.dot(local_normal))
	if first.size() < 3 or second.size() < 3 or _polygon_area(first) < 20 or _polygon_area(second) < 20:
		return result
	if bool(body.get_meta("enrolled", false)):
		food_removed_from_pan.emit(body)
		body.set_meta("enrolled", false)
	var definition: Dictionary = body.get_meta("definition", {})
	var art_offset: Vector2 = body.get_meta("art_offset", Vector2.ZERO)
	var parent_area := _polygon_area(polygon)
	var root_area := float(body.get_meta("root_area", parent_area))
	var cut_style := preload("res://modules/restaurant/assets/cut_state_library.gd").style_for(body.get_meta("cut_axis", Vector2.ZERO), local_normal, str(body.get_meta("cut_style", "slice")))
	for index in range(2):
		var piece: PackedVector2Array = first if index == 0 else second
		var center: = _polygon_centroid(piece)
		var centered: = PackedVector2Array()
		var cut_radius: = 0.0
		for point in piece:
			centered.append(point - center)
			cut_radius = maxf(cut_radius, (point - center).length())
		var fragment: = preload("res://modules/restaurant/world/food_body.gd").new()
		fragment.name = "Cut_" + str(body.get_meta("id", "food"))
		fragment.mass = body.mass * _polygon_area(piece) / _polygon_area(polygon)
		fragment.collision_layer = 16
		fragment.collision_mask = 17
		fragment.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		for key in ["id", "title", "definition", "saved_heat", "softness", "hydration", "cooking_heat"]:
			if body.has_meta(key):
				fragment.set_meta(key, body.get_meta(key))
		fragment.set_meta("title", str(definition.get("name", "食材")) + (" · 小块" if cut_style == "dice" else " · 切片"))
		fragment.set_meta("root_area", root_area)
		fragment.set_meta("source_fraction", _polygon_area(piece) / root_area)
		fragment.set_meta("cut_axis", local_normal)
		fragment.set_meta("cut_style", cut_style)
		fragment.set_meta("cut_variant", posmod(int(body.get_meta("cut_variant", 0)) + index, 3))
		fragment.set_meta("cut", true)
		fragment.set_meta("cut_depth", int(body.get_meta("cut_depth", 0)) + 1)
		fragment.set_meta("enrolled", false)
		fragment.set_meta("pending", false)
		fragment.set_meta("plated", false)
		fragment.set_meta("is_container", false)
		fragment.set_meta("instance_uid", "food_%s_%s" % [Time.get_ticks_usec(), index])
		fragment.set_meta("batch_uid", str(body.get_meta("batch_uid", body.get_meta("instance_uid", body.get_instance_id()))))
		var parent_lineage: Array = body.get_meta("lineage", []).duplicate(true)
		parent_lineage.append(str(body.get_meta("instance_uid", body.get_instance_id())))
		fragment.set_meta("lineage", parent_lineage)
		var ratio := _polygon_area(piece) / parent_area
		var coating: Dictionary = body.get_meta("surface_sauce", {}).duplicate(true)
		coating["volume_ml"] = float(coating.get("volume_ml", 0.0)) * ratio
		for key in coating.get("composition_ml", {}): coating.composition_ml[key] *= ratio
		fragment.set_meta("surface_sauce", coating)
		if coating.has("mass_kg"): coating.mass_kg *= ratio
		if body.has_meta("thermal"):
			fragment.set_meta("thermal", preload("res://modules/restaurant/domain/food_thermal.gd").split_state(body.get_meta("thermal"),ratio))
		var carryover: Dictionary = body.get_meta("pan_carryover", {}).duplicate(true)
		for key in carryover: carryover[key].mass_kg *= ratio
		fragment.set_meta("pan_carryover", carryover)
		fragment.set_meta("last_cut_time", _time)
		fragment.set_meta("fragment_polygon", centered)
		fragment.set_meta("art_offset", art_offset - center)
		fragment.set_meta("cut_radius", cut_radius)
		var collision: = CollisionShape2D.new()
		var shape: = ConvexPolygonShape2D.new()
		# Re-hull after repeated clipping: nearly collinear float intersections
		# can otherwise be rejected by the native convex-shape validator.
		var support := Geometry2D.convex_hull(centered)
		if support.size()>1 and support[0].is_equal_approx(support[-1]): support.remove_at(support.size()-1)
		shape.points = support
		collision.shape = shape
		fragment.add_child(collision)
		var visual: = preload("res://modules/restaurant/world/food_fragment.gd").new()
		visual.name = "FoodArt"
		visual.definition = definition
		visual.polygon = centered
		visual.art_offset = art_offset - center
		visual.cut_style = cut_style
		visual.cut_variant = int(fragment.get_meta("cut_variant"))
		visual.source_fraction = float(fragment.get_meta("source_fraction"))
		visual.heat = float(body.get_meta("saved_heat", 0.0))
		visual.thermal = fragment.get_meta("thermal",{}).duplicate(true)
		visual.coating = coating.duplicate(true)
		fragment.add_child(visual)
		_foods.add_child(fragment)
		# Keep the source silhouette continuous at the instant of the cut. The
		# two pieces separate through motion, rather than a seven-pixel jump.
		fragment.global_position = body.global_position + center.rotated(body.rotation)
		fragment.rotation = body.rotation
		fragment.linear_velocity = body.linear_velocity + normal.normalized() * (12.0 if index == 0 else -12.0)
		if body.get_meta("on_board", false):
			var side := 1.0 if index == 0 else -1.0
			var cut_response := preload("res://modules/restaurant/domain/material_response.gd").effective(fragment)
			var impulse := 0.85 * lerpf(0.7, 1.0, 1.0-float(cut_response.compliance))
			var kick := minf(48.0, impulse / maxf(fragment.mass, 0.005))
			var spin := side * (1.15 if cut_style == "slice" else 0.5) * clampf(1.0-ratio,0.15,0.85)
			fragment.begin_board_settle(Rect2(_board_food_min(), _board_food_max() - _board_food_min()), normal.normalized() * side * kick, spin, lerpf(1.5,4.0,sqrt(ratio)))
		result.append(fragment)
	body.collision_layer = 0
	body.collision_mask = 0
	body.visible = false
	body.queue_free()
	_chop_flash = 0.2
	audio.play_chop(definition)
	interaction.emit("notice", ("切成小块了。" if cut_style == "dice" else "切好了。") + "拿起其中一片，就能把这一份一起下锅。")
	return result

func _clip_half(polygon: PackedVector2Array, normal: Vector2, distance: float) -> PackedVector2Array:
	var output: = PackedVector2Array()
	for i in range(polygon.size()):
		var current: = polygon[i]
		var previous: = polygon[(i + polygon.size() - 1) % polygon.size()]
		var dc: = current.dot(normal) - distance
		var dp: = previous.dot(normal) - distance
		if (dc >= 0.0) != (dp >= 0.0):
			output.append(previous.lerp(current, dp / (dp - dc)))
		if dc >= 0.0:
			output.append(current)
	return output

func _polygon_centroid(polygon: PackedVector2Array) -> Vector2:
	var center: = Vector2.ZERO
	var cross_sum: = 0.0
	for i in range(polygon.size()):
		var a: = polygon[i]
		var b: = polygon[(i + 1) % polygon.size()]
		var cross: = a.cross(b)
		center += (a + b) * cross
		cross_sum += cross
	return center / (3.0 * cross_sum) if absf(cross_sum) > 0.0001 else polygon[0]

func _connect_food_audio(body: Node) -> void :
	if not body is RigidBody2D: return
	body.contact_monitor = true
	body.max_contacts_reported = 4
	# food_body uses relative normal contact speed, not post-collision world speed.

func _polygon_area(polygon: PackedVector2Array) -> float:
	var area: = 0.0
	for i in range(polygon.size()): area += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return absf(area) * 0.5

func has_active_utensil() -> bool:
	if is_instance_valid(lid) and lid.active: return true
	if is_instance_valid(sponge) and sponge.active: return true
	if is_instance_valid(cloth) and cloth.active: return true
	for tool in utensils:
		if tool.active or tool.storing or tool.releasing: return true
	return false

func leave_pan_residue(body: RigidBody2D) -> void:
	if body.get_meta("container_location", "") == "pan" and not body.get_meta("plated", false):
		pan.residue.deposit(body)
		if body.has_meta("thermal"): reactions._apply(body,body.get_meta("thermal"))
