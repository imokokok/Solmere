extends Control
## Shared renderer for the physical stand and the opened recipe.
const FONT = preload("res://modules/restaurant/assets/fonts/lxgw_wenkai_lite.ttf")
var record: Dictionary = {}
var _image: Texture2D
var _collage: Control
var _dish_sketch: Control

func setup(value: Dictionary) -> void:
	record = value.duplicate(true)
	_image = null
	if is_instance_valid(_dish_sketch):
		remove_child(_dish_sketch)
		_dish_sketch.queue_free()
		_dish_sketch = null
	if is_instance_valid(_collage):
		remove_child(_collage)
		_collage.queue_free()
		_collage = null
	if not str(record.get("thumbnail", "")).is_empty():
		var img := Image.new()
		if img.load_png_from_buffer(Marshalls.base64_to_raw(record.thumbnail)) == OK: _image = ImageTexture.create_from_image(img)
	if record.has("poster"):
		var paper = preload("res://modules/restaurant/ui/poster_canvas.gd").new()
		add_child(paper)
		paper.import_data(record.poster)
		paper.editable = false
		# The book supplies its own paper; keep the authored ink and photos intact.
		paper.draw_paper = false
		paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		paper.position = Vector2(42, 170)
		paper.custom_minimum_size = Vector2.ZERO
		paper.size = Vector2(476, 476.0 * 460.0 / 850.0)
		if not paper.recipe_sheet.is_empty():
			paper.position=Vector2.ZERO
			paper.size=Vector2(560,760)
		paper.visible = paper.has_content()
		_collage = paper
	if _image == null and (not is_instance_valid(_collage) or not _collage.visible) and not record.get("dish", {}).get("ingredients", []).is_empty():
		var sketch = preload("res://modules/restaurant/ui/recipe_vignette.gd").new()
		sketch.stage = "plate"
		sketch.entries = preload("res://modules/restaurant/domain/recipe_method.gd").targets(record)
		sketch.catalog = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/data/ingredients.json"))
		sketch.position = Vector2(66, 210)
		sketch.size = Vector2(166, 95)
		sketch.scale = Vector2.ONE * 2.5
		add_child(sketch)
		_dish_sketch = sketch
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	preload("res://modules/restaurant/ui/paper_surface.gd").paint(self,Rect2(0,0,560,760))
	if record.get("poster",{}).has("recipe_sheet"): return
	draw_line(Vector2(30, 25), Vector2(30, 730), Color("c68d6c", 0.4), 1.5)
	var title := str(record.get("title", "厨房食谱"))
	if title.length() <= 14:
		_words(title, Vector2(58, 81), 31, Color("76523d"), 435)
	else:
		for i in range(3): _words(title.substr(i * 20, 20), Vector2(58, 42 + i * 25), 21, Color("76523d"), 435)
	draw_polyline(PackedVector2Array([Vector2(57, 96), Vector2(277, 99), Vector2(492, 95)]), Color("b47050"), 2, true)
	_words("100饭店：每一餐，慢慢记下来", Vector2(59, 126), 16, Color("847456"), 435)
	if record.is_empty():
		for i in range(3):
			_sketch(Vector2(278, 239 + i * 170), i)
			_words(["暖暖的汤", "新鲜的蔬菜", "慢慢煮的面"][i], Vector2(180, 310 + i * 170), 21, Color("76523d"), 270)
		_words("从一次真实的烹饪，写下第一页。", Vector2(65, 727), 16, Color("847456"), 440)
	else:
		if _image != null and (not is_instance_valid(_collage) or not _collage.visible):
			var photo_size := _image.get_size()
			photo_size *= minf(472.0 / photo_size.x, 272.0 / photo_size.y)
			draw_texture_rect(_image, Rect2(Vector2(280, 308) - photo_size * 0.5, photo_size), false)
		elif is_instance_valid(_dish_sketch):
			_words("成品状态示意，拍照后可保留实际摆盘", Vector2(65, 465), 16, Color("847456"), 450)
		elif not is_instance_valid(_collage) or not _collage.visible:
			_words("这一页还没有照片", Vector2(160, 318), 21, Color("847456"), 310)
		_words("主厨  " + str(record.get("author", "匿名主厨")), Vector2(57, 491), 19, Color("76523d"), 448)
		var notes := str(record.get("notes", "")).strip_edges()
		if notes.is_empty(): notes = "记住这一餐的颜色，也记住亲手做它的过程。"
		var line := 0
		for offset in range(0, mini(notes.length(), 132), 22):
			_words(notes.substr(offset, 22), Vector2(58, 541 + line * 30), 18, Color("665d4a"), 444)
			line += 1
		_words("— 我的厨房手记 —", Vector2(162, 733), 15, Color("9b795c"), 300)

func _words(value: String, point: Vector2, font_size: int, color: Color, width: float) -> void:
	draw_string(FONT, point, value, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)

func _oval(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(48): points.append(center + Vector2.from_angle(i * TAU / 48) * radius)
	draw_colored_polygon(points, color)

func _sketch(center: Vector2, kind: int) -> void:
	_oval(center + Vector2(0, 10), Vector2(104, 37), Color("b8a582"))
	_oval(center, Vector2(110, 40), Color("ffedcf"))
	_oval(center, Vector2(88, 29), Color(["dba24b", "e6d5a8", "dfb263"][kind]))
	if kind == 0:
		for i in range(7):
			var p := center + Vector2(sin(i * 2.4) * 38, cos(i * 1.6) * 12)
			draw_line(p, p + Vector2(12, -7), Color("5f8060"), 5, true)
	elif kind == 1:
		for i in range(11):
			var p := center + Vector2(sin(i * 2.4) * 57, cos(i * 1.6) * 16)
			_oval(p, Vector2(12, 7), Color("648264") if i % 3 else Color("cc8155"))
	else:
		for i in range(9):
			var points := PackedVector2Array()
			for j in range(18): points.append(center + Vector2(-63 + j * 7, sin(j * 0.7 + i) * 9 + (i - 4) * 4))
			draw_polyline(points, Color("b97742") if i % 2 else Color("efd395"), 2.5, true)
