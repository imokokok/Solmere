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
	game.configure({"repository_path":"user://pan_input_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode(), "shift_seconds":600.0})
	root.add_child(game)
	await process_frame
	game._start_shift()
	await process_frame
	# Native input may enqueue the whole drag before the next rendered frame.
	game.world.spawn_ingredient(game._definition("tomato"))
	game.world.begin_food_drag(Vector2(85,220),true)
	_expect(game.world._held.position.distance_to(Vector2(85,220))<0.01 and game.world.held_grip.local_anchor.length()<0.01, "inventory grip starts at the press even if the OS cursor has already moved")
	game.world.discard_held()
	# A loose ingredient can visually overlap the handle above the fixed board.
	# Pan input runs before food input, so it must yield at opaque food pixels.
	game.world.spawn_ingredient(game._definition("potato"))
	var handle_food: RigidBody2D = game.world._held
	game.world.drop_held(false, false)
	await physics_frame
	await process_frame
	handle_food.stop_board_settle()
	handle_food.freeze = true
	var covered_handle: Vector2 = game.world.pan.point(Vector2(1035,578))
	handle_food.position = covered_handle
	handle_food.reset_physics_interpolation()
	await physics_frame
	await process_frame
	_expect(game.world._food_at(covered_handle) == handle_food and not game.world.pan.can_grab(covered_handle), "visible food over the pan handle owns its opaque pixels")
	_mouse(covered_handle, "down")
	await process_frame
	_expect(game.world._held == handle_food and not game.world.pan.active, "actual press picks the front food instead of the handle behind it")
	_mouse(covered_handle, "up")
	await process_frame
	if game.world.pan.active: game.world.pan.release_pan()
	game.world._pickup(handle_food)
	game.world.discard_held()
	await process_frame
	_expect(game.world.pan.can_grab(covered_handle), "uncovered handle remains grabbable after the front food is removed")
	# Grab food directly from a shelf on mouse-down, and release above a GUI panel.
	game.storage_display.reveal_ingredient("egg")
	var button = game.find_child("Ingredient_egg", true, false)
	if button == null:
		for node in game.find_children("*", "Button", true, false):
			if node.get_meta("ingredient_id", "") == "egg": button = node
	_expect(button != null, "find the visible cold-storage ingredient button")
	if button != null:
		var origin: Vector2 = button.get_global_rect().get_center()
		_mouse(origin, "down")
		await process_frame
		_expect(is_instance_valid(game.world._held) and game.world._dragging, "shelf press immediately owns a physical food drag")
		_mouse(Vector2(600, 605), "move")
		await create_timer(0.9).timeout
		_mouse(Vector2(1350, 250), "up")
		await process_frame
		_expect(not game.world._dragging, "release above GUI immediately ends pointer tracking")
		await create_timer(1.8).timeout
		_expect(game.world._held == null and not game.world._dragging, "release above GUI ends food drag")
		_mouse(origin, "down")
		_mouse(origin, "up")
		await process_frame
		_expect(not is_instance_valid(game.world._held), "the empty egg slot cannot create a second egg")
		var other = game.find_child("Ingredient_mushroom", true, false)
		_mouse(other.get_global_rect().get_center(), "down")
		_mouse(other.get_global_rect().get_center(), "up")
		await process_frame
		_expect(is_instance_valid(game.world._held), "a simple shelf click still supports click-to-carry")
		game.world.discard_held()
	# Independent loose food can be picked up more than once.
	game.world.spawn_ingredient(game._definition("bread"))
	var bread: RigidBody2D = game.world._held
	game.world.drop_into_pan()
	await create_timer(0.6).timeout
	_expect(bread.get_meta("enrolled", false), "pan fixture really enrolls through physics")
	game.session.set_heating(true)
	await create_timer(0.1).timeout
	_expect(game.world.audio.loops.flame.playing and not game.world.audio.loops.sizzle.playing, "dry bread in a dry pan has a burner sound without invented wet sizzling")
	var handle_home: Vector2 = game.world.pan.point(Vector2(1037, 578))
	var handle_sink: Vector2 = handle_home + Vector2(-587, 0)
	_mouse(handle_home, "down")
	await process_frame
	_expect(game.world.pan.active, "actual pan-handle press starts pan movement")
	var before := bread.position
	await _pan_motion(handle_sink)
	await process_frame
	await physics_frame
	await process_frame
	_expect(game.world.pan.rigid.position.x < before.x - 490 and game.world.pan.contains(bread.position) and not bread.freeze, "slow pan transport carries independent food through actual contacts")
	_mouse(handle_sink, "up")
	await create_timer(0.7).timeout
	_expect(not game.world.pan.active and game.world.pan.under_tap(), "released pan stays under sink faucet")
	_expect(game.session.dish.size() == 1 and bread.get_meta("enrolled", false), "pan transport preserves single recipe enrollment")
	if game.session.dish.is_empty():
		push_error("transport lost pan contents")
		quit(1)
		return
	var heat: float = game.session.dish[0].heat
	await create_timer(0.7).timeout
	_expect(is_equal_approx(game.session.dish[0].heat, heat), "pan away from burner stops receiving heat")
	_expect(game.world.audio.loops.flame.playing and not game.world.audio.loops.sizzle.playing, "burner remains audible while moved pan stops sizzling")
	# Pressing alone does not create water. The visible mixer lever must rotate.
	_mouse(Vector2(190,618), "down")
	_mouse(Vector2(190,618), "up")
	await process_frame
	_expect(not game.world.pan.faucet_on and is_zero_approx(game.world.pan.water_ml), "a faucet click alone cannot turn on water")
	_mouse(Vector2(190,618), "down")
	_mouse(Vector2(190,680), "move")
	_mouse(Vector2(190,680), "up")
	await create_timer(0.5).timeout
	_expect(game.world.pan.faucet_amount>0.95,"drag distance controls the visible faucet handle angle and flow amount")
	_expect(game.world.pan.water_ml > 60 and game.world.audio.loops.water.playing, "turning the faucet handle fills pan and starts matching water sound")
	_mouse(Vector2(175,632), "down")
	_mouse(Vector2(175,570), "move")
	_mouse(Vector2(175,570), "up")
	await process_frame
	var water: float = game.world.pan.water_ml
	await create_timer(0.1).timeout
	_expect(is_equal_approx(water, game.world.pan.water_ml), "turning the handle back stops filling immediately")
	await create_timer(0.4).timeout
	_expect(not game.world.audio.loops.water.playing, "turning the handle back fades the water recording within 400 milliseconds")
	_mouse(handle_sink, "down")
	await _pan_motion(handle_home)
	_mouse(handle_home, "up")
	await create_timer(0.7).timeout
	_expect(game.world.pan.on_stove() and game.world.pan.water_heat > 0, "returning a cold water-filled pan heats the water first")
	_expect(game.session.heating and bread.get_meta("enrolled", false), "moving the pan back does not drop its food or switch off the burner")
	game.world.pan.water_heat = 100
	game.world.pan.water_ml=600.0
	game.world.reactions.pan_c=130.0
	preload("res://tests/thermal_fixture.gd").cook(game,35.0)
	await create_timer(0.2).timeout
	_expect(game.session.dish[0].heat > heat, "hot water resumes actual food cooking")
	await process_frame
	await process_frame
	_expect(game.world.audio.loops.boil.playing and not game.world.audio.loops.sizzle.playing, "boiling water has its own sound instead of dry frying")
	game._show_pause()
	await process_frame
	var all_stopped := true
	for player in game.world.audio.loops.values(): all_stopped = all_stopped and not player.playing
	_expect(all_stopped, "modal suspends all continuous kitchen sounds")
	game._close_modal()
	game.world.audio.muted = true
	await process_frame
	for player in game.world.audio.loops.values(): _expect(not player.playing, "mute stops each loop independently of the host bus")
	game.world.audio.muted = false
	_mouse(handle_home, "down")
	await _pan_motion(handle_sink)
	_mouse(handle_sink, "up")
	await create_timer(0.7).timeout
	_expect(game.world.pan.under_tap(), "pan settles beneath faucet before draining")
	_mouse(Vector2(200,761), "down")
	_mouse(Vector2(200,761), "up")
	await create_timer(3.0).timeout
	_expect(game.world.pan.water_ml < 0.05, "sink drain empties pan water gradually")
	game.world.pan.faucet_on = true
	game.world.pan.water_ml = 1499
	await create_timer(0.2).timeout
	_expect(game.world.pan.water_ml <= 1500, "pan water remains within physical capacity")
	_expect(game.world.pan.overflow_water_ml > 0, "continued faucet flow becomes visible overflow instead of entering a full pan")
	game.world.pan.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_expect(not game.world.pan.faucet_on and not game.world.pan.active, "focus loss stops faucet and releases pan")
	# Drain the intentionally full fixture before testing moved-pan dispensing.
	_mouse(Vector2(200,761), "down")
	_mouse(Vector2(200,761), "up")
	await create_timer(6.0).timeout
	# Take the bottle from above the counter. Spawning inside the sink below
	# the pan and pulling upward correctly lifts the pan through contacts.
	_mouse(Vector2(420,480), "idle")
	await process_frame
	game.world.spawn_ingredient(game._definition("ketchup"))
	_mouse(Vector2(211,633), "idle")
	await create_timer(0.8).timeout
	_mouse(Vector2(211,633), "down")
	await create_timer(0.7).timeout
	_mouse(Vector2(211,633), "up")
	for frame in range(60):
		if game.session.dish.size() >= 2: break
		await physics_frame
	var moved_pan_received_ketchup := false
	for item in game.session.dish: moved_pan_received_ketchup = moved_pan_received_ketchup or item.id == "ketchup"
	_expect(game.session.dish.size() >= 2 and moved_pan_received_ketchup, "dispensing targets the moved pan instead of old stove coordinates")
	game.world.discard_held()
	game.world.audio.muted = true
	game.world.audio.stop_all()
	await create_timer(0.14).timeout
	game.queue_free()
	await process_frame
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: kitchen interactions, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _mouse(point: Vector2, kind: String) -> void:
	point = root.get_final_transform() * point
	if kind in ["move", "idle"]:
		var e := InputEventMouseMotion.new()
		e.position = point
		e.global_position = point
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if kind == "move" else 0
		Input.parse_input_event(e)
	else:
		var e := InputEventMouseButton.new()
		e.position = point
		e.global_position = point
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = kind == "down"
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if e.pressed else 0
		Input.parse_input_event(e)
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _pan_motion(target: Vector2) -> void:
	var pan=game.world.pan
	var start: Vector2=pan.rigid.to_global(pan.grip.local_anchor)
	# Lift clear of the surface, translate slowly, then set down.
	var waypoints := [start+Vector2(0,-85),target+Vector2(0,-85),target]
	for endpoint in waypoints:
		var frames := 420 if absf(endpoint.x-start.x)>100 else 90
		for i in frames:
			var t:=float(i+1)/frames
			_mouse(start.lerp(endpoint,smoothstep(0,1,t)), "move")
			await physics_frame
		start=endpoint
	await create_timer(0.5).timeout
