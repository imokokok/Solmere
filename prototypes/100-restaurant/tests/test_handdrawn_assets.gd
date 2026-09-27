extends SceneTree
## Source preservation + real scene stock/geometry/dispensing/plate regression.
const Art = preload("res://modules/restaurant/assets/sprite_library.gd")
var game
var checks := 0
var failures: Array[String] = []
var capture_prefix := ""

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")

func run() -> void:
	if not OS.get_cmdline_user_args().is_empty(): capture_prefix = OS.get_cmdline_user_args()[0]
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://handdrawn_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode(), "shift_seconds": 1200.0})
	root.add_child(game)
	await process_frame
	game._close_modal()
	game.world.audio.muted = true
	var manifest := Art.handdrawn_manifest()
	for id in ["mustard", "ketchup", "oil", "salt", "pepper", "mushroom", "resignation_letter", "alarm_clock", "yarn_ball", "tennis_ball", "dentures", "eraser", "sponge", "sock", "confetti", "toilet_paper", "soap", "soap_smooth", "toothpaste"]:
		expect(manifest.has(id), id + " supplied original registered")
	await capture("kitchen")
	var world = game.world
	for id in manifest:
		var entry: Dictionary = manifest[id]
		expect(FileAccess.get_sha256(entry.path) == entry.sha256, id + " source is byte-identical to supplied PNG")
		var texture := Art.food(id)
		var b: Array = entry.bounds
		expect(texture != null and texture.get_size() == Vector2(b[2], b[3]), id + " uses visible bounds, not full empty canvas")
		var source: Texture2D = load(entry.path)
		var pixels := source.get_image()
		if pixels.is_compressed(): pixels.decompress()
		expect(texture.get_image().get_data() == pixels.get_region(Rect2i(b[0], b[1], b[2], b[3])).get_data(), id + " runtime keeps authored colour and alpha edges")
		game.storage_display.reveal_ingredient(id)
		var slot := game.storage_display.find_child("Ingredient_" + id, true, false) as Button
		expect(slot != null and slot.is_visible_in_tree(), id + " available on its kitchen shelf page")
		if slot == null: continue
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = slot.size / 2
		slot.gui_input.emit(press)
		var body: RigidBody2D = world._held
		expect(is_instance_valid(body) and body.get_meta("id") == id, id + " visible slot picks up real body")
		if not is_instance_valid(body): continue
		expect(slot.disabled and not slot.get_node("FoodArt").visible, id + " taking the only object empties its slot")
		expect(body.get_node("FoodArt").definition.id == id and body.get_meta("fragment_polygon") == Art.body_outline(id), id + " physical shape and visual share authored coordinates")
		var uid: String = body.get_meta("instance_uid")
		if entry.has("nozzle_uv"):
			world._dragging = false
			body.position = world.pan.point(Vector2(810, 530))
			world._squeezing = true
			world.squeeze_pressure = 0.8
			world._sync_held_foreground()
			var rect := Art.fit(texture, Vector2.ZERO, Vector2(78, 78))
			var uv: Array = entry.nozzle_uv
			var tip := rect.position + rect.size * Vector2(uv[0], uv[1])
			var actual: Vector2 = world._held_proxy.transform * tip
			var expected: Vector2 = world.get_global_transform_with_canvas() * world.to_local(world._nozzle_world_position())
			expect(actual.distance_to(expected) < 0.01, id + " stream attaches to rendered mouth after deformation and rotation")
			expect(world._nozzle_world_position().y > body.global_position.y, id + " mouth faces the pan")
			if id == "ketchup" and not capture_prefix.is_empty():
				world.set_process(false)
				await capture("dispensing")
				world.set_process(true)
			var before := float(body.get_meta("remaining_ml"))
			var portion: RigidBody2D = world._dispense_seasoning(3.0)
			expect(portion != null and is_equal_approx(float(body.get_meta("remaining_ml")), before - 3.0), id + " measured output comes from actual container")
			expect(portion.get_node_or_null("SauceBlob") != null and portion.get_meta("liquid_state").source_id == uid, id + " output is sauce/powder, never a miniature bottle image")
			world._stop_squeezing()
			portion.queue_free()
		body.position = slot.get_global_rect().get_center()
		world._dragging = false
		expect(game._return_to_storage(body), id + " unprocessed item returns to its original empty slot")
		game._take_ingredient(game._definition(id))
		expect(world._held == body and body.get_meta("instance_uid") == uid, id + " re-taking keeps original identity")
		body.position = slot.get_global_rect().get_center()
		game._return_to_storage(body)
		await process_frame
		game.session.dish.clear()

	# Hard items accept a pan but not an impossible knife cut.
	for id in ["alarm_clock", "dentures"]:
		game._take_ingredient(game._definition(id))
		var hard: RigidBody2D = world._held
		hard.position = world.cutting_board.rect().get_center()
		world.drop_held(false)
		expect(world.split_food(hard).is_empty() and is_instance_valid(hard), id + " remains intact under a kitchen knife")
		world._pickup(hard)
		world.drop_into_pan()
		await create_timer(0.5).timeout
		expect(hard.get_meta("enrolled", false), id + " remains a usable odd ingredient")
		world.food_removed_from_pan.emit(hard)
		hard.queue_free()
		await process_frame

	# Same hand-drawn mushroom -> clipped pieces -> heat -> actual plate -> photo.
	game._take_ingredient(game._definition("mushroom"))
	var whole: RigidBody2D = world._held
	var mass := whole.mass
	whole.position = world.cutting_board.rect().get_center()
	world.drop_held(false)
	var parts: Array = world.split_food(whole, Vector2.RIGHT, Vector2.INF, 4)
	await process_frame
	expect(parts.size() == 2, "hand-drawn mushroom is physically sliced")
	if parts.size() == 2:
		expect(is_equal_approx(parts[0].mass + parts[1].mass, mass), "authored mushroom cutting conserves mass")
		await capture("sliced")
		var saved: Dictionary = {}
		for part in parts: saved[part.get_instance_id()] = part.get_meta("fragment_polygon").duplicate()
		for fragment in parts:
			world._pickup(fragment)
			world.drop_into_pan()
			await create_timer(0.4).timeout
		await create_timer(1.0).timeout
		expect(game.session.dish.size() == 2, "individually dropped mushroom pieces enter the pan")
		# Independent drops can correctly settle apart. Build a real contact pair
		# before testing contact heat, rather than assuming one landing arrangement.
		for i in parts.size():
			parts[i].stop_board_settle()
			parts[i].freeze=true
			parts[i].lock_rotation=true
			parts[i].rotation=0.0
			parts[i].linear_velocity=Vector2.ZERO
			parts[i].angular_velocity=0.0
			parts[i].position=world.pan.point(Vector2(810,560))+Vector2(0,-65*i)
		await physics_frame
		await physics_frame
		for part in parts: part.freeze=false
		await create_timer(1.2).timeout
		var touching: bool = parts[0].get_colliding_bodies().has(parts[1])
		print("CONTACT_PAIR touching=",touching," positions=",parts[0].position,",",parts[1].position)
		expect(touching, "thermal fixture establishes actual native contact between mushroom pieces")
		var thermal = preload("res://modules/restaurant/domain/food_thermal.gd")
		var sa: Dictionary = world.reactions.ensure_state(parts[0])
		var sb: Dictionary = world.reactions.ensure_state(parts[1])
		var ca: float = parts[0].mass * float(thermal.profile(parts[0].get_meta("definition")).cp) * 0.56
		var cb: float = parts[1].mass * float(thermal.profile(parts[1].get_meta("definition")).cp) * 0.56
		sa.core_c=120.0
		sb.core_c=22.0
		world.reactions._exchange_food_heat(parts,0.25)
		print("CONTACT_HEAT cores=",sa.core_c,",",sb.core_c)
		expect(absf(float(sa.core_c)*ca+float(sb.core_c)*cb-(120.0*ca+22.0*cb))<0.00001, "food contact transfers equal and opposite thermal energy")
		expect(float(sa.core_c)<120 and float(sb.core_c)>22 and float(sb.core_c)<float(sa.core_c), "stacked food warms only through its real contact without equalising instantly")
		sa.core_c=22.0
		sb.core_c=22.0
		game.session.set_heating(true)
		preload("res://tests/thermal_fixture.gd").cook(game,45.0)
		world.set_dish(game.session.dish, game.session.ingredients)
		for part in parts:
			expect(part.get_node("FoodArt").heat >= 6 and part.get_meta("fragment_polygon") == saved[part.get_instance_id()], "cooked mushroom retains authored slices and heat")
			part.lock_rotation=false
		game._interact("plate")
		game._plate_bodies(parts)
		for part in parts:
			expect(part.get_meta("plated", false) and game._plating_canvas._visuals[part.get_instance_id()].art.definition.id == "mushroom", "plate inherits the real hand-drawn fragments")
		await capture("plated")
		await process_frame
		for record in game._plating_canvas._visuals.values():
			expect(((record.art.position - game._plating_canvas.center()) / game._plating_canvas.radius()).length() < 0.9, "opening/resizing plate keeps food on the plate, not clipped offscreen")
		if not capture_prefix.is_empty():
			await game._photograph_plating()
			expect(not game._photo.is_empty(), "GPU photography captures actual hand-drawn plate")
			var photo := Image.new()
			photo.load_png_from_buffer(Marshalls.base64_to_raw(game._photo))
			expect(photo.save_png(capture_prefix + "-photo.png") == OK, "real photograph saved for inspection")
	game.queue_free()
	await process_frame
	if not capture_prefix.is_empty(): await gallery(manifest)
	for failure in failures: push_error(failure)
	print("%s: hand-drawn assets, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func gallery(manifest: Dictionary) -> void:
	var page := 0
	var ids := manifest.keys()
	while page * 14 < ids.size():
		await gallery_page(manifest, ids.slice(page * 14, mini(ids.size(), (page + 1) * 14)), page)
		page += 1

func gallery_page(manifest: Dictionary, ids: Array, page: int) -> void:
	var background := ColorRect.new()
	background.color = Color("fff0d6")
	background.size = Vector2(1600, 946)
	root.add_child(background)
	var index := 0
	for id in ids:
		var view := TextureRect.new()
		view.texture = Art.food(id)
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		view.position = Vector2(40 + (index % 7) * 222, 40 + (index / 7) * 420)
		view.size = Vector2(170, 300)
		background.add_child(view)
		var label := Label.new()
		label.text = str(manifest[id].get("display_name", manifest[id].source_name)).trim_suffix(".png")
		label.add_theme_font_override("font", preload("res://modules/restaurant/assets/fonts/noto_serif_sc.ttf"))
		label.add_theme_color_override("font_color", Color("493b2d"))
		label.position = view.position + Vector2(0, 310)
		background.add_child(label)
		index += 1
	await capture("gallery" if page == 0 else "gallery-%d" % (page + 1))
	background.queue_free()
	await process_frame

func capture(label: String) -> void:
	if capture_prefix.is_empty(): return
	if DisplayServer.get_name() == "headless":
		expect(false, "capture requires GPU")
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(capture_prefix + "-" + label + ".png") == OK, "GPU capture " + label)

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
