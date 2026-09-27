extends Control

signal changed
const Ink = preload("res://modules/restaurant/ui/paper_ink.gd")
const RecipeSheet = preload("res://modules/restaurant/ui/recipe_sheet.gd")
var recipe_sheet: Dictionary = {}
var _recipe_sheet_layer: Control
var _erasing := false
var eraser_radius := 13.0
var _text_edit_index := -1
var _text_editor: TextEdit
var _text_original := ""
var _text_original_position: Array = []
var _text_new := false

const FoodArt = preload("res://modules/restaurant/assets/food_art.gd")
static var _ingredient_catalog: Dictionary = {}
const DECORATION_KINDS := ["star", "heart", "leaf", "polka", "flower", "lemon", "checker", "wave", "sun", "tape"]
const DECORATION_COLORS := {"star": "e9bd38", "heart": "d76554", "leaf": "6f9364", "polka": "65aeb1", "flower": "df7854", "lemon": "edca3e", "checker": "4f918d", "wave": "d7653e", "sun": "e3a938", "tape": "d8b85d"}

var strokes: Array = []
var stickers: Array = []
var ink: = Color("284a42")
var brush_width: = 4.0
var brush_kind := "ink"
var _redo_history: Array = []
var editable: = true
var draw_paper: = true
var selected_index: = -1
var mode: = "select":
	set(value):
		mode = value if value in ["select", "draw", "cut", "write", "erase", "instructions"] else "select"
		_drawing = false
		_erasing = false
		_dragging_layer = false
		_stop_tape_drag()
		_cut_points.clear()
		queue_redraw()
		if is_instance_valid(_edit_overlay):
			_edit_overlay.queue_redraw()
var caption: = "":
	set(value):
		caption = value.left(120)
		queue_redraw()
var dish_texture: Texture2D:
	set(value):
		dish_texture = value
		queue_redraw()

var _drawing: = false
var _history: Array = []
var _hover_position: = Vector2.ZERO
var _dragging_layer: = false
var _drag_offset: = Vector2.ZERO
var _layer_root: Node2D
var _layer_nodes: Array[Node2D] = []
var _edit_overlay: Node2D
var _brush_overlay: Node2D
var _cut_points: Array = []
var _property_edit_active: = false
var _property_edit_recorded: = false
var _transform_mode: = ""
var _transform_scale: = 1.0
var _transform_rotation: = 0.0
var _transform_vector: = Vector2.ZERO
var _tape_drag_side: = 0
var _tape_drag_anchor: = Vector2.ZERO
var _tape_drag_axis: = Vector2.RIGHT
var _tape_drag_factor: = 1.0
const PAPER: = Color.WHITE
const MAX_STROKES: = 512
const MAX_STICKERS: = 32

func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(320, 300)
	clip_contents = true
	resized.connect(_layout_layers)
	_rebuild_layers()

func clear_canvas() -> void :
	_remember()
	strokes.clear()
	stickers.clear()
	caption = ""
	dish_texture = null
	_drawing = false
	_dragging_layer = false
	selected_index = -1
	_rebuild_layers()
	changed.emit()
	queue_redraw()

func undo() -> void :
	_erasing=false
	finish_text()
	_drawing = false
	_dragging_layer = false
	_stop_tape_drag()
	if _history.is_empty():
		return
	_redo_history.append(_snapshot())
	var previous: Dictionary = _history.pop_back()
	strokes = previous.strokes
	stickers = previous.stickers
	caption = previous.get("caption", "")
	dish_texture = previous.get("dish_texture")
	recipe_sheet=previous.get("recipe_sheet",{}).duplicate(true)
	selected_index = -1
	_rebuild_layers()
	changed.emit()
	queue_redraw()

func add_sticker(kind: String) -> void :
	if kind not in DECORATION_KINDS or stickers.size() >= MAX_STICKERS:
		return
	_remember()
	var count: = stickers.size()
	stickers.append({"kind": kind, "position": [0.18 + float(count % 4) * 0.2, 0.74 + float(int(count / 4) % 3) * 0.07], "scale": 0.065, "color": DECORATION_COLORS[kind], "length": 1.0, "width": 1.0})
	selected_index = stickers.size() - 1
	mode = "select"
	_rebuild_layers()
	changed.emit()
	queue_redraw()

func add_ingredient(definition: Dictionary) -> void :
	var id = definition.get("id", "")
	_ensure_catalog()
	if not id is String or not _ingredient_catalog.has(id) or stickers.size() >= MAX_STICKERS:
		return
	var is_cut = definition.get("cut", false)
	var heat_value = definition.get("heat", 0.0)
	if not is_cut is bool or not _finite_number(heat_value):
		return
	if not preload("res://modules/restaurant/domain/food_snapshot.gd").valid(definition): return
	_remember()
	var offset: = float(stickers.size() % 5) * 0.055
	stickers.append({"kind": "ingredient", "id": id, "cut": is_cut, "heat": clampf(float(heat_value), 0, 60), "position": [0.37 + offset, 0.38 + offset], "scale": 0.115})
	preload("res://modules/restaurant/domain/food_snapshot.gd").copy(definition,stickers.back())
	selected_index = stickers.size() - 1
	mode = "select"
	_rebuild_layers()
	changed.emit()
	queue_redraw()

func delete_selected() -> void :
	finish_text()
	if not editable or selected_index < 0 or selected_index >= stickers.size():
		return
	_remember()
	stickers.remove_at(selected_index)
	selected_index = -1
	_dragging_layer = false
	_rebuild_layers()
	changed.emit()
	queue_redraw()

func add_text(text: String, color: Color = Color("554735")) -> void :
	if text.strip_edges().is_empty() or stickers.size() >= MAX_STICKERS:
		return
	_remember()
	stickers.append({"kind": "text", "text": text.left(120), "color": color.to_html(), "position": [0.5, 0.5], "scale": 0.08})
	selected_index = stickers.size() - 1
	mode = "select"
	_rebuild_layers()
	changed.emit()
	queue_redraw()

func add_photo(texture: Texture2D) -> void :
	if texture == null or stickers.size() >= MAX_STICKERS:
		return
	var picture: = texture.get_image()
	if picture == null or picture.is_empty():
		return
	picture = picture.duplicate()
	var largest: = maxi(picture.get_width(), picture.get_height())
	if largest > 512:
		var ratio: = 512.0 / largest
		picture.resize(maxi(1, roundi(picture.get_width() * ratio)), maxi(1, roundi(picture.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
	var encoded: = Marshalls.raw_to_base64(picture.save_png_to_buffer())
	if not validate_photo(encoded):
		return
	_remember()
	stickers.append({"kind": "photo", "png": encoded, "position": [0.5, 0.5], "scale": 0.24, "rotation": 0.0})
	selected_index = stickers.size() - 1
	mode = "select"
	_rebuild_layers()
	changed.emit()

func rotate_selected(radians: float) -> void :
	finish_text()
	if not _selection_valid() or not is_finite(radians):
		return
	_remember()
	stickers[selected_index].rotation = wrapf(float(stickers[selected_index].get("rotation", 0.0)) + radians, - PI, PI)
	_layout_layers()
	changed.emit()

func resize_selected(factor: float) -> void :
	finish_text()
	if not _selection_valid() or not is_finite(factor) or factor <= 0:
		return
	_remember()
	stickers[selected_index].scale = clampf(float(stickers[selected_index].scale) * factor, 0.04, 0.28)
	_layout_layers()
	changed.emit()

func duplicate_selected() -> void :
	finish_text()
	if not _selection_valid() or stickers.size() >= MAX_STICKERS:
		return
	_remember()
	var duplicate: Dictionary = stickers[selected_index].duplicate(true)
	duplicate.position = [clampf(float(duplicate.position[0]) + 0.04, 0, 1), clampf(float(duplicate.position[1]) + 0.04, 0, 1)]
	stickers.append(duplicate)
	selected_index = stickers.size() - 1
	_rebuild_layers()
	changed.emit()

func send_selected_back() -> void :
	finish_text()
	if not _selection_valid() or selected_index == 0:
		return
	_remember()
	var layer: Dictionary = stickers[selected_index]
	stickers.remove_at(selected_index)
	stickers.push_front(layer)
	selected_index = 0
	_rebuild_layers()
	changed.emit()

func _selection_valid() -> bool:
	return editable and selected_index >= 0 and selected_index < stickers.size()

func selected_tape_settings() -> Dictionary:
	if not _selection_valid() or stickers[selected_index].kind != "tape":
		return {}
	var layer: Dictionary = stickers[selected_index]
	return {"color": str(layer.get("color", "baa977")), "length": float(layer.get("length", 1.0)), "width": float(layer.get("width", 1.0))}

func selected_decoration_settings() -> Dictionary:
	if not _selection_valid() or stickers[selected_index].kind not in DECORATION_KINDS:
		return {}
	var layer: Dictionary = stickers[selected_index]
	return {"kind": str(layer.kind), "color": str(layer.get("color", DECORATION_COLORS.get(layer.kind, "d8b85d"))), "length": float(layer.get("length", 1.0)), "width": float(layer.get("width", 1.0))}


func begin_property_edit() -> void :
	if not _property_edit_active:
		_property_edit_active = true
		_property_edit_recorded = false

func end_property_edit() -> void :
	_property_edit_active = false
	_property_edit_recorded = false

func set_tape_color(color: Color) -> void :
	var settings: = selected_decoration_settings()
	if settings.is_empty() or not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a):
		return
	var bounded: = color.clamp()
	if Color.from_string(settings.color, Color("baa977")).is_equal_approx(bounded):
		return
	_remember_property()
	stickers[selected_index].color = bounded.to_html()
	_refresh_decoration_visual(selected_index)
	changed.emit()

func set_tape_length(value: float) -> void :
	_set_tape_dimension("length", value, 0.5, 6.0)

func set_tape_width(value: float) -> void :
	_set_tape_dimension("width", value, 0.4, 3.0)

func _set_tape_dimension(key: String, value: float, minimum: float, maximum: float) -> void :
	var settings: = selected_decoration_settings()
	if settings.is_empty() or not is_finite(value):
		return
	var bounded: = clampf(value, minimum, maximum)
	if is_equal_approx(float(settings[key]), bounded):
		return
	_remember_property()
	stickers[selected_index][key] = bounded
	_refresh_decoration_visual(selected_index)
	changed.emit()

func _remember_property() -> void :
	if _property_edit_active:
		if _property_edit_recorded:
			return
		_property_edit_recorded = true
	_store_history()

func _refresh_tape_visual(index: int) -> void :
	_refresh_decoration_visual(index)

func _refresh_decoration_visual(index: int) -> void :
	if index >= _layer_nodes.size() or _layer_nodes[index].get_child_count() == 0:
		_rebuild_layers()
		return
	var layer: Dictionary = stickers[index]
	var visual: = _layer_nodes[index].get_child(0) as DecorativeLayer
	if visual == null:
		return
	visual.shape_color = Color.from_string(layer.get("color", DECORATION_COLORS.get(layer.kind, "d8b85d")), Color("d8b85d"))
	visual.tape_color = visual.shape_color
	visual.tape_length = float(layer.get("length", 1.0))
	visual.tape_width = float(layer.get("width", 1.0))
	var base := Vector2(80, 32) if layer.kind == "tape" else Vector2(80, 80)
	_layer_nodes[index].set_meta("extent", base * Vector2(visual.tape_length, visual.tape_width))
	visual.queue_redraw()
	_layout_layers()

func _tape_handle_at(point: Vector2) -> int:
	if mode != "select" or selected_tape_settings().is_empty():
		return 0
	var half_length: = float(stickers[selected_index].get("length", 1.0)) * 40.0
	for side in [-1, 1]:
		if point.distance_to(_from_layer_local(selected_index, Vector2(side * half_length, 0))) <= 9.0:
			return side
	return 0

func _begin_tape_drag(side: int) -> void :
	end_property_edit()
	begin_property_edit()
	_tape_drag_side = side
	_tape_drag_anchor = _from_layer_local(selected_index, Vector2( - side * 40.0 * float(stickers[selected_index].get("length", 1.0)), 0))
	_tape_drag_axis = Vector2.RIGHT.rotated(float(stickers[selected_index].get("rotation", 0.0)))
	_tape_drag_factor = maxf(0.001, float(stickers[selected_index].scale) * minf(size.x, size.y) / 40.0)
	_dragging_layer = false
	_drawing = false

func _stretch_tape_to(point: Vector2) -> void :
	if _tape_drag_side == 0 or selected_tape_settings().is_empty():
		return
	var distance: = clampf((point - _tape_drag_anchor).dot(_tape_drag_axis) * _tape_drag_side, 40.0 * _tape_drag_factor, 480.0 * _tape_drag_factor)
	var length: = distance / (80.0 * _tape_drag_factor)
	var center: = _normalized(_tape_drag_anchor + _tape_drag_axis * _tape_drag_side * distance * 0.5)
	if is_equal_approx(float(stickers[selected_index].get("length", 1.0)), length) and _pixel(stickers[selected_index].position).is_equal_approx(_pixel(center)):
		return
	_remember_property()
	stickers[selected_index].length = length
	stickers[selected_index].position = center
	_refresh_tape_visual(selected_index)
	changed.emit()

func _stop_tape_drag() -> void :
	_transform_mode = ""
	_tape_drag_side = 0
	end_property_edit()

func restore_selected_cut() -> void :
	if not _selection_valid() or not stickers[selected_index].has("mask"):
		return
	_remember()
	stickers[selected_index].erase("mask")
	_cut_points.clear()
	_rebuild_layers()
	changed.emit()

func finish_cut() -> bool:
	if not _selection_valid() or stickers[selected_index].kind not in ["ingredient", "photo"] or not _valid_mask(_cut_points):
		return false
	_remember()
	stickers[selected_index].mask = _cut_points.duplicate(true)
	_cut_points.clear()
	mode = "select"
	_rebuild_layers()
	changed.emit()
	return true

func export_data() -> Dictionary:
	finish_text()
	var result := {"version": 1, "strokes": strokes.duplicate(true), "stickers": stickers.duplicate(true), "caption": caption}
	if not recipe_sheet.is_empty(): result["recipe_sheet"]=recipe_sheet.duplicate(true)
	return result

func import_data(data: Dictionary) -> void :
	finish_text()
	_stop_tape_drag()
	strokes.clear()
	stickers.clear()
	_history.clear()
	_redo_history.clear()
	_drawing = false
	_dragging_layer = false
	selected_index = -1
	recipe_sheet=data.recipe_sheet.duplicate(true) if RecipeSheet.valid(data.get("recipe_sheet")) else {}
	caption = data.get("caption", "").left(120) if data.get("caption", "") is String else ""
	var incoming_strokes = data.get("strokes", [])
	if incoming_strokes is Array:
		for value in incoming_strokes.slice(0, MAX_STROKES):
			if not value is Dictionary or not value.get("points") is Array:
				continue
			var points: Array = []
			for point in value.points.slice(0, 512):
				if point is Array and point.size() == 2 and _finite_number(point[0]) and _finite_number(point[1]):
					points.append([clampf(float(point[0]), 0, 1), clampf(float(point[1]), 0, 1)])
			var color_text: = str(value.get("color", "284a42"))
			var width_value = value.get("width", 0.008)
			if not _finite_number(width_value):
				width_value = 0.008
			if not points.is_empty() and Color.html_is_valid(color_text):
				var stroke := {"points": points, "color": color_text, "width": clampf(float(width_value), 0.001, 0.08)}
				if value.get("brush","") in ["ink","pencil","marker"]: stroke["brush"]=value.brush
				strokes.append(stroke)
	var incoming_stickers = data.get("stickers", [])
	if incoming_stickers is Array:
		for value in incoming_stickers.slice(0, MAX_STICKERS):
			if not validate_sticker(value):
				continue
			var layer: Dictionary = value.duplicate(true)
			layer.scale = float(value.get("scale", 0.065))
			if layer.kind == "ingredient":
				layer.heat = float(value.get("heat", 0.0))
			stickers.append(layer)
	_rebuild_layers()
	changed.emit()
	queue_redraw()

func has_content() -> bool:
	return not strokes.is_empty() or not stickers.is_empty() or not caption.strip_edges().is_empty() or dish_texture != null

func _remember() -> void :
	finish_text()
	_stop_tape_drag()
	_store_history()

func _store_history() -> void :
	_redo_history.clear()
	_history.append(_snapshot())
	if _history.size() > 32:
		_history.pop_front()

func _gui_input(event: InputEvent) -> void :
	if not editable:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed:
		if event.keycode == KEY_Z:
			if event.shift_pressed: redo()
			else: undo()
			accept_event(); return
		if event.keycode == KEY_Y: redo(); accept_event(); return
	if event is InputEventKey and event.pressed and not event.echo and mode == "cut":
		if event.keycode == KEY_ESCAPE:
			_cut_points.clear()
			_layout_layers()
			accept_event()
			return
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			finish_cut()
			accept_event()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
		delete_selected()
		accept_event()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if selected_index < 0:
			selected_index = _hit_layer(event.position)
		if selected_index >= 0:
			var factor: = 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
			resize_selected(factor)
			accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			finish_text()
			grab_focus()
			if mode=="erase":
				_remember(); _erasing=true; erase_at(event.position); accept_event(); return
			if mode=="instructions": return
			var text_hit := _hit_layer(event.position)
			if mode == "write" or (event.double_click and text_hit >= 0 and stickers[text_hit].kind == "text"):
				begin_text(event.position, text_hit if text_hit >= 0 and stickers[text_hit].kind == "text" else -1)
				accept_event()
				return
			var transform_handle: = _transform_handle_at(event.position)
			if not transform_handle.is_empty():
				_remember()
				_transform_mode = transform_handle
				_transform_scale = float(stickers[selected_index].scale)
				_transform_rotation = float(stickers[selected_index].get("rotation", 0))
				_transform_vector = event.position - _pixel(stickers[selected_index].position)
				accept_event()
				return
			var tape_handle: = _tape_handle_at(event.position)
			if tape_handle != 0:
				_begin_tape_drag(tape_handle)
				changed.emit()
				accept_event()
				return
			if mode == "cut":
				if selected_index < 0:
					selected_index = _hit_layer(event.position)
				if selected_index >= 0 and stickers[selected_index].kind in ["ingredient", "photo"]:
					if event.double_click and _cut_points.size() >= 3:
						finish_cut()
					elif _cut_points.size() < 32:
						var local: = _to_layer_local(selected_index, event.position) / 40.0
						_cut_points.append([clampf(local.x, -1, 1), clampf(local.y, -1, 1)])
				_layout_layers()
				changed.emit()
				accept_event()
				return
			var hit: = _hit_layer(event.position)
			if mode == "select" and hit >= 0:
				_remember()
				var layer: Dictionary = stickers[hit]
				stickers.remove_at(hit)
				stickers.append(layer)
				selected_index = stickers.size() - 1
				_drag_offset = event.position - _pixel(layer.position)
				_dragging_layer = true
				_drawing = false
				_rebuild_layers()
			else:
				selected_index = -1
				if mode == "draw" and strokes.size() < MAX_STROKES:
					_remember()
					_drawing = true
					strokes.append({"points": [_normalized(event.position)], "color": ink.to_html(), "width": clampf(brush_width / maxf(size.x, 1), 0.001, 0.08),"brush":brush_kind})
			changed.emit()
		elif _drawing or _dragging_layer or _tape_drag_side != 0 or _erasing:
			_drawing = false
			_erasing = false
			_dragging_layer = false
			_stop_tape_drag()
			changed.emit()
		queue_redraw()
		if is_instance_valid(_edit_overlay):
			_edit_overlay.queue_redraw()
		if is_instance_valid(_brush_overlay):
			_brush_overlay.queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion:
		_hover_position = event.position
		if _erasing:
			erase_at(event.position); accept_event()
		elif _tape_drag_side != 0:
			_stretch_tape_to(event.position)
			accept_event()
		elif _dragging_layer and selected_index >= 0:
			stickers[selected_index].position = _normalized(event.position - _drag_offset)
			_layout_layers()
			accept_event()
		elif _drawing and not strokes.is_empty():
			var points: Array = strokes.back().points
			if points.size() < 512:
				points.append(_normalized(event.position))
			changed.emit()
			queue_redraw()
			if is_instance_valid(_brush_overlay):
				_brush_overlay.queue_redraw()
			accept_event()

func _normalized(point: Vector2) -> Array:
	return [clampf(point.x / maxf(size.x, 1), 0, 1), clampf(point.y / maxf(size.y, 1), 0, 1)]

func _pixel(point: Array) -> Vector2:
	return Vector2(float(point[0]) * size.x, float(point[1]) * size.y)

func _draw() -> void :
	if draw_paper:
		preload("res://modules/restaurant/ui/paper_surface.gd").paint(self,Rect2(Vector2.ZERO,size))

func _draw_brush() -> void :
	for stroke in strokes:
		var color: = Color.from_string(stroke.color, ink)
		var width: = maxf(1, float(stroke.width) * size.x)
		var points: Array = stroke.points
		if points.size() == 1:
			_brush_overlay.draw_circle(_pixel(points[0]), width / 2, color)
		for index in range(1, points.size()):
			var start := _pixel(points[index-1])
			var end := _pixel(points[index])
			if stroke.get("brush","ink")=="pencil":
				for strand in 3:
					var shift := Vector2.from_angle(float(index+strand)*2.1)*width*0.22
					_brush_overlay.draw_line(start+shift,end+shift,Color(color,0.27+strand*0.1),maxf(0.7,width*0.28),true)
			else:
				_brush_overlay.draw_line(start,end,Color(color,0.42) if stroke.get("brush","")=="marker" else color,width,true)
				if stroke.get("brush","ink")=="ink":
					_brush_overlay.draw_circle(start,width/2,color)
					_brush_overlay.draw_circle(end,width/2,color)

func erase_at(point: Vector2) -> void:
	# Split touched ink, leaving printed words and the untouched parts of a stroke.
	var remaining: Array = []
	var erased := false
	for stroke in strokes:
		var sampled: Array = []
		var radius := eraser_radius+float(stroke.width)*size.x/2
		var points: Array = stroke.points
		var touched := false
		for i in points.size():
			var start := _pixel(points[i])
			var end := _pixel(points[mini(i+1,points.size()-1)])
			if Geometry2D.get_closest_point_to_segment(point,start,end).distance_to(point)<=radius:
				touched=true; break
		if not touched:
			remaining.append(stroke); continue
		erased=true
		for i in points.size():
			var start := _pixel(points[i])
			var end := _pixel(points[mini(i+1,points.size()-1)])
			var count := maxi(1,ceili(start.distance_to(end)/maxf(radius/3,1)))
			for j in count: sampled.append(start.lerp(end,float(j)/count))
		var run: Array = []
		for pixel in sampled:
			if pixel.distance_to(point)>radius:
				run.append(_normalized(pixel))
			elif not run.is_empty():
				_append_ink_fragments(remaining,stroke,run); run=[]
		if not run.is_empty(): _append_ink_fragments(remaining,stroke,run)
	if erased and remaining.size()<=MAX_STROKES:
		strokes=remaining
		if is_instance_valid(_brush_overlay): _brush_overlay.queue_redraw()
		changed.emit()

func _append_ink_fragments(target: Array, stroke: Dictionary, points: Array) -> void:
	var offset := 0
	while offset<points.size():
		var fragment: Dictionary=stroke.duplicate(true)
		fragment.points=points.slice(offset,mini(offset+512,points.size()))
		target.append(fragment)
		if offset+512>=points.size(): break
		offset+=511

func _base_extent(index: int) -> Vector2:
	if index >= 0 and index < stickers.size() and stickers[index].kind in DECORATION_KINDS:
		var base := Vector2(80, 32) if stickers[index].kind == "tape" else Vector2(80, 80)
		return base * Vector2(float(stickers[index].get("length", 1.0)), float(stickers[index].get("width", 1.0)))
	return _layer_nodes[index].get_meta("extent", Vector2(80, 80)) if index < _layer_nodes.size() else Vector2(80, 80)

func _to_layer_local(index: int, point: Vector2) -> Vector2:
	var factor: = maxf(0.001, float(stickers[index].scale) * minf(size.x, size.y) / 40.0)
	return (point - _pixel(stickers[index].position)).rotated( - float(stickers[index].get("rotation", 0.0))) / factor

func _from_layer_local(index: int, point: Vector2) -> Vector2:
	var factor: = float(stickers[index].scale) * minf(size.x, size.y) / 40.0
	return point.rotated(float(stickers[index].get("rotation", 0.0))) * factor + _pixel(stickers[index].position)

func _draw_overlay() -> void :
	if not editable or _text_edit_index >= 0 or not _selection_valid():
		return
	var extent: = _base_extent(selected_index) / 2 + Vector2(5, 5)
	var border: = PackedVector2Array()
	for corner in [Vector2( - extent.x, - extent.y), Vector2(extent.x, - extent.y), Vector2(extent.x, extent.y), Vector2( - extent.x, extent.y), Vector2( - extent.x, - extent.y)]:
		border.append(_from_layer_local(selected_index, corner))
	_edit_overlay.draw_polyline(border, Color("597464"), 1.5, true)
	if mode == "select":
		var handles: = transform_handles()
		var top: = _from_layer_local(selected_index, Vector2(0, - extent.y))
		_edit_overlay.draw_line(top, handles.rotate, Color("597464"), 1.5, true)
		_edit_overlay.draw_circle(handles.rotate, 7, Color("f2dcaf"))
		_edit_overlay.draw_arc(handles.rotate, 7, 0, TAU, 20, Color("597464"), 1.5, true)
		_edit_overlay.draw_rect(Rect2(handles.scale - Vector2(6, 6), Vector2(12, 12)), Color("f2dcaf"))
		_edit_overlay.draw_rect(Rect2(handles.scale - Vector2(6, 6), Vector2(12, 12)), Color("597464"), false, 1.5)
	if mode == "select" and stickers[selected_index].kind == "tape":
		for side in [-1, 1]:
			var handle: = _from_layer_local(selected_index, Vector2(side * 40.0 * float(stickers[selected_index].get("length", 1.0)), 0))
			_edit_overlay.draw_circle(handle, 5.5, Color.WHITE)
			_edit_overlay.draw_circle(handle, 5.5, Color("597464"), false, 1.5, true)
	var polygon: = PackedVector2Array()
	for point in _cut_points:
		var pixel: = _from_layer_local(selected_index, Vector2(point[0], point[1]) * 40)
		polygon.append(pixel)
		_edit_overlay.draw_circle(pixel, 3.5, Color("ad7164"))
	if polygon.size() >= 2:
		_edit_overlay.draw_polyline(polygon, Color("ad7164"), 2.0, true)
func _hit_layer(point: Vector2) -> int:
	for index in range(stickers.size() - 1, -1, -1):
		var local: = _to_layer_local(index, point)
		var extent: = _base_extent(index)
		if not Rect2( - extent / 2, extent).has_point(local):
			continue
		if stickers[index].kind == "tape" and not Geometry2D.is_point_in_polygon(local, _tape_polygon(float(stickers[index].get("length", 1.0)), float(stickers[index].get("width", 1.0)))):
			continue
		if stickers[index].has("mask"):
			var polygon: = PackedVector2Array()
			for vertex in stickers[index].mask:
				polygon.append(Vector2(vertex[0], vertex[1]) * 40)
			if not Geometry2D.is_point_in_polygon(local, polygon):
				continue
		return index
	return -1

func _rebuild_layers() -> void :
	if is_instance_valid(_recipe_sheet_layer):
		remove_child(_recipe_sheet_layer); _recipe_sheet_layer.queue_free(); _recipe_sheet_layer=null
	if not recipe_sheet.is_empty():
		_recipe_sheet_layer=RecipeSheet.new(); add_child(_recipe_sheet_layer); _recipe_sheet_layer.build(self)
	if not is_instance_valid(_layer_root):
		_layer_root = Node2D.new()
		_layer_root.name = "CollageLayers"
		add_child(_layer_root)
	if not is_instance_valid(_brush_overlay):
		_brush_overlay = Node2D.new()
		_brush_overlay.name = "FreehandInk"
		_brush_overlay.z_index = 3
		_brush_overlay.draw.connect(_draw_brush)
		add_child(_brush_overlay)
	if not is_instance_valid(_edit_overlay):
		_edit_overlay = Node2D.new()
		_edit_overlay.name = "CollageSelection"
		_edit_overlay.z_index = 5
		_edit_overlay.draw.connect(_draw_overlay)
		add_child(_edit_overlay)
	for child in _layer_root.get_children():
		_layer_root.remove_child(child)
		child.queue_free()
	_layer_nodes.clear()
	_ensure_catalog()
	for layer in stickers:
		var visual: Node2D
		var extent: = Vector2(80, 80)
		if layer.kind == "ingredient":
			visual = FoodArt.new()
			visual.set("definition", _ingredient_catalog.get(layer.id, {}).duplicate(true))
			visual.set("cut", layer.get("cut", false))
			visual.set("heat", float(layer.get("heat", 0.0)))
			visual.set("thermal",layer.get("thermal",{}).duplicate(true))
			visual.set("coating",layer.get("surface_sauce",{}).duplicate(true))
			visual.set("shadows", false)
		elif layer.kind == "text":
			visual = TextLayer.new()
			visual.call("configure", layer.text, Ink.font(), Color.from_string(layer.color, Color("554735")))
			extent = visual.get("extent")
		elif layer.kind == "photo":
			var photograph: = Image.new()
			photograph.load_png_from_buffer(Marshalls.base64_to_raw(layer.png))
			var picture: = Sprite2D.new()
			picture.texture = ImageTexture.create_from_image(photograph)
			picture.scale = Vector2.ONE * 80.0 / maxf(photograph.get_width(), photograph.get_height())
			extent = Vector2(photograph.get_width(), photograph.get_height()) * picture.scale
			visual = picture
		else:
			visual = DecorativeLayer.new()
			visual.set("kind", layer.kind)
			visual.set("shape_color", Color.from_string(layer.get("color", DECORATION_COLORS.get(layer.kind, "d8b85d")), Color("d8b85d")))
			visual.set("tape_color", visual.get("shape_color"))
			visual.set("tape_length", float(layer.get("length", 1.0)))
			visual.set("tape_width", float(layer.get("width", 1.0)))
			var base := Vector2(80, 32) if layer.kind == "tape" else Vector2(80, 80)
			extent = base * Vector2(float(layer.get("length", 1.0)), float(layer.get("width", 1.0)))
		var wrapper: = Node2D.new()
		wrapper.set_meta("extent", extent)
		_layer_root.add_child(wrapper)
		if layer.has("mask"):
			var clipper: = Polygon2D.new()
			var vertices: = PackedVector2Array()
			for point in layer.mask:
				vertices.append(Vector2(point[0], point[1]) * 40)
			clipper.polygon = vertices
			clipper.color = Color.WHITE
			clipper.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
			wrapper.add_child(clipper)
			clipper.add_child(visual)
		else:
			wrapper.add_child(visual)
		_layer_nodes.append(wrapper)
	_layout_layers()

func _layout_layers() -> void :
	for index in mini(_layer_nodes.size(), stickers.size()):
		_layer_nodes[index].position = _pixel(stickers[index].position)
		_layer_nodes[index].scale = Vector2.ONE * float(stickers[index].scale) * minf(size.x, size.y) / 40.0
		_layer_nodes[index].rotation = float(stickers[index].get("rotation", 0.0))
	queue_redraw()
	if is_instance_valid(_edit_overlay):
		_edit_overlay.queue_redraw()
	if is_instance_valid(_brush_overlay):
		_brush_overlay.queue_redraw()

static func _ensure_catalog() -> void :
	if not _ingredient_catalog.is_empty():
		return
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/data/ingredients.json"))
	if source is Array:
		for entry in source:
			if entry is Dictionary and entry.get("id") is String:
				_ingredient_catalog[entry.id] = entry

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func validate_sticker(value: Variant) -> bool:
	if not value is Dictionary or (value.get("kind", "") not in DECORATION_KINDS and value.get("kind", "") not in ["ingredient", "text", "photo"]):
		return false
	var point = value.get("position")
	if not point is Array or point.size() != 2 or not _finite_number(point[0]) or not _finite_number(point[1]):
		return false
	if point[0] < 0 or point[0] > 1 or point[1] < 0 or point[1] > 1:
		return false
	var scale_value = value.get("scale", 0.065)
	if not _finite_number(scale_value) or scale_value < 0.02 or scale_value > 0.3:
		return false
	var allowed: = ["kind", "position", "scale", "rotation"]
	if not _finite_number(value.get("rotation", 0.0)) or absf(float(value.get("rotation", 0.0))) > PI:
		return false
	if value.kind == "ingredient":
		_ensure_catalog()
		if not value.get("id") is String or not _ingredient_catalog.has(value.id) or not value.get("cut") is bool:
			return false
		if not _finite_number(value.get("heat", 0.0)) or value.get("heat", 0.0) < 0 or value.get("heat", 0.0) > 60:
			return false
		if scale_value < 0.04 or scale_value > 0.28:
			return false
		if not preload("res://modules/restaurant/domain/food_snapshot.gd").valid(value): return false
		allowed.append_array(["id", "cut", "heat", "thermal", "surface_sauce"])
	elif value.kind == "text":
		if not value.get("text") is String or value.text.strip_edges().is_empty() or value.text.length() > 120:
			return false
		if not value.get("color") is String or not Color.html_is_valid(value.color):
			return false
		if scale_value < 0.04 or scale_value > 0.28:
			return false
		allowed.append_array(["text", "color"])
	elif value.kind == "photo":
		if not value.get("png") is String or not validate_photo(value.png) or scale_value < 0.04 or scale_value > 0.28:
			return false
		allowed.append("png")
	elif value.kind in DECORATION_KINDS:
		if not value.get("color", DECORATION_COLORS.get(value.kind, "d8b85d")) is String or not Color.html_is_valid(value.get("color", DECORATION_COLORS.get(value.kind, "d8b85d"))):
			return false
		var length_value = value.get("length", 1.0)
		var width_value = value.get("width", 1.0)
		if not _finite_number(length_value) or length_value < 0.5 or length_value > 6.0:
			return false
		if not _finite_number(width_value) or width_value < 0.4 or width_value > 3.0:
			return false
		allowed.append_array(["color", "length", "width"])
	if value.has("mask"):
		if value.kind not in ["ingredient", "photo"] or not _valid_mask(value.mask):
			return false
		allowed.append("mask")
	for key in value:
		if key not in allowed:
			return false
	return true

static func _valid_mask(value: Variant) -> bool:
	if not value is Array or value.size() < 3 or value.size() > 32:
		return false
	var polygon: = PackedVector2Array()
	for point in value:
		if not point is Array or point.size() != 2 or not _finite_number(point[0]) or not _finite_number(point[1]) or absf(float(point[0])) > 1 or absf(float(point[1])) > 1:
			return false
		var vertex: = Vector2(point[0], point[1])
		for existing in polygon:
			if existing.distance_squared_to(vertex) < 1e-05:
				return false
		polygon.append(vertex)
	for first in polygon.size():
		for second in range(first + 1, polygon.size()):
			if second == first + 1 or (first == 0 and second == polygon.size() - 1):
				continue
			if Geometry2D.segment_intersects_segment(polygon[first], polygon[(first + 1) % polygon.size()], polygon[second], polygon[(second + 1) % polygon.size()]) != null:
				return false
	var twice_area: = 0.0
	for index in polygon.size():
		twice_area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	if absf(twice_area) < 0.0001:
		return false
	return not Geometry2D.triangulate_polygon(polygon).is_empty()

static func validate_photo(value: String) -> bool:
	if value.is_empty() or value.length() > 699052 or value.length() % 4 != 0:
		return false
	var padding: = 0
	for code in value.to_ascii_buffer():
		if code == 61:
			padding += 1
			if padding > 2:
				return false
		elif padding > 0 or not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 43 or code == 47):
			return false
	var bytes: = Marshalls.base64_to_raw(value)
	if bytes.size() < 24 or bytes.size() > 524288 or bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		return false
	var width: = int(bytes[16]) * 16777216 + int(bytes[17]) * 65536 + int(bytes[18]) * 256 + bytes[19]
	var height: = int(bytes[20]) * 16777216 + int(bytes[21]) * 65536 + int(bytes[22]) * 256 + bytes[23]
	if width < 1 or width > 512 or height < 1 or height > 512:
		return false
	var picture: = Image.new()
	return picture.load_png_from_buffer(bytes) == OK

class TextLayer extends Node2D:
	var extent := Vector2(288,80)
	var editor: TextEdit
	func configure(value: String, _font: Font, color: Color) -> void:
		editor = TextEdit.new()
		Ink.style(editor,24,color)
		editor.text = value
		editor.editable = false
		editor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		editor.focus_mode = Control.FOCUS_NONE
		editor.scroll_fit_content_height = true
		editor.size = extent
		add_child(editor)
		update_extent()
	func update_extent() -> void:
		var paragraph := TextParagraph.new()
		paragraph.width = 280
		paragraph.add_string(editor.text if not editor.text.is_empty() else " ",Ink.font(),24)
		extent = Vector2(288,maxf(78,paragraph.get_size().y + paragraph.get_line_count()*3 + 38))
		editor.size = extent
		editor.position = -extent/2

class DecorativeLayer extends Node2D:
	var kind: = "star"
	var tape_color: = Color("baa977")
	var shape_color: = Color("d8b85d")
	var tape_length: = 1.0
	var tape_width: = 1.0
	func _draw() -> void :
		var stretch := Vector2(tape_length, tape_width)
		match kind:
			"star":
				var points: = PackedVector2Array()
				for index in 10:
					points.append(Vector2.from_angle( - PI / 2 + index * PI / 5) * (40.0 if index % 2 == 0 else 18.0) * stretch)
				draw_colored_polygon(points, shape_color)
			"heart":
				var points := PackedVector2Array()
				for p in [Vector2(-32, -16), Vector2(-15, -29), Vector2(0, -13), Vector2(15, -29), Vector2(32, -16), Vector2(32, 0), Vector2(0, 38), Vector2(-32, 0)]: points.append(p * stretch)
				draw_colored_polygon(points, shape_color)
			"leaf":
				var points := PackedVector2Array()
				for p in [Vector2(-40, 16), Vector2(-18, -22), Vector2(40, -26), Vector2(20, 14)]: points.append(p * stretch)
				draw_colored_polygon(points, shape_color)
				draw_line(Vector2(-32, 12) * stretch, Vector2(28, -18) * stretch, shape_color.darkened(0.28), 2)
			"polka":
				for y in [-22.0, 0.0, 22.0]:
					for x in [-25.0, 0.0, 25.0]: _ellipse(Vector2(x, y) * stretch, Vector2(7, 7) * stretch, shape_color)
			"flower":
				for i in 6: _ellipse(Vector2.from_angle(i * TAU / 6.0) * 19.0 * stretch, Vector2(14, 14) * stretch, shape_color)
				_ellipse(Vector2.ZERO, Vector2(11, 11) * stretch, shape_color.lightened(0.34))
			"lemon":
				_ellipse(Vector2.ZERO, Vector2(34, 24) * stretch, shape_color)
				draw_arc(Vector2.ZERO, 16.0 * minf(stretch.x, stretch.y), 0, TAU, 24, shape_color.lightened(0.34), 2.0, true)
			"checker":
				for y in 4:
					for x in 4:
						if (x + y) % 2 == 0: draw_rect(Rect2((Vector2(-40 + x * 20, -40 + y * 20)) * stretch, Vector2(20, 20) * stretch), shape_color)
			"wave":
				var points := PackedVector2Array()
				for i in 17: points.append(Vector2(-40 + i * 5, sin(i * PI / 2.0) * 15) * stretch)
				draw_polyline(points, shape_color, maxf(3.0, 6.0 * tape_width), true)
			"sun":
				_ellipse(Vector2.ZERO, Vector2(20, 20) * stretch, shape_color)
				for i in 12: draw_line(Vector2.from_angle(i * TAU / 12.0) * 25.0 * stretch, Vector2.from_angle(i * TAU / 12.0) * 39.0 * stretch, shape_color, 4.0, true)
			"tape":
				var points: = PackedVector2Array()
				for point in [Vector2(-40, -10), Vector2(34, -16), Vector2(40, 10), Vector2(-34, 16)]:
					points.append(point * stretch)
				draw_colored_polygon(points, shape_color)
	func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
		var points := PackedVector2Array()
		for i in 28: points.append(center + Vector2.from_angle(i * TAU / 28.0) * radius)
		draw_colored_polygon(points, color)

static func _tape_polygon(length: float, width: float) -> PackedVector2Array:
	var points: = PackedVector2Array()
	for point in [Vector2(-40, -10), Vector2(34, -16), Vector2(40, 10), Vector2(-34, 16)]:
		points.append(point * Vector2(length, width))
	return points

func _paper_style() -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color("d5c8a9")
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	return style

func _draw_sticker(kind: String, center: Vector2, radius: float) -> void :
	match kind:
		"star":
			var points: = PackedVector2Array()
			for i in 10:
				var angle: = - PI / 2 + i * PI / 5
				points.append(center + Vector2(cos(angle), sin(angle)) * radius * (1.0 if i % 2 == 0 else 0.45))
			draw_colored_polygon(points, Color("e8ae42"))
		"heart":
			draw_circle(center + Vector2( - radius * 0.34, - radius * 0.2), radius * 0.48, Color("d97468"))
			draw_circle(center + Vector2(radius * 0.34, - radius * 0.2), radius * 0.48, Color("d97468"))
			draw_colored_polygon(PackedVector2Array([center + Vector2( - radius * 0.76, 0), center + Vector2(radius * 0.76, 0), center + Vector2(0, radius)]), Color("d97468"))
		"leaf":
			_draw_leaf(center, radius)
		"tape":
			draw_colored_polygon(PackedVector2Array([center + Vector2( - radius, - radius * 0.24), center + Vector2(radius * 0.85, - radius * 0.4), center + Vector2(radius, radius * 0.24), center + Vector2( - radius * 0.85, radius * 0.4)]), Color(0.78, 0.68, 0.42, 0.65))

func _draw_leaf(center: Vector2, radius: float) -> void :
	var points: = PackedVector2Array([center + Vector2( - radius, radius * 0.4), center + Vector2( - radius * 0.45, - radius * 0.55), center + Vector2(radius, - radius * 0.65), center + Vector2(radius * 0.5, radius * 0.35)])
	draw_colored_polygon(points, Color("6b936e"))
	draw_line(center + Vector2( - radius * 0.8, radius * 0.3), center + Vector2(radius * 0.7, - radius * 0.45), Color("3e6550"), 2, true)

func transform_handles() -> Dictionary:
	if not _selection_valid(): return {}
	var extent: = _base_extent(selected_index) / 2 + Vector2(5, 5)
	var angle: = float(stickers[selected_index].get("rotation", 0))
	return {"scale": _from_layer_local(selected_index, extent), "rotate": _from_layer_local(selected_index, Vector2(0, - extent.y)) + Vector2(0, -24).rotated(angle)}

func _transform_handle_at(point: Vector2) -> String:
	if mode != "select" or not _selection_valid(): return ""
	var handles: = transform_handles()
	for action in ["rotate", "scale"]:
		if point.distance_to(handles[action]) <= 10: return action
	return ""

func _input(event: InputEvent) -> void :
	if not editable or not is_visible_in_tree(): return
	if event is InputEventMouseMotion and not _transform_mode.is_empty() and _selection_valid():
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var vector: Vector2 = point - _pixel(stickers[selected_index].position)
		if _transform_mode == "scale":
			stickers[selected_index].scale = clampf(_transform_scale * vector.length() / maxf(_transform_vector.length(), 1), 0.04, 0.28)
		else:
			stickers[selected_index].rotation = wrapf(_transform_rotation + _transform_vector.angle_to(vector), - PI, PI)
		_layout_layers()
		changed.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var transforming: = not _transform_mode.is_empty()
		if transforming or _tape_drag_side != 0 or _dragging_layer or _drawing or _erasing:
			_drawing = false
			_erasing = false
			_dragging_layer = false
			_stop_tape_drag()
			changed.emit()
			if transforming: get_viewport().set_input_as_handled()

func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or not is_visible_in_tree():
			_transform_mode = ""
			_erasing = false
			_dragging_layer = false
			_drawing = false
			_stop_tape_drag()

func begin_text(point: Vector2, index := -1) -> void:
	if not editable: return
	finish_text()
	if index < 0:
		if stickers.size() >= MAX_STICKERS: return
		_remember()
		stickers.append({"kind":"text","text":"","color":ink.to_html(),"position":_normalized(point),"scale":0.08})
		index = stickers.size()-1
		_text_new = true
	else:
		_remember()
		_text_new = false
	selected_index = index
	_rebuild_layers()
	_text_edit_index = index
	_text_original = str(stickers[index].text)
	_text_original_position = stickers[index].position.duplicate()
	var visual = _layer_nodes[index].get_child(0)
	_text_editor = visual.editor
	_text_editor.editable = true
	_text_editor.focus_mode = Control.FOCUS_ALL
	_text_editor.mouse_filter = Control.MOUSE_FILTER_STOP
	_text_editor.text_changed.connect(_text_changed)
	# A deferred focus event from the previous text must not finish its successor.
	_text_editor.focus_exited.connect(_finish_unfocused_text.bind(_text_editor.get_instance_id()).call_deferred)
	_text_editor.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not _text_editor.has_ime_text():
			finish_text(true)
			get_viewport().set_input_as_handled())
	_text_editor.grab_focus()
	_text_editor.set_caret_line(_text_editor.get_line_count()-1)
	_text_editor.set_caret_column(_text_editor.get_line(_text_editor.get_line_count()-1).length())
	_edit_overlay.queue_redraw()

func _finish_unfocused_text(editor_id: int) -> void:
	# The old layer may already be freed when this deferred callback runs.
	var editor := instance_from_id(editor_id) as TextEdit
	if is_instance_valid(editor) and editor == _text_editor and not editor.has_focus():
		finish_text()

func _text_changed() -> void:
	if _text_edit_index < 0 or not is_instance_valid(_text_editor): return
	# Native TextEdit owns composition/caret/selection; never recreate it mid-IME.
	if _text_editor.text.length() > 120:
		_text_editor.text = _text_editor.text.left(120)
		_text_editor.set_caret_line(_text_editor.get_line_count()-1)
		_text_editor.set_caret_column(_text_editor.get_line(_text_editor.get_line_count()-1).length())
	stickers[_text_edit_index].text = _text_editor.text
	var visual = _layer_nodes[_text_edit_index].get_child(0)
	var previous_extent: Vector2 = visual.extent
	visual.update_extent()
	_layer_nodes[_text_edit_index].set_meta("extent",visual.extent)
	# Grow down from the same first line instead of recentering all earlier ink.
	var wrapper: Node2D = _layer_nodes[_text_edit_index]
	var shift: Vector2 = ((visual.extent-previous_extent)*wrapper.scale*0.5).rotated(wrapper.rotation)
	stickers[_text_edit_index].position = _normalized(wrapper.position+shift)
	_layout_layers()
	changed.emit()

func finish_text(cancel := false) -> void:
	if _text_edit_index < 0: return
	var index := _text_edit_index
	# Commit composition while the editor can still update its anchored extent.
	if is_instance_valid(_text_editor) and _text_editor.has_ime_text(): _text_editor.apply_ime()
	_text_edit_index = -1
	if is_instance_valid(_text_editor):
		stickers[index].text = _text_editor.text.left(120)
		_text_editor.release_focus()
	if cancel:
		stickers[index].text = "" if _text_new else _text_original
		stickers[index].position = _text_original_position.duplicate()
	if str(stickers[index].text).strip_edges().is_empty():
		stickers.remove_at(index)
		selected_index = -1
	_text_editor = null
	_rebuild_layers()
	changed.emit()

func place_material(data: Dictionary, point: Vector2) -> void:
	if not editable: return
	finish_text()
	var before := stickers.size()
	match str(data.get("type","")):
		"sticker": add_sticker(str(data.get("kind","")))
		"ingredient": add_ingredient(data.get("definition",{}))
		"photo": add_photo(data.get("texture"))
	if stickers.size() > before:
		stickers.back().position = _normalized(point)
		_layout_layers()
		changed.emit()

func _can_drop_data(_point: Vector2, data: Variant) -> bool:
	return editable and data is Dictionary and data.get("source","") == "kitchen-collage" and data.get("type","") in ["sticker","ingredient","photo"]

func _drop_data(point: Vector2, data: Variant) -> void:
	if _can_drop_data(point,data): place_material(data,point)

func _snapshot() -> Dictionary:
	return {"strokes":strokes.duplicate(true),"stickers":stickers.duplicate(true),"caption":caption,"dish_texture":dish_texture,"recipe_sheet":recipe_sheet.duplicate(true)}

func redo() -> void:
	_erasing=false
	finish_text()
	if _redo_history.is_empty(): return
	_history.append(_snapshot())
	var next: Dictionary = _redo_history.pop_back()
	strokes=next.strokes; stickers=next.stickers; caption=next.caption; dish_texture=next.dish_texture
	recipe_sheet=next.get("recipe_sheet",{}).duplicate(true)
	selected_index=-1
	_rebuild_layers()
	changed.emit()
