extends Node2D
## Translucent surface is above immersed ingredients and below the opaque rim.
var controller: Node2D
const Geometry = preload("res://modules/restaurant/world/pan_geometry.gd")
func _draw() -> void:
	if controller.water_ml <= 0.0: return
	var fill: float = controller.world.pan_fill_ratio()
	var center := Geometry.water_center(fill)
	var radius := Geometry.water_radius(fill)
	var points := PackedVector2Array()
	for i in 48:
		var p := center + Vector2.from_angle(i * TAU / 48.0) * radius
		p.y += ((p.x-center.x)/radius.x) * clampf(controller.slosh*8.0, -5.0,5.0)
		points.append(p)
	draw_colored_polygon(points, Color("b6c9b6", 0.16))
	var boiling: float = controller.world.reactions.water_activity()
	if boiling <= 0.08: return
	for i in 8:
		var phase: float = fmod(controller.world._time * 1.8 + i * 0.173, 1.0)
		var p := center + Vector2(sin(i * 5.17) * radius.x * 0.72, cos(i * 3.1) * radius.y * 0.6)
		draw_arc(p, (1.5 + phase * 4) * boiling, 0, TAU, 12, Color("e2e7cf", (1.0 - phase) * 0.65), 1.0, true)
