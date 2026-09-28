extends SceneTree

const Rules = preload("res://extensions/elder_board/scripts/npc_rules.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("NPC_CHESS: " + description)

func baseline(id: String) -> Dictionary:
	return Rules.new_state([id, "mossner", "mingming", "xia_touming"],
		["naonao", "xanni", "beetman", "cici"], [24, 42, 46, 48], [0, 2, 4, 6], 0)

func run() -> void:
	check(Rules.definitions().size() == 12, "twelve definitions load")
	for spec in Rules.definitions():
		var state := baseline(str(spec.id))
		var actions := Rules.legal_actions(state, 0)
		check(not actions.is_empty(), "%s has legal actions" % spec.id)
		for action in actions:
			var next := Rules.apply_action(state, action)
			var occupied := {}
			for piece in next.pieces:
				check(int(piece.cell) >= 0 and int(piece.cell) < 49, "%s stays on board" % spec.id)
				check(not occupied.has(int(piece.cell)), "%s cannot overlap" % spec.id)
				occupied[int(piece.cell)] = true
			check(state.turns == 0 and state.scores == [0, 0], "simulation does not mutate source")
	var encounter := baseline("mossner")
	encounter.pieces[0].cell = 24
	encounter.pieces[4].cell = 27
	var first: Dictionary = {}
	for action in Rules.legal_actions(encounter, 0):
		if int(action.to) == 27: first = action; break
	check(not first.is_empty(), "first encounter is legal")
	if not first.is_empty():
		var scored := Rules.apply_action(encounter, first)
		check(scored.scores[0] == 1, "first encounter scores")
		check(scored.encounters.size() == 1, "encounter pair recorded")
		check(int(scored.pieces[0].cell) == 27 and int(scored.pieces[4].cell) == 24, "normal encounter swaps")
		var again := scored.duplicate(true)
		again.side = 0
		again.pieces[0].cell = 24
		again.pieces[4].cell = 27
		var repeat_action: Dictionary = {}
		for action in Rules.legal_actions(again, 0):
			if int(action.to) == 27: repeat_action = action; break
		if not repeat_action.is_empty():
			var repeated := Rules.apply_action(again, repeat_action)
			check(repeated.scores[0] == 1, "repeat encounter never scores")
	var push := baseline("beetman")
	push.pieces[0].cell = 24
	push.pieces[4].cell = 25
	var push_action: Dictionary = {}
	for action in Rules.legal_actions(push, 0):
		if int(action.to) == 25: push_action = action; break
	check(not push_action.is_empty(), "clear push is legal")
	if not push_action.is_empty():
		var pushed := Rules.apply_action(push, push_action)
		check(int(pushed.pieces[0].cell) == 25 and int(pushed.pieces[4].cell) == 26, "BEETMAN pushes without swapping")
	push.pieces[0].cell = 45
	push.pieces[4].cell = 46
	check(Rules.legal_actions(push, 0).all(func(a: Dictionary) -> bool: return int(a.to) != 46), "push off board is illegal")
	var xanni := baseline("xanni")
	xanni.pieces[4].cell = 11
	var xanni_action: Dictionary = {}
	for action in Rules.legal_actions(xanni, 0):
		if int(action.to) == 11: xanni_action = action; break
	check(not xanni_action.is_empty() and xanni_action.path.size() == 2, "Xanni uses two segments")
	if not xanni_action.is_empty():
		var xanni_after := Rules.apply_action(xanni, xanni_action)
		check(xanni_after.scores[0] == 1 and int(xanni_after.pieces[0].cell) == 5, "new encounter grants Xanni an empty tail step")
	var jumper := baseline("chenyuan")
	jumper.pieces[1].cell = 25
	check(Rules.legal_actions(jumper, 0).any(func(a: Dictionary) -> bool: return int(a.to) == 26), "Chenyuan jumps an occupied midpoint")
	var maya := baseline("maya")
	maya.pieces[1].cell = 18
	maya.pieces[2].cell = 43
	maya.pieces[3].cell = 47
	check(Rules.legal_actions(maya, 0).any(func(a: Dictionary) -> bool: return a.path.size() == 4), "Maya extends a turn when somebody is near the corner")
	var rest := baseline("mingming")
	var rest_action: Dictionary = {}
	for action in Rules.legal_actions(rest, 0):
		if str(action.kind) == "rest": rest_action = action
	var charged := Rules.apply_action(rest, rest_action)
	check(bool(charged.pieces[0].charged), "rest charges Mingming")
	charged.side = 0
	var charged_move: Dictionary = {}
	for action in Rules.legal_actions(charged, 0):
		if str(action.kind) == "move": charged_move = action; break
	check(not charged_move.is_empty(), "charged move is available")
	if not charged_move.is_empty(): check(not Rules.apply_action(charged, charged_move).pieces[0].charged, "charge clears after move")
	var flip := baseline("xia_touming")
	var flip_actions := Rules.legal_actions(flip, 0)
	check(not flip_actions.is_empty(), "upright move exists")
	if not flip_actions.is_empty(): check(not Rules.apply_action(flip, flip_actions[0]).pieces[0].upright, "Xia flips once")
	var lonely := baseline("yu_xingqing")
	lonely.pieces[1].cell = 42
	lonely.pieces[2].cell = 44
	lonely.pieces[3].cell = 46
	var leap: Dictionary = {}
	for action in Rules.legal_actions(lonely, 0):
		if int(action.to) == 33: leap = action; break
	check(not leap.is_empty(), "Yuxingqing can jump in an L")
	if not leap.is_empty():
		var leapt := Rules.apply_action(lonely, leap)
		check(int(leapt.pending_extra) == 0, "isolated landing offers a diagonal extra step")
		check(int(Rules.skip_extra(leapt).side) == 1, "extra step can be skipped")
	var crowded := baseline("shi_yongqi")
	crowded.pieces[1].cell = 18
	crowded.pieces[2].cell = 32
	var crowd_move: Dictionary = {}
	for action in Rules.legal_actions(crowded, 0):
		if int(action.to) == 25: crowd_move = action; break
	if not crowd_move.is_empty(): check(int(Rules.apply_action(crowded, crowd_move).pending_extra) == 0, "crowd landing offers Shi an extra step")
	var familiar := baseline("naonao")
	familiar.pieces[4].cell = 17
	var meeting: Dictionary = {}
	for action in Rules.legal_actions(familiar, 0):
		if int(action.to) == 17: meeting = action; break
	if not meeting.is_empty(): check(bool(Rules.apply_action(familiar, meeting).pieces[0].familiar), "Naonao becomes familiar after a new encounter")
	var cici := baseline("cici")
	cici.pieces[4].cell = 17
	var cici_meeting: Dictionary = {}
	for action in Rules.legal_actions(cici, 0):
		if int(action.to) == 17: cici_meeting = action; break
	if not cici_meeting.is_empty():
		var acquainted := Rules.apply_action(cici, cici_meeting)
		acquainted.side = 0
		check(bool(acquainted.pieces[0].familiar) and Rules.legal_actions(acquainted, 0).any(func(a: Dictionary) -> bool: return str(a.kind) == "turn"), "cici unlocks the two-step turn")
	var invalid := baseline("mossner")
	var invalid_after := Rules.apply_action(invalid, {"instance_id": 0, "from": 24, "to": 0, "path": [0], "kind": "move", "direction": Vector2i.UP, "extra": false})
	check(invalid_after == invalid, "illegal action cannot change match state")
	var overtime := baseline("mossner")
	overtime.max_turns = 1
	overtime.scores = [1, 1]
	var safe: Dictionary = Rules.legal_actions(overtime, 0)[0]
	var tied := Rules.apply_action(overtime, safe)
	check(bool(tied.overtime) and str(tied.result) == "", "tie enters overtime")
	var view = load("res://extensions/elder_board/scripts/npc_match.gd").new()
	root.add_child(view)
	await process_frame
	check(view.mode == "select", "selection screen opens")
	view._beginner_team()
	view._start_deployment()
	check(view.mode == "select" and view.selection_side == 1, "player roster advances to rival selection")
	view._beginner_team()
	view._start_deployment()
	check(view.mode == "deploy", "both rosters advance to formation")
	for i in 4:
		view.placing = i
		view.placed[i] = 35 + i
	view._advance_deployment()
	check(view.deploy_side == 1, "player formation advances to rival formation")
	for i in 4: view.rival_placed[i] = i * 2
	view._begin_match()
	check(view.mode == "play" and view.state.pieces.size() == 8, "formation advances to a playable match")
	var simulation := Rules.new_state(["mossner", "chenyuan", "beetman", "naonao"],
		["xanni", "maya", "xia_touming", "cici"], [35, 37, 39, 41], [0, 2, 4, 6], 0)
	for i in 90:
		if str(simulation.result) != "": break
		var ai_action := Rules.best_ai_action(simulation)
		if ai_action.is_empty():
			if int(simulation.pending_extra) >= 0: simulation = Rules.skip_extra(simulation)
			else: break
		else: simulation = Rules.apply_action(simulation, ai_action)
	check(str(simulation.result) != "", "automated full match reaches a result")
	print("NPC_CHESS_MATCH: %d turns / score %s / result %s" % [int(simulation.turns), str(simulation.scores), str(simulation.result)])
	print("NPC_CHESS: %d checks / %d failures" % [checks, failures])
	quit(1 if failures else 0)
