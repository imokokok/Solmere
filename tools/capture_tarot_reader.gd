extends SceneTree

var scene: Control
const OUT="res://docs/qa/tarot_reader_20260927"
func _initialize() -> void: call_deferred("run")
func capture(title: String) -> void:
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/"+title+".png")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_title("Tarot QA capture")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600,900))
	scene=load("res://extensions/myriorama_tarot/main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(1.0).timeout
	await capture("01-welcome")
	scene.start_case()
	var game=scene.case_game
	game.new_case("doors")
	Engine.time_scale=6.0
	for round_number in range(3):
		await game.draw_round()
		if round_number==0: await capture("02-fan")
		for slot in range(5):
			await game.pick_from_fan(slot)
			if round_number==0 and slot==0:
				await capture("03-question")
				game.show_card(game.round_picks[0],true)
				await capture("04-guide")
			game.close_modal()
	game.mode="choose"; game.render()
	await capture("05-choose")
	for id in game.Rules.CASES["doors"].main: game.toggle_main(id)
	game.mode="sort"; game.render()
	await capture("06-sort")
	game.check_story()
	await capture("07-truth")
	game.close_modal()
	game.show_truth()
	await capture("08-complete-layout")
	game.close_modal()
	scene.show_welcome()
	DisplayServer.window_set_size(Vector2i(1280,720))
	await capture("09-welcome-1280")
	scene.start_case(); game.mode="choose"; game.render()
	await capture("10-choose-1280")
	print("TAROT VISUAL CAPTURE PASS (completion layout is a fixture, not a truth-gate test)")
	quit()
