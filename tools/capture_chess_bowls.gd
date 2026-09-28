extends SceneTree
## Capture the real chess view without changing the player's save.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://extensions/elder_board/scenes/main.tscn")
	for frame in 30:
		await process_frame
		if current_scene != null: break
	var menu = current_scene
	if menu == null:
		push_error("Chess scene did not load")
		quit(1)
		return
	menu._select_game(2)
	await process_frame
	menu._start_match(9)
	for frame in 8: await process_frame
	var screenshot := root.get_texture().get_image()
	var path := "res://outputs/chess-npc-demo-20260928/filled-bowls-final.png"
	var error := screenshot.save_png(path)
	print("FILLED_BOWLS_SCREENSHOT: %s error=%d" % [path, error])
	quit(0 if error == OK else 1)
