extends SceneTree
var failures:=0
func check(ok:bool,why:String)->void:
	if not ok:failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func run()->void:
	var game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true
	preload("res://scripts/showcase_draft.gd").apply(game)
	check(game.pieces_root.get_child_count()>10 and game.letter_text.length()<80,"Demo communicates through independent collage pieces and restrained text")
	game.desk.get_node("Object_folio").pressed.emit();await create_timer(.32).timeout
	check(game.desk.shelf.position.distance_to(Vector2(84,480))<1,"Cover opens at its original physical position before enlarging")
	check(game.desk.shelf.scale.x<.7,"Opening cover keeps original scale")
	await create_timer(.9).timeout
	check(game.desk.shelf.scale.distance_to(Vector2.ONE)<.01,"Only the opened book grows to reading size")
	game.stage="END";game.restart();await process_frame
	check(game.letter_text.is_empty() and game.pieces_root.get_child_count()==0,"Next task contains no authored demo words or scraps")
	game.save_game(true);game.load_game(true)
	check(game.showcase_seen and game.letter_text.is_empty(),"Reload remembers the demo was already seen without refilling the blank next task")
	# An actual old draft must retain its old material text and move with the A4 layout once.
	game.take_material_whole(0,Vector2(720,400));game.save_game(true)
	var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	old.version=3;old.erase("paper_layout");old.pieces[0].erase("material_revision")
	var file:=FileAccess.open(game.save_path,FileAccess.WRITE);file.store_string(JSON.stringify(old));file.close()
	game.load_game(true);await process_frame;await RenderingServer.frame_post_draw
	var piece=game.pieces_root.get_child(0)
	check(piece.material_revision==1,"Old draft resolves its original text source, not the replacement classic excerpt")
	var expected:Vector2=game.LETTER.position+(Vector2(720,400)-Vector2(522,174))*game.LETTER.size/Vector2(396,560)
	check(piece.position.distance_to(expected)<.01,"Old collage coordinates migrate proportionally to the new A4 desk")
	game.save_game(true);game.load_game(true)
	check(game.pieces_root.get_child(0).position.distance_to(expected)<.01,"Reload never applies the layout migration twice")
	game.audio.shutdown();game.queue_free();await process_frame;await process_frame
	print("DEMO_TRANSITION_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures);quit(failures)
