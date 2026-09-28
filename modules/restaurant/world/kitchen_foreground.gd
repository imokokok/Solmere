extends Node2D
var controller: Node2D
const Geometry = preload("res://modules/restaurant/world/pan_geometry.gd")

func _ready() -> void:
	var front := Sprite2D.new()
	front.texture = Geometry.TEXTURE
	front.centered = false
	front.position = Geometry.ART_RECT.position
	front.scale = Geometry.ART_RECT.size / front.texture.get_size()
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://modules/restaurant/assets/pan_front.gdshader")
	front.material = mask
	add_child(front)

func _draw() -> void:
	# Only runoff is separate; the opaque front comes from the shared painting.
	if is_instance_valid(controller) and controller.world._overflow_until > controller.world._time:
		var path := PackedVector2Array()
		for i in range(17):
			var t := float(i) / 16.0
			path.append(Vector2(922 + 12 * sin(t * PI * 0.5), 593 + t * 48))
		draw_polyline(path, controller.world._overflow_color, 3.0, true)
