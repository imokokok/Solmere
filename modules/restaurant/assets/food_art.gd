extends Node2D


var definition: Dictionary = {}:
	set(value):
		definition = value
		queue_redraw()
var cut: = false:
	set(value):
		cut = value
		queue_redraw()
var heat: = 0.0:
	set(value):
		heat = value
		queue_redraw()
var softness: = 0.0:
	set(value):
		softness = clampf(value, 0.0, 1.0)
		queue_redraw()
var shadows: = true
var storage_clip := Rect2(-10000, -10000, 20000, 20000)
var flex := 0.0
var dangling := 0.0
var motion_time := 0.0
var thermal: Dictionary = {}:
	set(value):
		thermal=value
		queue_redraw()
var coating: Dictionary = {}:
	set(value):
		coating=value
		queue_redraw()
var compression := 0.0:
	set(value):
		compression = value
		queue_redraw()
var crack_progress := 0.0:
	set(value):
		crack_progress = value
		queue_redraw()

const CREAM: = Color("c7bca6")
const GREEN: = Color("6e7455")
const OUTLINE: = Color("302e29")
var _current_id: = ""
const CookingAppearance = preload("res://modules/restaurant/assets/cooking_appearance.gd")
const CookingSurface = preload("res://modules/restaurant/assets/cooking_surface.gdshader")
var _cooking_material: ShaderMaterial

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _draw() -> void :
	var id: String = str(definition.get("id", "tomato"))
	var base: = Color.from_string(str(definition.get("color", "e65d4f")), Color("e65d4f"))

	if id == "noodles":
		material = null
		_current_id = id
		var raw_noodles: Texture2D = preload("res://modules/restaurant/assets/sprite_library.gd").food(id)
		var loosened := clampf(softness * 3.0, 0.0, 1.0)
		if raw_noodles != null and loosened < 1.0:
			var raw_rect := preload("res://modules/restaurant/assets/sprite_library.gd").fit(raw_noodles, Vector2.ZERO, Vector2(78, 78))
			_draw_supported_texture(raw_noodles, raw_rect, Color(1, 1, 1, 1.0 - loosened))
		if loosened > 0.0: _noodles(base, loosened)
		return
	# Only the player's rim strikes open the egg. The same thermal record then
	# carries the edible portion through cooking, plating and recipe snapshots.
	if id == "egg" and not cut and bool(thermal.get("egg_opened", false)):
		material = null
		_fried_egg()
		return
	var painted: Texture2D = preload("res://modules/restaurant/assets/sprite_library.gd").food(id)
	if cut:
		var sliced := preload("res://modules/restaurant/assets/cut_state_library.gd").texture(id, "slice")
		if sliced != null: painted = sliced
	if painted:
		if _cooking_material == null:
			_cooking_material = ShaderMaterial.new()
			_cooking_material.shader = CookingSurface
		var appearance := CookingAppearance.surface(definition, heat,thermal,coating)
		for key in appearance:
			_cooking_material.set_shader_parameter(key, appearance[key])
		material = _cooking_material
		var rect := preload("res://modules/restaurant/assets/sprite_library.gd").fit(painted, Vector2.ZERO, Vector2(78, 78))
		if not thermal.is_empty() and float(thermal.get("liquid_kg",0.0))>0.000001:
			var initial := maxf(0.000001,float(thermal.initial_kg))
			var liquid := clampf(float(thermal.liquid_kg)/initial,0.0,1.0)
			var solid := clampf(1.0-(float(thermal.converted_kg)+float(thermal.evaporated_kg))/initial,0.0,1.0)
			var pool := PackedVector2Array()
			for i in 32:
				var angle := i*TAU/32.0
				pool.append(Vector2(cos(angle)*(22.0+liquid*19.0),sin(angle)*(9.0+liquid*12.0)+13.0))
			draw_colored_polygon(pool,base.lightened(0.06))
			draw_arc(Vector2(2,11),12.0+liquid*12.0,0.3,2.3,18,base.lightened(0.24),1.8,true)
			if solid<0.025: return
			rect=Rect2(rect.position*sqrt(solid),rect.size*sqrt(solid))
		if id == "sock" and (absf(flex) > 0.01 or dangling > 0.01):
			_draw_cloth(painted, rect)
		elif definition.get("dispense_mode", "") == "squeeze" and compression > 0.0001:
			_draw_grip_mesh(painted, rect)
		else: _draw_supported_texture(painted, rect)
		if id == "egg" and crack_progress > 0.0:
			_draw_egg_fissure(rect)
		return
	_current_id = id
	if heat > 28.0:
		base = base.lerp(Color("634231"), clampf((heat - 28.0) / 50.0, 0, 0.72))
	if shadows:
		draw_colored_polygon(PackedVector2Array([Vector2(-26, 28), Vector2(-16, 23), Vector2(20, 22), Vector2(35, 29), Vector2(18, 34), Vector2(-18, 34)]), Color(0.018, 0.024, 0.023, 0.36))
	match id:
		"tomato", "apple", "peach", "pumpkin", "onion", "garlic":
			_round_produce(id, base)
		"egg", "century_egg":
			_egg(id, base)
		"carrot", "chili", "banana", "eggplant", "cucumber", "bitter_melon":
			_long_produce(id, base)
		"grapes", "strawberry", "lemon", "watermelon", "mango", "durian":
			_fruit(id, base)
		"cabbage", "lettuce", "spinach", "houttuynia", "broccoli", "bean_sprout", "seaweed":
			_greens(id, base)
		"mushroom":
			_mushroom(base)
		"noodles", "tapioca", "natto":
			_bowl(id, base)
		"shrimp", "fish", "salmon", "squid", "mussel":
			_seafood(id, base)
		"chicken", "pork", "beef", "sausage":
			_meat(id, base)
		"cheese", "blue_cheese", "tofu", "stinky_tofu", "butter", "chocolate", "bread":
			_block(id, base)
		"potato", "lotus_root", "ginger":
			_root(id, base)
		"corn":
			_corn(base)
		"milk", "yogurt", "tea", "vinegar", "soy_sauce", "oil", "sesame_oil", "honey":
			_liquid(id, base)
		"salt", "sugar", "pepper", "cumin", "curry", "mustard", "chili_sauce", "ketchup", "mayonnaise", "miso":
			_seasoning(id, base)
		"ice_cream":
			_ice_cream(base)
		"sock", "paper", "soap", "eraser", "button", "spring", "confetti", "toy_brick", "candle", "rock":
			_odd(id, base)
		_:
			_round_produce(id, base)
	if cut:

		for i in 3:
			_ellipse(Vector2(27 + i * 4, 24 - i * 3), Vector2(2.4, 1.6), base.lightened(0.15))

func _draw_supported_texture(texture: Texture2D, rect: Rect2, tint := Color.WHITE) -> void:
	var visible := rect.intersection(storage_clip)
	if not visible.has_area(): return
	var source := Rect2((visible.position - rect.position) / rect.size * texture.get_size(), visible.size / rect.size * texture.get_size())
	draw_texture_rect_region(texture, visible, source, tint)

func _fried_egg() -> void:
	var cooked: float = clampf(float(thermal.get("egg_white_set", thermal.get("cooked", 0.0))), 0.0, 1.0)
	var yolk_set: float = clampf(float(thermal.get("egg_yolk_set",0.0)),0,1)
	var brown: float = maxf(float(thermal.get("brown", [0.0, 0.0])[0]), float(thermal.get("brown", [0.0, 0.0])[1]))
	var burnt: float = maxf(float(thermal.get("char", [0.0,0.0])[0]),float(thermal.get("char", [0.0,0.0])[1]))
	var outline := Color("e0cb8f",0.22 + cooked*0.6).lerp(Color("ae6a35"),brown).lerp(Color("342820"),burnt)
	var white := Color("e4ddbc",0.24 + cooked*0.76).lerp(Color("fff0d4"),cooked).lerp(Color("e0bb7a"),brown*0.48).lerp(Color("66513a"),burnt*0.75)
	var edge := PackedVector2Array([
		Vector2(-36, -3), Vector2(-32, -14), Vector2(-19, -17), Vector2(-13, -23),
		Vector2(1, -19), Vector2(12, -22), Vector2(25, -14), Vector2(35, -8),
		Vector2(31, 5), Vector2(36, 12), Vector2(20, 17), Vector2(7, 15),
		Vector2(-5, 20), Vector2(-18, 14), Vector2(-31, 13)
	])
	draw_colored_polygon(edge, outline)
	var inside := PackedVector2Array()
	for point in edge: inside.append(point * 0.92 + Vector2(0, -1))
	draw_colored_polygon(inside, white)
	_egg_oval(Vector2(4, -1), Vector2(15, 11), Color("ad7334", 0.42))
	_egg_oval(Vector2(3, -4), Vector2(13, 11 - yolk_set*1.5), Color("eaa331").lerp(Color("eec966"),yolk_set).lerp(Color("79532e"),burnt*0.6))
	_egg_oval(Vector2(-1, -8), Vector2(4, 2), Color("fff0ae", 0.7-yolk_set*0.5))
	if cooked > 0.1:
		for i in 7:
			var p := Vector2(sin(i*4.7)*26,cos(i*2.3)*12)
			if p.distance_to(Vector2(3,-4)) > 16:
				_egg_oval(p,Vector2(2.4,1.4),Color(1,0.96,0.8,cooked*0.4))

func _egg_oval(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 24:
		var angle := TAU * index / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _draw_egg_fissure(rect: Rect2) -> void:
	var c := rect.get_center()
	var line := PackedVector2Array([
		c + Vector2(-22, -7), c + Vector2(-15, -11), c + Vector2(-9, -6),
		c + Vector2(-3, -10), c + Vector2(4, -5), c + Vector2(11, -9), c + Vector2(19, -4)
	])
	draw_polyline(line, Color("88623d", 0.9), 2.8, true)
	draw_polyline(line + PackedVector2Array([c + Vector2(23, 0)]), Color("fff7df", 0.65), 1.0, true)

func grip_vertex(uv: Vector2, rect: Rect2) -> Vector2:
	# The cap and base retain their original position. Only the middle grip
	# narrows; every vertex, including the label, follows the same local mesh.
	var sideways: bool = str(definition.get("id", "")) == "toothpaste"
	var along := uv.x if sideways else uv.y
	var across := uv.y if sideways else uv.x
	var grip := pow(sin(clampf((along - 0.16) / 0.7, 0.0, 1.0) * PI), 2.0)
	across = 0.5 + (across - 0.5) * (1.0 - compression * grip)
	var mapped := Vector2(along, across) if sideways else Vector2(across, along)
	return rect.position + mapped * rect.size

func _draw_grip_mesh(texture: Texture2D, rect: Rect2) -> void:
	for y in 12:
		for x in 4:
			var uv := PackedVector2Array([Vector2(x / 4.0, y / 12.0), Vector2((x + 1) / 4.0, y / 12.0), Vector2((x + 1) / 4.0, (y + 1) / 12.0), Vector2(x / 4.0, (y + 1) / 12.0)])
			var vertices := PackedVector2Array()
			for point in uv: vertices.append(grip_vertex(point, rect))
			draw_polygon(vertices, PackedColorArray([Color.WHITE]), uv, texture)

func _noodles(base: Color, alpha: float = 1.0) -> void :
	var state := CookingAppearance.surface(definition, heat,thermal,coating)
	var noodle_color := base.lightened(softness * 0.2).lerp(Color("aa7036"), state.browned * 0.6).lerp(Color("30251c"), state.charred)
	if state.film_amount>0.0: noodle_color=noodle_color.lerp(state.film_color,state.film_amount*(0.3+state.film_spread*0.4))
	noodle_color.a = alpha
	var spread: = lerpf(27.0, 67.0, softness)
	var depth: = lerpf(18.0, 12.0, softness)
	for strand in 13:
		var row: = float(strand - 6)
		var points: = PackedVector2Array()
		for segment in 9:
			var ratio: = float(segment) / 8.0
			var x: = lerpf( - spread, spread, ratio)
			var wave: = sin(ratio * TAU * 1.45 + strand * 0.73) * lerpf(5.0, 2.5, softness)
			var y: = row * depth / 7.0 + wave + sin(strand * 1.7) * 1.6
			var lift := dangling * softness
			var hanging := Vector2(row * 1.9 + sin(ratio * 3.7 + strand * 0.2) * (7.0 + absf(flex)*9.0) + flex*ratio*ratio*25.0, -18.0 + ratio * (55.0 + strand % 4 * 5.0))
			points.append(Vector2(x, y).lerp(hanging, lift))
		draw_polyline(points, noodle_color.darkened(0.32), 4.4, true)
		draw_polyline(points, noodle_color.lightened(0.16), 2.5, true)
		if dangling * softness > 0.2:
			var drip := fmod(motion_time * 0.7 + strand * 0.17, 1.0)
			draw_line(points[-1] + Vector2(0, drip*25), points[-1]+Vector2(0,drip*25+3), Color(0.72,0.86,0.81,(1.0-drip)*0.4*softness),1.1,true)

func _draw_cloth(texture: Texture2D, rect: Rect2) -> void:
	# A shared strip mesh keeps the commissioned sock pixels and joins intact.
	# This is visual flex around a conservative collision envelope.
	for row in 12:
		var polygon := PackedVector2Array()
		var uv := PackedVector2Array()
		for corner in [Vector2(0,row/12.0),Vector2(1,row/12.0),Vector2(1,(row+1)/12.0),Vector2(0,(row+1)/12.0)]:
			var p: Vector2 = rect.position + rect.size * corner
			p.x += sin(corner.y * 2.3) * flex * 12.0
			p.y += dangling * corner.y * corner.y * 7.0
			polygon.append(p)
			uv.append(corner)
		draw_polygon(polygon,PackedColorArray([Color.WHITE]),uv,texture)

func _ellipse(center: Vector2, radii: Vector2, color: Color, angle: float = 0.0) -> void :
	if color.a < 0.75:
		return
	var points: = PackedVector2Array()
	for index in 10:
		var phase: = float(index) * TAU / 10.0 + PI / 10.0
		points.append(center + Vector2(cos(phase) * radii.x, sin(phase) * radii.y).rotated(angle))
	draw_colored_polygon(points, _flat_color(color))

func _disc(center: Vector2, radius: float, color: Color) -> void :
	_ellipse(center, Vector2.ONE * radius, color)

func _arc(center: Vector2, radius: float, begin: float, end: float, _original_segments: int, color: Color, width: float = 1.0, _antialiased: bool = false) -> void :
	var segments: = maxi(2, ceili(absf(end - begin) / (PI / 6)))
	var points: = PackedVector2Array()
	for index in range(segments + 1):
		var phase: = lerpf(begin, end, float(index) / segments)
		points.append(center + Vector2.from_angle(phase) * radius)
	draw_polyline(points, _flat_color(color), width, false)

func _edge(from: Vector2, to: Vector2, color: Color, width: float = 1.0, _antialiased: bool = false) -> void :
	draw_line(from, to, _flat_color(color), width, false)

func _flat_color(color: Color) -> Color:

	var pigment: = Color("9f8968")
	if color.s < 0.28:
		pigment = CREAM
	elif color.h >= 0.19 and color.h < 0.44:
		pigment = GREEN
	elif color.h >= 0.44 and color.h < 0.66:
		pigment = Color("697b83")
	elif color.h >= 0.66 and color.h < 0.89:
		pigment = Color("73506b")
	elif color.h < 0.09 or color.h >= 0.89:
		pigment = Color("a44338") if _current_id in ["tomato", "ketchup", "chili", "chili_sauce"] else Color("9b5943")
	if color.v < 0.39:
		pigment = pigment.darkened(0.48)
	elif color.v < 0.67:
		pigment = pigment.darkened(0.2)
	elif color.v > 0.88:
		pigment = pigment.lightened(0.12)
	return Color(pigment.r, pigment.g, pigment.b, 1.0)

func _poly(points: Array, color: Color, edge: Color = Color.TRANSPARENT) -> void :
	var packed: = PackedVector2Array(points)
	draw_colored_polygon(packed, _flat_color(color))
	if edge.a > 0:
		packed.append(packed[0])
		draw_polyline(packed, _flat_color(edge), 1.0, false)

func _stroke(points: Array, color: Color, width: float = 1.4) -> void :
	draw_polyline(PackedVector2Array(points), _flat_color(color), width, false)

func _box(rect: Rect2, color: Color, _radius: int = 4, edge: Color = Color.TRANSPARENT) -> void :
	var style: = StyleBoxFlat.new()
	style.bg_color = _flat_color(color)
	style.set_corner_radius_all(0)
	if edge.a > 0:
		style.border_color = _flat_color(edge)
		style.set_border_width_all(1)
	draw_style_box(style, rect)

func _leaf(center: Vector2, length: float, angle: float, color: Color = GREEN) -> void :
	var forward: = Vector2(cos(angle), sin(angle))
	var across: = forward.orthogonal()
	_poly([center - forward * length * 0.5, center - across * length * 0.28, center + forward * length * 0.55, center + across * length * 0.27], color)
	_edge(center - forward * length * 0.5, center + forward * length * 0.48, color.lightened(0.28), 1.1, true)

func _flecks(center: Vector2, area: Vector2, color: Color, count: int = 20, radius: float = 1.2) -> void :
	if color.a < 0.75:
		return
	count = mini(count, 12)
	for i in count:
		var angle: = float(i) * 2.399963
		var reach: = sqrt(float(i + 1) / float(count + 1))
		var point: = center + Vector2(cos(angle) * area.x, sin(angle) * area.y) * reach
		_ellipse(point, Vector2(radius, radius * 0.6), color, float(i) * 0.51)

func _round_produce(id: String, base: Color) -> void :
	if cut:
		var flesh: = base.lightened(0.24)
		if id in ["apple", "garlic", "peach"]:
			flesh = CREAM
		_ellipse(Vector2(-9, 3), Vector2(26, 28), base.darkened(0.12), -0.2)
		_ellipse(Vector2(-11, 0), Vector2(22, 25), flesh, -0.2)
		_ellipse(Vector2(19, 13), Vector2(15, 20), base, 0.3)
		_ellipse(Vector2(18, 10), Vector2(12, 17), flesh, 0.3)
		if id == "onion":
			for r in [7, 13, 19]:
				_arc(Vector2(-11, 0), r, 0, TAU, 36, base.darkened(0.1), 1.5, true)
		elif id == "tomato":
			for i in 5:
				var pos: = Vector2(-11, 0) + Vector2.from_angle(float(i) * TAU / 5) * 12
				_ellipse(pos, Vector2(6, 8), base.darkened(0.14), i)
				_flecks(pos, Vector2(4, 5), CREAM, 4, 1.1)
		else:
			_ellipse(Vector2(-11, 0), Vector2(4, 9), Color("8b613f"))
		return
	var size_y: = 27.0 if id != "garlic" else 23.0
	_ellipse(Vector2.ZERO, Vector2(29, size_y), base.darkened(0.17))
	for i in 5:
		var offset: = float(i - 2) * 8.0
		_ellipse(Vector2(offset, -2), Vector2(13, size_y - absf(offset) * 0.15), base.lerp(base.lightened(0.18), 0.3 + float(i) * 0.12))
	if id in ["pumpkin", "onion", "garlic"]:
		for i in [-1, 0, 1]:
			_arc(Vector2(i * 4, -2), 20 + abs(i) * 3, -1.1 + i * 0.18, 1.1 + i * 0.18, 24, base.darkened(0.18), 1.1, true)
		_poly([Vector2(-5, -23), Vector2(-3, -37), Vector2(3, -35), Vector2(7, -22)], base.darkened(0.32))
	else:
		_stroke([Vector2(0, -20), Vector2(2, -30), Vector2(8, -35)], Color("675434"), 3)
		_leaf(Vector2(10, -26), 22, -0.2)
		if id == "tomato":
			for i in 5:
				_leaf(Vector2.from_angle(i * TAU / 5) * 6 + Vector2(0, -20), 18, i * TAU / 5)
	_ellipse(Vector2(-13, -13), Vector2(7, 3), Color(1, 0.95, 0.85, 0.33), -0.6)

func _egg(id: String, base: Color) -> void :
	if cut or id == "century_egg":
		var white: = Color("ebe6d6") if id == "egg" else Color("554c39")
		_ellipse(Vector2(-10, 0), Vector2(21, 29), white.darkened(0.2), -0.28)
		_ellipse(Vector2(-12, -2), Vector2(19, 27), white, -0.28)
		_ellipse(Vector2(-11, 4), Vector2(11, 13), Color("e7ad30") if id == "egg" else Color("7a8062"))
		_ellipse(Vector2(20, 13), Vector2(15, 20), white, 0.35)
		_ellipse(Vector2(20, 17), Vector2(8, 10), Color("edbc43") if id == "egg" else Color("8b9468"))
	else:
		_ellipse(Vector2(0, 2), Vector2(23, 31), Color("bd9e77"), -0.18)
		_ellipse(Vector2(-3, -1), Vector2(21, 29), Color("e9d9b7"), -0.18)
		_ellipse(Vector2(-8, -13), Vector2(7, 10), Color(1, 0.98, 0.89, 0.65), -0.3)
		_flecks(Vector2(2, 6), Vector2(15, 19), Color(0.64, 0.46, 0.29, 0.25), 18, 0.65)

func _long_produce(id: String, base: Color) -> void :
	if cut and id not in ["chili", "banana"]:
		for i in 3:
			var pos: = Vector2(-20 + i * 19, -10 + i * 13)
			_ellipse(pos + Vector2(2, 4), Vector2(18, 13), base.darkened(0.22), -0.35)
			_ellipse(pos, Vector2(18, 13), base, -0.35)
			_ellipse(pos, Vector2(14, 10), CREAM if id in ["cucumber", "eggplant", "bitter_melon"] else base.lightened(0.3), -0.35)
			_flecks(pos, Vector2(9, 6), base.darkened(0.22), 7, 1)
		return
	if id == "carrot":
		_poly([Vector2(-18, -18), Vector2(-12, -28), Vector2(4, -29), Vector2(17, -15), Vector2(2, 27), Vector2(-5, 36)], base.darkened(0.12), base.darkened(0.38))
		_poly([Vector2(-10, -24), Vector2(4, -25), Vector2(9, -14), Vector2(-5, 31)], base.lightened(0.12))
		for i in 5:
			_edge(Vector2(-12 + i, -13 + i * 8), Vector2(-3 + i, -15 + i * 8), base.darkened(0.25), 1.4)
		for i in 4:
			_leaf(Vector2(-6 + i * 4, -31), 26, -2.2 + i * 0.45)
	elif id in ["chili", "banana"]:
		var pts: Array = []
		for i in 18:
			var a: = -0.25 + i * 2.1 / 17.0
			pts.append(Vector2.from_angle(a) * 34 + Vector2(-13, -17))
		for i in range(17, -1, -1):
			var a: = -0.25 + i * 2.1 / 17.0
			pts.append(Vector2.from_angle(a) * (18 + i * 0.8) + Vector2(-13, -17))
		_poly(pts, base, base.darkened(0.4))
		_stroke([Vector2(13, -28), Vector2(17, -34), Vector2(23, -35)], GREEN if id == "chili" else Color("796041"), 4)
		_arc(Vector2(-13, -17), 29, 0.1, 1.7, 25, base.lightened(0.3), 2, true)
	else:
		_ellipse(Vector2(1, 4), Vector2(16, 35), base.darkened(0.22), 0.4)
		_ellipse(Vector2(-3, 1), Vector2(13, 32), base, 0.4)
		_ellipse(Vector2(-8, -7), Vector2(3, 18), base.lightened(0.2), 0.4)
		if id == "bitter_melon":
			_flecks(Vector2(0, 1), Vector2(12, 28), base.lightened(0.25), 35, 2.7)
		elif id == "cucumber":
			_flecks(Vector2(0, 1), Vector2(10, 25), base.lightened(0.35), 24, 1)
		for i in 4:
			_leaf(Vector2(11, -25), 16, -2.4 + i * 0.55)

func _fruit(id: String, base: Color) -> void :
	match id:
		"grapes":
			for i in 12:
				var row: = int(i / 3)
				var pos: = Vector2((i % 3 - 1) * (15 - row * 2) + (row % 2) * 4, -17 + row * 13)
				_disc(pos + Vector2(1, 2), 11, base.darkened(0.28))
				_disc(pos, 9.5, base.lightened(float(i % 3) * 0.055))
				_ellipse(pos + Vector2(-3, -4), Vector2(3, 1.8), base.lightened(0.4), -0.4)
			_stroke([Vector2(-2, -24), Vector2(0, -33), Vector2(12, -36)], GREEN, 3)
			_leaf(Vector2(13, -27), 24, -0.2)
		"strawberry":
			_poly([Vector2(-23, -14), Vector2(-13, -25), Vector2(7, -25), Vector2(24, -13), Vector2(19, 6), Vector2(2, 31), Vector2(-15, 14)], base, base.darkened(0.3))
			_flecks(Vector2(0, -1), Vector2(18, 23), Color("f1ce7b"), 24, 1.4)
			for i in 6:
				_leaf(Vector2(-2, -23), 28, i * TAU / 6)
		"watermelon":
			_poly([Vector2(-34, 17), Vector2(0, -31), Vector2(34, 17)], Color("537447"), Color("385239"))
			_poly([Vector2(-29, 14), Vector2(0, -26), Vector2(29, 14)], Color("cfd49a"))
			_poly([Vector2(-24, 11), Vector2(0, -21), Vector2(24, 11)], base)
			for i in 7:
				_ellipse(Vector2((i % 3 - 1) * 12, (i / 3) * 11 - 9), Vector2(1.7, 3), Color("684635"), -0.25)
		"durian":
			_ellipse(Vector2.ZERO, Vector2(27, 31), base.darkened(0.2))
			for i in 38:
				var a: = i * 2.39996
				var pos: = Vector2(cos(a) * 25, sin(a) * 27) * sqrt(float(i + 1) / 39)
				_poly([pos + Vector2(-5, 4), pos + Vector2(0, -7), pos + Vector2(5, 4)], base.lightened(float(i % 3) * 0.09), base.darkened(0.2))
			_stroke([Vector2(1, -24), Vector2(3, -36)], Color("77603b"), 5)
		"lemon":
			_ellipse(Vector2.ZERO, Vector2(32, 23), base.darkened(0.14), -0.28)
			_ellipse(Vector2(-2, -3), Vector2(29, 20), base, -0.28)
			_flecks(Vector2.ZERO, Vector2(24, 15), base.lightened(0.24), 40, 0.8)
			if cut:
				_ellipse(Vector2(-8, -1), Vector2(19, 21), CREAM)
				for i in 8:
					var a: = i * TAU / 8
					_poly([Vector2(-8, -1), Vector2(-8, -1) + Vector2.from_angle(a + 0.08) * 17, Vector2(-8, -1) + Vector2.from_angle(a + 0.68) * 17], base)
		"mango":
			_ellipse(Vector2(1, 1), Vector2(25, 32), base.darkened(0.16), 0.38)
			_ellipse(Vector2(-4, -3), Vector2(21, 28), base, 0.38)
			_ellipse(Vector2(-9, -13), Vector2(7, 11), base.lightened(0.25), 0.4)
			if cut:
				for i in range(-2, 3):
					_edge(Vector2(-18, i * 8), Vector2(15, i * 8), base.darkened(0.2), 1.5)
					_edge(Vector2(i * 7, -23), Vector2(i * 7, 22), base.darkened(0.2), 1.5)

func _greens(id: String, base: Color) -> void :
	if id == "seaweed":
		_poly([Vector2(-29, -28), Vector2(23, -24), Vector2(29, 25), Vector2(-24, 29)], base.darkened(0.1), base.darkened(0.4))
		for i in 13:
			_edge(Vector2(-25, -24 + i * 4), Vector2(25, -21 + i * 4), base.lightened(0.13), 1)
		_flecks(Vector2.ZERO, Vector2(23, 23), base.lightened(0.27), 45, 0.8)
		return
	if id in ["bean_sprout", "houttuynia"]:
		for i in 10:
			var x: = float(i - 5) * 5
			_stroke([Vector2(x, 27), Vector2(x - 7, 8), Vector2(x + 3, -15), Vector2(x - 3, -25)], CREAM if id == "bean_sprout" else Color("c7b59c"), 3.2)
			if id == "bean_sprout":
				_ellipse(Vector2(x - 3, -25), Vector2(4, 6), base)
			elif i % 2 == 0:
				_leaf(Vector2(x + 2, -18), 20, -0.7, base)
		return
	if id == "broccoli":
		_poly([Vector2(-8, 28), Vector2(-9, 4), Vector2(-20, -7), Vector2(-14, -13), Vector2(0, 0), Vector2(11, -17), Vector2(18, -9), Vector2(8, 10), Vector2(8, 29)], base.lightened(0.35), base.darkened(0.18))
		for i in 9:
			var pos: = Vector2((i % 3 - 1) * 17, -23 + int(i / 3) * 11)
			_disc(pos, 12, base.darkened(0.15))
			_flecks(pos - Vector2(2, 3), Vector2(9, 8), base.lightened(0.16), 17, 2.4)
		return
	for i in 11:
		var a: = i * 2.39996
		var pos: = Vector2(cos(a) * 13, sin(a) * 14)
		_ellipse(pos, Vector2(18, 22), base.darkened(0.1 + float(i % 3) * 0.035), a)
		_leaf(pos + Vector2(-2, -2), 39, a, base.lightened(float(i % 4) * 0.05))
	if id in ["lettuce", "spinach"]:
		for i in 5:
			_stroke([Vector2(i - 2, 33), Vector2((i - 2) * 6, 6), Vector2((i - 2) * 9, -16)], base.lightened(0.48), 2)

func _mushroom(base: Color) -> void :
	_poly([Vector2(-9, -2), Vector2(9, -2), Vector2(13, 29), Vector2(-11, 29)], CREAM.darkened(0.1), base.darkened(0.25))
	_poly([Vector2(-4, 0), Vector2(4, 0), Vector2(5, 26), Vector2(-4, 26)], CREAM)
	_ellipse(Vector2(0, -3), Vector2(33, 14), base.darkened(0.35))
	for i in 11:
		var x: = float(i - 5) * 5.4
		_edge(Vector2(x, -8), Vector2(x * 0.5, 7), base.lightened(0.1), 1.1)
	_ellipse(Vector2(0, -12), Vector2(32, 19), base.darkened(0.1))
	_ellipse(Vector2(-3, -16), Vector2(27, 15), base.lightened(0.1))
	_flecks(Vector2(-3, -16), Vector2(23, 11), base.lightened(0.27), 20, 2)
	if cut:
		_stroke([Vector2(0, -29), Vector2(0, 27)], CREAM.lightened(0.1), 4)

func _bowl(id: String, base: Color) -> void :
	_poly([Vector2(-33, 0), Vector2(-23, 27), Vector2(20, 27), Vector2(33, 0)], Color("a6c4bb"), Color("597f75"))
	_ellipse(Vector2(0, 0), Vector2(33, 16), Color("f1eee0"))
	_ellipse(Vector2(0, -2), Vector2(29, 13), base.darkened(0.16))
	if id == "noodles":
		for i in 13:
			_arc(Vector2((i % 3 - 1) * 10, -3 + i % 4), 8 + i % 5, -2.7, 2.7, 28, base.lightened(float(i % 3) * 0.08), 2.1, true)
	elif id in ["tapioca", "natto"]:
		for i in 27:
			var a: = i * 2.39996
			var pos: = Vector2(cos(a) * 25, sin(a) * 10) * sqrt(float(i + 1) / 28)
			_disc(pos, 4.2, base.darkened(0.2))
			_ellipse(pos - Vector2(1, 1), Vector2(3.3, 3), base)
			if i % 3 == 0:
				_ellipse(pos - Vector2(1, 2), Vector2(1.3, 0.8), base.lightened(0.45))
		if id == "natto":
			for i in 6:
				_edge(Vector2(-21 + i * 7, -8), Vector2(15 - i * 5, 8), CREAM.darkened(0.1), 0.65)
	else:
		_flecks(Vector2(0, -5), Vector2(27, 14), base.lightened(0.07), 75, 3.1)
		_flecks(Vector2(0, -7), Vector2(23, 12), Color("fff8e4"), 32, 2.5)
	_arc(Vector2(0, 0), 31, 0.1, PI - 0.1, 32, Color("f6efe0"), 2, true)

func _seafood(id: String, base: Color) -> void :
	match id:
		"shrimp":
			for i in 9:
				var a: = -2.9 + i * 0.38
				var pos: = Vector2.from_angle(a) * 23
				_ellipse(pos + Vector2(1, 2), Vector2(10.5 - i * 0.43, 8), base.darkened(0.2), a)
				_ellipse(pos, Vector2(9.6 - i * 0.43, 7), base.lightened(float(i % 3) * 0.04), a)
				_stroke([pos + Vector2(-2, -5), pos + Vector2(2, -1), pos + Vector2(3, 4)], CREAM.darkened(0.05), 1.5)
			_poly([Vector2(22, 4), Vector2(34, 9), Vector2(24, 20), Vector2(15, 12)], base.darkened(0.15))
		"fish", "salmon":
			_poly([Vector2(-34, 10), Vector2(-18, -16), Vector2(10, -25), Vector2(32, -9), Vector2(24, 21), Vector2(-9, 26)], base.darkened(0.16), base.darkened(0.42))
			_poly([Vector2(-31, 6), Vector2(-17, -17), Vector2(9, -23), Vector2(29, -10), Vector2(21, 15), Vector2(-10, 19)], base)
			for i in 7:
				var x: = -23 + i * 7
				_stroke([Vector2(x, -5 - i), Vector2(x + 7, 2), Vector2(x + 5, 16)], CREAM if id == "salmon" else base.lightened(0.35), 2)
			_stroke([Vector2(-31, 9), Vector2(-9, 23), Vector2(23, 19)], Color("889693"), 3)
		"squid":
			_poly([Vector2(0, -36), Vector2(-21, -8), Vector2(-14, 9), Vector2(13, 9), Vector2(22, -7)], base, base.darkened(0.3))
			_ellipse(Vector2(-3, -9), Vector2(10, 20), base.lightened(0.2))
			for i in 7:
				var x: = float(i - 3) * 4
				_stroke([Vector2(x, 3), Vector2(x * 1.2, 20), Vector2(x * 1.8, 28), Vector2(x * 1.7 + 5, 34)], base.lightened(0.08), 3)
		"mussel":
			_ellipse(Vector2.ZERO, Vector2(24, 34), base.darkened(0.4), 0.4)
			_ellipse(Vector2(-3, -2), Vector2(20, 29), base.darkened(0.1), 0.4)
			for i in 6:
				_arc(Vector2(-3, -10 + i * 4), 13 + i * 1.8, -0.6, 2.8, 30, base.lightened(0.12), 1, true)
			if cut:
				_ellipse(Vector2(-3, -1), Vector2(14, 24), Color("d8bc86"), 0.4)
				_ellipse(Vector2(-2, 5), Vector2(8, 14), Color("d69453"), 0.4)

func _meat(id: String, base: Color) -> void :
	if id == "sausage":
		_ellipse(Vector2(0, 1), Vector2(34, 13), base.darkened(0.2), -0.3)
		_ellipse(Vector2(-1, -2), Vector2(32, 10), base, -0.3)
		for i in 5:
			_edge(Vector2(-21 + i * 10, -4 - i * 2), Vector2(-17 + i * 10, 5 - i * 2), base.darkened(0.26), 1.7)
		if cut:
			_ellipse(Vector2(23, -7), Vector2(9, 12), base.lightened(0.3), -0.3)
			_flecks(Vector2(23, -7), Vector2(6, 8), CREAM, 9, 1)
		return
	if id == "chicken":
		_poly([Vector2(8, 8), Vector2(27, 26), Vector2(33, 23), Vector2(17, 2)], CREAM, CREAM.darkened(0.25))
		_disc(Vector2(30, 28), 6, CREAM)
		_disc(Vector2(36, 22), 6, CREAM)
		_ellipse(Vector2(-7, -6), Vector2(25, 27), base.darkened(0.17), -0.45)
		_ellipse(Vector2(-11, -10), Vector2(20, 22), base.lightened(0.12), -0.45)
		_flecks(Vector2(-10, -9), Vector2(17, 18), base.darkened(0.16), 30, 0.85)
		return
	_poly([Vector2(-31, -13), Vector2(-11, -28), Vector2(14, -25), Vector2(33, -2), Vector2(21, 24), Vector2(-17, 28), Vector2(-34, 9)], CREAM.darkened(0.07), base.darkened(0.4))
	_poly([Vector2(-28, -11), Vector2(-9, -24), Vector2(13, -20), Vector2(28, -1), Vector2(18, 20), Vector2(-16, 23), Vector2(-29, 8)], base)
	for i in 5:
		var y: = float(i - 2) * 8
		_stroke([Vector2(-24, y + 2), Vector2(-7, y - 3), Vector2(4, y + 3), Vector2(21, y)], CREAM.darkened(0.07), 3.4 if id == "pork" else 1.4)
		if id == "beef":
			_stroke([Vector2(-4, y), Vector2(-9, y + 6), Vector2(-4, y + 10)], CREAM.darkened(0.13), 1)

func _block(id: String, base: Color) -> void :
	if id == "bread":
		_box(Rect2(-27, -26, 54, 56), base.darkened(0.25), 12)
		_box(Rect2(-22, -23, 44, 48), CREAM.darkened(0.04), 10)
		_flecks(Vector2.ZERO, Vector2(18, 20), base.lightened(0.15), 37, 1.8)
		return
	var top: Array = [Vector2(-31, -16), Vector2(16, -25), Vector2(32, -11), Vector2(-16, -2)]
	if id in ["cheese", "blue_cheese"]:
		top = [Vector2(-31, -12), Vector2(18, -28), Vector2(30, -9)]
	_poly([Vector2(-31, -12), Vector2(30, -9), Vector2(29, 21), Vector2(-29, 24)], base.darkened(0.1), base.darkened(0.3))
	_poly([Vector2(30, -9), Vector2(32, -11), Vector2(31, 16), Vector2(29, 21)], base.darkened(0.26))
	_poly(top, base.lightened(0.16), base.darkened(0.2))
	if id in ["cheese", "blue_cheese"]:
		for pos in [Vector2(-16, 8), Vector2(14, 12), Vector2(-2, -4), Vector2(19, -12)]:
			_ellipse(pos, Vector2(4.5, 3.7), base.darkened(0.27))
			_ellipse(pos + Vector2(1, 1), Vector2(3, 2.4), base.darkened(0.14))
		if id == "blue_cheese":
			for i in 7:
				_stroke([Vector2(-24 + i * 7, -4), Vector2(-20 + i * 6, 5), Vector2(-22 + i * 6, 13)], Color("628c82"), 1.8)
	elif id == "chocolate":
		for x in range(-2, 3):
			for y in 2:
				_box(Rect2(x * 10 - 4, y * 12 - 5, 8, 10), base.lightened(0.08), 1, base.darkened(0.26))
	elif id in ["tofu", "stinky_tofu"]:
		_flecks(Vector2(-2, 8), Vector2(24, 10), base.darkened(0.14), 33, 0.9)
		if cut:
			_edge(Vector2(-9, -14), Vector2(-8, 22), base.darkened(0.32), 2)
			_edge(Vector2(11, -17), Vector2(11, 21), base.darkened(0.32), 2)
	elif id == "butter":
		_poly([Vector2(-31, 13), Vector2(-15, 22), Vector2(23, 18), Vector2(35, 26), Vector2(-28, 31)], Color("e5dfd2"), Color("a19a8c"))

func _root(id: String, base: Color) -> void :
	if id == "lotus_root" or cut:
		for i in 2:
			var pos: = Vector2(-13 + i * 27, -8 + i * 17)
			_ellipse(pos + Vector2(1, 3), Vector2(23, 20), base.darkened(0.22), -0.3)
			_ellipse(pos, Vector2(22, 19), base.lightened(0.12), -0.3)
			if id == "lotus_root":
				for h in 7:
					_ellipse(pos + Vector2.from_angle(h * TAU / 7) * 12, Vector2(3.5, 5), base.darkened(0.43), h)
				_ellipse(pos, Vector2(3, 4), base.darkened(0.4))
		return
	if id == "ginger":
		for i in 6:
			var pos: = Vector2((i % 3 - 1) * 18, int(i / 3) * 24 - 10)
			_ellipse(pos, Vector2(13, 19), base.darkened(0.08), float(i) * 0.6)
			_ellipse(pos + Vector2(-3, -4), Vector2(8, 12), base.lightened(0.15), float(i) * 0.6)
			_stroke([pos + Vector2(-9, 0), pos + Vector2(4, -4)], base.darkened(0.2), 1)
	else:
		_ellipse(Vector2.ZERO, Vector2(32, 24), base.darkened(0.18), -0.35)
		_ellipse(Vector2(-3, -4), Vector2(28, 21), base, -0.35)
		_flecks(Vector2.ZERO, Vector2(26, 18), base.darkened(0.24), 27, 1.2)
		for pos in [Vector2(-15, -7), Vector2(9, 12), Vector2(18, -8)]:
			_ellipse(pos, Vector2(3, 1.5), base.darkened(0.4), -0.4)

func _corn(base: Color) -> void :
	_ellipse(Vector2.ZERO, Vector2(17, 34), base.darkened(0.2), 0.15)
	for col in 4:
		for row in 9:
			var point: = Vector2(-11 + col * 7, -27 + row * 6.5)
			_box(Rect2(point, Vector2(6, 5)), base.lightened(float((col + row) % 3) * 0.08), 2)
	_leaf(Vector2(-18, 10), 51, -1.25, Color("8b9c57"))
	_leaf(Vector2(19, 12), 44, -1.9, Color("788e4d"))

func _liquid(id: String, base: Color) -> void :
	if id == "milk":
		_poly([Vector2(-22, -18), Vector2(-8, -32), Vector2(17, -32), Vector2(24, -17), Vector2(23, 31), Vector2(-23, 31)], Color("e9e5d4"), Color("8e9b96"))
		_poly([Vector2(-22, -18), Vector2(-8, -32), Vector2(-1, -18)], Color("90b5bf"))
		_poly([Vector2(-1, -18), Vector2(17, -32), Vector2(24, -17), Vector2(23, 31), Vector2(0, 31)], Color("c5dce0"))
		_box(Rect2(-23, 0, 47, 17), Color("779eab"), 0)
		_ellipse(Vector2(1, 8), Vector2(8, 5), Color("e9e8db"))
		_edge(Vector2(-7, -32), Vector2(17, -32), Color("a9bfc1"), 3)
	elif id in ["tea", "yogurt"]:
		_poly([Vector2(-24, -19), Vector2(25, -19), Vector2(19, 29), Vector2(-18, 29)], Color("e1dfd1"), Color("9d998a"))
		_poly([Vector2(-19, -15), Vector2(20, -15), Vector2(15, 22), Vector2(-13, 22)], base.lightened(0.1))
		_ellipse(Vector2(0, -17), Vector2(24, 8), Color("e9e2ce"))
		_ellipse(Vector2(0, -18), Vector2(20, 5), base.darkened(0.08))
		_ellipse(Vector2(-7, -19), Vector2(7, 1.5), base.lightened(0.35))
		if id == "tea":
			_stroke([Vector2(20, -12), Vector2(31, -4), Vector2(22, 11)], Color("c2b79e"), 3)
	else:
		_box(Rect2(-22, -10, 44, 40), Color("94a59b").darkened(0.13), 8)
		_box(Rect2(-18, -10, 36, 36), base, 6)
		_poly([Vector2(-18, -9), Vector2(-9, -20), Vector2(-9, -33), Vector2(9, -33), Vector2(9, -20), Vector2(18, -9)], base.lightened(0.17), base.darkened(0.28))
		_box(Rect2(-11, -36, 22, 9), Color("4a5d51"), 2)
		_box(Rect2(-20, 0, 40, 17), Color("e4d9b8"), 2)
		_ellipse(Vector2(0, 8), Vector2(8, 5), base.darkened(0.1))
		_box(Rect2(-14, -7, 3, 29), Color(1, 1, 0.91, 0.35), 1)

func _seasoning(id: String, base: Color) -> void :
	if id in ["mustard", "ketchup", "chili_sauce", "mayonnaise"]:
		_box(Rect2(-19, -18, 38, 50), base.darkened(0.15), 10)
		_box(Rect2(-16, -18, 30, 45), base.lightened(0.05), 8)
		_poly([Vector2(-11, -16), Vector2(-5, -36), Vector2(5, -36), Vector2(10, -16)], base.darkened(0.27), base.darkened(0.4))
		_box(Rect2(-17, 0, 34, 15), CREAM, 1)
		_ellipse(Vector2(0, 7), Vector2(8, 4), base.darkened(0.07))
		return
	_box(Rect2(-23, -21, 46, 50), Color("b7c3b9"), 6, Color("8a9386"))
	_box(Rect2(-19, -14, 38, 39), base.darkened(0.07), 4)
	_box(Rect2(-25, -28, 50, 12), Color("716655"), 3)
	for i in 9:
		_edge(Vector2(-21 + i * 5, -26), Vector2(-21 + i * 5, -18), Color("a19784"), 1)
	if id in ["salt", "sugar", "pepper", "cumin", "curry"]:
		_flecks(Vector2(0, 3), Vector2(16, 19), base.lightened(0.3), 45, 1.6 if id != "pepper" else 2.4)
	_box(Rect2(-21, 4, 42, 14), Color("e8dec3"), 1)
	_ellipse(Vector2(0, 11), Vector2(7, 4), base.darkened(0.2))
	_box(Rect2(-16, -12, 3, 35), Color(1, 0.98, 0.9, 0.25), 1)

func _ice_cream(base: Color) -> void :
	_poly([Vector2(-24, 4), Vector2(24, 4), Vector2(15, 33), Vector2(-15, 33)], Color("9fae95"), Color("6d7d65"))
	for i in 7:
		_edge(Vector2(-18 + i * 6, 6), Vector2(-11 + i * 3.7, 30), Color("c2cbb8"), 1)
	_disc(Vector2(0, -7), 26, base.darkened(0.1))
	for i in 7:
		var a: = - PI + i * PI / 6
		_disc(Vector2.from_angle(a) * 18 + Vector2(0, -5), 10, base.lightened(float(i % 3) * 0.04))
	_ellipse(Vector2(-8, -18), Vector2(11, 6), base.lightened(0.24), -0.4)
	_flecks(Vector2(0, -9), Vector2(20, 17), Color("a36761"), 17, 0.9)

func _odd(id: String, base: Color) -> void :
	match id:
		"sock":
			_poly([Vector2(-18, -32), Vector2(8, -32), Vector2(7, 4), Vector2(28, 13), Vector2(29, 24), Vector2(18, 30), Vector2(-14, 16), Vector2(-20, 4)], base.darkened(0.12), base.darkened(0.4))
			_poly([Vector2(-16, -28), Vector2(5, -28), Vector2(5, 6), Vector2(25, 15), Vector2(23, 24), Vector2(-12, 13), Vector2(-17, 2)], base)
			for i in 5:
				_edge(Vector2(-17, -24 + i * 7), Vector2(6, -24 + i * 7), Color("e1d7bc"), 2.7)
			for i in 13:
				_edge(Vector2(-13 + i % 4 * 5, -20 + int(i / 4) * 8), Vector2(-11 + i % 4 * 5, -17 + int(i / 4) * 8), base.lightened(0.35), 0.8)
		"paper":
			_poly([Vector2(-29, -30), Vector2(14, -32), Vector2(29, -16), Vector2(25, 30), Vector2(-27, 25)], base, base.darkened(0.3))
			_poly([Vector2(14, -32), Vector2(13, -15), Vector2(29, -16)], base.darkened(0.16), base.darkened(0.3))
			for i in 6:
				_edge(Vector2(-18, -11 + i * 6), Vector2(17 - i % 3 * 5, -12 + i * 6), Color("9aa29a"), 1)
		"soap":
			_box(Rect2(-31, -19, 62, 41), base.darkened(0.18), 12)
			_box(Rect2(-29, -24, 59, 39), base, 12)
			_box(Rect2(-23, -20, 46, 26), base.lightened(0.08), 9)
			for i in 9:
				var pos: = Vector2(-27 + i * 7, 15 + sin(i * 2) * 7)
				_disc(pos, 4 + i % 3 * 2, Color(0.94, 0.98, 0.95, 0.6))
				_arc(pos, 4 + i % 3 * 2, -2.9, -0.5, 14, Color("eef6ed"), 1.2, true)
		"eraser":
			_poly([Vector2(-30, -19), Vector2(24, -19), Vector2(32, -9), Vector2(29, 21), Vector2(-26, 21)], base.darkened(0.18), base.darkened(0.3))
			_box(Rect2(-30, -20, 55, 33), base, 4)
			_box(Rect2(-21, -20, 29, 34), Color("d9d9c7"), 0)
			for i in 5:
				_edge(Vector2(-16, -13 + i * 5), Vector2(3, -13 + i * 5), Color("8caaa5"), 1)
		"button":
			_disc(Vector2(1, 3), 29, base.darkened(0.3))
			_disc(Vector2.ZERO, 28, base)
			_arc(Vector2.ZERO, 22, 0, TAU, 48, base.darkened(0.19), 2.2, true)
			for x in [-1, 1]:
				for y in [-1, 1]:
					_disc(Vector2(x * 7, y * 7), 3.6, base.darkened(0.5))
			_stroke([Vector2(-7, -7), Vector2(7, 7), Vector2(7, -7), Vector2(-7, 7)], Color("cfc5b6"), 1)
		"spring":
			for i in 8:
				_ellipse(Vector2(0, -25 + i * 7), Vector2(23, 8), base.darkened(0.35))
				_ellipse(Vector2(0, -25 + i * 7), Vector2(19, 5), Color(0, 0, 0, 0))
				_arc(Vector2(0, -26 + i * 7), 21, 0, PI, 26, base.lightened(0.25), 3, true)
		"confetti":
			var colors: = [Color("c98380"), Color("7bada3"), Color("d4b353"), Color("9a89b0"), CREAM]
			for i in 29:
				var a: = i * 2.39996
				var pos: = Vector2.from_angle(a) * sqrt(float(i + 1) / 30) * 31
				_poly([pos + Vector2(-3, -3), pos + Vector2(5, -1), pos + Vector2(3, 4), pos + Vector2(-4, 2)], colors[i % 5])
		"toy_brick":
			_box(Rect2(-30, -15, 60, 43), base.darkened(0.2), 3)
			_box(Rect2(-30, -22, 60, 34), base, 3)
			for x in 3:
				for y in 2:
					var pos: = Vector2(-19 + x * 19, -15 + y * 16)
					_ellipse(pos, Vector2(7, 5), base.darkened(0.18))
					_ellipse(pos - Vector2(0, 3), Vector2(7, 4), base.lightened(0.13))
		"candle":
			_box(Rect2(-10, -21, 20, 53), base.darkened(0.1), 3)
			_box(Rect2(-7, -21, 10, 51), base.lightened(0.12), 2)
			for i in 5:
				_edge(Vector2(-10, -16 + i * 10), Vector2(10, -24 + i * 10), CREAM, 2.3)
			_stroke([Vector2(0, -22), Vector2(-1, -30)], Color("594731"), 2)
			_ellipse(Vector2(0, -35), Vector2(5, 10), Color("e3b852"))
			_ellipse(Vector2(-1, -33), Vector2(2.5, 6), Color("f9e3a0"))
		"rock":
			_poly([Vector2(-32, 5), Vector2(-23, -23), Vector2(2, -31), Vector2(29, -12), Vector2(31, 19), Vector2(-6, 28)], base.darkened(0.13), base.darkened(0.4))
			_poly([Vector2(-23, -23), Vector2(2, -31), Vector2(29, -12), Vector2(3, -4)], base.lightened(0.13))
			_stroke([Vector2(-20, -10), Vector2(-4, 2), Vector2(-10, 18)], base.darkened(0.35), 1.3)
