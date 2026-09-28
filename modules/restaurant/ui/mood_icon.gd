extends Control


var mood: = 50.0:
	set(value):
		mood = clampf(value, 0.0, 100.0)
		queue_redraw()

func _ready() -> void :
	custom_minimum_size = Vector2(58, 58)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void :
	var center: = size * 0.5
	var warmth: = mood / 100.0
	var face: = Color("d8aa72").lerp(Color("efc979"), warmth)
	draw_circle(center, 24, Color("6d5945"))
	draw_circle(center, 21.5, face)
	for x in [-7.0, 7.0]:
		draw_circle(center + Vector2(x, -5), 2.2, Color("493e34"))
	var bend: = (warmth - 0.5) * 11.0
	var mouth: = PackedVector2Array()
	for i in range(13):
		var x: = -9.0 + i * 1.5
		var y: = 7.0 + bend * (1.0 - (x / 9.0) * (x / 9.0))
		mouth.append(center + Vector2(x, y))
	draw_polyline(mouth, Color("60483a"), 2.2, true)
	draw_line(center + Vector2(-15, -13), center + Vector2(-4, -13 - bend * 0.6), Color("745845"), 1.6, true)
	draw_line(center + Vector2(15, -13), center + Vector2(4, -13 - bend * 0.6), Color("745845"), 1.6, true)
