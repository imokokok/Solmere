extends RefCounted

const Canvas = preload("res://modules/restaurant/ui/poster_canvas.gd")
const MAX_BYTES: = 16 * 1024 * 1024

var storage_path: String
var last_error: = ""
var _loaded: = false
var _can_write: = true
var _from_backup: = false
var _poster: Dictionary = {}

func _init(path: String) -> void :
	storage_path = path

func get_last_error() -> String:
	return last_error

func load_poster() -> Dictionary:
	if _loaded:
		return _poster.duplicate(true)
	_loaded = true
	if not FileAccess.file_exists(storage_path):
		return {}
	var parsed: = _read(storage_path)
	if not parsed.ok:
		var backup: = _read(storage_path + ".bak")
		if not backup.ok:
			_can_write = false
			last_error = "海报文件损坏，已保留原文件，不会自动覆盖。"
			return {}
		parsed = backup
		_from_backup = true
		last_error = "海报主文件损坏，已读取上次备份。"
	_poster = parsed.poster
	return _poster.duplicate(true)

func save_poster(data: Dictionary) -> bool:
	load_poster()
	if not _can_write:
		last_error = "原海报文件损坏，保存已取消；请先保留并修复文件。"
		return false
	last_error = ""
	if not _valid_data(data):
		last_error = "海报数据无效或超出容量，未修改已保存的海报。"
		return false
	var canonical: = _canonical(data)
	var contents: = JSON.stringify({"schema_version": 1, "poster": canonical}, "\t", true, true)
	if contents.to_utf8_buffer().size() > MAX_BYTES:
		last_error = "海报文件超过 16 MiB 上限。"
		return false
	var absolute: = ProjectSettings.globalize_path(storage_path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		last_error = "无法创建海报保存目录。"
		return false
	var temporary: = absolute + ".tmp"
	var file: = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "无法创建海报临时文件。"
		return false
	file.store_string(contents)
	file.flush()
	var result: = file.get_error()
	file.close()
	if result != OK:
		last_error = "海报写入失败，原文件保持不变。"
		return false
	if FileAccess.file_exists(absolute) and not _from_backup:
		if DirAccess.copy_absolute(absolute, absolute + ".bak") != OK:
			last_error = "无法备份海报原文件，保存已取消。"
			return false
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		last_error = "无法替换海报文件，原文件和备份仍保留。"
		return false
	_poster = canonical
	_from_backup = false
	return true

func _read(path: String) -> Dictionary:
	var file: = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {"ok": false}
	var parser: = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"ok": false}
	var document = parser.data
	if not document is Dictionary or document.get("schema_version") != 1:
		return {"ok": false}
	if not document.get("poster") is Dictionary or not _valid_data(document.poster):
		return {"ok": false}
	return {"ok": true, "poster": _canonical(document.poster)}

func _canonical(data: Dictionary) -> Dictionary:

	var canvas: = Canvas.new()
	canvas.import_data(data)
	var result: = canvas.export_data()
	canvas.free()
	if data.has("tags"):
		result.tags = data.tags.duplicate()
	return result

func _valid_data(data: Dictionary) -> bool:
	if data.get("version") != 1 or not data.get("caption", "") is String or data.get("caption", "").length() > 120:
		return false
	for key in data:
		if key not in ["version", "caption", "strokes", "stickers", "tags", "recipe_sheet"]:
			return false
	if data.has("tags"):
		if not data.tags is Array or data.tags.size() > 16:
			return false
		for tag in data.tags:
			if not tag is String or tag.is_empty() or tag.length() > 40:
				return false
	if not data.get("strokes", []) is Array or not data.get("stickers", []) is Array:
		return false
	if data.get("strokes", []).size() > Canvas.MAX_STROKES or data.get("stickers", []).size() > 32:
		return false
	for stroke in data.get("strokes", []):
		if not stroke is Dictionary or not stroke.get("points") is Array:
			return false
		if stroke.points.is_empty() or stroke.points.size() > 512:
			return false
		if not stroke.get("color") is String or not Color.html_is_valid(stroke.color):
			return false
		if not _number(stroke.get("width")) or stroke.width <= 0 or stroke.width > 0.08:
			return false
		if stroke.has("brush") and stroke.brush not in ["ink","pencil","marker"]: return false
		for key in stroke:
			if key not in ["points", "color", "width", "brush"]:
				return false
		for point in stroke.points:
			if not _point(point):
				return false
	for sticker in data.get("stickers", []):
		if not Canvas.validate_sticker(sticker):
			return false
	if data.has("recipe_sheet") and not preload("res://modules/restaurant/ui/recipe_sheet.gd").valid(data.recipe_sheet): return false
	return JSON.stringify(data).to_utf8_buffer().size() < MAX_BYTES

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0]) and _number(value[1]) and value[0] >= 0 and value[0] <= 1 and value[1] >= 0 and value[1] <= 1
