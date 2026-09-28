extends Node2D

var world: Node2D
var center: = Vector2(1455, 630)
var active: = false
var moved: = false
var origin: = Vector2.ZERO
var pointer_origin: = Vector2.ZERO
var platform: StaticBody2D
func _ready() -> void :
	z_index = 4
	platform = StaticBody2D.new()
	platform.position = center + Vector2(0, 31)
	platform.collision_layer = 1
	var shape: = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(216, 14)
	platform.add_child(shape)
	world.add_child(platform)
	_sync()
func _draw() -> void :
	paint(self)

func paint(target: Node2D) -> void:
	if str(world.plate_presentation.get("vessel", "plate")) == "bowl":
		_ellipse(target, center + Vector2(0, 7), Vector2(124, 44), Color("85785d"))
		_ellipse(target, center, Vector2(120, 40), Color("f6ead1"))
		_ellipse(target, center, Vector2(99, 27), Color("bdad88"))
		if float(world.plate_presentation.get("broth_ml", 0.0)) > 0.001:
			_ellipse(target, center + Vector2(0, 2), Vector2(95, 25), Color("c6ab66", 0.72))
		return
	var tex: = preload("res://modules/restaurant/assets/sprite_library.gd").gear(1)
	if tex: target.draw_texture_rect(tex, Rect2(center - Vector2(123, 39), Vector2(246, 86)), false)

func _ellipse(target: Node2D, at: Vector2, radius: Vector2, color: Color) -> void:
	var polygon := PackedVector2Array()
	for index in 48:
		polygon.append(at + Vector2.from_angle(float(index) * TAU / 48.0) * radius)
	target.draw_colored_polygon(polygon, color)
func _input(event: InputEvent) -> void :
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pointer: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
		if not event.pressed and active:
			finish()
			get_viewport().set_input_as_handled()
		elif event.pressed and world.controls_enabled and not world.pan.active and not world._knife_held and not world.has_active_utensil() and not is_instance_valid(world._held) and (hit_rect().has_point(pointer) or Rect2(1320,542,235,75).has_point(pointer)):
			active = true
			moved = false
			origin = center
			pointer_origin = pointer
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and active:
		var pointer: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
		if pointer.distance_to(pointer_origin) > 7: moved = true
		if moved: move_to(origin + pointer - pointer_origin)
		get_viewport().set_input_as_handled()
func hit_rect() -> Rect2: return Rect2(center - Vector2(123, 39), Vector2(246, 86))
func move_to(destination: Vector2) -> void :
	var next: = destination.clamp(Vector2(130, 580), Vector2(1470, 738))
	var delta: = next - center
	center = next
	for body in world._foods.get_children():
		if body.get_meta("plated", false):
			body.position += delta
			body.set_deferred("position", body.position)
	_sync()
func _sync() -> void :
	platform.position = center + Vector2(0, 31)
	platform.collision_layer = 0 if active and moved else 1
	world._stations.plate = hit_rect()
	queue_redraw()
func finish(open_editor: = true) -> void :
	if not active: return
	active = false
	_sync()
	if not moved and open_editor and world.controls_enabled: world.interaction.emit("plate", "")
func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: finish(false)
