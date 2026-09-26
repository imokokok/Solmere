extends SceneTree
var failures:=0
var game
func check(ok:bool,why:String)->void:
	if not ok:failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func click(at:Vector2,down:bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=at;event.global_position=at;event.pressed=down;root.push_input(event,true)
	await process_frame
func move(at:Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.position=at;event.global_position=at;event.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(event,true);await process_frame
func drag(a:Vector2,b:Vector2)->void:
	await click(a,true);await move(b);await click(b,false);await process_frame
func capture(name:String)->void:
	await process_frame;await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("COLLAGE_TEST_OUTPUT")
	if not folder.is_empty():root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run()->void:
	game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true
	check(game.letter_text.is_empty() and not game.conversation_open,"A new desk opens without a prewritten letter or a blocking commission")
	check(not is_instance_valid(game.desk.writing) and game.tool=="move","The blank page has no placeholder body")
	check(not game.desk.has_node("Object_pen") and not game.desk.has_node("Object_tray"),"Desk uses two bottles and no decorative pen")
	await capture("new-blank-desk")
	game.desk.get_node("Object_typewriter").pressed.emit();await process_frame
	var station=game.desk.get_node("TypewriterStation")
	for key in ["Key_h","Key_i"]:
		var node:Button=station.get_node(key);await click(node.get_global_rect().get_center(),true);await click(node.get_global_rect().get_center(),false)
	check(game.typewriter_text=="hi" and game.letter_text.is_empty(),"Mouse letter keys type on an independent sheet")
	check(game.audio.last_clip.begins_with("typewriter"),"Typing uses a recorded mechanical key sound")
	await capture("typewriter-keys")
	station.get_node("UseTypedPage").pressed.emit();await process_frame
	check(game.letter_text=="hi" and not game.typewriter_previous.is_empty(),"Typed page replaces letter text with an undo snapshot")
	game.typewriter_open=true;game.build_ui();await process_frame;station=game.desk.get_node("TypewriterStation");station.get_node("UndoTypedPage").pressed.emit();await process_frame
	check(game.letter_text.is_empty(),"Undoing replacement restores the original blank page")
	station=game.desk.get_node("TypewriterStation");station.begin_cut();await station.cut_piece(Rect2(103,52,155,88));await process_frame
	check(game.selected.source_id==-5 and not game.selected.painted_png.is_empty(),"Typed passage becomes a saved independent clipping")
	var piece=game.selected;piece.position=Vector2(708,402);piece.scale=Vector2.ONE;piece.rotation=0.2;game.set_tool("move");await process_frame
	var handles=game.get_node("PieceHandles")
	for size in [Vector2i(960,600),Vector2i(1280,800),Vector2i(1440,900)]:
		DisplayServer.window_set_size(size);await process_frame;await process_frame
		var original_scale:Vector2=piece.scale;var p:PackedVector2Array=handles.points();var anchor:Vector2=p[7]
		await drag(p[3],p[3]+Vector2(35,0).rotated(piece.rotation))
		check(piece.scale.x>original_scale.x and is_equal_approx(piece.scale.y,original_scale.y),"Side handle stretches width only at "+str(size))
		check(handles.points()[7].distance_to(anchor)<1.0,"Opposite resize edge remains anchored")
		p=handles.points();original_scale=piece.scale
		await drag(p[5],p[5]+Vector2(0,25).rotated(piece.rotation))
		check(piece.scale.y>original_scale.y and is_equal_approx(piece.scale.x,original_scale.x),"Bottom handle stretches height independently")
		p=handles.points();var ratio:float=piece.scale.x/piece.scale.y
		await drag(p[4],p[0]+(p[4]-p[0])*1.13)
		check(is_equal_approx(piece.scale.x/piece.scale.y,ratio),"Corner handle preserves the current aspect ratio")
		var old_rotation:float=piece.rotation;var handle:Vector2=handles.rotate_point();var target:Vector2=piece.position+(handle-piece.position).rotated(0.35)
		await drag(handle,target)
		check(absf(piece.rotation-old_rotation)>0.25,"Circular handle rotates the clipping")
	await capture("selected-piece-handles")
	game.shelf_open=true;game.drawer_group="票据";game.build_ui();await process_frame
	var count:=0
	for child in game.desk.shelf.get_children():
		if child.name.begins_with("Material_"):count+=1;check(child.size.x>=300,"Text-heavy clippings have large readable previews")
	check(count==2,"Ticket page has only two items")
	await capture("two-large-tickets")
	game.drawer_group="照片";game.build_ui();await process_frame;count=0
	for child in game.desk.shelf.get_children():
		if child.name.begins_with("Material_"):count+=1
	check(count==4,"Photo page has four items")
	game.shelf_open=false;game.build_ui();await process_frame
	var envelope:Button=game.desk.get_node("Object_envelope");await click(envelope.get_global_rect().get_center(),true);await click(envelope.get_global_rect().get_center(),false)
	while game.busy:await process_frame
	check(game.stage=="FOLDING","Actual Fold & post button accepts an unglued clipping")
	await capture("fold-button-works")
	game.audio.shutdown();game.queue_free();await process_frame;await process_frame
	print("DIRECT_WORKBENCH_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures);quit(failures)
