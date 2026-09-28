extends Button
## Small illustrated paper tabs; standard Button keyboard/focus/input behavior.
var symbol := "book"
var accent := Color("9a583d")
func _ready() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_override("font", preload("res://modules/restaurant/ui/paper_ink.gd").font())
	add_theme_font_size_override("font_size", 22)
	add_theme_color_override("font_color", Color("4b4033"))
	add_theme_color_override("font_hover_color", Color("382e25"))
	add_theme_color_override("font_pressed_color", Color("382e25"))
	add_theme_color_override("font_disabled_color", Color("8a9184"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var skin := StyleBoxFlat.new()
		skin.bg_color = Color.TRANSPARENT if state in ["normal", "disabled"] else Color("c29b60", 0.12)
		if state == "focus":
			skin.bg_color = Color.TRANSPARENT
			skin.border_color = accent
			skin.set_border_width_all(2)
		skin.set_corner_radius_all(2)
		skin.content_margin_left = 54 if not symbol.is_empty() else 14
		skin.content_margin_right = 14
		skin.content_margin_top = 10
		skin.content_margin_bottom = 10
		add_theme_stylebox_override(state, skin)
	resized.connect(queue_redraw)

func _draw() -> void:
	if symbol.is_empty(): return
	var p := Vector2(27, size.y * 0.5)
	var ink := accent if not disabled else Color("9b9b8c")
	if symbol == "book":
		for side in [-1, 1]:
			var poly := PackedVector2Array([p, p + Vector2(side * 19, -4), p + Vector2(side * 19, -23), p + Vector2(0, -19)])
			poly += PackedVector2Array([p])
			poly = Transform2D(0, Vector2(0, 11)) * poly
			draw_polyline(poly, ink, 2.5, true)
	elif symbol == "arrow":
		draw_line(p + Vector2(17, 0), p - Vector2(15, 0), ink, 3, true)
		draw_polyline(PackedVector2Array([p + Vector2(-3, -11), p + Vector2(-15, 0), p + Vector2(-3, 11)]), ink, 3, true)
	else:
		draw_arc(p, 17, 0, TAU, 32, ink, 2, true)
		draw_polyline(PackedVector2Array([p + Vector2(-8, 0), p + Vector2(-1, 7), p + Vector2(10, -7)]), ink, 3, true)
