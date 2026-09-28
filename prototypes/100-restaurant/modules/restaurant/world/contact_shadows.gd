extends Node2D
var world: Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world._foods): return
	for body in world._foods.get_children():
		if not body.visible or body == world._held or body.get_meta("dispensed", false) or body.get_meta("plated", false): continue
		if not body.get_meta("on_board", false): continue
		var polygon: PackedVector2Array = body.get_meta("fragment_polygon", PackedVector2Array())
		if polygon.size() < 3: continue
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for point in polygon: bounds = bounds.expand(point.rotated(body.rotation))
		var height: float = maxf(0, body.board_height)
		var center: Vector2 = body.position + Vector2(2, 4)
		var radius := Vector2(clampf(bounds.size.x * 0.43, 4, 44), clampf(bounds.size.y * 0.12, 2, 7))
		for ring in range(4, 0, -1):
			var points := PackedVector2Array()
			for index in 32:
				var angle := TAU * index / 32.0
				points.append(center + Vector2(cos(angle), sin(angle)) * radius * (0.6 + ring * 0.15 + height * 0.005))
			draw_colored_polygon(points, Color("543b26", 0.042 / (1.0 + height * 0.025)))
