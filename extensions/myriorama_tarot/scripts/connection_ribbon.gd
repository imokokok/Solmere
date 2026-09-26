extends Node2D

var cards: Array = []
var links: Array = []
var lamps: Array[PointLight2D] = []
var active := false
var bright := false
var time := 0.0

static func light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0,Color(1,1,1,0.85))
	gradient.set_color(1,Color(1,1,1,0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1,0.5)
	texture.width = 256
	texture.height = 256
	return texture

func _ready() -> void:
	for i in range(7):
		var light := PointLight2D.new()
		light.name = "ConnectionLight%d" % i
		light.texture = light_texture()
		light.texture_scale = 2.3
		light.color = Color("ffe0a3")
		light.energy = 0
		add_child(light)
		lamps.append(light)

func _process(delta: float) -> void:
	time += delta
	links.clear()
	var ordered := cards.filter(func(c): return is_instance_valid(c))
	ordered.sort_custom(func(a,b): return a.position.x < b.position.x)
	for i in range(7):
		var energy := 0.0
		if active and i+1 < ordered.size():
			var a: Vector2 = to_local(ordered[i].RightConnection.global_position)
			var b: Vector2 = to_local(ordered[i+1].LeftConnection.global_position)
			var gap := a.distance_to(b)
			# No line through crossed/overlapped cards. Pulling away stretches then
			# dissolves the relation; reordered neighbors are recomputed every frame.
			if b.x >= a.x-3 and gap < 150 and absf(a.y-b.y)<80:
				var strength := clampf(1.0-gap/150.0,0,1)
				links.append({"a":a,"b":b,"strength":strength,"pair":[ordered[i].card_id,ordered[i+1].card_id]})
				lamps[i].position = (a+b)*0.5
				energy = strength*(0.55 if bright else 0.22)
		lamps[i].energy = lerpf(lamps[i].energy,energy,1.0-exp(-delta*8.0))
	queue_redraw()

func _draw() -> void:
	for link in links:
		var a: Vector2 = link.a
		var b: Vector2 = link.b
		var strength: float = link.strength
		# Actual world-space edge anchors, not an image sitting above the screen.
		var path := PackedVector2Array([a-Vector2(14,0),a,(a+b)*0.5+Vector2(0,-4*sin(time)),b,b+Vector2(14,0)])
		draw_polyline(path,Color(0.95,0.81,0.48,strength*0.10),12,true)
		draw_polyline(path,Color(1,0.9,0.66,strength*(0.78 if bright else 0.42)),2,true)
		var moving := a.lerp(b,fmod(time*0.3,1.0))
		draw_circle(moving,2.2,Color(1,0.93,0.76,strength*0.7))
		for at in [a,b]: draw_line(at+Vector2(0,-12),at+Vector2(0,12),Color(1,0.91,0.71,strength*0.45),1.2,true)
