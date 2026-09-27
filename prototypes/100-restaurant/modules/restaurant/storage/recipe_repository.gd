extends RefCounted


const SCHEMA_VERSION: = 1
const PosterCanvas = preload("res://modules/restaurant/ui/poster_canvas.gd")
const DEFAULT_PATH: = "user://after_hours_kitchen/cookbook.json"
const CATALOG_PATH: = "res://modules/restaurant/data/ingredients.json"
const RETIRED_INGREDIENT_IDS: = ["rice"]
const MAX_FILE_BYTES: = 16 * 1024 * 1024
const MAX_RECIPES: = 200
const MAX_DISH_INGREDIENTS: = 48
const MAX_THUMBNAIL_BYTES: = 1024 * 1024

var storage_path: String
var last_error: = ""
var _recipes: Array = []
var _liked_ids: Array = []
var _ingredient_ids: Dictionary = {}
var _loaded: = false
var _write_allowed: = true
var _recovered_from_backup: = false

func _init(custom_path: String = DEFAULT_PATH, catalog_path: String = CATALOG_PATH) -> void :
	storage_path = custom_path
	if FileAccess.file_exists(catalog_path):
		var catalog = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
		if catalog is Dictionary:
			catalog = catalog.get("ingredients", [])
		if catalog is Array:
			for entry in catalog:
				if entry is Dictionary and entry.get("id") is String:
					_ingredient_ids[entry.id] = true

func get_last_error() -> String:
	return last_error

func load_recipes() -> Array:
	if _loaded:
		return _recipes.duplicate(true)
	_loaded = true
	if not FileAccess.file_exists(storage_path):
		return []
	var result: = _read_document(storage_path)
	if not result.ok:
		var initial_error: String = result.error
		var backup: = _read_document(storage_path + ".bak")
		if backup.ok:
			result = backup
			_recovered_from_backup = true
			last_error = "主存档损坏，已读取上次备份：" + initial_error
		else:
			_write_allowed = false
			last_error = "菜谱文件无法读取，已保留原文件：" + initial_error
			return []
	_recipes = result.recipes
	_liked_ids = result.liked_ids
	return _recipes.duplicate(true)

func save_recipe(record: Dictionary) -> bool:
	load_recipes()
	last_error = ""
	if not _write_allowed:
		last_error = "原菜谱文件损坏；请先保留并修复原文件，避免覆盖。"
		return false
	var candidate: = record.duplicate(true)
	if not candidate.has("id"):
		candidate.id = "recipe_" + Crypto.new().generate_random_bytes(12).hex_encode()
	if not candidate.has("created_at"):
		candidate.created_at = Time.get_datetime_string_from_system(true, true) + " UTC"
	var checked: = _validate_record(candidate)
	if not checked.ok:
		last_error = checked.error
		return false
	var next: = _recipes.duplicate(true)
	var existing_index: = _find_index(candidate.id)
	if existing_index >= 0:
		checked.record.likes = _recipes[existing_index].likes
		checked.record.created_at = _recipes[existing_index].created_at
		next[existing_index] = checked.record
	else:
		if next.size() >= MAX_RECIPES:
			last_error = "本地菜谱最多保存 %d 道。" % MAX_RECIPES
			return false
		checked.record.likes = 0
		next.append(checked.record)
	if _write_document(storage_path, next, _liked_ids) != OK:
		return false
	_recipes = next
	return true

func like_recipe(recipe_id: String) -> bool:
	load_recipes()
	last_error = ""
	var index: = _find_index(recipe_id)
	if index < 0 or recipe_id in _liked_ids or not _write_allowed:
		last_error = "已经喜欢过这道菜，或菜谱不可用。"
		return false
	var next: = _recipes.duplicate(true)
	var next_liked: = _liked_ids.duplicate()
	next[index].likes = int(next[index].likes) + 1
	next_liked.append(recipe_id)
	if _write_document(storage_path, next, next_liked) != OK:
		return false
	_recipes = next
	_liked_ids = next_liked
	return true

func has_liked(recipe_id: String) -> bool:
	load_recipes()
	return recipe_id in _liked_ids

func export_to(path: String) -> Error:
	load_recipes()
	last_error = ""
	if path == storage_path or path == storage_path + ".bak":
		last_error = "请导出到新的 JSON 文件。"
		return ERR_INVALID_PARAMETER
	return _write_document(path, _recipes, [], false)

func export_recipe_to(recipe_id: String, path: String) -> Error:
	load_recipes()
	var index := _find_index(recipe_id)
	if index < 0 or _is_storage_path(path):
		last_error = "请选取已保存的菜谱，导出到新的文件。"
		return ERR_INVALID_PARAMETER
	return _write_document(path, [_recipes[index]], [], false)

func export_reading_page(recipe_id: String, path: String, page_png: String, catalog: Array) -> Error:
	load_recipes()
	last_error = ""
	var index := _find_index(recipe_id)
	if index < 0 or _is_storage_path(path) or path.get_extension().to_lower() != "html" or page_png.is_empty() or not _valid_thumbnail(page_png):
		last_error = "菜谱或纸面预览不可用，请保存为新的 HTML 文件。"
		return ERR_INVALID_PARAMETER
	var content := preload("res://modules/restaurant/storage/recipe_share.gd").document(_recipes[index], page_png, catalog)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "分享页无法写入，请选择可写文件夹。"
		return FileAccess.get_open_error()
	file.store_string(content)
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK: error = DirAccess.rename_absolute(temporary, path)
	if error != OK: last_error = "分享页没有保存成功，原文件保持不变。"
	return error

func _is_storage_path(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path).simplify_path().replace("\\", "/").to_lower()
	var stored := ProjectSettings.globalize_path(storage_path).simplify_path().replace("\\", "/").to_lower()
	return absolute in [stored, stored + ".bak", stored + ".tmp"]

func import_from(path: String) -> Dictionary:
	load_recipes()
	last_error = ""
	if not _write_allowed:
		return {"added": 0, "error": "原存档损坏，暂不能导入，以免覆盖。"}
	var incoming: = _read_document(path)
	if not incoming.ok:
		last_error = incoming.error
		return {"added": 0, "error": last_error}
	var next: = _recipes.duplicate(true)
	var ids: Dictionary = {}
	for recipe in next:
		ids[recipe.id] = true
	var added: = 0
	for recipe in incoming.recipes:
		if ids.has(recipe.id):
			continue
		var local_record: Dictionary = recipe.duplicate(true)

		local_record.likes = 0
		next.append(local_record)
		ids[recipe.id] = true
		added += 1
	if next.size() > MAX_RECIPES:
		return {"added": 0, "error": "导入后超过 %d 道菜谱上限。" % MAX_RECIPES}
	if added > 0 and _write_document(storage_path, next, _liked_ids) != OK:
		return {"added": 0, "error": last_error}
	_recipes = next
	return {"added": added, "error": ""}

func _find_index(recipe_id: String) -> int:
	for i in _recipes.size():
		if _recipes[i].id == recipe_id:
			return i
	return -1

func _read_document(path: String) -> Dictionary:
	var file: = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("无法打开 JSON 文件。")
	if file.get_length() > MAX_FILE_BYTES:
		return _failure("JSON 文件超过 16 MiB 上限。")
	var parser: = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return _failure("JSON 格式错误（第 %d 行）。" % parser.get_error_line())
	var data = parser.data
	if not data is Dictionary or data.get("schema_version") != SCHEMA_VERSION:
		return _failure("菜谱版本不兼容，需要 schema_version = 1。")
	if not data.get("recipes") is Array or data.recipes.size() > MAX_RECIPES:
		return _failure("菜谱列表格式或数量无效。")
	var records: Array = []
	var ids: Dictionary = {}
	for record in data.recipes:
		if not record is Dictionary:
			return _failure("菜谱必须是 JSON 对象。")
		var checked: = _validate_record(record, true)
		if not checked.ok:
			return checked
		if ids.has(checked.record.id):
			return _failure("文件中含有重复菜谱 ID。")
		ids[checked.record.id] = true
		records.append(checked.record)
	var liked: Array = []
	if data.has("liked_ids"):
		if not data.liked_ids is Array or data.liked_ids.size() > MAX_RECIPES:
			return _failure("本地喜欢记录格式无效。")
		for recipe_id in data.liked_ids:
			if not recipe_id is String or not ids.has(recipe_id):
				return _failure("本地喜欢记录引用了无效菜谱。")
			if not recipe_id in liked:
				liked.append(recipe_id)
	return {"ok": true, "recipes": records, "liked_ids": liked, "error": ""}

func _validate_record(record: Dictionary, allow_retired: bool = false) -> Dictionary:
	for field in ["title", "author"]:
		if not record.get(field) is String or record[field].strip_edges().is_empty():
			return _failure("菜名和署名不能为空。")
	if record.title.length() > 60 or record.author.length() > 40:
		return _failure("菜名最多 60 字，署名最多 40 字。")
	if not record.get("id", "") is String or not _valid_id(record.get("id", "")):
		return _failure("菜谱 ID 只能使用字母、数字、下划线和连字符。")
	if not record.get("notes", "") is String or record.get("notes", "").length() > 2000:
		return _failure("做法备注最多 2000 字。")
	if not record.get("created_at", "") is String or record.get("created_at", "").length() > 64:
		return _failure("创建时间格式无效。")
	var poster = record.get("poster", {})
	if not poster is Dictionary or not _valid_poster(poster):
		return _failure("纸面笔画或素材图层数据无效。")
	if poster.has("recipe_sheet"):
		var sheet=preload("res://modules/restaurant/ui/recipe_sheet.gd")
		if not sheet.has_title(poster) or not sheet.has_drawing(poster):
			return _failure("图解菜谱需要手写菜名和至少一幅亲手画的步骤配图。")
	# Written instructions now live directly on paper and are valid DIY content.
	var dish_result: = _validate_dish(record.get("dish", {}), _poster_has_content(poster) or not str(record.get("notes", "")).strip_edges().is_empty(), allow_retired)
	if not dish_result.ok:
		return dish_result
	var dish: Dictionary = dish_result.dish
	var thumbnail = record.get("thumbnail", record.get("photo", ""))
	if not thumbnail is String or not _valid_thumbnail(thumbnail):
		return _failure("照片必须是有效的 PNG base64，最大 1 MiB / 1024×1024。")
	var likes = record.get("likes", 0)
	if not _is_number(likes) or likes < 0 or likes > MAX_RECIPES or floor(likes) != likes:
		return _failure("本地喜欢数量无效。")
	return {"ok": true, "record": {"id": record.id, "title": record.title.strip_edges(),
		"author": record.author.strip_edges(), "notes": record.get("notes", ""),
		"created_at": record.get("created_at", ""), "dish": dish.duplicate(true),
		"thumbnail": thumbnail, "poster": poster.duplicate(true), "likes": int(likes)}, "error": ""}

func _validate_dish(dish: Variant, allow_empty: bool, allow_retired: bool = false) -> Dictionary:
	if not dish is Dictionary or not dish.get("ingredients") is Array or dish.ingredients.size() > MAX_DISH_INGREDIENTS:
		return _failure("料理食材记录超出存档上限（最多 48 项），或食材列表格式无效。")
	if not _safe_json(dish, 0) or JSON.stringify(dish).length() > 96000:
		return _failure("菜品数据过长或含有不支持的字段。")
	if dish.has("water_ml") and ( not _is_number(dish.water_ml) or float(dish.water_ml) < 0 or float(dish.water_ml) > 1500):
		return _failure("成品汤量必须是 0–1500 毫升的有效数值。")
	if dish.ingredients.is_empty():
		if not allow_empty:
			return _failure("这张纸还是空白的。请加入文字、照片、食材素材或绘画后再保存。")


		return {"ok": true, "dish": {"ingredients": []}, "error": ""}
	if _ingredient_ids.is_empty():
		return _failure("食材目录未加载，无法验证菜谱。")
	for ingredient in dish.ingredients:
		var ingredient_id = ingredient
		if ingredient is Dictionary:
			ingredient_id = ingredient.get("id", ingredient.get("ingredient_id", ""))
			if not preload("res://modules/restaurant/domain/food_snapshot.gd").valid(ingredient):
				return _failure("菜谱的食材温度、形态或酱汁记录格式无效。")
		if not ingredient_id is String or (not _ingredient_ids.has(ingredient_id) and not (allow_retired and ingredient_id in RETIRED_INGREDIENT_IDS)):
			return _failure("菜谱包含未知食材。")
	return {"ok": true, "dish": dish.duplicate(true), "error": ""}

func _poster_has_content(poster: Dictionary) -> bool:


	if not poster.get("stickers", []).is_empty():
		return true
	for stroke in poster.get("strokes", []):
		if not stroke.get("points", []).is_empty():
			return true
	return false

func _valid_id(value: String) -> bool:
	if value.is_empty() or value.length() > 80:
		return false
	for code in value.to_ascii_buffer():
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 45 or code == 95):
			return false
	return true

func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _safe_json(value: Variant, depth: int) -> bool:
	if depth > 6:
		return false
	if value == null or value is bool:
		return true
	if value is int or value is float:
		return _is_number(value) and abs(float(value)) < 10000000.0
	if value is String:
		return value.length() <= 2000
	if value is Array:
		if value.size() > 64:
			return false
		for item in value:
			if not _safe_json(item, depth + 1):
				return false
		return true
	if value is Dictionary:
		if value.size() > 40:
			return false
		for key in value:
			# GDScript dot assignment creates StringName keys; JSON writes them as strings.
			if not (key is String or key is StringName) or str(key).length() > 64 or str(key).to_lower() in ["path", "url", "script", "resource", "resource_path"]:
				return false
			if not _safe_json(value[key], depth + 1):
				return false
		return true
	return false

func _valid_thumbnail(value: String) -> bool:
	if value.is_empty():
		return true
	if value.length() > 1398104:
		return false
	if value.length() % 4 != 0:
		return false
	var padding_started: = false
	var padding_count: = 0
	for code in value.to_ascii_buffer():
		if code == 61:
			padding_started = true
			padding_count += 1
			if padding_count > 2:
				return false
		elif padding_started or not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 43 or code == 47):
			return false
	var bytes: = Marshalls.base64_to_raw(value)
	if bytes.size() < 24 or bytes.size() > MAX_THUMBNAIL_BYTES:
		return false
	if bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		return false

	var width: = int(bytes[16]) * 16777216 + int(bytes[17]) * 65536 + int(bytes[18]) * 256 + int(bytes[19])
	var height: = int(bytes[20]) * 16777216 + int(bytes[21]) * 65536 + int(bytes[22]) * 256 + int(bytes[23])
	if width < 1 or height < 1 or width > 1024 or height > 1024:
		return false
	var picture: = Image.new()
	return picture.load_png_from_buffer(bytes) == OK

func _valid_poster(poster: Dictionary) -> bool:
	if poster.is_empty():
		return true
	if not _is_number(poster.get("version", 1)) or poster.get("version", 1) != 1:
		return false
	if not poster.get("caption", "") is String or poster.get("caption", "").length() > 120:
		return false
	if not poster.get("strokes", []) is Array or not poster.get("stickers", []) is Array:
		return false
	if poster.get("strokes", []).size() > PosterCanvas.MAX_STROKES or poster.get("stickers", []).size() > 32:
		return false
	for stroke in poster.get("strokes", []):
		if not stroke is Dictionary or not stroke.get("points") is Array or stroke.points.size() > 512:
			return false
		if stroke.has("brush") and stroke.brush not in ["ink","pencil","marker"]: return false
		for key in stroke:
			if key not in ["points", "color", "width", "brush"]:
				return false
		if not stroke.get("color") is String or not Color.html_is_valid(stroke.color):
			return false
		if not _is_number(stroke.get("width")) or stroke.width <= 0 or stroke.width > 0.08:
			return false
		for point in stroke.points:
			if not _valid_point(point):
				return false
	for sticker in poster.get("stickers", []):
		if not PosterCanvas.validate_sticker(sticker):
			return false
	for key in poster:
		if key not in ["version", "caption", "strokes", "stickers", "recipe_sheet"]:
			return false
	if poster.has("recipe_sheet") and not preload("res://modules/restaurant/ui/recipe_sheet.gd").valid(poster.recipe_sheet): return false
	return JSON.stringify(poster).to_utf8_buffer().size() < MAX_FILE_BYTES

func _valid_point(point: Variant) -> bool:
	return point is Array and point.size() == 2 and _is_number(point[0]) and _is_number(point[1]) and point[0] >= 0 and point[0] <= 1 and point[1] >= 0 and point[1] <= 1

func _write_document(path: String, records: Array, liked: Array, include_profile: bool = true) -> Error:
	var document: Dictionary = {"schema_version": SCHEMA_VERSION, "recipes": records}
	if include_profile:
		document.liked_ids = liked
	var contents: = JSON.stringify(document, "\t", true, true)
	if contents.to_utf8_buffer().size() > MAX_FILE_BYTES:
		last_error = "菜谱文件超过 16 MiB，请减少照片大小或菜谱数量。"
		return ERR_OUT_OF_MEMORY
	var absolute: = ProjectSettings.globalize_path(path)
	var parent_error: = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if parent_error != OK:
		last_error = "无法创建保存目录。"
		return parent_error
	var temporary: = absolute + ".tmp"
	var file: = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "无法写入临时文件。"
		return FileAccess.get_open_error()
	file.store_string(contents)
	file.flush()
	var write_error: = file.get_error()
	file.close()
	if write_error != OK:
		last_error = "写入失败，原存档保持不变。"
		return write_error

	if FileAccess.file_exists(absolute) and not (path == storage_path and _recovered_from_backup):
		var backup_error: = DirAccess.copy_absolute(absolute, absolute + ".bak")
		if backup_error != OK:
			last_error = "无法备份原文件，已取消保存。"
			return backup_error
	var rename_error: = DirAccess.rename_absolute(temporary, absolute)
	if rename_error != OK:
		last_error = "无法替换文件；原文件和备份仍保留。"
	elif path == storage_path:
		_recovered_from_backup = false
	return rename_error

func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
