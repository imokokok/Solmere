extends SceneTree
## Exercise the player-facing page controls and finite stock across rebuilds.
var game
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")

func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://shelf_pages_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode()})
	root.add_child(game)
	await process_frame
	game._close_modal()
	game.world.audio.muted = true
	var shelf = game.storage_display
	expect(shelf.find_child("FridgeNextPage", true, false) == null and shelf.find_child("FridgeScrollDown", true, false) == null, "fridge has no page or stacked arrow buttons")
	var tomato := shelf.find_child("Ingredient_tomato", true, false) as Button
	expect(shelf.slot_at("tomato", tomato.get_global_rect().get_center()), "tomato is visible at the near side")
	var pull := shelf.find_child("FridgePull", true, false) as Control
	var first_point := pull.get_global_rect().get_center()
	mouse(first_point, "down")
	await process_frame
	mouse(first_point - Vector2(110, 0), "move")
	await create_timer(0.5).timeout
	mouse(first_point - Vector2(110, 0), "up")
	await process_frame
	expect(shelf.fridge_offset > 200, "dragging the cabinet pull continuously reveals the next interior section")
	expect(not shelf.slot_at("tomato", tomato.get_global_rect().get_center()), "clipped stock cannot accept off-cabinet returns")
	var found: Array[String] = []
	for def in shelf._cold_catalog:
		shelf.reveal_ingredient(str(def.id))
		var slot := shelf.find_child("Ingredient_" + str(def.id), true, false) as Button
		expect(slot != null and shelf.slot_at(str(def.id), slot.get_global_rect().get_center()), str(def.id) + " has a reachable physical slot")
		expect(not found.has(str(def.id)), str(def.id) + " occurs once")
		found.append(str(def.id))
	shelf.reveal_ingredient("tomato")
	game._take_ingredient(game._definition("tomato"))
	var original = game.world._held
	game.world._dragging = false
	shelf.reveal_ingredient("bell_pepper_orange")
	shelf.reveal_ingredient("tomato")
	expect(tomato.disabled and not tomato.get_node("FoodArt").visible, "sliding cabinet does not refill stock")
	original.position = tomato.get_global_rect().get_center()
	game.world.held_grip.target = original.global_position
	expect(game._return_to_storage(original), "same tomato returns to the exposed slot")
	for page in ceili(shelf._odd_catalog.size() / 12.0):
		var next := shelf.find_child("OddNextPage", true, false) as Button
		expect(next != null, "odd shelf has accessible layers")
		next.pressed.emit()
	expect(shelf.odd_page == 0, "odd shelf layers return to first")

	game._take_ingredient(game._definition("sock"))
	var body: RigidBody2D = game.world._held
	var identity: String = body.get_meta("instance_uid")
	game.world._dragging = false
	shelf.find_child("OddNextPage", true, false).pressed.emit()
	expect(not shelf.slot_at("sock", Vector2(1357, 257)), "an offscreen sock slot cannot accept a return")
	shelf.find_child("OddPreviousPage", true, false).pressed.emit()
	var slot := shelf.find_child("Ingredient_sock", true, false) as Button
	expect(slot.disabled and not slot.get_node("FoodArt").visible, "changing pages does not refill an emptied slot")
	game._take_ingredient(game._definition("sock"))
	expect(game.world._held == body and game.world._foods.get_child_count() == 1, "repeated take cannot create a second sock")
	body.position = slot.get_global_rect().get_center()
	game.world.held_grip.target = body.global_position
	expect(game._return_to_storage(body), "original sock can return after page navigation")
	game._pantry_category = "odd"
	game._show_pantry()
	await capture("cupboard")
	var pantry_slot := game._pantry_grid.find_child("Pantry_sock", true, false) as Button
	expect(pantry_slot != null and pantry_slot.get_node("FoodArt").definition.id == "sock", "cupboard uses the same authored sock thumbnail")
	pantry_slot.pressed.emit()
	expect(game.world._held == body and body.get_meta("instance_uid") == identity, "cupboard reuses returned shelf entity")
	expect(not game.modal.visible, "cupboard selection returns to gameplay")
	game.world.discard_held()
	await process_frame
	# A cupboard selection on another layer reveals its physical return slot.
	game._pantry_category = "all"
	game._show_pantry()
	game._pantry_grid.find_child("Pantry_sponge", true, false).pressed.emit()
	expect(shelf.odd_page > 0 and shelf.find_child("Ingredient_sponge", true, false) != null, "cupboard selection reveals the matching shelf layer")
	await capture("shelf-layer")
	for id in ["sock", "confetti", "toilet_paper", "soap", "soap_smooth", "toothpaste"]:
		var def: Dictionary = game._definition(id)
		expect(def.category == "odd" and "non_food" in def.tags, id + " remains a non-food strange ingredient")
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: paged shelves and shared finite stock, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func capture(label: String) -> void:
	if OS.get_cmdline_user_args().is_empty() or DisplayServer.get_name() == "headless": return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "-" + label + ".png") == OK, "GPU " + label)

func mouse(point: Vector2, kind: String) -> void:
	point = root.get_final_transform() * point
	if kind == "move":
		var event := InputEventMouseMotion.new()
		event.position = point
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
	else:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = kind == "down"
		Input.parse_input_event(event)
