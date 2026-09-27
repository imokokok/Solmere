extends SceneTree
## Headless integration test for the embeddable scene, UI pause and 2D physics.
## Godot --headless --path <project> --script res://tests/test_integration.gd

var game
var failures: Array = []
var checks: int = 0
var settlements: Array = []
var publications: Array = []
var original_mouse_mode: int

func _initialize() -> void:
	Engine.max_fps = 120
	root.size = Vector2i(1600, 900)
	call_deferred("_run")

func _run() -> void:
	original_mouse_mode = Input.mouse_mode
	var packed = load("res://modules/restaurant/restaurant.tscn")
	if packed == null:
		_expect(false, "restaurant scene loads")
		_finish()
		return
	game = packed.instantiate()
	game.configure({"shift_seconds": 30.0, "player_id": "integration_player", "display_name": "集成测试主厨", "repository_path": "user://integration_%s/cookbook.json" % Crypto.new().generate_random_bytes(16).hex_encode()})
	game.shift_completed.connect(func(result: Dictionary): settlements.append(result))
	game.recipe_published.connect(func(record: Dictionary): publications.append(record))
	root.add_child(game)
	await process_frame
	await process_frame
	_expect(game is Node2D, "embeddable minigame is a 2D scene")
	_expect(game.session.duration == 30.0, "host configured duration reaches domain")
	# The full physics and UI fixture can now outlast a 30-second service window.
	game.session.duration = 240.0
	_expect(game.modal.visible and game._modal_kind == "intro", "intro appears before service")
	_expect(not game.world.controls_enabled, "intro disables world interaction")
	_expect(game.session.phase == "prep", "opening intro does not start service")
	_check_modal_bounds("intro")
	game._start_shift()
	await process_frame
	_expect(game.session.phase == "service" and not game.modal.visible, "start button starts service and closes intro")
	_expect(game.world.controls_enabled, "start restores world control")
	_expect(not game.session.current_customer.is_empty(), "first scheduled customer appears")
	game._show_pause()
	var paused_at: float = game.session.elapsed
	var waiting_at_pause: float = game.session.customer_wait
	await create_timer(0.08).timeout
	_expect(is_equal_approx(game.session.elapsed, paused_at), "pause modal freezes module clock")
	_expect(is_equal_approx(game.session.customer_wait, waiting_at_pause), "pause modal freezes customer patience")
	_expect(not paused, "module pause does not pause host SceneTree")
	_expect(not game.world.controls_enabled, "pause disables world interaction")
	game._close_modal()
	await create_timer(0.08).timeout
	_expect(game.session.elapsed > paused_at, "closing modal resumes module clock")
	_expect(game.session.customer_wait < waiting_at_pause, "closing modal resumes customer patience countdown")
	_expect(game.world.controls_enabled, "closing modal restores world interaction")
	await _test_visible_storage()
	await _test_modals()
	await _test_physics_and_service()
	await _test_condiment_container()
	game._settle()
	await process_frame
	_expect(settlements.size() == 1, "scene emits one settlement")
	_expect(game.modal.visible and game._modal_kind == "result", "settlement opens result screen")
	_expect(not game.world.controls_enabled, "settlement prevents kitchen input")
	_check_modal_bounds("result")
	if not settlements.is_empty():
		var result: Dictionary = settlements[0]
		_expect(str(result.get("player_id", "")) == "integration_player", "settlement preserves host player id")
		_expect(not str(result.get("session_id", "")).is_empty(), "settlement supplies idempotency session id")
		_expect(is_equal_approx(float(result.get("share", -1.0)), snappedf(float(result.get("revenue", 0.0)) * 0.30, 0.01)), "scene pays agreed thirty percent share")
	game._settle(false)
	game._request_exit()
	await process_frame
	_expect(settlements.size() == 1, "repeat settle and exit cannot pay twice")
	game.world.audio.muted = true
	await create_timer(0.14).timeout
	game.queue_free()
	await process_frame
	_expect(Input.mouse_mode == original_mouse_mode, "unmount restores host mouse mode")
	_finish()

func _test_visible_storage() -> void:
	var storage
	for child in game.hud.get_children():
		if child.get_script() != null and str(child.get_script().resource_path).ends_with("/storage_display.gd"):
			storage = child
			break
	_expect(storage != null, "kitchen embeds visible fridge, shelves and baskets")
	if storage == null:
		return
	var buttons: Array[Node] = storage.find_children("Ingredient_*", "Button", true, false)
	var unique: Dictionary = {}
	var visible_count: int = 0
	for button in buttons:
		unique[str(button.get_meta("ingredient_id", ""))] = true
		if button.is_visible_in_tree():
			visible_count += 1
	_expect(unique.size() == 37 and visible_count == 37, "reference layout exposes 15 visible fridge, 5 prep tray, 5 condiment rack and 12 special shelf items")
	_expect(storage.definitions.size()==game.session.active_ingredients().size(),"storage exposes every allowed ingredient definition")
	var tomato_button = storage.find_child("Ingredient_tomato", true, false)
	if tomato_button == null:
		_expect(false, "tomato model is directly selectable in storage")
		return
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = tomato_button.size * 0.5
	tomato_button.gui_input.emit(press)
	_expect(is_instance_valid(game.world._held) and str(game.world._held.get_meta("id", "")) == "tomato", "clicking a displayed ingredient gives its matching physical body")
	game.world.discard_held()
	await process_frame

func _test_modals() -> void:
	game._show_pantry()
	await process_frame
	await process_frame
	_expect(game._pantry_grid.get_child_count() == game.session.active_ingredients().size(), "pantry shows every available ingredient without removed rice")
	_check_modal_bounds("pantry")
	game._pantry_category = "odd"
	game._refresh_pantry()
	var expected_odd_names: Array = []
	for item in game.session.active_ingredients():
		if item.category == "odd": expected_odd_names.append(str(item.name))
	var displayed_names: Array = []
	for button in game._pantry_grid.get_children(): displayed_names.append(str(button.text).split("\n")[0])
	expected_odd_names.sort()
	displayed_names.sort()
	_expect(displayed_names == expected_odd_names, "pantry category shows every odd ingredient and no unrelated food")
	game._pantry_search = "袜子"
	game._refresh_pantry()
	_expect(game._pantry_grid.get_child_count() == 1, "Chinese ingredient search works")
	game._pantry_category = "all"
	game._pantry_search = ""
	game._show_cookbook()
	await process_frame
	await process_frame
	_check_modal_bounds("empty cookbook")
	await _check_authoring_pause("cookbook")
	game._show_help()
	await process_frame
	await process_frame
	_check_modal_bounds("help")
	game._show_poster()
	await process_frame
	await process_frame
	_check_modal_bounds("poster")
	_expect(game._poster_canvas.size.x >= 600.0, "poster drawing canvas preserves host-requested usable width")
	_expect(not game._poster_canvas.has_content(), "first poster opens on a genuinely blank sheet")
	_expect(_used_ingredient_ids().is_empty(), "poster does not invent ingredients before any meal exists")
	await _check_authoring_pause("blank poster")
	_press_button("星星")
	_expect(game._poster_canvas.has_content(), "poster receives decoration only after explicit user action")
	var published_paper: Dictionary = game._poster_canvas.export_data()
	game._publish_poster(["sweet", "dairy"])
	_expect(game.session.poster_bonus and not game.modal.visible, "poster publishing reaches domain and returns to kitchen")
	var reloaded_store = load("res://modules/restaurant/ui/poster_store.gd").new(game.poster_store.storage_path)
	_expect(reloaded_store.load_poster().get("tags", []) == ["sweet", "dairy"], "published poster recruitment tags survive a fresh store reload")
	game._show_poster()
	await process_frame
	_expect(not game._poster_canvas.has_content(), "reopening poster does not automatically fill paper from a saved poster")
	var continue_button = _find_button("继续编辑已贴出的海报")
	_expect(continue_button != null and not continue_button.disabled, "saved poster is available through an explicit continue-editing action")
	_press_button("继续编辑已贴出的海报")
	_expect(game._poster_canvas.export_data() == published_paper, "explicit continue-editing restores the published paper layout")
	game._close_modal()

func _test_physics_and_service() -> void:
	var definition: Dictionary = game._definition("egg")
	_expect(game.world.spawn_ingredient(definition), "world spawns a physical ingredient")
	await physics_frame
	var bodies: Array[Node] = game.world.find_children("*", "RigidBody2D", true, false)
	if bodies.is_empty():
		_expect(false, "spawn creates RigidBody2D")
		return
	var body: RigidBody2D = game.world._held
	_expect(is_equal_approx(body.mass, float(definition["mass"])), "rigid body receives ingredient-specific mass")
	# Real physics body travels into the pan; no direct domain add is used.
	game.world.chop_held()
	var pieces: Array=game.world.split_food(body,Vector2.RIGHT,Vector2.INF,4)
	_expect(pieces.size()==2,"inline knife geometry produces actual pieces")
	body=pieces[0]
	game.world._pickup(body)
	game.world.drop_into_pan()
	for frame in range(90):
		await physics_frame
		if not game.session.dish.is_empty():
			break
	_expect(game.session.dish.size() == 1, "physical pan entry creates exactly one authoritative ingredient")
	if game.session.dish.is_empty():
		return
	_expect(str(game.session.dish[0].get("id", "")) == "egg", "pan signal preserves ingredient identity")
	_expect(int(game.session.dish[0].get("physics_id", 0)) == body.get_instance_id(), "dish links to physical body identity")
	game._show_pause()
	var resting_position: Vector2 = body.global_position
	await create_timer(0.05).timeout
	_expect(body.freeze and body.global_position.is_equal_approx(resting_position), "pause freezes loose ingredient physics")
	game._close_modal()
	game._interact("talk")
	for frame in 150:
		if game.world.pan.local_point(body.position).y >= 575.0: break
		await physics_frame
	game._interact("cook")
	preload("res://tests/thermal_fixture.gd").cook(game, 80.0)
	game._interact("cook")
	_expect(bool(game.session.dish[0].get("cut", false)), "cutting state survives physical integration")
	_expect(float(game.session.dish[0].get("heat", 0.0)) >= 8.0 and not game.session.heating, "stove interaction applies per-ingredient heat and turns off")
	await _test_current_dish_poster()
	game.world._pickup(body)
	_expect(game.session.dish.is_empty() and game._food_by_physics.is_empty(), "picking cooked food out removes it from the authoritative pan")
	_expect(float(body.get_meta("saved_heat", 0.0)) >= 8.0, "removed body retains cooking history")
	await physics_frame
	game.world.drop_into_pan()
	for frame in range(90):
		await physics_frame
		if not game.session.dish.is_empty():
			break
	_expect(game.session.dish.size() == 1, "returning the cooked body creates no duplicate ingredient")
	if not game.session.dish.is_empty():
		_expect(float(game.session.dish[0].get("heat", 0.0)) >= 8.0 and bool(game.session.dish[0].get("cut", false)), "returning to pan preserves heat and cut state")
	game._interact("plate")
	_expect(game._modal_kind == "plating", "plating opens a magnified workspace")
	game._plating_canvas.add_to_plate(body)
	game._show_recipe_editor()
	_expect(game.world.plated and game._modal_kind == "recipe_editor", "chosen plate food can be used in DIY recipe")
	_expect(not game._recipe_canvas.has_content(), "plating offers blank recipe paper without auto-stamping food")
	_expect(_used_ingredient_ids() == ["egg"], "plated recipe materials list only its actual egg")
	_expect(body.freeze and bool(body.get_meta("plated", false)), "plated body remains stationary and explicitly marked")
	game._close_modal()
	game.world.return_to_pan()
	_expect(not game.world.plated and game.session.dish.is_empty(), "reheating transfer unenrolls plated food until actual landing")
	for frame in range(90):
		await physics_frame
		if not game.session.dish.is_empty():
			break
	_expect(game.session.dish.size() == 1, "reheat transfer reenrolls one physical ingredient")
	if game.session.dish.is_empty():
		print("Reheat diagnostic: position=%s freeze=%s sleeping=%s velocity=%s layer=%s enrolled=%s pending=%s held=%s overlapping=%s" % [body.global_position, body.freeze, body.sleeping, body.linear_velocity, body.collision_layer, body.get_meta("enrolled", false), body.get_meta("pending", false), game.world._held == body, game.world._pan_area.get_overlapping_bodies().has(body)])
	if not game.session.dish.is_empty():
		_expect(float(game.session.dish[0].get("heat", 0.0)) >= 8.0 and bool(game.session.dish[0].get("cut", false)), "reheat transfer preserves cooked and cut history")
	var served_before_plate: int = game.session.served
	game._serve()
	_expect(game.session.served == served_before_plate and not game.session.dish.is_empty(), "serve refuses a real meal that has not entered the plate")
	game._interact("plate")
	game._plating_canvas.add_to_plate(body)
	game._close_modal()
	var letters_before: int = game._letters.size()
	await game._serve()
	await process_frame
	var served_result: Dictionary = game._pending_serve_result.duplicate(true)
	_expect(game.session.served == 1 and int(served_result.get("score", -1)) >= 0 and not str(served_result.get("customer", "")).is_empty(), "physical dish can be served and rated even when a guest dislikes it")
	_expect(game.session.dish.is_empty(), "serving consumes domain dish")
	_expect(game.modal.visible and game._modal_kind == "dish_showcase", "serving presents the actual plated dish first")
	_expect(game.modal_body.find_child("FinishedDishShowcase", true, false) != null, "showcase renders the current physical plate")
	game._show_serve_feedback()
	_expect(game._letters.size() == mini(40, letters_before + 1) and str(game._letters[-1].get("customer", "")) == str(served_result.get("customer", "")) and int(game._letters[-1].get("score", -1)) == int(served_result.get("score", -2)), "opening feedback records this guest's actual rating")
	_expect(game._food_by_physics.is_empty(), "leaving the showcase clears physical identity registry")
	_expect(game.modal.visible and game._modal_kind == "feedback", "continuing opens customer feedback")
	_expect(not game._last_dish.is_empty(), "served dish remains available for recipe publishing")
	await _test_recipe_collage()

func _test_current_dish_poster() -> void:
	# Deliberately distinguish the current physical meal from the last-meal record.
	var previous_last: Dictionary = game._last_dish.duplicate(true)
	game._last_dish = {"ingredients": [{"id": "grapes", "cut": false, "heat": 0.0}]}
	var live_dish: Array = game.session.dish.duplicate(true)
	game._show_poster()
	await process_frame
	await process_frame
	_expect(not game._poster_canvas.has_content(), "poster remains blank even with both live ingredients and a previously saved poster")
	_expect(_used_ingredient_ids() == ["egg"], "poster material strip prefers current dish over a different last dish")
	var material = game.modal_body.find_child("UsedIngredient_egg", true, false)
	_expect(material != null, "actual egg appears as an explicit poster material button")
	if material != null:
		material.emit_signal("pressed")
	var layer: Dictionary = _first_collage_layer(game._poster_canvas, "ingredient")
	_expect(layer.get("id", "") == "egg" and bool(layer.get("cut", false)) and float(layer.get("heat", 0.0)) >= 8.0, "poster ingredient art preserves the actual cooked and cut state")
	_expect(game.session.dish == live_dish, "adding food art to poster does not mutate the physical meal")
	await _check_authoring_pause("poster with current dish")
	game._close_modal()
	game._last_dish = previous_last

func _test_recipe_collage() -> void:
	# A new recipe uses the current physical meal; the served meal remains intact
	# as the fallback snapshot for a later entry with an empty pan.
	game._close_modal()
	_expect(game.world.spawn_ingredient(game._definition("tomato")), "a new meal can coexist with the last served recipe")
	game.world.drop_into_pan()
	for frame in range(90):
		await physics_frame
		if not game.session.dish.is_empty():
			break
	_expect(_dish_ids({"ingredients": game.session.dish}) == ["tomato"], "next physical meal is distinct from the last served egg")
	var live_dish: Array = game.session.dish.duplicate(true)
	var last_dish: Dictionary = game._last_dish.duplicate(true)
	# A cached photograph must remain outside a fresh sheet until explicitly added.
	var cached_photo: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	cached_photo.fill(Color("817359"))
	game._photo = Marshalls.raw_to_base64(cached_photo.save_png_to_buffer())
	game._show_recipe_editor()
	await process_frame
	await process_frame
	_check_modal_bounds("recipe editor")
	_expect(not game._recipe_canvas.has_content(), "recipe opens blank even when food state and a photograph are available")
	_expect(_used_ingredient_ids() == ["tomato"], "new recipe material strip prioritizes the current tomato over the last served egg")
	game._title_input.text = "集成测试番茄"
	game._notes_input.text = "记录当前锅中的番茄，再自由排版。"
	_expect(not game._recipe_canvas.has_content(), "title and notes remain distinct from freely positioned collage layers")
	var ingredient_button = game.modal_body.find_child("UsedIngredient_tomato", true, false)
	_expect(ingredient_button != null, "current-meal ingredient is offered as a recipe collage material")
	if ingredient_button != null:
		ingredient_button.emit_signal("pressed")
		ingredient_button.emit_signal("pressed")
	_expect(_collage_layer_count(game._recipe_canvas, "ingredient") == 2, "recipe material can be reused as two independent collage layers")
	_expect(game.session.dish == live_dish and game._last_dish == last_dish, "recipe collage editing changes neither the live meal nor the saved cooking snapshot")
	_press_button("纸上写字")
	game._recipe_canvas.begin_text(Vector2(390,220))
	game._recipe_canvas._text_editor.insert_text_at_caret(game._title_input.text)
	game._recipe_canvas.finish_text()
	_expect(_collage_layer_count(game._recipe_canvas, "text") == 1, "native paper writing creates one freely positioned text layer")
	var before_transform: Dictionary = _first_collage_layer(game._recipe_canvas, "text")
	game._recipe_canvas.rotate_selected(PI/12)
	game._recipe_canvas.resize_selected(1.12)
	var after_transform: Dictionary = _first_collage_layer(game._recipe_canvas, "text")
	_expect(float(after_transform.get("rotation", 0.0)) > float(before_transform.get("rotation", 0.0)), "recipe rotation tool updates the selected collage layer")
	_expect(float(after_transform.get("scale", 0.0)) > float(before_transform.get("scale", 0.0)), "recipe resize tool updates the selected collage layer")
	await _check_authoring_pause("recipe collage")
	var expected_paper: Dictionary = game._recipe_canvas.export_data()
	game._save_recipe()
	_expect(publications.size() == 1, "saving recipe emits publication")
	if not publications.is_empty():
		var published: Dictionary = publications[0]
		_expect(not str(published.get("id", "")).is_empty(), "publication contains persistent recipe id")
		_expect(not str(published.get("created_at", "")).is_empty(), "publication contains canonical creation metadata")
		_expect(not published.get("dish", {}).get("ingredients", [{}])[0].has("physics_id"), "saved recipe has no transient physics id")
		_expect(_dish_ids(published.get("dish", {})) == ["tomato"], "published recipe records one current tomato rather than collage duplicates or the previous egg")
		_expect(published.get("poster", {}) == expected_paper, "publication preserves the authored collage layout and transforms")
		var fresh_repository = load("res://modules/restaurant/storage/recipe_repository.gd").new(game.repository.storage_path)
		var saved: Array = fresh_repository.load_recipes()
		_expect(saved.size() == 1 and _same_json_value(saved[0].get("poster", {}), expected_paper), "recipe collage survives a fresh repository reload")
		game._view_recipe(saved[0] if not saved.is_empty() else published)
		await process_frame
		await process_frame
		_check_modal_bounds("published recipe view")
		var displayed = game._recipe_stand.page._collage
		_expect(displayed != null, "published recipe renders its saved layout using the paper canvas")
		if displayed != null:
			_expect(not displayed.editable and displayed.mouse_filter == Control.MOUSE_FILTER_IGNORE, "published layout is displayed as a read-only canvas")
			_expect(_same_json_value(displayed.export_data(), expected_paper), "displayed recipe layout matches the canonical publication")
			_expect(displayed._layer_nodes.size() == expected_paper.get("stickers", []).size(), "every saved collage layer has a rendered scene node")
	game._close_modal()
	game._interact("trash")
	await process_frame
	game._show_poster()
	await process_frame
	_expect(not game._poster_canvas.has_content(), "new poster is blank after a recipe was published")
	_expect(_used_ingredient_ids() == ["egg"], "poster falls back to the last served dish when the physical pan is empty")
	game._close_modal()
	game._show_recipe_editor()
	await process_frame
	_expect(not game._recipe_canvas.has_content(), "reopening recipe authoring starts a new blank sheet instead of auto-loading the prior collage")
	game._close_modal()

func _test_condiment_container() -> void:
	_expect(game.world.spawn_ingredient(game._definition("ketchup")), "condiment bottle can be taken from pantry")
	var bottle: RigidBody2D = game.world._held
	if not is_instance_valid(bottle):
		_expect(false, "condiment bottle remains a held physical object")
		return
	_expect(bool(bottle.get_meta("is_container", false)), "ketchup bottle is marked as a container")
	game.world._on_pan_entered(bottle)
	_expect(game.session.dish.is_empty(), "bottle itself cannot become an ingredient")
	bottle.global_position = game.world.pan.point(Vector2(809,520))
	game.world._dispense_ketchup()
	var portions: Array = []
	for child in game.world._foods.get_children():
		if bool(child.get_meta("dispensed", false)):
			portions.append(child)
	_expect(portions.size() == 1, "dispensing creates one separate sauce portion")
	if not portions.is_empty():
		var liquid_state: Dictionary = portions[0].get_meta("liquid_state", {})
		var definition: Dictionary = portions[0].get_meta("definition", {})
		var expected_mass := float(liquid_state.get("volume_ml", 0.0)) * float(definition.get("density_g_ml", 1.03)) / 1000.0
		_expect(is_equal_approx(portions[0].mass, expected_mass), "sauce portion mass derives from its measured volume and density")
	_expect(game.world._held == bottle and is_instance_valid(bottle), "dispensing keeps the bottle available")
	for frame in range(90):
		await physics_frame
		if not game.session.dish.is_empty():
			break
	_expect(game.session.dish.size() == 1 and str(game.session.dish[0].get("id", "")) == "ketchup", "only sauce actually landing in pan enters the recipe")
	game.world.drop_into_pan()
	for frame in range(30):
		await physics_frame
	_expect(game.session.dish.size() == 1 and not bool(bottle.get_meta("enrolled", false)), "dropping bottle into pan does not add a second ingredient")
	game._interact("trash")
	await process_frame
	_expect(game.session.dish.is_empty() and game._food_by_physics.is_empty(), "cleanup removes sauce from the authoritative pan")

func _check_authoring_pause(context: String) -> void:
	var elapsed_before: float = game.session.elapsed
	var wait_before: float = game.session.customer_wait
	await create_timer(0.08).timeout
	_expect(is_equal_approx(game.session.elapsed, elapsed_before), "%s pauses the shift clock" % context)
	_expect(is_equal_approx(game.session.customer_wait, wait_before), "%s pauses customer patience" % context)

func _used_ingredient_ids() -> Array:
	var ids: Array = []
	for child in game.modal_body.find_children("*", "Button", true, false):
		if child.has_meta("ingredient_id"):
			ids.append(str(child.get_meta("ingredient_id")))
	ids.sort()
	return ids

func _find_button(button_text: String) -> Button:
	for child in game.modal_body.find_children("*", "Button", true, false):
		if str(child.text) == button_text:
			return child as Button
	return null

func _press_button(button_text: String) -> bool:
	var button: Button = _find_button(button_text)
	_expect(button != null and not button.disabled, "authoring action is available: %s" % button_text)
	if button == null or button.disabled:
		return false
	button.emit_signal("pressed")
	return true

func _first_collage_layer(canvas, kind: String) -> Dictionary:
	for layer in canvas.export_data().get("stickers", []):
		if str(layer.get("kind", "")) == kind:
			return layer.duplicate(true)
	return {}

func _collage_layer_count(canvas, kind: String) -> int:
	var count: int = 0
	for layer in canvas.export_data().get("stickers", []):
		if str(layer.get("kind", "")) == kind:
			count += 1
	return count

func _dish_ids(dish_data: Dictionary) -> Array:
	var ids: Array = []
	for entry in dish_data.get("ingredients", []):
		ids.append(str(entry.get("id", "")))
	ids.sort()
	return ids

func _find_paper_in_modal():
	for child in game.modal_body.find_children("*", "Control", true, false):
		var script = child.get_script()
		if script != null and str(script.resource_path).ends_with("/poster_canvas.gd"):
			return child
	return null

func _same_json_value(actual: Variant, expected: Variant) -> bool:
	# Godot JSON parses integer-looking values as floats. Preserve all structure,
	# strings and field values while allowing the round-trip numeric representation.
	if (actual is int or actual is float) and (expected is int or expected is float):
		return absf(float(actual) - float(expected)) < 0.00000001
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size():
			return false
		for key in expected:
			if not actual.has(key) or not _same_json_value(actual[key], expected[key]):
				return false
		return true
	if actual is Array and expected is Array:
		if actual.size() != expected.size():
			return false
		for index in expected.size():
			if not _same_json_value(actual[index], expected[index]):
				return false
		return true
	return typeof(actual) == typeof(expected) and actual == expected

func _check_modal_bounds(title: String) -> void:
	var rect: Rect2 = game.modal_panel.get_global_rect()
	var viewport_size: Vector2 = game.get_viewport_rect().size
	_expect(rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= viewport_size.x + 1.0 and rect.end.y <= viewport_size.y + 1.0,
		"%s modal fits viewport: rect=%s viewport=%s" % [title, rect, viewport_size])

func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _finish() -> void:
	if failures.is_empty():
		print("PASS: restaurant integration, %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(str(failure))
		print("FAIL: restaurant integration, %d / %d checks" % [failures.size(), checks])
		quit(1)
