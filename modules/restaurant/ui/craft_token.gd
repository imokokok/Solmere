extends Button
## Real drag source: each physical-looking swatch carries an editable layer.
var payload: Dictionary = {}
var canvas
var appearance: Node2D
var active := false

func _ready() -> void:
	for state in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	add_theme_color_override("font_color",Color.TRANSPARENT)
	add_theme_color_override("font_hover_color",Color.TRANSPARENT)
	add_theme_color_override("font_pressed_color",Color.TRANSPARENT)
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = text + " · 拖到纸上"
	resized.connect(_layout)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	pressed.connect(func():
		if is_instance_valid(canvas): canvas.place_material(payload,canvas.size*Vector2(0.5,0.5)))
	appearance = _visual()
	if appearance: add_child(appearance)
	_layout()

func _visual() -> Node2D:
	var node: Node2D
	if payload.get("type","") == "ingredient":
		node = preload("res://modules/restaurant/assets/food_art.gd").new()
		node.definition = payload.definition
		node.cut = payload.definition.get("cut",false)
		node.heat = float(payload.definition.get("heat",0))
		node.thermal = payload.definition.get("thermal",{}).duplicate(true)
		node.coating = payload.definition.get("surface_sauce",{}).duplicate(true)
		node.shadows = false
	elif payload.get("type","") == "sticker":
		node = preload("res://modules/restaurant/ui/poster_canvas.gd").DecorativeLayer.new()
		node.kind = payload.kind
		node.shape_color = Color(preload("res://modules/restaurant/ui/poster_canvas.gd").DECORATION_COLORS[payload.kind])
		node.tape_color = node.shape_color
	elif payload.get("type","") == "photo":
		node=PhotoSwatch.new()
		node.texture=payload.texture
	return node

func _layout() -> void:
	if appearance:
		appearance.position = Vector2(size.x/2,size.y*0.43)
		appearance.scale = Vector2.ONE*minf(size.x/110.0,0.66)
	queue_redraw()

func _draw() -> void:
	if is_hovered() or has_focus(): draw_circle(Vector2(size.x/2,size.y*0.43),size.x*0.39,Color("f6e6c6",0.7))
	draw_string(preload("res://modules/restaurant/ui/paper_ink.gd").font(),Vector2(2,size.y-3),text,HORIZONTAL_ALIGNMENT_CENTER,size.x-4,16,Color("5f5544"))

func _get_drag_data(_at: Vector2) -> Variant:
	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var visual := _visual()
	if visual:
		preview.add_child(visual)
		visual.scale = Vector2.ONE*0.8
	set_drag_preview(preview)
	var data := payload.duplicate(true)
	data["source"] = "kitchen-collage"
	return data

class PhotoSwatch extends Node2D:
	var texture: Texture2D
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(-43,-35),Vector2(43,-33),Vector2(42,40),Vector2(-43,41)]),Color("fff8e9"))
		if texture:
			var picture_size := texture.get_size()
			picture_size *= minf(78/picture_size.x,60/picture_size.y)
			draw_texture_rect(texture,Rect2(-picture_size/2,picture_size),false)
