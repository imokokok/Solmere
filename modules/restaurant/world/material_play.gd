extends Node2D
## Bounded game material effects. Bodies retain native contact and finite mass;
## foam is an optical effect, never counted as extra food or water.
var world: Node2D
var foam := 0.0
var foam_linger := 0.0
var power_out := false
var sparks := 0.0
var clock := 0.0
var fire := 0.0
var smoke := 0.0
var hot_oil := 0.0
var splatter := 0.0
var _last_water := 0.0
var _foam_sound := 0.0
var _previous: Dictionary = {}
var _overlay: Node2D
var _fire_root: Node2D
var _fire_sheet: ColorRect

func reset_effects() -> void:
	foam = 0.0
	foam_linger = 0.0
	power_out = false
	sparks = 0.0
	fire = 0.0
	smoke = 0.0
	splatter = 0.0
	_last_water = 0.0
	_previous.clear()
	if has_meta("fire_warned"): remove_meta("fire_warned")

func _ready() -> void:
	_fire_root = Node2D.new()
	_fire_root.z_index = 8
	world.add_child.call_deferred(_fire_root)
	_fire_sheet = ColorRect.new()
	_fire_sheet.position = Vector2(682, 389)
	_fire_sheet.size = Vector2(256, 208)
	_fire_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var flame := ShaderMaterial.new()
	flame.shader = preload("res://modules/restaurant/assets/oil_fire.gdshader")
	_fire_sheet.material = flame
	_fire_root.add_child(_fire_sheet)
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	_overlay = Node2D.new()
	layer.add_child(_overlay)
	_overlay.draw.connect(_paint)

func _process(_dt: float) -> void:
	if not is_instance_valid(_fire_root) or not is_instance_valid(world.pan): return
	_fire_root.transform = world.pan.transform_pan()
	_fire_sheet.visible = fire > 0.005
	_fire_sheet.material.set_shader_parameter("intensity", fire)
	_fire_sheet.material.set_shader_parameter("clock", clock)

func _physics_process(dt: float) -> void:
	if not world.controls_enabled: return
	clock += dt
	sparks = maxf(0.0, sparks - dt)
	_foam_sound = maxf(0.0, _foam_sound - dt)
	var rubbing := false
	var fuel := 0.0
	var oil := 0.0
	for body in world._foods.get_children():
		if not body is RigidBody2D or body.is_queued_for_deletion(): continue
		var id := str(body.get_meta("id", ""))
		var key: int = body.get_instance_id()
		var previous: Vector2 = _previous.get(key, body.position)
		var distance: float = body.position.distance_to(previous)
		_previous[key] = body.position
		if world.pan.contains(body.position) and body != world._held and not body.get_meta("is_container", false):
			for state in [body.get_meta("liquid_state", {}), body.get_meta("surface_sauce", {})]:
				for fat in ["oil", "sesame_oil", "butter"]: oil += float(state.get("composition_ml", {}).get(fat, 0.0))
			if id in ["paper", "confetti", "toilet_paper", "resignation_letter", "bread"]: fuel += body.mass
		if id in ["soap", "soap_smooth"] and world.pan.contains(body.position) and (body == world._held or world.utensils.any(func(t): return t.active and t.rigid.position.distance_to(body.position) < 70)) and distance > 0.08:
			rubbing = true
			foam = minf(1.0, foam + minf(distance, 18.0) * dt * 0.65)
			foam_linger = 2.5
			if _foam_sound <= 0:
				world.audio.play_effect("stir_water", 0.3)
				_foam_sound = 0.5
		if id == "confetti" and body != world._held and not body.has_meta("confetti_piece") and not body.freeze:
			_scatter(body)
		if body != world._held and not body.get_meta("plated", false): _buoyancy(body)
	var covered: bool = world.lid.covered
	var dangerous: bool = world.reactions.pan_c > 245.0 and (oil > 8.0 or fuel > 0.005) and not covered and world.pan.water_ml < 30.0
	fire = clampf(fire + dt * (0.12 if dangerous else (-0.9 if covered else -0.22)), 0.0, 1.0)
	smoke = move_toward(smoke, fire * 0.85, dt * 0.22)
	if fire > 0.15 and not has_meta("fire_warned"):
		set_meta("fire_warned", true)
		world.interaction.emit("notice", "锅里着火了！关火，盖上锅盖。")
	if fire < 0.02 and has_meta("fire_warned"): remove_meta("fire_warned")
	hot_oil = oil if world.reactions.pan_c > 145 else 0.0
	var water_added: float = maxf(0.0, world.pan.water_ml - _last_water)
	if water_added > 0.3 and hot_oil > 5.0:
		splatter = minf(1.0, splatter + water_added * 0.04)
		world.audio.play_effect("hot_drop", 0.65)
		for body in world._foods.get_children():
			if body != world._held and world.pan.contains(body.position) and not body.freeze:
				body.apply_central_impulse(Vector2(sin(body.get_instance_id()) * 12, -25) * body.mass)
	_last_water = world.pan.water_ml
	splatter = maxf(0.0, splatter - dt * 1.3)
	# Clear stale identities rather than accumulating a history of deleted cuts.
	for key in _previous.keys():
		if not is_instance_id_valid(key): _previous.erase(key)
	if not rubbing:
		foam_linger = maxf(0.0, foam_linger - dt)
		foam = move_toward(foam, 0.0, dt * (0.15 if foam_linger > 0.0 else 1.3))
	var surface: float = world.flood_art.surface_y(1030.0)
	if not power_out and surface < 220.0:
		power_out = true
		sparks = 0.65
		world.set_cooking(false)
		world.interaction.emit("notice", "水碰到灯了，跳闸了。先关水，等水退下去。")
	if power_out:
		world.set_cooking(false)
		if world.flood_ratio() < 0.06 and not world.pan.faucet_on:
			power_out = false
			world.interaction.emit("notice", "水退下去了，来电了。炉火已经关好。")
	# A hollow upright pan traps air; the same pan inverted loses that buoyancy.
	var pan_depth := clampf((world.pan.rigid.position.y+25.0-world.flood_art.surface_y(world.pan.rigid.position.x))/55.0,0.0,1.0)
	if pan_depth > 0.0 and not world.pan.active and not world.pan.recovering:
		var support := 1.6 if absf(world.pan.angle) < 0.6 else 0.3
		world.pan.rigid.apply_central_force(Vector2(0,-world.pan.rigid.mass*980*pan_depth*support)-world.pan.rigid.linear_velocity*world.pan.rigid.mass*pan_depth*3.0)
	for tool in world.utensils:
		if tool.docked or tool.active or tool.storing: continue
		var depth := clampf((tool.position.y+10-world.flood_art.surface_y(tool.position.x))/25.0,0.0,1.0)
		if depth > 0:
			tool.rigid.apply_central_force(Vector2(0,-tool.rigid.mass*980*depth*(1.7 if tool.kind != "black" else 0.8))-tool.rigid.linear_velocity*tool.rigid.mass*depth*3)
	_overlay.transform = world.get_global_transform_with_canvas()
	_overlay.queue_redraw()

func _buoyancy(body: RigidBody2D) -> void:
	var surface: float = world.flood_art.surface_y(body.position.x)
	var depth := clampf((body.position.y + 22.0 - surface) / 44.0, 0.0, 1.0)
	body.set_meta("submerged", depth)
	var art := body.get_node_or_null("FoodArt") as Node2D
	if art: art.modulate = Color.WHITE.lerp(Color(0.68,0.82,0.79,1),depth * 0.65)
	if depth <= 0.0: return
	if body.get_meta("on_board", false):
		body.stop_board_settle()
		body.set_meta("on_board", false)
		body.freeze = false
	if body.freeze: return
	var id := str(body.get_meta("id", ""))
	var density := float(body.get_meta("definition", {}).get("density_g_ml", 1.08))
	if id in ["bread", "sock", "confetti", "paper", "toilet_paper", "rubber_duck", "sponge"]: density = 0.45
	elif id in ["rock", "soap", "soap_smooth", "eraser"]: density = 1.3
	elif body.get_meta("is_container", false): density = 0.72 if float(body.get_meta("remaining_ml", 0)) < 50 else 1.04
	body.apply_central_force(Vector2(0, -body.mass * 980.0 * depth / maxf(0.2, density)) - body.linear_velocity * body.mass * depth * 4.0)
	body.apply_torque(-body.angular_velocity * body.inertia * depth * 2.0)

func _scatter(source: RigidBody2D) -> void:
	var count := mini(12, 65 - world._foods.get_child_count())
	if count < 2: return # Wait until budget permits; do not lose the source.
	for i in count:
		var piece := preload("res://modules/restaurant/world/food_body.gd").new()
		for key in source.get_meta_list():
			var value = source.get_meta(key)
			piece.set_meta(key, value.duplicate(true) if value is Dictionary or value is Array else value)
		if source.has_meta("thermal"):
			piece.set_meta("thermal", preload("res://modules/restaurant/domain/food_thermal.gd").split_state(source.get_meta("thermal"), 1.0 / count))
		if source.has_meta("surface_sauce"):
			var coating: Dictionary = piece.get_meta("surface_sauce")
			coating.volume_ml = float(coating.get("volume_ml",0)) / count
			coating.mass_kg = float(coating.get("mass_kg",0)) / count
			for component in coating.get("composition_ml",{}): coating.composition_ml[component] /= count
		piece.set_meta("confetti_piece", i)
		piece.set_meta("instance_uid", str(source.get_meta("instance_uid", "paper")) + "_" + str(i))
		piece.mass = source.mass / count
		piece.collision_layer = 16
		piece.collision_mask = 17
		piece.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		var collider := CollisionShape2D.new()
		collider.shape = CircleShape2D.new()
		collider.shape.radius = 3.5
		piece.add_child(collider)
		var art := preload("res://modules/restaurant/world/paper_flake.gd").new()
		art.name = "FoodArt"
		art.index = i
		piece.add_child(art)
		world._foods.add_child(piece)
		piece.position = source.position + Vector2((i % 4 - 1.5) * 7, (i / 4 - 1) * 6)
		piece.linear_velocity = source.linear_velocity * 0.6 + Vector2(sin(i * 4.3) * 55, -20 - i * 2)
		piece.angular_velocity = sin(i * 7.0) * 3.0
		piece.gravity_scale = 0.22
		piece.linear_damp = 2.0
	source.queue_free()

func _paint() -> void:
	if power_out: _overlay.draw_rect(Rect2(0,0,1600,790), Color(0.12,0.17,0.24,0.4))
	if sparks > 0:
		for i in 9:
			var start := Vector2(1030, 180) + Vector2.from_angle(i * 2.4) * (1.0 - sparks) * 40
			_overlay.draw_line(start, start + Vector2.from_angle(i * 2.4) * 12, Color(1.0,0.85,0.4,sparks),2,true)
	var pan_center: Vector2 = world.pan.point(Vector2(810, 580))
	if smoke > 0.01:
		for i in 12:
			var rise := fmod(clock*0.23+i/12.0,1.0)
			_overlay.draw_circle(pan_center+Vector2(sin(i*3.7+rise*4)*rise*180,-rise*500),18+rise*70,Color(0.24,0.23,0.21,smoke*(1-rise)*0.13))
	if splatter > 0.01:
		for i in 13:
			var age := 1.0-splatter
			_overlay.draw_circle(pan_center+Vector2(sin(i*3.9)*age*170,-age*(1-age)*210+i%3*3),1.8,Color(0.89,0.73,0.3,splatter*0.8))
	if foam <= 0.005: return
	for i in int(20 + foam * 160):
		var p: Vector2 = world.pan.point(Vector2(810, 575))
		var spread := smoothstep(0.18, 0.95, foam)
		p += Vector2(sin(i*8.37)*lerpf(90,780,spread), cos(i*3.13)*lerpf(20,420,spread))
		p.y -= fmod(clock * (12+i%7)+i*17, 55.0)
		var radius := (10.0 + i % 13 * 1.4) * minf(1.0, foam * 5.0)
		_overlay.draw_circle(p, radius, Color(0.91,0.95,0.87,0.62))
		_overlay.draw_arc(p,radius,0,TAU,20,Color(0.75,0.88,0.85,0.8),1.4,true)
		_overlay.draw_arc(p-Vector2(2,2),radius*0.65,3.5,4.8,8,Color(1,1,0.95,0.8),1.6,true)
