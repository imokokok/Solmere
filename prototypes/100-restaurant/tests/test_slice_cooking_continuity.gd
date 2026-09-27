extends SceneTree

var game
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")

func run() -> void:
	var bath = preload("res://modules/restaurant/domain/kitchen_session.gd").new()
	bath.setup()
	bath.add_ingredient("chicken")
	bath.water_ml = 500
	bath.set_heating(true)
	bath.tick(30)
	expect(is_zero_approx(bath.dish[0].heat), "cold water does not instantly cook chicken")
	bath.water_heat = 100
	bath.tick(100)
	expect(bath.plate().raw_count == 0 and not bath.plate().burnt, "boiling water cooks chicken without dry-pan charring")
	bath.water_ml = 0
	bath.tick(20)
	var burnt_dose: float = bath.dish[0].heat
	expect(bath.plate().burnt, "boiled food can scorch once the pan dries out")
	bath.water_ml = 500
	bath.tick(20)
	expect(bath.dish[0].heat == burnt_dose, "adding water does not undo existing scorching")
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://slice_cooking_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode(), "shift_seconds": 600.0})
	root.add_child(game)
	await process_frame
	game._start_shift()
	var world = game.world
	world.audio.muted = true
	world.spawn_ingredient(game._definition("chicken"))
	var whole: RigidBody2D = world._held
	var mass: float = whole.mass
	whole.position = world.cutting_board.rect().get_center()
	world.drop_held()
	await process_frame
	world.pickup_knife()
	# Parallel blade strokes remove narrow slices from the remaining piece.
	for index in range(6):
		var remainder: RigidBody2D
		for body in world._foods.get_children():
			if not body.is_queued_for_deletion() and (remainder == null or body.mass > remainder.mass): remainder = body
		if remainder == null: break
		var points: PackedVector2Array = remainder.get_meta("fragment_polygon", PackedVector2Array())
		var left := -24.0
		if not points.is_empty():
			left = INF
			for point in points: left = minf(left, point.x)
		world._time += 0.4
		# Settling may rotate the remainder: parallel strokes follow its local axis.
		var stroke_from: Vector2 = remainder.to_global(Vector2(left + 6.0, -40))
		var stroke_to: Vector2 = remainder.to_global(Vector2(left + 6.0, 40))
		world._knife_visual.rotation = (stroke_to - stroke_from).angle() - PI / 2.0
		world._perform_knife_sweep(stroke_from, stroke_to)
		await process_frame
	world.put_knife_back()
	var pieces: Array = world._foods.get_children()
	expect(pieces.size() == 7, "six parallel knife strokes create seven independent pieces")
	var total := 0.0
	var thin := 0
	var geometry: Dictionary = {}
	for piece in pieces:
		total += piece.mass
		var polygon: PackedVector2Array = piece.get_meta("fragment_polygon", PackedVector2Array())
		var minimum := INF
		var maximum := -INF
		for point in polygon:
			minimum = minf(minimum, point.x)
			maximum = maxf(maximum, point.x)
		if maximum - minimum <= 6.1: thin += 1
		geometry[piece.get_instance_id()] = polygon.duplicate()
	expect(thin >= 6, "cutting produces thin parallel slices rather than uniform chunks")
	expect(is_equal_approx(mass, total), "slicing conserves ingredient mass")
	if not pieces.is_empty():
		for fragment in pieces:
			world._pickup(fragment)
			world.drop_into_pan()
			await create_timer(0.4).timeout
	await create_timer(1.4).timeout
	expect(game.session.dish.size() == pieces.size(), "all seven independently dropped slices reach the pan")
	game.session.set_heating(true)
	preload("res://tests/thermal_fixture.gd").cook(game,45.0)
	world.set_dish(game.session.dish, game.session.ingredients)
	for piece in pieces:
		expect(piece.get_meta("fragment_polygon") == geometry[piece.get_instance_id()], "cooking retains each slice's exact geometry")
		expect(float(piece.get_node("FoodArt").heat) >= 6.0, "cooked dose reaches the actual fragment renderer")
	game.session.set_heat_level("high")
	preload("res://tests/thermal_fixture.gd").cook(game,80.0)
	world.set_dish(game.session.dish, game.session.ingredients)
	expect(game.session.plate().burnt, "unattended dry heat produces evaluated burnt food")
	game._show_plating()
	await process_frame
	for piece in pieces: game._plating_canvas.add_to_plate(piece)
	await process_frame
	for piece in pieces:
		expect(piece.get_meta("plated", false) and piece.get_meta("fragment_polygon") == geometry[piece.get_instance_id()], "plating retains the actual slice rather than replacing it")
		expect(game._plating_canvas._visuals[piece.get_instance_id()].art.heat > 14, "plating keeps the burnt surface state")
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: slice cooking continuity, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
