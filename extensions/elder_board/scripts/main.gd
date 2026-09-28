extends Control
## Emitted when the user enters a local AI match.
signal game_selected(game_id: StringName)

const DESIGN_SIZE := Vector2(1579, 972)
const GAMES := [
	{"id": &"go", "title": "围棋"},
	{"id": &"gomoku", "title": "五子棋"},
	{"id": &"chess", "title": "国际象棋"},
	{"id": &"encounter", "title": "相遇棋 · NPC 策略"},
]

var selected_game: StringName = &""
var stage: Control
var dialogue: Label
var choices: VBoxContainer
var back_button: Button
var buttons: Array[Button] = []
var match_view: Control
var setup_view: Control
var selected_go_size := 9
var greeting_index := 0
const Text = preload("res://extensions/elder_board/scripts/game_text.gd")
const Memory = preload("res://extensions/elder_board/scripts/elder_memory.gd")
var teaching_view: Control
var story_view: Control
var role_choice: OptionButton
var solmere_completed := false

func _ready() -> void:
	Memory.hosted=has_meta("solmere_context")
	if has_node("/root/GameState"):
		Memory.role = str(get_node("/root/GameState").current_role)
	DisplayServer.window_set_title(LocalizationSystem.text("Solmere · 老棋友"))
	theme = preload("res://extensions/elder_board/scripts/ui_bits.gd").paper_theme()
	stage = Control.new()
	stage.name = "OriginalArtworkStage"
	stage.size = DESIGN_SIZE
	add_child(stage)
	stage.add_child(preload("res://extensions/elder_board/scripts/table_preview.gd").new())
	_build_dialogue()
	game_selected.connect(_open_match)
	resized.connect(_fit_stage)
	_fit_stage()
	buttons[0].grab_focus()
	if "--teach" in OS.get_cmdline_user_args(): call_deferred("_open_teaching")
	if "--story-preview" in OS.get_cmdline_user_args(): call_deferred("_preview_story")

func _fit_stage() -> void:
	var ratio: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	stage.scale = Vector2.ONE * ratio
	stage.position = (size - DESIGN_SIZE * ratio) / 2.0

func _panel_style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(9)
	style.set_border_width_all(2)
	style.border_color = border
	style.content_margin_left = 18
	style.content_margin_right = 18
	return style

func _button(text_value: String) -> Button:
	var button := preload("res://scripts/ui/components/solmere_button.gd").new()
	button.variant="outlined"; button.text=LocalizationSystem.text(text_value); button.custom_minimum_size=Vector2(220,65); button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return button

func _build_dialogue() -> void:
	var column := VBoxContainer.new()
	column.name = "DialogueOverlay"
	column.position = Vector2(1020, 172)
	column.size = Vector2(430, 600)
	column.add_theme_constant_override("separation", 10)
	stage.add_child(column)
	var speaker := Label.new()
	speaker.text = LocalizationSystem.text("老棋友")
	speaker.add_theme_font_size_override("font_size", 34)
	column.add_child(speaker)
	role_choice = OptionButton.new()
	role_choice.visible = not Memory.hosted
	role_choice.add_item(LocalizationSystem.text("角色 A"))
	role_choice.add_item(LocalizationSystem.text("角色 B"))
	role_choice.select(0 if Memory.role == "A" else 1)
	role_choice.item_selected.connect(func(index: int): Memory.role = "A" if index == 0 else "B")
	role_choice.position = Vector2(215, 55)
	role_choice.size = Vector2(230, 54)
	stage.add_child(role_choice)
	dialogue = Label.new()
	dialogue.text = LocalizationSystem.text(Text.GREETINGS[0])
	dialogue.add_theme_font_size_override("font_size", 25)
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.custom_minimum_size = Vector2(430, 126)
	column.add_child(dialogue)
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	column.add_child(choices)
	for index in range(GAMES.size()):
		var button := _button(str(GAMES[index]["title"]))
		button.custom_minimum_size = Vector2(430, 51)
		button.add_theme_font_size_override("font_size", 25)
		button.pressed.connect(_select_game.bind(index))
		choices.add_child(button)
		buttons.append(button)
	var teach_button := _button("教棋 / 共享棋谱")
	teach_button.add_theme_font_size_override("font_size", 23)
	teach_button.custom_minimum_size.y = 48
	teach_button.pressed.connect(_open_teaching)
	column.add_child(teach_button)
	var chat_button := _button("聊两句")
	chat_button.custom_minimum_size.y = 48
	chat_button.pressed.connect(_chat)
	column.add_child(chat_button)
	back_button = _button("重新选择")
	back_button.pressed.connect(_reset_selection)
	back_button.hide()
	column.add_child(back_button)

func _select_game(index: int) -> void:
	if index < 0 or index >= GAMES.size():
		return
	selected_game = GAMES[index]["id"]
	if selected_game == &"encounter":
		game_selected.emit(selected_game)
		return
	setup_view = preload("res://extensions/elder_board/scripts/rules_panel.gd").new()
	setup_view.configure(selected_game, true, selected_go_size)
	setup_view.closed.connect(_cancel_setup)
	setup_view.start_requested.connect(_start_match)
	stage.add_child(setup_view)

func _chat() -> void:
	greeting_index = (greeting_index + 1) % Text.GREETINGS.size()
	dialogue.text = LocalizationSystem.text(Text.GREETINGS[greeting_index])

func _cancel_setup() -> void:
	if is_instance_valid(setup_view): setup_view.queue_free()
	setup_view = null
	_reset_selection()

func _start_match(go_size: int) -> void:
	selected_go_size = go_size
	if is_instance_valid(setup_view): setup_view.queue_free()
	setup_view = null
	game_selected.emit(selected_game)

func _reset_selection() -> void:
	selected_game = &""
	dialogue.text = LocalizationSystem.text("回来啦。想再下一局，还是换种棋试试？\n选围棋的话，也可以换一张更大的棋盘。")
	back_button.hide()
	choices.show()
	buttons[0].grab_focus()

func _open_match(id: StringName) -> void:
	stage.get_node("DialogueOverlay").hide()
	if id == &"encounter":
		match_view = preload("res://extensions/elder_board/scripts/npc_match.gd").new()
	else:
		match_view = preload("res://extensions/elder_board/scripts/match.gd").new()
		match_view.setup(id, selected_go_size)
	match_view.return_requested.connect(_close_match)
	match_view.match_finished.connect(_on_finished)
	stage.add_child(match_view)

func _close_match() -> void:
	if is_instance_valid(match_view):
		match_view.queue_free()
	match_view = null
	stage.get_node("DialogueOverlay").show()
	_reset_selection()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(teaching_view) or is_instance_valid(story_view): return
	if is_instance_valid(match_view): return
	if is_instance_valid(setup_view): return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_reset_selection()
		get_viewport().set_input_as_handled()
	elif selected_game == &"" and event.keycode >= KEY_1 and event.keycode <= KEY_4:
		_select_game(event.keycode - KEY_1)
		get_viewport().set_input_as_handled()

func _open_teaching() -> void:
	if is_instance_valid(teaching_view): return
	stage.get_node("DialogueOverlay").hide()
	teaching_view = preload("res://extensions/elder_board/scripts/teaching_room.gd").new()
	teaching_view.closed.connect(_close_teaching)
	teaching_view.play_requested.connect(_play_learned)
	stage.add_child(teaching_view)

func _close_teaching() -> void:
	if is_instance_valid(teaching_view): teaching_view.queue_free()
	teaching_view = null
	stage.get_node("DialogueOverlay").show()
	_reset_selection()

func _play_learned(profile: Dictionary) -> void:
	if is_instance_valid(teaching_view): teaching_view.hide()
	match_view = preload("res://extensions/elder_board/scripts/learned_match.gd").new()
	match_view.setup(profile)
	match_view.return_requested.connect(func():
		match_view.queue_free()
		match_view = null
		if is_instance_valid(teaching_view): teaching_view.show()
	)
	match_view.match_finished.connect(_on_finished)
	stage.add_child(match_view)

func _on_finished(_result: String) -> void:
	solmere_completed = true
	call_deferred("_show_story")

func _show_story() -> void:
	if is_instance_valid(story_view): return
	story_view = preload("res://extensions/elder_board/scripts/elder_story.gd").new()
	story_view.closed.connect(_close_story)
	story_view.teach_requested.connect(func():
		_close_story()
		if is_instance_valid(match_view):
			match_view.queue_free()
			match_view = null
		if is_instance_valid(teaching_view): teaching_view.show()
		else: _open_teaching()
	)
	stage.add_child(story_view)

func _preview_story() -> void:
	if is_instance_valid(story_view): return
	story_view = preload("res://extensions/elder_board/scripts/elder_story.gd").new()
	story_view.preview_mode = true
	story_view.closed.connect(_close_story)
	stage.add_child(story_view)

func _close_story() -> void:
	if is_instance_valid(story_view): story_view.queue_free()
	story_view = null
