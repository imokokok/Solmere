extends SceneTree
var failures:=0
func check(ok:bool,why:String)->void:
	if not ok:failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func capture(name:String)->void:
	await process_frame;await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("COLLAGE_TEST_OUTPUT")
	if not folder.is_empty():root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run()->void:
	var game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true;game.sample_cycle=0;game.letter_text="这是一封不能被示例覆盖的原信。";game.save_game(true)
	var original_save:String=game.save_path
	game.receive_bottle();var incoming=game.get_node("IncomingBottle")
	check(incoming.stage=="LIFT" and game.dock_open,"Incoming bottle is picked up before reading")
	incoming.stage="READ";incoming.close();await process_frame;game.open_bottles();await process_frame;await RenderingServer.frame_post_draw;await process_frame
	var dock
	for child in game.get_children():
		if child.get_script()==game.BottleDock:dock=child
	check(dock!=null and dock.letters_box.has_node("LocalExampleLetter"),"The fictional letter is readable without a server")
	await capture("sea-incoming-example")
	await dock.show_example(true);await process_frame;await RenderingServer.frame_post_draw;await process_frame
	await capture("sea-reply-preview")
	dock.close();game.SeaExample.start_reply(game);await process_frame;await RenderingServer.frame_post_draw;await process_frame
	check(game.letter_text.contains("小岸") and game.pieces_root.get_child_count()>=3,"Prepared reply contains both a human letter and collage")
	check(game.save_path!=original_save,"Example has its own draft path")
	await capture("sea-reply-ready")
	await game.complete_letter();check(game.stage=="BOTTLE","Prepared reply immediately enters rolling")
	var ritual=game.bottle_finish
	ritual.input(Vector2(490,650),true);ritual.input(Vector2(490,270),false)
	ritual.input(ritual.cork_at,true);ritual.input(Vector2(1120,240),false)
	ritual.input(ritual.roll_at,true);ritual.move(Vector2(1000,220));ritual.input(Vector2(1000,558),false)
	ritual.input(ritual.cork_at,true);ritual.input(Vector2(1000,329),false)
	check(ritual.phase=="SEA","Example follows rolling, uncorking, insertion and recorking")
	ritual.input(ritual.bottle_at,true);ritual.input(Vector2(1270,550),false);await create_timer(0.45).timeout
	check(ritual.phase=="WAIT" and ritual.splash>0 and game.audio.bank.has("ocean"),"Water release has a visible splash and real recorded ocean audio")
	await capture("sea-release-ripples");await create_timer(3.5).timeout
	check(game.stage=="END" and game.bottle_published_id==0 and not game.sample_reply_due,"Local reply completes without pretending to publish online")
	game.SeaExample.return_to_letter(game)
	check(game.save_path==original_save and game.letter_text=="这是一封不能被示例覆盖的原信。","Returning restores the untouched original draft")
	game.audio.shutdown();game.queue_free();await process_frame;await process_frame
	print("SEA_EXAMPLE_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures);quit(failures)
