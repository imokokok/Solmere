extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		quit(1)
		return
	var state = root.get_node("GameState")
	var router = root.get_node("SceneRouter")
	root.get_node("ChapterSystem").start_new_game()
	state.current_location = "tarot_stall"
	state.current_minute = 925 # Current schedule: allow the shop-opening transition.
	router.active_space_id = "tarot_shop"
	router.interactive_space()
	await create_timer(0.7).timeout
	var room = current_scene
	var index := -1
	for i in range(room.objects.size()):
		if room.objects[i].get("kind","") == "tarot": index = i
	check(index >= 0,"Tarot table is present")
	if index < 0: quit(1); return
	room._select_object(index)
	room.stage.player_x = room._hotspot_x(index)
	room._open_selected()
	await process_frame
	var talk = room.conversation
	if not is_instance_valid(talk): check(false,"Approaching the table starts Xia's real invitation"); quit(1); return
	talk.typewriter = false
	check(talk.offer.get("module","") == "tarot","Xia invites the player from the table")
	for i in range(talk.lines.size()): talk._advance()
	await process_frame
	talk._choose_invitation("accept"); talk._advance(); await process_frame
	if get_nodes_in_group("native_confirmation").is_empty():
		# Non-launch invitations reserve the table; the next approach starts it.
		await create_timer(0.3).timeout
		room._open_selected()
		await process_frame
	var confirmations=get_nodes_in_group("native_confirmation")
	check(confirmations.size()==1,"The real invitation opens one activity confirmation")
	if confirmations.is_empty(): quit(1); return
	confirmations[0].accepted.emit()
	await create_timer(0.8).timeout
	var host = current_scene
	if host.get_script().resource_path!="res://scripts/ui/extension_host.gd":
		check(false,"Actual tarot entrance must reach its extension host")
		quit(1); return
	check(host.module_id == "tarot" and host.experience.deck.size() == 18,"Invitation table loads uploaded Myriorama with eighteen cards")
	check(not host._experience_completed(),"Opening or reading help cannot complete the story")
	host.experience.truth_draft = "尚未说完的推理"
	host.experience.save_session()
	host._cancel()
	await create_timer(0.8).timeout
	check(router.active_space_id == "tarot_shop" and state.current_location == "tarot_stall","Leaving returns to the tarot shop")
	router.gameplay_module("tarot","space:tarot_shop:table")
	await create_timer(0.8).timeout
	host = current_scene
	check(host.experience.truth_draft == "尚未说完的推理","Returning restores main-save tarot progress")
	host.experience.solmere_completed = true
	host.experience.new_case("doors")
	check(not host._experience_completed(),"Choosing a new story resets completion")
	print("MYRIORAMA ENTRY PASS" if failures == 0 else "MYRIORAMA ENTRY FAIL")
	quit(failures)
