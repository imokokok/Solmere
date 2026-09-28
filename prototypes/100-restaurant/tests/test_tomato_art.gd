extends SceneTree
## The supplied tomato keeps its pixels and reaches the real kitchen and recipe.
const Art = preload("res://modules/restaurant/assets/sprite_library.gd")
const CutArt = preload("res://modules/restaurant/assets/cut_state_library.gd")
const SOURCE := "res://docs/supplied_assets/20260925-tomato/tomato-original.jpg"
const DERIVED := "res://modules/restaurant/assets/derived/tomato.png"
const CROP := Rect2i(417, 472, 198, 176)
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")

func run() -> void:
	check(FileAccess.get_sha256(SOURCE) == "682335f386a407c78cd7141c0049c4e9c37c2f83cd019be4cb2eeba17cd0bea9", "the user-supplied JPEG is unchanged")
	check(FileAccess.get_sha256(DERIVED) == "a272899150076014d879f3c58068e848f4e1675690237d8cdc113965ea5e663e", "the active tomato matches the approved alpha-only derivative")
	var original := Image.load_from_file(SOURCE).get_region(CROP)
	var texture: Texture2D = Art.food("tomato")
	check(texture != null and texture == Art.supplied_tomato_food(), "shared art entry uses the supplied tomato rather than the legacy atlas")
	var current := texture.get_image()
	check(current.get_size() == CROP.size, "sprite crops empty source canvas without scaling brushwork")
	var preserved := true
	var partly_transparent := 0
	for y in current.get_height():
		for x in current.get_width():
			var a := original.get_pixel(x, y)
			var b := current.get_pixel(x, y)
			if b.a >= 0.98 and Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b)) > 0.008:
				var boundary := false
				for dy in range(-1,2):
					for dx in range(-1,2):
						if current.get_pixel(clampi(x+dx,0,current.get_width()-1),clampi(y+dy,0,current.get_height()-1)).a < 0.02: boundary = true
				if not boundary: preserved = false
			if b.a > 0.01 and b.a < 0.99: partly_transparent += 1
	check(preserved, "interior original brushwork stays intact while only the outer matte fringe is decontaminated")
	check(current.get_pixel(0, 0).a == 0.0 and current.get_pixel(90, 80).a > 0.99 and partly_transparent > 10, "white matte is transparent with a soft antialias edge")
	check(Art.body_outline("tomato").size() >= 3 and Art.alpha_at("tomato", Vector2.ZERO) > 0.9, "collision and hit testing use the new tomato silhouette")
	check(CutArt.texture("tomato", "slice") != null and CutArt.texture("tomato", "dice") != null, "tomato cut faces remain available")
	var game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://tomato_art_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode()})
	root.add_child(game)
	await process_frame
	game._close_modal()
	game.world.audio.muted = true
	var slot: Button = game.storage_display.find_child("Ingredient_tomato", true, false)
	check(slot != null and slot.is_visible_in_tree(), "new tomato is visible on fridge page one")
	check((slot.get_node("IngredientName") as Label).z_index > 0 and game.modal.z_index > (slot.get_node("IngredientName") as Label).z_index, "fridge labels remain readable below open recipe paper")
	await capture("kitchen")
	game._take_ingredient(game._definition("tomato"))
	var body: RigidBody2D = game.world._held
	check(is_instance_valid(body) and body.get_meta("fragment_polygon") == Art.body_outline("tomato"), "taken tomato is the same physical food as its artwork")
	body.position = game.world.cutting_board.rect().get_center() + Vector2(-105, 9)
	game.world.drop_held(false)
	await capture("board")
	var parts: Array = game.world.split_food(body, Vector2.RIGHT, Vector2.INF, 4)
	await process_frame
	check(parts.size() == 2 and parts[0].get_meta("id") == "tomato", "the supplied whole tomato cuts into real tomato pieces")
	await capture("cut")
	game._view_recipe(game.RecipeMethod.starter())
	await capture("recipe")
	var player_recipe := {"title":"今晚这一锅 · 番茄蛋蘑菇", "author":"主厨", "notes":"番茄切开，与鸡蛋、蘑菇一起入锅。", "dish":{"ingredients":[{"id":"tomato", "cut":true, "heat":6}, {"id":"egg", "heat":6}, {"id":"mushroom", "heat":6}]}}
	check(game.repository.save_recipe(player_recipe), "saved player recipe can occupy the second page")
	game._view_recipe(game.RecipeMethod.starter())
	await game._turn_recipe(1)
	check(game._recipe_page_index == 1 and game._recipe_pages.size() == 2, "turning the actual cookbook opens page two")
	await capture("recipe-page2")
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: supplied tomato integration, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().is_empty(): return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "-" + label + ".png") == OK, "GPU captured " + label)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
