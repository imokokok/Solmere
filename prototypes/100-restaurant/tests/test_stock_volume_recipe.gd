extends SceneTree
var game
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")
func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://stock_volume_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode()})
	root.add_child(game)
	await process_frame
	game._close_modal()
	game.world.audio.muted = true
	var world = game.world
	var tomato: Button = game.storage_display.find_child("Ingredient_tomato", true, false)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = tomato.size * 0.5
	tomato.gui_input.emit(press)
	var original: RigidBody2D = world._held
	expect(is_instance_valid(original), "visible food can be picked up")
	expect(tomato.disabled and not tomato.get_node("FoodArt").visible, "taking the only tomato leaves an empty slot")
	world._held.position = Vector2(1110, 735)
	world.drop_held()
	game._take_ingredient(game._definition("tomato"))
	expect(not is_instance_valid(world._held) and world._foods.get_child_count() == 1, "catalog cannot duplicate an already taken item")
	game._show_pantry()
	var unavailable := false
	for b in game._pantry_grid.get_children():
		if b.text.split("\n")[0] == "番茄": unavailable = b.disabled and b.text.contains("已取走")
	expect(unavailable, "pantry exposes the same depleted inventory")
	game._close_modal()
	world._pickup(original)
	world.begin_food_drag(original.position)
	world._move_dragged_food(tomato.get_global_rect().get_center())
	await create_timer(0.9).timeout
	world._finish_food_drag()
	expect(not is_instance_valid(world._held) and not tomato.disabled, "dragging unprocessed food home restores its slot")
	game._take_ingredient(game._definition("tomato"))
	expect(world._held == original, "taking it again uses the identical physical entity")
	world.discard_held()
	await process_frame
	game._take_ingredient(game._definition("oil"))
	var bottle: RigidBody2D = world._held
	bottle.set_meta("remaining_ml", 57.25)
	var oil: Button = game.storage_display.find_child("Ingredient_oil", true, false)
	world.begin_food_drag(bottle.position)
	world._move_dragged_food(oil.get_global_rect().get_center())
	await create_timer(0.9).timeout
	world._finish_food_drag()
	game._take_ingredient(game._definition("oil"))
	expect(world._held == bottle and is_equal_approx(float(bottle.get_meta("remaining_ml")), 57.25), "returned bottle retains identity and remaining liquid")
	world.discard_held()
	await process_frame
	expect(game._definition("rice").is_empty() and not game._stock.has("rice"), "removed rice has no inventory definition")
	expect(game.storage_display.find_child("Ingredient_rice", true, false) == null and game._pantry_grid.find_child("Pantry_rice", true, false) == null, "removed rice has no shelf or pantry slot")
	expect(game.hud.get_node_or_null("RiceCooker") == null, "no countertop rice cooker is created")
	for id in ["ketchup", "mayonnaise", "mustard", "chili_sauce", "vinegar"]:
		var slot: Button = game.storage_display.find_child("Ingredient_" + id, true, false)
		expect(slot.position.x >= 640 and slot.position.x < 1080 and not world.get_dispense_mode(game._definition(id)).is_empty(), "back tray contains an actual seasoning container: " + id)
	world.set_process(false)
	game.set_process(false)
	world.spawn_ingredient(game._definition("ketchup"))
	world._held.position = world.pan.point(Vector2(810, 500))
	var capacity: float = world._held.get_meta("remaining_ml")
	for i in range(2): world._dispense_seasoning(5)
	expect(_spill_ml() == 0.0 and is_equal_approx(world.pan_contents_ml(), 10.0), "two small squeezes remain inside an empty pan")
	expect(is_equal_approx(capacity - float(world._held.get_meta("remaining_ml")), 10.0), "squeezed quantity is deducted from the bottle")
	world.pan.water_ml = 1485
	world._dispense_seasoning(12)
	expect(is_equal_approx(world.pan_contents_ml(), 1500.0), "partial pour fills only the remaining five ml")
	expect(is_equal_approx(_spill_ml(), 7.0), "only the seven ml above the rim spill")
	expect(is_equal_approx(capacity - float(world._held.get_meta("remaining_ml")), 22.0), "pan and spill conserve bottle output")
	world.discard_held()
	world.clear_food()
	game.session.clear_dish()
	await process_frame
	world.spawn_ingredient(game._definition("chicken"))
	var meat: RigidBody2D = world._held
	world.drop_into_pan()
	world.accept_food(meat, true)
	var before: float = world.pan_contents_ml()
	var mass: float = meat.mass
	meat.set_meta("enrolled", false)
	meat.position = world.cutting_board.rect().get_center()
	meat.freeze = true
	var parts: Array = world.split_food(meat, Vector2.RIGHT, Vector2.INF, 8)
	for part in parts: part.set_meta("enrolled", true)
	expect(parts.size() == 2 and is_equal_approx(before, world.pan_contents_ml()), "cutting increases piece count without increasing displacement")
	expect(is_equal_approx(mass, parts[0].mass + parts[1].mass), "slice mass is conserved")
	game._show_cookbook()
	var preview: TextureRect = game.modal_body.find_child("SharedRecipePage", true, false)
	expect(preview.texture == game._recipe_stand.viewport.get_texture(), "opened cookbook retains a live page renderer without a counter stand")
	var record := {"title":"今天的手记", "author":"主厨", "notes":"番茄慢慢炒。", "dish":{"ingredients":[{"id":"tomato","heat":8.0,"cut":true}]}}
	expect(game.repository.save_recipe(record), "sample real recipe saves")
	var stored: Dictionary = game.repository.load_recipes()[0]
	game._view_recipe(stored)
	preview = game.modal_body.find_child("SharedRecipePage", true, false)
	expect(game._recipe_stand.record == stored and preview.texture == game._recipe_stand.viewport.get_texture(), "selected recipe stays identical outside and inside")
	game._show_cookbook()
	expect(game._recipe_stand.record == stored, "reopening does not revert to unrelated decorative dishes")
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: stock, pan volume and shared recipe, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
func _spill_ml() -> float:
	var amount := 0.0
	for body in game.world._foods.get_children():
		if body.get_meta("overflow", false): amount += float(body.get_meta("volume_ml", 0.0))
	return amount
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
