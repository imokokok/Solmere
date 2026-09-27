extends SceneTree
var game
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:
	Engine.max_fps=120
	root.size=Vector2i(1600,946)
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func run() -> void:
	game=preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://lid_native_%s/book.json"%Crypto.new().generate_random_bytes(16).hex_encode(),"shift_seconds":900})
	root.add_child(game)
	await process_frame
	game._start_shift()
	var w=game.world
	w.audio.muted=true
	var lid=w.lid
	var pan=w.pan
	check(lid.hit(lid.HOME),"parked hand-painted lid can be selected")
	check(lid.rigid.collision_layer==0,"parked lid has no invisible full-size collider")
	w.spawn_ingredient(game._definition("chicken"))
	var food: RigidBody2D=w._held
	w.drop_into_pan()
	await create_timer(0.7).timeout
	check(lid.close_lid(),"placing lid is allowed with empty hands")
	await create_timer(0.8).timeout
	print("SEATED ",lid.rigid.position," seat=",pan.point(Vector2(810,582))," angle=",lid.rotation," covered=",lid.covered)
	check(lid.covered and not lid.rigid.freeze,"cold lid rests dynamically on the pan rim")
	check(lid.rigid.get_contact_count()>0,"closed lid has real contact support")
	check(w._food_at(food.position)==null,"closed lid occludes underlying food selection")
	check(lid.pressure_pa<1,"cold contents cannot produce pressure")
	var utensil=w.utensils[0]
	utensil.active=true
	check(utensil.stir_sweep(food.position-Vector2(30,0),food.position+Vector2(30,0))==0,"lid blocks stir interaction")
	utensil.active=false
	w.spawn_ingredient(game._definition("carrot"))
	var held=w._held
	w.drop_into_pan()
	check(w._held==held,"closed lid blocks shortcut ingredient insertion")
	held.position=Vector2(1230,700)
	w.drop_held()
	# Water ledger is driven only by vapor actually produced by thermal exchange.
	w.reactions.set_physics_process(false)
	lid.advance(0.1,2.0,180,true)
	check(lid.received_steam_ml==2.0 and lid.condensed_ml>0,"actual captured vapor can condense into finite water")
	check(absf(lid.received_steam_ml-lid.steam_ml-lid.condensed_ml-lid.escaped_steam_ml)<0.000001,"steam ledger conserves captured mass")
	var water_before: float=pan.water_ml
	lid.open_lid()
	check(not lid.covered and lid.pressure_pa==0,"lifting cover releases pressure")
	check(absf(lid.received_steam_ml-lid.steam_ml-lid.condensed_ml-lid.escaped_steam_ml)<0.000001,"venting conserves captured mass")
	check(pan.water_ml==water_before,"venting does not invent pan water")
	lid.rest_lid()
	w.clear_workspace()
	await process_frame
	pan.move_to(pan.HOME)
	pan.rigid.linear_velocity=Vector2.ZERO
	pan.rigid.angular_velocity=0
	pan.water_ml=600
	pan.water_heat=100
	w.reactions.pan_c=180
	lid.close_lid()
	await create_timer(0.8).timeout
	var base: Vector2=lid.position
	var peak:=0.0
	var peak_pressure:=0.0
	game.session.water_ml=pan.water_ml
	game.session.set_heating(true)
	w.set_cooking(true)
	for i in 1800:
		await physics_frame
		peak=maxf(peak,base.y-lid.position.y)
		peak_pressure=maxf(peak_pressure,lid.pressure_pa)
		if lid.burst_count>0: break
	print("PRESSURE peak=",peak_pressure," lift=",peak," pops=",lid.burst_count," hot_s=",lid._hot_seconds," water=",pan.water_ml," heat=",pan.water_heat," cooking=",w.cooking)
	check(peak_pressure>100 and peak>1,"boiling steam lifts actual lid mass")
	check(lid.burst_count==1,"sustained boiling can produce a finite steam pop")
	var count: int=lid.burst_count
	var previous: Vector2=lid.position
	var max_step:=0.0
	for i in 240:
		await physics_frame
		max_step=maxf(max_step,previous.distance_to(lid.position))
		previous=lid.position
	check(max_step<12,"flight and collisions are continuous without a return-to-rack teleport")
	check(lid.position.distance_to(lid.HOME)>80,"steam pop does not home to the rack")
	check(not lid.rigid.freeze,"airborne and landed lid remains a physical body")
	w.set_controls_enabled(false)
	await physics_frame
	var pause: Vector2=lid.rigid.position
	await create_timer(0.2).timeout
	check(lid.rigid.position.distance_to(pause)<0.01,"modal freezes lid simulation")
	w.set_controls_enabled(true)
	game.session.set_heating(false)
	w.set_cooking(false)
	pan.water_heat=30
	w.reactions.pan_c=30
	await create_timer(2).timeout
	check(lid.pressure_pa<5,"cooling dissipates low-pressure steam")
	lid.rest_lid()
	pan.water_ml=0
	lid.close_lid()
	w.reactions.pan_c=240
	game.session.water_ml=pan.water_ml
	game.session.set_heating(true)
	w.set_cooking(true)
	await create_timer(2).timeout
	check(lid.burst_count==count and lid.pressure_pa<5,"hot dry pan has no invented steam explosion")
	game.queue_free()
	await process_frame
	for f in failures: push_error(f)
	print("%s: pan lid and burning, %d checks"%["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
