extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func run() -> void:
	var game=load("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://board_release_%s/book.json" % Crypto.new().generate_random_bytes(12).hex_encode()})
	root.add_child(game); await process_frame; game._start_shift(); game.world.audio.muted=true
	var world=game.world
	world.spawn_ingredient(game._definition("tomato"))
	var fast = world._held
	world.begin_food_drag(Vector2(100, 200), true)
	world._move_dragged_food(Vector2(1120, 740))
	world._finish_food_drag()
	expect(world._pending_drop and fast.position.x < 150, "queued fast drag retains physical motion without teleporting")
	await create_timer(1.8).timeout
	expect(world._held == null and fast.get_meta("on_board", false), "quick fridge-to-board release completes at the intended support surface")
	expect(fast.position.distance_to(Vector2(1120, 740)) < 60, "hand finishes close to the release point, never halfway across the room")
	world._pickup(fast)
	world.discard_held()
	await process_frame
	world.set_process(false)
	world.spawn_ingredient(game._definition("tomato"))
	var whole=world._held
	whole.set_physics_process(false)
	whole.position=Vector2(1200,730); whole.linear_velocity=Vector2(140,0)
	world.drop_held(false,false)
	expect(whole.board_velocity.x>30 and whole.board_settling,"real board drop retains bounded hand momentum")
	expect(whole.board_height==10 and whole.response.rolling,"whole tomato falls onto the support plane before rolling")
	var start: Vector2=whole.position
	var start_rotation: float=whole.rotation
	for i in 45: whole._physics_process(1.0/120.0)
	expect(whole.position.x>start.x+5 and absf(whole.rotation-start_rotation)>0.1,"whole produce translates and rolls instead of freezing on release")
	for i in 480: whole._physics_process(1.0/120.0)
	expect(not whole.board_settling and whole.board_velocity.length()<0.1,"friction brings the released object to rest")
	expect(whole.position.x<start.x+70,"gentle release never launches the object across the board")
	whole.set_meta("cut",true)
	whole.begin_board_settle(Rect2(1100,700,270,60),Vector2(36,0),0.0,10.0)
	expect(not whole.response.rolling,"cut flat faces do not inherit whole fruit rolling")
	for i in 240: whole._physics_process(1.0/120.0)
	expect(not whole.board_settling,"cut food settles without endless spin")
	whole.set_meta("cut",false)
	whole.set_meta("softness",0.8); whole.refresh_response()
	expect(not whole.response.rolling,"soft cooked fruit no longer rolls like firm raw fruit")
	game.queue_free(); await process_frame
	for failure in failures: push_error(failure)
	print("%s: board release, %d checks" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
