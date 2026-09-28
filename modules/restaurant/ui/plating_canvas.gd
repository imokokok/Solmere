extends Control
signal changed
signal status(message: String)
var game: Node
var render_only: = false
var mode: = "move"
var sauce_id: = "ketchup"
var selected: RigidBody2D
var dragging: = false
var drawing: = false
var _pointer: = Vector2.ZERO
var _grab_offset: = Vector2.ZERO
var _visuals: Dictionary = {}
var _stroke: Dictionary = {}
var squeeze_pressure: = 0.0
var _travel: = 0.0
var _last_pointer: = Vector2.ZERO

func _ready() -> void :
	custom_minimum_size = Vector2(680, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var ink: = preload("res://modules/restaurant/world/plate_sauce.gd").new()
	ink.canvas = self
	ink.z_index = 0
	add_child(ink)
	# Container layout assigns the final size after _ready. Reproject existing
	# food then, otherwise opening the workbench places it at the top-left.
	resized.connect(refresh_foods)
	refresh_foods()

func center() -> Vector2: return size * 0.5
func radius() -> Vector2: return size * Vector2(0.41, 0.39)
func presentation_data() -> Dictionary:
	if render_only and game._modal_kind == "dish_showcase":
		return game._last_dish.get("presentation", {})
	return game.session.presentation
func normalized(p: Vector2) -> Vector2:
	return ((p - center()) / radius()).limit_length(0.86)

func refresh_foods() -> void :
	for body in game.world._foods.get_children():
		if body.is_queued_for_deletion() or not body.get_meta("plated", false) or not body.get_meta("enrolled", false): continue
		var id: int = body.get_instance_id()
		if not _visuals.has(id):
			var source: Node2D = body.get_node_or_null("FoodArt")
			if source == null: source = body.get_node_or_null("SauceBlob")
			if source == null: continue
			var art: = Node2D.new()
			art.set_script(source.get_script())
			for property in source.get_property_list():
				if str(property.name) in ["definition", "cut", "heat", "softness", "thermal", "coating", "shadows", "polygon", "art_offset", "dispense_mode", "liquid_state", "cut_style", "cut_variant", "source_fraction"]:
					art.set(property.name, source.get(property.name))
			var is_sauce: bool = body.has_meta("liquid_state")
			art.scale = source.scale * (1.25 if is_sauce else 2.8)
			art.z_index = 0 if is_sauce else 1
			add_child(art)
			_visuals[id] = {"body": body, "art": art}
	for id in _visuals.keys():
		var record: Dictionary = _visuals[id]
		if not is_instance_valid(record.body) or not record.body.get_meta("plated", false):
			record.art.queue_free()
			_visuals.erase(id)
		else:
			var p: Vector2 = (record.body.position - game.world.plate.center) / Vector2(100, 20)
			record.art.position = center() + p * radius()
			record.art.rotation = record.body.rotation
	# Match the kitchen's depth order instead of creation order in the editor/photo.
	var ordered := _visuals.values()
	ordered.sort_custom(func(a, b): return a.art.position.y < b.art.position.y or (is_equal_approx(a.art.position.y, b.art.position.y) and a.body.get_instance_id() < b.body.get_instance_id()))
	for record in ordered: move_child(record.art, get_child_count() - 1)
	queue_redraw()

func add_to_plate(body: RigidBody2D) -> void :
	if not is_instance_valid(body) or not body.get_meta("enrolled", false): return
	if not body.get_meta("plated", false):
		game.world.leave_pan_residue(body)
		var is_sauce: bool = body.has_meta("liquid_state")
		var index := 0
		for record in _visuals.values():
			if is_instance_valid(record.body) and record.body.get_meta("plated", false) and record.body.has_meta("liquid_state") == is_sauce:
				index += 1
		body.set_meta("plated", true)
		body.freeze = true
		var solid_places := [Vector2(-36, -5), Vector2(18, -6), Vector2(-2, 6), Vector2(46, 4), Vector2(-52, 5), Vector2(25, 7), Vector2(-22, -11), Vector2(7, -11)]
		var sauce_places := [Vector2(-48, 10), Vector2(-27, 10), Vector2(-6, 11), Vector2(16, 10), Vector2(38, 9), Vector2(53, 6), Vector2(-57, 2), Vector2(56, -3)]
		var places: Array = sauce_places if is_sauce else solid_places
		var placement: Vector2 = places[index % places.size()]
		if index >= places.size(): placement += Vector2((index / places.size()) % 3 - 1, (index / places.size()) % 2) * 3.0
		body.position = game.world.plate.center + (placement / Vector2(100, 20)).limit_length(0.72) * Vector2(100, 20)
		body.set_deferred("position", body.position)
		game.world._update_plated_flag()
		game.world.audio.play_effect("drop")
	selected = body
	refresh_foods()
	_commit_layout()

func _gui_input(event: InputEvent) -> void :
	if render_only: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pointer = event.position
		if ((event.position - center()) / radius()).length() > 1: return
		if mode == "sauce":
			var bottle: RigidBody2D = game._plating_bottle(sauce_id)
			if bottle == null or float(bottle.get_meta("remaining_ml", 0.0)) <= 0.001:
				status.emit("先从调料架取出有余量的酱瓶，再给成品淋酱。")
				return
			if game.session.presentation.get("strokes", []).size() >= 24:
				status.emit("成品最多保留 24 笔酱汁，可清除后重淋。")
				return
			drawing = true
			_stroke = {}
			_travel = 0.0
			_last_pointer = _pointer
		else:
			selected = null
			var ordered := _visuals.values()
			ordered.sort_custom(func(a, b): return a.art.get_index() > b.art.get_index())
			for record in ordered:
				var source: Node2D = record.body.get_node_or_null("FoodArt")
				if source == null: source = record.body.get_node_or_null("SauceBlob")
				if source == null: continue
				var art_point: Vector2 = record.art.transform.affine_inverse() * event.position
				var world_point: Vector2 = game.world.to_local(source.to_global(art_point))
				if game.world.food_hit(record.body, world_point):
					selected = record.body
					break
			if is_instance_valid(selected):
				dragging = true
				_grab_offset = _visuals[selected.get_instance_id()].art.position - event.position
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		rotate_selected(0.15 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -0.15)
		accept_event()

func _input(event: InputEvent) -> void :
	if render_only or not is_visible_in_tree(): return
	if event is InputEventMouseMotion and (dragging or drawing):
		_pointer = get_global_transform_with_canvas().affine_inverse() * event.position
		if dragging and is_instance_valid(selected):
			var p: = normalized(_pointer + _grab_offset)
			selected.position = game.world.plate.center + p * Vector2(100, 20)
			selected.set_deferred("position", selected.position)
			refresh_foods()
			_commit_layout()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and (dragging or drawing):
		stop_gesture()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void :
	if render_only: return
	squeeze_pressure = move_toward(squeeze_pressure, 1.0 if drawing else 0.0, delta * (3.2 if drawing else 5.0))
	if not is_visible_in_tree():
		stop_gesture()
		return
	if drawing and ((_pointer - center()) / radius()).length() <= 1:
		_travel += _pointer.distance_to(_last_pointer)
		_last_pointer = _pointer
		var amount: float = game._dispense_plating_sauce(sauce_id, delta * lerpf(2.0, 18.0, squeeze_pressure))
		if amount <= 0:
			stop_gesture()
			status.emit("瓶中酱料已用完，或本盘达到 120 ml 上限。")
			return
		if _stroke.is_empty():
			_stroke = {"id": sauce_id, "color": game._definition(sauce_id).get("color", "d96143"), "width": 4.0, "points": [], "amount_ml": 0.0, "pressure_samples": [], "colour_model": "weighted_srgb_visual_approximation"}
			if not game.session.presentation.has("strokes"): game.session.presentation["strokes"] = []
			game.session.presentation.strokes.append(_stroke)
		_stroke.amount_ml = float(_stroke.amount_ml) + amount
		_stroke.pressure_samples.append(snappedf(squeeze_pressure, 0.01))
		if _stroke.pressure_samples.size() > 48: _stroke.pressure_samples.pop_front()
		var p: = normalized(_pointer)
		var xy: = [snappedf(p.x, 0.001), snappedf(p.y, 0.001)]
		var points: Array = _stroke.points
		if points.is_empty() or Vector2(points[-1][0], points[-1][1]).distance_to(p) > 0.025:
			if points.size() < 24: points.append(xy)
			else: stop_gesture()
		_stroke.width = clampf(3.0 + squeeze_pressure * 13.0 + sqrt(float(_stroke.amount_ml)) * 0.8, 3.0, 24.0)
		game.world.audio.ui_dispense_mode = game.world.get_dispense_mode(game._definition(sauce_id)) if drawing else ""
		game.world.audio.ui_dispense_id = sauce_id
		game.world.audio.ui_pressure = squeeze_pressure
		changed.emit()
	elif drawing: game.world.audio.ui_dispense_mode = ""
	for child in get_children():
		if child is Node2D: child.queue_redraw()
	queue_redraw()

func rotate_selected(by: float) -> void :
	if is_instance_valid(selected):
		selected.rotation += by
		refresh_foods()
		_commit_layout()

func _commit_layout() -> void :
	for item in game.session.dish:
		var record: Dictionary = _visuals.get(int(item.get("physics_id", 0)), {})
		if not record.is_empty():
			var p: Vector2 = (record.body.position - game.world.plate.center) / Vector2(100, 20)
			item["plate_position"] = [snappedf(p.x, 0.001), snappedf(p.y, 0.001)]
			item["plate_rotation"] = snappedf(record.body.rotation, 0.001)
	changed.emit()

func clear_sauce() -> void :
	stop_gesture()
	for garnish in game.session.garnishes:
		game.session.plating_waste_ml += maxf(0.0, float(garnish.get("amount_ml", 0.0)))
	game.session.garnishes.clear()
	game.session.presentation.erase("strokes")
	changed.emit()
	queue_redraw()

func stop_gesture() -> void :
	drawing = false
	dragging = false
	_travel = 0.0
	if is_instance_valid(game): game.world.audio.ui_dispense_mode = ""

func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: stop_gesture()
func _exit_tree() -> void : stop_gesture()

func _draw() -> void :
	draw_rect(Rect2(Vector2.ZERO, size), Color("b59a70"))
	var presentation := presentation_data()
	if str(presentation.get("vessel", "plate")) == "bowl":
		_ellipse(center() + Vector2(0, 10), radius() + Vector2(22, 13), Color("88785b"))
		_ellipse(center(), radius() + Vector2(18, 12), Color("f4e9d0"))
		_ellipse(center(), radius() - Vector2(12, 9), Color("c8b994"))
		var broth_ml := float(presentation.get("broth_ml", 0.0))
		if broth_ml > 0.001:
			var fill := clampf(broth_ml / 750.0, 0.0, 1.0)
			_ellipse(center() + Vector2(0, 3), (radius() - Vector2(19, 15)) * lerpf(0.82, 0.99, fill), Color("c6ab66", 0.72))
		if not render_only and is_instance_valid(selected) and _visuals.has(selected.get_instance_id()):
			draw_arc(_visuals[selected.get_instance_id()].art.position, 62, 0, TAU, 48, Color("987642"), 2, true)
		return
	_ellipse(center() + Vector2(0, 10), radius() + Vector2(22, 13), Color("8c7e61"))
	_ellipse(center(), radius() + Vector2(20, 12), Color("f7eed8"))
	_ellipse(center(), radius(), Color("e6dcc0"))
	_ellipse(center(), radius() - Vector2(15, 10), Color("f7f0dc"))
	if not render_only and is_instance_valid(selected) and _visuals.has(selected.get_instance_id()):
		draw_arc(_visuals[selected.get_instance_id()].art.position, 62, 0, TAU, 48, Color("987642"), 2, true)

func _ellipse(at: Vector2, r: Vector2, color: Color) -> void :
	var points: = PackedVector2Array()
	for i in range(64): points.append(at + Vector2.from_angle(i * TAU / 64.0) * r)
	draw_colored_polygon(points, color)
