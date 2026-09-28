extends SceneTree
## Native Godot movie: all four choices, live classic turns, an encounter
## match, result dialogues, and return to the menu. Run with --write-movie.
const Rules = preload("res://extensions/elder_board/scripts/npc_rules.gd")
const MOVIE_FPS := 12

func _initialize() -> void:
	call_deferred("record")

func pause(seconds: float) -> void:
	# Movie Maker advances game time independently of wall time. Count rendered
	# frames so every selection and turn is actually present in the AVI.
	for frame in maxi(1, ceili(seconds * MOVIE_FPS)):
		await process_frame

func tap_board(view: Control, at: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(231 + (at % 7 + 0.5) * 88, 163 + (int(at / 7) + 0.5) * 88)
	view._gui_input(event)

func tap_classic(view: Control, at: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	var offset := Vector2.ONE * 0.5 if view.game_id == &"chess" else Vector2.ZERO
	event.position = view.origin + (Vector2(at % view.n, int(at / view.n)) + offset) * view.cell
	view._gui_input(event)

func wait_for_classic_turn(view: Control) -> void:
	for frame in 48:
		await process_frame
		if not view.busy and view.turn == 1: return

func demonstrate_classic(menu: Control, index: int) -> void:
	menu._select_game(index)
	await pause(0.9)
	menu._start_match(9)
	await process_frame
	var view: Control = menu.match_view
	await pause(0.6)
	if index == 2:
		for turn_index in 2:
			var move: Dictionary = {}
			for candidate in view.legal_moves:
				if turn_index == 0 and int(candidate.from) == 52 and int(candidate.to) == 36:
					move = candidate
					break
			if move.is_empty(): move = view.legal_moves[0]
			tap_classic(view, int(move.from))
			await pause(0.45)
			tap_classic(view, int(move.to))
			await wait_for_classic_turn(view)
			await pause(0.3)
	else:
		var targets := [40, 30, 49] if index == 0 else [112, 113, 127]
		for target in targets:
			if view.board[target] != 0:
				for fallback in range(view.board.size()):
					if view.board[fallback] == 0:
						target = fallback
						break
			tap_classic(view, target)
			await wait_for_classic_turn(view)
			await pause(0.28)
	view.resign()
	await pause(0.65)
	if is_instance_valid(menu.story_view):
		await pause(0.55)
		menu._close_story()
		await pause(0.2)
	print("BOARD_MOVIE_MODE: %s completed" % str(view.game_id))
	menu._close_match()
	await pause(0.55)

func record() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://extensions/elder_board/scenes/main.tscn")
	await process_frame
	await pause(1.3)
	var menu = current_scene
	for index in 3:
		await demonstrate_classic(menu, index)
	menu._select_game(3)
	await process_frame
	var view = menu.match_view
	await pause(0.9)
	for id in ["mossner", "chenyuan", "beetman", "naonao"]:
		view._toggle_pick(id)
		await pause(0.27)
	await pause(0.6)
	view._start_deployment()
	await pause(0.5)
	view._beginner_team()
	await pause(0.4)
	view._start_deployment()
	await pause(0.7)
	for at in [35, 37, 39, 41]:
		tap_board(view, at)
		await pause(0.29)
	await pause(0.6)
	view._advance_deployment()
	await pause(0.5)
	for at in [0, 2, 4, 6]:
		tap_board(view, at)
		await pause(0.29)
	await pause(0.6)
	view._begin_match()
	view.state.side = 0
	await pause(1.0)
	for step in 90:
		if view.mode == "end": break
		if int(view.state.side) == 0:
			var action := Rules.best_ai_action(view.state)
			if action.is_empty():
				if int(view.state.pending_extra) >= 0: view._skip_extra()
				else: break
			else:
				view.selected_piece = int(action.instance_id)
				view._rebuild()
				await pause(0.32)
				view._apply_action(action)
			await pause(0.42)
		else:
			await pause(0.48)
	await pause(2.1)
	var summary := "NPC_CHESS_MOVIE: result=%s score=%s turns=%d" % [str(view.state.get("result", "")), str(view.state.get("scores", [])), int(view.state.get("turns", 0))]
	if is_instance_valid(menu.story_view):
		menu._close_story()
		await pause(0.5)
	menu._close_match()
	await pause(1.2)
	print(summary)
	quit()
