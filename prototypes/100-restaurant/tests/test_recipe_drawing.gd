extends SceneTree
const Sheet = preload("res://modules/restaurant/ui/recipe_sheet.gd")
const Repository = preload("res://modules/restaurant/storage/recipe_repository.gd")
var game
var checks := 0
var failures: Array[String] = []
var store := ""
var output := ""

func _initialize() -> void:
	root.size=Vector2i(1600,946)
	store="user://recipe_drawing_"+Crypto.new().generate_random_bytes(16).hex_encode()+"/book.json"
	if not OS.get_cmdline_user_args().is_empty(): output=OS.get_cmdline_user_args()[0]
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message)

func settle() -> void:
	for i in 4: await process_frame

func find_button(words: String, parent: Node = null) -> Button:
	if parent==null: parent=game.modal_body
	for child in parent.get_children():
		if child is Button and child.is_visible_in_tree() and not child.is_queued_for_deletion() and child.text.begins_with(words): return child
		var found := find_button(words,child)
		if found!=null: return found
	return null

func click(words: String) -> void:
	var control := find_button(words)
	expect(control!=null,"available button: "+words)
	if control==null: return
	var p: Vector2=control.get_global_rect().get_center()
	for state in [true,false]:
		var event := InputEventMouseButton.new(); event.position=root.get_final_transform()*p
		event.global_position=event.position; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=state
		Input.parse_input_event(event); await process_frame
	await settle()

func ink(points: Array, mode := "draw") -> void:
	var canvas=game._recipe_canvas
	canvas.mode=mode
	var previous: Vector2=points[0]
	for i in points.size():
		var p: Vector2=points[i]
		var motion := InputEventMouseMotion.new()
		motion.position=root.get_final_transform()*(canvas.get_global_transform_with_canvas()*p)
		motion.global_position=motion.position; motion.relative=p-previous; motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		if i==0:
			var down := InputEventMouseButton.new(); down.position=motion.position; down.global_position=motion.position
			down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true; Input.parse_input_event(down)
		await process_frame; previous=p
	var up := InputEventMouseButton.new(); up.position=root.get_final_transform()*(canvas.get_global_transform_with_canvas()*previous)
	up.global_position=up.position; up.button_index=MOUSE_BUTTON_LEFT; up.pressed=false; Input.parse_input_event(up)
	await settle()

func capture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name()=="headless": return
	await settle(); RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(output+"-"+name+".png")

func run() -> void:
	game=preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":store,"display_name":"小满"}); root.add_child(game)
	await settle(); game.world.audio.muted=true; game._start_shift(); await settle()
	game._show_cookbook(); await settle(); await click("新建 DIY 菜谱")
	var canvas=game._recipe_canvas
	expect(game._modal_kind=="recipe_editor" and Sheet.valid(canvas.recipe_sheet),"default DIY opens a structured illustrated recipe")
	expect(canvas.size.y>canvas.size.x and canvas.mode=="draw","portrait sheet defaults to a doodle pen")
	expect(canvas.strokes.is_empty() and canvas.stickers.is_empty(),"no hand-drawn name or diagrams are fabricated")
	expect(not game._title_input.is_visible_in_tree(),"the title is drawn at the top, without a typed title field")
	expect(canvas.recipe_sheet.materials.contains("番茄") and canvas.recipe_sheet.steps.size()==4,"materials and four step captions exist before drawing")
	expect(game._recipe_dish.ingredients.is_empty(),"example instructions invent no cooking ingredients")
	expect(game.modal_panel.get_global_rect().end.y<=946,"portrait workbench and save controls fit the game viewport")
	var empty: Dictionary=canvas.export_data()
	game._save_recipe(); await settle()
	expect(game.repository.load_recipes().is_empty() and game._editor_status.text.contains("菜名"),"prewritten instructions alone cannot save an uncreated page")
	await capture("empty")
	await ink([Vector2(120,48),Vector2(170,80),Vector2(200,48)])
	expect(Sheet.has_title(canvas.export_data()),"native mouse drawing reaches the full-page title region")
	game._save_recipe(); await settle()
	expect(game.repository.load_recipes().is_empty() and game._editor_status.text.contains("配图"),"a drawn title still needs a drawn step illustration")
	await ink([Vector2(298,253),Vector2(430,253)])
	var original: Dictionary=canvas.export_data()
	expect(Sheet.has_drawing(original),"native mouse drawing creates a step illustration")
	await ink([Vector2(363,253)],"erase")
	expect(canvas.strokes.size()==3,"eraser splits the middle of a drawn line and keeps its two sides")
	expect(canvas.recipe_sheet==empty.recipe_sheet,"eraser cannot remove the printed instructions")
	await click("撤销")
	expect(JSON.stringify(canvas.export_data())==JSON.stringify(original),"one undo restores the complete eraser gesture")
	await click("重做")
	expect(canvas.strokes.size()==3,"redo reapplies only the erased ink")
	await click("撤销")
	await click("改材料和步骤")
	var materials: TextEdit=canvas._recipe_sheet_layer.fields[0]
	expect(materials.editable and materials.mouse_filter==Control.MOUSE_FILTER_STOP,"printed words become native editable fields on the same paper")
	materials.grab_focus(); await settle()
	materials.select_all(); materials.insert_text_at_caret("番茄两颗\n面条一份\n清水")
	await settle(); materials.release_focus(); await settle()
	expect(canvas.recipe_sheet.materials.contains("两颗"),"edited printed words update persistent sheet data")
	await click("撤销")
	expect(canvas.recipe_sheet.materials==empty.recipe_sheet.materials,"undo also restores printed instruction edits")
	await click("重做")
	expect(canvas.recipe_sheet.materials.contains("两颗"),"redo restores the edited instruction text")
	# A detailed hand-lettered title plus diagrams regularly exceed the old 128 strokes.
	canvas.mode="draw"
	for i in 155:
		var down := InputEventMouseButton.new(); down.position=Vector2(65+i%35*4,483+floori(i/35)*5); down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true
		canvas._gui_input(down); down.pressed=false; canvas._gui_input(down)
	expect(canvas.strokes.size()>128,"detailed pen work is not truncated at the previous small collage budget")
	var before_draft: Dictionary=canvas.export_data()
	game._close_modal(); await settle(); game._show_recipe_editor({},true); await settle(); canvas=game._recipe_canvas
	expect(JSON.stringify(canvas.export_data())==JSON.stringify(before_draft),"closing and reopening retains the illustrated draft and instructions")
	await capture("drawn")
	game._save_recipe(); await settle()
	var records: Array=game.repository.load_recipes()
	expect(records.size()==1,"a pen-written name can save without typing a name")
	if records.size()==1:
		var record: Dictionary=records[0]
		var fresh=Repository.new(store)
		expect(same_json(fresh.load_recipes()[0].poster,before_draft),"disk roundtrip preserves instructions and every freehand stroke")
		expect(record.dish.ingredients.is_empty(),"saved printed sample is still a paper-only recipe")
		game._view_recipe(record); await settle()
		expect(game._recipe_stand.page._collage.size==Sheet.PAGE_SIZE,"stand and reading view use the same full portrait page")
		expect(JSON.stringify(game._recipe_stand.page._collage.export_data())==JSON.stringify(before_draft),"reading view displays the player's original ink, including the title")
		await capture("reader")
		await click("继续 DIY"); canvas=game._recipe_canvas
		await ink([Vector2(320,637),Vector2(402,665)])
		game._save_recipe(); await settle()
		expect(game.repository.load_recipes().size()==1,"saving an edit updates the original record")
		var updated: Dictionary=game.repository.load_recipes()[0]
		game._show_recipe_editor(updated); await settle(); game._save_recipe(true); await settle()
		expect(game.repository.load_recipes().size()==2,"save as copy retains the original and makes a separately editable page")
		var invalid: Dictionary=record.duplicate(true); invalid.erase("id"); invalid.poster.recipe_sheet.steps=["bad"]
		expect(not fresh.save_recipe(invalid),"malformed printed sheet data is rejected at the storage boundary")
		invalid=record.duplicate(true); invalid.erase("id"); invalid.poster.strokes=[]
		expect(not fresh.save_recipe(invalid),"importing empty printed scaffolding cannot pass as a player's creation")
		game._show_recipe_editor(); await settle()
		expect(game._recipe_canvas.recipe_sheet.is_empty(),"legacy collage remains a separate format, with no illustrated draft leakage")
	game.queue_free(); await process_frame
	if failures.is_empty(): print("PASS: hand-drawn recipe, %d checks" % checks); quit(0)
	else:
		for message in failures: push_error(message)
		print("FAIL: hand-drawn recipe, %d/%d checks" % [failures.size(),checks]); quit(1)

func same_json(actual: Variant, expected: Variant) -> bool:
	if (actual is int or actual is float) and (expected is int or expected is float):
		return absf(float(actual)-float(expected))<0.00000001
	if actual is Dictionary and expected is Dictionary:
		if actual.size()!=expected.size(): return false
		for key in expected:
			if not actual.has(key) or not same_json(actual[key],expected[key]): return false
		return true
	if actual is Array and expected is Array:
		if actual.size()!=expected.size(): return false
		for i in expected.size():
			if not same_json(actual[i],expected[i]): return false
		return true
	return typeof(actual)==typeof(expected) and actual==expected
