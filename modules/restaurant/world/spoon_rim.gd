extends Node2D

var tool: Node2D

func paint(target: Node2D) -> void :


	# Draw the front lip inside the existing bowl.  The former filled crescent
	# extended below the sprite and looked like a detached, cracked half.
	var center: = Vector2(-23, -1)
	var rim: = PackedVector2Array()
	for i in range(17):
		var angle: = lerpf(0.14, PI - 0.14, float(i) / 16.0)
		rim.append(center + Vector2(cos(angle) * 17.0, sin(angle) * 6.0))
	# Empty bowl already has its painted rim. Drawing a second dark arc over it
	# made it look split in two; add occlusion only when something sits inside.
	if is_instance_valid(tool) and not tool.bowl_contents().is_empty():
		target.draw_polyline(rim, Color("b9854b"), 1.3, true)

func _draw() -> void :
	paint(self)
