extends SceneTree
var game
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:
	root.size=Vector2i(1600,946)
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func total(w) -> float:
	var v: Dictionary=w.pan.runoff.inventory()
	return w.pan.water_ml+w.pan.rim_water_ml+v.sink_ml+v.sink_overflow_ml+v.surface_ml+v.flight_ml+v.floor_ml+v.drained_ml+v.wiped_ml
func step(w,seconds: float,rate:=120) -> void:
	for i in int(seconds*rate):
		w.pan.advance_water(1.0/rate)
		w.pan.runoff.advance(1.0/rate)
func run() -> void:
	game=preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://flood_%s/book.json"%Crypto.new().generate_random_bytes(16).hex_encode()})
	root.add_child(game)
	await process_frame
	game._close_modal()
	var w=game.world
	w.audio.muted=true
	w.pan.set_physics_process(false)
	w.pan.runoff.set_physics_process(false)
	w.reactions.set_physics_process(false)
	w.pan.rigid.freeze=true
	check(w.flood_art.get_parent()==game.hud,"water foreground retains HUD/world alignment")
	check(game.session.duration==720,"full shift retains twelve real minutes")
	game.session.phase="service"
	game.session.elapsed=360
	game._update_hud()
	check("12:00" in game.clock_label.text,"visible clock retains gradual shift time")
	w.pan.faucet_on=true
	step(w,0.01)
	check(w.pan.runoff.inventory().flight_ml>0 and w.sink_water_ml==0,"tap enters as falling water, not a sink teleport")
	step(w,6.0)
	check(w.sink_water_ml>900 and w.sink_water_ml<1200 and w.flood_water_ml==0,"sink fills before any floor flooding")
	step(w,1.0)
	check(w.sink_water_ml<=1200 and w.pan.runoff.sink_overflow_ml>0,"full sink develops a finite brim reservoir")
	step(w,4.0)
	check(w.flood_water_ml>300 and w.flood_water_ml<800,"sink water travels from its brim before reaching floor")
	check(absf(total(w)-w.pan.water_input_ml)<0.00001,"inlet, sink, brim, flights and floor conserve tap volume")
	var local_count:=0
	for ml in w.pan.runoff.floor_cells:
		if ml>1: local_count+=1
	check(local_count>1 and local_count<64,"floor pool spreads locally instead of appearing across the whole screen")
	step(w,55.0,60)
	check(w.flood_water_ml>7000,"continued overflow can gradually flood room")
	check(absf(total(w)-w.pan.water_input_ml)<0.00001,"60 Hz subdivided flow preserves mass even at room capacity")
	var before: float=w.flood_water_ml
	w.pan.faucet_on=false
	step(w,10.0)
	check(w.flood_water_ml<before and w.flood_water_ml>before-1100,"closing tap drains gradually")
	check(absf(total(w)-w.pan.water_input_ml)<0.00001,"drain and standing water remain conserved")
	w.pan.runoff.clear()
	w.pan.water_input_ml=0
	w.pan.angle=0
	w.pan.move_to(Vector2(w.pan.SINK_X-809,w.pan.HOME.y))
	w.pan.water_ml=1499
	w.pan.faucet_on=true
	step(w,1.0)
	check(w.pan.water_ml<=1500 and w.pan.outflow_ml_s>0,"filled pot produces actual rim overflow")
	check(absf(total(w)-1499-w.pan.water_input_ml)<0.00001,"filled pot conserves inlet and spill")
	w.pan.faucet_on=false
	w.pan.angle=PI/2
	var before_pour: float=w.pan.water_ml
	w.pan.advance_water(1.0/120)
	check(w.pan.water_ml>0 and w.pan.water_ml<before_pour,"tilting starts progressive flow without deleting water")
	step(w,2.0)
	check(w.pan.water_ml<0.01,"near-inverted pot eventually empties")
	check(absf(total(w)-1499-w.pan.water_input_ml)<0.00001,"tilted flow preserves vessel, flight, sink and drain volume")
	game.queue_free()
	await process_frame
	for f in failures: push_error(f)
	print("%s: kitchen flood, %d checks"%["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
