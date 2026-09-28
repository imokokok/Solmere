extends Node

signal module_unlocked(role: String, module_id: String)
signal module_started(role: String, module_id: String)
signal module_completed(role: String, module_id: String, outcome: Dictionary)

const MODULES_PATH := "res://data/gameplay/modules.json"
const PROTOTYPES_PATH := "res://data/gameplay/module_prototypes.json"
const COOKING = preload("res://scripts/core/cooking_mechanics.gd")

var modules: Dictionary = {}
var prototypes: Dictionary = {}


func _ready() -> void:
	load_module_data(MODULES_PATH)
	load_prototype_data(PROTOTYPES_PATH)


func load_module_data(path: String) -> void:
	modules.clear()
	if not FileAccess.file_exists(path):
		push_warning("Gameplay module data not found: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid gameplay module data: %s" % path)
		return
	for module in parsed.get("modules", []):
		var module_id := str(module.get("id", ""))
		if not module_id.is_empty():
			modules[module_id] = module


func load_prototype_data(path: String) -> void:
	prototypes.clear()
	if not FileAccess.file_exists(path):
		push_warning("Gameplay prototype data not found: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid gameplay prototype data: %s" % path)
		return
	for prototype in parsed.get("prototypes", []):
		var module_id := str(prototype.get("module_id", ""))
		if not module_id.is_empty():
			prototypes[module_id] = prototype


func ensure_state(module_id: String) -> Dictionary:
	if not modules.has(module_id):
		return {}
	if not GameState.module_states.has(module_id):
		var metadata: Dictionary = modules[module_id]
		GameState.module_states[module_id] = {
			"unlocked": bool(metadata.get("initially_unlocked", false)),
			"plays": 0,
			"completed": false,
			"outcomes": [],
			"last_day": 0,
		}
	return GameState.module_states[module_id]


func unlock(module_id: String) -> bool:
	var state := ensure_state(module_id)
	if state.is_empty():
		return false
	if not bool(state.get("unlocked", false)):
		state["unlocked"] = true
		GameState.module_states[module_id] = state
		GameState.commit_active_role_state()
		module_unlocked.emit(GameState.current_role, module_id)
		GameState.state_changed.emit()
	return true


func start(module_id: String) -> bool:
	var state := ensure_state(module_id)
	if not ChapterSystem.module_available(module_id) or state.is_empty() or not bool(state.get("unlocked", false)):
		return false
	state["plays"] = int(state.get("plays", 0)) + 1
	state["last_day"] = GameState.current_day
	GameState.module_states[module_id] = state
	GameState.commit_active_role_state()
	module_started.emit(GameState.current_role, module_id)
	return true


func complete(module_id: String, outcome: Dictionary = {}) -> bool:
	if pending_module_id()!=module_id: return false
	var state := ensure_state(module_id)
	if not ChapterSystem.module_available(module_id) or state.is_empty() or not bool(state.get("unlocked", false)):
		return false
	state["completed"] = true
	state["last_day"] = GameState.current_day
	var outcomes: Array = state.get("outcomes", [])
	var stored := outcome.duplicate(true)
	stored["context"] = session_context()
	stored["craft_perspective"] = ChapterSystem.module_perspective(module_id)
	if str(stored.context.get("current_character",""))!=GameState.current_role: return false
	stored["day"] = int(stored.get("day", GameState.current_day))
	outcomes.append(stored)
	state["outcomes"] = outcomes
	GameState.module_states[module_id] = state
	GameState.commit_active_role_state()
	module_completed.emit(GameState.current_role, module_id, stored)
	ChapterSystem.record_main_result(module_id,stored)
	GameState.state_changed.emit()
	return true


func is_unlocked(module_id: String) -> bool:
	return ChapterSystem.module_available(module_id) and bool(ensure_state(module_id).get("unlocked", false))


func is_known(module_id: String) -> bool:
	# Discovery permits planning, without starting a session or granting a result.
	if not modules.has(module_id) or not ChapterSystem.module_available(module_id): return false
	if is_unlocked(module_id): return true
	for fact: Dictionary in GameState.shared_state.get("knowledge_"+GameState.current_role,[]):
		if str(fact.get("predicate",""))=="lead" and (str(fact.get("module",""))==module_id or str(fact.get("id",""))=="invite_"+module_id): return true
	# Invitations remain known on later days, including saves made before discovery
	# was used by the planner. Another role's invitations stay private.
	var accepted: Dictionary=GameState.shared_state.get("accepted_invitations",{})
	for key in accepted:
		if str(key).begins_with(GameState.current_role+"_") and str(accepted[key].get("module",""))==module_id: return true
	return false


func state_for(module_id: String) -> Dictionary:
	return ensure_state(module_id).duplicate(true)


func latest_outcome(module_id: String) -> Dictionary:
	var state: Dictionary = GameState.module_states.get(module_id, {})
	var outcomes: Array = state.get("outcomes", [])
	if outcomes.is_empty():
		return {}
	return (outcomes[-1] as Dictionary).duplicate(true)


func begin_session(module_id: String, source_event_id := "", rollback_snapshot: Dictionary = {}) -> bool:
	if not ChapterSystem.module_available(module_id) or not GameState.shared_state.get("pending_module",{}).is_empty(): return false
	if not bool(entry_check(module_id,60 if source_event_id.begins_with("studio:") else -1).ok): return false
	if module_id == "contemplation" and GameState.current_minute < WorldGraph.LOOKOUT_OPEN:
		return false
	if not unlock(module_id) or not start(module_id):
		return false
	GameState.shared_state["pending_module"] = {
		"module_id": module_id,
		"role": GameState.current_role,
		"context": {"current_character":GameState.current_role,"day":GameState.current_day,"location":GameState.current_location},
		"day": GameState.current_day,
		"start_minute": GameState.current_minute,
		"source_event_id": source_event_id,
		"rollback_snapshot": rollback_snapshot.duplicate(true),
	}
	GameState.commit_active_role_state()
	return true


func pending_module_id() -> String:
	var pending: Dictionary = GameState.shared_state.get("pending_module", {})
	if str(pending.get("role", "")) != GameState.current_role or int(pending.get("day",0)) != GameState.current_day:
		return ""
	return str(pending.get("module_id", ""))


func session_context() -> Dictionary:
	if pending_module_id().is_empty(): return {}
	return GameState.shared_state.pending_module.get("context",{}).duplicate(true)

func cancel_session() -> void:
	var pending: Dictionary = GameState.shared_state.get("pending_module", {})
	var rollback_snapshot: Dictionary = pending.get("rollback_snapshot", {})
	if not rollback_snapshot.is_empty():
		GameState.load_save_data(rollback_snapshot)
		return
	GameState.shared_state.erase("pending_module")
	GameState.commit_active_role_state()


func prototype_for(module_id: String) -> Dictionary:
	return prototypes.get(module_id, {}).duplicate(true)


func choice_interaction_check(module_id: String, choice_id: String, interaction_record: Dictionary) -> Dictionary:
	if not prototypes.has(module_id):
		return {"ok": false, "message": "找不到这个玩法。"}
	var prototype: Dictionary = prototypes[module_id]
	var selected: Dictionary = {}
	for choice in prototype.get("choices", []):
		if str(choice.get("id", "")) == choice_id:
			selected = choice
			break
	if selected.is_empty():
		return {"ok": false, "message": "找不到这个玩法选择。"}
	var selected_tokens: Array = interaction_record.get("selected_tokens", [])
	var interaction: Dictionary = prototype.get("interaction", {})
	var minimum := int(interaction.get("min_select", 0))
	var maximum := int(interaction.get("max_select", minimum))
	if selected_tokens.size() < minimum:
		return {"ok": false, "message": "还需要选择%d项。" % (minimum - selected_tokens.size())}
	if selected_tokens.size() > maximum:
		return {"ok": false, "message": "选择数量超过了当前上限。"}
	var known_tokens: Array[String] = []
	for token in interaction.get("tokens", []):
		known_tokens.append(str(token.get("id", "")))
	var seen_tokens: Array[String] = []
	for token_id_value in selected_tokens:
		var token_id := str(token_id_value)
		if not known_tokens.has(token_id) or seen_tokens.has(token_id):
			return {"ok": false, "message": "操作记录里有无效或重复的项目。"}
		seen_tokens.append(token_id)
	for required_id_value in selected.get("required_tokens", []):
		var required_id := str(required_id_value)
		if not selected_tokens.has(required_id):
			return {"ok": false, "message": str(selected.get("constraint_note", "这个结果还缺少必要项目。"))}
	for forbidden_id_value in selected.get("forbidden_tokens", []):
		var forbidden_id := str(forbidden_id_value)
		if selected_tokens.has(forbidden_id):
			return {"ok": false, "message": str(selected.get("constraint_note", "当前选择包含不能用于这个结果的项目。"))}
	if module_id=="cooking":
		var mechanic: Dictionary=interaction_record.get("mechanic",{})
		if mechanic.has("phase") and not str(mechanic.get("phase","")).is_empty() and str(mechanic.get("phase","")) not in ["plate","serve"]:
			return {"ok":false,"message":"先完成备料、下锅、翻拌、尝味和装盘，再决定怎样出餐。"}
	return {"ok": true, "message": ""}


func complete_choice(choice_id: String, interaction_record: Dictionary = {}) -> Dictionary:
	var module_id := pending_module_id()
	if module_id.is_empty() or not prototypes.has(module_id):
		return {"ok": false, "message": "没有正在进行的玩法。"}
	var prototype: Dictionary = prototypes[module_id]
	var selected: Dictionary = {}
	for choice in prototype.get("choices", []):
		if str(choice.get("id", "")) == choice_id:
			selected = choice
			break
	if selected.is_empty():
		return {"ok": false, "message": "找不到这个玩法选择。"}
	if interaction_record.get("context",{}) != session_context(): return {"ok":false,"message":"这次操作不属于当前角色的活动。"}
	var stored_interaction := interaction_record.duplicate(true)
	if not stored_interaction.has("selected_labels"):
		var selected_labels: Array[String] = []
		for token_id_value in stored_interaction.get("selected_tokens", []):
			selected_labels.append(_prototype_token_label(prototype, str(token_id_value)))
		stored_interaction["selected_labels"] = selected_labels
	var interaction_check := choice_interaction_check(module_id, choice_id, stored_interaction)
	if not bool(interaction_check.get("ok", false)):
		return interaction_check
	var cost: Dictionary = selected.get("cost", {})
	if module_id == "cooking":
		var stock_check := EconomySystem.cooking_check(stored_interaction.get("selected_tokens", []))
		if not bool(stock_check.ok): return stock_check
		cost = EconomySystem.cooking_cost(cost)
	var payment: Dictionary = EventSystem.can_pay_cost_data(cost)
	if not bool(payment.get("ok", false)):
		return {"ok": false, "message": str(payment.get("reason", "当前资源不足。"))}
	var amount := int(cost.get("money", 0))
	var minutes := int(cost.get("minutes", 0))
	if amount > 0:
		GameState.spend_money(amount, "完成%s" % str(prototypes.get(module_id, {}).get("title", module_id)))
	if minutes > 0:
		GameState.use_free_time(minutes)
	var results: Dictionary = selected.get("results", {}).duplicate(true)
	var role_results: Dictionary = selected.get("results_by_role", {}).get(GameState.current_role, {}).duplicate(true)
	var work_payment := 0
	if module_id in ["ghostwriting", "sound_sampling"]:
		work_payment = int(results.get("money",0))
		results.erase("money")
	if module_id == "cooking":
		results.erase("money")
		role_results.erase("money")
		# A meal records an encounter; only a later people-puzzle review signs it.
		results.erase("confirmations")
		role_results.erase("confirmations")
		for artifact in results.get("artifacts",[]):
			if str(artifact.get("collection",""))!="recipes": continue
			artifact.data.merge({"id":"recipe_"+Crypto.new().generate_random_bytes(12).hex_encode(),"format":"solmere.recipe.v1","author":GameState.current_role,"ingredients":stored_interaction.get("selected_tokens",[]).duplicate(),"heat":float(stored_interaction.get("mechanic",{}).get("heat",0.58)),"notes":COOKING.recipe_notes(stored_interaction),"strokes":[]},true)
	EventSystem.apply_results("module_%s_%s" % [module_id, choice_id], results)
	EventSystem.apply_results("module_%s_%s" % [module_id, choice_id], role_results)
	var outcome := {
		"choice_id": choice_id,
		"label": str(selected.get("label", choice_id)),
		"source_event_id": str(GameState.shared_state.get("pending_module", {}).get("source_event_id", "")),
		"interaction": stored_interaction,
	}
	if module_id=="cooking":
		outcome["craft_grade"]=stored_interaction.get("mechanic",{}).get("grade",{}).duplicate(true)
		outcome["service_response"]=COOKING.service_response(stored_interaction)
	complete(module_id, outcome)
	if module_id == "cooking":
		PeoplePuzzleSystem.record_cooking_experience(stored_interaction,str(outcome.service_response))
		EconomySystem.finish_cooking(outcome, stored_interaction.get("selected_tokens", []))
	if work_payment > 0:
		var issuer := "handcraft_shop" if module_id == "ghostwriting" else "record_store"
		GameState.earn_money(work_payment,"书信委托报酬" if module_id == "ghostwriting" else "采样整理报酬",{"work_minutes":minutes,"kind":"income","issuer":issuer,"source":"module_"+module_id})
		var outcome_index := maxi(0,ensure_state(module_id).outcomes.size()-1)
		ResidencySystem.accept_contribution("module_%s_%d" % [module_id,outcome_index],issuer,{"accepted":true,"source":"counter_delivery"})
	EchoSystem.record_module(module_id, outcome)
	GameState.shared_state.erase("pending_module")
	GameState.commit_active_role_state()
	return {
		"ok": true,
		"message": str(selected.get("result_text", "这次经历已经被记录下来。"))+("\n"+str(outcome.get("service_response","")) if module_id=="cooking" else ""),
		"module_id": module_id,
		"outcome": outcome,
	}


func _prototype_token_label(prototype: Dictionary, token_id: String) -> String:
	for token in prototype.get("interaction", {}).get("tokens", []):
		if str(token.get("id", "")) == token_id:
			return str(token.get("label", token_id))
	return token_id


func complete_external(module_id: String, outcome: Dictionary, results: Dictionary = {}) -> bool:
	if outcome.get("interaction",{}).get("context",{}) != session_context(): return false
	if module_id!=pending_module_id() or not modules.has(module_id) or not is_unlocked(module_id):
		return false
	var was_completed := bool(ensure_state(module_id).get("completed", false))
	if not complete(module_id, outcome):
		return false
	var granted := results.duplicate(true)
	if module_id == "cooking" and int(outcome.get("restaurant", {}).get("served", 0)) > 0:
		# Record the outcome before procurement indexes it, and retain the source
		# until payment checks whether this service belongs to a scheduled shift.
		var order := EconomySystem.active_order()
		if not order.is_empty() and bool(order.get("delivered", false)) and not bool(order.get("paid", false)):
			var used: Array[String] = []
			for meal in outcome.restaurant.get("meals", []):
				for ingredient in meal.get("dish", {}).get("ingredients", []):
					var id := str(ingredient.get("id", ""))
					if not used.has(id): used.append(id)
			if order.get("items", []).all(func(id): return used.has(str(id))):
				EconomySystem.finish_cooking(outcome, order.get("items", []))
	if module_id == "cooking": granted.erase("confirmations")
	# This extension contains one authored client commission. Reopening its
	# finished letter is a keepsake, not a new payable delivery.
	if module_id == "ghostwriting":
		granted.erase("money")
		if not was_completed and bool(outcome.get("contribution_accepted",false)):
			var work: Dictionary = EconomySystem.config.work.letter
			GameState.earn_money(int(work.pay),"书信委托报酬",{"work_minutes":int(work.minutes),"kind":"income","issuer":"handcraft_shop","source":"letter_delivery"})
	EventSystem.apply_results("module_%s_external" % module_id, granted)
	EchoSystem.record_module(module_id, outcome)
	GameState.shared_state.erase("pending_module")
	GameState.commit_active_role_state()
	return true

func time_hint(module_id: String) -> String:
	var metadata: Dictionary = modules.get(module_id,{})
	if int(metadata.get("direct_time_minutes",0)) > 0: return "%d分钟" % int(metadata.direct_time_minutes)
	var costs: Array[int] = []
	for choice in prototypes.get(module_id,{}).get("choices",[]): costs.append(int(choice.get("cost",{}).get("minutes",0)))
	if costs.is_empty(): return ""
	costs.sort()
	return "%d分钟" % costs[0] if costs[0] == costs[-1] else "%d—%d分钟" % [costs[0],costs[-1]]

func record_studio_delivery(record: Dictionary) -> bool:
	if str(record.get("created_by",""))!=GameState.current_role or int(record.get("game_day",0))!=GameState.current_day: return false
	if not FileAccess.file_exists(str(record.get("final_audio_path",""))) or float(record.get("duration",0))<=0: return false
	var id := str(record.get("record_id",""))
	var completed: Array=GameState.artifacts.get("studio_deliveries",[])
	if completed.has(id): return true
	if not begin_session("sound_sampling","studio:record_store"): return false
	if not GameState.use_free_time(60): cancel_session(); return false
	var outcome := {"choice_id":"pressed_record","label":str(record.title),"record":record.duplicate(true),"interaction":{"context":session_context(),"mode":"studio","selected_labels":[str(record.title)]}}
	if not complete_external("sound_sampling",outcome): cancel_session(); return false
	completed.append(id); GameState.artifacts["studio_deliveries"]=completed
	return true

func required_minutes(module_id: String) -> int:
	var direct := int(modules.get(module_id,{}).get("direct_time_minutes",0))
	if direct>0: return direct
	var value := 0
	for choice in prototypes.get(module_id,{}).get("choices",[]): value=maxi(value,int(choice.get("cost",{}).get("minutes",0)))
	if module_id=="cooking": return int(EconomySystem.cooking_cost({"minutes":value}).get("minutes",value))
	return maxi(60,value) if module_id=="sound_sampling" else value

func entry_check(module_id: String, duration_override := -1) -> Dictionary:
	if not ChapterSystem.module_available(module_id): return {"ok":false,"reason":"今天先做手边的事情。"}
	if module_id=="contemplation" and GameState.current_minute<WorldGraph.LOOKOUT_OPEN: return {"ok":false,"reason":"观景台入夜开放，可以晚些再来。"}
	var minutes := duration_override if duration_override>=0 else required_minutes(module_id)
	var place := WorldGraph.activity_location(module_id)
	if not place.is_empty():
		var hours := WorldGraph.location_status(place)
		if not bool(hours.open): return {"ok":false,"reason":str(hours.reason)}
		if GameState.current_minute+minutes>int(hours.closes): return {"ok":false,"reason":"这次活动约需 %d 分钟，店铺 %02d:%02d 休息。明天早点来吧。"%[minutes,int(hours.closes)/60,int(hours.closes)%60]}
	if not GameState.can_fit_now(minutes): return {"ok":false,"reason":"这次活动需要约 %d 分钟，当前空闲时段放不下。可以查看日程。"%minutes}
	return {"ok":true,"reason":"","minutes":minutes}
