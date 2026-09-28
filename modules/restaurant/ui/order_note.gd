extends Node2D
func _draw() -> void :
	draw_rect(Rect2(-7, -9, 232, 286), Color("795439"))
	draw_colored_polygon(PackedVector2Array([Vector2(3, 1), Vector2(219, -1), Vector2(223, 268), Vector2(2, 271)]), Color("b59e7d"))
	draw_rect(Rect2(0, 0, 218, 264), Color("ecd5af"))
	for x in [24, 194]:
		draw_circle(Vector2(x, 6), 4, Color("5f4634"))
		draw_line(Vector2(x, 5), Vector2(x, -17), Color("594233"), 5, true)
		draw_arc(Vector2(x - 3, -17), 4, - PI, 0, 12, Color("bc9874"), 2, true)
	draw_line(Vector2(15, 48), Vector2(199, 48), Color("c5a882"), 1)
