extends Node2D

var definition: Dictionary = {}
var polygon: = PackedVector2Array()
var art_offset: = Vector2.ZERO
var cut: = true
var heat := 0.0:
	set(value):
		if is_equal_approx(heat, value): return
		heat = value
		queue_redraw()
var softness := 0.0
var cut_style := "slice"
var cut_variant := 0
var source_fraction := 0.5
var thermal: Dictionary = {}
var coating: Dictionary = {}
var _skin: Polygon2D
var _face: Polygon2D
var source_rect := Rect2()
var _last_appearance: Dictionary = {}

func _ready() -> void:
	var library = preload("res://modules/restaurant/assets/sprite_library.gd")
	var source_scale: float = library.physical_art_scale(str(definition.get("id", "")))
	var source: Texture2D = library.food(str(definition.get("id", "")))
	source_rect = library.fit(source, Vector2.ZERO, Vector2(78, 78))
	source_rect = Rect2(source_rect.position * source_scale, source_rect.size * source_scale)
	# Direct polygon UVs cut the original silhouette in one draw. Each fragment
	# used to allocate a separate clipping surface containing a full food image.
	_skin = _textured_face(source)
	var texture := preload("res://modules/restaurant/assets/cut_state_library.gd").interior_texture(str(definition.get("id", "")))
	if texture != null:
		_face = _textured_face(texture)
		_face.modulate.a = clampf(0.97 - source_fraction * 0.65, 0.18, 0.90)
		_face.material.set_shader_parameter("use_source_mask", true)
		_face.material.set_shader_parameter("source_mask", source)
	_update_face()
	queue_redraw()

func _textured_face(texture: Texture2D) -> Polygon2D:
	var face := Polygon2D.new()
	face.polygon = polygon
	face.texture = texture
	var uv := PackedVector2Array()
	for point in polygon: uv.append((point - art_offset - source_rect.position) / source_rect.size * texture.get_size())
	face.uv = uv
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://modules/restaurant/assets/cooking_surface.gdshader")
	face.material = shader
	add_child(face)
	return face

func _process(_delta: float) -> void:
	_update_face()

func _update_face() -> void:
	var appearance := preload("res://modules/restaurant/assets/cooking_appearance.gd").surface(definition, heat, thermal, coating)
	if appearance == _last_appearance: return
	for face in [_skin, _face]:
		if not is_instance_valid(face): continue
		for key in appearance:
			if appearance[key] != _last_appearance.get(key): face.material.set_shader_parameter(key, appearance[key])
	_last_appearance = appearance

func _draw() -> void:
	if polygon.size() < 3: return
	var library = preload("res://modules/restaurant/assets/sprite_library.gd")
	var id := str(definition.get("id", ""))
	var source_scale: float = library.physical_art_scale(id)
	var flesh := preload("res://modules/restaurant/assets/cooking_appearance.gd").edge_color(definition, heat)
	# Only interior knife edges receive a shallow exposed side. The old renderer
	# outlined every convex-hull edge, turning irregular food into hard triangles.
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		if a.distance_to(b) < 3.0: continue
		var middle := (a + b) * 0.5
		var outward := Vector2(-(b-a).y, (b-a).x).normalized()
		var inside_a: float = library.alpha_at(id, (middle + outward * 1.6 - art_offset) / source_scale)
		var inside_b: float = library.alpha_at(id, (middle - outward * 1.6 - art_offset) / source_scale)
		if minf(inside_a, inside_b) < 0.45: continue
		var thickness := clampf(sqrt(maxf(source_fraction, 0.001)) * 3.5, 0.6, 2.6)
		var down := Vector2(0, thickness).rotated(-global_rotation)
		# A vertical edge can be parallel to the projected thickness. It has no
		# visible side area and cannot be triangulated as a filled quadrilateral.
		if absf((b-a).cross(down)) > 0.05:
			draw_colored_polygon(PackedVector2Array([a, b, b + down, a + down]), flesh.darkened(0.12))
		draw_line(a, b, flesh.lightened(0.06), 0.7, true)
