extends Node2D
## The edge is aligned with the lower side of the drawn steel, not the handle.
const BLADE_MID := Vector2(-50, -22)
var cutting_guide := false:
	set(value):
		cutting_guide = value
		queue_redraw()

func _draw() -> void :
	paint(self)

func paint(target: Node2D) -> void:
	var tex: = preload("res://modules/restaurant/assets/sprite_library.gd").gear(6)
	if tex:
		target.draw_set_transform(Vector2.ZERO, 0.22)
		target.draw_texture_rect(tex, Rect2(-93, -24, 188, 52), false)
		target.draw_set_transform(Vector2.ZERO)
	if cutting_guide:
		var gold := Color(1.0, 0.84, 0.43, 0.85)
		target.draw_circle(BLADE_MID, 3.0, gold)
		target.draw_line(BLADE_MID + Vector2(0, 5), BLADE_MID + Vector2(0, 19), gold, 2.0, true)
		target.draw_colored_polygon(PackedVector2Array([BLADE_MID + Vector2(-5, 15), BLADE_MID + Vector2(5, 15), BLADE_MID + Vector2(0, 22)]), gold)
