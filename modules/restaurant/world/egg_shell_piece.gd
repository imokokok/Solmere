extends RigidBody2D
## The two waste pieces keep their own mass and the source egg's instance UID.
var side := 1
var _flight_origin := Vector2.ZERO
var _flight_target := Vector2.ZERO
var _flight_elapsed := -1.0
const FLIGHT_SECONDS := 0.55

func launch(from: Vector2, to: Vector2) -> void:
	_flight_origin = from
	_flight_target = to
	_flight_elapsed = 0.0
	position = from
	freeze = true
	collision_layer = 0
	collision_mask = 0

func _process(delta: float) -> void:
	if _flight_elapsed < 0.0: return
	_flight_elapsed += delta
	var t := clampf(_flight_elapsed / FLIGHT_SECONDS, 0.0, 1.0)
	position = _flight_origin.lerp(_flight_target, t) + Vector2(0, -57.0 * sin(PI * t))
	rotation = side * t * 2.8
	if t >= 1.0:
		_flight_elapsed = -1.0
		collision_layer = 64
		collision_mask = 1
		freeze = false
		linear_velocity = Vector2(-15.0, 20.0)
		angular_velocity = side * 2.0

func _ready() -> void:
	collision_layer = 64
	collision_mask = 1
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	linear_damp = 1.8
	angular_damp = 3.0
	var collision := CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([Vector2(-13, -8), Vector2(12, -8), Vector2(15, 0), Vector2(8, 10), Vector2(-11, 8)])
	collision.shape = shape
	add_child(collision)
	queue_redraw()

func _draw() -> void:
	var outer := PackedVector2Array([Vector2(-15, -8), Vector2(-6, -13), Vector2(7, -10), Vector2(15, -4), Vector2(11, 7), Vector2(3, 10), Vector2(-10, 7)])
	draw_colored_polygon(outer, Color("d6aa70"))
	var inside := PackedVector2Array([Vector2(-13, -7), Vector2(-5, -11), Vector2(6, -8), Vector2(12, -3), Vector2(8, 5), Vector2(2, 7), Vector2(-9, 5)])
	draw_colored_polygon(inside, Color("fff0d0"))
	draw_polyline(PackedVector2Array([Vector2(-10, 5), Vector2(-4, 1), Vector2(1, 5), Vector2(8, 2)]), Color("b28755"), 1.5, true)
	draw_circle(Vector2(-5, -5), 1.4, Color("fff8e7", 0.8))
