extends SceneTree
## A running tap has a conserved path through sink storage, room flood and drain.
var game: Node2D
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")

func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://flood_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode()})
	root.add_child(game)
	await process_frame
	game._close_modal()
	game.world.audio.muted = true
	check(game.world.flood_art.get_parent() == game.hud, "flood overlay covers the kitchen and HUD in the same screen layer")
	check(is_equal_approx(game.session.duration, 720.0), "a full shift lasts twelve real minutes")
	game.session.phase = "service"
	game.session.elapsed = 360.0
	game._update_hud()
	check("12:00" in game.clock_label.text, "halfway through the shift the visible clock has advanced two game hours")
	game.session.elapsed = 0.0
	game.session.phase = "prep"
	game.world.pan.faucet_on = true
	game.world.pan._process(10.0)
	check(is_equal_approx(game.world.sink_water_ml, 1200.0) and is_equal_approx(game.world.flood_water_ml, 600.0), "running tap fills sink then puts its overflow on the kitchen floor")
	check(game.world.flood_ratio() > 0.0 and game.world.flood_ratio() < 0.1, "waterline starts at the floor and rises continuously")
	game.world.pan._process(40.0)
	check(is_equal_approx(game.world.flood_water_ml, game.world.KITCHEN_FLOOD_ML) and is_equal_approx(game.world.drained_flood_ml, 0.0), "continued running water reaches the full-room flood height")
	game.world.pan._process(10.0)
	check(is_equal_approx(game.world.drained_flood_ml, 1800.0), "water beyond the room capacity is recorded rather than disappearing")
	game.world.pan.faucet_on = false
	game.world._process(12.0)
	check(is_equal_approx(game.world.flood_water_ml, 6600.0) and is_equal_approx(game.world.drained_flood_ml, 3000.0), "closing the tap drains standing room water without resetting it instantly")
	check(is_equal_approx(game.world.sink_water_ml + game.world.flood_water_ml + game.world.drained_flood_ml, 10800.0), "tap water remains conserved across sink, floor and drain")
	var world=game.world
	world.pan.move_to(Vector2(-598,world.pan.HOME.y))
	var overflow_path: PackedVector2Array=world.pan.faucet_art.overflow_path(1.0)
	check(world.pan.contains(overflow_path[0]) and overflow_path[1].y<overflow_path[3].y,"overflow starts inside the moved pot, crosses its rim and descends outside")
	world.pan.water_ml=400.0
	var before: float=world.sink_water_ml+world.flood_water_ml+world.drained_flood_ml
	world.pan.grab(world.pan.point(world.pan.PIVOT))
	world.pan.set_angle(PI/2)
	check(world.pan.water_ml==0 and is_equal_approx(world.sink_water_ml+world.flood_water_ml+world.drained_flood_ml-before,400.0),"tilting retained pot water into sink adds exactly that volume to sink/floor/drain")
	world.pan.release_pan()
	world.pan.water_ml=350.0
	before=world.sink_water_ml+world.flood_water_ml+world.drained_flood_ml
	var drain:=InputEventMouseButton.new()
	drain.button_index=MOUSE_BUTTON_LEFT; drain.pressed=true
	drain.position=world.get_global_transform_with_canvas()*Vector2(215,765)
	world.pan._input(drain)
	check(world.pan.water_ml==0 and is_equal_approx(world.sink_water_ml+world.flood_water_ml+world.drained_flood_ml-before,350.0),"sink drain action conserves retained pot water instead of deleting it")
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		var prefix: String = OS.get_cmdline_user_args()[0]
		game.world.flood_water_ml = 0.0
		game.world.flood_art.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var dry := root.get_texture().get_image()
		game.world.flood_water_ml = game.world.KITCHEN_FLOOD_ML * 0.72
		game.world.flood_art.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(prefix + "-rising.png") == OK, "GPU shows a room-wide rising waterline")
		game.world.flood_water_ml = game.world.KITCHEN_FLOOD_ML
		game.world.flood_art.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var full := root.get_texture().get_image()
		check(full.save_png(prefix + "-full.png") == OK, "GPU saves the fully flooded kitchen")
		var changed := true
		for pixel in [Vector2i(80, 80), Vector2i(720, 100), Vector2i(1250, 150), Vector2i(800, 750)]:
			var a: Color = dry.get_pixelv(pixel)
			var b: Color = full.get_pixelv(pixel)
			changed = changed and Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b)) > 0.08
		check(changed, "full flood tints every sampled screen region including HUD and upper kitchen")
	for failure in failures: push_error(failure)
	print("%s: kitchen flood, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	game.queue_free()
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description)
