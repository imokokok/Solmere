extends Control
const Ink = preload("res://modules/restaurant/ui/paper_ink.gd")
const Paper = preload("res://modules/restaurant/ui/paper_surface.gd")
const Token = preload("res://modules/restaurant/ui/craft_token.gd")
var canvas
var game
var status: Label
var title_input: LineEdit
var author_input: LineEdit
var notes_input: TextEdit
var tray: Control

func build(owner_game, paper, record: Dictionary, dish: Dictionary, is_recipe := true) -> void:
	game = owner_game
	canvas = paper
	custom_minimum_size = Vector2(1330,690)
	var sheet := Paper.new()
	sheet.position = Vector2(12,0)
	sheet.size = Vector2(906,660)
	add_child(sheet)
	var note := Paper.new()
	note.position = Vector2(946,540)
	note.size = Vector2(364,112)
	note.ruled = true
	note.rotation = -0.015
	add_child(note)
	canvas.reparent(self)
	canvas.position = Vector2(32,88)
	canvas.custom_minimum_size = Vector2.ZERO
	canvas.size = Vector2(866,866.0*460/850)
	canvas.draw_paper = false
	title_input = LineEdit.new()
	title_input.name = "PaperTitle"
	title_input.placeholder_text = "给这一页取个名字……" if is_recipe else "写下海报的题目……"
	title_input.max_length = 60
	title_input.text = str(record.get("title",""))
	Ink.style(title_input,30)
	_place(title_input,Vector2(42,18),Vector2(810,52))
	# Metadata is editable on the paper itself; it is no longer a detached form.
	notes_input = TextEdit.new()
	notes_input.name = "PaperNotes"
	notes_input.placeholder_text = "做法、灵感，或留给下一位主厨的话……"
	notes_input.text = str(record.get("notes",""))
	Ink.style(notes_input,20)
	notes_input.scroll_fit_content_height = false
	_place(notes_input,Vector2(42,574),Vector2(840,71))
	author_input = LineEdit.new()
	author_input.name = "PaperSignature"
	author_input.max_length = 40
	author_input.text = str(record.get("author",game.context.get("display_name","主厨")))
	author_input.placeholder_text = "在这里署名"
	Ink.style(author_input,23)
	_place(author_input,Vector2(969,594),Vector2(310,38))
	_label("把这一餐，留在纸上",Vector2(949,9),26)
	_label("拿起一支笔，或拖一张小贴纸。",Vector2(949,47),17)
	var modes := [["select","移动素材","hand"],["draw","画笔涂鸦","pencil"],["write","纸上写字","ink"],["cut","剪出形状","scissors"]]
	for i in modes.size():
		var tool := Tool.new()
		tool.text = modes[i][1]
		tool.symbol = modes[i][2]
		tool.canvas = canvas
		tool.mode = modes[i][0]
		_place(tool,Vector2(950+i*89,84),Vector2(82,76))
		tool.pressed.connect(func(): canvas.finish_text(); canvas.mode=tool.mode; canvas.changed.emit())
		canvas.changed.connect(tool.queue_redraw)
	var picker := ColorPickerButton.new()
	picker.name = "CollageColor"
	picker.color = canvas.ink
	picker.custom_minimum_size = Vector2(44,28)
	_place(picker,Vector2(956,168),Vector2(44,28))
	for state in ["normal","hover","pressed"]: picker.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	picker.pressed.connect(canvas.begin_property_edit)
	picker.popup_closed.connect(canvas.end_property_edit)
	picker.color_changed.connect(func(color):
		if canvas.mode=="select" and not canvas.selected_decoration_settings().is_empty(): canvas.set_tape_color(color)
		else: canvas.ink=color)
	for i in 3:
		var width_button := _ink_button(["细笔","铅笔","宽笔"][i],Vector2(1010+i*95,168),Vector2(87,29),func(): canvas.brush_width=[2.0,4.0,11.0][i]; canvas.brush_kind=["ink","pencil","marker"][i]; canvas.mode="draw"; canvas.changed.emit())
		width_button.tooltip_text = "选择笔触粗细，在纸上按住拖动"
	_label("小贴纸",Vector2(951,216),19)
	var kinds := ["star","heart","leaf","flower","lemon","sun","polka","checker","wave","tape"]
	var names := ["星星","爱心","叶子","小花","柠檬","太阳","波点","棋盘格","波浪","胶带"]
	for i in kinds.size():
		var token := Token.new()
		token.text=names[i]
		token.payload={"type":"sticker","kind":kinds[i]}
		token.canvas=canvas
		_place(token,Vector2(950+(i%5)*72,248+int(i/5)*74),Vector2(68,69))
	_label("这一餐的材料，拖到纸上",Vector2(951,401),18)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_place(scroll,Vector2(950,429),Vector2(360,82))
	var row := HBoxContainer.new()
	scroll.add_child(row)
	var seen := {}
	for entry in dish.get("ingredients",[]):
		var value: Dictionary = {"id":entry} if entry is String else entry
		var definition: Dictionary = game._definition(str(value.get("id",value.get("ingredient_id","")))).duplicate(true)
		if definition.is_empty(): continue
		var identity := str(definition.id)+str(value.get("cut",false))+str(int(float(value.get("heat",0))/6))+JSON.stringify(value.get("surface_sauce",{}))
		if seen.has(identity): continue
		seen[identity]=true
		definition.cut=bool(value.get("cut",false)); definition.heat=float(value.get("heat",0))
		preload("res://modules/restaurant/domain/food_snapshot.gd").copy(value,definition)
		var token := Token.new()
		token.name="UsedIngredient_"+str(definition.id)
		token.set_meta("ingredient_id",definition.id)
		token.text=str(definition.name)
		token.payload={"type":"ingredient","definition":definition}
		token.canvas=canvas
		token.custom_minimum_size=Vector2(74,73)
		row.add_child(token)
	if seen.is_empty():
		var empty := Label.new()
		empty.text="尚未记录实际用料\n做过的菜，材料会留在这里。"
		empty.add_theme_font_override("font",Ink.font())
		empty.add_theme_font_size_override("font_size",17)
		row.add_child(empty)
	var recorded_photo: String = game._recipe_photo if is_recipe else (game._photo if game._photo_is_plating else "")
	if not recorded_photo.is_empty():
		var photo:=Image.new()
		if photo.load_png_from_buffer(Marshalls.base64_to_raw(recorded_photo))==OK:
			var token:=Token.new()
			token.name="RecordedDishPhoto"
			token.text="料理照片"
			token.payload={"type":"photo","texture":ImageTexture.create_from_image(photo)}
			token.canvas=canvas
			token.custom_minimum_size=Vector2(84,73)
			row.add_child(token)
	_label("这一页，由你写下",Vector2(968,556),18)
	_ink_button("加入料理照片",Vector2(42,662),Vector2(170,29),func(): game._add_dish_photo(canvas))
	_ink_button("导入照片",Vector2(222,662),Vector2(110,29),func(): game._import_collage_photo(canvas))
	_ink_button("撤销",Vector2(346,662),Vector2(68,29),canvas.undo)
	_ink_button("复制",Vector2(425,662),Vector2(68,29),canvas.duplicate_selected)
	_ink_button("删除",Vector2(505,662),Vector2(68,29),canvas.delete_selected)
	_ink_button("移到底层",Vector2(583,662),Vector2(102,29),canvas.send_selected_back)
	_ink_button("恢复原图",Vector2(694,662),Vector2(98,29),canvas.restore_selected_cut)
	_ink_button("重做",Vector2(808,662),Vector2(68,29),canvas.redo)
	status = _label("双击字迹可改写，拖动边角调整大小与方向",Vector2(945,665),14)
	status.size=Vector2(365,34)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	# Selecting a decoration exposes its two continuous dimensions, not a wall of transforms.
	var dims := HBoxContainer.new()
	dims.name="TapeDimensions"
	_place(dims,Vector2(950,511),Vector2(360,26))
	for pair in [["TapeLength",0.5,6.0,"长"],["TapeWidth",0.4,3.0,"宽"]]:
		var label := Label.new(); label.text=pair[3]; dims.add_child(label)
		var slider := HSlider.new(); slider.name=pair[0]; slider.min_value=pair[1]; slider.max_value=pair[2]; slider.step=0.05; slider.custom_minimum_size=Vector2(130,24); dims.add_child(slider)
		slider.drag_started.connect(canvas.begin_property_edit)
		slider.drag_ended.connect(func(_changed): canvas.end_property_edit())
		slider.value_changed.connect(func(value):
			if slider.name=="TapeLength": canvas.set_tape_length(value)
			else: canvas.set_tape_width(value))
	var sync := func():
		var settings: Dictionary=canvas.selected_decoration_settings() if canvas.mode=="select" else {}
		dims.visible=not settings.is_empty()
		picker.text="素材颜色" if dims.visible else "画笔颜色"
		picker.color=Color(settings.get("color",canvas.ink.to_html()))
		if dims.visible:
			dims.get_node("TapeLength").set_value_no_signal(settings.length)
			dims.get_node("TapeWidth").set_value_no_signal(settings.width)
	canvas.changed.connect(sync)
	sync.call()
	if not is_recipe:
		title_input.visible=false; notes_input.visible=false; author_input.visible=false

func _place(node: Control, point: Vector2, box: Vector2) -> void:
	add_child(node); node.position=point; node.size=box

func _label(words: String, point: Vector2, font_size: int) -> Label:
	var label := Label.new(); label.text=words
	label.add_theme_font_override("font",Ink.font()); label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("554b3a"))
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(label); label.position=point
	return label

func _ink_button(words: String, point: Vector2, box: Vector2, callback: Callable) -> Button:
	var button := Button.new(); button.text=words
	for state in ["normal","hover","pressed","focus"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.add_theme_font_override("font",Ink.font()); button.add_theme_font_size_override("font_size",18)
	button.add_theme_color_override("font_color",Color("69583e"))
	button.add_theme_color_override("font_hover_color",Color("ad623b"))
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	_place(button,point,box)
	return button

class Tool extends Button:
	var symbol := "pencil"
	var canvas
	var mode := "draw"
	var brush := ""
	func _ready() -> void:
		for state in ["normal","hover","pressed","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
		for name in ["font_color","font_hover_color","font_pressed_color"]: add_theme_color_override(name,Color.TRANSPARENT)
		mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
		mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	func _draw() -> void:
		var chosen: bool=canvas.mode==mode and (brush.is_empty() or canvas.brush_kind==brush)
		var color := Color("607f72") if chosen else Color("8b7657")
		var p := Vector2(size.x/2,29)
		if symbol in ["pencil","ink"]:
			draw_colored_polygon(PackedVector2Array([p+Vector2(-25,9),p+Vector2(20,-16),p+Vector2(26,-6),p+Vector2(-21,17)]),Color("cc965d") if symbol=="pencil" else Color("698a7a"))
			draw_colored_polygon(PackedVector2Array([p+Vector2(-25,9),p+Vector2(-21,17),p+Vector2(-35,21)]),Color("e4c697"))
			draw_line(p+Vector2(-34,20),p+Vector2(-30,18),Color("4d463b"),3,true)
		elif symbol=="scissors":
			for x in [-12,12]: draw_arc(p+Vector2(x,9),8,0,TAU,24,color,3,true)
			draw_line(p+Vector2(-7,3),p+Vector2(17,-20),color,3,true)
			draw_line(p+Vector2(7,3),p+Vector2(-17,-20),color,3,true)
		else:
			draw_arc(p+Vector2(0,3),15,0,PI,24,color,2,true)
			for x in [-12,-4,4,12]: draw_line(p+Vector2(x,3),p+Vector2(x,-16+abs(x)*0.3),color,3,true)
		draw_string(Ink.font(),Vector2(0,69),text,HORIZONTAL_ALIGNMENT_CENTER,size.x,16,color)
		if chosen or is_hovered(): draw_line(Vector2(10,74),Vector2(size.x-10,73),color,2,true)
