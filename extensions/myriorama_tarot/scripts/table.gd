extends Control

const Card = preload("res://extensions/myriorama_tarot/scripts/card.gd")
const Rules = preload("res://extensions/myriorama_tarot/scripts/rules.gd")
const Sound = preload("res://extensions/myriorama_tarot/scripts/sound.gd")
const Questions = preload("res://extensions/myriorama_tarot/scripts/question_engine.gd")
const Guidance = preload("res://extensions/myriorama_tarot/scripts/card_guidance.gd")
const Truth = preload("res://extensions/myriorama_tarot/scripts/truth_engine.gd")
const GOLD := Color("eed577")
const CREAM := Color("faf7ee")
const MUTED := Color("52675f")
const INK := Color("38423e")
const SAVE_PATH := "user://table-session-v1.json"
const VISUAL_DECK_SIZE := 78
const REVERSED_ENABLED := false
const ORIENTATION_NAMES := {"upright": "正位", "reversed": "逆位"}

var solmere_completed := false
var stage: Control
var content: Control
var modal: Control
var status_label: Label
var deck: Dictionary = {}
var textures: Dictionary = {}
var common_back: Texture2D
var case_id := "murder"
var deal: Array = []
var owned: Array = []
var revealed: Array = []
var main_cards: Array = []
var answers: Dictionary = {}
var round_index := -1
var mode := "draw"
var busy := false
var modal_id := ""
var guide_side := false
var selected_swap := ""
var result_text := ""
var rng := RandomNumberGenerator.new()
var sound: Node
var question_records: Dictionary = {}
var question_drafts: Dictionary = {}
var pending_question: Dictionary = {}
var question_input: LineEdit
var question_reply: Label
var question_feedback: ScrollContainer
var question_confirm: Button
var round_picks: Array = []
var used_fan_slots: Array = []
var card_orientations: Dictionary = {}
var question_suggestions: Array[Button] = []
var truth_draft := ""
var truth_review: Dictionary = {}
var truth_input: TextEdit
var truth_reply: Label
var truth_confirm: Button
var conversations: Dictionary = {}
var tutorial_seen: Dictionary = {}
var tutorial_step := 0
var tutorial_swapped := false

func _ready() -> void:
	rng.randomize()
	var font: Font
	if FileAccess.file_exists("res://extensions/myriorama_tarot/assets/chinese.ttc"):
		font = load("res://extensions/myriorama_tarot/assets/chinese.ttc")
	elif DisplayServer.get_name() == "headless":
		font = ThemeDB.fallback_font
	else:
		var system_font := SystemFont.new()
		system_font.font_names = PackedStringArray(["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "Noto Sans SC", "sans-serif"])
		font = system_font
	var theme_resource := Theme.new()
	theme_resource.default_font = font
	theme_resource.default_font_size = 20
	preload("res://scripts/ui/production_assets.gd").apply_theme(theme_resource)
	theme = theme_resource
	sound = Node.new()
	sound.set_script(Sound)
	add_child(sound)
	var parsed: Array = JSON.parse_string(FileAccess.get_file_as_string("res://extensions/myriorama_tarot/assets/deck.json"))
	for item in parsed:
		deck[item.id] = item
		card_orientations[item.id] = "upright"
		textures[item.id + "front"] = load("res://extensions/myriorama_tarot/assets/" + item.front)
		textures[item.id + "back"] = load("res://extensions/myriorama_tarot/assets/" + item.back)
	# Runtime atlas clipping keeps the JPEG's checkerboard margin off the table.
	# The reference is preserved unchanged; production needs a clean alpha PNG.
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://extensions/myriorama_tarot/assets/common-back-reference.jpg")
	atlas.region = Rect2(94, 112, 768, 1404)
	common_back = atlas
	var bg := TextureRect.new()
	bg.texture = load("res://extensions/myriorama_tarot/assets/tablecloth.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cloth_material := ShaderMaterial.new()
	cloth_material.shader = preload("res://extensions/myriorama_tarot/shaders/cloth_surface.gdshader")
	bg.material = cloth_material
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.resized.connect(func(): cloth_material.set_shader_parameter("surface_size", bg.size))
	var tint := ColorRect.new()
	tint.color = Color("e9e3d1",.95)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage = Control.new()
	stage.size = Vector2(1600, 900)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	resized.connect(_layout)
	_layout()
	load_session()
	if deal.is_empty():
		deal = Rules.make_deal(case_id, rng)
	render()
	if OS.get_cmdline_user_args().has("--open-question") and not revealed.is_empty():
		show_card(str(revealed[0]))
	if OS.get_cmdline_user_args().has("--smoke-test"):
		call_deferred("smoke_test")
	elif not tutorial_seen.get("intro", false):
		show_myriorama_help()

func _layout() -> void:
	if is_instance_valid(stage):
		var fit := minf(size.x / 1600.0, size.y / 900.0)
		stage.scale = Vector2.ONE * fit
		stage.position = (size - stage.size * fit) / 2.0

func box(parent: Node, rect: Rect2, _opacity: float = 0.92) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("faf5e8")
	style.border_color = Color("8a816b",.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 0
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	return p

func label(parent: Node, text: String, rect: Rect2, font_size: int = 20, color: Color = CREAM, centered: bool = false) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.clip_text = true
	l.text = LocalizationSystem.text(text)
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color("86622d") if color==GOLD else INK if color==CREAM or color.get_luminance()>.55 else color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func button(parent: Node, title: String, rect: Rect2, action: Callable, accent: bool = false) -> Button:
	var b := preload("res://scripts/ui/components/solmere_button.gd").new()
	b.variant="choice"; b.selected=accent
	b.text = LocalizationSystem.text(title)
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size",19)
	b.pressed.connect(func():
		if busy:
			return
		sound.play("tap")
		action.call()
	)
	parent.add_child(b)
	return b

func card(parent: Node, id: String, rect: Rect2, face: bool = true, sort_enabled: bool = false) -> TextureRect:
	var c := TextureRect.new()
	c.set_script(Card)
	c.card_id = id
	c.orientation = card_orientations.get(id, "upright")
	c.sortable = sort_enabled
	c.texture = textures[id + "front"] if face else common_back
	c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c.stretch_mode = TextureRect.STRETCH_SCALE
	c.position = rect.position
	c.size = rect.size
	c.pivot_offset = rect.size / 2.0
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.tooltip_text = LocalizationSystem.text(deck[id].cn + " · 正位（逆位暂未启用）" if face else "当前全部正位；抽一张、解读一张，卡牌会一直保留")
	c.picked.connect(on_card)
	c.swapped.connect(swap_cards)
	parent.add_child(c)
	c.set_selected(main_cards.has(id))
	return c

func render() -> void:
	if is_instance_valid(content):
		stage.remove_child(content)
		content.queue_free()
	content = Control.new()
	content.size = stage.size
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(content)
	if is_instance_valid(modal):
		stage.move_child(modal, -1)
	var spec: Dictionary = Rules.CASES[case_id]
	box(content, Rect2(40, 17, 1500, 99), 0.96)
	label(content, "M Y R I O R A M A   /   万 景", Rect2(60, 24, 600, 32), 22, GOLD)
	label(content, spec.title, Rect2(60, 61, 570, 57), 39)
	button(content, "音效：关" if sound.muted else "音效：开", Rect2(956, 43, 137, 42), func(): sound.muted = not sound.muted; render())
	button(content, "切换故事", Rect2(1110, 43, 125, 42), choose_case)
	button(content, "规则", Rect2(1250, 43, 80, 42), show_rules)
	button(content, "万景图是什么？", Rect2(650, 53, 245, 43), show_myriorama_help)
	button(content, "全屏  F11", Rect2(1345, 43, 160, 42), toggle_fullscreen)
	var phase := "观牌 · 所有牌都会留下"
	if mode == "choose":
		phase = "甄选 · 留下故事的骨架"
	elif mode == "sort":
		phase = "万景 · 让故事重新连接"
	box(content, Rect2(650, 120, 830, 42), 0.95)
	label(content, phase + " · 正位", Rect2(650, 120, 830, 42), 24, GOLD, true)
	if mode == "draw":
		render_draw(spec)
	elif mode == "choose":
		render_choose()
	else:
		render_sort()
	# Lowered behind controls: feedback text never competes with the cloth pattern.
	var footer := box(content, Rect2(40, 811, 1500, 78), 0.99)
	content.move_child(footer, 0)
	status_label = label(content, result_text, Rect2(70, 817, 1000, 45), 18, CREAM)
	label(content, "78 张牌库 / 18 种有效牌 / 全部正位，逆位暂未启用 / 每局抽 15 张、主线 6–8 张 / 自动保存", Rect2(70, 866, 1380, 20), 14, MUTED)
	save_session()

func render_draw(spec: Dictionary) -> void:
	var story_panel := box(content, Rect2(60, 168, 320, 445), 1.0)
	var paper := story_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	paper.bg_color = Color("efe4c9")
	paper.border_color = GOLD
	story_panel.add_theme_stylebox_override("panel", paper)
	label(content, spec.subtitle, Rect2(84, 185, 272, 35), 18, Color("735634"))
	var story_scroll := ScrollContainer.new()
	story_scroll.position = Vector2(84, 234)
	story_scroll.size = Vector2(272, 302)
	story_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(story_scroll)
	var body := label(story_scroll, spec.surface, Rect2(0, 0, 255, 302), 21, INK)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.clip_text = false
	label(content, "牌面提供视角，\n不直接证明真相。", Rect2(84, 551, 272, 45), 16, Color("5c625a"))
	if round_index < 0:
		box(content, Rect2(467, 259, 862, 265), 0.97)
		label(content, "每一次抽取，都留下线索。", Rect2(480, 295, 800, 55), 32, CREAM, true)
		label(content, "三轮观牌 → 保留全部 → 选出主线 → 拼接故事", Rect2(450, 359, 860, 50), 21, MUTED, true)
		button(content, "开始第一轮", Rect2(760, 440, 230, 57), draw_round, true)
	else:
		box(content, Rect2(423, 172, 923, 37), 0.96)
		if round_picks.size() < 5:
			label(content, "第 %d / 3 轮  ·  每次抽 1 张，先解牌再提问  ·  已抽 %d / 5" % [round_index + 1, round_picks.size()], Rect2(430, 173, 865, 35), 19, CREAM, true)
			var fan_count := VISUAL_DECK_SIZE - round_index * 5
			for i in range(fan_count):
				if used_fan_slots.has(i):
					continue
				var pose := arc_pose(i, fan_count, Vector2(92, 158), true)
				var back := TextureRect.new()
				back.set_script(Card)
				back.card_id = "draw:" + str(i)
				back.texture = common_back
				back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				back.position = pose.position
				back.size = Vector2(92, 158)
				back.pivot_offset = back.size / 2.0
				back.rotation = pose.angle
				back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				back.picked.connect(on_card)
				content.add_child(back)
			for i in range(5):
				if i < round_picks.size():
					card(content, str(round_picks[i]), Rect2(490 + i * 164, 439, 75, 128), revealed.has(round_picks[i]))
				else:
					box(content, Rect2(490 + i * 164, 439, 75, 128), 0.5)
		else:
			label(content, "第 %d / 3 轮  ·  本轮 5 张已保留，点击继续与塔罗师对话" % (round_index + 1), Rect2(430, 173, 865, 35), 19, CREAM, true)
			for i in range(5):
				var id: String = round_picks[i]
				var pose := arc_pose(i, 5, Vector2(156, 267), false)
				var c := card(content, id, Rect2(pose.position, Vector2(156, 267)), revealed.has(id))
				c.rotation = pose.angle
		box(content, Rect2(423, 587, 923, 36), 0.96)
		label(content, "翻开的牌和 NO 答复都会保留，之后仍可回看。", Rect2(430, 587, 910, 36), 18, CREAM, true)
	# Visible edge strata evoke the full 78-card deck without loading decorative faces.
	for n in range(12):
		var back := TextureRect.new()
		back.set_script(Card)
		back.texture = common_back
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.position = Vector2(1400 + n * 1.1, 315 - n * 1.6)
		back.size = Vector2(105, 180)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(back)
	box(content, Rect2(1362, 508, 174, 80), 0.98)
	label(content, "牌 库", Rect2(1380, 511, 145, 30), 19, GOLD, true)
	label(content, "%d / 78 张已抽" % owned.size(), Rect2(1362, 548, 174, 30), 17, CREAM, true)
	render_collection_strip()
	if round_index >= 0:
		var next_title := "下一轮 · 保留全部" if round_index < 2 else "挑选主线牌"
		var next := button(content, next_title, Rect2(1240, 816, 285, 51), advance, true)
		next.disabled = not current_revealed()
		if next.disabled:
			next.tooltip_text = LocalizationSystem.text("先翻开本轮全部 5 张牌")

func render_collection_strip() -> void:
	box(content, Rect2(40, 628, 1500, 180), 0.94)
	label(content, "我的线索  /  %02d" % owned.size(), Rect2(70, 634, 320, 28), 21, GOLD)
	label(content, "点击回看 · 每张都会保留", Rect2(1170, 634, 350, 28), 17, MUTED, true)
	for i in range(15):
		if i < owned.size():
			var id: String = owned[i]
			card(content, id, Rect2(70 + i * 97, 674, 74, 127), revealed.has(id))
		else:
			box(content, Rect2(70 + i * 97, 674, 74, 127), 0.27)

func draw_round() -> void:
	if busy or round_index >= 2:
		return
	round_index += 1
	round_picks = []
	used_fan_slots = []
	result_text = "洗牌、切牌、展牌……随后由你从牌列中抽取。"
	render()
	busy = true
	var ritual := box(content, Rect2(420, 228, 938, 349), 0.99)
	var ritual_caption := label(ritual, "洗牌 · 切牌", Rect2(20, 10, 898, 44), 24, GOLD, true)
	var piles: Array[TextureRect] = []
	for i in range(3):
		var p := TextureRect.new()
		p.set_script(Card)
		p.texture = common_back
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.size = Vector2(115, 197)
		p.position = Vector2(407 + i * 3, 85 + i * 3)
		p.pivot_offset = p.size / 2.0
		ritual.add_child(p)
		piles.append(p)
	var tween := create_tween()
	for pass_index in range(3):
		tween.tween_callback(func(): sound.play("shuffle"))
		tween.tween_property(piles[2], "position", Vector2(465, 78), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(piles[2], "position", Vector2(413, 91), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	await move_packet(piles[2], Vector2(230, 96), 0.43, -0.035)
	await move_packet(piles[1], Vector2(590, 88), 0.43, 0.025)
	await get_tree().create_timer(0.16).timeout
	ritual_caption.text = LocalizationSystem.text("合牌 · 展开")
	await move_packet(piles[1], Vector2(407, 88), 0.39, 0.0)
	await move_packet(piles[2], Vector2(410, 85), 0.39, 0.0)
	await get_tree().create_timer(0.12).timeout
	content.remove_child(ritual)
	ritual.queue_free()
	# Animate every decorative back from one stack into its final continuous fan.
	# Identity is drawn only from the curated effective deck, never decorative cards.
	tween = create_tween().set_parallel(true)
	tween.tween_callback(func(): sound.play("deal"))
	var spread_nodes: Array = []
	var spread_poses: Array = []
	for child in content.get_children():
		if child.get_script() == Card and str(child.card_id).begins_with("draw:"):
			spread_nodes.append(child)
			spread_poses.append({"position": child.position, "angle": child.rotation})
			child.position = Vector2(1220, 282)
			child.rotation = 0.0
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# One continuous spreading stroke: each card settles as the sweep passes it.
	tween.tween_method(func(progress: float):
		for index in range(spread_nodes.size()):
			var fraction := float(index) / float(maxi(1, spread_nodes.size() - 1))
			var stop_time := 0.18 + (1.0 - fraction) * 0.82
			var t := clampf(progress / stop_time, 0.0, 1.0)
			var smooth_t := t * t * (3.0 - 2.0 * t)
			spread_nodes[index].position = Vector2(1220, 282).lerp(spread_poses[index].position, smooth_t)
			spread_nodes[index].rotation = lerpf(0.0, spread_poses[index].angle, smooth_t)
	, 0.0, 1.0, 1.35)
	await tween.finished
	busy = false
	result_text = "牌已展开。点击牌背，从牌列抽出本轮的 5 张。"
	render()

func move_packet(packet: TextureRect, destination: Vector2, duration: float, tilt: float) -> void:
	var origin := packet.position
	var original_rotation := packet.rotation
	packet.get_parent().move_child(packet, -1)
	var tween := create_tween()
	tween.tween_method(func(t: float):
		packet.position = origin.lerp(destination, t) + Vector2(0, -sin(t * PI) * 18.0)
		packet.rotation = lerpf(original_rotation, tilt, t) + sin(t * PI) * 0.025
		packet.scale = Vector2.ONE * (1.0 + sin(t * PI) * 0.025)
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): sound.play("place"))
	await tween.finished

func pick_from_fan(slot: int) -> void:
	if busy or used_fan_slots.has(slot) or round_picks.size() >= 5 or round_index < 0:
		return
	busy = true
	var id: String = deal[round_index * 5 + round_picks.size()]
	var floating := TextureRect.new()
	floating.set_script(Card)
	floating.texture = common_back
	floating.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floating.size = Vector2(92, 158)
	var fan_count := VISUAL_DECK_SIZE - round_index * 5
	var pose := arc_pose(slot, fan_count, floating.size, true)
	floating.position = pose.position
	floating.pivot_offset = floating.size / 2.0
	floating.rotation = pose.angle
	content.add_child(floating)
	floating.set_selected(true)
	for child in content.get_children():
		if child.get_script() == Card and child.card_id == "draw:" + str(slot):
			child.visible = false
	var tween := create_tween()
	tween.tween_callback(func(): sound.play("flip"))
	tween.tween_property(floating, "position", Vector2(490 + round_picks.size() * 164, 439), 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(floating, "rotation", 0.0, 0.30)
	await tween.finished
	sound.play("place")
	used_fan_slots.append(slot)
	round_picks.append(id)
	owned.append(id)
	busy = false
	result_text = "已抽 %d / 5 张。先听解牌、提出假设，再回桌面抽下一张。" % round_picks.size()
	render()
	await on_card(id)
	show_card(id)

func current_revealed() -> bool:
	if round_index < 0 or round_picks.size() != 5:
		return false
	for i in range(5):
		if not revealed.has(deal[round_index * 5 + i]):
			return false
	return true

func arc_pose(index: int, count: int, dimensions: Vector2, dense: bool) -> Dictionary:
	var half_angle := deg_to_rad(10.5 if dense else 13.2)
	var theta := lerpf(-half_angle, half_angle, float(index) / float(maxi(1, count - 1)))
	var radius := 2200.0 if dense else 1560.0
	var center := Vector2(885, 2500) if dense else Vector2(872, 1935)
	var midpoint := center + Vector2(sin(theta), -cos(theta)) * radius
	return {"position": midpoint - dimensions / 2.0, "angle": theta}

func advance() -> void:
	if busy or not current_revealed():
		return
	if round_index < 2:
		draw_round()
	else:
		mode = "choose"
		result_text = "从全部 15 张牌中挑出 6–8 张。余下的牌不会被丢弃。"
		render()
		if not tutorial_seen.get("choose", false): show_myriorama_help(1)

func on_card(id: String) -> void:
	if busy:
		return
	if id.begins_with("draw:"):
		await pick_from_fan(int(id.trim_prefix("draw:")))
		return
	if not revealed.has(id):
		busy = true
		var target: Control
		for child in content.get_children():
			if child.get_script() == Card and child.card_id == id:
				target = child
				break
		if is_instance_valid(target):
			var tween := create_tween()
			tween.tween_property(target, "scale:x", 0.02, 0.13)
			await tween.finished
			sound.play("flip")
			target.texture = textures[id + "front"]
			tween = create_tween()
			tween.tween_property(target, "scale:x", 1.0, 0.16)
			await tween.finished
		revealed.append(id)
		result_text = "已翻开「%s」并保留，再点一次查看引导与求证。" % deck[id].cn
		busy = false
		render()
		return
	if mode == "choose":
		toggle_main(id)
	elif mode == "sort" and main_cards.has(id):
		if selected_swap.is_empty():
			selected_swap = id
			result_text = "已选「%s」，点击另一张主线牌交换；也可直接拖动到目标牌。" % deck[id].cn
			render()
		else:
			swap_cards(selected_swap, id)
	else:
		show_card(id)

func open_modal() -> Control:
	close_modal()
	modal = Control.new()
	modal.size = Vector2(1600, 900)
	stage.add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color("263d39",.55)
	shade.size = modal.size
	modal.add_child(shade)
	return modal

func close_modal() -> void:
	if is_instance_valid(modal):
		stage.remove_child(modal)
		modal.queue_free()
	modal = null
	modal_id = ""

func show_card(id: String, flip: bool = false) -> void:
	var root := open_modal()
	modal_id = id
	guide_side = flip
	var data: Dictionary = deck[id]
	var pic := TextureRect.new()
	pic.set_script(Card)
	pic.texture = textures[id + ("back" if flip else "front")]
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.position = Vector2(270, 66)
	pic.size = Vector2(280, 480)
	root.add_child(pic)
	box(root, Rect2(150, 561, 510, 238), 1.0)
	label(root, "塔罗师 · 先读画面，再联系案件", Rect2(170, 574, 470, 30), 20, GOLD)
	var prompt: Dictionary = Questions.Bank.guide(case_id, id)
	scroll_text(root, Guidance.introduction(id, data.cn) + "\n\n本故事的观察方向：" + str(prompt.get(case_id, "")), Rect2(170, 613, 470, 168), 20)
	button(root, "看塔罗正面" if flip else "放大阅读引导面", Rect2(230, 810, 370, 44), func():
		if flip: show_card(id)
		else: show_guide_image(id), true)
	box(root, Rect2(680, 98, 700, 738), 0.99)
	label(root, "%s  /  %s" % [data.roman, data.en], Rect2(714, 120, 555, 34), 19, GOLD)
	label(root, data.cn + " · 正位", Rect2(714, 160, 530, 52), 36)
	button(root, "关闭 ×", Rect2(1260, 119, 94, 40), close_modal)
	var records: Array = question_records.get(id, [])
	label(root, "向主持人提问  /  有效求证 %d / 2" % records.size(), Rect2(714, 222, 610, 35), 22, GOLD)
	label(root, "这张牌可谈：" + str(Guidance.GUIDES[id][0]), Rect2(714, 261, 620, 37), 17, MUTED)
	question_input = LineEdit.new()
	question_input.position = Vector2(714, 308)
	question_input.size = Vector2(624, 62)
	question_input.placeholder_text = LocalizationSystem.text("输入你想问的问题……")
	question_input.max_length = 120
	question_input.add_theme_font_size_override("font_size", 23)
	question_input.add_theme_color_override("font_color", INK)
	question_input.add_theme_color_override("caret_color", INK)
	question_input.add_theme_color_override("font_placeholder_color", Color("646a63"))
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = CREAM
	input_style.set_content_margin_all(12)
	input_style.set_corner_radius_all(4)
	question_input.add_theme_stylebox_override("normal", input_style)
	root.add_child(question_input)
	question_input.text = question_drafts.get(id, "")
	pending_question = {}
	question_suggestions = []
	button(root, "理解我的问题 ↵", Rect2(714, 383, 270, 45), review_question, true)
	question_confirm = button(root, "确认含义 · 请回答", Rect2(1000, 383, 338, 45), confirm_question)
	question_confirm.disabled = true
	question_feedback = ScrollContainer.new()
	question_feedback.position = Vector2(714, 440)
	question_feedback.size = Vector2(624, 106)
	question_feedback.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(question_feedback)
	question_reply = Label.new()
	question_reply.custom_minimum_size.x = 600
	question_reply.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_reply.add_theme_font_size_override("font_size", 19)
	question_reply.text = LocalizationSystem.text("想了解画面也可以直接问；解牌不扣次数。\n提出案件假设时，请写明对象，再确认主持人的理解。")
	question_feedback.add_child(question_reply)
	question_input.text_submitted.connect(func(_value): review_question())
	question_input.text_changed.connect(func(value):
		question_drafts[id] = value
		pending_question = {}
		question_confirm.disabled = true
		question_reply.text = LocalizationSystem.text("输入完成后按 Enter；确认主持人理解正确，再求证。")
		clear_question_suggestions()
	)
	label(root, "与塔罗师的对话记录", Rect2(714, 560, 380, 32), 19, GOLD)
	button(root, "不知道怎么问？", Rect2(1125, 556, 213, 36), func(): show_question_help(id))
	var notes := "还没有有效提问。你可以先翻看引导面，再提出自己的假设。"
	if not records.is_empty():
		notes = ""
		for record in records:
			notes += ("YES · " if record.answer else "NO · ") + str(record.claim) + "\n"
	var history: Array = conversations.get(id, [])
	if not history.is_empty(): notes = "\n\n".join(history)
	var history_holder := Control.new()
	history_holder.name = "ConversationHistory"
	root.add_child(history_holder)
	scroll_text(history_holder, notes, Rect2(714, 601, 624, 132), 18)
	button(root, "回到桌面 · 保留此牌", Rect2(714, 752, 624, 48), close_modal, true)

func review_question() -> void:
	if not is_instance_valid(question_input):
		return
	pending_question = Questions.parse(case_id, question_input.text, modal_id)
	clear_question_suggestions()
	question_confirm.disabled = true
	if pending_question.status == "recognized" and not Guidance.allows(case_id, modal_id, pending_question.id):
		question_reply.text = LocalizationSystem.text("我理解你问的是「%s」。但这张牌更适合谈%s。可换一张相关牌继续问；本次不扣次数。" % [pending_question.claim, Guidance.GUIDES[modal_id][0]])
		var related: Array[String] = []
		for card_id in revealed:
			if Guidance.allows(case_id, card_id, pending_question.id): related.append(deck[card_id].cn)
		if not related.is_empty(): question_reply.text += LocalizationSystem.text("\n你已翻开的「" + "、".join(related.slice(0, 3)) + "」可继续这个方向。")
		pending_question.status = "unrelated"
		remember_exchange(question_input.text, question_reply.text)
		return
	if pending_question.status != "recognized":
		question_reply.text = LocalizationSystem.text(pending_question.message)
		if pending_question.status in ["unsupported", "clarify_scope"]:
			var clarifying: bool = pending_question.status == "clarify_scope"
			var proposals: Array = pending_question.options if clarifying else Questions.suggest(case_id, question_input.text, Guidance.allowed_facts(case_id, modal_id))
			proposals = proposals.filter(func(p): return Guidance.allows(case_id, modal_id, p.id))
			if not proposals.is_empty():
				if not clarifying:
					question_reply.text = LocalizationSystem.text("找到相近方向。下方是改写建议，不是对原句的回答：")
				question_reply.size.y = 32
				question_feedback.size.y = 32
				for i in range(proposals.size()):
					var proposal: Dictionary = proposals[i]
					var b := button(modal, ("我指的是：" if clarifying else "改问：") + str(proposal.claim), Rect2(714, 478 + i * 39, 624, 34), func():
						pending_question = proposal.duplicate(true)
						clear_question_suggestions()
						question_reply.text = LocalizationSystem.text("已选择改写后的命题：\n「%s」\n确认后才判断；这不是对你原句的直接回答。" % pending_question.claim)
						question_confirm.disabled = false
					)
					b.add_theme_font_size_override("font_size", 16)
					question_suggestions.append(b)
		remember_exchange(question_input.text, question_reply.text)
		return
	question_reply.text = LocalizationSystem.text("你想求证的是：\n「%s」\n请检查人物和时间；意思不对可直接修改输入。" % pending_question.claim)
	question_confirm.disabled = false
	remember_exchange(question_input.text, "我理解为「%s」。请确认含义后再求证。" % pending_question.claim)

func clear_question_suggestions() -> void:
	for b in question_suggestions:
		if is_instance_valid(b):
			b.hide()
			b.queue_free()
	question_suggestions.clear()
	if is_instance_valid(question_reply):
		question_reply.size.y = 106
	if is_instance_valid(question_feedback):
		question_feedback.size.y = 106
		question_feedback.scroll_vertical = 0

func scroll_text(parent: Control, text: String, rect: Rect2, font_size: int) -> void:
	var scroll := ScrollContainer.new()
	scroll.position = rect.position
	scroll.size = rect.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var body := Label.new()
	body.text = LocalizationSystem.text(text)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = rect.size.x - 22
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", font_size)
	body.add_theme_color_override("font_color", INK)
	scroll.add_child(body)

func remember_exchange(player: String, host: String) -> void:
	var history: Array = conversations.get(modal_id, [])
	history.append("你：" + player + "\n塔罗师：" + host)
	conversations[modal_id] = history
	var holder := modal.get_node_or_null("ConversationHistory")
	if holder:
		for child in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
		scroll_text(holder, "\n\n".join(history), Rect2(714, 601, 624, 132), 18)
		var scroller: ScrollContainer = holder.get_child(0)
		scroller.set_deferred("scroll_vertical", 100000)
	save_session()

func show_guide_image(id: String) -> void:
	var root := open_modal()
	var pic := TextureRect.new()
	pic.texture = textures[id + "back"]
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.position = Vector2(580, 38)
	pic.size = Vector2(455, 780)
	root.add_child(pic)
	button(root, "返回对话", Rect2(650, 833, 300, 45), func(): show_card(id), true)

func show_truth_dialogue() -> void:
	var root := open_modal()
	box(root, Rect2(130, 65, 1340, 785), 1.0)
	label(root, "万景已连接 · 现在请你说出真相", Rect2(165, 90, 1240, 50), 30, GOLD)
	label(root, "塔罗师：请把人物、原因、过程与结果串起来。每句写清主体，可分行陈述；我会先复述，不会自动补上漏掉的真相。", Rect2(165, 154, 1250, 64), 21)
	truth_input = TextEdit.new()
	truth_input.position = Vector2(165, 232)
	truth_input.size = Vector2(580, 482)
	truth_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	truth_input.placeholder_text = LocalizationSystem.text("用自己的话陈述完整真相……\n\n可以一行一个事实，明确谁做了什么。\n规则故事请说明全部成立条件，而不只是一个成功例子。")
	truth_input.add_theme_font_size_override("font_size", 21)
	root.add_child(truth_input)
	truth_input.text = truth_draft
	truth_review = {}
	truth_reply = label(root, "塔罗师：拼对主线还不算结束。\n\n写好后点击‘请理解我的陈述’。你可以反复修改，不限制尝试次数。\n\n离线覆盖有限，无法核对的句子会明确列出，不会被忽略。", Rect2(785, 239, 630, 460), 21)
	truth_input.text_changed.connect(func():
		truth_draft = truth_input.text
		truth_review = {}
		truth_confirm.disabled = true
		save_session())
	button(root, "请理解我的陈述", Rect2(165, 738, 580, 49), review_truth, true)
	truth_confirm = button(root, "复述正确 · 核对完整真相", Rect2(785, 738, 630, 49), confirm_truth)
	truth_confirm.disabled = true
	button(root, "返回桌面继续调查", Rect2(1090, 96, 315, 43), close_modal)

func review_truth() -> void:
	truth_review = Truth.review(case_id, truth_input.text)
	var lines: Array[String] = []
	for row in truth_review.rows: lines.append("· " + str(row.claim))
	var report := "我读到的陈述（此时尚未判定对错）：\n" + "\n".join(lines)
	if not truth_review.unknown.is_empty():
		report += "\n\n这些句子还需澄清，请写明人物与动作、拆开条件或否定：\n「" + "」\n「".join(truth_review.unknown) + "」"
	truth_reply.text = ""
	# Scroll avoids long paragraphs hiding either unparsed clauses or contradictions.
	for child in modal.get_children():
		if child.name == "TruthReport":
			modal.remove_child(child)
			child.queue_free()
	var holder := Control.new()
	holder.name = "TruthReport"
	modal.add_child(holder)
	scroll_text(holder, report, truth_report_rect(), 20)
	truth_confirm.disabled = truth_review.rows.is_empty() or not truth_review.unknown.is_empty()

func truth_report_rect() -> Rect2:
	return Rect2(785, 239, 630, 475)

func confirm_truth() -> void:
	if truth_review.is_empty() or not Rules.evaluate(case_id, main_cards).complete: return
	if truth_review.complete:
		show_truth()
		return
	for child in modal.get_children():
		if child.name == "TruthReport":
			modal.remove_child(child)
			child.queue_free()
	var report := "塔罗师：故事还没有闭合。你可以继续补充。\n"
	if not truth_review.conflicts.is_empty():
		report += "\n与案件设定冲突的陈述：\n「" + "」\n「".join(truth_review.conflicts) + "」\n"
	if not truth_review.missing.is_empty():
		report += "\n还需交代（这里只提示环节，不公布答案）：\n· " + "\n· ".join(truth_review.missing)
	var holder := Control.new()
	holder.name = "TruthReport"
	modal.add_child(holder)
	truth_reply.text = ""
	scroll_text(holder, report, truth_report_rect(), 21)
	truth_confirm.disabled = true

func show_question_help(id: String) -> void:
	var root := open_modal()
	box(root, Rect2(360, 135, 900, 630), 1.0)
	label(root, "从观察变成一个问题", Rect2(400, 170, 820, 60), 32, GOLD, true)
	var guide: Dictionary = Questions.Bank.guide(case_id, id)
	var text := "① 看见什么 → 你可以先问画面：\n「%s」\n%s\n\n② 在这个故事中往哪里想：\n%s\n\n③ 用自己的猜测填入句式，不是选择答案：\n%s\n\n先确认我复述的意思，再听 YES / NO。画面细节、未知设定或澄清都不扣次数。" % [guide.aliases[0], guide.reply, guide[case_id], guide.frames[0 if case_id == "murder" else 1]]
	scroll_text(root, text, Rect2(405, 250, 805, 395), 22)
	label(root, "完全离线，覆盖有限。没匹配上时可选择相近改写，不会乱给 NO。", Rect2(405, 658, 805, 35), 17, MUTED, true)
	button(root, "回去提出我的问题", Rect2(595, 702, 410, 46), func(): show_card(id), true)

func confirm_question() -> void:
	if pending_question.get("status", "") != "recognized" or modal_id.is_empty():
		return
	if not Guidance.allows(case_id, modal_id, pending_question.id):
		return
	var records: Array = question_records.get(modal_id, [])
	for record in records:
		if record.id == pending_question.id:
			question_reply.text = LocalizationSystem.text("这条事实已经问过，不重复扣次数。\n" + Questions.verdict(pending_question))
			question_confirm.disabled = true
			return
	if records.size() >= 2:
		question_reply.text = LocalizationSystem.text("这张牌的 2 次有效求证已用完；笔记仍可回看，可借其他牌继续发问。")
		question_confirm.disabled = true
		return
	var response := pending_question.duplicate(true)
	records.append(response)
	question_records[modal_id] = records
	remember_exchange(str(response.raw), Questions.verdict(response))
	sound.play("yes" if response.answer else "no")
	save_session()
	show_card(modal_id, guide_side)
	question_reply.text = LocalizationSystem.text(Questions.verdict(response) + "\n已加入笔记；卡牌仍然保留。")
	feedback("YES · 已记录" if response.answer else "NO · 排除这一种可能", Color("94d3b2") if response.answer else GOLD)

func render_choose() -> void:
	box(content, Rect2(80, 169, 1440, 41), 0.96)
	label(content, "已选 %d / 8   ·   点击选择或取消；点击下方「解读」查看卡片" % main_cards.size(), Rect2(100, 170, 1400, 34), 21, MUTED, true)
	for i in range(owned.size()):
		var id: String = owned[i]
		var x := 105.0 + (i % 8) * 177
		var y := 233.0 + floori(float(i) / 8.0) * 286
		if main_cards.has(id):
			var border := box(content, Rect2(x - 5, y - 5, 138, 231), 1.0)
			border.modulate = Color("f5d588")
		card(content, id, Rect2(x, y, 128, 219))
		var inspect := button(content, "正位·" + ("已选" if main_cards.has(id) else "解读"), Rect2(x, y + 227, 128, 33), func(): show_card(id))
		inspect.add_theme_font_size_override("font_size", 17)
	button(content, "回到观牌桌", Rect2(990, 817, 200, 49), func(): mode = "draw"; render())
	var go := button(content, "展开万景 · 开始排序", Rect2(1210, 817, 310, 49), func():
		mode = "sort"
		result_text = "按故事逻辑从左到右排列；画面接得上，不代表真相正确。"
		render()
		if not tutorial_seen.get("sort", false): show_myriorama_help(2), true)
	go.disabled = main_cards.size() < 6 or main_cards.size() > 8

func toggle_main(id: String) -> void:
	if main_cards.has(id):
		main_cards.erase(id)
	elif main_cards.size() < 8:
		main_cards.append(id)
	else:
		result_text = "主线最多 8 张，先取消一张；其他牌依然保留。"
		feedback("最多选择 8 张", GOLD)
		return
	sound.play("place")
	result_text = "已选 %d 张主线牌 · 全部 15 张仍然保留" % main_cards.size()
	render()

func render_sort() -> void:
	box(content, Rect2(70, 176, 1460, 46), 0.96)
	label(content, "从左到右讲故事 · 拖到另一张牌上交换，或依次点两张 · 接上景色 ≠ 推理成立", Rect2(80, 180, 1440, 36), 20, MUTED, true)
	var card_width := 170.0
	var left := (1600.0 - main_cards.size() * card_width) / 2.0
	for i in range(main_cards.size()):
		var id: String = main_cards[i]
		var c := card(content, id, Rect2(left + i * card_width, 270, card_width, card_width * 12.0 / 7.0), true, true)
		if id == selected_swap:
			c.modulate = Color("ffe4ab")
		label(content, "%02d" % (i + 1), Rect2(left + i * card_width, 571, card_width, 27), 20, GOLD, true)
	box(content, Rect2(60, 601, 1480, 195), 0.95)
	label(content, "所有牌仍在下方收藏区，点击可回看引导与记录。", Rect2(80, 604, 1440, 33), 18, CREAM, true)
	for i in range(owned.size()):
		var id: String = owned[i]
		var small := card(content, id, Rect2(95 + i * 94, 661, 66, 113))
		small.picked.disconnect(on_card)
		small.picked.connect(show_card)
	button(content, "重新选主线", Rect2(1090, 817, 190, 49), func(): mode = "choose"; selected_swap = ""; result_text = "未选牌仍然保留，可随时替换主线。"; render())
	button(content, "验证故事连接", Rect2(1300, 817, 235, 49), check_story, true)

func swap_cards(a: String, b: String) -> void:
	if not main_cards.has(a) or not main_cards.has(b):
		return
	var i := main_cards.find(a)
	var j := main_cards.find(b)
	main_cards[i] = b
	main_cards[j] = a
	sound.play("place")
	selected_swap = ""
	result_text = "已交换位置。线索没有丢失，可以继续调整。"
	render()
	feedback("位置已交换", GOLD)

func check_story() -> void:
	var result: Dictionary = Rules.evaluate(case_id, main_cards)
	if result.complete:
		show_truth_dialogue()
	else:
		sound.play("no")
		result_text = "主线相关 %d / %d 张 · 正确连接 %d 段。图能拼上，不代表故事已经成立。" % [result.related, result.required, result.connections]
		render()

func show_doors_test() -> void:
	var root := open_modal()
	box(root, Rect2(370, 205, 860, 485), 1.0)
	label(root, "推理已连接 · 再验证一次规律", Rect2(405, 232, 790, 63), 29, GOLD, true)
	label(root, "哪组人数能通过四扇门？每组选项的总人数都是五十。", Rect2(415, 316, 770, 55), 21, CREAM, true)
	var candidates := [[5, 5, 15, 25], [5, 10, 10, 25], [10, 10, 10, 20]]
	for i in range(candidates.size()):
		var numbers: Array = candidates[i]
		button(root, "%d  /  %d  /  %d  /  %d" % numbers, Rect2(510, 399 + i * 75, 580, 50), func():
			if Rules.doors_rule(numbers):
				show_truth()
			else:
				close_modal()
				result_text = "这个例子仍不能满足规则。重新比较相等两组的位置。"
				render()
		)
	button(root, "返回", Rect2(400, 610, 95, 48), close_modal)

func show_truth() -> void:
	solmere_completed = true
	save_session()
	sound.play("complete")
	var root := open_modal()
	box(root, Rect2(365, 145, 870, 610), 1.0)
	label(root, "世 界 · 故 事 闭 合", Rect2(400, 181, 800, 75), 37, GOLD, true)
	label(root, Rules.CASES[case_id].truth, Rect2(420, 278, 760, 333), 25)
	label(root, "这是完成标记，不是新增的第十九张可抽卡。", Rect2(420, 632, 760, 35), 18, MUTED, true)
	button(root, "回到万景桌", Rect2(610, 685, 380, 48), close_modal, true)
	feedback("主线成立 · 故事闭合", GOLD)

func choose_case() -> void:
	var root := open_modal()
	box(root, Rect2(420, 230, 760, 420), 1.0)
	label(root, "选择一则海龟汤", Rect2(455, 256, 690, 65), 34, GOLD, true)
	label(root, "开始新故事会重置当前一局的抽牌与排序。", Rect2(455, 326, 690, 50), 21, MUTED, true)
	button(root, "门外的目击者 · 事件链", Rect2(515, 406, 570, 56), func(): new_case("murder"), true)
	button(root, "五十人与四扇门 · 推理链", Rect2(515, 483, 570, 56), func(): new_case("doors"))
	button(root, "继续当前故事", Rect2(645, 574, 310, 45), close_modal)

func new_case(id: String) -> void:
	solmere_completed = false
	close_modal()
	case_id = id
	deal = Rules.make_deal(case_id, rng)
	owned = []
	revealed = []
	main_cards = []
	answers = {}
	question_records = {}
	question_drafts = {}
	conversations = {}
	truth_draft = ""
	truth_review = {}
	round_picks = []
	used_fan_slots = []
	round_index = -1
	mode = "draw"
	selected_swap = ""
	result_text = ""
	render()

func show_rules() -> void:
	var root := open_modal()
	box(root, Rect2(390, 190, 820, 560), 1.0)
	label(root, "观牌 · 取证 · 甄选 · 万景", Rect2(425, 220, 750, 60), 30, GOLD, true)
	label(root, "当前全部正位 · 逆位暂未启用；扇形摆放角度不是逆位。", Rect2(435, 636, 730, 28), 17, GOLD, true)
	label(root, "① 三轮，每轮 5 张；每次抽一张，先听解牌再提问。\n\n② 正面看画面，引导面看象征；象征不是案件证据。\n\n③ 自由输入相关问题，先确认含义再回答；每牌 2 次有效求证，所有牌和问答保留。\n\n④ 从 15 张中选出相关的 6–8 张，拖动交换拼成万景。\n\n⑤ 拼好后还须自由陈述完整真相，澄清和补全后才完成。", Rect2(440, 300, 720, 335), 22)
	button(root, "回到桌面", Rect2(640, 664, 320, 49), close_modal, true)
	button(root, "万景图入门", Rect2(425, 664, 180, 49), show_myriorama_help)

func show_myriorama_help(page: int = 0) -> void:
	tutorial_step = clampi(page, 0, 2)
	var root := open_modal()
	box(root, Rect2(245, 65, 1110, 790), 1.0)
	var titles := ["万景图：把几张小景，接成一幅长景", "选主线：不是看着顺眼就选", "排出故事后，还要讲清真相"]
	label(root, "初次上桌", Rect2(280, 91, 1000, 35), 20, GOLD)
	label(root, titles[tutorial_step], Rect2(280, 143, 1030, 52), 31, CREAM, true)
	if tutorial_step == 0:
		var samples := ["01", "03", "08"] if not tutorial_swapped else ["08", "03", "01"]
		for i in range(3):
			var pic := TextureRect.new()
			pic.texture = textures[samples[i] + "front"]
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.position = Vector2(515 + i * 190, 227)
			pic.size = Vector2(190, 326)
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(pic)
		label(root, "观察横穿牌面的山、水与地面。示意牌不加入收藏，也不代表本关答案。", Rect2(300, 565, 1000, 38), 19, MUTED, true)
		button(root, "试试交换两端的示意牌", Rect2(555, 613, 490, 44), func(): tutorial_swapped = not tutorial_swapped; show_myriorama_help(0))
		label(root, "换个顺序，仍能组成长景；但本游戏还要求牌能讲出有依据的故事。\n不是寻找唯一吻合的拼图缺口，也不需要先懂塔罗知识。", Rect2(300, 675, 1000, 70), 22, CREAM, true)
	elif tutorial_step == 1:
		var text := "① 先观察与求证\n每次抽一张，听塔罗师解释画面，用自己的假设提问。所有牌和 YES / NO 都保留。\n\n② 再从收藏选 6—8 张主线\n优先选能解释关键人物、动机、行动、结果或规则的牌。不是要求每张都问满两次，也不是只留 YES。\n\n③ 最后组织连接\n案件可以按‘起因 → 行动 → 结果’来思考；规则故事可以按‘猜测 → 反例 → 修正规则’来思考。\n\n这些是思考方法，不是本关的固定答案；选错可取消，未选的牌不会消失。"
		scroll_text(root, text, Rect2(315, 235, 970, 505), 26)
	else:
		var text := "① 从左到右排列\n拖一张牌到另一张上，就会交换位置；也可先点一张，再点另一张。当前没有插入或自由堆叠操作。\n\n② 同时检查两种连接\n画面层：山、水、地面连成一幅长景。\n故事层：相邻两张为什么有关？前因怎样导致后果？规则怎样被检验？\n\n③ 提交后继续向主持人解释\n拼牌通过不等于通关。还要用自己的话说清完整真相；漏项可补充，没理解的句子会追问。\n\n如果卡住：回看下方收藏的问答记录，或者返回选牌。不要靠卡片边缘的小误差猜答案。"
		scroll_text(root, text, Rect2(315, 235, 970, 505), 26)
	button(root, "稍后再看", Rect2(285, 778, 185, 45), finish_myriorama_help)
	if tutorial_step > 0:
		button(root, "上一步", Rect2(825, 778, 180, 45), func(): show_myriorama_help(tutorial_step - 1))
	button(root, "下一步" if tutorial_step < 2 else "明白了 · 回到桌面", Rect2(1020, 778, 300, 45), func():
		if tutorial_step < 2: show_myriorama_help(tutorial_step + 1)
		else: finish_myriorama_help(), true)

func finish_myriorama_help() -> void:
	tutorial_seen["intro"] = true
	tutorial_seen[mode] = true
	save_session()
	close_modal()

func toggle_fullscreen() -> void:
	var current := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if current == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle_fullscreen()
		elif event.keycode == KEY_ESCAPE:
			if is_instance_valid(modal):
				close_modal()
			elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func save_session() -> void:
	if OS.get_cmdline_user_args().has("--smoke-test"):
		return
	GameState.shared_state["myriorama_"+GameState.current_role] = {"case_id": case_id, "deal": deal, "owned": owned, "revealed": revealed, "main": main_cards, "answers": answers, "question_records": question_records, "round_picks": round_picks, "used_fan_slots": used_fan_slots, "orientations": card_orientations, "reversed_enabled": REVERSED_ENABLED, "round": round_index, "mode": mode, "muted": sound.muted, "truth_draft": truth_draft, "conversations": conversations, "question_drafts": question_drafts, "tutorial_seen": tutorial_seen, "solmere_completed": solmere_completed}
	SaveManager.save_or_report("塔罗状态保存失败")

func load_session() -> void:
	if not GameState.shared_state.has("myriorama_"+GameState.current_role) or OS.get_cmdline_user_args().has("--smoke-test"):
		return
	var data: Variant = GameState.shared_state["myriorama_"+GameState.current_role]
	if not data is Dictionary or not Rules.CASES.has(data.get("case_id", "")):
		return
	var saved_deal: Array = data.get("deal", [])
	if saved_deal.size() != 15:
		return
	for id in saved_deal:
		if not deck.has(id):
			return
	solmere_completed = bool(data.get("solmere_completed",false))
	case_id = data.case_id
	sound.muted = bool(data.get("muted", false))
	deal = saved_deal
	owned = data.get("owned", [])
	revealed = data.get("revealed", [])
	main_cards = data.get("main", [])
	answers = data.get("answers", {})
	question_records = data.get("question_records", {})
	conversations = data.get("conversations", {})
	question_drafts = data.get("question_drafts", {})
	tutorial_seen = data.get("tutorial_seen", {})
	truth_draft = data.get("truth_draft", "")
	round_index = clampi(int(data.get("round", -1)), -1, 2)
	round_picks = data.get("round_picks", owned.slice(maxi(0, round_index * 5), maxi(0, round_index * 5 + 5)))
	used_fan_slots = data.get("used_fan_slots", [])
	mode = data.get("mode", "draw")
	if not ["draw", "choose", "sort"].has(mode):
		mode = "draw"

func smoke_test() -> void:
	var original_owned := owned.duplicate()
	for page in range(3):
		show_myriorama_help(page)
		assert(is_instance_valid(modal) and tutorial_step == page)
		assert(owned == original_owned)
	finish_myriorama_help()
	assert(tutorial_seen.get("intro", false))
	for id in Rules.CASES:
		for seed_value in range(100):
			rng.seed = seed_value
			var sample: Array = Rules.make_deal(id, rng)
			assert(sample.size() == 15)
			var unique := {}
			for c in sample:
				unique[c] = true
			assert(unique.size() == 15)
			for c in Rules.CASES[id].main:
				assert(sample.has(c))
		assert(Rules.evaluate(id, Rules.CASES[id].main).complete)
		var reversed: Array = Rules.CASES[id].main.duplicate()
		reversed.reverse()
		assert(not Rules.evaluate(id, reversed).complete)
	assert(Rules.doors_rule([5, 10, 10, 25]))
	assert(Rules.doors_rule([25, 10, 5, 10]))
	assert(not Rules.doors_rule([5, 5, 15, 25]))
	assert(not Rules.doors_rule([10, 10, 10, 20]))
	assert(not Rules.doors_rule([5, 15, 15, 25]))
	assert(not Rules.doors_rule([0, 10, 10, 30]))
	for id in deck:
		assert(textures[id + "front"] != null and textures[id + "back"] != null)
		assert(card_orientations[id] == "upright")
	for kind in sound.clips:
		var clip: AudioStream = sound.clips[kind]
		assert(clip != null and clip.get_length() > 0.01)
		if clip is AudioStreamWAV and not sound.variants.has(kind):
			var peak := 0
			for sample_index in range(0, clip.data.size(), 2):
				peak = maxi(peak, absi(clip.data.decode_s16(sample_index)))
			assert(peak > 500 and peak < 32000)
	Questions.self_test()
	preload("res://extensions/myriorama_tarot/scripts/question_bank_test.gd").run()
	Truth.self_test()
	assert(Guidance.allows("doors", "01", "middle_equal"))
	assert(not Guidance.allows("murder", "09", "weapon"))
	for arc_index in range(5):
		var pose := arc_pose(arc_index, 5, Vector2(156, 267), false)
		var center_of_card: Vector2 = pose.position + Vector2(78, 133.5)
		assert(absf(center_of_card.distance_to(Vector2(872, 1935)) - 1560.0) < 0.05)
		var bottom := center_of_card.y + absf(sin(pose.angle)) * 78.0 + absf(cos(pose.angle)) * 133.5 + 8.0
		assert(bottom < 580.0)
	new_case("murder")
	for iteration in range(3):
		await draw_round()
		assert(owned.size() == 5 * iteration)
		var fan_total := 0
		for child in content.get_children():
			if child.get_script() == Card and str(child.card_id).begins_with("draw:"):
				fan_total += 1
		assert(fan_total == 78 - iteration * 5)
		for slot in range(5):
			await pick_from_fan(slot)
			assert(is_instance_valid(modal) and revealed.has(round_picks.back()))
			close_modal()
		assert(owned.size() == 5 * (iteration + 1))
		assert(current_revealed())
	assert(owned.size() == 15 and revealed.size() == 15)
	var owned_before := owned.duplicate()
	show_card("09")
	question_input.text = LocalizationSystem.text("两个杯子是爱情吗")
	review_question()
	confirm_question()
	assert(pending_question.status == "guidance" and question_records.is_empty())
	question_input.text = LocalizationSystem.text("水果刀上有指纹吗")
	review_question()
	confirm_question()
	assert(pending_question.status == "unwritten" and question_records.is_empty())
	question_input.text = LocalizationSystem.text("水果刀是凶器吗")
	review_question()
	confirm_question()
	assert(pending_question.status == "unrelated" and question_records.is_empty())
	show_card("16")
	question_input.text = LocalizationSystem.text("报案人进入过房间吗")
	review_question()
	confirm_question()
	assert(question_records["16"][0].answer == false and owned == owned_before)
	assert(is_instance_valid(modal))
	show_card("09", true)
	assert(guide_side)
	close_modal()
	mode = "choose"
	for id in Rules.CASES.murder.main:
		toggle_main(id)
	assert(main_cards.size() == 8)
	for id in owned:
		if not main_cards.has(id):
			toggle_main(id)
			break
	assert(main_cards.size() == 8 and owned.size() == 15)
	mode = "sort"
	render()
	swap_cards("09", "10")
	assert(not Rules.evaluate(case_id, main_cards).complete)
	swap_cards("10", "09")
	assert(Rules.evaluate(case_id, main_cards).complete)
	check_story()
	assert(is_instance_valid(truth_input))
	truth_input.text = LocalizationSystem.text("女子三杀死了死者")
	review_truth()
	confirm_truth()
	assert(not truth_review.complete)
	close_modal()
	new_case("doors")
	show_card("01")
	question_input.text = LocalizationSystem.text("不相等就会死")
	review_question()
	assert(pending_question.status == "clarify_scope" and question_suggestions.size() == 2)
	assert(question_records.is_empty())
	question_suggestions[0].pressed.emit()
	confirm_question()
	assert(question_records["01"][0].answer)
	show_question_help("01")
	close_modal()
	show_card("06")
	question_input.text = LocalizationSystem.text("测试 4、11、11、24")
	review_question()
	assert(not question_confirm.disabled)
	confirm_question()
	assert(question_records["06"].size() == 1 and question_records["06"][0].answer)
	question_input.text = LocalizationSystem.text("测试 24、11、4、11")
	review_question()
	confirm_question()
	assert(question_records["06"].size() == 1)
	close_modal()
	main_cards = Rules.CASES.doors.main.duplicate()
	check_story()
	truth_input.text = LocalizationSystem.text("四组总人数是五十。最低<中间=中间<最高。换门不影响结果。")
	review_truth()
	assert(truth_review.complete and not truth_confirm.disabled)
	confirm_truth()
	close_modal()
	show_rules()
	close_modal()
	print("PASS: 200 deals; one-card reveal + host dialogue x15; 78-card fan; 36 textures; 8 audio categories; upright; arc; NO retains; card affinity; scope clarification; truth completeness + contradiction + unknown + causal safeguards; two-stage ending")
	get_tree().quit()

func feedback(message: String, color: Color) -> void:
	var popup := box(stage, Rect2(485, 45, 630, 64), 1.0)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label(popup, message, Rect2(15, 8, 600, 46), 23, color, true)
	popup.position.y = 28
	popup.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(popup, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(popup, "position:y", 45.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.25)
	tween.tween_property(popup, "modulate:a", 0.0, 0.35)
	tween.tween_callback(popup.queue_free)
