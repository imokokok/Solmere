extends Control

var customer_id := "guest":
	set(value):
		customer_id = value
		queue_redraw()
var accent := Color("d7653e"):
	set(value):
		accent = value
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(118, 128)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var seed := absi(customer_id.hash())
	var center := Vector2(59, 64)
	var skin: Color = [Color("edc59b"), Color("d9aa7a"), Color("f0d0aa")][seed % 3]
	var hair: Color = [Color("415b54"), Color("72513d"), Color("344849")][seed % 3]
	draw_circle(center + Vector2(2, 41), 38, Color("f5dfa5", 0.48))
	draw_circle(center, 37, hair)
	draw_circle(center + Vector2(0, 7), 31, skin)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-30, -2), center + Vector2(-18, -34), center + Vector2(18, -36), center + Vector2(31, -3), center + Vector2(8, -18), center + Vector2(-8, -14)]), hair)
	for x in [-11.0, 11.0]: draw_circle(center + Vector2(x, 7), 2.3, Color("284b47"))
	draw_arc(center + Vector2(0, 13), 11, 0.35, PI - 0.35, 18, accent, 2.2, true)
	if seed % 3 == 0:
		draw_arc(center + Vector2(0, -22), 29, PI, TAU, 24, accent, 6.0, true)
	elif seed % 3 == 1:
		draw_line(center + Vector2(-27, 1), center + Vector2(27, 1), accent, 3.0, true)
		draw_circle(center + Vector2(-11, 7), 8, Color.TRANSPARENT)
		draw_arc(center + Vector2(-11, 7), 8, 0, TAU, 18, Color("284b47"), 1.5, true)
		draw_arc(center + Vector2(11, 7), 8, 0, TAU, 18, Color("284b47"), 1.5, true)
	else:
		draw_circle(center + Vector2(27, -15), 8, accent)
	draw_string(get_theme_default_font(), Vector2(14, 121), "给主厨的小画", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("64756a"))
