extends SceneTree
## Short production-scene recording of the real shelf-to-rim mouse gesture.
## godot --path . --write-movie <output.avi> --fixed-fps 24 --script res://tests/capture_egg_cracking.gd

var game
var previous_pointer := Vector2.ZERO
var original_pointer := Vector2.ZERO

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("_run")

func _run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://egg_capture_%s/book.json" % Time.get_ticks_usec(), "shift_seconds": 240.0})
	root.add_child(game)
	await process_frame
	original_pointer = root.get_mouse_position()
	game._start_shift()
	await _frames(25)
	var slot := game.storage_display.find_child("Ingredient_egg", true, false) as Button
	if slot == null: return _fail("egg shelf slot missing")
	var origin: Vector2 = slot.get_global_rect().get_center()
	var rim: Vector2 = game.world.pan.point(Vector2(809, 546))
	_mouse(origin, "down")
	await _frames(4)
	if not is_instance_valid(game.world._held): return _fail("egg did not leave shelf")
	var egg: RigidBody2D = game.world._held
	var original_mass := egg.mass
	for i in 28:
		_mouse(origin.lerp(rim, (i + 1) / 28.0), "move")
		await process_frame
	_mouse(rim, "up")
	await _frames(25)
	await _frames(24)
	if not bool(egg.get_meta("thermal", {}).get("egg_opened", false)): return _fail("single rim gesture did not pour the egg")
	if game.world._egg_shells.get_child_count() != 2: return _fail("shell fragments missing")
	var shell_mass := 0.0
	for shell in game.world._egg_shells.get_children(): shell_mass += shell.mass
	if absf(egg.mass + shell_mass - original_mass) > 0.00001: return _fail("egg mass balance changed")
	await _frames(48)
	for shell in game.world._egg_shells.get_children():
		if game.world.pan.contains(shell.position): return _fail("shell landed in pan")
	if not bool(egg.get_meta("enrolled", false)): return _fail("edible egg did not enter pan")
	print("PASS: filmed one scripted shelf-to-rim gesture, liquid egg and two counter shell pieces")
	game.world.audio.muted = true
	game.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless": Input.warp_mouse(original_pointer)
	quit(0)

func _frames(count: int) -> void:
	for i in count: await process_frame

func _mouse(point: Vector2, kind: String) -> void:
	var transformed: Vector2 = root.get_final_transform() * point
	if DisplayServer.get_name() != "headless": Input.warp_mouse(transformed)
	if kind == "move":
		var motion := InputEventMouseMotion.new()
		motion.position = transformed
		motion.global_position = transformed
		motion.relative = transformed - root.get_final_transform() * previous_pointer
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0
		Input.parse_input_event(motion)
	else:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if kind == "down" else 0
		button.pressed = kind == "down"
		button.position = transformed
		button.global_position = transformed
		Input.parse_input_event(button)
	previous_pointer = point

func _fail(reason: String) -> void:
	push_error("Egg capture failed: " + reason)
	if DisplayServer.get_name() != "headless": Input.warp_mouse(original_pointer)
	quit(1)
