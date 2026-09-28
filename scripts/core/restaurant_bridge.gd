extends RefCounted
## One transaction for time, existing shift wages, kitchen share and the receipt.
## A failed disk write restores the entire role snapshot; retry uses the same ID.

static func storage_path() -> String:
	var scope := "tests" if OS.get_cmdline_user_args().has("--isolated-save") else "saves"
	var journey := str(GameState.shared_state.get("journey_id", "legacy")).validate_filename()
	return "user://restaurant/%s/slot_%d/%s/%s/cookbook.json" % [scope, SaveManager.active_slot, journey, GameState.current_role]

static func settle(result: Dictionary, context: Dictionary, planned_minutes: int, save: Callable = Callable()) -> Dictionary:
	var receipt := str(result.get("session_id", ""))
	if receipt.is_empty(): return {"ok":false, "message":"这次的账单还没记好，请再试一次。"}
	var receipts: Dictionary = GameState.artifacts.get("restaurant_receipts", {})
	if receipts.has(receipt): return {"ok":true, "duplicate":true}
	if GameplayModuleSystem.pending_module_id() != "cooking" or context != GameplayModuleSystem.session_context():
		return {"ok":false, "message":"这次营业不属于当前角色，账目没有改动。"}
	var before := GameState.to_save_data().duplicate(true)
	if not GameState.compatible_save(before):
		return {"ok":false, "message":"当前日程还不能保存，账目没有改动。"}
	var served := int(result.get("served", 0))
	var elapsed := float(result.get("elapsed_seconds", 0.0))
	var duration := maxf(1.0, float(result.get("duration_seconds", 720.0)))
	if not is_finite(elapsed) or not is_finite(duration): return {"ok":false, "message":"营业时间不完整。"}
	var minutes := clampi(ceili(planned_minutes * clampf(elapsed / duration, 0.0, 1.0)), 0, planned_minutes)
	var source := str(GameState.shared_state.pending_module.get("source_event_id", ""))
	if served <= 0:
		# No meal was served. Leaving preparation must not grant a completed shift.
		GameplayModuleSystem.cancel_session()
	else:
		if minutes <= 0 or not GameState.use_free_time(minutes):
			GameState.load_save_data(before)
			return {"ok":false, "message":"这段营业时间还没能记入日程，请重试。"}
		var shift := LifeSystem.active_shift()
		if not shift.is_empty(): shift.actual_end = int(shift.actual_start) + minutes
		var outcome := {"choice_id":"restaurant_shift", "label":"在饭店做了一顿饭", "source_event_id":source,
			"restaurant":result.duplicate(true), "interaction":{"context":context.duplicate(true), "mode":"physical_kitchen", "selected_labels":["切配、下锅、出餐"]}}
		if not GameplayModuleSystem.complete_external("cooking", outcome):
			GameState.load_save_data(before)
			return {"ok":false, "message":"账目还没存好，再试一次。"}
		# Solmere's wallet stores whole yuan. Preserve every remaining cent, including
		# an unpaid compensation balance, instead of rounding each shift's share.
		var share := float(result.get("share", 0.0))
		if not is_finite(share):
			GameState.load_save_data(before)
			return {"ok":false, "message":"账单金额不完整。"}
		var cents := roundi(share * 100.0) + int(GameState.artifacts.get("restaurant_balance_cents", 0))
		var yuan := int(float(cents) / 100.0)
		if yuan > 0: GameState.earn_money(yuan, "饭店营业分成", {"work_minutes":minutes,"kind":"income","issuer":"night_market","source":receipt})
		elif yuan < 0:
			yuan = -mini(-yuan, GameState.money)
			GameState.spend_money(-yuan, "饭店赔偿")
		GameState.artifacts["restaurant_balance_cents"] = cents - yuan * 100
		GameState.add_artifact("restaurant_shifts", {"id":receipt,"title":"饭店账单","day":GameState.current_day,"minutes":minutes,"served":served,"share":share})
	receipts = GameState.artifacts.get("restaurant_receipts", {}).duplicate(true)
	receipts[receipt] = {"day":GameState.current_day,"served":served,"minutes":minutes}
	GameState.artifacts["restaurant_receipts"] = receipts
	GameState.commit_active_role_state()
	var saved: bool = bool(save.call()) if save.is_valid() else SaveManager.save_or_report("饭店账目没有存好")
	if not saved:
		GameState.load_save_data(before)
		return {"ok":false, "message":"账目没有存进文件，钱和日程都还没改。点“收起围裙”重试。"}
	return {"ok":true,"minutes":minutes}
