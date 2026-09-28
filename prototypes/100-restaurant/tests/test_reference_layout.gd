extends SceneTree
var game
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")
func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://layout_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode()})
	root.add_child(game)
	await process_frame
	game._close_modal()
	game.world.audio.muted = true
	for id in ["oil", "pepper", "salt", "sugar", "soy_sauce"]:
		var item: Button = game.hud.find_child("Ingredient_"+id, true, false)
		expect(item != null and item.position.x >= 340 and item.position.x < 548 and item.position.y > 440, "condiment comes from the left condiment rack: " + id)
		for other_id in ["oil", "pepper", "salt", "sugar", "soy_sauce"]:
			if other_id == id: break
			var other := game.hud.find_child("Ingredient_" + other_id, true, false) as Button
			expect(item != null and other != null and not item.get_rect().intersects(other.get_rect()), "left condiment footprints stay separate: " + id + " / " + other_id)
	for id in ["ketchup", "mayonnaise", "mustard", "chili_sauce", "vinegar"]:
		var item: Button = game.hud.find_child("Ingredient_"+id, true, false)
		expect(item != null and Rect2(640, 490, 435, 130).encloses(item.get_rect()), "ingredient belongs in the original five-slot tray: " + id)
		expect(item != null and item.get_rect().end.y < 590, "tray click area stays inside its groove: " + id)
		if item != null:
			var art: Node2D = item.get_node("FoodArt")
			var image: Texture2D = preload("res://modules/restaurant/assets/sprite_library.gd").food(id)
			var fitted: Rect2 = preload("res://modules/restaurant/assets/sprite_library.gd").support_rect(id)
			var height := fitted.size.y * art.scale.y
			expect(height >= 68.0 and height <= 77.0, id + " fills most of its rack cubby without losing relative bottle shape")
			expect(absf(item.position.y + art.position.y + fitted.end.y * art.scale.y - 604.0) < 0.5, id + " rests on the inner rack floor behind the 14 pixel front wall")
			expect(absf(item.position.y + art.position.y + art.storage_clip.end.y * art.scale.y - 590.0) < 0.5, id + " front wall occludes its lower body without covering foreground cookware")
			expect(item.position.y + (item.get_node("IngredientName") as Label).position.y >= 590.0, id + " name sits on the rack front below the bottle")
	for child in game.storage_display._content.get_children():
		if child is TextureRect:
			expect(not child.get_rect().intersects(Rect2(635, 590, 425, 39)), "rear rack front is not redrawn over the pan")
	var art_library = preload("res://modules/restaurant/assets/sprite_library.gd")
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/assets/supplementary_manifest.json"))
	for id in ["mayonnaise", "chili_sauce", "vinegar"]:
		var bounds: Array = atlas[id].region
		var source: Image = (load(atlas[id].path) as Texture2D).get_image()
		if source.is_compressed(): source.decompress()
		var expected := source.get_region(Rect2i(bounds[0], bounds[1], bounds[2], bounds[3]))
		var displayed: Image = art_library.food(id).get_image()
		var matches := displayed.get_size() == expected.get_size()
		for y in expected.get_height():
			for x in expected.get_width():
				var pixel := expected.get_pixel(x,y)
				if pixel.a < 0.98: continue
				var edge := false
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if expected.get_pixel(clampi(x+d.x,0,expected.get_width()-1), clampi(y+d.y,0,expected.get_height()-1)).a < 0.02: edge = true
				if not edge and not pixel.is_equal_approx(displayed.get_pixel(x,y)): matches = false
		expect(matches, id + " keeps the hand-painted bottle interior while cleaning its matte fringe")
	expect(art_library.physical_art_scale("mayonnaise") > art_library.physical_art_scale("chili_sauce"), "larger mayonnaise bottle keeps a larger physical scale than narrow chili sauce")
	var faucet_stream := Rect2(194, 560, 12, 175)
	var pull := game.storage_display.find_child("FridgePull", true, false) as Control
	expect(pull != null and not pull.get_global_rect().intersects(faucet_stream), "cabinet pull stays clear of running water")
	expect(game.storage_display.find_child("FridgeNextPage", true, false) == null, "fridge uses spatial browsing without page buttons")
	expect(game._order_paper.position.y <= 140 and game._order_paper.position.y + game._order_paper.size.y >= 440, "order note covers the original blank sheet rather than leaving a top strip")
	expect(game.world.pan.point(Vector2(809, 541)).y > 639.0, "pan opening starts below the rear rack front")
	expect(game.world.cutting_board.rect().encloses(Rect2(game.world._knife_rest_position + Vector2(-93, -24), Vector2(188, 52))), "knife art rests entirely on the cutting board")
	expect(game.world.cutting_board.z_index < game.world.pan.pan_back.z_index and game.world.pan.pan_back.z_index < game.world._foods.z_index and game.world.cutting_board.z_index < game.world._knife_visual.z_index, "raised pan handle, food and knife remain above the cutting board without hiding pan contents")
	for id in ["sock", "confetti", "toilet_paper", "soap"]:
		var item := game.hud.find_child("Ingredient_" + id, true, false) as Button
		if item == null: continue
		var art := item.get_node("FoodArt") as Node2D
		var library = preload("res://modules/restaurant/assets/sprite_library.gd")
		var tex: Texture2D = library.food(id)
		var visible_rect: Rect2 = library.support_rect(id)
		var row := roundi((item.position.y + item.size.y - 300.0) / 105.0)
		var shelf_front := 300.0 + row * 105.0
		var art_bottom := item.position.y + art.position.y + visible_rect.end.y * art.scale.y
		expect(absf(art_bottom - (shelf_front + 5.0)) < 1.0, "odd ingredient rests inside the five pixel shelf lip: " + id)
		var name: Label = item.get_node("IngredientName")
		var name_center := item.position.y + name.position.y + name.size.y * 0.5
		expect(name_center >= shelf_front and name_center <= shelf_front + 14.0, "readable odd name remains centered on the shelf front: " + id)
	for utensil in game.world.utensils:
		expect(utensil.position.x >= 545 and utensil.position.x <= 630 and utensil.home_angle > 1, "utensil rests upright in the source cup")
	expect(game.hud.find_child("ReferenceRecipeBook", true, false) == null and not game._recipe_stand.visible, "removed countertop recipe stand has no hotspot or visible art")
	var book: Button = null
	for child in game.hud.get_node("KitchenActionDock").get_children():
		if child is Button and child.text == "菜谱": book = child
	expect(book != null, "cookbook remains available in the action dock")
	if book != null: book.pressed.emit()
	await process_frame
	expect(game.modal.visible, "dock cookbook opens the working recipe interface")
	game._close_modal()
	game.world.pan.overflow_water_ml = 100
	game.world.spill_pan_water(100, Vector2(480, 716))
	await create_timer(0.3).timeout
	var sponge = game.world.sponge
	_mouse(sponge.position, "down")
	await process_frame
	expect(sponge.active and not game.world.spawn_ingredient(game._definition("tomato")), "sponge can be picked up and owns the hand")
	_mouse(Vector2(480, 736), "move")
	_mouse(Vector2(480, 716), "up")
	await process_frame
	expect(not sponge.active and sponge.absorbed_ml > 0 and sponge.absorbed_ml <= sponge.CAPACITY_ML, "sponge absorbs a finite amount of contacted water")
	await process_frame
	expect(game.world._foods.get_child_count() == 0, "wiped liquid has no ghost physical body")
	var ketchup := game.storage_display.find_child("Ingredient_ketchup", true, false) as Button
	ketchup.tooltip_text = ""
	_mouse(ketchup.get_global_rect().get_center(), "down")
	_mouse(ketchup.get_global_rect().get_center(), "up")
	await process_frame
	expect(is_instance_valid(game.world._held) and game.world._held.get_meta("id", "") == "ketchup", "expanded rack bottle can be picked up in the native window")
	var pan_point: Vector2 = game.world.pan.point(Vector2(800, 535))
	_mouse(pan_point, "move")
	_mouse(pan_point, "down")
	await process_frame
	expect(game.world._squeezing, "holding a rack bottle over the pan starts dispensing without the tray blocking input")
	_mouse(pan_point, "up")
	game.world.discard_held()
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: reference layout and sponge, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
func _mouse(point: Vector2, kind: String) -> void:
	point = root.get_final_transform() * point
	if DisplayServer.get_name() != "headless": Input.warp_mouse(point)
	if kind == "move":
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
	else:
		var button := InputEventMouseButton.new()
		button.position = point
		button.global_position = point
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = kind == "down"
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if button.pressed else 0
		Input.parse_input_event(button)
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
