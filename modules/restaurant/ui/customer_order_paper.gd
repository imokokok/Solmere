extends Control
signal opened
const Ink = preload("res://modules/restaurant/ui/paper_ink.gd")
var heading: Label
var body: Label
var footer: Label
var mood: Control
var full_text := ""
var reading_sections: Array[Dictionary] = []

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var paper = preload("res://modules/restaurant/ui/paper_surface.gd").new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(paper)
	paper.z_index=-1
	heading = _label(Vector2(19,29),Vector2(size.x-87,34),24)
	heading.clip_text = true
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body = _label(Vector2(19,79),Vector2(size.x-38,size.y-125),20)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.clip_text = true
	body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_setup_footer()
	mood = preload("res://modules/restaurant/ui/mood_icon.gd").new()
	mood.position = Vector2(size.x-64,26)
	add_child(mood)
	tooltip_text = "拿近一点，读完整的叮嘱"

func _setup_footer() -> void:
	footer = _label(Vector2(19,size.y-32),Vector2(size.x-36,25),14)
	footer.modulate = Color("978565")

func _label(point: Vector2, box: Vector2, font_size: int) -> Label:
	var value := Label.new()
	value.position = point
	value.size = box
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.add_theme_font_override("font",Ink.font())
	value.add_theme_font_size_override("font_size",font_size)
	value.add_theme_color_override("font_color",Color("5b4935"))
	add_child(value)
	return value

func update_order(npc: Dictionary, wait: float, preference: String) -> void:
	reading_sections.clear()
	mood.visible = not npc.is_empty()
	if npc.is_empty():
		heading.text = "留给主厨"
		body.text = "今天，慢慢来。\n\n先做一道你喜欢的菜，等街坊们来坐坐。"
		footer.text = "100饭店的小纸条"
		reading_sections.append({"title":"慢慢来", "items":["先做一道你喜欢的菜，等街坊们来坐坐。"]})
	else:
		heading.text = str(npc.get("name","客人"))
		heading.add_theme_font_size_override("font_size",20 if heading.text.length()>6 else 24)
		var words := str(npc.get("quote","今天想吃点什么？"))
		reading_sections.append({"title":"今天想吃", "items":[words]})
		if npc.has("ordered_recipe"):
			var order := "想点《%s》。" % str(npc.ordered_recipe.get("title",""))
			words += "\n\n" + order
			reading_sections.append({"title":"点的菜", "items":[order]})
		if npc.get("preferences_known",false):
			words += "\n\n小叮嘱：" + preference
			reading_sections.append({"title":"口味与习惯", "items":Array(preference.split("\n"))})
		body.text = words
		mood.mood = float(npc.get("mood_before",50))
		footer.text = "还能等 %d:%02d，拿近读" % [int(ceil(wait))/60,int(ceil(wait))%60]
	full_text = heading.text + "\n\n" + body.text

func _draw() -> void:
	# A short pencilled rule and an off-centre translucent tape tab.
	draw_polyline(PackedVector2Array([Vector2(18,68),Vector2(size.x*.48,69),Vector2(size.x-22,67)]),Color("b59570",0.5),1.2,true)
	# The original room has an empty clipped sheet. This replacement sheet covers
	# its top edge; two visible clips now connect the note to that board.
	for x in [22.0, size.x - 22.0]:
		draw_line(Vector2(x, -9), Vector2(x, 7), Color("3d3630", 0.55), 6.0, true)
		draw_circle(Vector2(x, 8), 5.0, Color("4b4036"))
		draw_circle(Vector2(x - 1, 7), 2.0, Color("bca88a"))
	draw_colored_polygon(PackedVector2Array([Vector2(83,8),Vector2(154,10),Vector2(152,22),Vector2(84,20)]),Color("bcad7c",0.42))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		opened.emit()
		accept_event()
