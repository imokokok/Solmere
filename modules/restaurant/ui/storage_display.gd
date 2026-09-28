extends Control

signal ingredient_chosen(definition: Dictionary, press_position: Vector2)

const FoodArt = preload("res://modules/restaurant/assets/food_art.gd")
const Support = preload("res://modules/restaurant/ui/storage_geometry.gd")
const ROOM = preload("res://modules/restaurant/assets/kitchen_reference_no_recipe_stand.png")
const FRIDGE: = Rect2(30, 175, 330, 360)
const SHELVES: = Rect2(390, 421, 840, 114)
const BASKETS: = Rect2(1260, 155, 326, 635)
const COLD_IDS: = ["egg", "shrimp", "fish", "salmon", "squid", "mussel", "chicken", "pork", "beef", "sausage", "milk", "yogurt", "butter", "cheese", "ice_cream", "tofu"]
const AMBIENT_IDS: = ["noodles", "bread", "seaweed", "potato", "onion", "mushroom", "corn", "pumpkin", "lotus_root", "bean_sprout", "cabbage", "broccoli", "eggplant"]
const FRIDGE_VIEW := Rect2(51, 176, 281, 377)
# Three columns are visible at a time. Colours are interspersed with food,
# continuing into the neighbouring part of the same cupboard.
const FEATURED_FOODS_FIRST := ["tomato", "potato", "carrot", "onion", "eggplant", "bell_pepper_yellow", "zucchini", "mushroom", "egg", "noodles", "bread", "cheese", "broccoli", "lettuce", "bell_pepper_green", "milk", "bell_pepper_lavender", "pumpkin", "shrimp", "tofu", "bell_pepper_gold", "chicken", "bell_pepper_purple", "bell_pepper_brown", "bell_pepper_white", "bell_pepper_orange"]

var definitions: Array = []
var sections: Dictionary = {"fridge": [], "shelves": [], "baskets": []}
var section_counts: Dictionary = {"fridge": 0, "shelves": 0, "baskets": 0}
var fridge_open: = true:
	set(value):
		fridge_open = value
		if is_instance_valid(_fridge_items):
			_fridge_items.visible = fridge_open
		if is_instance_valid(_fridge_toggle):
			_fridge_toggle.text = "冷藏柜  ·  打开" if not fridge_open else "冷藏柜  ·  已打开"
		queue_redraw()

var _fridge_items: Control
var _fridge_toggle: Button
var _content: Control
var stock: Dictionary = {}
var fridge_offset := 0.0
var fridge_target := 0.0
var _fridge_view: Control
var _fridge_rail: Control
var _rail_dragging := false
var _rail_origin := 0.0
var _rail_offset := 0.0
var odd_page := 0
var _cold_catalog: Array = []
var _odd_catalog: Array = []
var _settling: Dictionary = {}

func pickup_view(id: String) -> Dictionary:
	var button := find_child("Ingredient_" + id, true, false) as Button
	if button == null: return {}
	var art: Node2D = button.get_node("FoodArt")
	return {"transform": art.get_global_transform_with_canvas(), "opening": button.get_global_transform_with_canvas() * button.get_meta("opening")}

func settle_item(id: String, from: Transform2D) -> void:
	set_available(id, true)
	var button := find_child("Ingredient_" + id, true, false) as Button
	if button == null: return
	var art: Node2D = button.get_node("FoodArt")
	var home: Transform2D = button.get_meta("rest_transform")
	var start := button.get_global_transform_with_canvas().affine_inverse() * from
	# A supported placement: descend into the measured inner floor, with the
	# existing front wall masking the lower part throughout the handoff.
	_set_seating_pose(0.0, art, button, start, home)
	var tween := create_tween()
	_settling[id] = tween
	tween.tween_method(_set_seating_pose.bind(art, button, start, home), 0.0, 1.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): _settling.erase(id))

func _set_seating_pose(t: float, art: Node2D, button: Button, start: Transform2D, home: Transform2D) -> void:
	if not is_instance_valid(art): return
	art.transform = start.interpolate_with(home, t)
	art.storage_clip = art.transform.affine_inverse() * button.get_meta("opening")
	art.queue_redraw()

func set_available(id: String, available: bool) -> void:
	stock[id] = available
	var button := find_child("Ingredient_" + id, true, false) as Button
	if button == null: return
	if _settling.has(id):
		_settling[id].kill()
		_settling.erase(id)
	var art: Node2D = button.get_node("FoodArt")
	if button.has_meta("rest_transform"):
		art.transform = button.get_meta("rest_transform")
		art.storage_clip = art.transform.affine_inverse() * button.get_meta("opening")
		art.queue_redraw()
	button.disabled = not available
	button.mouse_filter = Control.MOUSE_FILTER_STOP if available else Control.MOUSE_FILTER_IGNORE
	button.get_node("FoodArt").visible = available
	button.get_node("IngredientName").text = str(button.get_meta("definition").name) if available else "空位"
	if not available: button.get_node("IngredientName").hide()
	queue_redraw()

func slot_at(id: String, point: Vector2) -> bool:
	var button := find_child("Ingredient_" + id, true, false) as Button
	if button != null and button.get_meta("display_surface", "") == "fridge" and not FRIDGE_VIEW.has_point(point - global_position): return false
	return button != null and button.is_visible_in_tree() and button.get_global_rect().grow(16.0).has_point(point)

func reveal_ingredient(id: String) -> void:
	# Opening the full cupboard also reveals the item's physical return slot.
	for section in ["fridge", "odd"]:
		var items: Array = _cold_catalog if section == "fridge" else _odd_catalog
		for index in items.size():
			if str(items[index].id) != id: continue
			if section == "fridge":
				var x := _cold_position(index).x
				if x < fridge_offset: fridge_target = x
				elif x + 90 > fridge_offset + FRIDGE_VIEW.size.x: fridge_target = x + 90 - FRIDGE_VIEW.size.x
				fridge_target = clampf(fridge_target, 0, _fridge_max_offset())
				# A pantry selection must expose its return slot before handoff.
				fridge_offset = fridge_target
				_apply_fridge_offset()
				return
			else:
				var page := index / 12
				if odd_page == page: return
				odd_page = page
			_build_items()
			return

func _turn_page(section: String, step: int) -> void:
	if section == "fridge":
		_scroll_fridge(step)
		return
	else:
		odd_page = posmod(odd_page + step, maxi(1, ceili(_odd_catalog.size() / 12.0)))
	_build_items()

func _fridge_page_count() -> int:
	# Compatibility for capture tools only; no pages or wrapping in gameplay.
	return ceili((_fridge_max_offset() + FRIDGE_VIEW.size.x) / FRIDGE_VIEW.size.x)

func _cold_position(index: int) -> Vector2:
	return Vector2((index / 15 * 3 + index % 3) * 94, (index % 15 / 3) * 77)

func _fridge_max_offset() -> float:
	return maxf(0, ceili(_cold_catalog.size() / 15.0) * 282.0 - FRIDGE_VIEW.size.x)

func _scroll_fridge(step: int) -> void:
	fridge_target = clampf(fridge_target + step * 188.0, 0, _fridge_max_offset())

func _process(delta: float) -> void:
	if absf(fridge_offset - fridge_target) < 0.01: return
	fridge_offset = lerpf(fridge_offset, fridge_target, 1.0 - exp(-14.0 * delta))
	_apply_fridge_offset()

func _apply_fridge_offset() -> void:
	if is_instance_valid(_fridge_items): _fridge_items.position.x = -fridge_offset
	if is_instance_valid(_fridge_rail): _fridge_rail.queue_redraw()
	queue_redraw()

func _rail_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_rail_dragging = event.pressed
			_rail_origin = (_fridge_rail.get_global_transform_with_canvas() * event.position).x
			_rail_offset = fridge_target
			_fridge_rail.accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_scroll_fridge(1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
			_fridge_rail.accept_event()
	elif event is InputEventMouseMotion and _rail_dragging:
		var pointer: Vector2 = _fridge_rail.get_global_transform_with_canvas() * event.position
		fridge_target = clampf(_rail_offset - (pointer.x - _rail_origin) * 3.0, 0, _fridge_max_offset())
		_fridge_rail.accept_event()

func _draw_fridge_rail() -> void:
	# An inset pull along the cabinet edge, with physical end stops. No page UI.
	var x := 9.0 + 3.0 * fridge_offset / maxf(1, _fridge_max_offset())
	_fridge_rail.draw_style_box(_handle_style(Color("546e75", 0.22)), Rect2(x + 3, 16, 12, 112))
	_fridge_rail.draw_style_box(_handle_style(Color("7e9696")), Rect2(x, 12, 11, 112))
	_fridge_rail.draw_line(Vector2(x + 2, 19), Vector2(x + 2, 114), Color("fff0d0", 0.5), 2.0, true)

func _handle_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style

func _page_controls(section: String, location: Vector2, width: float, page: int, count: int) -> void:
	if count <= 1: return
	_heading("%d / %d" % [page + 1, count], location + Vector2(42, 3), Vector2(width - 84, 24), Color("fff0d5"), 16)
	for direction in [-1, 1]:
		var button := Button.new()
		button.name = section.capitalize() + ("PreviousPage" if direction < 0 else "NextPage")
		button.text = "‹" if direction < 0 else "›"
		button.tooltip_text = "看看旁边的架子"
		button.position = location + Vector2(0 if direction < 0 else width - 34, 0)
		button.size = Vector2(34, 28)
		_compact_sign(button)
		button.pressed.connect(_turn_page.bind(section, direction))
		_content.add_child(button)

func setup(defs: Array) -> void :
	definitions.clear()
	var seen: Dictionary = {}
	for value in defs:
		if not value is Dictionary or not value.get("id") is String or not value.get("name") is String:
			continue
		if seen.has(value.id):
			continue
		seen[value.id] = true
		definitions.append(value.duplicate(true))
	_organize()
	if is_node_ready():
		_build_items()
	queue_redraw()

func _ready() -> void :
	size = Vector2(1600, 900)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_items()

func _organize() -> void :
	sections = {"fridge": [], "shelves": [], "baskets": []}
	var catalog: Dictionary = {}
	var used: Dictionary = {}
	for item in definitions:
		catalog[item.id] = item
	for id in COLD_IDS:
		if catalog.has(id):
			sections.fridge.append(catalog[id])
			used[id] = true
	for item in definitions:
		if item.get("category") == "seasoning" and not used.has(item.id):
			sections.shelves.append(item)
			used[item.id] = true
	for id in AMBIENT_IDS:
		if catalog.has(id) and not used.has(id) and sections.shelves.size() < 30:
			sections.shelves.append(catalog[id])
			used[id] = true

	for group in ["sweet", "basic", "odd", "seasoning"]:
		for item in definitions:
			if not used.has(item.id) and item.get("category") == group:
				sections.baskets.append(item)
				used[item.id] = true
	for item in definitions:
		if not used.has(item.id):
			sections.baskets.append(item)
	for key in sections:
		section_counts[key] = sections[key].size()

signal browse_requested
func _build_items() -> void :
	for tween in _settling.values(): tween.kill()
	_settling.clear()
	if is_instance_valid(_content):
		remove_child(_content)
		_content.queue_free()
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	var catalog: = {}
	for item in definitions: catalog[item.id] = item
	var cold: = FEATURED_FOODS_FIRST
	_cold_catalog.clear()
	for id in cold:
		if catalog.has(id): _cold_catalog.append(catalog[id])
	for item in definitions:
		if item.get("category", "") in ["basic", "sweet"] and not cold.has(str(item.id)): _cold_catalog.append(item)
	_fridge_view = Control.new()
	_fridge_view.name = "FridgeInterior"
	_fridge_view.position = FRIDGE_VIEW.position
	_fridge_view.size = FRIDGE_VIEW.size
	_fridge_view.clip_contents = true
	_fridge_view.mouse_filter = Control.MOUSE_FILTER_PASS
	_fridge_view.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_scroll_fridge(1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
			_fridge_view.accept_event())
	_content.add_child(_fridge_view)
	_fridge_items = Control.new()
	_fridge_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fridge_items.size = Vector2(_fridge_max_offset() + FRIDGE_VIEW.size.x, FRIDGE_VIEW.size.y)
	_fridge_view.add_child(_fridge_items)
	for i in _cold_catalog.size():
		_slot(_fridge_items, _cold_catalog[i], _cold_position(i), Vector2(90, 69), 0.76, Color("344854"), "fridge")
	_fridge_rail = Control.new()
	_fridge_rail.name = "FridgePull"
	_fridge_rail.position = Vector2(342, 284)
	_fridge_rail.size = Vector2(32, 140)
	_fridge_rail.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_fridge_rail.tooltip_text = "按住柜沿左右拖动，看看另一边 · 也可滚动鼠标滚轮"
	_fridge_rail.gui_input.connect(_rail_input)
	_fridge_rail.draw.connect(_draw_fridge_rail)
	_content.add_child(_fridge_rail)
	_apply_fridge_offset()
	var counter: = ["ketchup", "mayonnaise", "mustard", "chili_sauce", "vinegar"]
	for i in counter.size():
		if catalog.has(counter[i]): _slot(_content, catalog[counter[i]], Vector2(688 + i * 77, 495), Vector2(75, 92), preload("res://modules/restaurant/assets/sprite_library.gd").physical_art_scale(counter[i]), Color("fff0d5"), "rack")
	# The authored room already has the rack's front board. Repainting it in
	# the HUD placed that rear board in front of the skillet's upper rim.
	# Separate condiment rack at the exact left-hand position in the source.
	for spec in [["oil", 367.0], ["pepper", 412.0], ["salt", 457.0], ["sugar", 498.0], ["soy_sauce", 541.0]]:
		if catalog.has(spec[0]):
			_counter_slot(catalog[spec[0]], spec[1])
			# The crowded left rack uses hover labels rather than painting text over bottles.
			_content.get_node("Ingredient_" + spec[0] + "/IngredientName").hide()
	var odd: = []
	for id in ["sock", "confetti", "toilet_paper", "soap", "soap_smooth", "toothpaste", "resignation_letter", "alarm_clock", "yarn_ball", "tennis_ball", "dentures", "eraser", "sponge", "baseball_bat", "computer_mouse", "slipper", "rubber_duck", "rock"]:
		if catalog.has(id): odd.append(catalog[id])
	for item in definitions:
		if item.get("category", "") == "odd" and not odd.has(item): odd.append(item)
	_odd_catalog = odd
	var odd_count := mini(odd.size() - odd_page * 12, 12)
	for i in odd_count:
		var shelf_row := (2 - i / 4) if odd_count < 12 else i / 4
		var floor_y := 300.0 + shelf_row * 105.0
		_slot(_content, odd[odd_page * 12 + i], Vector2(1326 + (i % 4) * 67, floor_y - 75.0), Vector2(64, 75), 0.70, Color("fff0d5"), "odd")
	_page_controls("odd", Vector2(1340, 518), 242, odd_page, ceili(odd.size() / 12.0))
	var browse: = Button.new()
	browse.name = "BrowseIngredientCupboard"
	browse.text = ""
	browse.tooltip_text = "打开全部食材"
	browse.position = Vector2(64, 122)
	browse.size = Vector2(228, 34)
	_transparent_button(browse)
	browse.pressed.connect( func(): browse_requested.emit())
	_content.add_child(browse)
	for id in stock: set_available(id, bool(stock[id]))
	queue_redraw()

func _surface_front(parent: Control, region: Rect2) -> void:
	var front := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = ROOM
	atlas.region = Rect2(region.position * Vector2(ROOM.get_size()) / Vector2(1600, 900), region.size * Vector2(ROOM.get_size()) / Vector2(1600, 900))
	front.texture = atlas
	front.position = region.position
	front.size = region.size
	front.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	front.stretch_mode = TextureRect.STRETCH_SCALE
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(front)

func _counter_slot(item: Dictionary, center_x: float) -> void:
	var art_library = preload("res://modules/restaurant/assets/sprite_library.gd")
	var scale: float = art_library.physical_art_scale(str(item.id))
	var texture: Texture2D = art_library.food(str(item.id))
	var footprint := Vector2(78, 78)
	if texture != null: footprint = art_library.fit(texture, Vector2.ZERO, Vector2(78, 78)).size
	footprint *= scale
	var dimensions := Vector2(maxf(footprint.x + 2.0, 24.0), footprint.y + 9.0)
	_slot(_content, item, Vector2(center_x - dimensions.x * 0.5, 612.0 - dimensions.y), dimensions, scale, Color("493b2d"), "counter")

func _compact_sign(button: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var paper := StyleBoxFlat.new()
		paper.bg_color = Color("f1d5a5") if state == "normal" else Color("ffe7b8")
		paper.set_content_margin_all(5)
		button.add_theme_stylebox_override(state, paper)
	button.add_theme_font_size_override("font_size", 16)

func _heading(words: String, location: Vector2, dimensions: Vector2, color: Color, font_size: int) -> void :
	var label: = Label.new()
	label.text = words
	label.position = location
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(label)

func _slot(parent: Control, item: Dictionary, location: Vector2, dimensions: Vector2, icon_scale: float, name_color: Color, surface: String = "") -> void :
	var button: = Button.new()
	button.name = "Ingredient_" + str(item.id)
	button.position = location
	button.size = dimensions
	button.set_meta("ingredient_id", item.id)
	button.set_meta("definition", item.duplicate(true))
	button.set_meta("display_surface", surface)
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.tooltip_text = str(item.name) + ("\n拿到锅上方，按住出料。" if str(item.get("dispense_mode", "")) != "" else "\n按住拖出，松手放下。")
	_transparent_button(button)
	# Use the actual press event, not the OS cursor's later position. A quick
	# drag can enqueue press/motion/release before the next game frame.
	button.gui_input.connect(func(event: InputEvent):
		if not button.disabled and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if button.has_meta("opening") and not (button.get_meta("opening") as Rect2).has_point(event.position): return
			# Consume before hiding/disabling the emptied slot. Otherwise this same
			# press falls through to the kitchen and immediately puts the item back.
			button.accept_event()
			ingredient_chosen.emit(item.duplicate(true), button.get_global_transform_with_canvas() * event.position))
	parent.add_child(button)
	var label_height: = 19.0
	var icon_center := Vector2(dimensions.x * 0.5, (dimensions.y - label_height) * 0.47)
	var support := Support.support(surface, Rect2(location, dimensions))
	if surface in ["fridge", "odd", "rack", "counter"]:
		var library = preload("res://modules/restaurant/assets/sprite_library.gd")
		var art_rect: Rect2 = library.support_rect(str(item.id))
		# Seat the visible alpha silhouette, not its transparent image margin.
		icon_center.y = support.floor - location.y - art_rect.end.y * icon_scale
		icon_center.x -= art_rect.get_center().x * icon_scale
	var art: = FoodArt.new()
	art.name = "FoodArt"
	art.definition = item.duplicate(true)
	art.position = icon_center
	art.scale = Vector2.ONE * icon_scale
	art.shadows = true
	if surface in ["fridge", "odd", "rack", "counter"]:
		var opening: Rect2 = support.opening
		art.storage_clip = Rect2((opening.position - location - icon_center) / icon_scale, opening.size / icon_scale)
		button.set_meta("support_floor", support.floor)
		button.set_meta("front_lip", support.lip)
		button.set_meta("opening", Rect2(opening.position - location, opening.size))
		button.set_meta("rest_transform", art.transform)
	button.add_child(art)
	var label: = Label.new()
	label.name = "IngredientName"
	label.text = item.name
	label.position = Vector2(0, dimensions.y - 4.0 if surface in ["fridge", "odd"] else (dimensions.y + 4.0 if surface == "rack" else dimensions.y - label_height))
	label.size = Vector2(dimensions.x, label_height)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14 if surface in ["fridge", "odd"] else 12)
	label.add_theme_color_override("font_color", name_color)
	# Persistent outlined captions formed a row of bright seams across the
	# painted shelves. Let the food read first; reveal its name when inspected.
	if surface in ["fridge", "odd", "rack"]:
		label.visible = false
		button.mouse_entered.connect(func(): label.visible = not button.disabled)
		button.mouse_exited.connect(func(): label.visible = button.has_focus())
		button.focus_entered.connect(func(): label.visible = not button.disabled)
		button.focus_exited.connect(func(): label.hide())
		label.add_theme_color_override("font_shadow_color", Color("f1e0c1", 0.35) if surface == "fridge" else Color("302820",0.35))
		label.add_theme_constant_override("shadow_offset_y", 1)
	# Shelf art is drawn above the HUD; keep its caption readable in the slot.
	# Recipe paper has a higher canvas Z and covers this caption when open.
	if surface in ["fridge", "rack", "odd"]: label.z_index = 1
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)

func _transparent_button(button: Button, _header: bool = false) -> void :
	var normal: = StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("disabled", normal)
	var hover: = StyleBoxFlat.new()
	hover.bg_color = Color.TRANSPARENT
	hover.border_color = Color("8b7d62")
	hover.set_border_width_all(0)
	hover.set_corner_radius_all(0)
	button.add_theme_stylebox_override("hover", hover)
	var pressed: = hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color.TRANSPARENT
	button.add_theme_stylebox_override("pressed", pressed)
	var focus: = StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("453f35")
	focus.set_border_width_all(0)
	focus.set_corner_radius_all(0)
	button.add_theme_stylebox_override("focus", focus)

func _panel(rect: Rect2, color: Color, edge: Color, _radius: int = 0, _width: int = 1) -> void :
	var style: = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	draw_style_box(style, rect)

func _draw() -> void :
	# Small contact shadows connect the separate art nodes to the shelf floor.
	if not is_instance_valid(_content): return
	for slot in _content.find_children("Ingredient_*", "Button", true, false):
		if not slot is Button or slot.disabled or not slot.has_meta("display_surface"): continue
		var surface: String = slot.get_meta("display_surface")
		if surface not in ["fridge", "rack", "odd", "counter"]: continue
		var button := slot as Button
		var origin := button.global_position - global_position
		if surface == "fridge" and not FRIDGE_VIEW.encloses(Rect2(origin, button.size)): continue
		var center: float = origin.x + button.size.x * 0.5
		var art: Node2D = button.get_node("FoodArt")
		var library = preload("res://modules/restaurant/assets/sprite_library.gd")
		var footprint: Rect2 = library.support_rect(str(button.get_meta("ingredient_id")))
		var floor_y: float = origin.y + minf(art.position.y + footprint.end.y * art.scale.y, float(button.get_meta("front_lip")) - button.position.y) - 1.0
		var radius: float = clampf(footprint.size.x * art.scale.x * 0.31, 4.0, 27.0)
		# Feathered warm contact shade; no hard ellipse/underline below every item.
		for ring in range(4,0,-1):
			var points := PackedVector2Array()
			for step in 24:
				var angle := TAU * step / 24.0
				points.append(Vector2(center + cos(angle) * radius * (0.65 + ring * 0.12), floor_y + sin(angle) * (0.7 + ring * 0.55)))
			draw_colored_polygon(points, Color("3e443c", 0.032) if surface == "fridge" else Color("553825", 0.042))
