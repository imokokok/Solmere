extends SceneTree
const Art = preload("res://modules/restaurant/assets/sprite_library.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	root.size = Vector2i(1600,946)
	call_deferred("run")
func run() -> void:
	var game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://support_%s/book.json" % Crypto.new().generate_random_bytes(8).hex_encode()})
	root.add_child(game)
	await process_frame
	game._close_modal()
	game.world.audio.muted = true
	for id in ["tomato", "egg", "mushroom", "oil", "salt", "ketchup", "mayonnaise", "mustard", "sock", "toilet_paper"]:
		var slot: Button = game.storage_display.find_child("Ingredient_"+id,true,false)
		var art = slot.get_node("FoodArt")
		var bottom: float = slot.position.y + art.position.y + Art.support_rect(id).end.y * art.scale.y
		expect(absf(bottom - float(slot.get_meta("support_floor"))) < 0.05, id + " touches its internal support plane")
		expect(bottom > float(slot.get_meta("front_lip")), id + " sits behind the finite thickness of its front wall")
		expect(art.storage_clip.end.y < Art.support_rect(id).end.y, id + " lower silhouette is actually clipped by the wall")
	var slot: Button = game.storage_display.find_child("Ingredient_mayonnaise",true,false)
	var art = slot.get_node("FoodArt")
	if DisplayServer.get_name() != "headless":
		await process_frame
		RenderingServer.force_draw(false)
		var point := Vector2(slot.global_position.x + slot.size.x*0.5, float(slot.get_meta("front_lip"))+4)
		var pixel := Vector2i(root.get_final_transform()*point)
		var covered := root.get_texture().get_image().get_pixelv(pixel)
		var clip: Rect2 = art.storage_clip
		art.storage_clip = Rect2(-10000,-10000,20000,20000)
		art.queue_redraw()
		await process_frame
		RenderingServer.force_draw(false)
		var uncovered := root.get_texture().get_image().get_pixelv(pixel)
		expect(Vector3(covered.r,covered.g,covered.b).distance_to(Vector3(uncovered.r,uncovered.g,uncovered.b)) > 0.10, "GPU shows the actual bottle below the front lip only when occlusion is removed")
		art.storage_clip = clip
		art.queue_redraw()
	var view: Transform2D = art.get_global_transform_with_canvas()
	game._take_ingredient(game._definition("mayonnaise"), slot.get_global_rect().get_center())
	var body: RigidBody2D = game.world._held
	expect(body != null and slot.disabled, "taking one bottle empties that compartment")
	expect(game.world._held_proxy.transform.origin.distance_to(view.origin) < 0.05, "pickup begins at the displayed bottle, without jumping to the pointer")
	var uid: String = body.get_meta("instance_uid")
	var remaining: float = body.get_meta("remaining_ml")
	game.world._dragging = false
	body.position = slot.get_global_rect().get_center()
	game.world._sync_held_foreground()
	expect(game._return_to_storage(body), "same bottle can be seated back in its compartment")
	await create_timer(0.4).timeout
	expect(art.transform.is_equal_approx(slot.get_meta("rest_transform")), "return settles at the supported pose")
	expect(body.get_meta("instance_uid") == uid and is_equal_approx(body.get_meta("remaining_ml"),remaining), "seating never duplicates inventory or refills contents")
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		await process_frame
		RenderingServer.force_draw(false)
		expect(root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]) == OK,"GPU captured supported containers")
	game._take_ingredient(game._definition("mayonnaise"))
	body.position = slot.get_global_rect().get_center()
	game._return_to_storage(body)
	game.storage_display._turn_page("odd",1)
	await create_timer(0.4).timeout
	expect(game.storage_display._settling.is_empty(),"browsing another shelf cancels obsolete seating views safely")
	game.queue_free()
	await process_frame
	for message in failures: push_error(message)
	print("%s: storage support and occlusion, %d checks" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
