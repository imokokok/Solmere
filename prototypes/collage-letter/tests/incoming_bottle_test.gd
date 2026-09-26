extends SceneTree
var failures:=0
var game
func check(value:bool,message:String)->void:
	if not value:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func mouse(at:Vector2,down:bool)->void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=at;e.global_position=at;e.pressed=down;root.push_input(e,true);await process_frame
func move(at:Vector2)->void:
	var e:=InputEventMouseMotion.new();e.position=at;e.global_position=at;e.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(e,true);await process_frame
func drag(a:Vector2,b:Vector2)->void:
	await mouse(a,true);await move(b);await mouse(b,false)
func run()->void:
	game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true
	for height in [400,470,560,620]:
		game.receive_bottle();await process_frame
		var incoming=game.get_node("IncomingBottle")
		await drag(incoming.bottle,Vector2(750,height))
		check(incoming.stage=="UNCORK","Bottle picked up at height "+str(height))
		await mouse(incoming.cork,true);await move(Vector2(750,height-280))
		check(incoming.cork_removed and incoming.stage=="POUR","Uncorking is reachable at every bottle height")
		check(game.audio.last_clip=="cork_pop","Uncorking plays the dedicated recorded pop")
		await move(Vector2(1090,320));await mouse(Vector2(1090,320),false)
		var released:Vector2=incoming.cork
		await create_timer(.16).timeout
		check(incoming.cork.distance_to(released)>3,"Thrown cork has momentum instead of snapping to an anchor")
		await create_timer(1.5).timeout
		check(incoming.paper_slide==0 and incoming.stage=="POUR","Upright uncorked bottle does not eject paper")
		await mouse(incoming.cork,true);check(incoming.drag=="cork","Loose cork can be picked up again")
		await move(Vector2(1200,600));await mouse(Vector2(1200,600),false)
		var at:Vector2=incoming.bottle
		await drag(at,at+Vector2(-285 if height in [400,560] else 285,-30))
		await create_timer(.5).timeout
		check(incoming.paper_slide>0 and incoming.paper_slide<320,"Paper slides gradually through the down-facing mouth")
		if height==560:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("COLLAGE_TEST_OUTPUT").path_join("incoming-tilt.png"))
		await create_timer(4).timeout
		check(incoming.stage=="READ" and incoming.opening==1,"Released paper settles and opens without dragging its edge")
		if height==560:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("COLLAGE_TEST_OUTPUT").path_join("incoming-open.png"))
		incoming.close();await process_frame
	game.audio.shutdown();game.queue_free();await process_frame;await process_frame
	print("INCOMING_BOTTLE_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures," heights=4");quit(failures)
