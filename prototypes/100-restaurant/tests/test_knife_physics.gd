extends SceneTree
## Focused regression tests for actual knife sweeps and independent food fragments.

var game
var failures: Array = []
var checks: int = 0

func _initialize() -> void:
	Engine.max_fps = 120
	root.size = Vector2i(1600, 900)
	call_deferred("_run")

func _run() -> void:
	game = load("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://knife_test_%s/cookbook.json" % Crypto.new().generate_random_bytes(16).hex_encode()})
	root.add_child(game)
	await process_frame
	game._close_modal()
	var world = game.world
	_expect(world.spawn_ingredient(game._definition("tomato")), "tomato spawns for cutting")
	var original: RigidBody2D = world._held
	var original_mass: float = original.mass
	_expect(not world.pickup_knife(), "hands cannot hold ingredient and knife simultaneously")
	world.drop_held(false)
	original.global_position = Vector2(1210, 725)
	original.set_deferred("position", original.position)
	original.freeze = true
	original.set_meta("saved_heat", 7.5)
	_expect(world.pickup_knife(), "knife can be picked up after food is placed")
	world._perform_knife_sweep(Vector2(350, 550), Vector2(390, 550))
	_expect(_fragments().is_empty(), "knife swipe missing the food does not cut")
	world._perform_knife_sweep(Vector2(1210, 685), Vector2(1210, 765))
	var halves: Array = _fragments()
	_expect(halves.size() == 2, "knife blade crossing food creates two separate pieces")
	if halves.size() != 2:
		await _finish()
		return
	_expect(original.is_queued_for_deletion(), "original whole ingredient is removed after splitting")
	_expect(halves[0].get_instance_id() != halves[1].get_instance_id(), "cut fragments have distinct physics identities")
	_expect(is_equal_approx(halves[0].mass + halves[1].mass, original_mass), "two halves conserve original mass")
	for half in halves:
		_expect(half is RigidBody2D and bool(half.get_meta("cut", false)), "each half is an independently cut rigid body")
		_expect(is_equal_approx(float(half.get_meta("saved_heat", 0.0)), 7.5), "cutting preserves previous cooking time")
		_expect(half.get_child(0).shape is ConvexPolygonShape2D, "fragment collision shape follows its cut polygon")
	_expect(game.session.dish.is_empty(), "cutting on the board does not enroll food in the pan")
	world.put_knife_back()
	await process_frame
	var quarters: Array = []
	for half in halves:
		half.global_position = Vector2(1210, 725)
		half.freeze = true
		var result: Array = world.split_food(half, Vector2.UP)
		quarters.append_array(result)
	_expect(quarters.size() == 4, "each half can be split once more into four independent quarters")
	var total_mass: float = 0.0
	for quarter in quarters:
		total_mass += quarter.mass
		quarter.global_position = Vector2(1210, 725)
		quarter.freeze = true
		_expect(world.split_food(quarter).is_empty(), "fragment depth cap prevents endless splitting")
	_expect(is_equal_approx(total_mass, original_mass), "repeated cuts conserve total ingredient mass")
	await process_frame
	if quarters.is_empty():
		await _finish()
		return
	world._pickup(quarters[0])
	world.begin_food_drag(world.to_local(quarters[0].global_position))
	_expect(world._drag_group.is_empty(), "picking one quarter does not magnetically collect its siblings")
	for sibling in quarters.slice(1): _expect(sibling.freeze, "untouched sibling remains on the board")
	world.drop_into_pan()
	await create_timer(0.4).timeout
	for quarter in quarters.slice(1):
		world._pickup(quarter)
		world.drop_into_pan()
		await create_timer(0.4).timeout
	_expect(world._drag_group.is_empty() and world._held == null, "all four independent releases leave no hidden held pieces")
	for frame in range(120):
		await physics_frame
		if game.session.dish.size() == 4:
			break
	_expect(game.session.dish.size() == 4, "individual drops retain every independent quarter")
	var ids: Dictionary = {}
	for entry in game.session.dish:
		ids[entry.get("physics_id", 0)] = true
		_expect(str(entry.get("id", "")) == "tomato" and bool(entry.get("cut", false)), "pan enrollment preserves original ingredient identity and cut flag")
		_expect(is_equal_approx(float(entry.get("heat", 0.0)), 7.5), "pan enrollment restores fragment cooking history")
	_expect(ids.size() == 4, "all four fragments remain distinct in domain-to-physics mapping")
	game._interact("trash")
	await process_frame
	_expect(world.spawn_ingredient(game._definition("ketchup")), "condiment bottle available for cutting rejection test")
	var bottle: RigidBody2D = world._held
	world.drop_held(false)
	bottle.global_position = Vector2(1210, 725)
	bottle.freeze = true
	_expect(world.split_food(bottle).is_empty(), "knife cannot convert a condiment container into food fragments")
	await _finish()

func _fragments() -> Array:
	var result: Array = []
	for body in game.world._foods.get_children():
		if not body.is_queued_for_deletion() and int(body.get_meta("cut_depth", 0)) > 0:
			result.append(body)
	return result

func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _finish() -> void:
	game.world.audio.muted = true
	await create_timer(0.14).timeout
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: knife physics, %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(str(failure))
		print("FAIL: knife physics, %d / %d checks" % [failures.size(), checks])
		quit(1)
