extends SceneTree
var failures:=0
var game
var r
func check(ok:bool,why:String)->void:
	if not ok:failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func settle(limit:float=12.0)->void:
	var until:=Time.get_ticks_msec()+int(limit*1000)
	while (not r.pending_characters.is_empty() or not r.active.is_empty()) and Time.get_ticks_msec()<until:
		if r.waiting_page>=0:r.turn_page(1)
		await process_frame
	check(r.pending_characters.is_empty() and r.active.is_empty(),"Queue drains within bound")
func reset(value:String="")->void:
	r.load_text(value);game.letter_text=value;game.build_ui()
func key(code:int,unicode:int=0)->void:
	var event:=InputEventKey.new();event.keycode=code;event.unicode=unicode;event.pressed=true;root.push_input(event,true);await process_frame
func run()->void:
	game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true;game.set_tool("write");r=game.letter_text_node
	check(game.letter_text.is_empty(),"Default letter is blank")
	game.desk.writing.insert_text_at_caret("人");await process_frame
	check(game.letter_text=="人" and r.full_text=="人","Native committed Chinese enters authoritative String")
	await settle();check(r.visual_text=="人","One character renders")
	var example: String="Hello, Solmere! 你好，海边。123 🙂 é 👩‍👩‍👧‍👦 🇨🇳\n\nTake your time."
	reset();game.desk.writing.insert_text_at_caret(example);await process_frame
	check(game.letter_text==example,"Pasting preserves mixed Unicode String")
	await settle();check(r.visual_text==example,"Shaping queue preserves combining marks and joined emoji")
	check(r.graphemes("é👩‍👩‍👧‍👦🇨🇳").size()==3,"Grapheme clusters remain intact")
	var start:Vector2=r.caret_position(0);var narrow:Vector2=r.caret_position(1)
	check(narrow.x>start.x,"Caret comes from actual shaped advance")
	reset();game.desk.writing.insert_text_at_caret("a".repeat(50));await process_frame
	game.desk.writing.insert_text_at_caret("删除前还在书写");await process_frame
	for _i in 8:game.desk.writing.backspace()
	await process_frame;await settle();check(r.visual_text==game.letter_text,"Rapid insert and delete events converge")
	reset("é👩‍👩‍👧‍👦🇨🇳");game.desk.writing.position_caret(game.letter_text.length())
	await key(KEY_BACKSPACE);check(game.letter_text=="é👩‍👩‍👧‍👦","Backspace removes complete flag")
	await key(KEY_BACKSPACE);await key(KEY_BACKSPACE);await key(KEY_BACKSPACE);await settle();check(game.letter_text.is_empty() and r.visual_text.is_empty(),"Backspace to empty is safe")
	reset();r.writing_speed="Fast";game.desk.writing.insert_text_at_caret("海边的风很轻。\n".repeat(25));await process_frame
	var until:=Time.get_ticks_msec()+10000
	while r.waiting_page<0 and Time.get_ticks_msec()<until:await process_frame
	check(r.waiting_page==1 and r.page==0,"Full page waits for manual page turn without scrolling")
	var queued:int=r.pending_characters.size();await create_timer(.15).timeout
	check(r.pending_characters.size()==queued,"Page pause does not lose or consume queued characters")
	r.writing_speed="Instant";await settle();check(r.page_count>1 and r.visual_text==game.letter_text,"All pages retain long paste")
	game.save_game(true);var saved:String=game.letter_text;game.load_game(true)
	check(game.letter_text==saved and r.visual_text==saved and r.pending_characters.is_empty(),"Reload renders original String immediately")
	check(game.current_letter_data().has_all(["letter_id","sender","recipient","full_text","created_time","letter_type","reply_to","completed","sealed","sent","author_id","reply_chain_id","required_keywords","forbidden_keywords","tone"]),"Persisted record includes narrative and puzzle interfaces")
	r.page=1;game.take_material_whole(620,game.LETTER.get_center());await process_frame
	reset("");check(r.page_count==2,"Removing text keeps a later page containing collage")
	game.save_game(true);game.load_game(true);check(r.page_count==2,"Collage-only later page survives reload")
	var document=preload("res://scripts/letter_document.gd").new();game.add_child(document);await document.build(game)
	check(document.pages.size()==2,"Finishing composition includes the later collage page")
	document.queue_free()
	for piece in game.pieces_root.get_children():game.pieces_root.remove_child(piece);piece.queue_free()
	await process_frame;game.set_tool("write")
	reset();r.writing_speed="Normal";r.play_letter_animation(example.repeat(8));await process_frame;r.skip();await create_timer(.22).timeout
	check(r.visual_text==example.repeat(8) and r.pending_characters.is_empty(),"Replay Skip settles in 0.1–0.2 seconds")
	reset();game.writing_preferences.speed="Fast";game.apply_writing_preferences();game.desk.writing.insert_text_at_caret("阿宁：\n今天的海风让我想起你。\n林舟");await process_frame
	game.complete_letter();await process_frame
	check(game.stage=="WORKBENCH" and game.busy and not game.desk.writing.editable,"Finish locks input and waits for queued ink")
	while game.busy:await process_frame
	check(game.stage=="FOLDING" and r.state==r.State.FOLDING,"Writing finishes before existing fold interaction")
	check(r.visual_text==game.letter_text and game.current_letter_data().completed,"Finished text and metadata remain intact")
	var folder:=OS.get_environment("COLLAGE_TEST_OUTPUT")
	if not folder.is_empty():await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder.path_join("new-writing-fold.png"))
	game.audio.shutdown();game.queue_free();await process_frame;await process_frame
	print("WRITING_SYSTEM_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures);quit(failures)
