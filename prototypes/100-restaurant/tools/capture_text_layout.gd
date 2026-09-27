extends SceneTree
# Production UI captures at native and scaled window sizes. No player saves.
class CaptureRestaurant extends "res://modules/restaurant/restaurant.gd":
	func _load_letters() -> void: _letters.clear()
	func _persist_letters() -> void: pass
var game
var output := "res://qa/20260927-text-layout"
func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	root.content_scale_size = Vector2i(1600, 946)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	if not OS.get_cmdline_user_args().is_empty(): output = OS.get_cmdline_user_args()[0]
	game = CaptureRestaurant.new()
	game.configure({"repository_path":"user://text_layout_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode()})
	root.add_child(game)
	await process_frame
	game.world.audio.muted = true
	await capture("intro")
	game._show_help()
	await capture("help")
	game.modal_body.find_child("ReadingScroll", true, false).scroll_vertical = 10000
	await capture("help-end")
	game.session.current_customer = {"name":"林阿姨", "quote":"今天想要一碗暖暖的南瓜汤，清淡一点，不要太油。\n也想尝一点你拿手的味道。", "mood_before":65, "preferences_known":true, "likes":["comfort"], "dislikes":["spicy"], "habit":"少盐，慢慢吃。", "ordered_recipe":{"title":"暖暖的南瓜汤"}}
	game._update_hud()
	game._show_order_paper()
	await capture("order")
	game._view_recipe(game.RecipeMethod.starter())
	await capture("recipe")
	# Preview the feedback with domain-generated ratings; skip persistence so
	# capture cannot append a fake review to the player's collaboration record.
	var snapshot := {"ingredients":[{"id":"bread","heat":8,"cut":true,"mass_kg":0.16}], "quality":0.8,"weirdness":0.0,"tags":["grain","comfort"],"raw_count":0,"cut_count":1,"burnt":false}
	var review: Dictionary = game.session._evaluate(snapshot, game.session.customers[0])
	review.merge({"customer":"林阿姨", "customer_id":str(game.session.customers[0].id), "mood_before":65, "mood_after":72, "mood_delta":7, "meal_fee":42.0, "tip":0.0, "compensation":0.0, "payment":42.0})
	# Persistence is disabled only in this capture subclass.
	game._pending_serve_result = review.duplicate(true)
	game._show_serve_feedback()
	await capture("feedback")
	game.modal_body.find_child("ReadingScroll", true, false).scroll_vertical = 10000
	await capture("feedback-end")
	game._show_letters()
	await capture("letters")
	game._settle()
	await capture("receipt")
	root.size = Vector2i(1152, 681)
	game.session.phase = "prep"
	game._show_intro()
	await capture("small-intro")
	game._show_help()
	await capture("small-help")
	game.modal_body.find_child("ReadingScroll", true, false).scroll_vertical = 10000
	await capture("small-help-end")
	game._show_order_paper()
	await capture("small-order")
	game._view_recipe(game.RecipeMethod.starter())
	await capture("small-recipe")
	game._pending_serve_result = review.duplicate(true)
	game._show_serve_feedback()
	await capture("small-feedback")
	game.modal_body.find_child("ReadingScroll", true, false).scroll_vertical = 10000
	await capture("small-feedback-end")
	game._settle()
	await capture("small-receipt")
	game.queue_free()
	await process_frame
	print("TEXT_LAYOUT_CAPTURES_COMPLETE")
	quit()
func capture(label: String) -> void:
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var rect: Rect2 = game.modal_panel.get_global_rect()
	if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > 1600.1 or rect.end.y > 946.1:
		push_error("Reading panel outside logical viewport: %s %s" % [label, rect])
		quit(1)
		return
	var path := output.path_join(label + ".png")
	var picture := root.get_texture().get_image()
	var result := picture.save_png(path)
	print("CAPTURE %s result=%s bounds=%s pixels=%s" % [label, result, rect, picture.get_size()])
