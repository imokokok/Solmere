extends Node

const Restaurant = preload("res://modules/restaurant/restaurant.tscn")
var paid_sessions: Dictionary = {}
var demo_wallet: float = 0.0
var module: Node

func _ready() -> void :
	_enter_restaurant()
	# Opt-in release QA: capture this real playable window without OS mouse
	# automation or replacing the exported main scene with a test scene.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preview-capture=") and DisplayServer.get_name() != "headless":
			_capture_live_preview.call_deferred(argument.trim_prefix("--preview-capture="))

func _capture_live_preview(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("LIVE_PREVIEW_CAPTURE ", get_viewport().get_texture().get_image().save_png(path))

func _enter_restaurant() -> void :
	module = Restaurant.instantiate()
	var entry := {"player_id": "local_demo", "display_name": "100饭店主厨", "shift_seconds": 720.0}
	if "--qa-preview" in OS.get_cmdline_user_args():
		var folder := "user://preview/%s/" % Crypto.new().generate_random_bytes(12).hex_encode()
		entry.repository_path = folder + "cookbook.json"
		entry.letters_path = folder + "letters.json"
		DisplayServer.window_set_title("街角厨房 · 2D 验收")
	module.configure(entry)
	module.shift_completed.connect(_on_settlement)
	module.exit_requested.connect(_on_exit)
	add_child(module)
	if "--practice-preview" in OS.get_cmdline_user_args():
		module.call_deferred("_close_modal")
	if "--live-preview" in OS.get_cmdline_user_args():
		module.call_deferred("_start_shift")
		module.call_deferred("_notify", "客人来了。先看看右边的点菜单。")
		if "--recipe-preview" in OS.get_cmdline_user_args():
			module.call_deferred("_show_cookbook")

func _on_settlement(result: Dictionary) -> void :

	var receipt: String = str(result.get("session_id", ""))
	if receipt.is_empty() or paid_sessions.has(receipt):
		return
	paid_sessions[receipt] = true
	demo_wallet += float(result.get("share", 0.0))
	print("HOST_SETTLEMENT ", JSON.stringify(result))

func _on_exit() -> void :
	module.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layer: = CanvasLayer.new()
	add_child(layer)
	var bg: = ColorRect.new()
	bg.color = Color("f8edcf")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var box: = VBoxContainer.new()
	box.position = Vector2(480, 280)
	box.size = Vector2(640, 340)
	box.add_theme_constant_override("separation", 24)
	layer.add_child(box)
	var font = preload("res://modules/restaurant/ui/paper_ink.gd").font()
	var title: = Label.new()
	title.text = "街角厨房"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("4b4033"))
	box.add_child(title)
	var info: = Label.new()
	info.text = "主厨的钱包  ¥ %.2f\n今天先到这里。" % demo_wallet
	info.add_theme_font_override("font", font)
	info.add_theme_font_size_override("font_size", 20)
	info.add_theme_color_override("font_color", Color("7b7060"))
	box.add_child(info)
	var again = preload("res://modules/restaurant/ui/paper_action.gd").new()
	again.text = "再做一顿饭"
	again.symbol = "book"
	again.add_theme_color_override("font_color", Color("4b4033"))
	again.custom_minimum_size.y = 54
	again.add_theme_font_override("font", font)
	again.pressed.connect( func(): layer.queue_free();_enter_restaurant())
	box.add_child(again)
	var close = preload("res://modules/restaurant/ui/paper_action.gd").new()
	close.text = "离开"
	close.symbol = "arrow"
	close.add_theme_color_override("font_color", Color("4b4033"))
	close.custom_minimum_size.y = 48
	close.add_theme_font_override("font", font)
	close.pressed.connect( func(): get_tree().quit())
	box.add_child(close)
