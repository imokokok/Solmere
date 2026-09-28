extends SceneTree
## Optional rendered QA capture. Omit --headless; pass destination after --.
## Godot --path <project> --script res://tests/capture_preview.gd -- <absolute.png>

var game

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	Engine.max_fps = 60
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Preview capture needs a rendering display, not --headless.")
		quit(1)
		return
	var packed = load("res://modules/restaurant/restaurant.tscn")
	game = packed.instantiate()
	game.configure({"shift_seconds": 720.0, "display_name": "预览主厨", "repository_path": "user://preview_qa/cookbook.json"})
	root.add_child(game)
	await process_frame
	game._start_shift()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[1] if args.size() > 1 else "kitchen"
	var staged_id := "egg" if mode == "knife" else ("noodles" if mode == "noodles" else "tomato")
	game.world.spawn_ingredient(game._definition(staged_id))
	await physics_frame
	pass # Capture stages an intact ingredient; cutting is tested via pointer input.
	game.world.drop_into_pan()
	for frame in range(45):
		await physics_frame
	if mode == "fire":
		game.session.set_heat_level("high")
		game.session.set_heating(true)
		game.world.set_heat_level("high")
		game.world.set_cooking(true)
		for frame in range(8): await process_frame
	elif mode == "noodles":
		game.world.pan.water_ml = 650.0
		game.world.pan.water_heat = 100.0
		game.session.water_ml = 650.0
		game.session.water_heat = 100.0
		game.session.tick(8.0)
		game.world.set_dish(game.session.dish, game.session.ingredients)
		game._notify("沸水中的面条正在吸水、散开并变软")
		for frame in range(12): await process_frame
	elif mode == "cutting":
		game.world.clear_food()
		game.session.clear_dish()
		for id in ["tomato","mushroom","carrot"]:
			game.world.spawn_ingredient(game._definition(id))
			game.world._held.position = Vector2(1110+game.world._foods.get_child_count()*65,735)
			game.world.drop_held()
		game._notify("在右侧菜板直接使用刀具切配")
		await process_frame
		await process_frame
		game.world.split_food(game.world._foods.get_child(0),Vector2.RIGHT,Vector2(1175,735),4)
	elif mode == "cut_batch":
		game.world.clear_food()
		game.session.clear_dish()
		game.world.spawn_ingredient(game._definition("tomato"))
		var whole: RigidBody2D = game.world._held
		whole.position = game.world.cutting_board.rect().get_center()
		game.world.drop_held(false)
		var generation: Array[RigidBody2D] = [whole]
		for depth in range(3):
			var next: Array[RigidBody2D] = []
			for piece in generation:
				next.append_array(game.world.split_food(piece, Vector2.RIGHT if depth % 2 == 0 else Vector2.DOWN, Vector2.INF, 4))
			generation = next
			await process_frame
		game.world._pickup(generation[0])
		game.world.begin_food_drag(generation[0].position)
		game.world._move_dragged_food(game.world.pan.point(Vector2(810, 560)))
		game.world._finish_food_drag()
		game._notify("每片单独取放，剩下的切块留在菜板上。")
		for frame in range(80): await physics_frame
	elif mode == "panlift":
		game.world.pan.grab(Vector2(610,570))
		game.world.pan.move_pointer(Vector2(690,320))
	elif mode == "plating_full":
		for id in ["egg","mushroom","broccoli"]:
			game.world.spawn_ingredient(game._definition(id))
			game.world.drop_into_pan()
			await create_timer(0.6).timeout
		game._show_plating()
		await process_frame
		for body in game.world._foods.get_children():
			if body.get_meta("enrolled",false): game._plating_canvas.add_to_plate(body)
		game.session.add_garnish("ketchup",8)
		game.session.presentation={"strokes":[{"id":"ketchup","color":"d96143","width":10.0,"amount_ml":8,"points":[[-0.5,0.5],[-0.2,0.65],[0.2,0.65],[0.5,0.5]]}]}
		game._plating_canvas.selected=null
	elif mode == "knife":
		await _stage_knife_scene()
	elif mode == "spatula":
		var tool = game.world._spatula
		tool.active = true
		tool.rotation = -PI/3
		tool.queue_redraw()
		tool.position = Vector2(826, 607)
		tool.stir_sweep(Vector2(750, 628), tool.position)
		game.world.focus_changed.emit("锅铲", "按住铲柄拖入锅中，左右推拌、向上翻动；松开放回锅边")
		await physics_frame
		await physics_frame
	elif mode == "spoon":
		var spoon=game.world.utensils[2]
		spoon.active=true
		spoon.rotation=-0.22
		spoon.position=Vector2(820,565)
		spoon._set_bowl_enabled(true)
		var food=game.world._foods.get_child(0)
		food.global_position=spoon.to_global(Vector2(-25,-5))
		food.linear_velocity=Vector2.ZERO
		for i in range(8): await physics_frame
		game.world.focus_changed.emit("木勺","食物由勺面与前缘包住；轻移承托，快速甩动或倾斜会滑出")
	elif mode == "faucet":
		game.world.pan.move_to(Vector2(game.world.pan.SINK_X-809,game.world.pan.HOME.y))
		game.world.pan.faucet_amount=0.82
		for i in range(8): await physics_frame
	elif mode == "faucet_overflow":
		game.world.clear_food()
		game.session.clear_dish()
		game.world.pan.move_to(Vector2(game.world.pan.SINK_X-809,game.world.pan.HOME.y))
		game.world.pan.water_ml = game.world.PAN_CAPACITY_ML - 8.0
		game.world.pan.faucet_amount = 1.0
		await create_timer(0.3).timeout
	elif mode == "shelf_last":
		game.storage_display.fridge_offset = game.storage_display._fridge_max_offset()
		game.storage_display.fridge_target = game.storage_display.fridge_offset
		game.storage_display._build_items()
	elif mode in ["seasoning", "seasoning_powder", "seasoning_pour", "overflow"]:
		await _stage_seasoning_scene(mode)
	elif mode == "water":
		game.world.set_process(false)
		game.world.pan.active = true
		for body in game.world._foods.get_children():
			if body.get_meta("enrolled", false):
				body.set_meta("pan_origin", body.position)
				body.freeze = true
				game.world.pan._carried.append(body)
		game.world.pan.move_to(-509)
		game.world.pan.release_pan()
		game.world.pan.water_ml = 900
		game.world.pan.faucet_on = true
		game._notify("握住锅柄拖到左侧水槽；拖动右侧把手转开水流，回到灶台加热。")
	elif mode == "review":
		game.session.dish = [{"id":"mushroom", "heat":15, "cut":true}]
		game.session.current_customer = game.session.customers[1].duplicate(true)
		await game._serve()
	elif mode == "poster":
		game._show_poster()
	elif mode == "cookbook":
		game._show_cookbook()
	elif mode == "diy_blank":
		game.world.clear_food()
		game.session.clear_dish()
		game._last_dish = {}
		game._new_diy_recipe()
	elif mode in ["recipe", "collage", "tape"]:
		game.world.spawn_ingredient(game._definition("egg"))
		game.world.drop_into_pan()
		for frame in range(45):
			await physics_frame
		game._last_dish = game.session.plate()
		game._show_recipe_editor()
		if mode in ["collage", "tape"]:
			game._title_input.text = "一份晒过太阳的午餐"
			game._notes_input.text = "番茄切好，慢慢下锅。把今天的阳光也装进盘子里。"
			var paper = game._recipe_canvas
			paper.add_text("一份晒过太阳的午餐", Color("64422e"))
			paper.stickers[-1].position = [0.5, 0.16]
			paper.stickers[-1].scale = 0.15
			paper.add_ingredient(game._definition("tomato"))
			paper.stickers[-1].position = [0.34, 0.50]
			paper.stickers[-1].scale = 0.20
			paper.add_ingredient(game._definition("egg"))
			paper.stickers[-1].position = [0.57, 0.53]
			paper.stickers[-1].scale = 0.18
			paper.rotate_selected(-0.3)
			paper.add_text("切一点番茄，留一点时间。", Color("806643"))
			paper.stickers[-1].position = [0.50, 0.84]
			paper.add_sticker("leaf")
			paper.stickers[-1].position = [0.76, 0.27]
			paper._layout_layers()
			paper.selected_index = -1
			paper.queue_redraw()
			if mode == "tape":
				paper.add_sticker("tape")
				paper.stickers[-1].position = [0.23, 0.30]
				paper.set_tape_length(2.5)
				paper.set_tape_width(1.2)
				paper.set_tape_color(Color("bd715d"))
				paper.rotate_selected(-0.22)
				paper.add_sticker("tape")
				paper.stickers[-1].position = [0.74, 0.69]
				paper.set_tape_length(3.5)
				paper.set_tape_width(0.8)
				paper.set_tape_color(Color("69857c"))
				paper.rotate_selected(0.18)
	elif mode == "pantry":
		game._show_pantry()
	elif mode == "intro":
		game._show_intro()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output: String = args[0] if not args.is_empty() else "user://preview.png"
	var img: Image = root.get_texture().get_image()
	var error: Error = img.save_png(output)
	if mode == "knife":
		var detail: Image = img.get_region(Rect2i(342, 547, 276, 115))
		detail.resize(828, 345, Image.INTERPOLATE_NEAREST)
		detail.save_png(output.get_basename() + "_detail.png")
	print("Preview capture: %s (error %d)" % [output, error])
	game.world.audio.muted = true
	await create_timer(0.14).timeout
	game.queue_free()
	await process_frame
	quit(0 if error == OK else 1)

func _stage_seasoning_scene(mode: String) -> void:
	# Screenshot staging avoids moving the user's OS cursor for an offscreen window.
	# Input behavior is covered separately by test_seasoning.gd.
	var ingredient_id := "salt" if mode == "seasoning_powder" else ("soy_sauce" if mode == "seasoning_pour" else "ketchup")
	game.world.spawn_ingredient(game._definition(ingredient_id))
	game.world.set_process(false)
	game.world._held.global_position = Vector2(810, 458)
	game.world._held.rotation = PI
	game.world._squeezing = true
	game.world._time = 0.19
	game.world._dispense_seasoning()
	if mode == "overflow":
		for i in range(9): game.world._dispense_seasoning()
	game.world._sync_held_foreground()
	game.world.queue_redraw()
	for frame in range(34):
		await physics_frame
	game.world._update_landed_seasoning()
	game.world.queue_redraw()

func _stage_knife_scene() -> void:
	game.world.spawn_ingredient(game._definition("ketchup"))
	game.world._held.global_position = Vector2(809, 500)
	game.world._dispense_ketchup()
	game.world.discard_held()
	for frame in range(45):
		await physics_frame
	game.world.spawn_ingredient(game._definition("tomato"))
	var tomato: RigidBody2D = game.world._held
	game.world.drop_held(false)
	tomato.global_position = Vector2(470, 610)
	tomato.freeze = true
	game.world.pickup_knife()
	game.world._perform_knife_sweep(Vector2(470, 568), Vector2(470, 648))
	for frame in range(24):
		await physics_frame
	game.world.set_controls_enabled(false)
	game.world._knife_visual.global_position = Vector2(470, 563)
	game._notify("实际刀刃切开番茄：两个独立碰撞碎块，质量守恒。")
