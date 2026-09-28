extends SceneTree
var game
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	root.size = Vector2i(1280, 756)
	Engine.max_fps = 120
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://material_play_%s/book.json" % Crypto.new().generate_random_bytes(8).hex_encode()})
	root.add_child(game)
	await process_frame
	game._start_shift()
	var w = game.world
	w.audio.muted = true
	w.set_process(false) # fixture hand positions, not the unrelated desktop cursor
	# Input coordinates come from the event, including a smaller host viewport.
	for id in ["salt", "pepper", "soy_sauce", "oil", "ketchup"]:
		w.spawn_ingredient(game._definition(id))
		var bottle: RigidBody2D = w._held
		var point: Vector2 = w.pan.point(Vector2(810,550))
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = w.get_global_transform_with_canvas() * point
		w._unhandled_input(press)
		check(w._squeezing,"scaled viewport starts " + id + " from its event position")
		var remaining: float = bottle.get_meta("remaining_ml")
		for tick in 48:
			w.squeeze_pressure = move_toward(w.squeeze_pressure,1.0,3.2/120.0)
			w._update_held_motion(1.0/120.0,point)
		check(float(bottle.get_meta("remaining_ml"))<remaining,"scaled dispensing reduces finite " + id + " contents")
		press.pressed = false
		w._input(press)
		check(not w._squeezing,"release stops " + id)
		w.discard_held()
		w.clear_workspace()
		await process_frame
	var lid = w.lid
	var seat: Vector2 = w.pan.point(preload("res://modules/restaurant/world/pan_geometry.gd").CENTER)-Vector2(0,8)
	lid.parked = false
	lid.rigid.freeze = false
	lid.rigid.position = seat+Vector2(65,-45)
	lid.rigid.rotation = -0.25
	var start: Vector2 = lid.rigid.position
	lid.release_near_pan(seat+Vector2(60,-25))
	check(lid.seating and lid.rigid.position == start,"nearby lid starts a continuous force-guided seating, no teleport")
	await create_timer(2.0).timeout
	check(lid.covered and not lid.seating,"lid seats from a generous nearby release")
	lid.rest_lid()
	w.pan.rigid.rotation = 2.7
	w.pan.rigid.position = Vector2(1450,500)
	w.pan.recover_to_stove()
	await create_timer(4.0).timeout
	print("RECOVERY ",w.pan.rigid.position," angle=",w.pan.angle," recovering=",w.pan.recovering)
	check(absf(w.pan.angle)<0.15 and w.pan.rigid.position.distance_to(w.pan.PIVOT+w.pan.HOME)<12,"upside-down pan can return upright to stove")
	w.spawn_ingredient(game._definition("mushroom"))
	var mushroom: RigidBody2D = w._held
	w.drop_held(false,false)
	mushroom.freeze = true
	mushroom.position = Vector2(180,270)
	await process_frame
	await process_frame
	check(w.get_node("FloatingTools").copies.has(mushroom.get_node("FoodArt").get_instance_id()),"released mushroom remains in front of fridge")
	mushroom.queue_free()
	await process_frame
	w.spawn_ingredient(game._definition("confetti"))
	var original_mass: float = w._held.mass
	w._held.position = Vector2(820,320)
	w.drop_held(false,false)
	await physics_frame
	await physics_frame
	var pieces := 0
	var mass := 0.0
	for body in w._foods.get_children():
		if body.is_queued_for_deletion(): continue
		if body.has_meta("confetti_piece"): pieces+=1; mass+=body.mass
	check(pieces==12 and absf(mass-original_mass)<0.000001,"paper scatters into twelve independently moving pieces without mass duplication")
	check(w._foods.get_children().filter(func(b): return b.has_meta("confetti_piece")).all(func(b): return b.get_meta("instance_uid") != ""),"scattered pieces retain independent identities")
	w.clear_workspace()
	await process_frame
	w.set_physics_process(false)
	w.material_play.set_physics_process(false)
	w.spawn_ingredient(game._definition("soap"))
	var soap: RigidBody2D = w._held
	soap.freeze = true
	for i in 250:
		soap.position = w.pan.point(Vector2(810+sin(i*0.8)*28,580))
		w.material_play._physics_process(1.0/120)
	check(w.material_play.foam > 0.6,"repeated soap rubbing builds a large visible foam response")
	soap.position = Vector2(1200,400)
	for i in 420: w.material_play._physics_process(1.0/120)
	check(w.material_play.foam < 0.01,"foam clears shortly after the player stops rubbing")
	w.discard_held()
	await process_frame
	w.spawn_ingredient(game._definition("bread"))
	var bread: RigidBody2D = w._held
	w.drop_held(false,false)
	bread.position = w.pan.point(Vector2(810,580))
	bread.freeze = true
	w.reactions.pan_c = 280
	for i in 250: w.material_play._physics_process(1.0/120)
	check(w.material_play.fire > 0.15,"dry flammable food in a very hot uncovered pan can catch fire")
	lid.covered = true
	for i in 200: w.material_play._physics_process(1.0/120)
	check(w.material_play.fire < 0.01,"covering the pan smothers the game fire")
	lid.covered = false
	w.reactions.pan_c = 22
	bread.freeze = false
	bread.position = Vector2(900,650)
	w.pan.faucet_on = true
	w.pan.runoff.floor_ml = 7800
	w.pan.runoff.floor_cells.fill(7800.0/64)
	w.flood_water_ml = 7800
	w.material_play._physics_process(1.0/120)
	check(w.material_play.power_out and not w.cooking,"water reaching the lamp trips power while leaving cleanup controls usable")
	check(float(bread.get_meta("submerged",0))>0.9,"buoyancy is driven by the same visible water surface")
	var y: float = bread.position.y
	for i in 30:
		w.material_play._buoyancy(bread)
		await physics_frame
	check(bread.position.y < y-15,"low-density bread visibly rises through floodwater")
	w.pan.runoff.clear()
	w.pan.faucet_on = false
	w.material_play._physics_process(1.0/120)
	check(not w.material_play.power_out,"power recovers after water drains and tap is closed")
	var cut = preload("res://modules/restaurant/assets/cut_state_library.gd")
	for id in ["cheese","bread","tofu","sausage","cabbage","corn"]:
		check(cut.interior_texture(id)!=null,"cut interior exists for "+id)
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: playability and material response, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
