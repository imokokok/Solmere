extends RefCounted
## Authored tabletop and cutout pieces; coordinates remain native game hit areas.
const TABLE = preload("res://art/ui/pocket_doodles/chess_table.png")
const PIECES = preload("res://art/ui/pocket_doodles/chess_pieces.png")
const INK := Color("594c38")
const WOOD := Color("edcf98")
const SAGE := Color("9ea786")
const ORIGIN := Vector2(250, 177)
const EXTENT := 608.0

static func tabletop(canvas: CanvasItem) -> void:
	canvas.draw_texture_rect(TABLE, Rect2(0, 0, 1579, 972), false)
	# The bowls are part of the painted table. Fill only their inner wells so
	# the original ink rims, wood grain, and paper remain untouched.
	_bowl_stones(canvas, Vector2(92, 300), false)
	_bowl_stones(canvas, Vector2(92, 463), true)

static func _bowl_stones(canvas: CanvasItem, center: Vector2, dark: bool) -> void:
	var positions := [
		Vector2(-25, -22), Vector2(-11, -28), Vector2(6, -27), Vector2(23, -21),
		Vector2(-33, -9), Vector2(-19, -14), Vector2(-3, -11), Vector2(13, -14), Vector2(29, -8),
		Vector2(-29, 3), Vector2(-15, 0), Vector2(2, 3), Vector2(19, 0), Vector2(32, 5),
		Vector2(-27, 16), Vector2(-10, 14), Vector2(6, 17), Vector2(22, 16),
		Vector2(-15, 26), Vector2(1, 25), Vector2(16, 25),
	]
	var face := Color("40584e") if dark else Color("f5ead2")
	var edge := Color("283b32") if dark else Color("806e54")
	var gleam := Color("a9beaa", 0.68) if dark else Color("fffdf0", 0.75)
	canvas.draw_circle(center + Vector2(0, 7), 40, Color(INK, 0.16))
	for i in positions.size():
		var at: Vector2 = center + positions[i] + (Vector2(1.5, -1) if dark and i % 4 == 0 else Vector2.ZERO)
		var radius := 10.3 + float((i * 7) % 5) * 0.38
		canvas.draw_circle(at + Vector2(1.0, 2.5), radius + 1.4, Color(INK, 0.3))
		canvas.draw_circle(at, radius, face)
		canvas.draw_circle(at + Vector2(-2.4, -2.2), radius * 0.56, Color(gleam, 0.28))
		canvas.draw_arc(at, radius - 0.5, 0, TAU, 28, edge, 1.2, true)
		canvas.draw_arc(at + Vector2(-1.5, -1.2), radius * 0.7, PI * 1.09, PI * 1.68, 12, gleam, 1.25, true)

static func piece(canvas: CanvasItem, kind: int, side: int, rect: Rect2) -> void:
	# Keep one full atlas cell so the relative heights of pawn and king survive.
	var source := Rect2((kind - 1) * 256, 76 if side > 0 else 520, 256, 436)
	var at := Rect2(rect.position + Vector2(rect.size.x * .11, 2), Vector2(rect.size.x * .78, rect.size.y - 4))
	canvas.draw_texture_rect_region(PIECES, at, source)

static func stone(canvas: CanvasItem, at: Vector2, radius: float, side: int) -> void:
	canvas.draw_circle(at + Vector2(1, 2), radius, Color(INK, .16))
	canvas.draw_circle(at, radius, Color("52665d") if side > 0 else Color("fcf0d3"))
	canvas.draw_arc(at, radius, 0, TAU, 36, INK, 1.3, true)
	canvas.draw_arc(at + Vector2(-radius * .08, -radius * .04), radius * .77, PI * 1.12, PI * 1.55, 12, Color("d7cba9", .35), 1.0, true)

static func grid(canvas: CanvasItem, n: int, origin: Vector2 = ORIGIN) -> void:
	var cell := EXTENT / (n - 1)
	for i in n:
		canvas.draw_line(origin + Vector2(i * cell, 0), origin + Vector2(i * cell, EXTENT), Color(INK, .77), 1.4, true)
		canvas.draw_line(origin + Vector2(0, i * cell), origin + Vector2(EXTENT, i * cell), Color(INK, .77), 1.4, true)
	var stars := [3, int(n / 2), n - 4] if n != 9 else [2, 4, 6]
	for x in stars:
		for y in stars:
			if n == 19 or x == y or x + y == n - 1:
				canvas.draw_circle(origin + Vector2(x, y) * cell, 3.5, INK)
