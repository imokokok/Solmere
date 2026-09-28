extends SceneTree
## New source integration and actually reachable vegetable stock.
const Art = preload("res://modules/restaurant/assets/sprite_library.gd")
const CutArt = preload("res://modules/restaurant/assets/cut_state_library.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")

func run() -> void:
	var team := Art.team_jpeg_manifest()
	var source_ids := ["potato", "carrot", "onion", "eggplant", "zucchini", "bell_pepper_yellow", "bell_pepper_lavender", "bell_pepper_gold", "bell_pepper_purple", "bell_pepper_brown", "bell_pepper_white", "bell_pepper_orange", "bell_pepper_green"]
	for id in source_ids:
		var entry: Dictionary = team.get(id, {})
		expect(not entry.is_empty() and FileAccess.get_sha256(str(entry.path)) == str(entry.sha256), id + " source JPEG preserved byte for byte")
		var texture := Art.food(id)
		expect(texture != null and texture == Art.team_jpeg_food(id), id + " routed through common sprite source")
		if texture == null: continue
		var pixels := texture.get_image()
		expect(pixels.get_pixel(0, 0).a < 0.01 and pixels.get_pixel(pixels.get_width() - 1, pixels.get_height() - 1).a < 0.01, id + " black matte is transparent")
		expect(Art.body_outline(id).size() >= 3, id + " physical silhouette follows visible art")
	for id in ["egg", "noodles", "bread"]:
		var texture := Art.food(id)
		expect(texture != null and texture == Art.supplementary_food(id), id + " uses labeled new illustration")
		if texture != null: expect(texture.get_image().get_pixel(0, 0).a < 0.01, id + " generated art has transparent margins")
	var game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://team_food_art_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode()})
	root.add_child(game)
	await process_frame
	game._close_modal()
	game.world.audio.muted = true
	for id in source_ids:
		var definition: Dictionary = game._definition(id)
		expect(not definition.is_empty() and definition.category == "basic", id + " stocked as real vegetable")
		game.storage_display.reveal_ingredient(id)
		var slot := game.storage_display.find_child("Ingredient_" + id, true, false) as Button
		expect(slot != null and slot.is_visible_in_tree(), id + " reachable on kitchen shelf")
		if slot == null: continue
		game._take_ingredient(definition)
		var body: RigidBody2D = game.world._held
		expect(body != null and body.get_meta("id") == id, id + " pickup carries same ingredient identity")
		if body != null:
			body.position = slot.get_global_rect().get_center()
			game.world.held_grip.target = body.global_position
			expect(game._return_to_storage(body), id + " returns to original stock slot")
		await process_frame
	for id in source_ids:
		if id.begins_with("bell_pepper") or id == "zucchini":
			expect(CutArt.texture(id, "slice") != null and CutArt.texture(id, "dice") != null, id + " has matching cut-state art")
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: team art, generated staples, real shelf stock, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
