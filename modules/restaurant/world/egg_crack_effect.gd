extends Node2D
## A short liquid bridge makes the shell-to-egg transition visible in the pan.
signal finished
var origin := Vector2.ZERO
var target := Vector2.ZERO
var elapsed := 0.0
const DURATION := 0.64

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= DURATION:
		finished.emit()
		queue_free()

func _draw() -> void:
	var t := clampf(elapsed / DURATION, 0.0, 1.0)
	if t < 0.82:
		var length := smoothstep(0.0, 0.38, t)
		var end := origin.lerp(target, length)
		var width := 7.0 * (1.0 - smoothstep(0.57, 0.82, t))
		draw_line(origin, end, Color("fff6da", 0.86), maxf(0.5, width), true)
		var yolk := origin.lerp(target, smoothstep(0.05, 0.72, t))
		draw_circle(yolk, 7.0 + 2.0 * sin(t * PI), Color("f2b83e"))
		draw_circle(yolk + Vector2(-2, -2), 2.1, Color("ffe69d", 0.75))
	if t > 0.4:
		var spread := smoothstep(0.4, 1.0, t)
		var white := PackedVector2Array()
		for i in 32: white.append(target + Vector2.from_angle(i * TAU / 32.0) * Vector2(8.0 + spread * 25.0, 5.0 + spread * 8.0))
		draw_colored_polygon(white, Color("efead0", spread * 0.36))
		draw_circle(target + Vector2(3, -2), 4.0 + spread * 8.0, Color("f3ba47", spread))
