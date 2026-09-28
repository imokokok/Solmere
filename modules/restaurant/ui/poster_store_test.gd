extends SceneTree
## godot --headless --path . --script modules/restaurant/ui/poster_store_test.gd
const Store = preload("res://modules/restaurant/ui/poster_store.gd")
const World = preload("res://modules/restaurant/world/kitchen_world.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("POSTER FAIL: " + label)

func run() -> void:
	var folder := "user://after_hours_poster_tests/" + Crypto.new().generate_random_bytes(8).hex_encode()
	var path := folder + "/poster.json"
	var store := Store.new(path)
	check(store.load_poster().is_empty(), "new poster empty")
	var data := {"version": 1, "caption": "今天请你吃番茄！", "strokes": [{"points": [[0.1, 0.2], [0.8, 0.7]], "color": "284a42ff", "width": 0.01}], "stickers": [{"kind": "heart", "position": [0.6, 0.8], "scale": 0.065}]}
	data.tags = ["comfort", "fresh", "vegetable"]
	check(store.save_poster(data), "save first poster")
	var reloaded := Store.new(path)
	var loaded: Dictionary = reloaded.load_poster()
	check(loaded.get("caption") == data.caption, "caption roundtrip")
	check(loaded.get("strokes") == data.strokes, "strokes roundtrip")
	check(loaded.get("stickers") == data.stickers, "stickers roundtrip")
	check(loaded.get("tags") == data.tags, "recruitment tags roundtrip")
	data.caption = "明天见"
	check(store.save_poster(data), "second save creates backup")
	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	var recovery := Store.new(path)
	check(recovery.load_poster().get("caption") == "今天请你吃番茄！", "backup restored")
	check(recovery.save_poster(data), "recovered poster saves safely")
	var bad_path := folder + "/malformed.json"
	var bad := FileAccess.open(bad_path, FileAccess.WRITE)
	bad.store_string("{broken")
	bad.close()
	var protected := Store.new(bad_path)
	check(not protected.save_poster(data), "malformed original not overwritten")
	check(FileAccess.get_file_as_string(bad_path) == "{broken", "malformed original retained")
	var invalid := data.duplicate(true)
	invalid.strokes[0].points[0] = [2.0, 0.5]
	check(not store.save_poster(invalid), "invalid coordinates rejected")
	var world := World.new()
	world.set_poster(data)
	get_root().add_child(world)
	await process_frame
	await process_frame
	var paper := world.get_node_or_null("PublishedWallPoster")
	check(paper == null, "published poster belongs outside the minigame; no interior overlay")
	world.queue_free()
	await process_frame
	if failures == 0:
		print("POSTER_PERSISTENCE_AND_WALL_TESTS_PASSED")
	quit(0 if failures == 0 else 1)
