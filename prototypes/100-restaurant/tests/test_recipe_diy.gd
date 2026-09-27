extends SceneTree
## DIY recipe lifecycle through the embedded module and its real GUI entry.
## Godot --headless --path <project> --script res://tests/test_recipe_diy.gd

const Repository = preload("res://modules/restaurant/storage/recipe_repository.gd")
var game
var publications: Array = []
var failures: Array[String] = []
var checks := 0
var test_thumbnail := ""
var original_mouse_mode: int

func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	Engine.max_fps = 120
	call_deferred("_run")

func _run() -> void:
	original_mouse_mode = Input.mouse_mode
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"shift_seconds": 240.0, "display_name": "DIY 测试主厨", "repository_path": "user://recipe_diy_%s/cookbook.json" % Crypto.new().generate_random_bytes(16).hex_encode()})
	game.recipe_published.connect(func(record: Dictionary): publications.append(record.duplicate(true)))
	root.add_child(game)
	await process_frame
	await process_frame
	game._start_shift()
	var first: Dictionary = await _test_new_paper_recipe()
	if not first.is_empty():
		await _test_edit_and_copy(first)
		await _test_page_turn()
	game.world.audio.muted = true
	await create_timer(0.14).timeout
	game.queue_free()
	await process_frame
	_expect(Input.mouse_mode == original_mouse_mode, "DIY test restores host pointer mode")
	if failures.is_empty():
		print("PASS: recipe DIY lifecycle, %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: recipe DIY lifecycle, %d / %d checks" % [failures.size(), checks])
		quit(1)

func _test_page_turn() -> void:
	var pages: Array = game.repository.load_recipes()
	_expect(pages.size() >= 2, "page-turn fixture has two saved recipes")
	if pages.size() < 2: return
	game._view_recipe(pages[0])
	await _layout()
	var original_id := str(game._recipe_selected.get("id", ""))
	game._turn_recipe(1)
	await create_timer(0.6).timeout
	_expect(str(game._recipe_selected.get("id", "")) == str(pages[1].id), "next-page control selects the next saved recipe")
	_expect(game._recipe_stand.record.get("id", "") == pages[1].id, "physical stand and open page remain in sync")
	_expect(not game._recipe_turning, "page-fold animation completes")
	game._turn_recipe(-1)
	await create_timer(0.6).timeout
	_expect(str(game._recipe_selected.get("id", "")) == original_id, "previous-page control returns to the same recipe")

func _test_new_paper_recipe() -> Dictionary:
	_expect(game.session.dish.is_empty() and game._last_dish.is_empty(), "DIY entry fixture has never cooked a dish")
	game._show_cookbook()
	await _layout()
	var new_button: Button = _button("自由拼贴手记")
	_expect(new_button != null and not new_button.disabled, "cookbook offers a usable new-DIY-recipe button before cooking")
	if new_button == null:
		return {}
	await _click(new_button)
	_expect(game.modal.visible and game._modal_kind == "recipe_editor", "actual cookbook button click opens the DIY recipe editor")
	if game._modal_kind != "recipe_editor":
		return {}
	_expect(not game._recipe_canvas.has_content(), "a new DIY recipe starts with genuinely empty paper")
	_expect(game._recipe_dish.get("ingredients", []).is_empty(), "a new DIY recipe records no invented cooking ingredients")
	_expect(_used_ids().is_empty(), "paper-only recipe offers no unrelated food-material buttons")
	_expect(_has_label("尚未记录实际用料"), "paper-only editor clearly states that actual ingredients have not been recorded")
	_check_bounds("new DIY editor")
	game._title_input.text = "第一张自己的菜谱"
	game._author_input.text = "纸上主厨"
	await _click_text("收进我的菜谱")
	_expect(publications.is_empty() and game.repository.load_recipes().is_empty(), "metadata alone cannot publish completely blank paper without a dish")
	_expect(game.modal.visible and game._modal_kind == "recipe_editor" and not game._editor_status.text.is_empty(), "blank-save rejection keeps the editor open with a visible reason")
	game._notes_input.text = "这是一张自主创作的菜谱，还没有实际下锅。"
	await _write_on_paper(game._title_input.text)
	await _click_text("星星")
	_expect(game._recipe_canvas.has_content(), "explicit text and decoration make a DIY paper creation")
	var expected_paper: Dictionary = game._recipe_canvas.export_data()
	await _click_text("收进我的菜谱")
	await _layout()
	_expect(publications.size() == 1, "paper-only recipe emits one publication without requiring a cooked dish")
	if publications.is_empty():
		return {}
	var published: Dictionary = publications[0]
	_expect(not str(published.get("id", "")).is_empty() and not str(published.get("created_at", "")).is_empty(), "DIY publication contains persistent canonical metadata")
	_expect(published.get("dish", {}).get("ingredients", []).is_empty(), "paper-only publication keeps the actual ingredient list empty")
	_expect(_same_json(published.get("poster", {}), expected_paper), "paper-only publication contains the authored layout")
	var stored: Dictionary = _fresh_record(str(published.id))
	_expect(_same_json(stored, published), "paper-only recipe survives a fresh repository load with canonical content")
	_expect(game.session.dish.is_empty() and game._last_dish.is_empty(), "publishing paper does not fabricate a current or last cooked dish")
	return stored

func _test_edit_and_copy(first: Dictionary) -> void:
	# Add a thumbnail to the first record and append an unrelated second record.
	# Updating the first must never accidentally emit the final list element.
	var image := Image.create(16, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color("7d8d63"))
	test_thumbnail = Marshalls.raw_to_base64(image.save_png_to_buffer())
	first["thumbnail"] = test_thumbnail
	_expect(game.repository.save_recipe(first), "thumbnail fixture can be attached to the first recipe")
	var second := {"id": "recipe_diy_unrelated_second", "title": "第二条独立菜谱", "author": "另一位主厨", "notes": "编辑第一条时不可修改我。", "created_at": "2026-09-08 00:00:00 UTC", "dish": {"ingredients": [{"id": "bread", "cut": false, "heat": 8.0}]}, "thumbnail": "", "poster": {"version": 1, "caption": "", "strokes": [], "stickers": []}}
	_expect(game.repository.save_recipe(second), "an unrelated final record exists before editing the first")
	var second_before: Dictionary = _fresh_record(second.id)
	var first_id: String = str(first.id)
	first = _fresh_record(first_id)
	_expect(game.repository.load_recipes().size() == 2, "update regression uses two independently stored recipes")
	game._close_modal()
	_expect(game.world.spawn_ingredient(game._definition("tomato")), "editing-isolation fixture creates a new physical tomato")
	game.world.drop_into_pan()
	for frame in range(90):
		await physics_frame
		if not game.session.dish.is_empty():
			break
	_expect(_dish_ids({"ingredients": game.session.dish}) == ["tomato"], "the currently cooking meal differs from the recipe being edited")
	game._last_dish = {"ingredients": [{"id": "egg", "cut": true, "heat": 8.0, "physics_id": 12345}], "quality": 90.0, "weirdness": 0.0, "tags": ["protein"], "burnt": false}
	var physical_before: Array = game.session.dish.duplicate(true)
	var last_before: Dictionary = game._last_dish.duplicate(true)
	game._show_recipe_editor(first)
	await _layout()
	_expect(game._modal_kind == "recipe_editor", "an existing record opens directly for DIY editing")
	_expect(game._title_input.text == first.title and game._author_input.text == first.author and game._notes_input.text == first.notes, "editing loads the selected recipe's title, author and notes")
	_expect(_same_json(game._recipe_canvas.export_data(), first.poster), "editing restores the existing paper layout")
	_expect(game._recipe_dish.get("ingredients", []).is_empty() and _used_ids().is_empty(), "editing a paper recipe never substitutes current tomato or last egg ingredients")
	_expect(_has_label("尚未记录实际用料"), "existing paper-only recipe retains its no-actual-ingredients explanation")
	_expect(game._recipe_photo == test_thumbnail, "editing loads the selected recipe thumbnail")
	_check_bounds("existing DIY editor")
	game._title_input.text = "第一条已经重新排版"
	game._author_input.text = "更新后的主厨"
	game._notes_input.text = "保留原菜谱身份，更新纸面内容。"
	await _write_on_paper(game._notes_input.text)
	game._recipe_canvas.rotate_selected(PI/12.0)
	await _layout()
	var revised_paper: Dictionary = game._recipe_canvas.export_data()
	await _click_text("保存修改")
	await _layout()
	_expect(publications.size() == 2, "editing an existing recipe emits exactly one additional publication")
	_expect(game.repository.load_recipes().size() == 2, "saving an edit updates the existing id instead of appending")
	if publications.size() < 2:
		return
	var updated: Dictionary = publications[1]
	_expect(str(updated.get("id", "")) == first_id and str(updated.get("id", "")) != str(second.id), "updating a non-final recipe publishes that exact record rather than the last list entry")
	_expect(updated.get("created_at", "") == first.created_at, "editing preserves the original creation metadata")
	_expect(updated.get("title", "") == "第一条已经重新排版" and updated.get("author", "") == "更新后的主厨", "update publication contains the revised metadata")
	_expect(_same_json(updated.get("poster", {}), revised_paper), "update publication includes the edited layout and rotation")
	_expect(updated.get("thumbnail", "") == test_thumbnail, "updating a recipe preserves its loaded thumbnail")
	_expect(_same_json(_fresh_record(first_id), updated), "update publication matches a fresh disk read of its canonical record")
	_expect(_same_json(_fresh_record(second.id), second_before), "editing first recipe leaves the unrelated final recipe unchanged")
	_expect(game.session.dish == physical_before and game._last_dish == last_before, "editing and saving cannot alter the physical meal or last-dish snapshot")

	game._show_recipe_editor(_fresh_record(first_id))
	await _layout()
	_expect(_same_json(game._recipe_canvas.export_data(), revised_paper), "reopening an updated recipe restores the exact arrangement")
	_expect(game._title_input.text == updated.title and game._notes_input.text == updated.notes, "reopening an updated recipe restores revised metadata")
	game._title_input.text = "第一条的独立副本"
	await _click_text("另存为新菜谱")
	await _layout()
	_expect(publications.size() == 3 and game.repository.load_recipes().size() == 3, "save-as-copy creates one new record and one new publication")
	if publications.size() < 3:
		return
	var copied: Dictionary = publications[2]
	var copy_id: String = str(copied.get("id", ""))
	_expect(not copy_id.is_empty() and copy_id != first_id and copy_id != str(second.id), "copy receives its own persistent recipe identity")
	_expect(copied.get("title", "") == "第一条的独立副本" and _same_json(copied.get("poster", {}), revised_paper), "copy publication contains the requested title and copied layout")
	_expect(copied.get("thumbnail", "") == test_thumbnail, "copy retains the edited recipe's thumbnail")
	_expect(_same_json(_fresh_record(first_id), updated), "save-as-copy leaves the original recipe unchanged")
	_expect(_same_json(_fresh_record(second.id), second_before), "save-as-copy leaves other recipes unchanged")
	_expect(_same_json(_fresh_record(copy_id), copied), "copy publication matches the newly persisted canonical record")
	_expect(game.session.dish == physical_before and game._last_dish == last_before, "save-as-copy does not consume or replace kitchen food snapshots")
	game._show_recipe_editor(_fresh_record(copy_id))
	await _layout()
	_expect(_same_json(game._recipe_canvas.export_data(), revised_paper), "reopening the copy restores all paper layers and transforms")
	game._view_recipe(_fresh_record(copy_id))
	await _layout()
	var displayed = game._recipe_stand.page._collage
	_expect(displayed != null and not displayed.editable, "saved DIY copy has a read-only paper view")
	if displayed != null:
		_expect(_same_json(displayed.export_data(), revised_paper), "read-only DIY view displays the saved layout rather than a generated recipe")
	_expect(_has_label("尚未记录实际用料"), "paper-only recipe view also states that no actual ingredients were recorded")
	_check_bounds("DIY recipe view")
	await _click_text("继续 DIY")
	_expect(game._modal_kind == "recipe_editor" and game._title_input.text == copied.title, "saved recipe view offers a real continue-DIY entry for that record")
	_expect(_same_json(game._recipe_canvas.export_data(), revised_paper) and game._recipe_photo == test_thumbnail, "continue-DIY button loads the exact paper and thumbnail")

	# A fresh sheet may offer the current meal as reference material, but it must
	# not auto-fill paper or inherit the previously edited recipe's photograph.
	game._show_cookbook()
	await _layout()
	await _click_text("自由拼贴手记")
	_expect(not game._recipe_canvas.has_content() and _dish_ids(game._recipe_dish) == ["tomato"], "new DIY paper stays blank while offering the actual current meal as reference")
	_expect(game._recipe_photo.is_empty(), "new DIY recipe does not inherit the old recipe thumbnail")
	_expect(game.session.dish == physical_before and game._last_dish == last_before, "new DIY entry preserves the current and last cooked dishes")
	game._close_modal()
	game._show_recipe_editor()
	await _layout()
	_expect(not game._recipe_canvas.has_content() and _dish_ids(game._recipe_dish) == ["tomato"], "normal recipe entry starts blank paper and prioritizes the actual current meal")
	game._title_input.text = "真实料理可以先存配方"
	game._save_recipe(false)
	await _layout()
	_expect(publications.size() == 4, "an actual cooked dish can be saved even without collage content")
	if publications.size() >= 4:
		var cooked: Dictionary = publications[3]
		_expect(_dish_ids(cooked.get("dish", {})) == ["tomato"], "normal recipe records the current tomato before falling back to the last dish")
		_expect(not cooked.get("dish", {}).get("ingredients", [{}])[0].has("physics_id"), "cooked recipe strips transient physical body identifiers")
	_expect(game.session.dish == physical_before and game._last_dish == last_before, "all DIY and cooked save paths leave kitchen snapshots unchanged")

func _fresh_record(recipe_id: String) -> Dictionary:
	var repository = Repository.new(game.repository.storage_path)
	for record in repository.load_recipes():
		if str(record.get("id", "")) == recipe_id:
			return record
	return {}

func _button(text: String) -> Button:
	for child in game.modal_body.find_children("*", "Button", true, false):
		if child.text == text:
			return child as Button
	return null

func _click_text(text: String) -> void:
	var button := _button(text)
	_expect(button != null and not button.disabled, "GUI action is available: %s" % text)
	if button != null and not button.disabled:
		await _click(button)

func _click(button: Button) -> void:
	var point: Vector2 = root.get_final_transform() * button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.pressed = true
	down.position = point
	down.global_position = point
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = point
	up.global_position = point
	Input.parse_input_event(up)
	await _layout()

func _layout() -> void:
	await process_frame
	await process_frame

func _used_ids() -> Array:
	var ids: Array = []
	for child in game.modal_body.find_children("*", "Button", true, false):
		if child.has_meta("ingredient_id"):
			ids.append(str(child.get_meta("ingredient_id")))
	ids.sort()
	return ids

func _has_label(fragment: String) -> bool:
	for child in game.modal_body.find_children("*", "Label", true, false):
		if fragment in child.text:
			return true
	return false

func _dish_ids(dish: Dictionary) -> Array:
	var ids: Array = []
	for entry in dish.get("ingredients", []):
		ids.append(str(entry.get("id", "")))
	ids.sort()
	return ids

func _paper_in_modal():
	for child in game.modal_body.find_children("*", "Control", true, false):
		var script = child.get_script()
		if script != null and str(script.resource_path).ends_with("/poster_canvas.gd"):
			return child
	return null

func _same_json(actual: Variant, expected: Variant) -> bool:
	if (actual is int or actual is float) and (expected is int or expected is float):
		return absf(float(actual) - float(expected)) < 0.00000001
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size(): return false
		for key in expected:
			if not actual.has(key) or not _same_json(actual[key], expected[key]): return false
		return true
	if actual is Array and expected is Array:
		if actual.size() != expected.size(): return false
		for index in expected.size():
			if not _same_json(actual[index], expected[index]): return false
		return true
	return typeof(actual) == typeof(expected) and actual == expected

func _check_bounds(context: String) -> void:
	var rect: Rect2 = game.modal_panel.get_global_rect()
	var size: Vector2 = game.get_viewport_rect().size
	_expect(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= size.x + 1 and rect.end.y <= size.y + 1, "%s fits the viewport" % context)

func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _write_on_paper(words: String) -> void:
	await _click_text("纸上写字")
	var paper=game._recipe_canvas
	var point: Vector2=paper.global_position+paper.size*Vector2(0.55,0.35)
	var press:=InputEventMouseButton.new()
	press.position=root.get_final_transform()*point
	press.global_position=press.position
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	Input.parse_input_event(press)
	await process_frame
	press=press.duplicate(); press.pressed=false; Input.parse_input_event(press)
	await _layout()
	_expect(paper._text_edit_index>=0,"paper writing gesture opens an in-place editable text layer")
	if paper._text_edit_index>=0:
		paper._text_editor.insert_text_at_caret(words)
		paper.finish_text()
