extends SceneTree
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok:failures+=1;push_error(message)
func snapshot(game,name:String)->void:
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	var path:=OS.get_environment("COLLAGE_TEST_OUTPUT")
	if not path.is_empty():root.get_texture().get_image().save_png(path.path_join(name+".png"))
func run()->void:
	var game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true;game.get_node("DeskLighting").preview_minute=840
	game.stage="FOLDING";game.build_ui()
	check(not game.ui.find_children("*","Label",true,false).any(func(label):return label.text.contains("恰好的空白")),"Removed folding caption stays absent")
	game.stage="WAX_SEAL";game.finishing.flap=1;game.finishing.phase="PELLETS";game.build_ui()
	var f=game.finishing
	f.input(Vector2(310,600),true);f.mouse_move(f.spoon)
	await snapshot(game,"wax-held-over-bowl")
	f.input(f.spoon,false)
	check(f.pellets and f.phase=="MELT","Foreground handful settles into the spoon")
	await snapshot(game,"wax-settled-in-bowl")
	game.stage="SEND";f.mailbox=1;f.mailed=0;f.mail_pos=Vector2(1080,610);game.build_ui()
	await snapshot(game,"envelope-recoverable-in-front")
	f.input(f.mail_pos,true);check(f.drag=="mail","Old save with hidden envelope remains pickable")
	f.mouse_move(Vector2(700,610));f.input(Vector2(700,610),false)
	check(f.mailed==0 and f.mail_pos==Vector2(1080,610),"Missed drop returns to visible pickup position")
	f.input(f.mail_pos,true);f.mouse_move(Vector2(1080,535));f.input(Vector2(1080,535),false)
	check(f.mailed>0,"Partial overlap with opening accepts the letter, not just pointer position")
	await create_timer(.3).timeout;await snapshot(game,"accepted-mail-occlusion")
	await create_timer(.7).timeout
	check(f.mailed==1,"Accepted letter finishes sliding into box")
	f.input(Vector2(1080,300),true);f.mouse_move(Vector2(1080,470));f.input(Vector2(1080,470),false)
	check(game.stage=="END","Closing lid completes delivery after recovered drop")
	game.audio.shutdown();game.queue_free();await process_frame;await process_frame
	print("FINISHING_RECOVERY_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures);quit(failures)
