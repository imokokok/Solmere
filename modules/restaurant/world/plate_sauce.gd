extends Node2D
var canvas: Control
var world: Node2D
func _process(_delta: float) -> void : queue_redraw()
func _draw() -> void :
	var data: Dictionary = canvas.presentation_data() if is_instance_valid(canvas) else world.plate_presentation
	var center: Vector2 = canvas.center() if is_instance_valid(canvas) else world.plate.center
	var radius: Vector2 = canvas.radius() if is_instance_valid(canvas) else Vector2(100, 20)
	for stroke in data.get("strokes", []):
		var points: = PackedVector2Array()
		for p in stroke.get("points", []): points.append(center + Vector2(p[0], p[1]) * radius)
		if points.is_empty(): continue
		var color: = Color.from_string(str(stroke.get("color", "d96143")), Color("d96143"))
		var width: float = float(stroke.get("width", 12)) * (1.0 if is_instance_valid(canvas) else 0.28)
		if points.size() > 1: draw_polyline(points, color, width, true)
		for point in [points[0], points[-1]]: draw_circle(point, width * 0.5, color)
