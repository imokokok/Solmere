extends SceneTree
## Full-scene GUI routing regression. All tested mouse/key interactions enter
## through Input.parse_input_event, never through Canvas._gui_input or signals.
## Godot --headless --path <project> --script res://tests/test_collage_input.gd

var game
var failures: Array[String] = []
var checks := 0
var previous_pointer := Vector2.ZERO
var original_mouse_mode: int

func _initialize() -> void:
	root.size = Vector2i(960, 568)
	Engine.max_fps = 120
	call_deferred("_run")

func _run() -> void:
	original_mouse_mode = Input.mouse_mode
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"shift_seconds": 240.0, "repository_path": "user://collage_input_%s/cookbook.json" % Crypto.new().generate_random_bytes(16).hex_encode()})
	root.add_child(game)
	await process_frame
	await process_frame
	game._start_shift()
	# The prior meal supplies the editable paper materials. A separate physical
	# mushroom remains on the counter to detect accidental kitchen interaction.
	game._last_dish = {"ingredients": [{"id": "egg", "cut": true, "heat": 8.0}], "quality": 90.0, "weirdness": 0.0, "tags": ["protein"], "burnt": false}
	_expect(game.world.spawn_ingredient(game._definition("mushroom")), "world fixture creates a real physical mushroom")
	var mushroom: RigidBody2D = game.world._held
	game.world.drop_held(false)
	if is_instance_valid(mushroom):
		mushroom.global_position = Vector2(470, 610)
		mushroom.freeze = true
	await process_frame
	await _test_editor("recipe")
	await _test_editor("poster")
	_release(previous_pointer)
	game._close_modal()
	game.world.audio.muted = true
	await create_timer(0.14).timeout
	game.queue_free()
	await process_frame
	_expect(Input.mouse_mode == original_mouse_mode, "GUI input test restores the host pointer mode on unmount")
	if failures.is_empty():
		print("PASS: real collage GUI input, %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: real collage GUI input, %d / %d checks" % [failures.size(), checks])
		quit(1)

func _test_editor(kind: String) -> void:
	if kind == "recipe":
		game._show_recipe_editor()
	else:
		game._show_poster()
	await process_frame
	await process_frame
	var canvas = game._recipe_canvas if kind == "recipe" else game._poster_canvas
	_expect(game.modal.visible and not game.world.controls_enabled, "%s editor owns interaction while open" % kind)
	_expect(not canvas.has_content(), "%s paper is initially blank" % kind)
	var dish_before: Array = game.session.dish.duplicate(true)
	var last_dish_before: Dictionary = game._last_dish.duplicate(true)
	var food_count_before: int = game.world._foods.get_child_count()
	var material = game.modal_body.find_child("UsedIngredient_egg", true, false)
	_expect(material is Button and material.is_visible_in_tree(), "%s used-food material is a visible GUI button" % kind)
	if not material is Button:
		game._close_modal()
		return
	await _click(material.get_global_rect().get_center())
	_expect(canvas.stickers.size() == 1 and str(canvas.stickers[0].get("id", "")) == "egg", "%s actual mouse click adds the selected food art" % kind)
	_expect(game.world._foods.get_child_count() == food_count_before and game.world._held == null and not game.world._knife_held, "%s material click never spawns or grabs a kitchen object" % kind)
	_expect(game.session.dish == dish_before and game._last_dish == last_dish_before, "%s GUI material click leaves both cooking snapshots unchanged" % kind)
	if canvas.stickers.size() != 1:
		game._close_modal()
		return

	# Grab off-center so the test also catches snapping the layer to the pointer.
	var initial: Vector2 = _layer_center(canvas)
	var grab: Vector2 = initial + Vector2(12, 8)
	_press(grab)
	await process_frame
	_expect(canvas._dragging_layer, "%s routed mouse press begins a layer drag" % kind)
	_expect(_layer_center(canvas).is_equal_approx(initial), "%s press preserves the grabbed offset" % kind)
	_motion(grab + Vector2(100, 40), true)
	await process_frame
	_expect(_layer_center(canvas).distance_to(initial + Vector2(100, 40)) < 0.1, "%s held motion translates layer by the actual pointer delta" % kind)
	_release(grab + Vector2(100, 40))
	await process_frame
	_expect(not canvas._dragging_layer and not canvas._drawing, "%s release inside paper clears active pointer state" % kind)
	var placed: Array = canvas.stickers[0].position.duplicate()
	_motion(grab + Vector2(190, 110), false)
	await process_frame
	_expect(canvas.stickers[0].position == placed, "%s released layer does not stick to subsequent mouse movement" % kind)

	# Godot must route mouse-up back to the drag owner even beyond the paper.
	_press(_layer_center(canvas))
	await process_frame
	var outside: Vector2 = canvas.global_position + Vector2(-35, 60)
	_motion(outside, true)
	await process_frame
	_release(outside)
	await process_frame
	_expect(not canvas._dragging_layer and not canvas._drawing, "%s release outside paper always terminates the drag" % kind)
	placed = canvas.stickers[0].position.duplicate()
	_motion(canvas.global_position + canvas.size * Vector2(0.52, 0.54), false)
	await process_frame
	_expect(canvas.stickers[0].position == placed, "%s returning from outside with no mouse button cannot move the layer" % kind)
	await _move_layer_to_center(canvas)
	# A short OS drag can coalesce its last motion into the release event.
	var quick_start := _layer_center(canvas)
	_press(quick_start)
	await process_frame
	_release(quick_start+Vector2(90,-45))
	await process_frame
	_expect(_layer_center(canvas).distance_to(quick_start+Vector2(90,-45))<0.1,"%s release commits the final position without a motion event"%kind)
	await _move_layer_to_center(canvas)

	# Release over a real sibling tool button, where GUI interception used to be
	# a source of sticky drags. A release alone must not activate that tool.
	var star: Button = _button("星星")
	_expect(star != null, "%s sibling tool button is available for release routing" % kind)
	if star != null:
		_press(_layer_center(canvas))
		await process_frame
		_motion(star.get_global_rect().get_center(), true)
		await process_frame
		_release(star.get_global_rect().get_center())
		await process_frame
		_expect(not canvas._dragging_layer and not canvas._drawing, "%s release over another GUI button clears drag state" % kind)
		_expect(canvas.stickers.size() == 1, "%s release over a tool does not count as a separate tool click" % kind)
		placed = canvas.stickers[0].position.duplicate()
		_motion(canvas.global_position + canvas.size * Vector2(0.33, 0.61), false)
		await process_frame
		_expect(canvas.stickers[0].position == placed, "%s button-area release cannot leave a sticky layer" % kind)
		await _move_layer_to_center(canvas)

	await _click_tool("剪出形状", kind)
	_expect(canvas.mode == "cut", "%s real tool click enters cut mode" % kind)
	for offset in [Vector2(-25, -25), Vector2(25, -25), Vector2(25, 25), Vector2(-25, 25)]:
		await _click(_layer_center(canvas) + offset)
	_expect(canvas._cut_points.size() == 4, "%s routed paper clicks create four cut vertices" % kind)
	_expect(canvas.has_focus(), "%s paper owns keyboard focus after marking cut vertices" % kind)
	await _key(KEY_ENTER)
	_expect(game.modal.visible, "%s Enter completes a cut without leaving the editor" % kind)
	if not is_instance_valid(canvas) or not game.modal.visible:
		return
	_expect(canvas.stickers[0].get("mask", []).size() == 4 and canvas._cut_points.is_empty(), "%s Enter commits the polygon mask through GUI keyboard routing" % kind)
	_expect(canvas.mode == "select", "%s completed cut returns to material movement" % kind)
	var committed_mask: Array = canvas.stickers[0].get("mask", []).duplicate(true)

	await _click_tool("剪出形状", kind)
	for offset in [Vector2(-12, -12), Vector2(12, -12), Vector2(0, 12)]:
		await _click(_layer_center(canvas) + offset)
	_expect(canvas._cut_points.size() == 3, "%s second cut has an unfinished polygon before Escape" % kind)
	await _key(KEY_ESCAPE)
	_expect(game.modal.visible and game._modal_kind == ("recipe_editor" if kind == "recipe" else "poster"), "%s Escape cancels a cut without closing its parent modal" % kind)
	if not is_instance_valid(canvas) or not game.modal.visible:
		return
	_expect(canvas._cut_points.is_empty(), "%s Escape discards pending cut vertices" % kind)
	_expect(canvas.stickers[0].get("mask", []) == committed_mask, "%s cancelled cut preserves the previously committed shape" % kind)
	_expect(not game.world.controls_enabled and game.world._held == null, "%s cut keyboard shortcuts remain isolated from kitchen control" % kind)
	await _click_tool("移动素材", kind)
	_expect(canvas.mode == "select", "%s editing remains usable after cancelling a cut" % kind)
	game._close_modal()
	await process_frame
	_expect(game.world.controls_enabled, "%s closing its editor returns kitchen control" % kind)

func _move_layer_to_center(canvas) -> void:
	var center: Vector2 = _layer_center(canvas)
	# Edge-clamped layers still have a visible portion inside the paper to grab.
	var local: Vector2 = center - canvas.global_position
	local.x = clampf(local.x, 8, canvas.size.x - 8)
	local.y = clampf(local.y, 8, canvas.size.y - 8)
	var grab: Vector2 = canvas.global_position + local
	var destination: Vector2 = canvas.global_position + canvas.size * Vector2(0.5, 0.45)
	_press(grab)
	await process_frame
	_motion(destination + grab - center, true)
	await process_frame
	_release(destination + grab - center)
	await process_frame

func _layer_center(canvas) -> Vector2:
	var position: Array = canvas.stickers[0].position
	return canvas.global_position + Vector2(float(position[0]), float(position[1])) * canvas.size

func _button(text: String) -> Button:
	for child in game.modal_body.find_children("*", "Button", true, false):
		if child.text == text:
			return child as Button
	return null

func _click_tool(text: String, kind: String) -> void:
	var button := _button(text)
	_expect(button != null and not button.disabled, "%s tool is available: %s" % [kind, text])
	if button != null and not button.disabled:
		await _click(button.get_global_rect().get_center())

func _click(point: Vector2) -> void:
	_motion(point, false)
	await process_frame
	_press(point)
	await process_frame
	_release(point)
	await process_frame

func _press(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	previous_pointer = point
	Input.parse_input_event(event)

func _release(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = 0
	event.pressed = false
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	previous_pointer = point
	Input.parse_input_event(event)

func _motion(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	event.relative = event.position - (root.get_final_transform() * previous_pointer)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	previous_pointer = point
	Input.parse_input_event(event)

func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
