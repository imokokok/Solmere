extends SceneTree
var failures:=0
func check(ok:bool, why:String)->void:
	if not ok:failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func capture(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("COLLAGE_TEST_OUTPUT")
	if not folder.is_empty():root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run()->void:
	var game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true;game.open_commission();await process_frame
	var card=game.ui.get_child(1)
	check(not game.desk.visible and not game.pieces_root.visible,"Commission hides workbench controls and collage layers")
	check(not card.attachments.visible,"Greeting does not show unexplained attachments")
	check(card.body.visible_characters<card.body.text.length(),"Commission begins with gradual character reveal")
	card.advance();check(card.step==0 and card.body.visible_characters==card.body.text.length(),"First click reveals without skipping dialogue")
	await capture("commission-intro")
	card.advance();card.advance();card.advance();card.advance()
	check(card.step==2 and card.choices.get_child_count()==2,"Optional questions appear after client's request")
	check(not card.attachments.visible,"Player's opening reply does not display attachments")
	card.ask(0);card.advance();await capture("commission-answer")
	check(card.question_return and card.body.text==game.commissions[0].answers_zh[0],"Question receives the customer's authored answer")
	card.advance();check(card.step==2 and not card.question_return,"Answer returns to the same dialogue step")
	var cursor: int=card.step
	card.open_history();await process_frame
	check(card.reading_history and game.commission_history["0"].any(func(entry):return entry.key=="answer_0_zh"),"History includes the actual optional answer")
	var journal=card.get_child(card.get_child_count()-1)
	await capture("conversation-history")
	journal.on_close.call();check(card.step==cursor and not card.reading_history,"Closing history preserves dialogue progress")
	for i in card.lines.size()*2:
		if not game.conversation_open:break
		card.advance()
	await process_frame
	check(game.accepted_commission==0 and not game.conversation_open and game.drawer_group=="客户","Accepting reveals the attached materials in the drawer")
	check(game.desk.visible and game.pieces_root.visible,"Leaving commission restores the playable desk")
	game.take_material_whole(30,Vector2(650,365));await capture("paper-before-paint")
	var sheet=game.selected
	var before: Image=sheet.texture.get_image().duplicate()
	game.paint.scope="material";game.paint.begin(sheet.position)
	check(not game.paint.active,"Dry brush cannot paint")
	game.paint.dip(2);game.paint.begin(sheet.position);game.paint.move(Vector2(790,365));game.paint.end()
	var after: Image=sheet.texture.get_image()
	check(before.get_data()!=after.get_data(),"Dipped pigment changes the paper")
	var spill:=0
	for y in after.get_height():
		for x in after.get_width():
			if before.get_pixel(x,y).a<0.12 and before.get_pixel(x,y)!=after.get_pixel(x,y):spill+=1
	check(spill==0,"Material painting leaves every transparent pixel unchanged")
	check(not sheet.painted_png.is_empty(),"Material paint is serialized with the piece")
	sheet.rotation=0.22;sheet.position=Vector2(670,360)
	game.save_game(true);game.load_game(true);sheet=game.pieces_root.get_child(0)
	check(sheet.texture.get_image().get_data()==after.get_data() and is_equal_approx(sheet.rotation,0.22),"Paint and transformed paper survive reload together")
	game.select(sheet);game.apply_glue(sheet.position,0.12)
	check(sheet.glue_coverage>0 and not sheet.back_visible,"Optional glue works without flipping the paper")
	for y in 5:
		for x in 6:game.apply_glue(sheet.to_global(sheet.bounds().position+sheet.bounds().size*Vector2((x+0.5)/6.0,(y+0.5)/5.0)),0.12)
	check(sheet.is_glued and not sheet.back_visible,"Glue records adhesion without hiding the front")
	var before_scale:Vector2=sheet.scale;game.transform_selected(1.12,0.1)
	check(sheet.scale!=before_scale,"Previously glued pieces remain editable")
	game.save_game(true);game.load_game(true)
	check(game.commission_history["0"].any(func(entry):return entry.key=="answer_0_zh"),"Dialogue history survives reloading the draft")
	sheet=game.pieces_root.get_child(0)
	game.paint.scope="page";game.paint.dip(0);game.paint.begin(Vector2(585,350));game.paint.move(Vector2(755,390));game.paint.end()
	check(game.pieces_root.get_child_count()==2 and game.pieces_root.get_child(1).source_id==-4,"Whole-page wash sits above existing collage")
	game.tools_open=true;game.set_tool("brush");await capture("painted-collage")
	game.paint.undo();check(game.pieces_root.get_child_count()==1,"Undo removes only the latest whole-page wash")
	game.source_preview_id=31;game.shelf_open=true;game.build_ui();await process_frame;await RenderingServer.frame_post_draw
	game.paint.scope="material";game.paint.dip(1);game.paint.begin(game.sources[31].get_center());game.paint.move(game.sources[31].get_center()+Vector2(40,0));game.paint.end()
	game.tool="rect";game.cutting_source=31;game.start=game.sources[31].position+Vector2(20,20);game.finish_cut(game.start+Vector2(230,180))
	check(not game.selected.painted_png.is_empty(),"A painted source transfers pigment to a newly cut piece")
	game.save_game(true);game.load_game(true)
	check(not game.pieces_root.get_child(1).painted_png.is_empty(),"Painted source cut survives save and reload")
	for locale in ["zh","en"]:
		if game.L.language!=locale:game.switch_language()
		for commission in game.commissions.size():
			game.commission_index=commission;game.open_commission();await process_frame
			var dialogue=game.ui.get_child(1)
			for line in dialogue.lines.size():
				dialogue.step=line;dialogue.show_step();dialogue.advance();await process_frame
				check(dialogue.body.size.y<=156,"Dialogue fits its stationery: "+locale+" "+str(commission)+" / "+str(line))
				check(dialogue.attachments.visible==(line>=3 and not game.customer_material_ids().is_empty()),"Attachments follow their introduction")
				check(dialogue.body.get_rect().end.y<dialogue.reply.position.y,"Text and reply never overlap")
				if line==3 and commission==0:await capture("commission-enclosures-"+locale)
			for question in 2:
				dialogue.ask(question);dialogue.advance();await process_frame
				check(dialogue.body.size.y<=156,"Optional answer fits its stationery")
			if commission==0:await capture("commission-"+locale)
			dialogue.close();await process_frame
	game.audio.shutdown();game.queue_free();await process_frame;await process_frame
	print("PAINT_DIALOGUE_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(failures)
