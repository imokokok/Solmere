extends SceneTree
## godot --headless --path . --script modules/restaurant/storage/paper_recipe_test.gd
const Repository = preload("res://modules/restaurant/storage/recipe_repository.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("PAPER RECIPE FAIL: " + label)

func run() -> void:
	var folder := "user://paper_recipe_tests/" + Crypto.new().generate_random_bytes(8).hex_encode()
	var book := Repository.new(folder + "/book.json")
	var blank := {"version": 1, "caption": "", "strokes": [], "stickers": []}
	var note := {"kind": "text", "text": "随手画一顿春天的午饭", "color": "74513dff", "position": [0.5, 0.4], "scale": 0.1, "rotation": -0.17}
	var paper := blank.duplicate(true)
	paper.stickers.append(note)
	var record := {"title": "纸上的午饭", "author": "手作主厨", "notes": "这是一张DIY图文菜谱。", "dish": {"ingredients": []}, "poster": paper}
	check(book.save_recipe(record), "paper-only recipe saves: " + book.last_error)
	var saved: Dictionary = book.load_recipes()[0]
	check(saved.dish == {"ingredients": []}, "paper-only canonical dish has no fabricated cooking score")
	check(saved.poster == paper, "collage preserved")
	var recipe_id: String = saved.id
	var created_at: String = saved.created_at
	check(book.like_recipe(recipe_id), "like recorded before editing")
	var edit := saved.duplicate(true)
	edit.title = "纸上的午饭 · 修订"
	edit.created_at = "1900-01-01"
	edit.likes = 199
	edit.poster.stickers[0].text = "把食材颜色拼成一片花园"
	check(book.save_recipe(edit), "existing recipe updates by same id")
	var edited: Dictionary = book.load_recipes()[0]
	check(book.load_recipes().size() == 1 and edited.id == recipe_id, "edit does not duplicate entry")
	check(edited.created_at == created_at, "edit preserves original creation time")
	check(edited.likes == 1 and book.has_liked(recipe_id), "edit preserves likes and local profile")
	check(not book.like_recipe(recipe_id), "editing does not bypass one-like limit")
	var reload := Repository.new(folder + "/book.json")
	var reloaded_paper: Dictionary = reload.load_recipes()[0].poster
	check(reloaded_paper.stickers == edited.poster.stickers and reloaded_paper.strokes == edited.poster.strokes and reloaded_paper.caption == edited.poster.caption and int(reloaded_paper.version) == 1, "paper-only recipe survives disk reload")
	check(reload.load_recipes()[0].dish == {"ingredients": []}, "reload remains honest about uncooked dish")
	var drawing := blank.duplicate(true)
	drawing.strokes = [{"points": [[0.15, 0.22], [0.5, 0.78]], "color": "284a42ff", "width": 0.01}]
	var drawn := record.duplicate(true)
	drawn.poster = drawing
	drawn.dish = {"ingredients": [], "quality": 1.0, "weirdness": 0.0, "raw_count": 0}
	check(book.save_recipe(drawn), "a real drawing also qualifies")
	check(book.load_recipes()[-1].dish == {"ingredients": []}, "empty dish drops accidental cooking metrics")
	var invalid := record.duplicate(true)
	invalid.notes = ""
	invalid.poster = blank
	check(not book.save_recipe(invalid), "blank paper with no ingredients rejected")
	invalid.poster.caption = "旧标题不是纸面内容"
	check(not book.save_recipe(invalid), "legacy caption alone rejected")
	invalid.poster = {"version": 1, "strokes": [{"points": [], "color": "284a42ff", "width": 0.01}], "stickers": []}
	check(not book.save_recipe(invalid), "empty stroke object does not count")
	invalid.erase("poster")
	check(not book.save_recipe(invalid), "missing poster cannot bypass empty-dish rule")
	invalid = record.duplicate(true)
	invalid.dish.ingredients = [{"id": "unknown_ingredient"}]
	check(not book.save_recipe(invalid), "artwork does not bypass unknown actual ingredient validation")
	invalid = record.duplicate(true)
	invalid.poster.stickers = [{"kind": "ingredient", "id": "unknown_ingredient", "cut": false, "position": [0.5, 0.5], "scale": 0.1}]
	check(not book.save_recipe(invalid), "unknown collage ingredient rejected")
	var cooked := {"title": "六种食材", "author": "主厨", "dish": {"ingredients": ["egg", "tomato", "bread", "shrimp", "cheese", "mushroom"], "quality": 0.8}, "poster": {}}
	check(book.save_recipe(cooked), "valid six-ingredient cooked recipe still saves")
	check(book.load_recipes()[-1].dish.quality == 0.8, "actual cooking metrics preserved")
	var legacy := cooked.duplicate(true)
	legacy.title = "四十八块物理切片记录"
	while legacy.dish.ingredients.size() < 48:
		legacy.dish.ingredients.append("tomato")
	check(book.save_recipe(legacy), "full 48-piece kitchen record remains writable")
	var legacy_reload := Repository.new(folder + "/book.json")
	check(legacy_reload.load_recipes().size() == 4 and legacy_reload.load_recipes()[-1].dish.ingredients.size() == 48, "48-piece record does not invalidate the existing book")
	var retired_path := folder + "/retired-rice.json"
	var retired_record: Dictionary = legacy_reload.load_recipes()[-1].duplicate(true)
	retired_record.dish.ingredients = ["rice", "egg"]
	var retired_file := FileAccess.open(retired_path, FileAccess.WRITE)
	retired_file.store_string(JSON.stringify({"schema_version": 1, "recipes": [retired_record], "liked_ids": []}))
	retired_file.close()
	var retired_book := Repository.new(retired_path)
	check(retired_book.load_recipes().size() == 1 and retired_book.load_recipes()[0].dish.ingredients[0] == "rice", "historical rice cookbook still reads without losing the file")
	check(not retired_book.save_recipe({"title": "new rice", "author": "tester", "dish": {"ingredients": ["rice"]}, "poster": {}}), "new rice recipe cannot be saved")
	check(retired_book.load_recipes().size() == 1, "rejected rice save preserves historical cookbook")
	legacy.dish.ingredients.append("chili")
	check(not book.save_recipe(legacy), "49 entries exceed the physical kitchen limit")
	var blank_update := edited.duplicate(true)
	blank_update.notes = ""
	blank_update.poster = {"version": 1, "caption": "", "strokes": [], "stickers": []}
	check(not book.save_recipe(blank_update), "existing paper recipe cannot be overwritten with blank paper")
	check(book.load_recipes()[0].poster == edited.poster, "invalid edit preserves previous work")
	check(book.export_to(folder + "/portable.json") == OK, "mixed paper/cooked book exports")
	var imported := Repository.new(folder + "/imported.json")
	var result: Dictionary = imported.import_from(folder + "/portable.json")
	check(result.error.is_empty() and result.added == 4, "mixed book imports")
	check(imported.load_recipes()[0].dish == {"ingredients": []}, "portable import does not invent cooking data")
	check(imported.load_recipes()[-1].dish.ingredients.size() == 48, "48-piece recipe also survives portable import")
	if failures == 0:
		print("PAPER_RECIPE_TESTS_PASSED checks=" + str(checks))
	quit(0 if failures == 0 else 1)
