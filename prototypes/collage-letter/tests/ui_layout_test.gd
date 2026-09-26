extends SceneTree
var failures:=0
func check(ok:bool, why:String)->void:
	if not ok:failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func visible_buttons(node: Node, result: Array) -> void:
	if node is Button and node.is_visible_in_tree() and Rect2(0,0,1440,900).intersects(node.get_global_rect()):result.append(node)
	for child in node.get_children():visible_buttons(child,result)
func capture(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("COLLAGE_TEST_OUTPUT")
	if not folder.is_empty():root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run()->void:
	var game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true;game.conversation_open=false;game.build_ui()
	check(not game.shelf_open and not game.tools_open,"Both drawers start closed")
	await capture("closed-desk")
	game.desk.toggle("shelf");await create_timer(1.2).timeout
	check(is_equal_approx(game.desk.shelf.position.x,38),"Shelf slides into its open position")
	game.desk.toggle("tools");await create_timer(1.2).timeout
	check(is_equal_approx(game.desk.kit.position.x,1039),"Kit slides into its open position")
	game.desk.begin_material_drag(622,Vector2(200,360))
	var drop:=InputEventMouseButton.new();drop.button_index=MOUSE_BUTTON_LEFT;drop.pressed=false;drop.position=Vector2(650,360);game.desk._input(drop)
	check(game.selected.source_id==622 and game.selected.position==drop.position,"Drawer drag creates an independent photo at release position")
	game.drawer_group="票据";game.build_ui()
	var tickets: Array=game.desk.group_material_ids()
	game.source_preview_id=tickets[0];game.build_ui();await process_frame
	game.desk.shelf.get_node("PreviewNext").pressed.emit();await create_timer(0.8).timeout
	check(game.source_preview_id==tickets[1],"Preview next arrow turns directly to the next ticket")
	game.desk.shelf.get_node("PreviewPrevious").pressed.emit();await create_timer(0.8).timeout
	game.desk.shelf.get_node("PreviewPrevious").pressed.emit();await create_timer(0.8).timeout
	check(game.source_preview_id==tickets[-1] and game.drawer_page==(tickets.size()-1)/game.desk.page_size(),"Preview wraps within its category and keeps list page aligned")
	check(game.pieces_root.get_child_count()==1,"Preview paging preserves the collage")
	for locale in ["zh","en"]:
		if game.L.language!=locale:game.switch_language()
		for dimensions in [Vector2i(960,600),Vector2i(1280,800),Vector2i(1440,900)]:
			DisplayServer.window_set_size(dimensions)
			for tool in ["move","tape","pen","brush","glue","rect","free","write"]:
				game.set_tool(tool);await process_frame;await process_frame
				var buttons:Array=[];visible_buttons(game.desk,buttons)
				for a in buttons.size():
					check(Rect2(0,0,1440,900).encloses(buttons[a].get_global_rect()),"Button inside canvas: "+buttons[a].text)
					for b in range(a+1,buttons.size()):check(not buttons[a].get_global_rect().intersects(buttons[b].get_global_rect()),"Overlapping controls: "+buttons[a].text+" / "+buttons[b].text)
				if dimensions==Vector2i(1280,800):await capture("ui-"+locale+"-"+tool)
	game.audio.shutdown();game.queue_free();await process_frame;await process_frame
	print("UI_LAYOUT_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures," locales=2 window_sizes=3 tools=8")
	quit(failures)
