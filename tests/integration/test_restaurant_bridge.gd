extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func prepare(state) -> void:
	root.get_node("ChapterSystem").start_new_game()
	state.switch_to_role("B", 2, true)
	root.get_node("ChapterSystem").align_saved_chapter()
	state.current_location = "night_market"
	state.current_minute = 600
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	var state = root.get_node("GameState")
	var gameplay = root.get_node("GameplayModuleSystem")
	var life = root.get_node("LifeSystem")
	var bridge = load("res://scripts/core/restaurant_bridge.gd")
	prepare(state)
	expect(gameplay.modules.cooking.scene_path == "res://scenes/restaurant_host.tscn", "real restaurant replaces legacy cooking entrance")
	expect(gameplay.begin_session("cooking", "restaurant_bridge_test"), "cooking session begins")
	var context: Dictionary = gameplay.session_context().duplicate(true)
	var result := {"session_id":"receipt_one","served":1,"elapsed_seconds":360.0,"duration_seconds":720.0,"share":12.37,"meals":[{"id":"meal_one","ingredients":[{"id":"tomato","mass_kg":0.1}]}]}
	var before: Dictionary = state.to_save_data().duplicate(true)
	var money_before: int = state.money
	var rejected: Dictionary = bridge.settle(result, {}, 90, func(): return true)
	expect(not rejected.ok and state.money == money_before, "foreign context rejected without mutation")
	var failed: Dictionary = bridge.settle(result, context, 90, func(): return false)
	expect(not failed.ok and state.to_save_data() == before, "failed save restores time, wallet, pending session and outcomes")
	var success: Dictionary = bridge.settle(result, context, 90, func(): return true)
	expect(success.ok and state.current_minute == 645, "half a shift advances exactly 45 minutes")
	expect(state.money == money_before + 12 and state.artifacts.restaurant_balance_cents == 37, "fractional share preserves cents")
	expect(gameplay.pending_module_id().is_empty() and gameplay.state_for("cooking").outcomes.size() == 1, "one physical service becomes one main outcome")
	var settled: Dictionary = state.to_save_data().duplicate(true)
	expect(bridge.settle(result,context,90,func(): return true).ok and state.to_save_data() == settled, "same receipt cannot pay twice")
	expect(gameplay.begin_session("cooking","restaurant_bridge_test_2"), "second session begins")
	var second: Dictionary = result.duplicate(true)
	second.session_id = "receipt_two"; second.share = 0.68
	expect(bridge.settle(second,gameplay.session_context(),90,func(): return true).ok, "second real service commits")
	expect(state.money == money_before + 13 and state.artifacts.restaurant_balance_cents == 5, "cents carry across shifts without rounding each result")
	prepare(state)
	var cancel_money: int = state.money
	gameplay.begin_session("cooking","empty_shift")
	var empty := {"session_id":"empty_receipt","served":0,"elapsed_seconds":100.0,"duration_seconds":720.0,"share":999.0}
	expect(bridge.settle(empty,gameplay.session_context(),90,func(): return true).ok, "preparation can be left")
	expect(state.money == cancel_money and state.current_minute == 600 and not gameplay.state_for("cooking").completed, "empty preparation grants no money, time or completion")
	gameplay.begin_session("cooking","host_viewport_test")
	var ticks := Engine.physics_ticks_per_second
	var host = load("res://scenes/restaurant_host.tscn").instantiate()
	root.add_child(host); await process_frame; await process_frame
	expect(is_instance_valid(host.kitchen) and host.viewport.world_2d != root.world_2d, "formal host mounts the kitchen in an isolated physics world")
	expect(Engine.physics_ticks_per_second == 120, "native kitchen keeps 120 Hz while open")
	expect(host.kitchen.context.repository_path.contains("/tests/") and host.kitchen.context.repository_path.contains("/B/"), "test and role cookbook paths stay isolated")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture=") and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			expect(root.get_texture().get_image().save_png(argument.trim_prefix("--capture=")) == OK, "main entrance GPU capture saved")
	host.queue_free(); await process_frame; await process_frame
	expect(Engine.physics_ticks_per_second == ticks, "closing the kitchen restores main engine settings")
	prepare(state)
	var economy = root.get_node("EconomySystem")
	var router = root.get_node("SceneRouter")
	# An actual scheduled shift must pay only the worked fraction and retain the
	# procurement order until the delivered ingredients appear in served meals.
	var shift: Dictionary = state.next_commitment().duplicate(true)
	state.current_minute = int(shift.start)
	router.active_space_id = "restaurant"
	shift.merge({"actual_start":state.current_minute,"actual_end":int(shift.end),"token":state._commitment_token(shift)},true)
	life.state().active_shift = shift
	expect(gameplay.begin_session("cooking", "shift:"+str(shift.id)), "scheduled restaurant shift enters physical kitchen")
	state.inventory.merge({"tomato":1,"herbs":1,"sea_beans":1},true)
	economy.state().procurement[str(state.current_day)] = {"id":"qa_order","delivered":true,"paid":false,"items":["tomato","herbs","sea_beans"]}
	var shift_money: int = state.money
	var service := result.duplicate(true)
	service.session_id = "real_shift"; service.share = 0.0
	var shift_minutes := int(shift.end)-int(shift.start)
	expect(bridge.settle(service,gameplay.session_context(),shift_minutes,func(): return true).ok, "scheduled shift saves")
	expect(state.money == shift_money + int(floor(float(shift.pay)*0.5)), "half a scheduled shift pays half its wage without extra commission")
	expect(not economy.active_order().paid and state.inventory.herbs == 1, "unused procurement is not silently consumed or paid")
	state.current_minute = int(shift.end)
	expect(gameplay.begin_session("cooking", "procurement_followup"), "unfinished order can be cooked later")
	service.session_id = "real_procurement"; service.elapsed_seconds = 720.0
	service.meals = [{"customer":"客人","dish":{"ingredients":[{"id":"tomato"},{"id":"herbs"},{"id":"sea_beans"}]}}]
	var procurement_money: int = state.money
	expect(bridge.settle(service,gameplay.session_context(),90,func(): return true).ok, "real delivered ingredients complete order")
	expect(economy.active_order().paid and int(state.inventory.get("herbs",0)) == 0, "served procurement consumed exactly once")
	expect(state.money == procurement_money + int(economy.config.work.restaurant.pay), "out-of-shift commission pays once")
	print("Restaurant bridge: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
