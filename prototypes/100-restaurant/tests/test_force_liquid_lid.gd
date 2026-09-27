extends SceneTree
var game
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	root.size=Vector2i(1600,946)
	Engine.max_fps=120
	call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func run() -> void:
	game=preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://physics_force_%s/book.json"%Crypto.new().generate_random_bytes(16).hex_encode(),"shift_seconds":600})
	root.add_child(game)
	await process_frame
	game._start_shift()
	var w=game.world
	w.audio.muted=true
	var pan=w.pan
	w.spawn_ingredient(game._definition("tomato"))
	var food: RigidBody2D=w._held
	w.drop_into_pan()
	await create_timer(0.8).timeout
	var mass:=food.mass
	var start: Vector2=food.position
	var handle: Vector2=pan.point(Vector2(1000,566))
	pan.grab(handle)
	pan.move_pointer(handle+Vector2(-1,-2))
	expect(pan.rigid.position.distance_to(pan.PIVOT+pan.HOME)<3,"target change does not teleport pan")
	for i in 90:
		pan.move_pointer(handle+Vector2(-90,-180)*(i+1)/90.0)
		await physics_frame
	await create_timer(0.6).timeout
	print("LIFT_METRICS food=",food.position," start=",start," pan=",pan.offset," angle=",pan.angle)
	expect(not food.freeze and not pan.rigid.freeze,"held pan and independent food stay dynamic")
	expect(food.position.y<start.y-140 and pan.contains(food.position),"colliders support food during a gentle lift")
	expect(pan.grip.last_force.length()<=pan.grip.max_force+0.01,"grip force remains bounded")
	expect(absf(food.mass-mass)<0.000001,"transport conserves solid mass")
	pan.release_pan()
	expect(not pan.rigid.freeze,"release leaves a freely falling native body")
	await create_timer(1.5).timeout
	expect(absf(pan.offset.y-pan.HOME.y)<2 and pan.rigid.linear_velocity.length()<10,"released pan settles on physical counter")
	w.clear_workspace()
	game.session.clear_dish()
	await process_frame
	pan.angle=0
	pan.move_to(pan.HOME)
	pan.rigid.linear_velocity=Vector2.ZERO
	pan.rigid.angular_velocity=0
	pan.rigid.freeze=true
	pan.set_physics_process(false)
	pan.runoff.set_physics_process(false)
	# Every unit crosses the rim, flies, spreads, and can be drained/wiped.
	pan.water_ml=1700
	pan.advance_water(1.0/120)
	var inv: Dictionary=pan.runoff.inventory()
	expect(pan.water_ml<=1500 and pan.rim_water_ml>150,"full pot retains a finite rim reservoir while overflow starts")
	expect(inv.flight_ml>0 and inv.surface_ml==0,"new overflow begins at the rim, not on the table")
	for i in 360:
		pan.advance_water(1.0/120)
		pan.runoff.advance(1.0/120)
	inv=pan.runoff.inventory()
	expect(inv.surface_ml>100,"water reaches the counter and spreads from the impact")
	expect(absf(pan.water_ml+pan.rim_water_ml+inv.flight_ml+inv.surface_ml+inv.floor_ml+inv.sink_ml+inv.sink_overflow_ml+inv.drained_ml+inv.wiped_ml-1700)<0.00001,"vessel, flights, surface, floor and drain conserve 1700 ml")
	var removed: float=pan.runoff.wipe(pan.point(Vector2(930,582))+Vector2(8,90),30)
	expect(removed>=0 and removed<=30.000001,"local wipe never exceeds sponge capacity")
	pan.angle=deg_to_rad(110)
	pan.advance_water(0.1)
	expect(pan.water_ml>0 and pan.water_ml<1499,"tilting begins continuous outflow instead of deleting full volume")
	for i in 90:
		pan.advance_water(1.0/60)
		pan.runoff.advance(1.0/60)
	inv=pan.runoff.inventory()
	expect(absf(pan.water_ml+pan.rim_water_ml+inv.flight_ml+inv.surface_ml+inv.floor_ml+inv.sink_ml+inv.sink_overflow_ml+inv.drained_ml+inv.wiped_ml-1700)<0.00001,"60 Hz fallback also conserves liquid")
	expect(pan.water_ml<0.01,"inverted pan eventually empties below the lower rim")
	pan.angle=0
	pan.move_to(pan.HOME)
	pan.rigid.freeze=false
	pan.set_physics_process(true)
	pan.runoff.set_physics_process(true)
	pan.water_ml=600
	pan.water_heat=22
	var lid=pan.lid
	lid.parked=false
	lid.rigid.freeze=false
	lid.rigid.rotation=0
	lid.rigid.position=pan.point(Vector2(810,580))
	await create_timer(0.8).timeout
	print("COLD lid=",lid.rigid.position," angle=",lid.rigid.rotation," pan=",pan.rigid.position," seat=",pan.point(Vector2(810,582))," contact=",lid.rigid.get_contact_count())
	expect(lid.covered and lid.pressure_pa<1,"cold loose lid rests on actual rim with no invented pressure")
	var cold_y: float=lid.rigid.position.y
	game.session.set_heating(true)
	w.reactions.pan_c=140
	pan.water_heat=100
	var max_lift:=0.0
	var peak_pressure:=0.0
	for i in 360:
		await physics_frame
		max_lift=maxf(max_lift,cold_y-lid.rigid.position.y)
		peak_pressure=maxf(peak_pressure,lid.pressure_pa)
	expect(peak_pressure>100 and max_lift>1,"sustained boiling raises pressure and physically lifts lid")
	print("LID_METRICS pressure=",peak_pressure," lift=",max_lift," covered=",lid.covered)
	game.session.set_heating(false)
	pan.water_heat=40
	w.reactions.pan_c=40
	await create_timer(2).timeout
	expect(lid.pressure_pa<5,"cooling and open gap vent pressure continuously")
	game.queue_free()
	await process_frame
	for f in failures: push_error(f)
	print("%s: force liquid lid, %d checks"%["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
