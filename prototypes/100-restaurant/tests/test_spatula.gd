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
	game.configure({"repository_path": "user://spatula_test_%s/cookbook.json" % Crypto.new().generate_random_bytes(16).hex_encode()})
	root.add_child(game)
	await process_frame
	game._start_shift()
	var world = game.world
	world.spawn_ingredient(game._definition("tomato"))
	var tomato: RigidBody2D = world._held
	world.drop_into_pan()
	await create_timer(0.7).timeout
	_expect(game.session.dish.size() == 1, "fixture ingredient actually lands in pan")
	var tool = world._spatula
	_expect(tool.visible and not tool.active, "spatula rests visibly next to stove")
	var mass := tomato.mass
	var home: Vector2 = tool.position
	_mouse(tool.to_global(Vector2(-24, 0)), "down")
	await process_frame
	_expect(tool.active and world.get_held_name() == "锅铲", "pressing the exposed spatula above its cup grabs the correct tool")
	await create_timer(0.8).timeout
	_expect(absf(angle_difference(tool.rotation, tool.cooking_angle()))<0.15, "pickup settles into a comfortable cooking angle")
	_expect(not world.spawn_ingredient(game._definition("egg")) and not world.pickup_knife(), "spatula occupies the hand exclusively")
	# Contact fixture: put the real tool below real food, then lift its hand target.
	tool.grip.target_angle=0
	tool.rigid.position=Vector2(800,670)
	tool.rigid.rotation=0
	tool.rigid.linear_velocity=Vector2.ZERO
	tool.rigid.angular_velocity=0
	tool.grip.target=tool.rigid.to_global(tool.grip.local_anchor)
	tomato.position=Vector2(785,627)
	tomato.linear_velocity=Vector2.ZERO
	tomato.angular_velocity=0
	await create_timer(0.6).timeout
	_expect(tool.rigid.get_colliding_bodies().has(tomato), "solid spatula face physically supports the food")
	var center: Vector2=tomato.position
	var target: Vector2=tool.grip.target
	for i in 60:
		tool.grip.target=target+Vector2(0,-60)*(i+1)/60.0
		await physics_frame
	await create_timer(0.3).timeout
	_expect(tomato.position.y<center.y-30 and not tomato.freeze, "native face contact lifts independent food")
	_expect(tomato.mass==mass and not tomato.get_meta("cut"), "contact preserves mass and does not cut")
	_expect(world._foods.get_child_count()==1, "contact never duplicates food")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_E
	Input.parse_input_event(key)
	await process_frame
	_expect(not game.session.heating, "held spatula E never toggles stove")
	_mouse(Vector2(1400, 300), "up")
	await process_frame
	_expect(not tool.active and not tool.docked and not tool.rigid.freeze, "release outside cup leaves the spatula as a free physical object")
	_mouse(Vector2(900, 580), "idle")
	await process_frame
	var released_target: Vector2 = tool.grip.target
	_mouse(Vector2(1400, 230), "idle")
	await create_timer(1.7).timeout
	_expect(not tool.grip.enabled and not tool.docked and tool.grip.target == released_target, "quick release finishes at the release target; later hover never moves the tool")
	_expect(tool.stir_sweep(Vector2(740, 600), Vector2(870, 600)) == 0, "idle tool cannot apply impulses")
	_expect(world.audio.stir_profile(game._definition("beef"))=="meat", "meat has a heavier contact profile")
	_expect(world.audio.stir_profile(game._definition("bread"))=="dry", "grain has a dry brushing profile")
	_expect(world.audio.stir_profile(game._definition("rock"))=="hard", "strange hard objects have a restrained knock profile")
	await create_timer(0.8).timeout
	_expect(is_instance_valid(tomato), "independent ingredient survives release")
	# Begin the independent modal/focus checks from a settled exposed head.
	tool.dock()
	_mouse(tool.to_global(Vector2(-24, 0)), "down")
	await process_frame
	_expect(tool.active, "modal fixture picks the exposed tool")
	var poster_key := InputEventKey.new()
	poster_key.pressed = true
	poster_key.physical_keycode = KEY_P
	poster_key.keycode = KEY_P
	Input.parse_input_event(poster_key)
	await process_frame
	_expect(game.modal.visible and not tool.active, "actual poster shortcut opens editor and releases spatula")
	_mouse(tool.to_global(Vector2(-24, 0)), "down")
	await process_frame
	_expect(not tool.active, "modal prevents tool pickup through UI")
	_mouse(home, "up")
	game._close_modal()
	tool.dock()
	await process_frame
	_mouse(tool.to_global(Vector2(-24, 0)), "down")
	await process_frame
	tool.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_expect(not tool.active, "window focus loss releases tool")
	_mouse(home, "up")
	tool.dock()
	await process_frame
	# The wooden spoon has an actual open U collision instead of a visual-only
	# overlap. A small ingredient can sit between its two sides and bottom.
	var spoon=world.utensils[2]
	var spoon_home: Vector2=spoon.position
	_mouse(spoon.to_global(Vector2(-24,0)),"down")
	await physics_frame
	await process_frame
	_expect(spoon.active and spoon._bowl_shapes.size()==3,"wooden spoon enables three physical bowl edges")
	var enabled:=true
	for shape in spoon._bowl_shapes: enabled=enabled and not shape.disabled
	_expect(enabled,"spoon bowl collisions are active outside the cup")
	# A quarter, rather than an oversized whole tomato, fits in the spoon bowl.
	tomato.position=Vector2(1210,730)
	tomato.freeze=true
	tomato.set_meta("on_board",true)
	var halves: Array=world.split_food(tomato,Vector2.RIGHT,Vector2.INF,4)
	var quarters: Array=world.split_food(halves[0],Vector2.DOWN,Vector2.INF,4)
	var morsel: RigidBody2D=quarters[0]
	morsel.stop_board_settle()
	morsel.set_meta("on_board",false)
	morsel.freeze=false
	spoon.grip.target_angle=0
	spoon.rigid.position=Vector2(710,550)
	spoon.rigid.rotation=0
	spoon.rigid.linear_velocity=Vector2.ZERO
	spoon.rigid.angular_velocity=0
	spoon.grip.target=spoon.rigid.to_global(spoon.grip.local_anchor)
	morsel.position=Vector2(685,525)
	morsel.linear_velocity=Vector2.ZERO
	morsel.angular_velocity=0
	await create_timer(0.7).timeout
	_expect(spoon.rigid.get_colliding_bodies().has(morsel),"finite spoon bowl supports a fitting cut morsel")
	var spoon_food_start:=morsel.position
	var spoon_target: Vector2=spoon.grip.target
	for i in 90:
		spoon.grip.target=spoon_target+Vector2(55,0)*(i+1)/90.0
		await physics_frame
	await create_timer(0.4).timeout
	_expect(morsel.position.x>spoon_food_start.x+25 and spoon.bowl_contains(morsel),"bowl collisions carry food without magnetic attraction")
	for i in range(14): _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await create_timer(1.3).timeout
	_expect(spoon.rotation>2.0 and not spoon.bowl_contains(morsel),"wrist tilt releases the morsel over the real rim")
	world.spawn_ingredient(game._definition("shrimp"))
	_expect(world._held==null,"held spoon prevents creating an unrelated hand-held item")
	spoon.release_tool()
	await physics_frame
	await process_frame
	_expect(spoon._bowl_body.collision_mask!=0 and not spoon.docked,"spoon left outside retains real bowl contact")
	# Release over the actual cup, rather than invoking the storage helper.
	spoon.active = true
	spoon.rigid.position = Vector2(590,560)
	spoon.grip.target = Vector2(590,560)
	spoon.rigid.linear_velocity = Vector2.ZERO
	spoon.rigid.angular_velocity = 0.0
	var return_start: Vector2 = spoon.rigid.position
	spoon.release_tool()
	_expect(spoon.storing and spoon.rigid.position == return_start and not spoon.docked, "return starts continuously at the released pose")
	await create_timer(2.0).timeout
	_expect(spoon.rigid.collision_layer==0 and spoon.position.is_equal_approx(spoon_home),"stored spoon sits behind the cup with no hidden collision")
	spoon.active = true
	spoon.docked = false
	spoon.grip.target = Vector2(1000,560)
	spoon.release_tool()
	_expect(not spoon.docked, "fast outward pull never docks because its body still lags at the cup")
	spoon.active = true
	spoon.rigid.position = Vector2(590,458)
	spoon.grip.target = Vector2(590,510)
	spoon.release_tool()
	await create_timer(2.0).timeout
	_expect(spoon.docked, "head or handle approaching the cup mouth can be put back without pixel hunting")
	# Isolate the front-object selection fixture from the earlier contact run.
	var overlap_tool = world._spatula
	overlap_tool.dock()
	overlap_tool.docked = false
	overlap_tool.position = world.pan.point(Vector2(1005,578))
	overlap_tool.rigid.position = overlap_tool.position
	overlap_tool.rotation = 0.0
	overlap_tool.rigid.rotation = 0.0
	await physics_frame
	await process_frame
	var overlap_point: Vector2 = overlap_tool.to_global(Vector2(-15,0))
	_expect(overlap_tool.can_pick(overlap_point) and not world.pan.can_grab(overlap_point), "front spatula owns its opaque pixels over the pan handle")
	_mouse(overlap_point, "down")
	await process_frame
	_expect(overlap_tool.active and not world.pan.active, "native pointer routing grabs the visible utensil instead of the pan behind it")
	_mouse(overlap_point, "up")
	game.world.audio.muted = true
	await create_timer(0.14).timeout
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: spatula input and physics, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
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

func _wheel(direction: MouseButton) -> void:
	var e:=InputEventMouseButton.new()
	e.position=root.get_final_transform()*Vector2(500,580)
	e.global_position=e.position
	e.button_index=direction
	e.pressed=true
	e.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)

func _expect(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text)
