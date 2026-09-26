extends SceneTree
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	var state=root.get_node("GameState")
	var router=root.get_node("SceneRouter")
	root.get_node("ChapterSystem").start_new_game()
	state.current_location="tarot_stall"; state.current_minute=925
	router.active_space_id="tarot_shop"
	var accepted: bool=router.gameplay_module("tarot","space:tarot_shop:table")
	check(accepted,"Public gameplay router accepts tarot session")
	if not accepted: quit(1); return
	await create_timer(1.0).timeout
	var host=current_scene
	check(host.module_id=="tarot" and host.experience.deck.size()==18,"Existing extension entry now reaches the reader room")
	check(not is_instance_valid(host.host_panel),"No unrelated top HUD in immersive room")
	host.experience.truth_draft="尚未说完的推理"
	host.experience.start_mode("reading")
	host.experience.question_edit.text="如何面对改变？"
	host.experience.submit_question()
	host.experience.save_session()
	host._cancel()
	await create_timer(1.0).timeout
	check(router.active_space_id=="tarot_shop","Cancel returns to same shop")
	check(state.shared_state.get("tarot_reader_"+state.current_role,{}).get("question","")=="如何面对改变？","Reading draft survives transaction rollback")
	check(router.gameplay_module("tarot","space:tarot_shop:table"),"Re-entry succeeds")
	await create_timer(1.0).timeout
	host=current_scene
	check(host.experience.truth_draft=="尚未说完的推理","Original case draft survives return and reload")
	check(not host._experience_completed(),"Reading/opening the room does not falsely complete the old case")
	print("TAROT READER HOST PASS" if failures==0 else "TAROT READER HOST FAIL")
	quit(failures)
