extends SceneTree
## Headless regression; optional rendered invocation also verifies crop pixels.
const Canvas = preload("res://modules/restaurant/ui/poster_canvas.gd")
const Store = preload("res://modules/restaurant/ui/poster_store.gd")
const Repository = preload("res://modules/restaurant/storage/recipe_repository.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("COLLAGE FAIL: " + label)

func click(canvas: Control, point: Vector2, down: bool = true, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = down
	canvas._gui_input(event)

func motion(canvas: Control, point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	canvas._gui_input(event)

func key(canvas: Control, code: int) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	canvas._gui_input(event)

func run() -> void:
	var text_canvas := Canvas.new()
	get_root().add_child(text_canvas)
	text_canvas.size = Vector2(650, 400)
	await process_frame
	text_canvas.begin_text(Vector2(100, 100))
	var prior_editor: TextEdit = text_canvas._text_editor
	prior_editor.text = "第一段文字"
	prior_editor.text_changed.emit()
	prior_editor.focus_exited.emit()
	text_canvas.finish_text()
	# A layer rebuild can destroy this editor before its deferred focus event.
	prior_editor.free()
	text_canvas.begin_text(Vector2(250, 100))
	var successor: TextEdit = text_canvas._text_editor
	successor.text = "第二段文字"
	successor.text_changed.emit()
	await process_frame
	await process_frame
	check(is_instance_valid(successor) and text_canvas._text_editor == successor and text_canvas._text_edit_index >= 0, "freed editor's deferred focus event leaves its successor active")
	text_canvas.finish_text()
	check(text_canvas.stickers.size() == 2 and text_canvas.stickers[0].text == "第一段文字" and text_canvas.stickers[1].text == "第二段文字", "both native text layers survive rapid finish and reopen")
	text_canvas.queue_free()
	await process_frame
	var canvas := Canvas.new()
	get_root().add_child(canvas)
	canvas.size = Vector2(650, 400)
	check(not canvas.has_content(), "new paper has no automatic content")
	check(canvas.caption.is_empty() and canvas.dish_texture == null, "no default caption/photo")
	click(canvas, Vector2(100, 100))
	motion(canvas, Vector2(120, 130))
	click(canvas, Vector2(120, 130), false)
	check(canvas.strokes.is_empty(), "select mode does not draw accidentally")
	canvas.mode = "draw"
	click(canvas, Vector2(100, 100))
	motion(canvas, Vector2(120, 130))
	click(canvas, Vector2(120, 130), false)
	check(canvas.strokes.size() == 1, "explicit draw mode accepts freehand")
	canvas.clear_canvas()
	canvas.mode = "select"
	canvas.add_ingredient({"id": "tomato", "cut": true, "heat": 7.5})
	canvas.add_sticker("star")
	check(canvas.stickers.size() == 2, "ingredient and decoration added")
	var start: Vector2 = canvas._pixel(canvas.stickers[0].position)
	click(canvas, start)
	motion(canvas, start + Vector2(95, 53))
	click(canvas, start + Vector2(95, 53), false)
	check(canvas.stickers[-1].kind == "ingredient", "selected layer comes to front")
	check(canvas.strokes.is_empty(), "layer drag does not create brush stroke")
	check(canvas._pixel(canvas.stickers[-1].position).distance_to(start + Vector2(95, 53)) < 0.1, "real input drag updates normalized position")
	var prior_scale: float = canvas.stickers[-1].scale
	click(canvas, start, true, MOUSE_BUTTON_WHEEL_UP)
	check(canvas.stickers[-1].scale > prior_scale, "wheel resizes selected layer")
	canvas.undo()
	check(is_equal_approx(canvas.stickers[-1].scale, prior_scale), "undo restores layer scale")
	canvas.selected_index = canvas.stickers.size() - 1
	canvas.rotate_selected(PI / 4)
	check(is_equal_approx(canvas.stickers[-1].rotation, PI / 4), "rotation stored")
	canvas.duplicate_selected()
	check(canvas.stickers.size() == 3, "duplicate creates independent layer")
	canvas.send_selected_back()
	check(canvas.selected_index == 0 and canvas.stickers[0].kind == "ingredient", "send to back reorders layers")
	key(canvas, KEY_DELETE)
	check(canvas.stickers.size() == 2, "Delete removes selected layer")
	canvas.undo()
	check(canvas.stickers.size() == 3, "undo restores removed layer")
	canvas.add_text("番茄，今天也认真生活。", Color("74513d"))
	check(canvas.stickers[-1].kind == "text", "text is an explicit movable layer")
	canvas.rotate_selected(-0.3)
	canvas.resize_selected(1.2)
	var text_scale: float = canvas.stickers[-1].scale
	check(text_scale > 0.08, "text resizes through same API")
	var picture := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	picture.fill(Color("dc382d"))
	canvas.add_photo(ImageTexture.create_from_image(picture))
	check(canvas.stickers[-1].kind == "photo", "photo imports inline PNG")
	check(Canvas.validate_photo(canvas.stickers[-1].png), "photo bytes are validated")
	canvas.mode = "cut"
	var photo_index: int = canvas.selected_index
	for local in [Vector2(-34, -34), Vector2(34, -34), Vector2(-34, 34)]:
		click(canvas, canvas._from_layer_local(photo_index, local))
	key(canvas, KEY_ENTER)
	check(canvas.stickers[-1].has("mask") and canvas.stickers[-1].mask.size() == 3, "Enter closes cut polygon")
	check(canvas._layer_nodes[-1].get_child(0) is Polygon2D, "crop uses actual geometry clip")
	check(canvas._layer_nodes[-1].get_child(0).clip_children == CanvasItem.CLIP_CHILDREN_ONLY, "clip hides source pixels outside mask")
	canvas.restore_selected_cut()
	check(not canvas.stickers[-1].has("mask"), "restore removes crop without changing photo source")
	canvas.undo()
	check(canvas.stickers[-1].has("mask"), "crop restoration can be undone")
	canvas.selected_index = photo_index
	canvas.mode = "cut"
	click(canvas, canvas._from_layer_local(photo_index, Vector2(0, 0)))
	key(canvas, KEY_ESCAPE)
	check(canvas._cut_points.is_empty(), "Esc cancels crop draft")
	var data := canvas.export_data()
	var before_size_position: Array = data.stickers[0].position.duplicate()
	canvas.size = Vector2(800, 500)
	await process_frame
	check(canvas.export_data().stickers[0].position == before_size_position, "resize does not change normalized composition")
	var folder := "user://collage_tests/" + Crypto.new().generate_random_bytes(8).hex_encode()
	var store := Store.new(folder + "/poster.json")
	check(store.save_poster(data), "collage poster saved: " + store.last_error)
	var restored := Store.new(folder + "/poster.json")
	check(restored.load_poster().stickers == data.stickers, "all collage layer fields survive poster reload")
	var book := Repository.new(folder + "/recipes.json")
	var recipe := {"title": "自由拼贴", "author": "主厨", "dish": {"ingredients": [{"id": "tomato", "cut": true, "heat": 7.5}]}, "poster": data}
	check(book.save_recipe(recipe), "recipe collage saved: " + book.last_error)
	var restored_book := Repository.new(folder + "/recipes.json")
	check(restored_book.load_recipes()[0].poster.stickers == data.stickers, "recipe collage reloads all fields")
	var invalid := data.duplicate(true)
	invalid.stickers[0].id = "not_a_catalog_ingredient"
	check(not store.save_poster(invalid), "unknown ingredient cannot enter poster store")
	recipe.poster = invalid
	check(not book.save_recipe(recipe), "unknown ingredient cannot enter recipe store")
	invalid = data.duplicate(true)
	invalid.stickers[-1].png = "C:/private/photo.png"
	check(not store.save_poster(invalid), "file paths rejected as photos")
	invalid = data.duplicate(true)
	invalid.stickers[-1].mask = [[-1, -1], [1, 1], [-1, 1], [1, -1]]
	check(not store.save_poster(invalid), "self-intersecting crop rejected")
	canvas.import_data(data)
	check(canvas.export_data().stickers == data.stickers, "canvas import preserves positions scales rotations masks and text")
	canvas.editable = false
	var readonly := canvas.export_data()
	click(canvas, Vector2(200, 200))
	motion(canvas, Vector2(250, 250))
	key(canvas, KEY_DELETE)
	check(canvas.export_data() == readonly, "read-only composition ignores edits")
	canvas.editable = true
	canvas.clear_canvas()
	for index in 36:
		canvas.add_ingredient({"id": "egg"})
	check(canvas.stickers.size() == 32, "32 layers cap enforced")
	canvas.undo()
	check(canvas.stickers.size() == 31, "undo remains usable at layer cap")
	canvas.caption = "legacy caption"
	canvas.dish_texture = ImageTexture.create_from_image(picture)
	canvas.clear_canvas()
	check(not canvas.has_content() and canvas.caption.is_empty() and canvas.dish_texture == null, "clear returns completely blank paper")
	canvas.add_photo(ImageTexture.create_from_image(picture))
	canvas.mode = "cut"
	for local in [Vector2(-40, -40), Vector2(40, -40), Vector2(-40, 40)]:
		click(canvas, canvas._from_layer_local(canvas.selected_index, local))
	key(canvas, KEY_ENTER)
	canvas.editable = false
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var rendered := get_root().get_texture().get_image()
		var center: Vector2 = canvas._pixel(canvas.stickers[0].position)
		var to_pixels := get_root().get_stretch_transform() * canvas.get_global_transform_with_canvas()
		var inside: Color = rendered.get_pixelv(Vector2i(to_pixels * (center + Vector2(-40, -40))))
		var outside: Color = rendered.get_pixelv(Vector2i(to_pixels * (center + Vector2(60, 60))))
		check(inside.r > 0.6 and inside.g < 0.4, "rendered crop keeps inside pixels")
		check(outside.g > 0.6, "rendered crop removes outside pixels")
		canvas.editable = true
		canvas.mode = "draw"
		canvas.ink = Color("234edb")
		canvas.brush_width = 14
		click(canvas, center + Vector2(-80, -60))
		motion(canvas, center + Vector2(-20, -60))
		click(canvas, center + Vector2(-20, -60), false)
		await process_frame
		await RenderingServer.frame_post_draw
		rendered = get_root().get_texture().get_image()
		var ink_pixel: Color = rendered.get_pixelv(Vector2i(to_pixels * (center + Vector2(-50, -60))))
		check(ink_pixel.b > 0.5 and ink_pixel.r < 0.4, "freehand ink visibly paints above photo layers")
		rendered.save_png(ProjectSettings.globalize_path(folder + "/crop_render.png"))
	canvas.queue_free()
	await process_frame
	if failures == 0:
		print("ADVANCED_COLLAGE_TESTS_PASSED checks=" + str(checks))
	quit(0 if failures == 0 else 1)
