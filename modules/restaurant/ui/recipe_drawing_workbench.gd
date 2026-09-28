extends Control
## A portrait recipe on a desk: printed instructions, hand-drawn title and illustrations.
const Ink = preload("res://modules/restaurant/ui/paper_ink.gd")
var title_input: LineEdit
var author_input: LineEdit
var notes_input: TextEdit
var status: Label
var canvas

func build(game, paper, record: Dictionary) -> void:
	canvas=paper
	custom_minimum_size=Vector2(1330,690)
	canvas.reparent(self)
	canvas.position=Vector2(218,0)
	canvas.custom_minimum_size=Vector2.ZERO
	canvas.size=Vector2(560,760)
	canvas.scale=Vector2.ONE*0.87
	canvas.draw_paper=true
	canvas.mode="draw"; canvas.ink=Color("ae6350"); canvas.brush_width=3.8
	# Metadata is an archive label, never substituted for the player's ink title.
	title_input=LineEdit.new(); title_input.text=str(record.get("title","")); title_input.hide(); add_child(title_input)
	notes_input=TextEdit.new(); notes_input.text=str(record.get("notes","")); notes_input.hide(); add_child(notes_input)
	_label("一页图解菜谱",Vector2(793,28),31)
	_label("文字已经排好。\n菜名和配图，用笔亲手画。",Vector2(795,82),23)
	_label("涂鸦笔",Vector2(795,174),23)
	for i in 3:
		var tool := preload("res://modules/restaurant/ui/craft_workbench.gd").Tool.new()
		tool.text=["细笔","铅笔","宽笔"][i]; tool.symbol="pencil"; tool.canvas=canvas; tool.mode="draw"; tool.brush=["ink","pencil","marker"][i]
		tool.position=Vector2(790+i*104,211); tool.size=Vector2(94,78); add_child(tool)
		tool.pressed.connect(func():
			canvas.mode="draw"; canvas.brush_width=[3.8,3.4,9.0][i]; canvas.brush_kind=["ink","pencil","marker"][i]; canvas.changed.emit())
		canvas.changed.connect(tool.queue_redraw)
	var colors := [Color("ae6350"),Color("584d44"),Color("7c9363"),Color("c3a54f"),Color("718f9c")]
	for i in colors.size():
		var swatch := Button.new(); swatch.name="RecipeInk%d" % i
		swatch.position=Vector2(796+i*57,310); swatch.size=Vector2(43,36)
		for state in ["normal","hover","pressed"]:
			var style := StyleBoxFlat.new(); style.bg_color=colors[i]; style.set_corner_radius_all(18); style.set_border_width_all(2); style.border_color=Color("f3e8d0"); swatch.add_theme_stylebox_override(state,style)
		swatch.tooltip_text=["砖红","深墨","草绿","姜黄","蓝灰"][i]
		swatch.pressed.connect(func(): canvas.ink=colors[i]; canvas.mode="draw"; canvas.changed.emit())
		add_child(swatch)
	_button("橡皮擦",Vector2(796,366),func(): canvas.mode="erase"; canvas.changed.emit())
	_button("改材料和步骤",Vector2(940,366),func(): canvas.mode="instructions"; canvas.changed.emit())
	_button("撤销",Vector2(796,418),canvas.undo)
	_button("重做",Vector2(940,418),canvas.redo)
	_label("主厨署名",Vector2(795,486),20)
	author_input=LineEdit.new(); author_input.max_length=40
	author_input.text=str(record.get("author",game.context.get("display_name","主厨")))
	Ink.style(author_input,22); author_input.position=Vector2(795,524); author_input.size=Vector2(300,40); add_child(author_input)
	status=_label("顶部写菜名，再给步骤画配图。\n画错了，可以擦掉或撤销。",Vector2(795,596),19)
	status.size=Vector2(410,70); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	canvas.changed.emit()

func _label(words: String, position_value: Vector2, font_size: int) -> Label:
	var label := Label.new(); label.text=words; label.position=position_value
	label.add_theme_font_override("font",Ink.font()); label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("5c503e")); label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(label); return label

func _button(words: String, position_value: Vector2, callback: Callable) -> void:
	var tool := Button.new(); tool.text=words; tool.position=position_value; tool.size=Vector2(136,36)
	for state in ["normal","hover","pressed","focus"]: tool.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	tool.add_theme_font_override("font",Ink.font()); tool.add_theme_font_size_override("font_size",21)
	tool.add_theme_color_override("font_color",Color("685940")); tool.add_theme_color_override("font_hover_color",Color("b46745"))
	tool.pressed.connect(callback); add_child(tool)
