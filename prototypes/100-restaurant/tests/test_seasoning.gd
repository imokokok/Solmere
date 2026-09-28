extends SceneTree
## Real input -> held container -> timed portions -> physics pan -> domain.
## Godot --headless --path <project> --script res://tests/test_seasoning.gd

var PAN_POINT := Vector2.ZERO
var game
var checks := 0
var failures: Array[String] = []
var previous_pointer := Vector2.ZERO
var original_mouse_mode: int

func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	Engine.max_fps = 120
	call_deferred("_run")

func _run() -> void:
	original_mouse_mode = Input.mouse_mode
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"shift_seconds": 240.0, "repository_path": "user://seasoning_input_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode()})
	root.add_child(game)
	await process_frame
	await process_frame
	game._start_shift()
	PAN_POINT=game.world.pan.point(Vector2(809,550))
	if "--foreground-only" in OS.get_cmdline_user_args():
		await _test_hand_foreground()
	else:
		for sample in [["salt", "powder", "ui"], ["pepper", "powder", "normal"], ["vinegar", "pour", "focus"], ["soy_sauce", "pour", "normal"], ["oil", "pour", "outside"], ["mustard", "squeeze", "modal"], ["ketchup", "squeeze", "normal"]]:
			await _test_container(sample[0], sample[1], sample[2])
		await _test_capacity()
		await _test_hand_foreground()
		await _test_solid_seasoning("ginger")
		await _test_solid_seasoning("garlic")
	await _clean_kitchen()
	game.world._sound.stop()
	game.world.audio.stop_all()
	await create_timer(0.08).timeout
	game.world.audio.muted = true
	await create_timer(0.14).timeout
	game.queue_free()
	await process_frame
	_expect(Input.mouse_mode == original_mouse_mode, "seasoning test restores host pointer mode")
	if failures.is_empty():
		print("PASS: seasoning input and physics, %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: seasoning input and physics, %d / %d checks" % [failures.size(), checks])
		quit(1)

func _test_container(id: String, mode: String, stop_kind: String) -> void:
	await _clean_kitchen()
	var definition: Dictionary = game._definition(id)
	_expect(definition.get("dispense_mode", "") == mode, "%s catalog specifies its actual %s operation" % [id, mode])
	_expect(float(definition.get("dispense_mass", 0)) > 0, "%s defines a positive portion mass" % id)
	_expect(game.world.spawn_ingredient(definition), "%s can be taken as a physical kitchen object" % id)
	var bottle: RigidBody2D = game.world._held
	if not is_instance_valid(bottle):
		_expect(false, "%s has a valid held container" % id)
		return
	_expect(bool(bottle.get_meta("is_container", false)), "%s is marked as a reusable container" % id)
	_motion(PAN_POINT, false)
	await process_frame
	await process_frame
	_mouse_button(PAN_POINT, true)
	await process_frame
	_expect(game.world._squeezing, "%s real mouse press above pan begins timed dispensing" % id)
	if not game.world._squeezing:
		print("Seasoning input diagnostic %s: mouse=%s held=%s focus=%s controls=%s" % [id, game.world.get_global_mouse_position(), game.world._held, game.world._focus, game.world.controls_enabled])
		_mouse_button(PAN_POINT, false)
		return
	await create_timer(0.12).timeout
	_expect(_portions().is_empty(), "%s quick initial press does not create a portion before the hold threshold" % id)
	await create_timer(1.42).timeout
	var portions: Array = _portions()
	_expect(game.world._nozzle_world_position().y > bottle.global_position.y, "%s actual held input keeps the nozzle facing into the pan" % id)
	_expect(portions.size() >= 2 and portions.size() <= 6, "%s sustained mouse hold releases repeated pressure-driven portions" % id)
	_expect(game.world._held == bottle and is_instance_valid(bottle), "%s dispensing preserves the original held bottle" % id)
	var valid_portions := not portions.is_empty()
	for portion in portions:
		valid_portions = valid_portions and str(portion.get_meta("id", "")) == id and str(portion.get_meta("dispense_mode", "")) == mode
		var liquid_state: Dictionary = portion.get_meta("liquid_state", {})
		var expected_mass := float(liquid_state.get("volume_ml", 0.0)) * float(definition.get("density_g_ml", 1.03)) / 1000.0
		valid_portions = valid_portions and not bool(portion.get_meta("is_container", true)) and is_equal_approx(portion.mass, expected_mass)
		valid_portions = valid_portions and str(liquid_state.get("source_id", "")) == str(bottle.get_meta("instance_uid", ""))
		var visual = portion.get_node_or_null("SauceBlob")
		valid_portions = valid_portions and visual != null and str(visual.get("dispense_mode")) == mode
	_expect(valid_portions, "%s portions preserve source identity, operation-specific art, measured volume and matching mass" % id)
	match stop_kind:
		"ui":
			_mouse_button(Vector2(1420, 220), false)
		"focus":
			# The engine notification is the actual window-focus-loss entry point;
			# no OS focus is stolen from the user's live game window.
			game.world.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		"outside":
			_motion(Vector2(580, 550), true) # Clear of the enlarged skillet rim.
		"modal":
			game._show_pause()
		_:
			_mouse_button(PAN_POINT, false)
	await process_frame
	await process_frame
	_expect(not game.world._squeezing, "%s %s stop condition cancels active dispensing" % [id, stop_kind])
	var count_at_stop: int = _portions().size()
	await create_timer(0.88).timeout
	_expect(_portions().size() == count_at_stop, "%s produces no extra portions after its %s stop condition" % [id, stop_kind])
	if stop_kind == "modal":
		game._close_modal()
		await process_frame
		_expect(not game.world._squeezing, "closing a seasoning pause does not resume dispensing automatically")
	_mouse_button(previous_pointer, false)
	await create_timer(0.15).timeout
	_expect(not game.session.dish.is_empty(), "%s portions really fall into the physics pan and enter the recipe" % id)
	var correct_recipe: bool = not game.session.dish.is_empty()
	for item in game.session.dish:
		correct_recipe = correct_recipe and str(item.get("id", "")) == id and int(item.get("physics_id", 0)) != bottle.get_instance_id()
	_expect(correct_recipe, "%s recipe contains only the dispensed ingredient and never the container body" % id)
	_expect(not bool(bottle.get_meta("enrolled", false)), "%s bottle itself remains excluded from pan enrollment" % id)
	if id == "ketchup":
		_motion(PAN_POINT, false)
		await process_frame
		await _key(KEY_E)
		await create_timer(0.55).timeout
		_expect(game.world._held == null and not bool(bottle.get_meta("enrolled", false)), "even physically dropping a condiment bottle into the pan never enrolls it")
		var bottle_in_recipe := false
		for item in game.session.dish:
			bottle_in_recipe = bottle_in_recipe or int(item.get("physics_id", 0)) == bottle.get_instance_id()
		_expect(not bottle_in_recipe, "dropped condiment packaging never becomes a recipe ingredient")
		var cooked_portions: Array = _portions()
		if not cooked_portions.is_empty():
			var portion: RigidBody2D = cooked_portions[0]
			game.world._pickup(portion)
			await process_frame
			await process_frame
			_expect(is_instance_valid(game.world._held_proxy) and game.world._held_foreground.visible, "a picked-up sauce portion also has a visible foreground proxy")
			_motion(PAN_POINT, false)
			await create_timer(0.8).timeout
			await _key(KEY_E)
			await create_timer(0.55).timeout
			_expect(portion.collision_layer == 32 and portion.collision_mask == 1, "re-dropping a sauce portion preserves its non-stacking collision layer")
			var appearances := 0
			for item in game.session.dish:
				if int(item.get("physics_id", 0)) == portion.get_instance_id():
					appearances += 1
			_expect(appearances == 1, "re-dropped sauce reenters the actual recipe exactly once")

func _test_capacity() -> void:
	await _clean_kitchen()
	_expect(game.world.spawn_ingredient(game._definition("ketchup")), "capacity test starts with a reusable ketchup bottle")
	_motion(PAN_POINT, false)
	await process_frame
	_mouse_button(PAN_POINT, true)
	await process_frame
	_expect(game.world._squeezing, "capacity regression starts through actual held mouse input")
	await create_timer(5.2).timeout
	_expect(_portions().size() >= 2 and _portions().size() <= 8, "sustained output pools locally without unbounded bodies")
	var spill: RigidBody2D
	for body in game.world._foods.get_children():
		if body.get_meta("overflow", false): spill = body
	_expect(not is_instance_valid(spill), "several seconds of sauce do not fill a 1500 ml pan")
	_expect(game.world.pan_contents_ml() < 200, "small portions reserve actual millilitres, not whole food slots")
	_mouse_button(PAN_POINT, false)
	await process_frame
	# Fill the remaining volume with water, then resume the same held input.
	game.world.pan.water_ml = maxf(0.0, 1498.0 - game.world.pan_contents_ml())
	_mouse_button(PAN_POINT, true)
	await create_timer(1.2).timeout
	for body in game.world._foods.get_children():
		if body.get_meta("overflow", false): spill = body
	_expect(is_instance_valid(spill), "sauce spills after the combined contents reach the rim")
	if not is_instance_valid(spill):
		_mouse_button(PAN_POINT, false)
		return
	var spill_before := float(spill.get_meta("volume_ml", 0.0))
	var bottle_before := float(game.world._held.get_meta("remaining_ml", 0.0))
	await create_timer(0.8).timeout
	_expect(float(spill.get_meta("volume_ml")) > spill_before, "continued pressure grows the existing spill")
	_expect(absf(float(spill.get_meta("volume_ml")) - spill_before - bottle_before + float(game.world._held.get_meta("remaining_ml"))) < 0.03, "overflow growth conserves bottle volume")
	_expect(absf(game.world.pan_contents_ml() - 1500.0) < 0.03, "pan holds its calibrated volume while the excess spills")
	_mouse_button(PAN_POINT, false)
	await process_frame
	var stopped := float(spill.get_meta("volume_ml"))
	await create_timer(0.4).timeout
	_expect(is_equal_approx(stopped, float(spill.get_meta("volume_ml"))), "release stops overflow output")
	for portion in _portions():
		_expect(portion.get_node("SauceBlob").z_index < game.world.pan.pan_front.z_index, "liquid remains behind the opaque front wall")
	game.world._on_pan_entered(spill)
	_expect(not spill.get_meta("enrolled", false), "spill is not counted as food in the pan")
	_motion(Vector2(620, 520), false)
	await process_frame
	await _key(KEY_Q)
	_expect(game.world._wipe_spill_at(spill.position), "measured countertop spill can be wiped")
	await process_frame
	_expect(not is_instance_valid(spill), "wiping removes the spill entity")
func _test_hand_foreground() -> void:
	await _clean_kitchen()
	_expect(game.world.spawn_ingredient(game._definition("mustard")), "foreground regression starts with a held condiment")
	var body: RigidBody2D = game.world._held
	_motion(Vector2(809, 350), false)
	await process_frame
	await process_frame
	var source = game.world._held_proxy_source
	_expect(is_instance_valid(game.world._held_proxy) and game.world._held_foreground.visible, "held condiment foreground clone is visible while kitchen control is enabled")
	_expect(game.world._held_foreground.get_parent() is CanvasLayer and game.world._held_foreground.get_parent().layer == 2, "held visual is drawn on a layer above the storage HUD")
	_expect(is_instance_valid(source) and not source.visible, "held object hides its original world visual to avoid a double image")
	_expect(game.world._held_foreground.get_child_count() == 1, "held foreground creates exactly one visual proxy")
	game._show_pause()
	await process_frame
	await process_frame
	_expect(not game.world._held_foreground.visible and not source.visible, "opening a modal hides the foreground proxy without revealing a duplicate source")
	game._close_modal()
	await process_frame
	await process_frame
	_expect(game.world._held_foreground.visible, "closing a modal restores the held foreground visual")
	_motion(Vector2(1210,735), false)
	await process_frame
	await _key(KEY_Q)
	await process_frame
	var loose_proxy: bool = game.world.get_node("FloatingTools").copies.has(source.get_instance_id())
	_expect(game.world._held == null and (source.visible or loose_proxy), "dropping transfers the visual to the world or the loose foreground above cupboards")
	_expect(not is_instance_valid(game.world._held_proxy) and game.world._held_foreground.get_child_count() == 0, "dropping removes the foreground clone instead of leaving an overlapping copy")
	game.world._pickup(body)
	await process_frame
	await process_frame
	_expect(is_instance_valid(game.world._held_proxy), "picking the dropped container up again rebuilds its foreground clone")
	body.queue_free()
	await process_frame
	await process_frame
	await process_frame
	_expect(not is_instance_valid(game.world._held_proxy) and not is_instance_valid(game.world._held_proxy_source), "deleting the held owner body also cleans up both proxy references")
	_expect(game.world._held_foreground.get_child_count() == 0 and not game.world._held_foreground.visible, "owner deletion leaves no floating foreground image")

func _test_solid_seasoning(id: String) -> void:
	await _clean_kitchen()
	var definition: Dictionary = game._definition(id)
	_expect(str(definition.get("dispense_mode", "")).is_empty(), "%s remains an intact solid seasoning in the catalog" % id)
	_expect(game.world.spawn_ingredient(definition), "%s can still be picked up as a physical ingredient" % id)
	var original: RigidBody2D = game.world._held
	if not is_instance_valid(original):
		return
	_expect(not bool(original.get_meta("is_container", false)), "%s is not incorrectly treated as a dispensing bottle" % id)
	_motion(Vector2(1210,735), false)
	await process_frame
	await _key(KEY_Q)
	# Stabilize a resting board fixture; the cutting action itself is real mouse
	# input through the shared scene, not a direct split_food call.
	original.global_position = Vector2(1210,735)
	original.set_deferred("position",original.position)
	original.freeze = true
	await process_frame
	_mouse_button(game.world._knife_handle_rect().get_center(), true)
	await process_frame
	_motion(Vector2(1210,680)-game.world._knife_drag_offset-Vector2(-50,-22),true)
	await process_frame
	_motion(Vector2(1210,775)-game.world._knife_drag_offset-Vector2(-50,-22),true)
	await process_frame
	_mouse_button(Vector2(1420, 220), false)
	await process_frame
	var fragments: Array = []
	for body in game.world._foods.get_children():
		if not body.is_queued_for_deletion() and str(body.get_meta("id", "")) == id and int(body.get_meta("cut_depth", 0)) > 0:
			fragments.append(body)
	_expect(fragments.size() == 2, "%s still splits into two pieces under an actual knife drag" % id)
	if fragments.size() == 2:
		_expect(is_equal_approx(fragments[0].mass + fragments[1].mass, float(definition.mass)), "%s cutting preserves solid ingredient mass" % id)
	_expect(_portions().is_empty(), "%s cutting never generates a liquid or powder portion" % id)

func _clean_kitchen() -> void:
	_mouse_button(previous_pointer, false)
	if game.modal.visible:
		game._close_modal()
	game.world.put_knife_back()
	game.world.discard_held()
	game.world.clear_food()
	game.session.clear_dish()
	game._food_by_physics.clear()
	for body in game.world._foods.get_children():
		body.queue_free()
	await process_frame
	await physics_frame

func _portions() -> Array:
	var portions: Array = []
	for body in game.world._foods.get_children():
		if not body.is_queued_for_deletion() and bool(body.get_meta("dispensed", false)) and not body.get_meta("overflow", false):
			portions.append(body)
	return portions

func _mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
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
	Input.parse_input_event(release)
	await process_frame

func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
