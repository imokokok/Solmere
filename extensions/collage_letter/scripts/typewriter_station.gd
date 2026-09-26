extends Control
const Art=preload("res://extensions/collage_letter/scripts/typewriter_art.gd")
const MACHINE=Rect2(6,284,443,300)
const PAPER=Rect2(92,40,242,342)
var g
var desk
var editor:TextEdit
var cutting:=false
var cut_start:=Vector2.ZERO
var cut_end:=Vector2.ZERO
var cut_drag:=false
var uppercase:=false
var key_buttons:Array[Button]=[]
var sheet_view:SubViewport
var status:Label
var hammer:=0.0
func _ready() -> void:
	position=Vector2(949,160);size=Vector2(465,687);mouse_filter=Control.MOUSE_FILTER_STOP
	desk.button("×",Rect2(418,4,32,32),close,false,self).name="TypewriterClose"
	editor=TextEdit.new();editor.name="TypewriterText";editor.position=PAPER.position+Vector2(15,18);editor.size=PAPER.size-Vector2(30,36);editor.text=g.typewriter_text
	editor.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;editor.add_theme_font_override("font",g.font);editor.add_theme_font_size_override("font_size",13);editor.add_theme_constant_override("line_spacing",3)
	editor.add_theme_color_override("font_color",g.letter_ink_color);editor.add_theme_color_override("caret_color",g.letter_ink_color)
	for state in ["normal","focus","read_only"]:editor.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	add_child(editor);editor.grab_focus();editor.set_caret_line(editor.get_line_count()-1);editor.set_caret_column(editor.get_line(editor.get_caret_line()).length())
	editor.text_changed.connect(func():g.typewriter_text=editor.text;hammer=0.10;g.audio.play("TYPE_KEY",0.48);g.save_game();queue_redraw())
	var rows:=Art.KEY_ROWS
	for row in rows.size():
		for column in rows[row].length():
			var letter:String=rows[row][column]
			var key:Button=desk.button(letter,Rect2(MACHINE.position+Art.key_center(row,column)*MACHINE.size/Vector2(440,330)-Vector2(10,10),Vector2(20,20)),func():type_key(letter.to_upper() if uppercase else letter),false,self)
			key.name="Key_"+(letter if letter not in [',','.'] else ('Comma' if letter==',' else 'Period'));key.focus_mode=Control.FOCUS_NONE;key_buttons.append(key)
			key.text=letter.to_upper();key.add_theme_font_size_override("font_size",10)
			for state in ["normal","hover","pressed","focus"]:
				var skin:=StyleBoxFlat.new();skin.bg_color=Color("e3d4b1") if state=="normal" else Color("b5b994");skin.set_corner_radius_all(10);skin.set_content_margin_all(0);skin.border_color=Color("8d9179");skin.set_border_width_all(1);key.add_theme_stylebox_override(state,skin)
			key.size=Vector2(20,20)
	var shift:Button=desk.button("⇧",Rect2(28,542,46,30),toggle_case,false,self);shift.name="TypeShift";shift.focus_mode=Control.FOCUS_NONE
	for entry in [["Space","空格","Space",Rect2(80,542,174,30),' '],["Backspace","退格","⌫",Rect2(260,542,75,30),'\b'],["Return","回车","↵",Rect2(341,542,89,30),'\n']]:
		var value:String=entry[4];var key:Button=desk.button(entry[1] if g.L.language=="zh" else entry[2],entry[3],func():type_key(value),false,self);key.name=entry[0];key.focus_mode=Control.FOCUS_NONE
	desk.button("用这张信纸" if g.L.language=="zh" else "Use this page",Rect2(28,591,196,34),replace_letter,false,self).name="UseTypedPage"
	desk.button("裁下一段" if g.L.language=="zh" else "Cut a passage",Rect2(234,591,196,34),begin_cut,false,self).name="CutTypedPage"
	status=desk.label("点击字母键打字 · 中文可直接用键盘输入" if g.L.language=="zh" else "Click the keys, or type with your keyboard",Rect2(28,638,402,39),12,self);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if not g.typewriter_previous.is_empty():desk.button("撤回换纸" if g.L.language=="zh" else "Undo page",Rect2(10,4,135,30),undo_replace,false,self).name="UndoTypedPage"
func _draw() -> void:
	var backing:=StyleBoxFlat.new();backing.bg_color=Color("ddc6a0");backing.set_corner_radius_all(15);backing.shadow_color=Color(0.23,0.19,0.14,0.20);backing.shadow_size=10
	# The machine is a desk object; the paper and enamel body carry their own shadows.
	g.LetterPaper.paint(self,PAPER,g.letter_paper_style,false)
	Art.paint(self,MACHINE,false)
	# The preview has its own paper; a pressed typebar reaches the same caret.
	if hammer>0:
		var x:float=clampf(editor.position.x+editor.get_caret_draw_pos().x,110,319)
		draw_line(Vector2(x,386),Vector2(x,372),Color("bdb49a"),3,true)
	if cutting:
		draw_rect(PAPER,Color("826c50"),false,1.2)
		if cut_drag:draw_rect(Rect2(cut_start,cut_end-cut_start).abs(),Color("836d52"),false,1.2)
func _process(dt:float) -> void:
	if hammer>0:hammer=maxf(0,hammer-dt);queue_redraw()
func type_key(value:String) -> void:
	if cutting:return
	editor.grab_focus()
	if value=='\b':editor.backspace()
	else:editor.insert_text_at_caret(value)
func toggle_case() -> void:
	uppercase=not uppercase
	for key in key_buttons:key.text=key.text.to_upper() if uppercase else key.text.to_lower()
	editor.grab_focus()
func fits() -> bool:
	if g.typewriter_text.strip_edges().is_empty():status.text="先打一些想说的话。" if g.L.language=="zh" else "Type a few words first.";return false
	var lines:=0
	for line in editor.get_line_count():lines+=editor.get_line_wrap_count(line)+1
	if lines>19:status.text="这张纸写满了，请先删减到一页内。" if g.L.language=="zh" else "This page is full. Please shorten it before using it.";return false
	return true
func replace_letter() -> void:
	if not fits():return
	g.typewriter_previous={"text":g.letter_text,"paper":g.letter_paper_style,"ink":g.letter_ink_color.to_html()}
	g.letter_text=g.typewriter_text;g.typewriter_open=false;g.set_tool("move");g.changed()
	g.say("换好了，已有拼贴都保留。重新打开打字机可撤回换纸。" if g.L.language=="zh" else "Page changed; your collage is safe. Reopen the typewriter to undo.")
func undo_replace() -> void:
	if g.typewriter_previous.is_empty():return
	g.letter_text=g.typewriter_previous.text;g.letter_paper_style=int(g.typewriter_previous.paper);g.letter_ink_color=Color(g.typewriter_previous.ink);g.typewriter_previous={};g.changed();g.build_ui()
func begin_cut() -> void:
	if not fits():return
	cutting=true;editor.release_focus();editor.mouse_filter=Control.MOUSE_FILTER_IGNORE;editor.editable=false
	status.text="在出纸上拖一个框，裁下想要的部分。" if g.L.language=="zh" else "Drag a rectangle over the paper to cut your passage.";queue_redraw()
func _gui_input(event:InputEvent) -> void:
	if not cutting:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed and PAPER.has_point(event.position):cut_drag=true;cut_start=event.position;cut_end=cut_start;accept_event()
func _input(event:InputEvent) -> void:
	if not cut_drag:return
	if event is InputEventMouse:
		var point:Vector2=get_global_transform_with_canvas().affine_inverse()*event.position
		cut_end=point.clamp(PAPER.position,PAPER.end);queue_redraw()
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
			cut_drag=false;var crop:=Rect2(cut_start,cut_end-cut_start).abs().intersection(PAPER)
			if crop.size.x>8 and crop.size.y>8:cut_piece(crop)
		get_viewport().set_input_as_handled()
func cut_piece(crop:Rect2) -> void:
	# Render clean output at A4 scale, with no caret, selection outline or UI in the image.
	sheet_view=SubViewport.new();sheet_view.size=Vector2i(420,594);sheet_view.disable_3d=true;sheet_view.transparent_bg=true;sheet_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(sheet_view)
	var canvas:=Control.new();sheet_view.add_child(canvas)
	canvas.draw.connect(func():g.LetterPaper.paint(canvas,Rect2(0,0,420,594),g.letter_paper_style,false))
	var words:=Label.new();words.text=g.typewriter_text;words.position=Vector2(27,32);words.size=Vector2(366,530);words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;words.add_theme_font_override("font",g.font);words.add_theme_font_size_override("font_size",19);words.add_theme_constant_override("line_spacing",5);words.add_theme_color_override("font_color",g.letter_ink_color);sheet_view.add_child(words);words.size=Vector2(366,530)
	await RenderingServer.frame_post_draw
	if not is_instance_valid(sheet_view):return
	var texture:=ImageTexture.create_from_image(sheet_view.get_texture().get_image());sheet_view.queue_free()
	var normalized:=Rect2((crop.position-PAPER.position)/PAPER.size,crop.size/PAPER.size)
	var piece=g.Piece.new();piece.source_id=-5;piece.texture=texture;piece.painted_png=Marshalls.raw_to_base64(texture.get_image().save_png_to_buffer());piece.paper_thickness=0.65
	piece.handwriting=g.typewriter_text # Keep the original typed String alongside the cutout cache.
	var dimensions:=normalized.size*Vector2(300,240)
	for corner in [Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)]:piece.polygon.append((corner-Vector2.ONE*0.5)*dimensions);piece.uv.append(normalized.position+corner*normalized.size)
	# Generic clipping coordinates stay 300x240, with A4 physical proportions applied as a transform.
	piece.scale=Vector2(1,1.768);piece.position=g.LETTER.get_center();g.pieces_root.add_child(piece);g.select(piece);g.typewriter_open=false;g.set_tool("move");g.audio.play("PAPER_CUT");g.changed()
func close() -> void:
	g.typewriter_open=false;g.save_game();g.build_ui()
