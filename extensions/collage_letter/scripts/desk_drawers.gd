extends Control
const PanelArt=preload("res://extensions/collage_letter/scripts/folio_panel.gd")
const Item=preload("res://extensions/collage_letter/scripts/folio_item.gd")
const DeskObject=preload("res://extensions/collage_letter/scripts/desk_object.gd")
const Tool=preload("res://extensions/collage_letter/scripts/journal_tool.gd")
var g
var shelf: Control
var kit: Control
var drag_id: int=-1
var drag_origin:=Vector2.ZERO
var drag_at:=Vector2.ZERO
var dragging_item:=false
var handle_side:=""
var handle_was_open:=false
var handle_fraction:=0.0
var preview_id: int=-1
var overlay: Control
var pigment_level: Label
var blind_drag:=false
var blind_start:=0.0
var blind_origin:=0.0
var writing: TextEdit
var ink_swatches: Array[Button]=[]
var book_animation:Tween
var book_amount:=1.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;size=Vector2(1440,900)
	shelf=PanelArt.new();shelf.g=g;shelf.material_book=true;shelf.size=Vector2(366,520);shelf.position=Vector2(38,306);add_child(shelf)
	shelf.g=g;shelf.material_book=true;shelf.mouse_filter=Control.MOUSE_FILTER_IGNORE
	kit=PanelArt.new();kit.g=g;kit.size=Vector2(360,626);kit.position=Vector2(1039 if g.tools_open else 1454,142);add_child(kit)
	build_shelf();build_kit()
	shelf.visible=g.shelf_open
	# Real objects occupy the sides; all remain clear of the A4 writing area.
	object("folio","素材夹" if g.L.language=="zh" else "Materials",Rect2(84,480,245,348),func():toggle("shelf"))
	object("tools","文具" if g.L.language=="zh" else "Tools",Rect2(1100,313,267,163),func():toggle("tools"))
	button("写几句话" if g.L.language=="zh" else "Add words",Rect2(655,817,130,36),func():g.set_tool("write"),g.tool=="write").name="WriteLetter"
	var history:=object("notebook","对话记录" if g.L.language=="zh" else "Conversation",Rect2(1252,25,119,88),g.open_commission_history);history.visible=g.letter_mode=="npc"
	object("bottle_full","海上来信" if g.L.language=="zh" else "Read a letter",Rect2(85,300,114,174),g.receive_bottle)
	object("bottle_empty","写一封新信" if g.L.language=="zh" else "Write a letter",Rect2(226,300,114,174),g.compose_from_empty_bottle)
	object("typewriter","打字机" if g.L.language=="zh" else "Typewriter",Rect2(1033,484,327,225),func():g.typewriter_open=true;g.build_ui())
	object("envelope","寄出 →" if g.L.language=="zh" else "Send →",Rect2(1120,747,190,75),g.complete_letter)
	if g.tool=="write":build_writing()
	var controls=preload("res://extensions/collage_letter/scripts/writing_controls.gd").new();controls.g=g;add_child(controls)
	if not g.example_return.is_empty():button("返回原信" if g.L.language=="zh" else "Return to draft",Rect2(1110,832,215,30),func():g.SeaExample.return_to_letter(g)).name="ReturnOriginalDraft"
	var cord:=Control.new();cord.name="BlindCord";cord.position=Vector2(1068,5);cord.size=Vector2(24,300);cord.mouse_default_cursor_shape=Control.CURSOR_VSIZE;cord.tooltip_text="向下拉绳升起百叶窗，向上推绳放下" if g.L.language=="zh" else "Pull down to raise the blind; move up to lower it";add_child(cord)
	cord.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			blind_drag=true;blind_start=g.blinds_open;blind_origin=get_global_mouse_position().y;accept_event())
	g.status_label=label(g.hint,Rect2(449,859,565,36),14);g.status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var sign_title:=label("Solmere 书信事务所",Rect2(51,33,340,44),25);sign_title.add_theme_color_override("font_color",Color("f3e2c1"))
	var sign_note:=label("给某个人的一封信" if g.L.language=="zh" else "A letter for someone",Rect2(53,79,336,28),14);sign_note.add_theme_color_override("font_color",Color("d8c5a3"))
	# Objects sit beneath the opened drawers, without invisible click areas above them.
	move_child(shelf,get_child_count()-1);move_child(kit,get_child_count()-1)
	if g.typewriter_open:
		var station=preload("res://extensions/collage_letter/scripts/typewriter_station.gd").new();station.name="TypewriterStation";station.g=g;station.desk=self;add_child(station)
func object(kind: String, title: String, rect: Rect2, action: Callable) -> Button:
	var b:=DeskObject.new();b.kind=kind;b.bottle_edition=g.sample_cycle;b.caption=title;b.font=g.font;b.name="Object_"+kind;b.tooltip_text=title;b.position=rect.position;b.size=rect.size;b.pressed.connect(action);add_child(b);return b

func build_writing() -> void:
	writing=preload("res://extensions/collage_letter/scripts/letter_input.gd").new();writing.name="LetterWriting";writing.game=g;writing.renderer=g.letter_text_node
	writing.position=g.LETTER.position+Vector2(28,35);writing.size=g.LETTER.size-Vector2(56,70);add_child(writing)
func refresh_writing_ink() -> void:
	if is_instance_valid(writing):
		g.letter_text_node.set_ink(g.letter_ink_color)
		writing.grab_focus()
	for swatch in ink_swatches:
		var ink: Color=g.LETTER_INKS[int(swatch.get_meta("ink_index"))]
		style(swatch,g.letter_ink_color==ink)
		for state in ["font_color","font_hover_color","font_pressed_color"]:swatch.add_theme_color_override(state,ink)
func t(text: String) -> String:return g.L.t(text)
func style(b: Button, active: bool=false) -> void:
	b.add_theme_font_override("font",g.font);b.add_theme_font_size_override("font_size",14);b.add_theme_color_override("font_color",Color("46685d"));b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]:
		var skin:=StyleBoxFlat.new();skin.bg_color=Color("c1c6af") if active or state!="normal" else Color("ebddbf");skin.border_color=Color("ad9e83");skin.set_border_width_all(1);skin.set_corner_radius_all(4);skin.set_content_margin_all(5);b.add_theme_stylebox_override(state,skin)
func button(text: String, rect: Rect2, action: Callable, active: bool=false, parent: Control=self) -> Button:
	var b:=Tool.new();b.text=t(text);b.position=rect.position;b.size=rect.size;style(b,active);b.clip_text=true;b.pressed.connect(action);parent.add_child(b);b.size=rect.size;return b
func label(text: String, rect: Rect2, font_size: int=16, parent: Control=self) -> Label:
	var l:=Label.new();l.text=t(text);l.position=rect.position;l.size=rect.size;l.clip_text=true;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;l.add_theme_font_override("font",g.font);l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",Color("4c5d4e"));parent.add_child(l);return l
func build_shelf() -> void:
	label("素材夹",Rect2(24,20,260,31),22,shelf)
	button("‹",Rect2(303,19,39,34),func():toggle("shelf"),false,shelf)
	var groups: Array=["字母","文字","票据","乐谱","纸张","广告","画作","照片","客户","图案"]
	for i in groups.size():
		var group: String=groups[i]
		var tab:=button(group,Rect2(25+(i%5)*65,59+(i/5)*34,60,30),func():change_book_group(group),g.drawer_group==group,shelf)
		for state in ["normal","hover","pressed","focus"]:tab.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		tab.add_theme_color_override("font_color",Color("8b5140") if g.drawer_group==group else Color("657164"))
		if g.drawer_group==group:
			var line:=ColorRect.new();line.position=Vector2(13,28);line.size=Vector2(34,2);line.color=Color("b98668");line.mouse_filter=Control.MOUSE_FILTER_IGNORE;tab.add_child(line)
	if g.source_preview_id>=0:
		preview_id=g.source_preview_id
		shelf.preview_id=preview_id
		label(g.materials[preview_id].title,Rect2(26,129,310,30),16,shelf)
		var origin:String=str(g.materials[preview_id].get("provenance_"+g.L.language,""))
		label(origin,Rect2(27,156,310,18),10,shelf)
		# The source is rendered in the world layer, aligned with this cut window.
		button("拿取整张",Rect2(23,439,150,32),func():g.take_material_whole(preview_id,g.LETTER.get_center()),false,shelf)
		button("返回素材夹",Rect2(182,439,160,32),func():g.source_preview_id=-1;g.build_ui(),false,shelf)
		var preview_ids: Array=group_material_ids()
		var previous:=button("‹",Rect2(25,478,47,30),func():turn_preview(-1),false,shelf);previous.name="PreviewPrevious";previous.disabled=preview_ids.size()<2
		var counter:=label("%d / %d" % [preview_ids.find(preview_id)+1,preview_ids.size()],Rect2(88,480,192,27),15,shelf);counter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var next:=button("›",Rect2(294,478,47,30),func():turn_preview(1),false,shelf);next.name="PreviewNext";next.disabled=preview_ids.size()<2
		return
	var ids: Array=group_material_ids()
	var per_page:=page_size()
	var pages:=maxi(1,ceili(float(ids.size())/per_page));g.drawer_page=posmod(g.drawer_page,pages)
	for n in mini(per_page,maxi(0,ids.size()-g.drawer_page*per_page)):
		var id: int=ids[g.drawer_page*per_page+n]
		var card:=Item.new();card.name="Material_"+str(id);card.desk=self;card.material_id=id
		card.position=Vector2(27,145) if per_page==1 else (Vector2(28,138+n*151) if per_page==2 else Vector2(25+n%2*160,138+n/2*151))
		card.size=Vector2(312,270) if per_page==1 else (Vector2(304,129) if per_page==2 else Vector2(150,124))
		card.icon=g.get_material_texture(id);card.expand_icon=true;card.add_theme_constant_override("icon_max_width",312 if per_page==1 else (300 if per_page==2 else 148));card.tooltip_text=g.materials[id].title;style(card)
		for state in ["normal","hover","pressed","focus"]:card.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		shelf.add_child(card)
		var caption:=label(g.materials[id].title,Rect2(card.position+Vector2(0,card.size.y+2),Vector2(card.size.x,22)),12,shelf);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var prev:=button("‹",Rect2(25,456,47,34),func():turn_book_page(-1),false,shelf);prev.name="BookPrevious";prev.disabled=pages<2
	label("— %d / %d —" % [g.drawer_page+1,pages],Rect2(88,460,192,27),15,shelf)
	var next:=button("›",Rect2(294,456,47,34),func():turn_book_page(1),false,shelf);next.name="BookNext";next.disabled=pages<2
	label("拖到信纸 · 点击可裁剪或上色",Rect2(24,493,321,24),12,shelf)
func page_size() -> int:
	return 1 if g.drawer_group in ["文字","乐谱"] else (2 if g.drawer_group in ["票据","广告"] else 4)
func group_material_ids() -> Array:
	var ids: Array=[]
	for i in g.materials.size():
		if g.drawer_group=="客户":
			if i in g.customer_material_ids():ids.append(i)
		elif i not in g.customer_material_ids() and g.materials[i].kind==g.MATERIAL_TYPES.get(g.drawer_group,""):ids.append(i)
	return ids
func turn_preview(direction: int) -> void:
	if shelf.has_node("TurningLeaf"):return
	var ids: Array=group_material_ids()
	if ids.size()<2:return
	var old_leaf:=capture_leaf()
	var index: int=posmod(ids.find(g.source_preview_id)+direction,ids.size())
	g.source_preview_id=ids[index];g.drawer_page=index/page_size()
	g.cutting_source=-1;g.path.clear()
	finish_book_turn(old_leaf,direction)
func capture_leaf() -> ImageTexture:
	var image:=get_viewport().get_texture().get_image()
	# The captured viewport may be scaled by window size; normalize to game coordinates.
	if image.get_size()!=Vector2i(1440,900):image.resize(1440,900,Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(image.get_region(Rect2i(shelf.global_position+Vector2(25,12),Vector2i(317,486))))
func finish_book_turn(old_leaf: ImageTexture, direction: int) -> void:
	var game=g
	game.audio.play("PAGE_TURN",0.65);game.build_ui()
	var leaf=preload("res://extensions/collage_letter/scripts/book_turn.gd").new();leaf.name="TurningLeaf";leaf.leaf=old_leaf;leaf.direction=direction;leaf.position=Vector2(25,12);leaf.size=Vector2(317,486)
	game.desk.shelf.add_child(leaf)
func turn_book_page(direction: int) -> void:
	if shelf.has_node("TurningLeaf"):return
	var old_leaf:=capture_leaf()
	g.drawer_page+=direction
	finish_book_turn(old_leaf,direction)
func change_book_group(group: String) -> void:
	if shelf.has_node("TurningLeaf"):return
	if g.drawer_group==group:return
	var old_leaf:=capture_leaf()
	g.drawer_group=group;g.drawer_page=0;g.source_preview_id=-1
	finish_book_turn(old_leaf,1)
func build_kit() -> void:
	label("文具盒",Rect2(25,20,250,33),22,kit)
	button("›",Rect2(303,19,37,34),func():toggle("tools"),false,kit)
	var ids: Array=["move","rect","free","tape","pen","brush","glue","write"]
	var names: Array=["移动","方框裁剪","自由裁剪","胶带","涂鸦笔","水粉笔","胶棒","写信" if g.L.language=="zh" else "Write"]
	for i in ids.size():
		var id: String=ids[i]
		var b:=button(names[i],Rect2(23+i%4*81,64+i/4*70,74,63),func():g.audio.play("TOOL_PICK",0.55);g.set_tool(id),g.tool==id,kit);b.tool_id=id;b.add_theme_font_size_override("font_size",11)
		for state in ["normal","hover","pressed","focus"]:
			var skin=b.get_theme_stylebox(state);skin.content_margin_top=34;skin.bg_color=Color("d8c5a0") if g.tool==id else Color(0,0,0,0);skin.set_border_width_all(0)
		b.size=Vector2(74,63)
	if g.tool=="write":
		label("正文墨色" if g.L.language=="zh" else "Letter ink",Rect2(26,224,300,29),18,kit)
		var ink_names: Array=["墨绿","墨蓝","炭黑","棕褐","酒红"] if g.L.language=="zh" else ["Forest","Blue","Black","Sepia","Wine"]
		for i in g.LETTER_INKS.size():
			var index: int=i;var ink: Color=g.LETTER_INKS[i]
			var swatch:=button("●",Rect2(26+i*63,273,55,45),func():g.choose_letter_ink(index),g.letter_ink_color==ink,kit)
			swatch.name="LetterInk_"+str(i);swatch.set_meta("ink_index",i);swatch.tooltip_text=ink_names[i];ink_swatches.append(swatch)
			for state in ["font_color","font_hover_color","font_pressed_color"]:swatch.add_theme_color_override(state,ink)
			var ink_name:=label(ink_names[i],Rect2(22+i*63,324,63,23),12,kit);ink_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var instruction: String="墨色用于这封信的正文。\n可以直接输入、修改和撤销。\n\n涂鸦笔可以另选颜色。" if g.L.language=="zh" else "Choose an ink for this letter.\nType, edit and undo directly on the page.\n\nDoodles have their own ink colors."
		var note:=label(instruction,Rect2(28,373,303,144),15,kit);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		button("挑选信纸" if g.L.language=="zh" else "Choose letter paper",Rect2(25,553,307,39),func():g.set_tool("move"),false,kit)
	elif g.tool=="pen":
		label("涂鸦笔",Rect2(26,224,300,29),18,kit)
		for i in 4:
			var ink: Color=[Color("40566b"),Color("915942"),Color("4b6354"),Color("443a32")][i]
			var swatch:=button("●",Rect2(27+i*81,268,70,43),func():g.pen_color=ink;g.build_ui(),g.pen_color==ink,kit);swatch.add_theme_color_override("font_color",ink)
		label("在信纸上按住鼠标涂鸦",Rect2(28,330,300,80),15,kit)
	elif g.tool=="tape":
		for i in 8:
			var index: int=i;var b:=button("",Rect2(29,224+i*38,304,30),func():g.tape_style=index;g.build_ui(),g.tape_style==i,kit);b.sample_style=i
	elif g.tool=="brush":
		label("先蘸颜料，再落笔",Rect2(26,214,307,31),18,kit)
		for i in g.paint.COLORS.size():
			var index: int=i;var b:=button("",Rect2(27+i%4*81,250+i/4*52,70,43),func():g.paint.dip(index);g.build_ui(),g.paint.color_index==i,kit);b.pigment_color=g.paint.COLORS[i];b.show_pigment=true
		button("整页涂色",Rect2(25,375,145,36),func():g.paint.scope="page";g.build_ui(),g.paint.scope=="page",kit)
		button("只涂素材",Rect2(182,375,151,36),func():g.paint.scope="material";g.build_ui(),g.paint.scope=="material",kit)
		for i in 3:
			var radius: float=[8.0,18.0,32.0][i];button(["细笔","中笔","宽笔"][i],Rect2(26+i*105,430,97,34),func():g.paint.radius=radius;g.build_ui(),g.paint.radius==radius,kit)
		button("清水晕染" if not g.paint.dilute else "浓颜料",Rect2(25,484,307,37),func():g.paint.dilute=not g.paint.dilute;g.build_ui(),false,kit)
		button("撤回这一笔",Rect2(25,535,307,37),func():g.paint.undo(),false,kit)
		pigment_level=label(t("余量")+" %d%%" % int(g.paint.load_amount*100),Rect2(28,589,300,24),13,kit)
	elif g.tool=="glue":
		var note:=label("在素材上轻轻涂抹即可。\n不需要翻面，随时可以重新排列。" if g.L.language=="zh" else "Brush gently over a piece.\nNo flipping needed; rearrange it whenever you like.",Rect2(28,234,300,130),16,kit);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	else:
		label("信纸",Rect2(26,224,300,29),18,kit)
		for i in g.LetterPaper.NAMES.size():
			var index: int=i;var sample:=button("",Rect2(25+i%4*80,268+i/4*49,70,40),func():g.choose_letter_paper(index),g.letter_paper_style==i,kit);sample.paper_style_index=i;sample.tooltip_text=t(g.LetterPaper.NAMES[i]);sample.name="LetterPaper_"+str(i)
		label(g.LetterPaper.NAMES[g.letter_paper_style],Rect2(27,592,300,26),14,kit)
func begin_material_drag(id: int, point: Vector2) -> void:drag_id=id;drag_origin=point;drag_at=point;dragging_item=false;g.audio.play("PAPER_MOVE",0.35)
func begin_handle_drag(side: String, point: Vector2) -> void:handle_side=side;drag_origin=point;handle_was_open=g.shelf_open if side=="shelf" else g.tools_open
func book_pose(amount:float) -> void:
	book_amount=amount
	var unfold:=clampf(amount/0.60,0,1)
	var enlarge:=smoothstep(0.60,1.0,amount)
	shelf.position=Vector2(84,480).lerp(Vector2(38,306),enlarge)
	shelf.scale=(Vector2(245,348)/shelf.size).lerp(Vector2.ONE,enlarge)
	shelf.open_amount=unfold
	for child in shelf.get_children():
		if child!=shelf.cover:child.modulate.a=smoothstep(0.34,0.60,amount)
	shelf.queue_redraw()
func toggle(side: String) -> void:
	if side=="shelf":
		if is_instance_valid(book_animation) and book_animation.is_running():return
		g.shelf_open=not g.shelf_open;shelf.visible=true
		book_pose(0.0 if g.shelf_open else 1.0)
		book_animation=create_tween()
		book_animation.tween_method(book_pose,0.0 if g.shelf_open else 1.0,1.0 if g.shelf_open else 0.0,1.1)
		if not g.shelf_open:book_animation.tween_callback(func():shelf.hide())
	else:
		g.tools_open=not g.tools_open
		create_tween().tween_property(kit,"position:x",1039 if g.tools_open else 1454,0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	g.audio.play("PAGE_TURN" if side=="shelf" else "PAPER_MOVE")
func _input(event: InputEvent) -> void:
	if g.conversation_open:return
	if event is InputEventMouse:event=make_input_local(event)
	var input_viewport:=get_viewport()
	if blind_drag:
		if event is InputEventMouseMotion:g.blinds_open=clampf(blind_start+(event.position.y-blind_origin)/100.0,0,1);g.queue_redraw();input_viewport.set_input_as_handled();return
		if event is InputEventMouseButton and not event.pressed:blind_drag=false;g.audio.play("PAPER_MOVE",0.25);g.save_game();input_viewport.set_input_as_handled();return
	if event is InputEventMouseMotion:
		drag_at=event.position
		if drag_id>=0 and drag_at.distance_to(drag_origin)>9:dragging_item=true;queue_redraw();get_viewport().set_input_as_handled()
		if not handle_side.is_empty():
			var direction: float=1.0 if handle_side=="shelf" else -1.0
			if handle_was_open:direction*=-1
			var distance: float=(event.position.x-drag_origin.x)*direction;handle_fraction=clampf(distance/200,0,1)
			var node: Control=shelf if handle_side=="shelf" else kit
			var closed: float=-380 if handle_side=="shelf" else 1454;var opened: float=38 if handle_side=="shelf" else 1039
			if handle_side=="shelf":shelf.visible=true;book_pose(1.0-handle_fraction if handle_was_open else handle_fraction)
			else:node.position.x=lerpf(opened if handle_was_open else closed,closed if handle_was_open else opened,handle_fraction)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		if not handle_side.is_empty():
			var side:=handle_side
			var click: bool=event.position.distance_to(drag_origin)<9
			var wanted: bool=not handle_was_open if click or handle_fraction>=0.25 else handle_was_open
			if side=="shelf":g.shelf_open=not wanted
			else:g.tools_open=not wanted
			handle_side="";handle_fraction=0;toggle(side);input_viewport.set_input_as_handled()
		if drag_id>=0:
			var id:=drag_id;drag_id=-1
			var moved: bool=dragging_item or event.position.distance_to(drag_origin)>9
			if moved and g.LETTER.has_point(event.position):g.take_material_whole(id,event.position)
			elif not moved:
				var old_leaf:=capture_leaf();g.source_preview_id=id;g.tool="rect";finish_book_turn(old_leaf,1)
			dragging_item=false;queue_redraw();input_viewport.set_input_as_handled()
func _process(_dt: float) -> void:
	for child in get_children():
		if child is DeskObject:
			var covered:bool=(child.kind=="folio" and shelf.visible) or (child.position.x<400 and g.shelf_open) or (child.get_global_rect().intersects(kit.get_global_rect()) and g.tools_open)
			child.visible=not covered and not (child.kind=="notebook" and g.letter_mode!="npc") and not (g.typewriter_open and child.kind in ["typewriter","tools","envelope"])
	kit.visible=not g.typewriter_open
	if is_instance_valid(pigment_level):pigment_level.text=t("余量")+" %d%%" % int(g.paint.load_amount*100)
	if preview_id>=0:
		g.sources[preview_id]=Rect2(shelf.position+Vector2(27,176),Vector2(312,250));g.queue_redraw()
		shelf.queue_redraw()
func _draw() -> void:
	if dragging_item and drag_id>=0:draw_texture_rect(g.get_material_texture(drag_id),Rect2(drag_at-Vector2(90,72),Vector2(180,144)),false,Color(1,1,1,0.8))
