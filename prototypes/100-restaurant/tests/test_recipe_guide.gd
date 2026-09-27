extends SceneTree
const Method = preload("res://modules/restaurant/domain/recipe_method.gd")
var game
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")
func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://guide_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode()})
	root.add_child(game)
	await process_frame
	game.world.audio.muted = true
	game._view_recipe(Method.starter())
	await layout()
	check(game._recipe_stand.record == Method.starter(), "reference page equals the outside book")
	check(game.repository.load_recipes().is_empty(), "starter never becomes a fake player recipe or menu order")
	check_bounds("recipe spread")
	var preview = game.modal_body.find_child("SharedRecipePage", true, false)
	check(preview.texture == game._recipe_stand.viewport.get_texture(), "same actual texture inside and outside")
	await click(game.modal_body.find_child("FollowRecipe", true, false))
	check(game.recipe_guide.active and not game.modal.visible, "real follow button returns to an interactive kitchen")
	game._update_recipe_guide()
	check(game.recipe_guide.index == 0, "empty kitchen cannot complete any step")
	for i in range(20): game.recipe_guide.update(game._recipe_snapshot())
	check(game.recipe_guide.index == 0, "time and repeated observations cannot fake progress")
	check(game._guide_bar.position.y == 900 and game._guide_bar.size.y == 46, "guide stays entirely in the dedicated footer")
	game._take_ingredient(game._definition("tomato"))
	var whole = game.world._held
	whole.position = game.world.cutting_board.rect().get_center()
	game.world.drop_held(false)
	game._update_recipe_guide()
	check(game.recipe_guide.sequence[game.recipe_guide.index].kind == "cut", "taking actual tomato unlocks cut instruction")
	check(not game.recipe_guide.completed.get(1, false), "whole tomato is not a completed cut")
	var pieces: Array = game.world.split_food(whole, Vector2.RIGHT, Vector2.INF, 4)
	await process_frame
	game._update_recipe_guide()
	check(pieces.size() == 2 and game.recipe_guide.completed.get(1, false), "two real geometry fragments complete cutting")
	for fragment in pieces:
		game.world._pickup(fragment)
		game.world.drop_into_pan()
		await create_timer(0.4).timeout
	await create_timer(1.1).timeout
	check(game.session.dish.size() == 2, "both individually dropped fragments enroll")
	game._take_ingredient(game._definition("noodles"))
	game.world.drop_into_pan()
	await create_timer(0.8).timeout
	game._update_recipe_guide()
	check(game.recipe_guide.sequence[game.recipe_guide.index].kind == "water", "dry pan cannot advance water step")
	game.world.pan.water_ml = 250
	game.world.pan.water_heat = 100
	game.session.water_ml = 250
	game.session.water_heat = 100
	game.session.set_heating(true)
	game._update_recipe_guide()
	check(game.recipe_guide.sequence[game.recipe_guide.index].kind == "cook", "actual water and admitted food unlock heating")
	preload("res://tests/thermal_fixture.gd").cook(game,1.0)
	game._update_recipe_guide()
	check(game.recipe_guide.sequence[game.recipe_guide.index].kind == "cook", "one second cannot complete raw cooking")
	game.world.pan.water_ml=800.0
	game.world.pan.water_heat=100.0
	game.world.reactions.pan_c=120.0
	preload("res://tests/thermal_fixture.gd").cook(game,70.0)
	game.world.set_dish(game.session.dish, game.session.ingredients)
	game._update_recipe_guide()
	check(game.recipe_guide.sequence[game.recipe_guide.index].kind == "plate", "physical heat and finite noodle hydration complete cooking")
	var ids_before := []
	for food in game.world._foods.get_children(): ids_before.append(food.get_instance_id())
	game._interact("plate")
	game._plate_bodies(game.world._foods.get_children())
	game._update_recipe_guide()
	check(game.recipe_guide.sequence[game.recipe_guide.index].kind == "plate", "soup guide waits for broth to reach the serving bowl")
	var pan_before: float = game.world.pan.water_ml
	game._set_serving_vessel("bowl")
	var transferred: float = game._transfer_broth_to_bowl(250.0)
	check(is_equal_approx(transferred, 250.0) and is_equal_approx(game.world.pan.water_ml + transferred, pan_before), "serving broth transfers conserved water out of the pan")
	game._update_recipe_guide()
	check(game.recipe_guide.index == game.recipe_guide.sequence.size() and is_equal_approx(float(game.session.plate().get("water_ml", 0.0)), transferred), "plated food and actual bowl broth complete the guide and recipe snapshot")
	for food in game.world._foods.get_children(): check(food.get_instance_id() in ids_before, "guide never swaps or fabricates food")
	game._close_modal()
	game._interact("trash")
	game._update_recipe_guide()
	check(game.recipe_guide.index == 0, "clearing a failed dish restarts the same recipe")
	game._view_recipe({"id":"paper", "title":"手写的一页", "author":"主厨", "dish":{"ingredients":[]}})
	await layout()
	check(game.modal_body.find_child("FollowRecipe", true, false).disabled, "paper-only work has no fake follow action")
	game._show_cookbook()
	await layout()
	check_bounds("cookbook contents")
	var long_recipe := {"title":"番茄面和主厨亲手写下的那些关于夏日午餐的小故事".repeat(3).left(60), "author":"主厨", "notes":"很长的手记。".repeat(200), "dish":{"ingredients":[]}}
	for i in range(48): long_recipe.dish.ingredients.append({"id":"tomato", "cut":true, "heat":6})
	game._view_recipe(long_recipe)
	await layout()
	check_bounds("long title, 48 fragments and long notes")
	game._settle()
	await layout()
	check_bounds("receipt")
	var paid: Dictionary = game.session.end_shift().duplicate(true)
	game._view_recipe(Method.starter())
	await layout()
	check(game.modal_body.find_child("FollowRecipe", true, false).disabled, "closed shift can browse but cannot start a phantom kitchen")
	game._close_modal()
	check(game._modal_kind == "result" and game.session.end_shift() == paid, "closing post-shift book restores receipt without paying again")
	test_edge_cases()
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: recipe guide, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func test_edge_cases() -> void:
	var target := {"id":"chicken", "cut":true, "heat":6.0, "mass_kg":0.2, "softness":0.0}
	var piece := {"id":"chicken", "cut":true, "heat":6.0, "mass_kg":0.01, "enrolled":true, "plated":true}
	check(not Method.enough([piece], target, "plate"), "one crumb cannot satisfy a 200 g recipe")
	piece.mass_kg = 0.18
	check(Method.enough([piece], target, "plate"), "reasonable quantity tolerance supports re-cooking")
	piece.heat = 5.9
	check(not Method.enough([piece], target, "plate"), "still-raw food cannot satisfy cooked reference")
	piece.heat = 22
	check(not Method.enough([piece], target, "plate"), "burnt version cannot masquerade as successful normal recipe")
	target.heat = 20
	check(Method.enough([piece], target, "plate"), "deliberately burnt reference retains its own target")
	piece.id = "tomato"
	check(not Method.enough([piece], target, "plate"), "wrong ingredient is not accepted by renamed text")
	var noodle := {"id":"noodles", "heat":7.0, "enrolled":true, "softness":0.0}
	var goal := {"id":"noodles", "heat":6.0, "softness":0.8}
	check(not Method.enough([noodle], goal, "cook"), "heated but dry noodles are not soft noodles")
	noodle.softness = 0.9
	check(Method.enough([noodle], goal, "cook"), "actual absorbed water enables noodle target")
	var recipe := {"dish":{"ingredients":[{"id":"tomato", "heat":8, "cut":true, "mass_kg":0.1}, {"id":"tomato", "heat":8, "cut":true, "mass_kg":0.1}]}}
	var backup: Dictionary = recipe.duplicate(true)
	check(Method.targets(recipe).size() == 1 and is_equal_approx(Method.targets(recipe)[0].mass_kg, 0.2), "recipe consolidates fragments by type and sums actual mass")
	Method.steps(recipe, game.session.ingredients)
	check(recipe == backup, "reading old recipes does not overwrite their provenance or shapes")
	var source_recipe := {"dish":{"ingredients":[{"id":"tomato", "mass_kg":0.16}, {"id":"ketchup", "volume_ml":15}]}}
	var source_steps: Array = Method.steps(source_recipe, game.session.ingredients)
	check("食材柜" in str(source_steps[0].detail), "fresh produce recipe directs players to its real cabinet")
	check("调料架" in str(source_steps[1].detail), "sauce recipe names its physical rack")
	var sauce_recipe := {"dish":{"ingredients":[{"id":"ketchup", "volume_ml":15, "heat":6}, {"id":"ketchup", "amount_ml":5, "garnish":true}]}}
	var sauce_targets := Method.targets(sauce_recipe)
	check(sauce_targets.size() == 2, "the same sauce in pan and on plate remains two separate operations")
	check(Method.satisfied({"kind":"garnish", "target":sauce_targets[1]}, {"garnishes":[{"id":"ketchup", "amount_ml":4}]}, sauce_targets), "actual plated sauce quantity completes garnish operation")

func layout() -> void:
	await process_frame
	await process_frame
func click(button: Button) -> void:
	check(button != null, "click target exists")
	if button == null: return
	var point: Vector2 = root.get_final_transform() * button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
func check_bounds(context: String) -> void:
	var bounds: Rect2 = game.modal_panel.get_global_rect()
	if bounds.end.x > 1600 or bounds.end.y > 900: print(context, " BOUNDS ", bounds)
	check(bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= 1600 and bounds.end.y <= 900, context + " leaves footer and canvas clear")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
