extends SceneTree

var failed:=0
func check(ok: bool,message: String) -> void:
	if not ok: failed+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	var scene=load("res://extensions/myriorama_tarot/main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.6).timeout
	var identity=scene.stage.get_instance_id()
	scene.start_case()
	var game=scene.case_game
	for case_id in ["murder","doors"]:
		game.new_case(case_id)
		for round_number in range(3):
			await game.draw_round()
			for slot in range(5):
				await game.pick_from_fan(slot)
				check(is_instance_valid(game.question_input),"Every draw opens a real editable question")
				game.question_input.text="这张牌有什么含义"
				game.review_question()
				check(game.question_records.is_empty(),"Free guidance never consumes a fact attempt")
				game.close_modal()
		check(game.owned.size()==15 and game.revealed.size()==15,"Three rounds retain all fifteen cards")
		check(scene.stage.get_instance_id()==identity and scene.reader.visible,"Persistent room and reader")
		game.mode="choose"
		game.render()
		await process_frame; await process_frame
		for control in game.content.get_children():
			if control is Button and control.text.contains("解读"):
				check(control.size.y<=26,"Compact inspect buttons must not overlap the next card row")
		check(scene.dialogue.position.x>1000,"Returning from a card never covers the left case brief")
		for id in game.Rules.CASES[case_id].main: game.toggle_main(id)
		game.mode="sort"; game.render()
		await process_frame; await process_frame
		check(scene.ribbons.links.size()==game.main_cards.size()-1,"All adjacent main cards get live connections")
		game.check_story()
		check(not scene.ribbons.active,"No orphan connection effects behind truth dialog")
		check(is_instance_valid(game.truth_input),"Correct landscape requires complete truth next")
		game.truth_input.text="不知道"
		game.review_truth()
		check(not game.truth_review.complete,"Unknown narration never completes a case")
		var report=game.modal.get_node_or_null("TruthReport")
		check(is_instance_valid(report) and report.get_child(0).position.x>=1050 and report.get_child(0).position.x+report.get_child(0).size.x<=1565,"Truth feedback stays inside the reader room result panel")
		game.truth_input.text_changed.emit()
		check(game.modal.get_node_or_null("TruthReport")==null,"Editing narration clears stale truth feedback")
		game.truth_input.text="女子三因无法接受分手而杀死死者。" if case_id=="murder" else "四组总人数是五十。"
		game.review_truth(); game.confirm_truth()
		check(not game.solmere_completed,"A partial truth does not complete the case")
		report=game.modal.get_node_or_null("TruthReport")
		check(is_instance_valid(report) and report.get_child(0).position.x>=1050,"Missing truth feedback remains inside the result panel")
		if case_id=="murder":
			game.truth_input.text="女子三与死者曾是恋人。女子三与死者已经分手。女子三因无法接受分手而杀死死者。女子三主动来到死者家中。门边的冲突与死亡有关。水果刀是凶器。报案人留在门外。侦探是案发后第一位进入现场的人。女子三附身侦探。女子三原本打算附身报案人。女子三附身侦探后误导调查。"
		else:
			game.truth_input.text="四组总人数是五十。最低<中间=中间<最高。换门不影响结果。"
		game.review_truth(); game.confirm_truth()
		check(game.solmere_completed,"Both cases require and accept a complete truth statement")
		check(scene.dialogue.get_theme_stylebox("panel") is StyleBoxFlat and scene.dialogue.speaker.position.x>=24,"Reader dialogue uses a padded rectangular panel")
		check(scene.dialogue.position.x>100 and scene.dialogue.position.y>500 and scene.dialogue.position.x+scene.dialogue.size.x<1040,"Completed-case dialogue sits below the reader without covering the truth panel")
		game.close_modal()
		game.save_session()
		var before=game.owned.duplicate()
		scene.request_return(); scene.start_case()
		check(game.owned==before,"Returning to welcome does not discard cards")
	check(scene.stage.get_instance_id()==identity,"No scene change during modes")
	print("TAROT READER CASE FLOW PASS" if failed==0 else "TAROT READER CASE FLOW FAIL: "+str(failed))
	quit(failed)
