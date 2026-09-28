extends SceneTree
## Offline copy of the exact shared display adapter. Never alters artist files.
const Art = preload("res://modules/restaurant/assets/sprite_library.gd")
func _initialize() -> void:
	Art.prepared_enabled = false
	var started := Time.get_ticks_msec()
	var foods := {}
	var inputs := {}
	var folder := "res://modules/restaurant/assets/prepared_food"
	DirAccess.make_dir_recursive_absolute(folder)
	for name in ["handdrawn_manifest", "team_jpeg_manifest", "supplementary_manifest"]:
		var path: String = "res://modules/restaurant/assets/" + name + ".json"
		inputs[path] = FileAccess.get_sha256(path)
		for entry in JSON.parse_string(FileAccess.get_file_as_string(path)).values():
			inputs[entry.path] = FileAccess.get_sha256(entry.path)
	inputs["res://modules/restaurant/assets/derived/tomato.png"] = FileAccess.get_sha256("res://modules/restaurant/assets/derived/tomato.png")
	for row in JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/data/ingredients.json")):
		var id: String = row.id
		if id in ["fish","salmon","herbs","sea_beans","star_salt"]: continue
		var texture: Texture2D = Art.food(id)
		if texture == null: push_error("Missing " + id); quit(1); return
		var path: String = folder + "/" + id + ".png"
		var pixels := texture.get_image()
		if pixels.is_compressed(): pixels.decompress()
		if pixels.save_png(path) != OK: quit(1); return
		var support := Art.support_rect(id)
		foods[id] = {"path":path,"sha256":FileAccess.get_sha256(path),"support":[support.position.x,support.position.y,support.size.x,support.size.y]}
	var report := {"method":"Shared SpriteLibrary display copy: original team silhouettes and interior paint retained, matte fringe RGB repaired; unrelated tiny gutter components removed only from generated supplemental atlases. All source files unchanged.","inputs":inputs,"foods":foods}
	FileAccess.open("res://modules/restaurant/assets/prepared_food_manifest.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("PASS: baked %d display textures in %d ms" % [foods.size(),Time.get_ticks_msec()-started])
	quit()
