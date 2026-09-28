extends RefCounted
## Pure rules for the seven-by-seven encounter game. The UI only executes actions
## returned by legal_actions(), including deployment-independent extra steps.

const SIZE := 7
const ORTHO := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const DIAG := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]
const EIGHT := ORTHO + DIAG

static func definitions() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://extensions/elder_board/data/npc_chess.json"))
	return parsed.get("characters", []) if parsed is Dictionary else []

static func definition(id: String) -> Dictionary:
	for item in definitions():
		if str(item.get("id", "")) == id: return item
	return {}

static func cell(x: int, y: int) -> int:
	return y * SIZE + x if x >= 0 and x < SIZE and y >= 0 and y < SIZE else -1

static func point(index: int) -> Vector2i:
	return Vector2i(index % SIZE, int(index / SIZE))

static func offset(index: int, direction: Vector2i, steps: int = 1) -> int:
	if index < 0: return -1
	var at := point(index) + direction * steps
	return cell(at.x, at.y)

static func occupant(state: Dictionary, at: int) -> Dictionary:
	for piece in state.get("pieces", []):
		if int(piece.get("cell", -1)) == at: return piece
	return {}

static func piece_by_id(state: Dictionary, instance_id: int) -> Dictionary:
	for piece in state.get("pieces", []):
		if int(piece.get("instance_id", -1)) == instance_id: return piece
	return {}

static func new_state(player_ids: Array, rival_ids: Array, player_cells: Array, rival_cells: Array, first_side: int = -1) -> Dictionary:
	var pieces := []
	for side in 2:
		var ids: Array = player_ids if side == 0 else rival_ids
		var cells: Array = player_cells if side == 0 else rival_cells
		for i in 4:
			pieces.append({"instance_id": side * 4 + i, "id": str(ids[i]), "side": side,
				"cell": int(cells[i]), "familiar": false, "charged": false, "upright": true})
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://extensions/elder_board/data/npc_chess.json"))
	return {"pieces": pieces, "side": first_side if first_side in [0, 1] else randi() % 2,
		"scores": [0, 0], "encounters": {}, "last_vacated": -1,
		"turns": 0, "target_score": int(parsed.get("target_score", 4)),
		"max_turns": int(parsed.get("max_turns", 30)), "overtime": false,
		"pending_extra": -1, "result": "", "message": "请选择己方角色。"}

static func _new_action(piece: Dictionary, destination: int, path: Array, kind: String, direction: Vector2i, extra := false) -> Dictionary:
	return {"instance_id": int(piece.instance_id), "from": int(piece.cell), "to": destination,
		"path": path, "kind": kind, "direction": direction, "extra": extra}

static func _add(state: Dictionary, piece: Dictionary, destination: int, path: Array, kind: String, direction: Vector2i, actions: Array, jump := false, extra := false) -> void:
	if destination < 0 or int(piece.cell) == destination: return
	if not jump:
		for i in range(path.size() - 1):
			if not occupant(state, int(path[i])).is_empty(): return
	var target := occupant(state, destination)
	if not target.is_empty() and int(target.side) == int(piece.side): return
	if str(piece.id) == "beetman" and not target.is_empty():
		var pushed := offset(destination, direction)
		if pushed < 0 or not occupant(state, pushed).is_empty(): return
	var action := _new_action(piece, destination, path, kind, direction, extra)
	if not target.is_empty(): action["encounter_id"] = int(target.instance_id)
	for existing in actions:
		if existing == action: return
	actions.append(action)

static func _ray(state: Dictionary, piece: Dictionary, directions: Array, distances: Array, actions: Array, jump := false) -> void:
	for direction in directions:
		for distance in distances:
			var path := []
			for step in range(1, int(distance) + 1):
				var at := offset(int(piece.cell), direction, step)
				if at < 0: break
				path.append(at)
			if path.size() == int(distance):
				_add(state, piece, int(path[-1]), path, "move", direction, actions, jump)

static func _adjacent_other(state: Dictionary, at: int, instance_id: int) -> int:
	var count := 0
	for direction in EIGHT:
		var neighbor := occupant(state, offset(at, direction))
		if not neighbor.is_empty() and int(neighbor.instance_id) != instance_id: count += 1
	return count

static func legal_actions(state: Dictionary, instance_id: int) -> Array:
	var actions := []
	if str(state.get("result", "")) != "": return actions
	var piece := piece_by_id(state, instance_id)
	if piece.is_empty() or int(piece.side) != int(state.side): return actions
	var pending := int(state.get("pending_extra", -1))
	if pending >= 0:
		if pending != instance_id: return actions
		var directions: Array = DIAG if str(piece.id) == "yu_xingqing" else EIGHT
		for direction in directions:
			var at := offset(int(piece.cell), direction)
			_add(state, piece, at, [at], "extra", direction, actions, false, true)
		return actions
	var id := str(piece.id)
	var start := int(piece.cell)
	var spec := definition(id)
	var steps := int(spec.get("steps", 1))
	match id:
		"mossner":
			_ray(state, piece, ORTHO, [steps], actions)
			for direction in ORTHO:
				var mid := offset(start, direction)
				var second := offset(start, direction, 2)
				if second >= 0 and ( _adjacent_other(state, mid, instance_id) > 0 or _adjacent_other(state, second, instance_id) > 0):
					_add(state, piece, second, [mid, second], "early_stop", direction, actions)
		"xanni":
			for first in ORTHO:
				var mid := offset(start, first)
				if mid < 0 or not occupant(state, mid).is_empty(): continue
				for second in DIAG:
					var end := offset(mid, second)
					_add(state, piece, end, [mid, end], "two_beat", second, actions)
		"chenyuan": _ray(state, piece, EIGHT, [steps], actions, true)
		"maya":
			for first in ORTHO:
				for second in ORTHO:
					if first.x * second.x + first.y * second.y != 0: continue
					for total in [steps, steps + 1]:
						for first_steps in range(1, total):
							var turn := offset(start, first, first_steps)
							if turn < 0 or (total > steps and _adjacent_other(state, turn, instance_id) == 0): continue
							var path := []
							for i in range(1, first_steps + 1): path.append(offset(start, first, i))
							for i in range(1, total - first_steps + 1): path.append(offset(turn, second, i))
							if not path.has(-1): _add(state, piece, int(path[-1]), path, "turn", second, actions)
		"mingming":
			var reach := 3 if bool(piece.charged) else steps
			var distances := []
			for i in range(1, reach + 1): distances.append(i)
			_ray(state, piece, EIGHT, distances, actions)
			if not bool(piece.charged): actions.append(_new_action(piece, start, [], "rest", Vector2i.ZERO))
		"zhou_xiaoliu":
			_ray(state, piece, ORTHO, [steps], actions)
			var vacated := int(state.get("last_vacated", -1))
			if vacated >= 0 and point(start).distance_to(point(vacated)) <= float(steps) and occupant(state, vacated).is_empty():
				_add(state, piece, vacated, [vacated], "follow", point(vacated) - point(start), actions)
		"beetman": _ray(state, piece, ORTHO, [1, steps], actions)
		"xia_touming": _ray(state, piece, ORTHO if bool(piece.upright) else DIAG, [steps], actions)
		"yu_xingqing":
			for dx in [-2, -1, 1, 2]:
				for dy in [-2, -1, 1, 2]:
					if absi(dx) + absi(dy) != 3: continue
					var at := cell(point(start).x + dx, point(start).y + dy)
					_add(state, piece, at, [at], "jump", Vector2i(signi(dx), signi(dy)), actions, true)
		"shi_yongqi": _ray(state, piece, EIGHT, [steps], actions)
		"naonao":
			_ray(state, piece, EIGHT if bool(piece.familiar) else ORTHO, [1, 2] if bool(piece.familiar) else [1], actions)
		"cici":
			if not bool(piece.familiar): _ray(state, piece, ORTHO, [1, steps], actions)
			else:
				for first in ORTHO:
					var mid := offset(start, first)
					if mid < 0 or not occupant(state, mid).is_empty(): continue
					for second in ORTHO:
						if first.x * second.x + first.y * second.y != 0: continue
						var end := offset(mid, second)
						_add(state, piece, end, [mid, end], "turn", second, actions)
	return actions

static func apply_action(state: Dictionary, action: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var id := int(action.get("instance_id", -1))
	if not legal_actions(next, id).has(action): return next
	var piece := piece_by_id(next, id)
	if str(action.kind) == "rest":
		piece["charged"] = true
		next["message"] = "%s 休息一回合，下次移动会更远。" % definition(str(piece.id)).get("name", "角色")
		_end_turn(next, false)
		return next
	var origin := int(piece.cell)
	var target := occupant(next, int(action.to))
	var new_pair := false
	var active_side := int(piece.side)
	if not target.is_empty():
		var a := mini(id, int(target.instance_id))
		var b := maxi(id, int(target.instance_id))
		var key := "%d:%d" % [a, b]
		new_pair = not next.encounters.has(key)
		if new_pair:
			next.encounters[key] = true
			next.scores[active_side] += 1
			for participant in [piece, target]:
				if str(participant.id) in ["naonao", "cici"]: participant["familiar"] = true
		if str(piece.id) == "beetman": target["cell"] = offset(int(action.to), action.direction)
		else: target["cell"] = origin
		next["message"] = "%s 与 %s %s。%s" % [definition(str(piece.id)).get("name", ""), definition(str(target.id)).get("name", ""),
			"第一次碰面" if new_pair else "再次碰面", "+1 分" if new_pair else "已经认识，不再计分"]
	else:
		next["message"] = "%s 走到了新位置。" % definition(str(piece.id)).get("name", "角色")
	piece["cell"] = int(action.to)
	next["last_vacated"] = origin
	if str(piece.id) == "mingming": piece["charged"] = false
	if str(piece.id) == "xia_touming": piece["upright"] = not bool(piece.upright)
	if str(piece.id) == "xanni" and new_pair:
		var tail := offset(int(piece.cell), action.direction)
		if tail >= 0 and occupant(next, tail).is_empty():
			next["last_vacated"] = int(piece.cell)
			piece["cell"] = tail
			next["message"] += " Xanni 顺势再走一格。"
	if str(action.kind) != "extra" and str(piece.id) == "yu_xingqing" and _adjacent_other(next, int(piece.cell), id) == 0:
		next["pending_extra"] = id
	if str(action.kind) != "extra" and str(piece.id) == "shi_yongqi" and _adjacent_other(next, int(piece.cell), id) >= 2:
		next["pending_extra"] = id
	if int(next.pending_extra) >= 0 and not legal_actions(next, id).is_empty():
		next["message"] += " 可以选择额外一步，或跳过。"
	else:
		next["pending_extra"] = -1
		_end_turn(next, new_pair)
	return next

static func skip_extra(state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if int(next.get("pending_extra", -1)) < 0: return next
	next["pending_extra"] = -1
	next["message"] = "跳过额外一步。"
	_end_turn(next, false)
	return next

static func _end_turn(state: Dictionary, new_pair: bool) -> void:
	state["turns"] = int(state.turns) + 1
	var side := int(state.side)
	if bool(state.overtime) and new_pair:
		state["result"] = "player" if side == 0 else "rival"
	elif int(state.scores[side]) >= int(state.target_score):
		state["result"] = "player" if side == 0 else "rival"
	elif int(state.turns) >= int(state.max_turns) and not bool(state.overtime):
		if int(state.scores[0]) == int(state.scores[1]):
			state["overtime"] = true
			state["message"] += " 比分相同，进入加赛；下一次新碰面获胜。"
		else:
			state["result"] = "player" if int(state.scores[0]) > int(state.scores[1]) else "rival"
	if str(state.result) != "":
		state["message"] += " 对局结束。"
		return
	state["side"] = 1 - side
	var any_action := false
	for piece in state.pieces:
		if int(piece.side) == int(state.side) and not legal_actions(state, int(piece.instance_id)).is_empty(): any_action = true
	if not any_action:
		state["side"] = side
		state["message"] += " 对方无合法行动，轮到你继续。"

static func best_ai_action(state: Dictionary) -> Dictionary:
	var actions := []
	for piece in state.pieces:
		if int(piece.side) == int(state.side): actions.append_array(legal_actions(state, int(piece.instance_id)))
	if actions.is_empty(): return {}
	var best: Dictionary = actions[0]
	var best_value := -9999.0
	for action in actions:
		var value := 0.0
		if str(action.kind) == "rest": value -= 8.0
		if action.has("encounter_id"):
			var a := mini(int(action.instance_id), int(action.encounter_id))
			var b := maxi(int(action.instance_id), int(action.encounter_id))
			value += 40.0 if not state.encounters.has("%d:%d" % [a, b]) else 4.0
		var nearest := 20.0
		for other in state.pieces:
			if int(other.side) != int(state.side):
				nearest = minf(nearest, float(point(int(action.to)).distance_to(point(int(other.cell)))))
		value += (10.0 - nearest) * 0.5
		value += float((int(action.instance_id) * 13 + int(action.to) * 7 + int(state.turns) * 3) % 11) * 0.001
		if value > best_value:
			best_value = value
			best = action
	return best
