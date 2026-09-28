extends Node2D
var controller: Node2D
func _draw() -> void :
	if controller.world.cooking and controller.on_stove():
		_draw_burner_flame()
	var tex: = preload("res://modules/restaurant/world/pan_geometry.gd").TEXTURE
	# This texture is the horizontal opening; the separate front supplies depth.
	# Both share one ellipse, rather than painting two misaligned front rims.
	if tex: draw_texture_rect(tex, preload("res://modules/restaurant/world/pan_geometry.gd").ART_RECT, false)
	if controller.residue.total_kg() > 0.000001:
		var index := 0
		for item in controller.residue.components.values():
			var pigment := Color(str(item.color))
			pigment.a = clampf(float(item.mass_kg) * 950.0, 0.05, 0.7)
			_ellipse(Vector2(764 + (index % 4) * 29, 573 + (index / 4) * 6), Vector2(16, 5), pigment)
			index += 1
	var water: float = controller.water_ml
	if water > 0:
		var fill: float = controller.world.pan_fill_ratio()
		var geometry = preload("res://modules/restaurant/world/pan_geometry.gd")
		_ellipse(geometry.water_center(fill), geometry.water_radius(fill), Color("a1b9ae", 0.18))

func _draw_burner_flame() -> void:
	var strength: float = {"low": 0.55, "medium": 0.8, "high": 1.0}.get(str(controller.world.heat_level), 0.8)
	var now: float = controller.world._time
	_ellipse(Vector2(810, 622), Vector2(106, 9), Color(0.24, 0.51, 0.63, 0.17 * strength))
	for band in 2:
		var ribbon := PackedVector2Array()
		for i in 49:
			var x := 706.0 + i * 4.3
			var edge := pow(sin(i / 48.0 * PI), 0.55)
			var flicker := sin(x * 0.071 - now * 5.1) * 1.7 + sin(x * 0.139 + now * 7.7) * 0.8
			ribbon.append(Vector2(x, 624 - edge * (7.0 + flicker) * strength * (1.0 if band == 0 else 0.45)))
		for i in range(48, -1, -1): ribbon.append(Vector2(706.0 + i * 4.3, 625.0))
		draw_colored_polygon(ribbon, Color(0.20, 0.55, 0.76, 0.75) if band == 0 else Color(0.65, 0.81, 0.80, 0.86))

func _poly(points: Array, color: Color) -> void :
	draw_colored_polygon(PackedVector2Array(points), color)
func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void :
	var points: = PackedVector2Array()
	for i in range(24): points.append(center + Vector2.from_angle(i * TAU / 24.0) * radius)
	draw_colored_polygon(points, color)
