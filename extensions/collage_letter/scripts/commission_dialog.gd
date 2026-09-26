extends Control
const Stationery=preload("res://extensions/collage_letter/scripts/commission_stationery.gd")
var g
var desk
var body: Label
var speaker: Label
var reply: Button
var choices: Control
var attachments: Control
var stationery: Control
var later: Button
var step: int=0
var char_clock:=0.0
var question_return:=false
var accepted:=false
var reading_history:=false
var question_index: int=-1
var lines: Array=[]
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP;size=Vector2(1440,900)
	stationery=Stationery.new();stationery.dialogue=true;stationery.position=Vector2(310,183);stationery.size=Vector2(820,500);stationery.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(stationery)
	var request: Dictionary=g.commissions[g.commission_index%g.commissions.size()]
	lines=request.get("dialogue_"+g.L.language,[])
	if lines.is_empty():lines=[{"speaker":"npc","text":request["request_"+g.L.language],"reply":desk.t("好的，请交给我。")},{"speaker":"player","text":desk.t("做好后，我会帮您寄出。"),"reply":"›"},{"speaker":"npc","text":desk.t("好的，麻烦您了。"),"reply":desk.t("开始拼贴") }]
	var heading: String="来访者" if g.L.language=="zh" else "A visitor"
	desk.label(heading,Rect2(354,216,480,34),23,self)
	conversation_button("对话记录" if g.L.language=="zh" else "Conversation",Rect2(910,214,174,38),open_history)
	speaker=desk.label(request["name_"+g.L.language],Rect2(354,288,725,31),19,self)
	body=desk.label("",Rect2(354,339,725,156),22,self);body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	choices=Control.new();choices.mouse_filter=Control.MOUSE_FILTER_IGNORE;choices.position=Vector2(0,0);add_child(choices)
	attachments=Control.new();attachments.position=Vector2(354,500);attachments.size=Vector2(725,152);attachments.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(attachments)
	desk.label("对方带来的素材" if g.L.language=="zh" else "Brought by the visitor",Rect2(0,0,650,25),16,attachments)
	desk.label("接下委托后，可从素材夹的「客户」页取用。" if g.L.language=="zh" else "Accept the request to use these from the Client tab.",Rect2(0,128,725,24),13,attachments)
	for i in g.customer_material_ids().size():
		var id: int=g.customer_material_ids()[i]
		var photo:=TextureRect.new();photo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;photo.texture=g.get_material_texture(id);photo.position=Vector2(i*350,34);photo.size=Vector2(110,82);photo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;photo.mouse_filter=Control.MOUSE_FILTER_IGNORE;attachments.add_child(photo)
		var caption: Label=desk.label(g.materials[id].title,Rect2(122+i*350,45,210,59),15,attachments);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	reply=conversation_button("›",Rect2(774,608,310,44),advance,true)
	later=conversation_button("稍后继续" if g.L.language=="zh" else "Continue later",Rect2(354,608,172,44),close)
	step=clampi(int(g.commission_steps.get(str(g.commission_index),0)),0,lines.size()-1)
	show_step()
func show_step() -> void:
	g.commission_steps[str(g.commission_index)]=step
	var line: Dictionary=lines[step]
	stationery.player_speaking=line.get("speaker","npc")=="player"
	speaker.text=desk.t("我") if line.get("speaker","npc")=="player" else g.commissions[g.commission_index%g.commissions.size()]["name_"+g.L.language]
	body.text=str(line.text);body.visible_characters=0;char_clock=0;reply.text=desk.t("显示整段")
	body.add_theme_font_size_override("font_size",21 if g.L.language=="zh" else 19)
	# Enclosures become meaningful when the client introduces them, not on the greeting.
	attachments.visible=step>=3 and not g.customer_material_ids().is_empty()
	var has_questions: bool=bool(line.get("questions",false))
	stationery.size.y=570 if attachments.visible else (500 if has_questions else 410)
	reply.position.y=682 if attachments.visible else (608 if has_questions else 518)
	later.position.y=reply.position.y
	stationery.queue_redraw()
	queue_redraw()
	for child in choices.get_children():choices.remove_child(child);child.queue_free()
func _process(dt: float) -> void:
	if reading_history:return
	if body.visible_characters>=body.text.length():return
	char_clock+=dt
	while char_clock>=0.042 and body.visible_characters<body.text.length():
		char_clock-=0.042;body.visible_characters+=1
		if body.text.substr(body.visible_characters-1,1) in ["。","，","？","！",".",",","?","!"]:char_clock-=0.12;break
	if body.visible_characters>=body.text.length():finished_typing()
func finished_typing() -> void:
	var key: String=str(g.commission_index)
	var entries: Array=g.commission_history.get(key,[])
	var event_key: String=("answer_"+str(question_index) if question_return else "line_"+str(step))+"_"+g.L.language
	if not entries.any(func(entry):return entry.key==event_key):
		entries.append({"key":event_key,"speaker":speaker.text,"text":body.text});g.commission_history[key]=entries
	for child in choices.get_children():choices.remove_child(child);child.queue_free()
	reply.text=desk.t("继续") if question_return else str(lines[step].get("reply",desk.t("继续")))
	if not question_return and lines[step].get("questions",false):
		for i in 2:
			var index: int=i;conversation_button(desk.t(["对方喜欢哪种风格？","有什么特别的回忆？"][i]),Rect2(354+i*371,534,354,38),func():ask(index),false,choices)
func advance() -> void:
	if body.visible_characters<body.text.length():body.visible_characters=body.text.length();finished_typing();return
	if question_return:question_return=false;show_step();body.visible_characters=body.text.length();finished_typing();return
	if step<lines.size()-1:step+=1;show_step();g.audio.play("DIALOGUE_ADVANCE",0.45)
	else:
		g.accepted_commission=g.commission_index;g.shelf_open=false;g.tools_open=false;g.tool="move";g.drawer_group="客户";g.drawer_page=0;g.save_game();close()
func ask(index: int) -> void:
	question_index=index
	var data: Dictionary=g.commissions[g.commission_index%g.commissions.size()]
	var answers: Array=data.get("answers_"+g.L.language,[])
	body.text=str(answers[index]) if answers.size()>index else data["request_"+g.L.language]
	speaker.text=data["name_"+g.L.language];body.visible_characters=0;char_clock=0;question_return=true
	stationery.player_speaking=false;stationery.queue_redraw();reply.text=desk.t("显示整段")
	for child in choices.get_children():choices.remove_child(child);child.queue_free()
func conversation_button(text: String, rect: Rect2, action: Callable, primary: bool=false, parent: Control=self) -> Button:
	var control: Button=desk.button(text,rect,action,false,parent)
	control.add_theme_color_override("font_color",Color("f8f0de") if primary else Color("52665b"))
	control.add_theme_color_override("font_hover_color",Color("fff6e3") if primary else Color("384f46"))
	control.add_theme_color_override("font_pressed_color",Color("fff6e3") if primary else Color("384f46"))
	for state in ["normal","hover","pressed","focus"]:
		var skin:=StyleBoxFlat.new();skin.set_corner_radius_all(9);skin.set_content_margin_all(6)
		skin.bg_color=Color("52796e") if primary else Color("e9ddc5")
		if state=="hover":skin.bg_color=Color("63887a") if primary else Color("ded2b8")
		if state=="pressed":skin.bg_color=Color("456a5f") if primary else Color("d4c5a8")
		if state=="focus":skin.bg_color=Color.TRANSPARENT;skin.border_color=Color("c29d60");skin.set_border_width_all(2)
		control.add_theme_stylebox_override(state,skin)
	return control
func _unhandled_key_input(event: InputEvent) -> void:
	if reading_history:return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ENTER,KEY_KP_ENTER]:
		advance();get_viewport().set_input_as_handled()
func close() -> void:
	g.save_game();g.conversation_open=false;queue_free();g.build_ui()
func open_history() -> void:
	reading_history=true
	var visible_nodes: Array=[]
	for child in get_children():
		if child is CanvasItem and child.visible:visible_nodes.append(child);child.hide()
	var history=load("res://extensions/collage_letter/scripts/commission_history.gd").new();history.g=g;history.desk=desk
	history.on_close=func():
		remove_child(history);history.queue_free();reading_history=false
		for child in visible_nodes:
			if is_instance_valid(child):child.show()
	add_child(history)
func _draw() -> void:
	if attachments and attachments.visible:
		draw_line(Vector2(354,489),Vector2(1084,489),Color("d4c5a4"),1,true)
