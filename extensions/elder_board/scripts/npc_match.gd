extends Control
## Solmere's compact encounter board. Selection, formation and play share one scene.
signal return_requested
signal match_finished(result: String)

const Rules = preload("res://extensions/elder_board/scripts/npc_rules.gd")
const Art = preload("res://extensions/elder_board/scripts/table_art.gd")
const UI = preload("res://extensions/elder_board/scripts/ui_bits.gd")
const BOARD := Rect2(231, 163, 616, 616)
const TILE := 88.0
const PLAYER := Color("456c67")
const RIVAL := Color("a0644f")
const TARGET := Color("d4b971")
const PAPER := Color("fbf4e4")

var mode := "select"
var selected_ids: Array[String] = []
var rival_ids: Array[String] = []
var selection_side := 0
var placed := [-1, -1, -1, -1]
var rival_placed := [-1, -1, -1, -1]
var deploy_side := 0
var placing := 0
var selected_piece := -1
var hover_inspect_id := -1
var hovered_cell := -1
var state: Dictionary = {}
var layer: Control
var textures: Dictionary = {}
var generation := 0
var tutorial := true
var debug_open := false
var debug_relocate := false
var feedback := "选四位角色，让他们在棋盘上碰面。"
var animation_progress := 1.0
var transitions: Dictionary = {}
var pulse_score := false

func _ready() -> void:
	size = Vector2(1579, 972)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UI.paper_theme()
	layer = Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.size = size
	add_child(layer)
	_rebuild()

func _rebuild() -> void:
	for child in layer.get_children(): child.queue_free()
	match mode:
		"select": _selection_ui()
		"deploy": _deployment_ui()
		"play", "end": _match_ui()
	queue_redraw()

func _label(parent: Node, text: String, at: Vector2, width: float, height: float, font_size := 23) -> Label:
	return UI.label(parent, text, Rect2(at, Vector2(width, height)), font_size)

func _button(parent: Node, text: String, at: Vector2, extent: Vector2, action: Callable, font_size := 22) -> Button:
	var item := UI.button(parent, text, Rect2(at, extent), action)
	item.add_theme_font_size_override("font_size", font_size)
	return item

func _selection_ui() -> void:
	_label(layer, "相遇棋", Vector2(226, 74), 600, 58, 44)
	_label(layer, "先为你选四位，再为老棋友选四位 · 双方可以选同一角色", Vector2(226, 173), 700, 35, 20)
	var definitions := Rules.definitions()
	var roster: Array[String] = selected_ids if selection_side == 0 else rival_ids
	for i in definitions.size():
		var item: Dictionary = definitions[i]
		var x := 226 + (i % 3) * 233
		var y := 218 + int(i / 3) * 132
		var chosen := roster.has(str(item.id))
		UI.panel(layer, Rect2(x, y, 216, 119))
		var card := _button(layer, ("✓  " if chosen else "＋  ") + str(item.name), Vector2(x + 8, y + 8), Vector2(200, 45), _toggle_pick.bind(str(item.id)), 22)
		card.variant = "paper"
		card.selected = chosen
		card.tooltip_text = str(item.rule)
		card.refresh()
		var rule := _label(layer, _card_rule(str(item.rule)), Vector2(x + 13, y + 58), 190, 45, 16)
		rule.clip_text = true
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(layer, "你的四人队" if selection_side == 0 else "老棋友的四人队", Vector2(1015, 174), 380, 48, 30)
	for i in 4:
		var name := "尚未选择" if i >= roster.size() else str(Rules.definition(roster[i]).get("name", ""))
		_label(layer, "%02d   %s" % [i + 1, name], Vector2(1020, 229 + i * 69), 405, 48, 25)
	_label(layer, "移动到对方角色所在格会触发碰面。\n每一组新碰面得一分，先得四分获胜。", Vector2(1018, 545), 410, 105, 21)
	var ready := _button(layer, "选择对手阵容  →" if selection_side == 0 else "开始布阵  →", Vector2(1017, 693), Vector2(417, 57), _start_deployment, 25)
	ready.disabled = roster.size() != 4
	_button(layer, "推荐阵容", Vector2(1017, 765), Vector2(200, 48), _beginner_team, 21)
	_button(layer, "返回上一页", Vector2(1233, 765), Vector2(201, 48), _back_selection, 20)
	_label(layer, "先点角色，再点棋盘；棋子的规则随时显示在右侧。", Vector2(233, 826), 850, 40, 21)

func _card_rule(value: String) -> String:
	var lines: Array[String] = []
	for start in range(0, mini(value.length(), 22), 11):
		lines.append(value.substr(start, 11))
	if value.length() > 22 and not lines.is_empty(): lines[lines.size() - 1] += "…"
	return "\n".join(lines)

func _toggle_pick(id: String) -> void:
	var roster: Array[String] = selected_ids if selection_side == 0 else rival_ids
	if roster.has(id): roster.erase(id)
	elif roster.size() < 4: roster.append(id)
	_rebuild()

func _beginner_team() -> void:
	if selection_side == 0: selected_ids.assign(["mossner", "chenyuan", "beetman", "naonao"])
	else: rival_ids.assign(["xanni", "maya", "xia_touming", "cici"])
	_rebuild()

func _start_deployment() -> void:
	if selection_side == 0:
		if selected_ids.size() != 4: return
		selection_side = 1
		_rebuild()
		return
	if rival_ids.size() != 4: return
	placed = [-1, -1, -1, -1]
	rival_placed = [-1, -1, -1, -1]
	deploy_side = 0
	placing = 0
	mode = "deploy"
	feedback = "点一位角色，再点底部两行空格。"
	_rebuild()

func _back_selection() -> void:
	if selection_side == 1: selection_side = 0; _rebuild()
	else: return_requested.emit()

func _deployment_ui() -> void:
	_label(layer, "布阵 · 你的起点" if deploy_side == 0 else "布阵 · 对手的起点", Vector2(224, 60), 650, 56, 39)
	_label(layer, "你的四人队" if deploy_side == 0 else "老棋友的四人队", Vector2(1018, 175), 390, 45, 29)
	var roster: Array[String] = selected_ids if deploy_side == 0 else rival_ids
	var placement: Array = placed if deploy_side == 0 else rival_placed
	for i in 4:
		var item := Rules.definition(roster[i])
		var pos := "待布置" if int(placement[i]) < 0 else "第 %d 行 · 第 %d 列" % [int(int(placement[i]) / 7) + 1, int(placement[i]) % 7 + 1]
		var button := _button(layer, "%d  %s  ·  %s" % [i + 1, str(item.name), pos], Vector2(1018, 224 + i * 80), Vector2(410, 63), _choose_deployment.bind(i), 21)
		button.selected = placing == i
		button.refresh()
	_label(layer, feedback, Vector2(1018, 575), 411, 89, 21)
	var ready := _button(layer, "布置对手  →" if deploy_side == 0 else "开局  →", Vector2(1018, 692), Vector2(410, 58), _advance_deployment, 25)
	ready.disabled = placement.has(-1)
	_button(layer, "重排当前阵容", Vector2(1018, 768), Vector2(193, 47), _reset_placement, 18)
	_button(layer, "返回选人", Vector2(1232, 768), Vector2(196, 47), func(): mode = "select"; _rebuild(), 21)
	_label(layer, "上方红棕色是对手区域，下方蓝绿色是你的区域。", Vector2(235, 823), 775, 42, 20)

func _choose_deployment(index: int) -> void:
	placing = index
	_rebuild()

func _reset_placement() -> void:
	if deploy_side == 0: placed = [-1, -1, -1, -1]
	else: rival_placed = [-1, -1, -1, -1]
	placing = 0
	_rebuild()

func _advance_deployment() -> void:
	if deploy_side == 0:
		if placed.has(-1): return
		deploy_side = 1
		placing = 0
		feedback = "为对手布置顶部两行。"
		_rebuild()
	else: _begin_match()

func _begin_match() -> void:
	if placed.has(-1) or rival_placed.has(-1): return
	state = Rules.new_state(selected_ids, rival_ids, placed, rival_placed)
	selected_piece = -1
	mode = "play"
	feedback = "开局！先点己方棋子，合法落点会亮起。"
	_rebuild()
	if int(state.side) == 1: call_deferred("_ai_turn", generation)

func _match_ui() -> void:
	_label(layer, "相遇棋 · 7×7", Vector2(223, 60), 650, 55, 40)
	var score_label := _label(layer, "你  %d     :     %d  老棋友" % [int(state.scores[0]), int(state.scores[1])], Vector2(1016, 172), 418, 54, 31)
	if pulse_score:
		pulse_score = false
		score_label.pivot_offset = Vector2(115, 27)
		score_label.scale = Vector2.ONE * 1.1
		create_tween().tween_property(score_label, "scale", Vector2.ONE, 0.23)
	var turn_text := "对局结束" if mode == "end" else ("你的回合" if int(state.side) == 0 else "对手思考中")
	_label(layer, "%s  ·  第 %d / %d 回合%s" % [turn_text, int(state.turns) + 1, int(state.max_turns), " · 加赛" if bool(state.overtime) else ""], Vector2(1020, 233), 410, 46, 22)
	var piece := Rules.piece_by_id(state, selected_piece if selected_piece >= 0 else hover_inspect_id)
	if not piece.is_empty():
		var definition := Rules.definition(str(piece.id))
		_label(layer, str(definition.name), Vector2(1018, 307), 390, 42, 31)
		_label(layer, str(definition.rule), Vector2(1018, 358), 402, 98, 21)
		var flags := "状态：" + ("熟络  " if bool(piece.familiar) else "未熟络  " if str(piece.id) in ["naonao", "cici"] else "待行动")
		if str(piece.id) == "mingming": flags += "蓄力" if bool(piece.charged) else "未蓄力"
		if str(piece.id) == "xia_touming": flags += "正位" if bool(piece.upright) else "逆位"
		_label(layer, flags, Vector2(1018, 458), 390, 37, 20)
	else:
		_label(layer, "点击己方角色查看移动范围与能力。", Vector2(1018, 323), 400, 112, 22)
	var message := str(state.get("message", feedback))
	var message_label := _label(layer, message, Vector2(1018, 519), 397, 98, 20)
	message_label.clip_text = true
	if mode == "play":
		if selected_piece >= 0 and not piece.is_empty() and str(piece.id) == "mingming" and not bool(piece.charged) and int(state.pending_extra) < 0:
			_button(layer, "休息一回合 · 下次走更远", Vector2(1018, 634), Vector2(410, 50), _rest, 20)
		if int(state.pending_extra) >= 0 and int(state.side) == 0:
			_button(layer, "跳过额外一步", Vector2(1018, 634), Vector2(410, 50), _skip_extra, 22)
	else:
		var result := "你赢了！" if str(state.result) == "player" else "老棋友获胜"
		_label(layer, result, Vector2(1018, 624), 410, 56, 30)
	_button(layer, "再开一局", Vector2(1018, 708), Vector2(195, 50), _restart, 22)
	_button(layer, "返回棋类选择", Vector2(1230, 708), Vector2(200, 50), func(): return_requested.emit(), 20)
	_button(layer, "玩法说明", Vector2(1018, 775), Vector2(195, 48), _show_help, 20)
	_button(layer, "调试  F9", Vector2(1230, 775), Vector2(200, 48), _toggle_debug, 20)
	_label(layer, "浅色格可走 · 描边格可碰面 · 细线提示分段路径", Vector2(233, 825), 770, 44, 21)
	if debug_open: _debug_ui()

func _show_help() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "相遇棋 · 玩法说明"
	dialog.dialog_text = "双方各选四位角色，在各自的两行布阵。轮到你时，点己方角色，再点高亮的合法落点。碰到对方角色时，双方通常交换位置；BEETMAN 会推开对方。每组角色首次碰面得一分，先得四分获胜。三十回合后比较比分，同分则加赛到下一次新碰面。角色能力请点棋子查看。"
	dialog.size = Vector2i(740, 320)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.popup_centered()

func _toggle_debug() -> void:
	debug_open = not debug_open
	_rebuild()

func _debug_ui() -> void:
	var panel := UI.panel(layer, Rect2(770, 105, 742, 750))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_label(panel, "规则调试", Vector2(25, 20), 630, 45, 30)
	_label(panel, "目标分：%d    最大回合：%d    当前阵营：%s" % [int(state.target_score), int(state.max_turns), "玩家" if int(state.side) == 0 else "对手"], Vector2(25, 75), 675, 55, 21)
	_button(panel, "目标 -", Vector2(24, 145), Vector2(145, 44), func(): state.target_score = maxi(1, int(state.target_score) - 1); _rebuild(), 20)
	_button(panel, "目标 +", Vector2(179, 145), Vector2(145, 44), func(): state.target_score += 1; _rebuild(), 20)
	_button(panel, "回合 -", Vector2(334, 145), Vector2(145, 44), func(): state.max_turns = maxi(1, int(state.max_turns) - 1); _rebuild(), 20)
	_button(panel, "回合 +", Vector2(489, 145), Vector2(145, 44), func(): state.max_turns += 1; _rebuild(), 20)
	_button(panel, "切换阵营", Vector2(24, 211), Vector2(210, 44), func(): state.side = 1 - int(state.side); _rebuild(), 20)
	_button(panel, "清空碰面记录", Vector2(246, 211), Vector2(225, 44), func(): state.encounters.clear(); _rebuild(), 20)
	if selected_piece >= 0:
		_button(panel, "移动选中棋子", Vector2(24, 268), Vector2(210, 42), func(): debug_relocate = true; debug_open = false; _rebuild(), 18)
		_button(panel, "切换熟络", Vector2(245, 268), Vector2(145, 42), _debug_toggle.bind("familiar"), 18)
		_button(panel, "切换蓄力", Vector2(400, 268), Vector2(145, 42), _debug_toggle.bind("charged"), 18)
		_button(panel, "翻转状态", Vector2(555, 268), Vector2(140, 42), _debug_toggle.bind("upright"), 18)
	var lines := []
	if selected_piece >= 0:
		var p := Rules.piece_by_id(state, selected_piece)
		lines.append("选中：%s  格 %d  熟络 %s  蓄力 %s  正位 %s" % [str(p.id), int(p.cell), str(p.familiar), str(p.charged), str(p.upright)])
		for action in Rules.legal_actions(state, selected_piece):
			lines.append("%s  %d → %d  路径 %s" % [str(action.kind), int(action.from), int(action.to), str(action.path)])
	_label(panel, "\n".join(lines) if not lines.is_empty() else "先在棋盘上选择一枚当前阵营的棋子，以查看 BoardAction。", Vector2(26, 334), 673, 320, 17)
	_button(panel, "关闭", Vector2(520, 665), Vector2(175, 48), _toggle_debug, 21)

func _debug_toggle(flag: String) -> void:
	var piece := Rules.piece_by_id(state, selected_piece)
	if piece.is_empty(): return
	piece[flag] = not bool(piece.get(flag, false))
	_rebuild()

func _restart() -> void:
	generation += 1
	mode = "select"
	state = {}
	selected_ids.clear()
	rival_ids.clear()
	selection_side = 0
	selected_piece = -1
	hover_inspect_id = -1
	debug_open = false
	debug_relocate = false
	_rebuild()

func _rest() -> void:
	for action in Rules.legal_actions(state, selected_piece):
		if str(action.kind) == "rest": _apply_action(action); return

func _skip_extra() -> void:
	state = Rules.skip_extra(state)
	selected_piece = -1
	_rebuild()
	if int(state.side) == 1: call_deferred("_ai_turn", generation)

func _apply_action(action: Dictionary) -> void:
	var previous: Dictionary = state.duplicate(true)
	state = Rules.apply_action(state, action)
	print("NPC_CHESS_ACTION: %s %d → %d %s | score %s" % [str(Rules.definition(str(Rules.piece_by_id(state, int(action.instance_id)).id)).get("name", "")), int(action.from), int(action.to), str(action.kind), str(state.scores)])
	transitions.clear()
	for piece in state.pieces:
		var prior := Rules.piece_by_id(previous, int(piece.instance_id))
		if not prior.is_empty() and int(prior.cell) != int(piece.cell):
			transitions[int(piece.instance_id)] = {"from": int(prior.cell), "to": int(piece.cell)}
	animation_progress = 0.0 if not transitions.is_empty() else 1.0
	if animation_progress < 1.0:
		create_tween().tween_property(self, "animation_progress", 1.0, 0.24)
	if state.scores != previous.scores: pulse_score = true
	selected_piece = int(state.pending_extra) if int(state.pending_extra) >= 0 else -1
	hover_inspect_id = -1
	if str(state.result) != "":
		mode = "end"
		match_finished.emit(str(state.result))
	_rebuild()
	if mode == "play" and int(state.side) == 1: call_deferred("_ai_turn", generation)

func _ai_turn(expected_generation: int) -> void:
	if mode != "play" or expected_generation != generation or int(state.side) != 1: return
	await get_tree().create_timer(0.38).timeout
	if mode != "play" or expected_generation != generation or int(state.side) != 1: return
	var action := Rules.best_ai_action(state)
	if action.is_empty():
		if int(state.pending_extra) >= 0: state = Rules.skip_extra(state)
		else: state.side = 0
		_rebuild()
		return
	_apply_action(action)

func _gui_input(event: InputEvent) -> void:
	if debug_open or mode not in ["deploy", "play"]: return
	if event is InputEventMouseMotion:
		hovered_cell = _cell_at(event.position)
		if mode == "play" and selected_piece < 0:
			var hovered := Rules.occupant(state, hovered_cell) if hovered_cell >= 0 else {}
			var inspect_id := int(hovered.get("instance_id", -1))
			if inspect_id != hover_inspect_id:
				hover_inspect_id = inspect_id
				_rebuild()
		queue_redraw()
		return
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT: return
	var at := _cell_at(event.position)
	if at < 0: return
	if mode == "deploy":
		if (deploy_side == 0 and int(at / 7) < 5) or (deploy_side == 1 and int(at / 7) > 1):
			feedback = "请放在当前阵营的两行区域。"; _rebuild(); return
		var placement: Array = placed if deploy_side == 0 else rival_placed
		if placement.has(at): feedback = "这里已经有人了。"; _rebuild(); return
		placement[placing] = at
		for i in 4:
			if int(placement[i]) < 0: placing = i; break
		feedback = "已布置 %d / 4 位角色。" % (4 - placement.count(-1))
		_rebuild()
		return
	if debug_relocate:
		if selected_piece >= 0 and Rules.occupant(state, at).is_empty():
			var moving_piece := Rules.piece_by_id(state, selected_piece)
			moving_piece["cell"] = at
			debug_relocate = false
			state.message = "调试：棋子已移动到 %d。" % at
			_rebuild()
		return
	if mode != "play" or int(state.side) != 0: return
	var selected := Rules.piece_by_id(state, selected_piece)
	if not selected.is_empty():
		for action in Rules.legal_actions(state, selected_piece):
			if int(action.to) == at and str(action.kind) != "rest":
				_apply_action(action)
				return
	var piece := Rules.occupant(state, at)
	if not piece.is_empty() and int(piece.side) == 0 and (int(state.pending_extra) < 0 or int(piece.instance_id) == int(state.pending_extra)):
		selected_piece = int(piece.instance_id)
		_rebuild()

func _cell_at(pos: Vector2) -> int:
	if not BOARD.has_point(pos): return -1
	return Rules.cell(floori((pos.x - BOARD.position.x) / TILE), floori((pos.y - BOARD.position.y) / TILE))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9 and mode in ["play", "end"]:
		_toggle_debug()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if animation_progress < 1.0: queue_redraw()

func _draw() -> void:
	Art.tabletop(self)
	if mode == "select":
		draw_rect(Rect2(207, 165, 733, 592), Color("f7e8c9", 0.94))
		draw_rect(Rect2(207, 165, 733, 592), Art.INK, false, 3)
		return
	for y in 7:
		for x in 7:
			var rect := Rect2(BOARD.position + Vector2(x, y) * TILE, Vector2.ONE * TILE)
			var color := Color("f2e5cb") if (x + y) % 2 == 0 else Color("d9dfca")
			if mode == "deploy": color = Color("e0e9dc") if y >= 5 else Color("f1dccc") if y <= 1 else color
			draw_rect(rect, color)
			draw_rect(rect, Color(Art.INK, 0.18), false, 1)
	draw_rect(BOARD, Art.INK, false, 4)
	if mode == "deploy":
		for i in 4:
			if int(placed[i]) >= 0:
				_draw_token(str(selected_ids[i]), 0, int(placed[i]), deploy_side == 0 and i == placing, {})
		for i in 4:
			if int(rival_placed[i]) >= 0:
				_draw_token(str(rival_ids[i]), 1, int(rival_placed[i]), deploy_side == 1 and i == placing, {})
	if mode in ["play", "end"]:
		if debug_open:
			for y in 7:
				for x in 7:
					var font: Font = theme.default_font
					if font != null: draw_string(font, _tile_rect(Rules.cell(x, y)).position + Vector2(5, 16), "%d,%d" % [x, y], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Art.INK)
		var actions := Rules.legal_actions(state, selected_piece) if selected_piece >= 0 else []
		for action in actions:
			if str(action.kind) == "rest": continue
			var at := int(action.to)
			var tile := _tile_rect(at)
			draw_rect(tile.grow(-5), Color(TARGET, 0.44))
			if action.has("encounter_id"):
				draw_rect(tile.grow(-5), Color("ab684f"), false, 4)
			else: draw_circle(tile.get_center(), 8, Color("6b8a78"))
		if hovered_cell >= 0:
			for action in actions:
				if int(action.to) != hovered_cell or str(action.kind) == "rest": continue
				var previous := _tile_rect(int(action.from)).get_center()
				for step in action.path:
					var next := _tile_rect(int(step)).get_center()
					draw_line(previous, next, Color("a66048"), 4, true)
					previous = next
				break
		for piece in state.pieces:
			_draw_token(str(piece.id), int(piece.side), int(piece.cell), int(piece.instance_id) == selected_piece, piece)

func _tile_rect(at: int) -> Rect2:
	return Rect2(BOARD.position + Vector2(at % 7, int(at / 7)) * TILE, Vector2.ONE * TILE)

func _draw_token(id: String, side: int, at: int, selected: bool, piece: Dictionary) -> void:
	if at < 0: return
	var spec := Rules.definition(id)
	var center := _tile_rect(at).get_center()
	if not piece.is_empty() and animation_progress < 1.0 and transitions.has(int(piece.instance_id)):
		var travel: Dictionary = transitions[int(piece.instance_id)]
		center = _tile_rect(int(travel.from)).get_center().lerp(_tile_rect(int(travel.to)).get_center(), animation_progress)
		center.y += (1.0 if side == 0 else -1.0) * sin(animation_progress * PI) * 12.0
	var ring := PLAYER if side == 0 else RIVAL
	var radius := 35.0 if selected else 32.0
	if selected: draw_circle(center + Vector2(0, 3), 39, Color("e7b965"))
	draw_circle(center + Vector2(0, 3), radius + 3, Color(Art.INK, 0.25))
	draw_circle(center, radius, ring)
	draw_circle(center, radius - 5, PAPER)
	var path := str(spec.get("portrait", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		if not textures.has(path): textures[path] = load(path)
		var crop: Array = spec.get("crop", [0, 0, 100, 100])
		var source := Rect2(float(crop[0]), float(crop[1]), float(crop[2]), float(crop[3]))
		draw_texture_rect_region(textures[path], Rect2(center - Vector2.ONE * 24, Vector2.ONE * 48), source)
	else:
		var mark := str(spec.get("mark", "?"))
		var font: Font = theme.default_font
		if font != null:
			var width := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			draw_string(font, center + Vector2(-width * 0.5, 10), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Art.INK)
	draw_arc(center, radius, 0, TAU, 32, Art.INK, 2, true)
	if not piece.is_empty():
		if bool(piece.get("charged", false)): draw_circle(center + Vector2(24, -25), 9, Color("e9cf78"))
		if bool(piece.get("familiar", false)): draw_circle(center + Vector2(-24, -25), 8, Color("82ae91"))
		if id == "xia_touming" and not bool(piece.get("upright", true)): draw_rect(Rect2(center + Vector2(19, 19), Vector2(13, 13)), Color("9e6b87"))
