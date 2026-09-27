extends SceneTree
var game
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	Engine.max_fps = 120
	call_deferred("run")
func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://free_pan_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode()})
	root.add_child(game)
	await process_frame
	game._start_shift()
	game.world.spawn_ingredient(game._definition("tomato"))
	var food = game.world._held
	game.world.drop_into_pan()
	await create_timer(0.6).timeout
	var initial: Vector2 = food.position
	var first_handle: Vector2=game.world.pan.point(Vector2(1000,566))
	mouse(first_handle, MOUSE_BUTTON_LEFT, true)
	for i in 90:
		motion(first_handle+Vector2(-70,-250)*(i+1)/90.0)
		await physics_frame
	await create_timer(0.6).timeout
	expect(game.world.pan.offset.y < game.world.pan.HOME.y - 235, "native pan follows a deliberate upward drag")
	expect(food.position.y < initial.y - 210 and not food.freeze, "colliders lift independent contents")
	expect(not game.world.pan.on_stove(), "raised pan does not receive stove heat")
	mouse(first_handle+Vector2(-70,-250), MOUSE_BUTTON_LEFT, false)
	await process_frame
	expect(game.world.pan.falling, "released raised pan falls under gravity")
	await create_timer(1.3).timeout
	expect(not game.world.pan.falling and absf(game.world.pan.offset.y-game.world.pan.HOME.y) < 2.0, "pan lands on counter and stops following pointer")
	expect(game.session.dish.size() == 1, "gravity landing preserves ingredients")
	# Stage the bowl above the plate using a deliberate lift and transfer.
	var pan=game.world.pan
	var handle: Vector2=pan.point(Vector2(1000,566))
	mouse(handle,MOUSE_BUTTON_LEFT,true)
	var lift_target: Vector2=handle+Vector2(0,-240)
	for i in 90:
		motion(handle.lerp(lift_target,(i+1)/90.0))
		await physics_frame
	await create_timer(0.4).timeout
	# Pointer must move around the preserved local grip while the wrist rotates.
	var pivot: Vector2=Vector2(1355,430)
	for i in 150:
		var t:=float(i+1)/150.0
		pan.set_angle(t*deg_to_rad(105))
		var desired: Vector2=pivot+pan.grip.local_anchor.rotated(t*deg_to_rad(105))
		motion(lift_target.lerp(desired,t))
		await physics_frame
	await create_timer(1.3).timeout
	expect(pan.angle > 1.5, "wrist target tilts a force-held native pan")
	expect(food.get_meta("plated", false), "gravity pours original food into plate")
	expect(game.session.dish.size() == 1 and int(game.session.dish[0].physics_id) == food.get_instance_id(), "poured food retains identity without duplication")
	print("POUR_METRICS pan=",pan.rigid.position," food=",food.position," plate=",game.world.plate.center)
	pan.release_pan()
	game.world.audio.muted = true
	await create_timer(0.2).timeout
	game.queue_free()
	await process_frame
	for f in failures: push_error(f)
	print("%s free pan %d checks" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
func expect(ok:bool,text:String)->void:
	checks+=1
	if not ok:failures.append(text)
func mouse(p:Vector2,button:MouseButton,down:bool)->void:
	var e:=InputEventMouseButton.new()
	e.position=root.get_final_transform()*p
	e.global_position=e.position
	e.button_index=button
	e.pressed=down
	e.button_mask=MOUSE_BUTTON_MASK_LEFT if down or button==MOUSE_BUTTON_RIGHT else 0
	Input.parse_input_event(e)
func motion(p:Vector2)->void:
	var e:=InputEventMouseMotion.new()
	e.position=root.get_final_transform()*p
	e.global_position=e.position
	e.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
