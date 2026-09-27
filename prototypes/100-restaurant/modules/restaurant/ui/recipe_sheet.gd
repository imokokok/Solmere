extends Control
## The printed words and free spaces of one portrait recipe. Ink lives in PosterCanvas.
const Ink = preload("res://modules/restaurant/ui/paper_ink.gd")
const PAGE_SIZE := Vector2(560,760)
const TITLE_RECT := Rect2(44,30,472,80)
const DRAWING_RECTS := [Rect2(240,215,270,100), Rect2(268,332,245,110), Rect2(45,458,200,102), Rect2(280,589,235,108)]
const TEXT_RECTS := [Rect2(254,136,262,74), Rect2(55,337,205,100), Rect2(285,465,233,100), Rect2(57,596,216,95)]
var canvas
var fields: Array[TextEdit] = []

static func from_dish(dish: Dictionary, catalog: Array) -> Dictionary:
	if dish.get("ingredients",[]).is_empty():
		return {"version":1,"materials":"番茄一颗\n面条一份\n清水、少许盐","steps":["番茄洗净，\n切成小块。","番茄入锅，\n炒出汁。","加入清水和面条，\n慢慢煮软。","关火调味，\n盛进汤碗。"],"source":"做法示例 · 配图由你画"}
	var method = preload("res://modules/restaurant/domain/recipe_method.gd")
	var names: PackedStringArray = []
	for item in method.targets({"dish":dish}):
		names.append(method.name_of(str(item.id),catalog))
	var groups: Array = [[],[],[],[]]
	for step in method.steps({"dish":dish},catalog):
		var index := 0
		match str(step.kind):
			"take", "cut": index=0
			"pan", "water": index=1
			"cook": index=2
			_: index=3
		if not str(step.title) in groups[index]: groups[index].append(str(step.title))
	var words: Array = []
	for i in 4:
		words.append("、".join(groups[i]).left(80) if not groups[i].is_empty() else ["准备材料。","按做法搭配材料。","留意这餐的状态。","慢慢摆盘。"][i])
	return {"version":1,"materials":"\n".join(names).left(180),"steps":words,"source":"按成品状态整理 · 配图由你画"}

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1: return false
	for key in data:
		if key not in ["version","materials","steps","source"]: return false
	if not data.get("materials") is String or data.materials.length()>200: return false
	if not data.get("source") is String or data.source.length()>60: return false
	if not data.get("steps") is Array or data.steps.size()!=4: return false
	for text in data.steps:
		if not text is String or text.length()>120: return false
	return true

static func has_ink(poster: Dictionary, area: Rect2) -> bool:
	for stroke in poster.get("strokes",[]):
		for point in stroke.get("points",[]):
			if area.has_point(Vector2(float(point[0]),float(point[1]))*PAGE_SIZE): return true
	return false

static func has_title(poster: Dictionary) -> bool:
	return has_ink(poster,TITLE_RECT)

static func has_drawing(poster: Dictionary) -> bool:
	for area in DRAWING_RECTS:
		if has_ink(poster,area): return true
	return false

func build(owner_canvas) -> void:
	canvas=owner_canvas
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2.ZERO
	size=PAGE_SIZE
	_add_field(canvas.recipe_sheet.materials,Rect2(53,158,170,153),-1)
	for i in 4: _add_field(canvas.recipe_sheet.steps[i],TEXT_RECTS[i],i)
	canvas.changed.connect(sync)
	sync()

func _add_field(words: String, box: Rect2, index: int) -> void:
	var field := TextEdit.new()
	field.name="RecipeMaterials" if index<0 else "RecipeStep%d" % (index+1)
	field.text=words
	Ink.style(field,21)
	field.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	field.scroll_fit_content_height=false
	field.position=box.position; field.size=box.size
	add_child(field); fields.append(field)
	field.focus_entered.connect(func(): canvas._remember())
	field.text_changed.connect(func():
		var limit := 200 if index<0 else 120
		if field.text.length()>limit: field.text=field.text.left(limit)
		if index<0: canvas.recipe_sheet.materials=field.text
		else: canvas.recipe_sheet.steps[index]=field.text
		canvas.changed.emit())

func sync() -> void:
	var writing: bool = canvas.editable and canvas.mode=="instructions"
	for field in fields:
		field.editable=writing
		field.mouse_filter=Control.MOUSE_FILTER_STOP if writing else Control.MOUSE_FILTER_IGNORE
		field.focus_mode=Control.FOCUS_ALL if writing else Control.FOCUS_NONE
	queue_redraw()

func _draw() -> void:
	if canvas==null: return
	var ink := Color("5d4b3f")
	var accent := Color("b97558")
	draw_polyline(PackedVector2Array([Vector2(46,115),Vector2(270,117),Vector2(514,113)]),accent,1.5,true)
	if canvas.editable and not has_title({"strokes":canvas.strokes}):
		draw_string(Ink.font(),Vector2(116,74),"在这里，用笔写下菜名",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("ab9d83",0.7))
	draw_string(Ink.font(),Vector2(55,142),"材料",HORIZONTAL_ALIGNMENT_LEFT,-1,24,ink)
	for i in 4:
		var point: Vector2 = TEXT_RECTS[i].position+Vector2(-18,14)
		draw_arc(point,13,0,TAU,32,accent,1.5,true)
		draw_string(Ink.font(),point+Vector2(-5,7),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,19,accent)
		if canvas.editable and not has_ink({"strokes":canvas.strokes},DRAWING_RECTS[i]):
			var area: Rect2 = DRAWING_RECTS[i]
			draw_string(Ink.font(),area.get_center()+Vector2(-55,8),"在这里画配图",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("b5a990",0.65))
	draw_string(Ink.font(),Vector2(55,737),canvas.recipe_sheet.source,HORIZONTAL_ALIGNMENT_LEFT,455,15,Color("94836a"))
