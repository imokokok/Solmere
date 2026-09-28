extends SceneTree
## GPU fixture: real fragment geometry, 48-body stress and evolving flame.
## Frame timings describe this host under current load, not every machine.
var game
var folder := "res://qa/20260929-precision/"
func _initialize() -> void:
	root.size=Vector2i(1600,946)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	Engine.max_fps=60
	call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder+name+".png")==OK)
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	DirAccess.make_dir_recursive_absolute(folder)
	game=preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://precision_gpu_%s/book.json" % Time.get_ticks_usec(),"shift_seconds":3600})
	root.add_child(game)
	await process_frame
	game._start_shift()
	var w=game.world
	w.audio.muted=true
	await capture("supported-storage")
	var groups: Array=[]
	for id in ["tomato","potato","mushroom","carrot","onion","cucumber"]:
		w.spawn_ingredient(game._definition(id))
		var whole: RigidBody2D=w._held
		whole.position=w.cutting_board.rect().get_center()
		w.drop_held(false)
		var generation: Array=[whole]
		for depth in 3:
			var next: Array=[]
			for part in generation: next.append_array(w.split_food(part,Vector2.RIGHT if depth%2==0 else Vector2.DOWN,Vector2.INF,4))
			generation=next
			await process_frame
		groups.append(generation)
	# Spread the first three cut portions over the board to inspect original
	# silhouette, exposed flesh and repeated cut offsets at ordinary scale.
	var index:=0
	for group in groups:
		for part in group:
			part.stop_board_settle()
			if index<24:
				part.position=Vector2(1068+(index%8)*42,692+(index/8)*35)
				part.freeze=true
				part.set_meta("on_board",true)
			else:
				part.position=w.pan.point(Vector2(738+(index%8)*20,535-(index/8)*18))
				part.freeze=false
				part.set_meta("on_board",false)
			index+=1
	await create_timer(3).timeout
	await capture("cut-portions")
	var samples: Array[float]=[]
	var physics: Array[float]=[]
	var previous:=Time.get_ticks_usec()
	for frame in 600:
		await process_frame
		var now:=Time.get_ticks_usec()
		samples.append((now-previous)/1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		previous=now
	samples.sort()
	physics.sort()
	var report={"scope":"GPU 48 cut bodies; 24 on board, 24 native contacts in pan; other desktop apps remain open","body_count":w._foods.get_child_count(),"frames":samples.size(),"frame_ms_p50":samples[300],"frame_ms_p95":samples[570],"frame_ms_max":samples[-1],"physics_ms_p95":physics[570],"renderer":RenderingServer.get_video_adapter_name()}
	# The idle pile alone cannot stand in for cooking performance. Measure the
	# same contacts with live thermal evolution as a separate controlled stage.
	w.reactions.pan_c=160.0
	w.set_heat_level("medium")
	w.set_cooking(true)
	samples.clear()
	physics.clear()
	previous=Time.get_ticks_usec()
	for frame in 300:
		await process_frame
		var now:=Time.get_ticks_usec()
		samples.append((now-previous)/1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		previous=now
	samples.sort()
	physics.sort()
	report["heated"]={"frames":300,"initial_pan_c":160.0,"frame_ms_p50":samples[150],"frame_ms_p95":samples[285],"frame_ms_max":samples[-1],"physics_ms_p95":physics[285]}
	await capture("heated-portions")
	for part in w._foods.get_children(): assert(part.position.is_finite() and part.position.y<850)
	FileAccess.open(folder+"performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	w.material_play.set_physics_process(false)
	w.material_play.fire=0.8
	w.material_play.smoke=0.3
	for i in 3:
		await create_timer(0.35).timeout
		w.material_play.clock+=0.35
		await capture("fire-motion-%d"%i)
	print("PASS: GPU precision review ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	await process_frame
	quit()
