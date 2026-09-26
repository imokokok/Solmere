extends Control

const Card = preload("res://extensions/myriorama_tarot/scripts/reader_card.gd")
const Motion = preload("res://extensions/myriorama_tarot/scripts/deck_motion.gd")
const Sound = preload("res://extensions/myriorama_tarot/scripts/sound.gd")
const Actor = preload("res://extensions/myriorama_tarot/scripts/reader_actor.gd")
const CasePresenter = preload("res://extensions/myriorama_tarot/scripts/case_presenter.gd")
const Dialogue = preload("res://extensions/myriorama_tarot/scripts/paper_dialogue.gd")
const Ribbon = preload("res://extensions/myriorama_tarot/scripts/connection_ribbon.gd")
const Composer = preload("res://extensions/myriorama_tarot/scripts/story_composer.gd")
const Guidance = preload("res://extensions/myriorama_tarot/scripts/card_guidance.gd")
const Questions = preload("res://extensions/myriorama_tarot/scripts/question_engine.gd")
const SAVE := "user://tarot-reader-session-v1.json"
const PAPER := Color("eee2c8")
const INK := Color("35364e")
const GOLD := Color("bb9a63")

signal exit_requested
var stage: Control
var table: Node2D
var slots: Control
var deck_layer: Control
var ui: Control
var dialogue_layer: Control
var reader: Node2D
var dialogue: PanelContainer
var ribbons: Node2D
var ambient: CanvasModulate
var sound: Node
var deck: Dictionary = {}
var textures: Dictionary = {}
var back: Texture2D
var cards: Array = []
var picked_ids: Array = []
var revealed: Array = []
var draw_ids: Array = []
var used_slots: Array = []
var collection: Array = []
var mode := "welcome"
var phase := "welcome"
var question := ""
var busy := false
var rng := RandomNumberGenerator.new()
var question_edit: LineEdit
var status: Label
var listen_button: Button
var back_button: Button
var tick := 0.0
var history: Array = []
var session: Dictionary = {}
var test_mode := false
var card_size := Vector2(154,264)
var case_panel: Control
var case_game: Control
var finish_requested := false
var solmere_completed: bool:
	get:
		return is_instance_valid(case_game) and case_game.solmere_completed
	set(value):
		ensure_case()
		case_game.solmere_completed = value
var truth_draft: String:
	get: return case_game.truth_draft if is_instance_valid(case_game) else ""
	set(value):
		ensure_case()
		case_game.truth_draft = value


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--smoke-test"):
		add_child(load("res://extensions/myriorama_tarot/scenes/case_table.tscn").instantiate())
		return
	test_mode = OS.get_cmdline_user_args().has("--reader-test")
	rng.randomize()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei","PingFang SC","Noto Sans CJK SC","Noto Sans SC","sans-serif"])
	var styling := Theme.new()
	styling.default_font = font
	styling.default_font_size = 21
	theme = styling
	for item in JSON.parse_string(FileAccess.get_file_as_string("res://extensions/myriorama_tarot/assets/deck.json")):
		deck[item.id] = item
		textures[item.id] = load("res://extensions/myriorama_tarot/assets/" + item.front)
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://extensions/myriorama_tarot/assets/common-back-reference.jpg")
	atlas.region = Rect2(94,112,768,1404)
	back = atlas
	sound = Node.new()
	sound.set_script(Sound)
	add_child(sound)
	build_space()
	load_session()
	resized.connect(layout)
	layout()
	show_welcome()
	if test_mode: call_deferred("self_test")

func build_space() -> void:
	stage = $Space
	stage.clip_contents = true
	var background := $Space/Background
	asset(background,"Window","room-backdrop-v2.png",Rect2(0,0,1600,570))
	asset(background,"Curtain","curtains-v2.png",Rect2(0,0,1600,570))
	var lights := $Space/EnvironmentalLighting
	ambient = CanvasModulate.new()
	ambient.name = "AmbientColor"
	ambient.color = Color(0.88,0.9,0.98)
	lights.add_child(ambient)
	point_light(lights,"WindowLight",Vector2(800,225),Color("becbf5"),0.24,4.0)
	point_light(lights,"LeftCandleLight",Vector2(175,558),Color("ffd49a"),0.45,2.6)
	point_light(lights,"RightCandleLight",Vector2(1413,533),Color("ffd49a"),0.45,2.6)
	reader = $Space/TarotReader
	reader.set_script(Actor)
	reader._ready()
	reader.set_process(true)
	table = $Space/Table
	# Horizontal table edge. Source alpha is retained; no trapezoid projection.
	asset(table,"TableCloth","tabletop-v2.png",Rect2(0,350,1600,620))
	asset(table,"CandleLeft","candle-v2.png",Rect2(25,493,150,190))
	asset(table,"CandleRight","candle-v2.png",Rect2(1425,493,150,190))
	deck_layer = Control.new()
	deck_layer.name = "Deck"
	deck_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table.add_child(deck_layer)
	slots = Control.new()
	slots.name = "CardSlots"
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table.add_child(slots)
	ribbons = $Space/TarotVFX
	ribbons.set_script(Ribbon)
	ribbons._ready()
	ribbons.set_process(true)
	dialogue_layer = $Space/DialogueSystem
	dialogue = PanelContainer.new()
	dialogue.set_script(Dialogue)
	dialogue_layer.add_child(dialogue)
	dialogue.line_changed.connect(func(_index): reader.set_state(Actor.State.SPEAKING))
	dialogue.finished.connect(on_dialogue_finished)
	ui = $Space/InteractionUI
	stamp(ui,"SOLMERE  /  塔罗小摊",Rect2(55,33,390,32),20,Color("d0b992"))
	back_button = paper_button(ui,"收好牌 · 返回",Rect2(1290,32,230,44),request_return)
	back_button.name = "ReturnNote"
	status = stamp(ui,"",Rect2(480,856,660,29),17,Color("dfcda8"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func layout() -> void:
	if not is_instance_valid(stage): return
	var factor := minf(size.x/1600.0,size.y/900.0)
	stage.scale = Vector2.ONE*factor
	stage.position = (size-Vector2(1600,900)*factor)*0.5

func asset(parent: Node,title: String,file: String,rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.name = title
	image.texture = load("res://extensions/myriorama_tarot/assets/reader-scene/"+file)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.position = rect.position
	image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func point_light(parent: Node,title: String,at: Vector2,color: Color,energy: float,scale_value: float) -> void:
	var light := PointLight2D.new()
	light.name = title
	light.texture = Ribbon.light_texture()
	light.position = at
	light.color = color
	light.energy = energy
	light.texture_scale = scale_value
	parent.add_child(light)

func stamp(parent: Node,text: String,rect: Rect2,font_size: int = 21,color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func paper(parent: Node,rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.corner_radius_top_left = 3
	style.corner_radius_bottom_right = 5
	style.shadow_color = Color(0.05,0.06,0.1,0.28)
	style.shadow_size = 5
	style.shadow_offset = Vector2(3,4)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	return panel

func paper_button(parent: Node,text: String,rect: Rect2,action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	var normal := StyleBoxFlat.new()
	normal.bg_color = PAPER
	normal.border_color = GOLD
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.shadow_color = Color(0.05,0.06,0.1,0.35)
	normal.shadow_size = 5
	normal.shadow_offset = Vector2(2,4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("f6e8c7")
	hover.shadow_offset = Vector2(3,7)
	button.add_theme_stylebox_override("normal",normal)
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",normal)
	button.add_theme_stylebox_override("focus",normal)
	var disabled:=normal.duplicate() as StyleBoxFlat
	disabled.bg_color=Color("afa996")
	button.add_theme_stylebox_override("disabled",disabled)
	button.add_theme_color_override("font_disabled_color",Color("59594f"))
	button.add_theme_font_size_override("font_size",14 if rect.size.y<36 else 20)
	for key in ["font_color","font_hover_color","font_pressed_color"]: button.add_theme_color_override(key,INK)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func(): sound.play("tap"); action.call())
	button.mouse_entered.connect(func():
		if button.disabled: return
		if button.has_meta("lift"): button.get_meta("lift").kill()
		var lift := create_tween()
		button.set_meta("lift",lift)
		lift.tween_property(button,"position:y",rect.position.y-3,0.12))
	button.mouse_exited.connect(func():
		if button.has_meta("lift"): button.get_meta("lift").kill()
		var lift := create_tween()
		button.set_meta("lift",lift)
		lift.tween_property(button,"position:y",rect.position.y,0.14))
	parent.add_child(button)
	button.size=rect.size
	return button

func clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func clear_controls() -> void:
	for child in ui.get_children():
		if child.has_meta("session_ui"):
			ui.remove_child(child)
			child.queue_free()
	listen_button = null

func session_node(node: Node) -> Node:
	node.set_meta("session_ui",true)
	return node

func deck_stack() -> void:
	clear_children(deck_layer)
	for i in range(7):
		var c := make_card(deck_layer,"stack",back,Rect2(1345+i,620-i*1.4,83,142))
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.rotation = 0.055

func make_card(parent: Node,id: String,texture: Texture2D,rect: Rect2) -> TextureRect:
	var c := TextureRect.new()
	c.set_script(Card)
	c.card_id = id
	c.texture = texture
	c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c.position = rect.position
	c.size = rect.size
	c.pivot_offset = rect.size/2
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(c)
	return c

func show_welcome() -> void:
	if is_instance_valid(case_game): case_game.hide(); case_game.close_modal()
	dialogue.position = Vector2(70,190)
	clear_controls()
	clear_children(slots)
	cards.clear()
	ribbons.cards = []
	ribbons.active = false
	ribbons.bright = false
	ambience(false)
	mode = "welcome"
	phase = "welcome"
	reader.set_state(Actor.State.IDLE)
	status.text = "一张桌子，两种相遇。"
	var selection := Control.new()
	selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(selection)
	session_node(selection)
	var a := make_card(selection,"choice_reading",back,Rect2(505,520,137,235))
	a.rotation = -0.045
	a.picked.connect(func(_id): start_mode("reading"))
	var b := make_card(selection,"choice_story",textures["08"],Rect2(953,520,137,235))
	b.rotation = 0.035
	b.picked.connect(func(_id): start_mode("story"))
	paper_button(selection,"问一个问题",Rect2(423,754,310,52),func(): start_mode("reading"))
	paper_button(selection,"听一个故事",Rect2(870,754,310,52),func(): start_mode("story"))
	stamp(selection,"三张牌，梳理此刻的你。",Rect2(421,818,360,30),19,Color("dac8a6"))
	stamp(selection,"保留线索，拼出完整真相。",Rect2(868,818,360,30),19,Color("dac8a6"))
	if not session.is_empty():
		paper_button(selection,"继续上次的牌",Rect2(1210,782,275,46),resume_session)
	paper_button(selection,"万景图怎么玩？",Rect2(72,787,270,44),func():
		dialogue.say(["万景图就是把几张小景，接成一幅长景。\n\n听故事模式沿用原来的两则案件：每局保留 15 张线索，最后选 6–8 张主线。","画面接起来只是第一步。\n你还要向主持人提问，再把原因、经过和结果讲清楚。"]))
	dialogue.visible = false
	await get_tree().create_timer(0.45 if not test_mode else 0.01).timeout
	if mode == "welcome":
		dialogue.say(["今天想做什么？\n\n问一个问题，或一起解开一则故事。"])

func start_mode(next_mode: String) -> void:
	if busy: return
	if next_mode == "story" and not test_mode:
		start_case()
		return
	clear_controls()
	clear_children(slots)
	cards.clear()
	picked_ids.clear()
	revealed.clear()
	used_slots.clear()
	ribbons.cards = []
	ribbons.active = false
	ribbons.bright = false
	question = ""
	mode = next_mode
	phase = "question" if mode == "reading" else "ready"
	reader.set_state(Actor.State.WAITING)
	if mode == "reading":
		dialogue.say(["你想知道什么？\n\n可以写下一个具体的困惑。牌会提供观察方向，但不会替你决定未来。"])
		var note := paper(ui,Rect2(470,540,665,204))
		session_node(note)
		stamp(note,"写给自己的问题",Rect2(24,17,610,34),23)
		question_edit = LineEdit.new()
		question_edit.position = Vector2(24,64)
		question_edit.size = Vector2(613,51)
		question_edit.max_length = 160
		question_edit.placeholder_text = "例如：面对一次改变，我最在意的是什么？"
		question_edit.add_theme_font_size_override("font_size",20)
		note.add_child(question_edit)
		paper_button(note,"把问题放在桌上",Rect2(322,138,313,46),submit_question)
		question_edit.text_submitted.connect(func(_text): submit_question())
		status.text = "不用问得完美。先说出你此刻在意的事。"
	else:
		dialogue.say(["那我们看看这些牌今天想讲什么。\n\n抽四张，逐张翻开，再把它们拖到你喜欢的顺序。画面连接时，光也会跟着连接。"])
		session_node(paper_button(ui,"轻轻洗牌",Rect2(612,639,380,58),begin_draw))
		status.text = "故事模式不需要输入问题；顺序会改变故事。"

func submit_question() -> void:
	if phase != "question" or busy: return
	question = question_edit.text.strip_edges()
	if question.is_empty():
		status.text = "先写下一句话，再把纸条交给她。"
		return
	clear_controls()
	question_note()
	phase = "ready"
	reader.set_state(Actor.State.REACTING)
	dialogue.say(["我看到了。先不急着寻找唯一答案。\n\n三张牌会放在同一张桌上：你带来的、你正在面对的、你可以尝试的。"])
	session_node(paper_button(ui,"准备好了 · 洗牌",Rect2(607,640,390,58),begin_draw))

func question_note() -> void:
	if mode != "reading": return
	var note := paper(ui,Rect2(72,700,275,128))
	note.rotation = -0.025
	session_node(note)
	stamp(note,"留在桌上的问题",Rect2(15,11,240,28),17,Color("826c50"))
	var body := RichTextLabel.new()
	body.position = Vector2(15,43)
	body.size = Vector2(246,69)
	body.text = question
	body.add_theme_font_size_override("normal_font_size",18)
	body.add_theme_color_override("default_color",INK)
	note.add_child(body)

func begin_draw() -> void:
	if busy or phase != "ready": return
	busy = true
	phase = "shuffle"
	clear_controls()
	question_note()
	reader.set_state(Actor.State.WATCHING_CARD)
	status.text = "洗牌 · 切牌 · 展牌"
	draw_ids = deck.keys()
	preload("res://extensions/myriorama_tarot/scripts/rules.gd").shuffle_with_rng(draw_ids,rng)
	var piles: Array = []
	for i in range(3):
		var pile := make_card(slots,"ritual",back,Rect2(738+i*3,584+i*3,110,188))
		pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piles.append(pile)
	await Motion.shuffle(self,piles,Vector2(738,584),sound)
	clear_children(slots)
	var backs: Array = []
	var poses: Array = []
	for i in range(78):
		var pose := Motion.fan_pose(i,78,Vector2(65,111))
		var c := make_card(slots,"draw:"+str(i),back,Rect2(1190,655,65,111))
		c.picked.connect(on_fan_pick)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backs.append(c)
		poses.append(pose)
	sound.play_timed("deal",1.70)
	var tween := create_tween()
	tween.tween_method(func(progress: float):
		for i in range(backs.size()):
			var stop := 0.18+(1.0-float(i)/77.0)*0.82
			var t := smoothstep(0.0,1.0,clampf(progress/stop,0,1))
			backs[i].position = Vector2(1190,655).lerp(poses[i].position,t)
			backs[i].rotation = lerpf(0,poses[i].angle,t)
	,0.0,1.0,1.70)
	await tween.finished
	for c in backs: c.mouse_filter = Control.MOUSE_FILTER_STOP
	phase = "drawing"
	busy = false
	status.text = "选一张有光的牌背 · 已抽 0 / %d" % target_count()
	dialogue.say(["不必急。让目光停在一张牌上，再轻轻抽出来。"])

func target_count() -> int:
	return 3 if mode == "reading" else 4

func slot_position(index: int, count: int) -> Vector2:
	# Re-map the existing centered reading layout, retaining a gentle arc.
	if mode == "reading":
		# Pure geometry, with no second scene/controller.
		var theta := lerpf(-0.105,0.105,float(index)/float(maxi(1,count-1)))
		return Vector2(800+sin(theta)*2140,495+(1-cos(theta))*2140)-Vector2(card_size.x/2,0)
	return Vector2(800-count*card_size.x/2+index*card_size.x,505)

func on_fan_pick(token: String) -> void:
	if busy or phase != "drawing": return
	var index := int(token.trim_prefix("draw:"))
	if used_slots.has(index): return
	busy = true
	used_slots.append(index)
	var source: Control
	for item in slots.get_children():
		if item.get_script() == Card and item.card_id == token: source = item; break
	if not is_instance_valid(source): busy = false; return
	source.mouse_filter = Control.MOUSE_FILTER_IGNORE
	source.hide()
	var id: String = draw_ids[picked_ids.size()]
	var target := slot_position(picked_ids.size(),target_count())
	var landing_size := Vector2(105,180)
	target.x += (card_size.x-landing_size.x)/2
	var c := make_card(slots,id,back,Rect2(source.position,Vector2(65,111)))
	c.rotation = source.rotation
	c.StoryTags = Composer.tags(id)
	c.picked.connect(on_card_picked)
	c.drag_started.connect(on_drag_started)
	c.drag_released.connect(on_drag_released)
	c.locked = true
	reader.set_state(Actor.State.WATCHING_CARD,target.x+card_size.x/2)
	sound.play("flip")
	var tween := create_tween().set_parallel(true)
	tween.tween_property(c,"position",target,0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(c,"size",landing_size,0.32)
	tween.tween_property(c,"rotation",0.0,0.32)
	await tween.finished
	c.pivot_offset = landing_size/2
	sound.play("place")
	picked_ids.append(id)
	cards.append(c)
	if not collection.has(id): collection.append(id)
	busy = false
	if picked_ids.size() == target_count():
		for item in slots.get_children():
			if item.get_script() == Card and str(item.card_id).begins_with("draw:"):
				slots.remove_child(item)
				item.queue_free()
		phase = "flipping"
		for i in range(cards.size()):
			var item=cards[i]
			item.position=slot_position(i,target_count())
			item.size=card_size
			item.pivot_offset=card_size/2
			item.locked = false
		status.text = "点击牌，逐张翻开 · 目前全部正位"
		dialogue.say(["牌已经落定了。你可以从任何一张开始翻开，我会陪你一起看。"])
	else:
		status.text = "再选一张 · 已抽 %d / %d" % [picked_ids.size(),target_count()]
	save_session()

func on_card_picked(id: String) -> void:
	if busy or phase in ["narrating","drawing"]: return
	var c: TextureRect = find_card(id)
	if not is_instance_valid(c): return
	if not revealed.has(id):
		busy = true
		reader.set_state(Actor.State.WATCHING_CARD,c.position.x+c.size.x/2)
		await Motion.flip(self,c,textures[id],sound)
		revealed.append(id)
		reader.set_state(Actor.State.THINKING,c.position.x+c.size.x/2)
		await get_tree().create_timer(0.35 if not test_mode else 0.01).timeout
		busy = false
		if mode == "reading": read_card(id)
		elif revealed.size() == 4:
			phase = "arranging"
			for item in cards: item.movable = true
			ribbons.cards = cards
			ribbons.active = true
			dialogue.say(["现在，试着拖动其中一张。\n\n让牌边的水面和远景靠近：位置吸附后，相邻牌之间的光会连起来。顺序改变，故事也会改变。"])
			story_actions()
		else:
			dialogue.say(["这是正位的「%s」。\n%s\n\n继续翻开其余的牌吧。" % [deck[id].cn,Composer.MOMENTS[id][3]]])
		save_session()
	else:
		if mode == "reading": read_card(id)
		else: dialogue.say([Guidance.introduction(id,deck[id].cn)])

func read_card(id: String) -> void:
	var index := picked_ids.find(id)
	var roles := ["你带来的","你正在面对的","你可以尝试的"]
	var intro: String = Guidance.introduction(id,deck[id].cn)
	var followup := "在‘%s’这个位置，可以把问题带回自己：%s？\n\n这是一种观察方向，不是对未来的确定预告。" % [roles[index],Composer.MOMENTS[id][3]]
	dialogue.say([intro,followup])
	status.text = "「%s」· 正位 · %s" % [deck[id].cn,roles[index]]
	if revealed.size() == 3:
		phase = "reading_done"
		clear_controls()
		question_note()
		session_node(paper_button(ui,"把三张牌一起读",Rect2(594,806,415,45),reading_summary))

func reading_summary() -> void:
	var first: String = Composer.MOMENTS[picked_ids[0]][3]
	var second: String = Composer.MOMENTS[picked_ids[1]][3]
	var last: String = Composer.MOMENTS[picked_ids[2]][3]
	dialogue.say(["你带来的问题仍放在桌上。\n我们先问：%s？\n再问：%s？" % [first,second],"最后，不急着替未来下结论。\n你可以带走一个小行动：%s？\n\n同样的牌，也允许你有自己的理解。" % last])
	reader.set_state(Actor.State.SPEAKING)

func find_card(id: String) -> TextureRect:
	for c in cards:
		if c.card_id == id: return c
	return null

func on_drag_started(id: String) -> void:
	if phase != "arranging": return
	reader.set_state(Actor.State.WATCHING_CARD,find_card(id).position.x)
	sound.play("flip")
	status.text = "拖动的是真实卡片 · 松开后吸附到牌位，其他牌让出位置"

func on_drag_released(id: String) -> void:
	if phase != "arranging" or busy: return
	var c := find_card(id)
	var center := c.position.x+c.size.x/2
	var left := 800.0-card_size.x*2
	var destination := clampi(int(floor((center-left)/card_size.x)),0,3)
	await reorder(id,destination)

func reorder(id: String, destination: int) -> void:
	if phase != "arranging" or busy: return
	busy = true
	picked_ids.erase(id)
	picked_ids.insert(clampi(destination,0,3),id)
	var tween := create_tween().set_parallel(true)
	for i in range(4):
		var c := find_card(picked_ids[i])
		c.locked = true
		tween.tween_property(c,"position",slot_position(i,4),0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	for c in cards: c.locked = false
	sound.play("place")
	busy = false
	reader.set_state(Actor.State.THINKING)
	status.text = "边缘已吸附 · 当前顺序：" + names_in_order()
	save_session()

func names_in_order() -> String:
	var names: Array[String] = []
	for id in picked_ids: names.append(deck[id].cn)
	return " → ".join(names)

func story_actions() -> void:
	clear_controls()
	listen_button = paper_button(ui,"听听这个故事",Rect2(601,806,398,45),listen_story)
	session_node(listen_button)
	status.text = "四张牌可拖动重排 · 景色接上不代表只有一种故事"

func listen_story() -> void:
	if busy or phase != "arranging" or revealed.size() != 4: return
	phase = "narrating"
	for c in cards: c.locked = true
	ribbons.bright = true
	ambience(true)
	clear_controls()
	dialogue.say(Composer.compose(picked_ids))
	status.text = "牌已暂时锁定 · " + names_in_order()
	reader.set_state(Actor.State.SPEAKING)
	session_node(paper_button(ui,"结束讲述 · 重新排列",Rect2(594,810,415,44),unlock_story))
	var entry := {"mode":"story","order":picked_ids.duplicate(),"story":Composer.compose(picked_ids)}
	if history.is_empty() or history.back().get("order",[]) != picked_ids: history.append(entry)
	save_session()

func unlock_story() -> void:
	phase = "arranging"
	for c in cards: c.locked = false; c.movable = true
	ribbons.bright = false
	ambience(false)
	story_actions()
	reader.set_state(Actor.State.WAITING)
	dialogue.say(["换一种排列也没关系。\n\n不是把刚才的故事改错，而是试试看，另一个开头会把我们带去哪里。"])
	save_session()

func ambience(narrating: bool) -> void:
	var tween := create_tween()
	tween.tween_property(ambient,"color",Color(0.74,0.77,0.87) if narrating else Color(0.88,0.90,0.98),0.45)

func on_dialogue_finished() -> void:
	reader.set_state(Actor.State.WAITING)
	if phase == "narrating": status.text = "故事讲完了 · 可以再换一个顺序听听"

func request_return() -> void:
	if busy or (is_instance_valid(case_game) and case_game.busy): return
	if mode == "welcome":
		if exit_requested.get_connections().is_empty():
			get_tree().quit()
			return
		exit_requested.emit()
		dialogue.say(["在这里坐一会儿也好。想继续时，桌上的两张纸条都还在。"])
		return
	save_session()
	show_welcome()

func save_session() -> void:
	if is_instance_valid(case_game): case_game.save_session()
	if mode == "case": return
	if test_mode or mode == "welcome": return
	session = {"mode":mode,"phase":phase,"question":question,"cards":picked_ids.duplicate(),"revealed":revealed.duplicate(),"collection":collection,"history":history.slice(-24)}
	GameState.shared_state["tarot_reader_"+GameState.current_role] = session.duplicate(true)
	SaveManager.save_or_report("塔罗记录保存失败")

func load_session() -> void:
	if test_mode: return
	ensure_case()
	var value: Variant = GameState.shared_state.get("tarot_reader_"+GameState.current_role,{})
	if not value is Dictionary or value.get("mode","") not in ["reading","story"]: return
	for id in value.get("cards",[]):
		if not deck.has(id): return
	session = value
	collection = value.get("collection",[])
	history = value.get("history",[])

func resume_session() -> void:
	if session.is_empty(): return
	var saved := session.duplicate(true)
	start_mode(saved.mode)
	question = saved.get("question","")
	if saved.get("cards",[]).is_empty():
		if mode == "reading": question_edit.text = question
		return
	clear_controls()
	question_note()
	picked_ids = saved.cards.duplicate()
	revealed = saved.revealed.duplicate()
	for i in range(picked_ids.size()):
		var id: String = picked_ids[i]
		var c := make_card(slots,id,textures[id] if revealed.has(id) else back,Rect2(slot_position(i,target_count()),card_size))
		c.StoryTags = Composer.tags(id)
		c.picked.connect(on_card_picked)
		c.drag_started.connect(on_drag_started)
		c.drag_released.connect(on_drag_released)
		cards.append(c)
	# An interrupted partial draw resumes the remaining deck, preserving identities.
	if picked_ids.size() < target_count():
		draw_ids = picked_ids.duplicate()
		for id in deck:
			if not draw_ids.has(id): draw_ids.append(id)
		phase = "drawing"
		for i in range(78-picked_ids.size()):
			var pose := Motion.fan_pose(i,78-picked_ids.size(),Vector2(65,111))
			var c := make_card(slots,"draw:"+str(i),back,Rect2(pose.position,Vector2(65,111)))
			c.rotation = pose.angle
			c.picked.connect(on_fan_pick)
		for c in cards:
			c.locked = true
			c.position.x += (card_size.x-105)/2
			c.size=Vector2(105,180)
			c.pivot_offset=c.size/2
	elif mode == "story" and revealed.size()==4:
		phase = "arranging"
		for c in cards: c.movable = true
		ribbons.cards = cards
		ribbons.active = true
		story_actions()
	else:
		phase = "flipping"
		if mode == "reading" and revealed.size()==3: read_card(picked_ids[0])
	dialogue.say(["刚才的牌都还在。我们接着看，不用重新开始。"])

func show_case_notes() -> void:
	if is_instance_valid(case_panel): case_panel.queue_free()
	case_panel = paper(ui,Rect2(1080,150,450,352))
	session_node(case_panel)
	stamp(case_panel,"原有海龟汤档案 · 不会删除",Rect2(20,17,410,35),21)
	var saved: Variant = {}
	if FileAccess.file_exists("user://table-session-v1.json"):
		saved = JSON.parse_string(FileAccess.get_file_as_string("user://table-session-v1.json"))
	var message := "旧版案件逻辑、问答库与存档保留。这里的三张占卜和四张叙事，是同一牌库的新体验；叙事不冒充案件标准答案。"
	if saved is Dictionary:
		message += "\n\n原档案：%d 张已抽牌，%d 张主线牌。" % [saved.get("owned",[]).size(),saved.get("main",[]).size()]
	stamp(case_panel,message,Rect2(20,63,406,205),20)
	paper_button(case_panel,"收起笔记",Rect2(118,290,215,42),func(): case_panel.queue_free())

func _process(delta: float) -> void:
	if not is_instance_valid(reader): return
	tick += delta
	back_button.disabled = busy or (is_instance_valid(case_game) and case_game.busy)
	back_button.text = "离开小摊" if mode=="welcome" else "收好牌 · 返回"
	if is_instance_valid(listen_button): listen_button.disabled = busy or phase != "arranging"

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event.keycode == KEY_ESCAPE: request_return()
		elif event.keycode == KEY_SPACE and is_instance_valid(dialogue) and not (is_instance_valid(question_edit) and question_edit.has_focus()): dialogue.next()

func self_test() -> void:
	assert(deck.size()==18 and reader.get_child_count()==1)
	assert(Composer.compose(["01","03","08","16"]) != Composer.compose(["16","08","03","01"]))
	var stable_space := stage.get_instance_id()
	start_mode("reading")
	question_edit.text = "如何看待一次改变？"
	submit_question()
	await begin_draw()
	for i in range(3): await on_fan_pick("draw:"+str(i))
	assert(cards.size()==3 and phase=="flipping")
	for id in picked_ids.duplicate(): await on_card_picked(id)
	assert(revealed.size()==3 and phase=="reading_done")
	reading_summary()
	assert(reader.visible and stage.get_instance_id()==stable_space)
	start_mode("story")
	assert(phase=="ready" and question.is_empty())
	await begin_draw()
	for i in range(4): await on_fan_pick("draw:"+str(i))
	for id in picked_ids.duplicate(): await on_card_picked(id)
	assert(phase=="arranging" and cards.size()==4 and ribbons.active)
	await get_tree().process_frame
	await get_tree().process_frame
	ribbons._process(0.016)
	assert(ribbons.links.size()==3)
	var old_order := picked_ids.duplicate()
	await reorder(picked_ids[3],0)
	assert(old_order != picked_ids)
	var c := find_card(picked_ids[0])
	assert(c.LeftConnection != null and c.RightConnection != null and not c.StoryTags.is_empty())
	var previous := c.position
	c.position.y += 150
	await get_tree().process_frame
	await get_tree().process_frame
	ribbons._process(0.016)
	assert(ribbons.links.size()<3)
	c.position = previous
	listen_story()
	assert(phase=="narrating" and c.locked and ribbons.bright)
	unlock_story()
	assert(phase=="arranging" and not c.locked)
	assert(stage.get_instance_id()==stable_space and reader.visible)
	print("PASS: shared reader space; original portrait; reading 3; story 4; reused shuffle/flip; continuous anchors; drag reorder; order-dependent local story; lock/unlock; legacy save untouched")
	get_tree().quit()


func ensure_case() -> void:
	if is_instance_valid(case_game): return
	case_game = Control.new()
	case_game.set_script(CasePresenter)
	case_game.room = self
	case_game.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(case_game)
	case_game.size = Vector2(1600,900)
	case_game.hide()

func start_case() -> void:
	clear_controls()
	clear_children(slots)
	ribbons.active = false
	mode = "case"
	phase = "case"
	ensure_case()
	case_game.show()
	case_game.render()
	dialogue.position = Vector2(1050,170)
	dialogue.say(["还是那两则故事，线索与规则没有改变。\n\n我们一张张抽、一张张问。所有牌都会留下，最后再挑出主线并讲清真相。"])
	status.text = ""
	stage.move_child(dialogue_layer,-1)
	stage.move_child(ui,-1)

func new_case(id: String) -> void:
	start_case()
	case_game.new_case(id)
