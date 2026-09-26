extends "table.gd"

# The existing controller remains the authority for deals, claims, truth,
# completion and Solmere saves. Only its presentation is replaced here.
const Motion = preload("deck_motion.gd")
const RoomCard = preload("reader_card.gd")
var room: Control
var history_scroll: ScrollContainer
var presented_mode: String=""

func _ready() -> void:
	super._ready()
	for child in get_children():
		if child is TextureRect or child is ColorRect: child.hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _layout() -> void:
	if is_instance_valid(stage): stage.position = Vector2.ZERO; stage.scale = Vector2.ONE

func box(parent: Node, rect: Rect2, _opacity: float = 0.92) -> Panel:
	return room.paper(parent,rect)

func button(parent: Node,title: String,rect: Rect2,action: Callable,_accent: bool=false) -> Button:
	return room.paper_button(parent,title,rect,func():
		if not busy: action.call())

func label(parent: Node,text: String,rect: Rect2,font_size: int=20,_color: Color=CREAM,centered: bool=false) -> Label:
	var l: Label = room.stamp(parent,text,rect,font_size,room.INK)
	if centered: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func render() -> void:
	if not is_instance_valid(stage): return
	if is_instance_valid(content): stage.remove_child(content); content.queue_free()
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(content)
	if is_instance_valid(modal): stage.move_child(modal,-1)
	room.ribbons.active = false
	if mode!=presented_mode:
		presented_mode=mode
		room.dialogue.position=Vector2(1050,170)
		if mode=="choose":
			room.dialogue.say(["这 15 张牌都是你的线索。点击牌面选择 6–8 张最关键的牌，亮起表示已选。下面的‘解读’可以回看提问，不会改变选择。"])
			result_text="点击牌面选择主线 · 点击解读回看提问"
		elif mode=="sort":
			room.dialogue.say(["现在把主线接起来。可以拖动交换，也可以依次点两张。水面连上只是第一步，还要按事件的因果顺序排列，最后说出完整真相。"])
	var spec: Dictionary = Rules.CASES[case_id]
	var note := box(content,Rect2(45,143,420,292))
	label(note,spec.title,Rect2(20,16,380,40),26)
	scroll_text(note,spec.surface,Rect2(20,64,382,202),20)
	button(content,"换一则故事",Rect2(45,449,180,40),choose_case)
	button(content,"万景图提示",Rect2(243,449,190,40),show_myriorama_help)
	if mode == "draw": render_draw(spec)
	elif mode == "choose": render_choose()
	else: render_sort()
	status_label = room.stamp(content,result_text,Rect2(185,857,1230,30),18,Color("efdfc0"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_session()

func render_draw(_spec: Dictionary) -> void:
	if round_index < 0:
		button(content,"开始第一轮 · 洗牌",Rect2(610,620,380,55),draw_round,true)
		room.stamp(content,"每轮 5 张 · 全部保留 · 最后选 6–8 张主线",Rect2(510,704,650,35),20,Color("efdfc0"))
		return
	if round_picks.size()<5:
		var count := VISUAL_DECK_SIZE-round_index*5
		for i in range(count):
			if used_fan_slots.has(i): continue
			var pose := arc_pose(i,count,Vector2(72,123),true)
			var c: TextureRect = room.make_card(content,"draw:"+str(i),common_back,Rect2(pose.position,Vector2(72,123)))
			c.rotation = pose.angle
			c.picked.connect(on_card)
		for i in range(round_picks.size()): card(content,round_picks[i],Rect2(535+i*112,486,77,132),true)
	else:
		for i in range(5):
			var pose := arc_pose(i,5,Vector2(128,219),false)
			var c := card(content,round_picks[i],Rect2(pose.position,Vector2(128,219)),true)
			c.rotation = pose.angle
		button(content,"下一轮 · 保留全部" if round_index<2 else "挑选主线牌",Rect2(1060,806,355,44),advance,true)
	button(content,"所有线索 · %d / 15" % owned.size(),Rect2(40,806,240,44),show_collection)
	room.stamp(content,"第 %d / 3 轮 · 已抽 %d / 5 · 全部正位" % [round_index+1,round_picks.size()],Rect2(1080,493,360,28),16,Color("efdfc0"))

func arc_pose(index: int,count: int,dimensions: Vector2,dense: bool) -> Dictionary:
	var theta := lerpf(-0.30 if dense else -0.115,0.30 if dense else 0.115,float(index)/maxi(1,count-1))
	var radius := 1550.0 if dense else 2420.0
	var midpoint := Vector2(800,690 if dense else 643)+Vector2(sin(theta)*radius,(1-cos(theta))*radius)
	return {"position":midpoint-dimensions/2,"angle":theta}

func draw_round() -> void:
	if busy or round_index>=2: return
	round_index += 1
	round_picks=[]; used_fan_slots=[]
	result_text="洗牌、切牌，然后从右向左慢慢展开。"
	render()
	busy=true
	var backs: Array=[]
	for c in content.get_children():
		if c.get_script()==RoomCard and str(c.card_id).begins_with("draw:"): backs.append(c); c.hide()
	var piles: Array=[]
	for i in range(3):
		var p: TextureRect = room.make_card(content,"packet",common_back,Rect2(740+i*3,560+i*3,100,171))
		p.mouse_filter=Control.MOUSE_FILTER_IGNORE
		piles.append(p)
	room.reader.set_state(room.Actor.State.WATCHING_CARD)
	await Motion.shuffle(self,piles,Vector2(740,560),sound)
	for p in piles: content.remove_child(p); p.queue_free()
	var poses: Array=[]
	for c in backs:
		poses.append({"position":c.position,"angle":c.rotation})
		c.show(); c.position=Vector2(1230,665); c.rotation=0; c.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var tween:=create_tween()
	sound.play_timed("deal",1.70)
	tween.tween_method(func(progress: float):
		for i in range(backs.size()):
			var stop:=0.18+(1.0-float(i)/maxi(1,backs.size()-1))*0.82
			var t:=clampf(progress/stop,0,1)
			t=t*t*(3-2*t)
			backs[i].position=Vector2(1230,665).lerp(poses[i].position,t)
			backs[i].rotation=lerpf(0,poses[i].angle,t)
	,0.0,1.0,1.70)
	await tween.finished
	busy=false
	result_text="停在一张牌上，等它亮起，再点击抽出。"
	render()

func pick_from_fan(slot: int) -> void:
	if busy or used_fan_slots.has(slot) or round_picks.size()>=5 or round_index<0: return
	busy=true
	var id: String=deal[round_index*5+round_picks.size()]
	var pose:=arc_pose(slot,VISUAL_DECK_SIZE-round_index*5,Vector2(72,123),true)
	var floating: TextureRect=room.make_card(content,"flying",common_back,Rect2(pose.position,Vector2(72,123)))
	floating.rotation=pose.angle; floating.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for c in content.get_children():
		if c.get_script()==RoomCard and c.card_id=="draw:"+str(slot): c.hide()
	sound.play("flip")
	var tween:=create_tween().set_parallel(true)
	tween.tween_property(floating,"position",Vector2(535+round_picks.size()*112,486),0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(floating,"rotation",0.0,0.42)
	await tween.finished
	sound.play("place")
	await Motion.flip(self,floating,textures[id+"front"],sound)
	used_fan_slots.append(slot); round_picks.append(id); owned.append(id); revealed.append(id)
	busy=false
	render()
	show_card(id)

func card(parent: Node,id: String,rect: Rect2,face: bool=true,sort_enabled: bool=false) -> TextureRect:
	var c: TextureRect=room.make_card(parent,id,textures[id+"front"] if face else common_back,rect)
	c.sortable=sort_enabled; c.movable=sort_enabled; c.update_surface()
	c.StoryTags=[id]
	c.picked.connect(on_card)
	if sort_enabled:
		c.drag_started.connect(func(_id): sound.play("flip"))
		c.drag_released.connect(func(dragged):
			var left: float=(1600-main_cards.size()*132.0)/2
			var target:=clampi(int((c.position.x+c.size.x/2-left)/132.0),0,main_cards.size()-1)
			swap_cards(dragged,main_cards[target]))
	return c

func on_card(id: String) -> void:
	if busy: return
	if id.begins_with("draw:"): await pick_from_fan(int(id.trim_prefix("draw:"))); return
	if mode=="choose": toggle_main(id)
	elif mode=="sort" and main_cards.has(id):
		if selected_swap.is_empty(): selected_swap=id; render()
		else: swap_cards(selected_swap,id)
	else: show_card(id)

func render_choose() -> void:
	for i in range(owned.size()):
		var id: String=owned[i]
		var x:=350.0+(i%8)*113
		var y:=500.0+floori(float(i)/8)*158
		var c:=card(content,id,Rect2(x,y,75,129))
		c.set_selected(main_cards.has(id))
		var b:=button(content,"已选 · 解读" if main_cards.has(id) else "解读",Rect2(x,y+132,94,24),func(): show_card(id))
		b.add_theme_font_size_override("font_size",14)
	var go:=button(content,"排列主线 · %d / 8" % main_cards.size(),Rect2(1070,819,355,34),func(): mode="sort"; render(),true)
	go.disabled=main_cards.size()<6 or main_cards.size()>8
	button(content,"回到观牌",Rect2(180,817,240,36),func(): mode="draw"; render())

func render_sort() -> void:
	var left: float=(1600-main_cards.size()*132.0)/2
	var joined: Array=[]
	for i in range(main_cards.size()):
		var c:=card(content,main_cards[i],Rect2(left+i*132,516,132,226),true,true)
		c.set_selected(c.card_id==selected_swap)
		joined.append(c)
	room.ribbons.cards=joined; room.ribbons.active=true
	room.stamp(content,"拖动交换顺序，或依次点两张 · 接上景色 ≠ 推理成立",Rect2(410,757,900,29),18,Color("efdfc0"))
	button(content,"重新选主线",Rect2(185,806,250,44),func(): mode="choose"; selected_swap=""; render())
	button(content,"回看所有线索",Rect2(580,806,260,44),show_collection)
	button(content,"验证连接与完整真相",Rect2(1060,806,355,44),check_story,true)

func show_collection() -> void:
	var root:=open_modal()
	box(root,Rect2(275,436,1060,425))
	label(root,"所有线索都会留下 · 点击回看",Rect2(305,449,720,30),21)
	button(root,"收好线索",Rect2(1110,445,190,36),close_modal)
	for i in range(owned.size()):
		var c:=card(root,owned[i],Rect2(312+(i%8)*124,499+floori(float(i)/8)*170,83,142))
		c.picked.disconnect(on_card); c.picked.connect(show_card)

func open_modal() -> Control:
	close_modal()
	if is_instance_valid(content): content.hide()
	room.ribbons.active=false
	room.dialogue.hide()
	modal=Control.new(); modal.size=Vector2(1600,900)
	stage.add_child(modal)
	return modal

func close_modal() -> void:
	super.close_modal()
	if is_instance_valid(content): content.show()
	room.ribbons.active=mode=="sort"
	if is_instance_valid(room.dialogue):
		room.dialogue.position=Vector2(1050,170)
		room.dialogue.show()

func show_card(id: String,flip: bool=false) -> void:
	var root:=open_modal()
	modal_id=id; guide_side=flip
	var inspect_rect:=Rect2(65,146,410,703) if flip else Rect2(300,492,175,300)
	var pic: TextureRect=room.make_card(root,"inspect",textures[id+("back" if flip else "front")],inspect_rect)
	pic.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button(root,"看正面" if flip else "看引导面",Rect2(110,850,300,36) if flip else Rect2(280,805,220,39),func(): show_card(id,not flip))
	room.dialogue.position=Vector2(35,154)
	room.dialogue.say([Guidance.introduction(id,deck[id].cn),"本故事的观察方向："+str(Questions.Bank.guide(case_id,id).get(case_id,""))])
	if flip: room.dialogue.hide()
	room.reader.set_state(room.Actor.State.SPEAKING)
	box(root,Rect2(1050,123,510,719))
	label(root,deck[id].cn+" · 正位",Rect2(1072,142,380,39),28)
	button(root,"收起",Rect2(1450,139,90,37),close_modal)
	label(root,"这张牌可谈："+str(Guidance.GUIDES[id][0]),Rect2(1072,191,458,53),18)
	question_input=LineEdit.new(); question_input.position=Vector2(1072,253); question_input.size=Vector2(458,52)
	question_input.placeholder_text="写下你的问题……"; question_input.max_length=120
	question_input.add_theme_font_size_override("font_size",21)
	var input_face:=StyleBoxFlat.new(); input_face.bg_color=Color("fff4dc"); input_face.set_content_margin_all(10)
	question_input.add_theme_stylebox_override("normal",input_face)
	question_input.add_theme_color_override("font_color",room.INK)
	question_input.add_theme_color_override("caret_color",room.INK)
	root.add_child(question_input); question_input.text=question_drafts.get(id,"")
	pending_question={}; question_suggestions=[]
	button(root,"理解我的问题",Rect2(1072,318,218,43),review_question,true)
	question_confirm=button(root,"确认含义 · 回答",Rect2(1302,318,228,43),confirm_question)
	question_confirm.disabled=true
	question_feedback=ScrollContainer.new(); question_feedback.position=Vector2(1072,376); question_feedback.size=Vector2(458,118)
	question_feedback.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; root.add_child(question_feedback)
	question_reply=Label.new(); question_reply.custom_minimum_size.x=435
	question_reply.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	question_reply.add_theme_font_size_override("font_size",19); question_reply.add_theme_color_override("font_color",room.INK)
	question_reply.text="想了解画面也可以直接问，不扣次数。案件求证会先确认理解，再判断 YES / NO。"
	question_feedback.add_child(question_reply)
	question_input.text_submitted.connect(func(_value): review_question())
	question_input.text_changed.connect(func(value): question_drafts[id]=value; pending_question={}; question_confirm.disabled=true; clear_question_suggestions())
	label(root,"对话笔记 · 求证 %d / 2" % question_records.get(id,[]).size(),Rect2(1072,526,290,33),19)
	button(root,"提问帮助",Rect2(1380,521,150,36),func(): show_question_help(id))
	history_scroll=ScrollContainer.new(); history_scroll.position=Vector2(1072,574); history_scroll.size=Vector2(458,184)
	history_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; root.add_child(history_scroll)
	update_history()
	button(root,"回到桌面 · 保留此牌",Rect2(1072,778,458,43),close_modal,true)
	save_session()

func review_question() -> void:
	super.review_question()
	if not question_suggestions.is_empty(): question_feedback.size.y=64
	for i in range(question_suggestions.size()):
		question_suggestions[i].position=Vector2(1072,446+i*40)
		question_suggestions[i].size=Vector2(458,36)
		question_suggestions[i].clip_text=true

func clear_question_suggestions() -> void:
	super.clear_question_suggestions()
	if is_instance_valid(question_feedback): question_feedback.size=Vector2(458,118)

func remember_exchange(player: String,host: String) -> void:
	var lines: Array=conversations.get(modal_id,[])
	lines.append("你："+player+"\n塔罗师："+host); conversations[modal_id]=lines
	update_history(); save_session()

func update_history() -> void:
	if not is_instance_valid(history_scroll): return
	for c in history_scroll.get_children(): history_scroll.remove_child(c); c.queue_free()
	var text: String="\n\n".join(conversations.get(modal_id,[]))
	var l:=label(history_scroll,text if not text.is_empty() else "还没有提问。先观察牌面，再提出你的假设。",Rect2(0,0,434,160),18)
	l.custom_minimum_size.x=434; l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	history_scroll.set_deferred("scroll_vertical",100000)

func show_guide_image(id: String) -> void: show_card(id,true)

func show_question_help(id: String) -> void:
	show_card(id)
	question_reply.text="先说清对象，再问一件事。例如：某人是否进入过房间？如果‘相等’，请说明比较哪两组。无法理解不会判 NO，也不扣次数。"

func show_truth_dialogue() -> void:
	var root:=open_modal()
	box(root,Rect2(35,144,465,688)); box(root,Rect2(1050,144,515,688))
	label(root,"现在，请说出完整真相",Rect2(58,162,415,40),25)
	label(root,"写清原因、经过、结果。支持分行；不自动替你补全。",Rect2(58,213,415,62),19)
	truth_input=TextEdit.new(); truth_input.position=Vector2(58,291); truth_input.size=Vector2(416,444)
	truth_input.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY; truth_input.add_theme_font_size_override("font_size",20)
	root.add_child(truth_input); truth_input.text=truth_draft
	var scroll:=ScrollContainer.new(); scroll.position=Vector2(1074,214); scroll.size=Vector2(464,503)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; root.add_child(scroll)
	truth_reply=label(scroll,"我会先复述，再核对。无法识别的句子会列出来，不会当成正确，也不会忽略。",Rect2(0,0,440,460),21)
	truth_reply.custom_minimum_size.x=440; truth_reply.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	truth_review={}
	truth_input.text_changed.connect(func(): truth_draft=truth_input.text; truth_review={}; truth_confirm.disabled=true; save_session())
	button(root,"请理解我的陈述",Rect2(58,759,416,46),review_truth,true)
	truth_confirm=button(root,"复述正确 · 核对真相",Rect2(1074,759,464,46),confirm_truth); truth_confirm.disabled=true
	button(root,"继续调查",Rect2(1330,161,207,40),close_modal)

func show_myriorama_help(page: int=0) -> void:
	tutorial_seen["intro"]=true; tutorial_seen["sort"]=true; tutorial_seen["choose"]=true
	room.dialogue.position=Vector2(1050,170)
	var lines: Array=["万景图：把几张小景接成一幅长景。\n左右边的水和远景能相接。试着交换顺序，看故事如何改变。","但景色能接上，不等于推理成立。\n全部 15 张牌都会保留。选出和案件最相关的 6–8 张，按原因、经过、结果排序。","最后还要讲清完整真相。\n可以自由提问；主持人先复述你的意思，再回答。没听懂会澄清，不会直接判 NO。"]
	room.dialogue.say(lines.slice(clampi(page,0,2)))
	save_session()

func show_rules() -> void: show_myriorama_help()

func show_truth() -> void:
	solmere_completed=true
	save_session()
	sound.play("complete")
	var root:=open_modal()
	box(root,Rect2(1040,145,525,670))
	label(root,"世界 · 故事闭合",Rect2(1064,171,475,48),29)
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(1064,238); scroll.size=Vector2(475,465)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var summary:=label(scroll,Rules.CASES[case_id].truth,Rect2(0,0,448,430),22)
	summary.custom_minimum_size.x=448; summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(root,"回到万景桌",Rect2(1085,742,430,48),close_modal,true)
	room.dialogue.position=Vector2(35,154)
	room.dialogue.say(["景色与真相终于接上了。你不仅排好了牌，也说清了这个故事。所有提问和牌都会留在桌上，可以再回看。"])
	feedback("主线成立 · 故事闭合",GOLD)

func choose_case() -> void:
	var root:=open_modal()
	box(root,Rect2(1030,170,525,375))
	label(root,"选择一则海龟汤",Rect2(1055,192,470,42),26)
	label(root,"开始新故事会重置当前案件的抽牌与排序。",Rect2(1055,247,470,60),20)
	button(root,"门外的目击者",Rect2(1055,319,470,49),func(): new_case("murder"))
	button(root,"五十人与四扇门",Rect2(1055,385,470,49),func(): new_case("doors"))
	button(root,"继续当前故事",Rect2(1110,474,360,44),close_modal)

func feedback(message: String,_color: Color) -> void:
	result_text=message
	if is_instance_valid(status_label): status_label.text=message

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and is_instance_valid(modal):
		close_modal()
		get_viewport().set_input_as_handled()
