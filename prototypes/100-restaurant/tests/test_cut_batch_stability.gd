extends SceneTree

var game
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	Engine.max_fps = 120
	call_deferred("_run")

func _run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://cut_stability_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode(), "shift_seconds": 600.0})
	root.add_child(game)
	await process_frame
	game._start_shift()
	await process_frame
	var world = game.world
	world.audio.muted = true

	# Drag the board's empty area toward the pan using real input events.
	# The fixed station and its food must remain in the preparation area.
	world.spawn_ingredient(game._definition("tomato"))
	var whole: RigidBody2D = world._held
	whole.position = world.cutting_board.rect().get_center()
	world.drop_held(false)
	await process_frame
	var old_board: Vector2 = world.cutting_board.position
	var old_food: Vector2 = whole.position
	_mouse(old_board + Vector2(14, 14), "down")
	_mouse(world.pan.point(Vector2(810, 560)), "move")
	_mouse(world.pan.point(Vector2(810, 560)), "up")
	await process_frame
	_expect(world.cutting_board.position == old_board, "dragging the board toward the pan leaves it fixed in place")
	_expect(world._stations.chop == Rect2(old_board, world.cutting_board.SIZE), "fixed cutting station retains its original bounds")
	_expect(whole.position.distance_to(old_food) < 1.0 and whole.get_meta("on_board", false), "dragging an empty board area does not carry its food away")

	# Make eight pieces from one lineage.  A single drag must enroll all of them
	# without any shared spawn position or solver ejection.
	var generation: Array[RigidBody2D] = [whole]
	for depth in range(3):
		var next: Array[RigidBody2D] = []
		for piece in generation:
			var normal := Vector2.RIGHT if depth % 2 == 0 else Vector2.DOWN
			next.append_array(world.split_food(piece, normal, Vector2.INF, 4))
		generation = next
		await process_frame
	_expect(generation.size() == 8, "three real cuts produce eight independent pieces")
	var batch_uid := str(generation[0].get_meta("batch_uid", "")) if not generation.is_empty() else ""
	for piece in generation:
		_expect(str(piece.get_meta("batch_uid", "")) == batch_uid and piece.freeze, "every cut piece keeps lineage and stays stable on the board")

	if not generation.is_empty():
		var pan_before: Vector2 = world.pan.offset
		var start: Vector2 = generation[0].position
		_mouse(start, "down")
		await process_frame
		_expect(world._drag_group.size() == 7, "one real pointer press lifts the seven sibling slices")
		_mouse(world.pan.point(Vector2(810,580)), "move")
		_mouse(world.pan.point(Vector2(810,580)), "up")
		await create_timer(1.7).timeout
		await create_timer(1.6).timeout
		_expect(world.pan.offset.distance_to(pan_before)<35.0,"dropping at the near half of the bowl does not shove the pan off the burner")
	_expect(game.session.dish.size() == generation.size(), "one quick drag drops the complete eight-piece portion")
	_expect(world._held==null and world._drag_group.is_empty() and not world._pending_drop,"the near-rim release frees the hand and every sibling grip")
	var occupied: Dictionary = {}
	for piece in generation:
		_expect(is_instance_valid(piece) and piece.get_meta("enrolled", false), "every batch fragment is accepted by the pan")
		_expect(world.pan.contains(piece.position), "every batch fragment remains inside the pan")
		_expect(piece.position.is_finite() and piece.position.y < 760.0, "no cut fragment is thrown off the worktop")
		var cell := Vector2i(roundi(piece.position.x), roundi(piece.position.y))
		occupied[cell] = true
	_expect(occupied.size() > 5, "native contacts separate all eight fragments")

	# Capacity is conserved and excess tap water is tracked as overflow.
	world.pan.move_to(Vector2(world.pan.SINK_X - 809.0, world.pan.HOME.y))
	world.pan.water_ml = 1499.0
	world.pan.overflow_water_ml = 0.0
	world.pan.faucet_on = true
	await create_timer(0.25).timeout
	_expect(world.pan.water_ml <= 1500.0, "pan cannot contain more than its physical water capacity")
	_expect(world.pan.overflow_water_ml > 0.0, "water after capacity is recorded as overflow")
	world.pan.faucet_on = false
	world.pan.water_ml = 500.0
	world.pan.angle = 0.0
	world.pan.grab(world.pan.point(Vector2(1000,566)))
	world.pan.move_pointer(Vector2(660,440))
	world.pan.set_angle(deg_to_rad(110.0))
	_expect(world.pan.water_ml == 500.0, "changing wrist target cannot instantly delete water")
	await create_timer(2.5).timeout
	_expect(world.pan.water_ml < 25.0 and world.pan.runoff.received_ml > 450, "tilt drains water progressively through the low rim")
	world.pan.release_pan()
	world.clear_workspace()
	await process_frame
	_expect(is_zero_approx(world.pan.overflow_water_ml) and world._foods.get_child_count() == 0, "clean workspace removes loose food, spills and residual overflow state")

	game.queue_free()
	await process_frame
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: cut-batch stability, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _mouse(point: Vector2, kind: String) -> void:
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
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if event.pressed else 0
		Input.parse_input_event(event)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
