extends Node2D

const L = preload("res://scripts/localization.gd")
const Finishing=preload("res://scripts/finishing.gd")
const BottleFinishing=preload("res://scripts/bottle_finishing.gd")
const PaperArt = preload("res://scripts/paper_art.gd")
const Piece = preload("res://scripts/collage_piece.gd")
const BottleClient = preload("res://scripts/bottle_client.gd")
const SeaExample=preload("res://scripts/sea_example.gd")
const BottleDock = preload("res://scripts/bottle_dock.gd")
const Audio = preload("res://scripts/audio_manager.gd")
const DeskDrawers=preload("res://scripts/desk_drawers.gd")
const Paint=preload("res://scripts/pigment_brush.gd")
const CommissionDialog=preload("res://scripts/commission_dialog.gd")
const LetterPaper = preload("res://scripts/letter_paper.gd")
const OfficeScene=preload("res://scripts/office_scene.gd")
const Journal = preload("res://scripts/journal_style.gd")
const ToolButton = preload("res://scripts/journal_tool.gd")
const INK = Color("465951")
const LETTER_INKS = [Color("465951"),Color("344d70"),Color("343b3c"),Color("795544"),Color("783f4a")]
const RUST = Color("ab6759")
const LETTER = Rect2(543,306,354,500) # A4, 210:297 (rounded to canvas pixels).
const MATERIAL_TYPES = {"图案":"decoration","纸张":"paper","文字":"print","票据":"ticket","乐谱":"score","画作":"art","广告":"advert","照片":"photo","字母":"letter"}
var desk
var paint
var shelf_open:=false
var tools_open:=false
var drawer_group:="字母"
var drawer_page:=0
var source_preview_id: int=-1
var source_overrides: Dictionary={}
var conversation_open:=false
var accepted_commission: int=-1
var commission_history: Dictionary={}
var commission_steps: Dictionary={}
var history_open:=false
var blinds_open: float=0.75
var example_return:Dictionary={}
var sample_reply_due:=false
var sample_cycle:=0
var showcase_seen:=false
var typewriter_text: String=""
var typewriter_open:=false
var typewriter_previous:Dictionary={}
var letter_text: String=""
var letter_ink_color: Color=INK
var letter_text_node
var letter_paper_root: Node2D
var letter_data: Dictionary=preload("res://scripts/letter_data.gd").fresh()
var writing_preferences: Dictionary={"speed":"Normal","volume":0.55,"reduce_motion":false}
var sent_letters: Array=[]
var glue_drawing:=false
var glue_last:=Vector2.ZERO
var save_path := "user://letter_v1.json"
var font: SystemFont
var audio: Node
var ui: CanvasLayer
var pieces_root: Node2D
var textures: Array[Texture2D] = []
var sources := [Rect2(62,190,300,240),Rect2(70,450,300,240),Rect2(74,450,300,240),Rect2(1074,482,300,240),Rect2(1070,196,300,240)]
var stage := "WORKBENCH"
var finishing
var bottle_finish
var commissions: Array=[]
var commission_index:=0
var dialogue := 0
var tool := "move"
var selected: Node2D
var dragging := false
var drag_offset := Vector2.ZERO
var start := Vector2.ZERO
var path := PackedVector2Array()
var cutting_source := -1
var secondary := 1
var last_sound := Vector2.ZERO
var hint := ""
var fold := 0
var envelope_inserted := false
var wax_step := 0
var wax_progress := 0.0
var seal_style := 0
var seal_points := PackedVector2Array()
var stage_drag := ""
var stage_pos := Vector2(700,310)
var stamp_holding := false
var elapsed := 0.0
var save_clock := 0.0
var entry: LineEdit
var tape_start := Vector2.ZERO
var tape_drawing := false
var letter_preview: Texture2D
var live_document: Node
var preview_path := "user://letter_preview.png"
var status_label: Label
var phase_label: Label
var help_open := false
var ready_done := false
var final_feedback := ""
var smoke := false
var busy := false
var fold_visual := 0.0
var insert_visual := 0.0
var flap_visual := 0.0
var pour_visual := 1.0
var mail_visual := 0.0
var stamp_lift := 0.0
var materials: Array = []
var source_materials: Array = []
var texture_cache: Dictionary = {}
var texture_viewports: Dictionary = {}
var texture_use_order: Array[String] = []
const MAX_CACHED_MATERIALS := 96
var catalog_group := "全部"
var catalog_page := 0
const CATALOG_PAGE_SIZE = 24
var category := "全部"
var material_page := 0
var primary := 0
var album_source := 4
var bottle: Node
var dock_open := false
var letter_mode := "npc"
var reply_parent: Dictionary = {}
var letter_title := "一封来自海边的信"
var bottle_request_id := ""
var bottle_published_id := 0
var compose_server := ""
var title_entry: LineEdit
var tape_style:=0
var doodle_drawing:=false
var doodle_path:=PackedVector2Array()
var pen_color:=Color("40566b")
var pen_width:=3.0
var overlay: Node2D
var desk_texture: Texture2D
var desk_grain: Texture2D
var paper_grain: Texture2D
var letter_paper_style:=1
var photo_source:=620
var catalog_layer: CanvasLayer

func _ready() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("This visual game needs a rendering display. Run --smoke-test without --headless; editor import can use --headless.")
		get_tree().quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			var profile:=arg.trim_prefix("--profile=").validate_filename()
			save_path="user://letter_"+profile+".json"
			preview_path="user://preview_"+profile+".png"
	L.initialize()
	paint=Paint.new(self)
	finishing=Finishing.new(self)
	bottle_finish=BottleFinishing.new(self)
	commissions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/commissions.json"))
	source_materials=JSON.parse_string(FileAccess.get_file_as_string("res://assets/materials.json"))
	_load_host_materials()
	for raw in source_materials: materials.append(L.material(raw,L.language))
	letter_title=L.t(letter_title)
	bottle=BottleClient.new()
	add_child(bottle)
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC","PingFang SC","sans-serif"])
	font.allow_system_fallback = true
	audio = Audio.new()
	add_child(audio)
	letter_paper_root=Node2D.new();letter_paper_root.name="LetterPaper";add_child(letter_paper_root)
	letter_text_node=preload("res://scripts/letter_renderer.gd").new();letter_text_node.name="LetterRenderer"
	letter_text_node.position=LETTER.position+Vector2(28,35);letter_text_node.size=LETTER.size-Vector2(56,70);letter_text_node.audio=audio;letter_paper_root.add_child(letter_text_node)
	pieces_root = Node2D.new()
	letter_paper_root.add_child(pieces_root)
	pieces_root.child_entered_tree.connect(func(piece):
		if not piece.has_meta("letter_page"):piece.set_meta("letter_page",letter_text_node.page))
	pieces_root.child_order_changed.connect(func():sync_letter_pages.call_deferred())
	overlay=load("res://scripts/work_overlay.gd").new()
	overlay.game=self;overlay.z_index=80;add_child(overlay)
	var handles=preload("res://scripts/piece_handles.gd").new();handles.name="PieceHandles";handles.game=self;handles.z_index=90;add_child(handles)
	desk_texture=load("res://assets/open_pack/desk-wood.png")
	desk_grain=load("res://assets/open_pack/desk-light-wood.png")
	paper_grain=load("res://assets/open_pack/paper/Papier6.png")
	ui = CanvasLayer.new()
	add_child(ui)
	var daylight=preload("res://scripts/desk_lighting.gd").new();daylight.name="DeskLighting";daylight.game=self;add_child(daylight)
	textures.resize(materials.size())
	for i in materials.size():
		if i>=sources.size(): sources.append(Rect2(62,190,300,240))
	update_material_slots()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	load_game();load_voyage()
	if stage!="WORKBENCH":
		live_document=preload("res://scripts/letter_document.gd").new();add_child(live_document);await live_document.build(self);letter_preview=live_document.first_page()
	if stage=="DIALOGUE": stage="WORKBENCH"
	pieces_root.visible=stage=="WORKBENCH"
	update_material_slots()
	fold_visual = float(fold)
	flap_visual = 1.0 if stage in ["WAX_SEAL","SEND","END"] else 0.0
	build_ui()
	ready_done = true
	if get_viewport()==get_tree().root:DisplayServer.window_set_title("Solmere · 拼贴书信"+ (" · 示例" if "--showcase" in OS.get_cmdline_user_args() else ""))
	if "--showcase" in OS.get_cmdline_user_args() and not showcase_seen and letter_text.is_empty() and pieces_root.get_child_count()==0:preload("res://scripts/showcase_draft.gd").apply(self)
	if hint.is_empty():say("点开桌上的素材夹，剪下字母与小镇剪报，拼成想说的话。")
	queue_redraw()
	if "--smoke-test" in OS.get_cmdline_user_args():
		smoke = true
		run_smoke_test()
	if "--network-test" in OS.get_cmdline_user_args():
		smoke=true
		run_network_test()
	if "--capture" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png("res://preview.png")
	if "--open-dock" in OS.get_cmdline_user_args():
		open_bottles()

func label_at(text: String, rect: Rect2, size: int = 18, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = L.t(text)
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_override("font",font)
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color)
	node.clip_text=true
	ui.add_child(node)
	return node

func button(text: String, rect: Rect2, action: Callable, active: bool = false) -> Button:
	var node := ToolButton.new()
	node.text = L.t(text)
	node.position = rect.position
	node.size = rect.size
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font",font)
	var fitted:=17
	while fitted>9 and (font.get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted).x>rect.size.x-16 or font.get_height(fitted)>rect.size.y-8): fitted-=1
	node.add_theme_font_size_override("font_size",fitted)
	node.set_meta("layout_rect",rect)
	node.add_theme_color_override("font_color",Color("faf3df") if active else INK)
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = (RUST if active else Color("fff3da")) if state == "normal" else Color("c5ded3")
		style.corner_radius_top_left = 13
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 13
		style.border_color = Color("90b5a4")
		style.set_border_width_all(2)
		style.content_margin_left=8
		style.content_margin_right=8
		style.content_margin_top=4
		style.content_margin_bottom=4
		node.add_theme_stylebox_override(state,style)
	node.mouse_entered.connect(func(): node.pivot_offset=node.size*0.5;node.create_tween().tween_property(node,"scale",Vector2(1.025,1.025),0.10))
	node.mouse_exited.connect(func(): node.create_tween().tween_property(node,"scale",Vector2.ONE,0.12))
	node.pressed.connect(action)
	ui.add_child(node)
	node.size=rect.size
	return node

func build_ui() -> void:
	pieces_root.visible=stage=="WORKBENCH" and not conversation_open
	letter_text_node.text=letter_text;letter_text_node.visible=stage=="WORKBENCH" and not conversation_open
	letter_text_node.set_ink(letter_ink_color)
	letter_text_node.pen_visible=tool=="write" and stage=="WORKBENCH"
	apply_writing_preferences()
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	if stage=="WORKBENCH":
		desk=DeskDrawers.new();desk.g=self;ui.add_child(desk)
		if conversation_open:
			desk.hide()
			if history_open:
				var history=load("res://scripts/commission_history.gd").new();history.g=self;history.desk=desk
				history.on_close=func():history_open=false;conversation_open=false;build_ui()
				ui.add_child(history)
			else:
				var card:=CommissionDialog.new();card.g=self;card.desk=desk;ui.add_child(card)
		queue_redraw();return
	label_at("Solmere 书信事务所",Rect2(51,33,340,44),25,Color("f3e2c1"))
	button("操作说明",Rect2(1300,39,94,34),func(): help_open = not help_open; build_ui())
	phase_label = label_at(phase_title(),Rect2(53,79,336,28),14,Color("d8c5a3"))
	status_label = label_at(hint,Rect2(58,866,1320,26),14)
	if stage in ["DIALOGUE","WORKBENCH","END"]:
		button("海边 · 漂流瓶邮局",Rect2(1175,85,219,32),open_bottles)
	if stage == "DIALOGUE":
		var lines := ["她以前总在旧公交站等我。\n后来她搬走了，我们很多年没有见面。","我不想在信里直接写「我想你」。\n也别写得像告别。","如果你愿意，把这张旧车票放进去吧。\n她应该还记得，夏天的最后一班车。"]
		label_at("林舟  /  住在旧街的客人",Rect2(585,302,660,40),22,RUST)
		label_at(lines[dialogue],Rect2(585,369,700,120),25)
		if dialogue < 2:
			button("我在听。",Rect2(590,555,230,49),advance_dialogue,true)
			button("说说那个公交站吧。",Rect2(846,555,300,49),advance_dialogue)
		else:
			button("收下车票，开始写信  →",Rect2(590,555,450,49),advance_dialogue,true)
		label_at("第一封委托    /    夏季，仍然",Rect2(585,651,650,30),17)
	elif stage == "FOLDING":
		label_at("保留那些恰好的空白。",Rect2(515,147,700,50),26)
	elif stage in ["SEND","BOTTLE"]:
		if letter_mode!="npc":
			label_at("给漂流瓶写一个标题",Rect2(360,166,460,28),17)
			title_entry=LineEdit.new()
			title_entry.position=Vector2(360,206)
			title_entry.size=Vector2(460,43)
			title_entry.max_length=40
			title_entry.text=letter_title
			title_entry.editable=bottle_request_id.is_empty()
			title_entry.add_theme_font_override("font",font)
			title_entry.text_changed.connect(func(value): letter_title=value; save_game())
			ui.add_child(title_entry)

	elif stage == "END":
		if not example_return.is_empty():button("返回原信" if L.language=="zh" else "Return to draft",Rect2(550,687,220,42),func():SeaExample.return_to_letter(self))
		label_at("信已经出发。",Rect2(540,262,700,55),36)
		label_at(final_feedback,Rect2(540,350,800,140),23)
		label_at("没有评分。你留下的排列、图像和空白，就是这封信。",Rect2(540,543,800,40),18)
		button("再写一封" if letter_mode=="npc" else "去海边读信 / 回信",Rect2(550,626,230,46),restart if letter_mode=="npc" else open_bottles,true)
		button("导出作品 PNG",Rect2(790,626,220,46),export_art)
	if help_open:
		var panel := ColorRect.new()
		panel.position = Vector2(350,192)
		panel.size = Vector2(740,510)
		panel.color = Color("f6efdb")
		ui.add_child(panel)
		label_at("桌边操作指南",Rect2(392,216,650,44),28)
		label_at("① 刻刀：在纸张上拖方框，或按住划出自由轮廓。\n② 纸片：选中后拖角缩放、拖边拉伸，圆柄旋转。\n③ 胶带：沿纸片边缘拖出一条装饰胶带。\n④ 素材按类型分类；字母可直接拿取，涂鸦笔按住绘画。\n⑤ 漂流瓶：自由发信、读旧信、回复其他寄信人。\n\n滚轮缩放 · Q / E 旋转 · Delete 删除 · 右键返回移动\n发出新漂流瓶后，需要回复一封来信，才能再发新信。\n自动保存作品和回信对象；发信失败可以原样重试。",Rect2(392,287,670,340),20)
		button("回到桌边",Rect2(804,630,230,43),func(): help_open=false; build_ui(),true)
	queue_redraw()

func phase_title() -> String:
	return {"DIALOGUE":"01  /  听一段往事","WORKBENCH":"02  /  捡到语言，重新排列","BOTTLE":"让这封信，随海风出发","FOLDING":"03  /  折好这一页","ENVELOPE":"04  /  装进信封","WAX_SEAL":"05  /  留下一枚火漆","SEND":"06  /  寄向远方","END":"07  /  夏季，仍然"}.get(stage,"")

func say(text: String) -> void:
	hint = text
	if is_instance_valid(status_label):
		status_label.text = L.t(hint)

func _draw() -> void:
	if not font:
		return
	draw_rect(Rect2(0,0,1440,900),Color("dcb38b"))
	if desk_grain:
		draw_set_transform(Vector2(1440,0),PI/2)
		draw_texture_rect(desk_grain,Rect2(0,0,900,1440),false,Color(1.0,0.91,0.79,0.25))
		draw_texture_rect(desk_texture,Rect2(0,0,900,1440),false,Color(1,0.9,0.8,0.055))
		draw_set_transform(Vector2.ZERO)
	for seam in [286,576,873]:
		var contour:=PackedVector2Array()
		for x in range(0,1441,20):contour.append(Vector2(x,seam+sin(x*0.004+seam)*2))
		draw_polyline(contour,Color(0.31,0.23,0.17,0.16),2,true)
	OfficeScene.paint(self)
	if stage=="WORKBENCH" and conversation_open:return
	if stage == "WORKBENCH":
		LetterPaper.paint(self,LETTER,letter_paper_style)
		if cutting_source >= 0 and path.size()>1:
			if tool == "rect":
				draw_rect(Rect2(start,get_global_mouse_position()-start).abs(),Color(0.9,0.85,0.72,0.08))
				draw_rect(Rect2(start,get_global_mouse_position()-start).abs(),Color("f4ead1"),false,1)
			else:
				draw_polyline(path,Color("f4ead1"),1.3,true)

		if tool in ["rect","free"]:
			var tip:=get_global_mouse_position()
			draw_line(tip+Vector2(7,-9),tip+Vector2(27,-40),Color("735e4c"),8,true)
			draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(5,-20),tip+Vector2(12,-12)]),Color("e5e9db"))
	elif stage == "FOLDING":
		var rect := LETTER
		var third: float=LETTER.size.y/3.0
		rect.size.y -= minf(fold_visual,1.0)*third
		if fold_visual > 1:
			rect.position.y += (fold_visual-1)*third
			rect.size.y -= (fold_visual-1)*third
		LetterPaper.paint(self,rect,letter_paper_style)
		if letter_preview and fold_visual < 0.01:
			draw_texture_rect(letter_preview,rect,false)
		elif letter_preview and fold_visual < 1:
			draw_texture_rect_region(letter_preview,Rect2(LETTER.position,Vector2(LETTER.size.x,third*2)),Rect2(Vector2.ZERO,Vector2(letter_preview.get_size())*Vector2(1,0.6667)))
			LetterPaper.paint(self,Rect2(LETTER.position.x,LETTER.position.y+third*2-minf(fold_visual,1)*third,LETTER.size.x,third*minf(fold_visual,1)),letter_paper_style)
		if fold < 2:
			var y: float=LETTER.position.y+third*(2 if fold==0 else 1)
			for x in range(int(LETTER.position.x)+10,int(LETTER.end.x)-10,18):
				draw_line(Vector2(x,y),Vector2(x+9,y),Color("9d967e"),1)
			text_at("↑ 将下沿向上拖动" if fold==0 else "↓ 将上沿向下拖动",Vector2(582,742),22)
		else:
			text_at("按一下，压平最后的折痕",Vector2(552,625),22)
	elif stage=="BOTTLE":
		bottle_finish.draw()
	elif finishing.active():
		finishing.draw()
	elif stage == "END":
		paper(Rect2(490,222,850,497),Color("f5edda"))
		paper(Rect2(94,225,326,453),Color("f7efdf"))
		if letter_preview:
			draw_texture_rect(letter_preview,Rect2(104,235,306,433),false)

func text_at(text: String, at: Vector2, size: int = 20, color: Color = INK) -> void:
	draw_string(font,at,L.t(text),HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func paper(rect: Rect2, color: Color) -> void:
	var points:=PackedVector2Array()
	var corners: Array=[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	for side in 4:
		var begin: Vector2=corners[side];var end: Vector2=corners[(side+1)%4]
		var steps:=maxi(2,int(begin.distance_to(end)/12))
		for index in steps:
			var point:=begin.lerp(end,float(index)/steps)
			point+=Vector2(sin(index*13+side*7+rect.position.x),cos(index*9+side*3))*1.2
			points.append(point)
	var shade:=PackedVector2Array()
	for point in points: shade.append(point+Vector2(4,5))
	draw_colored_polygon(shade,Color(0.19,0.14,0.09,0.16))
	painted_polygon(points,color,0.16)

func draw_ellipse_custom(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 40:
		points.append(center+Vector2(cos(i*TAU/40),sin(i*TAU/40))*radius)
	draw_colored_polygon(points,color)

func draw_seal(style: int) -> void:
	var color := Color("d69569")
	match style:
		0:
			draw_polyline(PackedVector2Array([Vector2(-17,1),Vector2(-8,-7),Vector2(0,1),Vector2(8,-7),Vector2(17,1)]),color,2.4,true)
		1:
			draw_line(Vector2(-9,14),Vector2(8,-14),color,2,true)
			for p in [Vector2(-3,3),Vector2(3,-5)]:
				draw_arc(p+Vector2(4,0),5,PI,TAU,14,color,2,true)
				draw_arc(p-Vector2(4,2),5,0,PI,14,color,2,true)
		2:
			var star := PackedVector2Array()
			for i in 11:
				var a := i*TAU/10-PI/2
				star.append(Vector2(cos(a),sin(a))*(15 if i%2==0 else 6))
			draw_polyline(star,color,2,true)

func advance_dialogue() -> void:
	audio.play("DIALOGUE_ADVANCE")
	if dialogue < 2:
		dialogue += 1
	else:
		stage = "WORKBENCH"
		say("先拿起刻刀，在纸张上框住一段字；也可以从右侧的画作裁一小片颜色。")
	changed()
	build_ui()

func set_tool(value: String) -> void:
	if value=="write" and tool=="write" and is_instance_valid(desk) and is_instance_valid(desk.writing):
		desk.writing.grab_focus();return
	if paint and paint.active:paint.end()
	tool = value
	if tool=="write":
		select(null);say("点击信纸慢慢写。文具盒里可以换墨色，照片可以稍后添上。" if L.language=="zh" else "Write at your own pace. Change ink in the tool box; add photos whenever you like.");build_ui();return
	dragging = false
	cutting_source = -1
	tape_drawing = false
	say({"move":"选中素材后，拖角缩放、拖边调整宽高，拖圆柄旋转。","rect":"刻刀方框裁切：在纸张上按住左键拖动，松开切下。","free":"刻刀自由裁切：按住左键沿边缘划一圈，松开闭合。","tape":"按住左键拉出胶带，松开截断；胶带可以重新摆放。","pen":"按住鼠标在信纸上涂鸦。松手留下笔迹，可以移动、缩放或删除。","brush":"先蘸颜料；整页模式可画过纸片，只涂素材会锁住边缘。","glue":"在素材上轻轻涂抹即可，不需要翻面；随时可以重新排列。"}[tool])
	build_ui()

func pick(point: Vector2) -> Node2D:
	var children := pieces_root.get_children()
	children.reverse()
	for piece in children:
		if piece.visible and piece.hit(point):
			return piece
	return null

func select(piece: Node2D) -> void:
	if selected and is_instance_valid(selected):
		selected.selected = false
		selected.queue_redraw()
	selected = piece
	if selected:
		selected.selected = true
		selected.queue_redraw()

func _input(event: InputEvent) -> void:
	if stage!="WORKBENCH" or conversation_open:return
	if event is InputEventMouse:event=make_input_local(event)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		if paint and paint.active:paint.move(event.position);paint.end()
		if glue_drawing:glue_drawing=false;changed()
		if dragging and is_instance_valid(selected):selected.position=(event.position+drag_offset).clamp(Vector2(25,130),Vector2(1415,770));selected.release_lift();dragging=false;changed()

func _unhandled_input(event: InputEvent) -> void:
	if not ready_done or help_open or busy or dock_open or conversation_open or is_instance_valid(catalog_layer):
		return
	var mouse := get_global_mouse_position()
	# Fast queued press/release events can share the latest OS cursor position.
	# Use each event's own viewport position so short drags retain their origin.
	if event is InputEventMouse:
		mouse=get_canvas_transform().affine_inverse()*event.position
	if stage=="BOTTLE":
		if event is InputEventMouseMotion:bottle_finish.move(mouse)
		elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:bottle_finish.input(mouse,event.pressed)
		return
	if finishing.active():
		if event is InputEventMouseMotion: finishing.mouse_move(mouse)
		elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT: finishing.input(mouse,event.pressed)
		return
	if event is InputEventKey and event.pressed and stage == "WORKBENCH":
		if selected and is_instance_valid(selected):
			match event.keycode:
				KEY_Q: selected.rotation -= 0.075; changed()
				KEY_E: selected.rotation += 0.075; changed()
				KEY_DELETE: delete_selected()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and stage == "WORKBENCH":
			set_tool("move")
			return
		if stage == "WORKBENCH" and selected and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := 1.07 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/1.07
			if absf(selected.scale.x*factor) >= 0.25 and absf(selected.scale.x*factor) <= 3.0:
				selected.scale *= factor
				changed()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if stage != "WORKBENCH":
			stage_input(mouse,event.pressed)
			return
		if event.pressed:
			start = mouse
			last_sound = mouse
			if tool in ["rect","free"]:
				for i in ([source_preview_id] if shelf_open and source_preview_id>=0 else []):
					if sources[i].has_point(mouse):
						cutting_source = i
						path = PackedVector2Array([mouse])
						audio.play("KNIFE_SLICE")
						break
			elif tool=="brush":
				paint.begin(mouse)
			elif tool=="glue":
				glue_drawing=true;glue_last=mouse;apply_glue(mouse,0.12)
			elif tool == "tape":
				tape_start = mouse
				tape_drawing = true
				audio.play("TAPE_PULL")
			elif tool=="pen" and LETTER.has_point(mouse):
				doodle_drawing=true;doodle_path=PackedVector2Array([mouse])
				audio.play("PENCIL_DRAW")
			elif tool == "move":
				select(pick(mouse))
				if not selected:
					for id in [primary,secondary]:
						if materials[id].kind=="letter" and sources[id].has_point(mouse):
							take_letter(id,mouse);break
				if selected:
					selected.raise_paper()
					dragging = true
					drag_offset = selected.position-mouse
					audio.play("PAPER_MOVE")
				build_ui()
		else:
			if paint.active:paint.move(mouse);paint.end()
			glue_drawing=false
			if doodle_drawing: finish_doodle()
			if cutting_source >= 0:
				finish_cut(mouse)
			if tape_drawing:
				finish_tape(mouse)
			if dragging:
				selected.release_lift()
				press_glued_piece(selected)
				audio.play("PHOTO_DROP" if selected.source_id==4 else "PAPER_PRESS")
			dragging = false
			changed()
	elif event is InputEventMouseMotion:
		if stage == "WORKBENCH":
			if paint.active:paint.move(mouse)
			if glue_drawing:apply_glue(mouse,minf(0.25,mouse.distance_to(glue_last)*0.015));glue_last=mouse
			if doodle_drawing and LETTER.has_point(mouse) and doodle_path[-1].distance_to(mouse)>2:
				doodle_path.append(mouse);audio.play("PENCIL_DRAW")
			if dragging and selected:
				selected.position = mouse+drag_offset
				selected.position = selected.position.clamp(Vector2(25,130),Vector2(1415,770))
				refresh_paper_stack()
			if cutting_source >= 0:
				var bound: Rect2 = sources[cutting_source]
				var clamped := mouse.clamp(bound.position+Vector2(1,1),bound.end-Vector2(1,1))
				if path[-1].distance_to(clamped)>4:
					path.append(clamped)
			if mouse.distance_to(last_sound)>30:
				if cutting_source>=0:
					audio.play("KNIFE_SLICE",0.65)
				last_sound = mouse
		elif stage == "ENVELOPE" and stage_drag == "letter":
			stage_pos = mouse
	queue_redraw()

func roughen(poly: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i+1)%poly.size()]
		var length := a.distance_to(b)
		var steps := maxi(1,int(length/10))
		var normal := (b-a).normalized().orthogonal()
		for j in steps:
			result.append(a.lerp(b,float(j)/steps)+normal*randf_range(-1.5,1.5))
	if Geometry2D.triangulate_polygon(result).is_empty():
		return poly
	return result

func finish_cut(mouse: Vector2) -> void:
	var source := cutting_source
	cutting_source = -1
	var bound: Rect2 = sources[source]
	var poly := PackedVector2Array()
	if tool == "rect":
		var box := Rect2(start,mouse-start).abs().intersection(bound)
		if box.size.x < 14 or box.size.y < 14:
			say("切口太小了，试着圈住更大一点的纸。")
			return
		poly = PackedVector2Array([box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)])
	else:
		poly = path.duplicate()
		if poly.size()<5 or Geometry2D.triangulate_polygon(poly).is_empty():
			say("这条轮廓没有形成可裁区域。请画一圈不交叉的轮廓。")
			return
	var center := Vector2.ZERO
	for point in poly:
		center += point
	center /= poly.size()
	var piece := Piece.new()
	piece.paper_thickness=1.4 if materials[source].kind in ["photo","art"] else (0.4 if materials[source].kind in ["score","advert"] else 0.85)
	piece.source_id = source
	piece.font = font
	piece.source_language=L.language
	piece.texture = get_material_texture(source)
	if source_overrides.has(L.language+":"+str(source)):piece.painted_png=Marshalls.raw_to_base64(piece.texture.get_image().save_png_to_buffer())
	for point in roughen(poly):
		piece.polygon.append(point-center)
		piece.uv.append((point-bound.position).clamp(Vector2.ZERO,bound.size)/bound.size)
	piece.position = Vector2(680+randf_range(-80,80),430+randf_range(-70,70))
	piece.rotation = randf_range(-0.04,0.04)
	pieces_root.add_child(piece)
	select(piece)
	audio.play("PAPER_CUT")
	set_tool("move")
	say("裁下来了。拖到喜欢的位置，松手就放好；随时可以重新排列。")
	changed()

func finish_tape(mouse: Vector2) -> void:
	tape_drawing = false
	if mouse.distance_to(tape_start)<16:
		return
	var length := minf(mouse.distance_to(tape_start),500)
	var piece := Piece.new()
	piece.source_id = -2
	piece.tape_style=tape_style
	piece.font = font
	piece.polygon = roughen(PackedVector2Array([Vector2(-length/2,-11),Vector2(length/2,-11),Vector2(length/2,11),Vector2(-length/2,11)]))
	piece.position = (tape_start+mouse)/2
	piece.rotation = (mouse-tape_start).angle()
	piece.is_taped = true
	pieces_root.add_child(piece)
	for other in pieces_root.get_children():
		if other == piece:
			continue
		for i in 20:
			if other.hit(tape_start.lerp(mouse,float(i)/19)):
				other.is_taped = true
				break
	select(piece)
	audio.play("TAPE_TEAR")
	get_tree().create_timer(0.16).timeout.connect(func(): audio.play("TAPE_STICK"))
	set_tool("move")
	say("胶带贴好了。选中后拖角调整大小，拖圆柄旋转。")

func add_handwriting() -> void:
	var value := entry.text.strip_edges()
	if value.is_empty():
		return
	var chinese := false
	for character in value:
		if character.unicode_at(0)>127:
			chinese = true
	if chinese and value.length()>20:
		say("这一小段最多 20 个字，留一些空白给纸片吧。")
		return
	var piece := Piece.new()
	piece.font = font
	piece.source_id = -1
	piece.handwriting = value
	var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x+22
	piece.polygon = roughen(PackedVector2Array([Vector2(-width/2,-22),Vector2(width/2,-22),Vector2(width/2,22),Vector2(-width/2,22)]))
	piece.position = Vector2(720,510)
	pieces_root.add_child(piece)
	select(piece)
	set_tool("move")
	audio.play("PAPER_MOVE")
	changed()

func delete_selected() -> void:
	if selected and is_instance_valid(selected):
		pieces_root.remove_child(selected)
		selected.queue_free()
		selected = null
		changed()
		build_ui()

func _process(delta: float) -> void:
	if not ready_done:
		return
	for piece in pieces_root.get_children():piece.visible=int(piece.get_meta("letter_page",0))==letter_text_node.page
	if stage=="ENVELOPE":letter_text_node.state=letter_text_node.State.INSERTING
	elif stage=="SEND":letter_text_node.state=letter_text_node.State.SEALED
	elif stage=="END":letter_text_node.state=letter_text_node.State.SENT
	elapsed += delta
	save_clock += delta
	if save_clock > 3:
		save_clock = 0
		save_game()
	finishing.tick(delta)
	if stage=="BOTTLE":bottle_finish.tick(delta)
	overlay.queue_redraw()
	queue_redraw()

func complete_letter() -> void:
	if busy or stage!="WORKBENCH":
		return
	var count := 0
	if not letter_text.strip_edges().is_empty():
		count=1
	for piece in pieces_root.get_children():
		if LETTER.has_point(piece.position):
			count += 1
	if count == 0:
		say("信纸还空着。写一点想说的话，或挑选素材开始拼贴吧。" if L.language=="zh" else "The page is empty. Write a few words or choose a piece to start your collage.")
		return
	select(null)
	busy=true
	letter_text_node.text=letter_text
	letter_text_node.request_finish()
	if is_instance_valid(desk) and is_instance_valid(desk.writing):desk.writing.editable=false
	await letter_text_node.finished
	letter_data["completed"]=true
	letter_text_node.page=0
	tool = "move"
	build_ui()
	if is_instance_valid(live_document):live_document.queue_free()
	live_document=preload("res://scripts/letter_document.gd").new();add_child(live_document)
	await live_document.build(self)
	letter_preview=live_document.first_page()
	if not smoke:letter_preview.get_image().save_png(preview_path)
	stage = "FOLDING"
	letter_text_node.state=letter_text_node.State.FOLDING
	if letter_mode!="npc":stage="BOTTLE";bottle_finish=BottleFinishing.new(self)
	fold = 0
	fold_visual = 0
	pieces_root.visible = false
	letter_text_node.hide()
	say(bottle_finish.hint() if stage=="BOTTLE" else "用鼠标参与折叠：先把下半部向上拖，再把上半部向下拖。")
	changed()
	busy=false
	build_ui()

func stage_input(mouse: Vector2, down: bool) -> void:
	if busy:
		return
	if down:
		start = mouse
	match stage:
		"FOLDING":
			if not down:
				if fold==0 and Rect2(522,547,396,187).has_point(start) and mouse.y<start.y-65:
					fold=1
					audio.play("PAPER_FOLD")
					animate_property("fold_visual",1.0,0.45)
				elif fold==1 and Rect2(522,174,396,187).has_point(start) and mouse.y>start.y+65:
					fold=2
					audio.play("PAPER_FOLD")
					animate_property("fold_visual",2.0,0.45)
				elif fold==2 and Rect2(522,361,396,187).has_point(mouse):
					stage="ENVELOPE"
					stage_pos=Vector2(720,285)
					finishing=Finishing.new(self)
					finishing.say()
					audio.play("PAPER_PRESS")
					build_ui()
				changed()
		"ENVELOPE", "WAX_SEAL", "SEND": finishing.input(mouse,down)

func generate_seal() -> void:
	seal_points.clear()
	for i in 48:
		var angle := i*TAU/48
		var radius := randf_range(29,34)+sin(angle*3)*2
		seal_points.append(Vector2(cos(angle),sin(angle))*radius)

func send_letter() -> void:
	if stage != "SEND" or busy or not finishing.delivery_ready:
		return
	if letter_mode!="npc":
		await send_bottle()
		return
	var request: Dictionary=commissions[commission_index%commissions.size()]
	final_feedback=str(request["reply_"+L.language])
	if not finishing.impression_good:
		final_feedback+="\n"+L.t("火漆留下了不规则的印记，它也是这封信的一部分。")
	stage = "END"
	say("你的信件已保存。愿远处的人，在某个下午收到它。")
	changed()
	build_ui()

func restart() -> void:
	letter_text="";letter_text_node.load_text("");letter_data=preload("res://scripts/letter_data.gd").fresh();history_open=false
	for piece in pieces_root.get_children():
		pieces_root.remove_child(piece)
		piece.queue_free()
	selected=null
	if stage=="END" and letter_mode=="npc": commission_index+=1
	conversation_open=true
	source_overrides.clear();source_preview_id=-1;shelf_open=false;tools_open=false
	stage="WORKBENCH"
	finishing=Finishing.new(self)
	letter_mode="npc"
	reply_parent={}
	bottle_request_id=""
	bottle_published_id=0
	dialogue=0
	fold=0
	envelope_inserted=false
	wax_step=0
	wax_progress=0
	stage_drag=""
	stamp_holding=false
	fold_visual=0
	flap_visual=0
	mail_visual=0
	insert_visual=0
	tool="move"
	pieces_root.visible=false
	say("一封新信，一次新的排列。")
	changed()
	build_ui()

func export_art() -> void:
	if not letter_preview:
		return
	var destination := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES).path_join("CollageLetter_"+Time.get_datetime_string_from_system().replace(":","-")+".png")
	var result := letter_preview.get_image().save_png(destination)
	say("作品已导出："+destination if result==OK else "导出失败，请检查图片文件夹权限。")

func changed() -> void:
	pieces_root.visible = stage=="WORKBENCH" and not conversation_open
	refresh_paper_stack()
	queue_redraw()
	save_game()

func refresh_paper_stack() -> void:
	var below: Array=[]
	for piece in pieces_root.get_children():
		piece.refresh_stack(below)
		below.append(piece)

func animate_property(property: String, target: float, duration: float, after: Callable = Callable()) -> void:
	busy=true
	var tween := create_tween()
	tween.tween_property(self,property,target,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	busy=false
	if after.is_valid():
		after.call()

func _load_host_materials() -> void:
	pass

func _host_save_data() -> Dictionary:
	return {}

func save_game(force: bool = false) -> void:
	if smoke and not force:
		return
	if stage=="END":archive_current_letter()
	var all: Array = []
	for piece in pieces_root.get_children():
		all.append(piece.serialize())
	var points: Array = []
	for p in seal_points:
		points.append([p.x,p.y])
	var painted_sources: Dictionary={}
	for key in source_overrides:painted_sources[key]=Marshalls.raw_to_base64(source_overrides[key].get_image().save_png_to_buffer())
	var data := {"version":4,"paper_layout":2,"showcase_seen":showcase_seen,"source_overrides":painted_sources,"accepted_commission":accepted_commission,"letter_paper_style":letter_paper_style,"finishing":finishing.serialize(),"commission_index":commission_index,"letter_mode":letter_mode,"reply_parent":reply_parent,"letter_title":letter_title,"bottle_request_id":bottle_request_id,"bottle_published_id":bottle_published_id,"compose_server":compose_server,"category":category,"material_page":material_page,"album_source":album_source,"photo_source":photo_source,"task":"summer_still_here","stage":stage,"dialogue":dialogue,"pieces":all,"fold":fold,"inserted":envelope_inserted,"wax_step":wax_step,"wax_progress":wax_progress,"seal_style":seal_style,"seal_points":points,"feedback":final_feedback,"muted":audio.muted,"photos":[{"id":materials[album_source].asset,"title":materials[album_source].title}],"owned_sources":[0,1,2,3,4]}
	data.merge(_host_save_data(),true)
	var file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	data["commission_history"]=commission_history;data["commission_steps"]=commission_steps
	data["example_return"]=example_return;data["sample_reply_due"]=sample_reply_due;data["sample_cycle"]=sample_cycle;data["typewriter_text"]=typewriter_text;data["typewriter_previous"]=typewriter_previous;data["letter_text"]=letter_text;data["letter_ink_color"]=letter_ink_color.to_html(false);data["blinds_open"]=blinds_open
	data["letter_data"]=current_letter_data();data["writing_preferences"]=writing_preferences;data["sent_letters"]=sent_letters;data["letter_page"]=letter_text_node.page
	data["bottle_finishing"]=bottle_finish.serialize()
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		var result := DirAccess.rename_absolute(save_path+".tmp",save_path)
		if result!=OK:
			say("本次保存失败，请检查存档目录是否可写。")

func load_game(force: bool = false) -> void:
	if not force and ("--smoke-test" in OS.get_cmdline_user_args() or "--network-test" in OS.get_cmdline_user_args() or "--fresh" in OS.get_cmdline_user_args()):
		return
	if not FileAccess.file_exists(save_path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or int(data.get("version",0)) not in [1,2,3,4]:
		say("存档无法读取，已开始新的委托。")
		return
	for piece in pieces_root.get_children():
		pieces_root.remove_child(piece)
		piece.queue_free()
	selected=null
	seal_points.clear()
	accepted_commission=int(data.get("accepted_commission",-1))
	commission_history=data.get("commission_history",{});commission_steps=data.get("commission_steps",{})
	showcase_seen=bool(data.get("showcase_seen",false))
	example_return=data.get("example_return",{});sample_reply_due=bool(data.get("sample_reply_due",false));sample_cycle=int(data.get("sample_cycle",0))
	typewriter_text=str(data.get("typewriter_text",""));typewriter_previous=data.get("typewriter_previous",{})
	letter_data=preload("res://scripts/letter_data.gd").restore(data.get("letter_data",{}))
	writing_preferences.merge(data.get("writing_preferences",{}),true);sent_letters=data.get("sent_letters",[])
	letter_text=str(data.get("letter_data",{}).get("full_text",data.get("letter_text","")));letter_text_node.load_text(letter_text)
	letter_text_node.page=clampi(int(data.get("letter_page",0)),0,letter_text_node.page_count-1)
	letter_ink_color=INK
	for color in LETTER_INKS:
		if color.to_html(false)==str(data.get("letter_ink_color",INK.to_html(false))):letter_ink_color=color;break
	letter_text_node.set_ink(letter_ink_color)
	blinds_open=clampf(float(data.get("blinds_open",0.75)),0,1)
	source_overrides.clear()
	for key in data.get("source_overrides",{}):
		var paint_image:=Image.new()
		if paint_image.load_png_from_buffer(Marshalls.base64_to_raw(data.source_overrides[key]))==OK:source_overrides[key]=ImageTexture.create_from_image(paint_image)
	letter_mode=data.get("letter_mode","npc")
	reply_parent=data.get("reply_parent",{})
	letter_title=data.get("letter_title","一封来自海边的信")
	bottle_request_id=data.get("bottle_request_id","")
	bottle_published_id=int(data.get("bottle_published_id",0))
	compose_server=data.get("compose_server","")
	letter_paper_style=clampi(int(data.get("letter_paper_style",0)),0,LetterPaper.NAMES.size()-1)
	category=data.get("category","全部")
	material_page=int(data.get("material_page",0))
	album_source=clampi(int(data.get("album_source",4)),0,materials.size()-1)
	photo_source=clampi(int(data.get("photo_source",620)),620,625)
	stage = data.get("stage","WORKBENCH")
	if stage=="DIALOGUE": stage="WORKBENCH"
	if stage not in ["DIALOGUE","WORKBENCH","FOLDING","ENVELOPE","WAX_SEAL","SEND","BOTTLE","END"]:
		stage="DIALOGUE"
	commission_index=maxi(0,int(data.get("commission_index",0)))
	finishing=Finishing.new(self)
	finishing.restore(data.get("finishing",{}))
	bottle_finish=BottleFinishing.new(self);bottle_finish.restore(data.get("bottle_finishing",{}))
	if stage in ["WAX_SEAL","SEND"] and not data.has("finishing"):
		finishing.inserted=true;finishing.flap=1
		if stage=="SEND": finishing.phase="COOL";finishing.cool=2
	dialogue=clampi(int(data.get("dialogue",0)),0,2)
	fold=clampi(int(data.get("fold",0)),0,2)
	envelope_inserted=data.get("inserted",false)
	wax_step=clampi(int(data.get("wax_step",0)),0,6)
	wax_progress=float(data.get("wax_progress",0))
	if wax_step==5:
		wax_progress=0
	seal_style=clampi(int(data.get("seal_style",0)),0,2)
	final_feedback=data.get("feedback","")
	if data.get("muted",false)!=audio.muted:
		audio.toggle()
	for point in data.get("seal_points",[]):
		seal_points.append(Vector2(point[0],point[1]))
	if seal_points.size()<3:
		generate_seal()
	for record in data.get("pieces",[]):
		var piece := Piece.new()
		piece.set_meta("letter_page",int(record.get("letter_page",0)))
		piece.source_id=int(record.get("source",0))
		piece.font=font
		piece.material_revision=int(record.get("material_revision",1))
		if piece.source_id>=0 and piece.source_id<textures.size():
			piece.source_language=str(record.get("source_language","en"))
			piece.texture=get_material_texture(piece.source_id,piece.source_language,piece.material_revision)
		for p in record.get("polygon",[]):
			piece.polygon.append(Vector2(p[0],p[1]))
		for p in record.get("uv",[]):
			piece.uv.append(Vector2(p[0],p[1]))
		if piece.polygon.size()<3:
			piece.free()
			continue
		piece.position=Vector2(record.position[0],record.position[1])
		piece.rotation=float(record.rotation)
		piece.scale=Vector2(record.scale[0],record.scale[1])
		if int(data.get("paper_layout",1))<2:
			piece.position=LETTER.position+(piece.position-Vector2(522,174))*LETTER.size/Vector2(396,560)
			piece.scale*=LETTER.size/Vector2(396,560)
		piece.paper_thickness=clampf(float(record.get("paper_thickness",0.8)),0.25,1.8)
		piece.is_glued=bool(record.get("glued",false))
		piece.glue_coverage=float(record.get("glue_coverage",0))
		piece.back_visible=false # Legacy drafts always reopen face up; never lock their edits.
		for mark in record.get("glue_marks",[]):piece.glue_marks.append(Vector2(mark[0],mark[1]))
		piece.painted_png=str(record.get("painted_png",""))
		if not piece.painted_png.is_empty():
			var img:=Image.new()
			if img.load_png_from_buffer(Marshalls.base64_to_raw(piece.painted_png))==OK:piece.texture=ImageTexture.create_from_image(img)
		piece.is_taped=record.get("taped",false)
		piece.handwriting=record.get("text","")
		piece.alpha_hit=bool(record.get("alpha_hit",false))
		piece.tape_style=int(record.get("tape_style",0))
		piece.pen_color=Color(str(record.get("pen_color","40566b")))
		piece.pen_width=float(record.get("pen_width",3))
		for p in record.get("strokes",[]): piece.strokes.append(Vector2(p[0],p[1]))
		pieces_root.add_child(piece)
	sync_letter_pages()
	letter_text_node.page=clampi(int(data.get("letter_page",0)),0,letter_text_node.page_count-1)
	if not smoke and FileAccess.file_exists(preview_path):
		letter_preview=ImageTexture.create_from_image(Image.load_from_file(preview_path))
	pieces_root.visible=stage=="WORKBENCH"
	refresh_paper_stack()
	say("已恢复上次的信件。慢慢来，桌上的纸都还在。")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and ready_done:
		save_game()
		audio.shutdown()

func run_smoke_test() -> void:
	load("res://scripts/finishing_smoke.gd").run(self)

func capture_test(filename: String) -> void:
	var output := OS.get_environment("COLLAGE_TEST_OUTPUT")
	if output.is_empty():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(filename+".png"))

func material_ids(filter_category: String = "") -> Array:
	var ids: Array=[]
	var current := category if filter_category.is_empty() else filter_category
	for i in materials.size():
		if materials[i].kind not in ["art","photo"] and (current=="全部" or materials[i].kind==MATERIAL_TYPES.get(current,"")):
			ids.append(i)
	return ids

func close_material_catalog() -> void:
	if is_instance_valid(catalog_layer): catalog_layer.queue_free()
	catalog_layer=null

func select_catalog_material(id: int) -> void:
	close_material_catalog()
	if materials[id].kind=="letter":
		take_letter(id,Vector2(700,420));return
	var location := "左侧素材夹"
	if materials[id].kind=="photo":
		photo_source=id;location="右下方照片"
	elif materials[id].kind=="art":
		album_source=id
		location="右上方画作相册"
	else:
		category=MATERIAL_TYPES.find_key(materials[id].kind)
		material_page=material_ids().find(id)/2
	update_material_slots()
	say("已拿出「"+str(materials[id].title)+"」· "+location+"，可用刻刀裁取。")
	changed()
	build_ui()

func catalog_ids() -> Array:
	var ids: Array=[]
	for i in materials.size():
		if catalog_group=="全部" or (catalog_group=="私人车票" and materials[i].category=="私人") or (materials[i].category!="私人" and materials[i].kind==MATERIAL_TYPES.get(catalog_group,"")): ids.append(i)
	return ids

func open_material_catalog() -> void:
	close_material_catalog()
	dragging=false;cutting_source=-1;tape_drawing=false
	catalog_layer=CanvasLayer.new();catalog_layer.layer=20;add_child(catalog_layer)
	var shade:=ColorRect.new()
	shade.size=Vector2(1440,900);shade.color=Color(0.16,0.20,0.17,0.72);catalog_layer.add_child(shade)
	var panel:=Panel.new()
	panel.position=Vector2(230,100);panel.size=Vector2(980,690)
	var cover:=StyleBoxFlat.new();cover.bg_color=Color("fff0d5");cover.border_color=Color("81b6a9");cover.set_border_width_all(9);cover.set_corner_radius_all(24);panel.add_theme_stylebox_override("panel",cover);catalog_layer.add_child(panel)
	var heading:=Label.new()
	heading.text=L.t("素材一览")+" · "+str(materials.size())+L.t(" 份")
	heading.position=Vector2(256,119);heading.add_theme_font_override("font",font)
	heading.add_theme_font_size_override("font_size",23);heading.add_theme_color_override("font_color",INK);catalog_layer.add_child(heading)
	var close:=Button.new()
	close.text=L.t("回到桌边");close.position=Vector2(1040,120);close.size=Vector2(140,38)
	close.add_theme_font_override("font",font);close.pressed.connect(close_material_catalog);catalog_layer.add_child(close)
	var filter:=OptionButton.new()
	filter.name="CatalogCategory";filter.position=Vector2(560,120);filter.size=Vector2(260,38)
	filter.add_theme_font_override("font",font)
	var groups: Array=["全部","图案","纸张","广告","文字","票据","乐谱","画作","照片","字母","私人车票"]
	for group in groups: filter.add_item(L.t(group))
	filter.select(groups.find(catalog_group))
	filter.item_selected.connect(func(index): catalog_group=groups[index];catalog_page=0;open_material_catalog())
	catalog_layer.add_child(filter)
	var ids:=catalog_ids()
	var pages:=maxi(1,ceili(ids.size()/float(CATALOG_PAGE_SIZE)))
	catalog_page=posmod(catalog_page,pages)
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(256,174);scroll.size=Vector2(928,548);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	catalog_layer.add_child(scroll)
	var grid:=GridContainer.new()
	grid.columns=3;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",8);scroll.add_child(grid)
	for id in ids.slice(catalog_page*CATALOG_PAGE_SIZE,(catalog_page+1)*CATALOG_PAGE_SIZE):
		var item:=Button.new()
		item.name="Material_"+str(id);item.text=materials[id].title;item.tooltip_text=item.text
		item.icon=get_material_texture(id);item.expand_icon=true
		item.add_theme_constant_override("icon_max_width",84)
		item.add_theme_font_override("font",font);item.add_theme_font_size_override("font_size",16)
		item.add_theme_color_override("font_color",INK);item.add_theme_color_override("font_hover_color",INK)
		item.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		for state in ["normal","hover","pressed"]:
			var style:=StyleBoxFlat.new()
			style.bg_color=Color("f8e3c5") if state=="normal" else Color("c5ded3")
			style.set_corner_radius_all(12)
			style.border_color=Color("90b5a4");style.set_border_width_all(1);style.set_content_margin_all(8)
			item.add_theme_stylebox_override(state,style)
		item.custom_minimum_size=Vector2(292,84);item.alignment=HORIZONTAL_ALIGNMENT_LEFT
		item.pressed.connect(select_catalog_material.bind(id));grid.add_child(item)
	for delta in [-1,1]:
		var paging:=Button.new()
		paging.text="‹" if delta<0 else "›"
		paging.tooltip_text=L.t("上一页" if delta<0 else "下一页")
		paging.position=Vector2(256 if delta<0 else 1024,738);paging.size=Vector2(160,36)
		paging.add_theme_font_override("font",font)
		paging.pressed.connect(func(): catalog_page+=delta;open_material_catalog());catalog_layer.add_child(paging)
	var counter:=Label.new()
	counter.text="%d / %d · %d" % [catalog_page+1,pages,ids.size()]+L.t(" 份")
	counter.position=Vector2(620,744);counter.add_theme_font_override("font",font);counter.add_theme_color_override("font_color",INK);catalog_layer.add_child(counter)

func get_material_texture(id: int, locale: String = "",revision:int=2) -> Texture2D:
	if locale.is_empty(): locale=L.language
	var key:=locale+":"+str(id)+(":legacy" if revision<2 else "")
	if source_overrides.has(key):return source_overrides[key]
	if not texture_cache.has(key):
		var viewport:=SubViewport.new()
		viewport.size=Vector2i(300,240)
		viewport.transparent_bg=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		add_child(viewport)
		var art:=PaperArt.new()
		var raw:Dictionary=source_materials[id]
		if revision<2:
			var legacy:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/materials_legacy.json"))
			raw=legacy.get(str(id),raw)
		art.kind=id;art.sheet_data=L.material(raw,locale);art.font=font
		viewport.add_child(art)
		texture_cache[key]=viewport.get_texture()
		texture_viewports[key]=viewport
	texture_use_order.erase(key)
	texture_use_order.append(key)
	if locale==L.language: textures[id]=texture_cache[key]
	prune_material_textures(key)
	return texture_cache[key]

func prune_material_textures(keep_key: String = "") -> void:
	if texture_cache.size()<=MAX_CACHED_MATERIALS: return
	var protected: Dictionary={keep_key:true}
	for id in [primary,secondary,album_source,photo_source]:
		protected[L.language+":"+str(id)]=true
	if source_preview_id>=0:protected[L.language+":"+str(source_preview_id)]=true
	if is_instance_valid(desk) and is_instance_valid(desk.shelf):
		for card in desk.shelf.find_children("Material_*","Button",true,false):
			protected[L.language+":"+card.name.trim_prefix("Material_")]=true
	for piece in pieces_root.get_children():
		if piece.source_id>=0:
			protected[piece.source_language+":"+str(piece.source_id)+(":legacy" if piece.material_revision<2 else "")]=true
	if is_instance_valid(catalog_layer):
		for card in catalog_layer.find_children("Material_*","Button",true,false):
			protected[L.language+":"+card.name.trim_prefix("Material_")]=true
	for old_key in texture_use_order.duplicate():
		if texture_cache.size()<=MAX_CACHED_MATERIALS: break
		if protected.has(old_key): continue
		var old_texture: Texture2D=texture_cache[old_key]
		texture_cache.erase(old_key)
		texture_use_order.erase(old_key)
		var old_viewport: SubViewport=texture_viewports[old_key]
		texture_viewports.erase(old_key)
		old_viewport.queue_free()
		var parts: PackedStringArray=old_key.split(":",false,1)
		if parts[0]==L.language:
			var old_id:=int(parts[1])
			if textures[old_id]==old_texture: textures[old_id]=null

func switch_language() -> void:
	L.choose("en" if L.language=="zh" else "zh")
	if bottle.token.is_empty() and bottle.display_name in ["海边来客","Seaside Guest"]: bottle.display_name=L.t("海边来客")
	materials.clear();textures.fill(null)
	for raw in source_materials: materials.append(L.material(raw,L.language))
	update_material_slots();build_ui()
	if get_viewport()==get_tree().root: DisplayServer.window_set_title(L.t("拼贴书信 · Solmere 书信事务所"))

func update_material_slots() -> void:
	var ids:=material_ids()
	if ids.is_empty():
		category="全部"
		ids=material_ids()
	var pages:=ceili(ids.size()/2.0)
	material_page=posmod(material_page,pages)
	primary=ids[material_page*2]
	secondary=ids[mini(material_page*2+1,ids.size()-1)]
	# Every category has at least two sheets, so both table slots remain independent.
	if secondary==primary:
		secondary=ids[0]
	sources[primary]=Rect2(62,190,300,240)
	sources[secondary]=Rect2(70,450,300,240)
	sources[album_source]=Rect2(1070,196,300,240)
	sources[photo_source]=Rect2(1070,484,300,240)
	for id in [primary,secondary,album_source,photo_source]: get_material_texture(id)
	audio.play("PAPER_MOVE",0.5)
	queue_redraw()

func cycle_photo() -> void:
	var ids: Array=[]
	for i in materials.size():
		if materials[i].category=="影像":
			ids.append(i)
	album_source=ids[(ids.find(album_source)+1)%ids.size()]
	update_material_slots()
	changed()
	build_ui()

func receive_bottle() -> void:
	if busy or dock_open:return
	dock_open=true
	var ritual=preload("res://scripts/incoming_bottle.gd").new();ritual.name="IncomingBottle";ritual.g=self;add_child(ritual)
func compose_from_empty_bottle() -> void:
	if sample_reply_due or bottle.player.get("reply_required",false):
		say("先给收到的来信回一封，再让新的漂流瓶出发。" if L.language=="zh" else "Reply to a received letter before sending another new one.");receive_bottle();return
	if not bottle.player.is_empty():start_bottle({});return
	SeaExample.start_reply(self)
	letter_mode="local_bottle";letter_text="";typewriter_text=""
	for piece in pieces_root.get_children():pieces_root.remove_child(piece);piece.queue_free()
	selected=null;letter_title="来自 Solmere 的信" if L.language=="zh" else "A letter from Solmere";set_tool("move");changed()
	say("本地漂流体验：写完一封新信后，再回复一封来信。可在海上来信的邮局设置中连接其他玩家。" if L.language=="zh" else "Local voyage: reply to a received letter after sending a new one. Connect to other players in Post Office Settings.")
func open_bottles() -> void:
	if busy or dock_open:
		return
	dragging=false
	tape_drawing=false
	cutting_source=-1
	save_game()
	dock_open=true
	var dock:=BottleDock.new()
	dock.g=self;dock.client=bottle
	dock.font=font
	add_child(dock)
	dock.compose_requested.connect(start_bottle)
	dock.example_requested.connect(func():SeaExample.start_reply(self))
	dock.closed.connect(func(): dock_open=false)
	dock.open()

func start_bottle(parent: Dictionary) -> void:
	# Keep the collage if the player brings the current open draft to the sea.
	if stage!="WORKBENCH":
		restart()
	letter_mode="bottle" if parent.is_empty() else "reply"
	conversation_open=false;history_open=false
	reply_parent={"id":int(parent.get("id",0)),"title":parent.get("title",""),"caption":parent.get("caption","")} if not parent.is_empty() else {}
	compose_server=bottle.base_url
	letter_title=L.t("一封来自海边的信") if parent.is_empty() else (L.t("回信：")+str(parent.title)).left(40)
	bottle_request_id=""
	bottle_published_id=0
	stage="WORKBENCH"
	tool="write"
	pieces_root.visible=true
	say("写给还没有遇见的人。慢慢写，准备好后把信卷起装进瓶子。" if parent.is_empty() else "正在回复 #"+str(parent.id)+" · "+str(parent.title))
	changed()
	build_ui()

func send_bottle() -> void:
	if not letter_preview:
		say("没有找到信件作品，请回到桌边完成这封信。" if L.language=="zh" else "Return to the desk and finish your letter first.")
		return
	if letter_mode in ["example","local_bottle"]:
		sample_reply_due=letter_mode=="local_bottle";sample_cycle+=1;save_voyage()
		final_feedback=("回信已在本地示例中寄出。\n谢谢你认真读完这封信。" if letter_mode=="example" else "新信已在本地漂流体验中寄出。\n下一步：打开有纸卷的瓶子，回一封来信。") if L.language=="zh" else "Your local voyage is complete. Read a letter and leave someone a reply."
		stage="END";changed();audio.play("MAIL_DROP",0.4);build_ui();return
	if not compose_server.is_empty() and compose_server!=bottle.base_url:
		say("这封草稿属于另一个邮局，请重新连接原邮局后再寄出。")
		return
	if letter_title.strip_edges().is_empty():
		say("请先写一个信件标题。")
		return
	busy=true
	say("正在把信交给海岸邮局……")
	if bottle.player.is_empty():
		var connection: Dictionary=await bottle.connect_service(bottle.base_url,bottle.display_name)
		if not connection.ok:
			busy=false
			say(connection.get("error","连接失败，请重试。"))
			return
	if bottle_request_id.is_empty():
		bottle_request_id=Crypto.new().generate_random_bytes(16).hex_encode()
		save_game()
	if is_instance_valid(title_entry):
		title_entry.editable=false
	var art:=letter_preview.get_image()
	if art.get_width()>700 or art.get_height()>900:
		var fit:=minf(700.0/art.get_width(),900.0/art.get_height())
		art.resize(roundi(art.get_width()*fit),roundi(art.get_height()*fit),Image.INTERPOLATE_LANCZOS)
	var payload: Dictionary={"request_id":bottle_request_id,"title":letter_title.strip_edges(),"caption":letter_text,"letter_data":current_letter_data(),"art_png":Marshalls.raw_to_base64(art.save_png_to_buffer())}
	payload["parent_id"]=int(reply_parent.id) if letter_mode=="reply" else null
	var result: Dictionary=await bottle.publish(payload)
	busy=false
	if not result.ok:
		say(result.get("error","寄出失败，信仍在这里，可以重试。"))
		build_ui()
		return
	bottle_published_id=int(result.letter_id)
	final_feedback="漂流瓶 #%d 已留在海上。\n下一步：读一封来信，给另一个人回信。" % bottle_published_id if letter_mode=="bottle" else "回信 #%d 已送到对方的信箱。\n你现在可以投出新的漂流瓶了。" % bottle_published_id
	# Persist the committed result before animation; a lost response can be retried with the same request id.
	stage="END"
	changed()
	audio.play("MAIL_DROP")
	say("信已寄出。后来的人仍然可以读到，并继续回复。")
	build_ui()

func run_network_test() -> void:
	save_path="user://network_test_draft.json"
	bottle.identity_path="user://network_test_identity_a.json"
	bottle.identities={}
	var url:=OS.get_environment("COLLAGE_TEST_URL")
	if url.is_empty():
		url="http://127.0.0.1:8789"
	var result: Dictionary=await bottle.connect_service(url,"测试寄信人甲")
	assert(result.ok)
	var other:=BottleClient.new()
	add_child(other)
	other.identity_path="user://network_test_identity_b.json"
	other.identities={}
	result=await other.connect_service(url,"测试寄信人乙")
	assert(result.ok)
	start_bottle({})
	letter_text="测试信：海边的风很轻，愿你的今天也能放松一些。";letter_text_node.text=letter_text
	build_ui();await get_tree().process_frame
	await capture_test("v2-workbench")
	await complete_letter()
	assert(stage=="BOTTLE" and letter_preview!=null)
	await send_bottle()
	assert(stage=="END")
	assert(bottle.player.reply_required)
	var original:=bottle_published_id
	var second: Dictionary={"title":"不应发出","caption":"test","request_id":Crypto.new().generate_random_bytes(16).hex_encode()}
	result=await bottle.publish(second)
	assert(not result.ok)
	result=await other.publish({"title":"来自乙的回声","caption":"我听见了。","parent_id":original,"request_id":Crypto.new().generate_random_bytes(16).hex_encode()})
	assert(result.ok)
	result=await bottle.request("/v1/letters?view=inbox")
	assert(result.ok and result.letters.size()==1)
	var reply: Dictionary=result.letters[0]
	start_bottle(reply)
	save_game(true)
	load_game(true)
	assert(letter_mode=="reply" and int(reply_parent.id)==int(reply.id))
	letter_text="谢谢你回信。这里有一朵刚刚看到的小花，也想让你看见。";letter_text_node.text=letter_text
	build_ui();await get_tree().process_frame
	await complete_letter()
	assert(stage=="BOTTLE")
	await send_bottle()
	assert(stage=="END" and not bottle.player.reply_required)
	open_bottles()
	await get_tree().create_timer(1).timeout
	var dock: Node=get_child(get_child_count()-1)
	assert(dock is CanvasLayer)
	await dock.show_letter(original)
	await capture_test("v2-bottle-dock")
	print("NETWORK PASS: Godot A sends artwork / debt blocks send / B replies / A inbox / reply draft survives reload / A replies / debt clears / UI displays original artwork")
	for file in [save_path,bottle.identity_path,other.identity_path]:
		DirAccess.remove_absolute(file)
	audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func cycle_snapshot() -> void:
	var ids: Array=[]
	for i in materials.size():
		if materials[i].kind=="photo": ids.append(i)
	photo_source=ids[(ids.find(photo_source)+1)%ids.size()]
	update_material_slots();changed();build_ui()

func finish_doodle() -> void:
	doodle_drawing=false
	if doodle_path.size()<2:return
	var piece:=Piece.new()
	piece.source_id=-3;piece.font=font;piece.pen_color=pen_color;piece.pen_width=pen_width
	piece.position=doodle_path[0]
	var bounds:=Rect2(Vector2.ZERO,Vector2.ONE)
	for point in doodle_path:
		piece.strokes.append(point-piece.position);bounds=bounds.expand(point-piece.position)
	bounds=bounds.grow(5)
	piece.polygon=PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
	pieces_root.add_child(piece);changed()

func take_letter(id: int, at: Vector2) -> void:
	if id<0 or id>=materials.size() or materials[id].kind!="letter": return
	var raw: Texture2D=load("res://assets/open_pack/"+str(materials[id].asset))
	var dimensions:=raw.get_size()*minf(170.0/raw.get_width(),165.0/raw.get_height())
	var piece:=Piece.new()
	piece.source_id=id;piece.source_language=L.language;piece.font=font
	piece.texture=get_material_texture(id);piece.alpha_hit=true
	for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var point: Vector2=corner*dimensions*0.5
		piece.polygon.append(point)
		piece.uv.append((Vector2(150,119)+point)/Vector2(300,240))
	piece.position=at;piece.scale=Vector2(0.45,0.45)
	pieces_root.add_child(piece);select(piece);set_tool("move")
	audio.play("PAPER_MOVE")
	say("字母已拿到信纸上。选中后拖角缩放、拖边调整宽高，圆柄旋转。")
	changed();build_ui()

func painted_polygon(points: PackedVector2Array, color: Color, grain: float = 0.14) -> void:
	draw_colored_polygon(points,color)
	if paper_grain and points.size()>2:
		var bounds:=Rect2(points[0],Vector2.ONE)
		for p in points: bounds=bounds.expand(p)
		var uv:=PackedVector2Array()
		for p in points: uv.append((p-bounds.position)/bounds.size)
		draw_polygon(points,PackedColorArray([Color(color,grain)]),uv,paper_grain)

func choose_letter_ink(index: int) -> void:
	letter_ink_color=LETTER_INKS[clampi(index,0,LETTER_INKS.size()-1)]
	letter_text_node.set_ink(letter_ink_color)
	if is_instance_valid(desk):desk.refresh_writing_ink()
	save_game()

func choose_letter_paper(index: int) -> void:
	letter_paper_style=clampi(index,0,LetterPaper.NAMES.size()-1)
	audio.play("PAPER_MOVE")
	say("换好了信纸，已贴的内容都保留。")
	changed();build_ui()

func open_commission() -> void:
	history_open=false;conversation_open=true;build_ui()
func open_commission_history() -> void:
	history_open=true;conversation_open=true;build_ui()
func customer_material_ids() -> Array:
	var ids: Array=[]
	for id in commissions[commission_index%commissions.size()].get("attachments",[622,623]):ids.append(int(id))
	return ids
func take_material_whole(id: int, at: Vector2) -> void:
	if materials[id].kind=="letter":take_letter(id,at);return
	var piece:=Piece.new();piece.source_id=id;piece.source_language=L.language;piece.texture=get_material_texture(id);piece.font=font
	piece.polygon=PackedVector2Array([Vector2(-150,-120),Vector2(150,-120),Vector2(150,120),Vector2(-150,120)])
	piece.uv=PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)])
	piece.alpha_hit=true;piece.position=at;piece.scale=Vector2.ONE*0.68;piece.paper_thickness=1.3 if materials[id].kind in ["photo","art"] else 0.65
	var override_key:=L.language+":"+str(id)
	if source_overrides.has(override_key):piece.painted_png=Marshalls.raw_to_base64(piece.texture.get_image().save_png_to_buffer())
	pieces_root.add_child(piece);select(piece);set_tool("move");audio.play("PAPER_MOVE",0.5);changed()
func apply_glue(at: Vector2, amount: float) -> void:
	var piece=pick(at)
	if not piece or piece.source_id<0:return
	if amount<=0:return
	piece.add_glue(at);piece.glue_flash=0.8;piece.back_visible=false;audio.play("GLUE_BRUSH",0.3)
	press_glued_piece(piece);changed()
func press_glued_piece(piece) -> void:
	if piece.source_id<0 or piece.back_visible or piece.glue_coverage<0.6 or not LETTER.has_point(piece.position):return
	piece.is_glued=true;piece.release_lift();piece.queue_redraw();audio.play("PAPER_PRESS");say("贴好了，仍然可以拖动和调整大小。")
func transform_selected(factor: float, angle: float) -> void:
	if not is_instance_valid(selected):return
	if absf(selected.scale.x*factor)>=0.25 and absf(selected.scale.x*factor)<=3.0:selected.scale*=factor
	selected.rotation+=angle;changed()

func voyage_path() -> String:
	return str(example_return.get("save",save_path)).get_basename()+"_voyage.json"
func save_voyage() -> void:
	var file:=FileAccess.open(voyage_path(),FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"due":sample_reply_due,"cycle":sample_cycle}))
func load_voyage() -> void:
	if not FileAccess.file_exists(voyage_path()):return
	var record=JSON.parse_string(FileAccess.get_file_as_string(voyage_path()))
	if record is Dictionary:sample_reply_due=record.get("due",false);sample_cycle=int(record.get("cycle",0))

func apply_writing_preferences() -> void:
	letter_text_node.writing_speed=str(writing_preferences.speed);letter_text_node.pen_volume=float(writing_preferences.volume);letter_text_node.reduce_motion=bool(writing_preferences.reduce_motion)
func current_letter_data() -> Dictionary:
	letter_data.full_text=letter_text;letter_data.letter_type=letter_mode
	letter_data.reply_to=reply_parent.get("id");letter_data.reply_chain_id=str(reply_parent.get("reply_chain_id",reply_parent.get("id","")))
	letter_data.author_id=str(bottle.player.get("id",""))
	letter_data.sealed=stage in ["SEND","END"] or (stage=="BOTTLE" and bottle_finish.phase in ["SEA","WAIT"])
	letter_data.sent=stage=="END"
	return letter_data.duplicate(true)
func play_letter_animation(value: String) -> void:
	letter_text=value;build_ui();letter_text_node.play_letter_animation(value)
func sync_letter_pages() -> void:
	var count:=1
	for piece in pieces_root.get_children():count=maxi(count,int(piece.get_meta("letter_page",0))+1)
	if letter_text_node.minimum_pages!=count:
		letter_text_node.minimum_pages=count;letter_text_node.reflow()
func letter_puzzle_payload() -> Dictionary:
	return current_letter_data()

func archive_current_letter() -> void:
	for record in sent_letters:
		if record.get("letter_id")==letter_data.letter_id:return
	var record:=current_letter_data();record["pieces"]=[];record["paper_style"]=letter_paper_style;record["ink"]=letter_ink_color.to_html()
	for piece in pieces_root.get_children():record.pieces.append(piece.serialize())
	sent_letters.append(record)
