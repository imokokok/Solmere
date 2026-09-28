extends Control

const STEPS := 16
const BPM := 78.0
const SAVE_PATH := "user://sample_records.json"
const NOTE_TRACK_START := 4
const NOTE_LENGTHS := [0, 1, 2, 4, 8]

const RHYTHM_NAMES := ["社区中心木门"]
const MELODY_NAMES := ["社区中心玩具琴", "B 家旧掌机"]
const MELODY_PREFIXES := ["toy_reed", "handheld_game"]
const AMBIENCE_NAMES := ["眺望台风声", "磁带底噪声"]

const RHYTHM_PATHS := [
	"res://assets/audio/soulmere_rhythm_community_center_door_thud_short_rr01.wav"
]
const PERCUSSION_PATHS := [
	"res://assets/audio/soulmere_perc_general_store_glass_bottle_click.wav",
	"res://assets/audio/soulmere_perc_chess_piece_wood_tick_short_rr01.wav",
	"res://assets/audio/soulmere_perc_bookshop_page_flick_short_rr01.wav"
]
const AMBIENCE_PATHS := [
	"res://assets/audio/soulmere_texture_lookout_railing_wind_cg_loop.wav",
	"res://assets/audio/soulmere_texture_record_shop_turntable_hum_c2g2_loop.wav"
]
const NOTE_KEYS := ["c3", "d3", "e3", "g3", "a3"]
# 线性音量：玻璃瓶为上一版的 60%；两条背景声音均为最初基准音量的 15%。
const TRACK_VOLUME_DB := [-5.0, 5.563, -11.0, -12.0, -13.0, -13.0, -13.0, -13.0, -13.0]
const AMBIENCE_VOLUME_DB := [-12.479, -20.479]

const BG := Color("e4c9a8")
const PANEL := Color("ede4cf")
const PANEL_ALT := Color("e8e0c0")
const PAPER_LIGHT := Color("f3ead2")
const LINE := Color("858272")
const TEXT := Color("3f4b47")
const MUTED := Color("72786f")
const ACCENT := Color("ad6d58")
const CORAL := Color("c77d68")
const BLUE := Color("87adb0")
const VIOLET := Color("a69aaa")
const TEAL := Color("87a695")
const GOLD := Color("d7b85e")
const PINK := Color("c99aa3")


class PaperBackdrop extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), BG)
		for y in range(70, int(size.y), 72):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color("c5a98955"), 1.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1209
		for index in 150:
			var point := Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
			draw_circle(point, rng.randf_range(0.4, 1.2), Color("745f4930"))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

var patterns := [
	[true, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false],
	[false, false, false, false, true, false, false, false, false, false, false, false, true, false, false, false],
	[false, false, true, false, false, false, true, false, false, false, true, false, false, false, true, false],
	[false, true, false, false, false, true, false, false, false, true, false, false, false, true, false, false],
	[true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true],
	[false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false],
	[false, false, false, false, true, false, false, false, false, false, true, false, false, false, false, false],
	[false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false],
	[false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false]
]

# 五条旋律轨固定为 C3、D3、E3、G3、A3；整组旋律音色只能二选一。
var note_lengths := [
	[4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
	[0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0]
]
var track_names := [
	"社区中心木门",
	"杂货店玻璃瓶",
	"木制棋子",
	"书店翻页",
	"Do",
	"Re",
	"Mi",
	"Sol",
	"La"
]
var track_colors := [CORAL, GOLD, TEAL, BLUE, ACCENT, TEAL, GOLD, PINK, Color("8fb4ff")]
# 节奏轨保持原有密度限制；固定音高轨允许更自由地实验。
var track_limits := [6, 8, 8, 8, 8, 8, 8, 8, 8]

var rhythm_choice := 0
var melody_choice := 0
var ambience_choice := 0
var ambience_enabled := false

var step_buttons: Array = []
var header_labels: Array = []
var track_name_labels: Array = []
var audio_voices: Array = []
var rhythm_streams: Array = []
var percussion_streams: Array = []
var ambience_streams: Array = []
var melody_streams: Array = []
var records: Array = []

var is_playing := false
var play_started_usec := 0
var last_absolute_step := -1
var current_step := -1

var play_button: Button
var status_label: Label
var record_name: LineEdit
var records_list: VBoxContainer
var empty_collection_label: Label
var density_label: Label
var melody_buttons: Array = []
var ambience_buttons: Array = []
var ambience_toggle_button: Button
var ambience_player: AudioStreamPlayer


func _ready() -> void:
	_build_theme()
	_build_audio()
	_load_records()
	_build_ui()
	_refresh_grid()
	_refresh_collection()
	set_process(true)


func _process(_delta: float) -> void:
	if not is_playing:
		return

	var step_duration := 60.0 / BPM / 4.0
	var elapsed := (Time.get_ticks_usec() - play_started_usec) / 1000000.0
	var target_step := int(floor(elapsed / step_duration))

	# 补发极少量因帧率波动错过的步；避免卡顿后一次触发整串声音。
	var catch_up_from: int = maxi(last_absolute_step + 1, target_step - 1)
	for absolute_step in range(catch_up_from, target_step + 1):
		_trigger_step(absolute_step % STEPS)
	last_absolute_step = target_step

	var next_step := target_step % STEPS
	if next_step != current_step:
		current_step = next_step
		_refresh_grid()


func _build_theme() -> void:
	var theme := Theme.new()
	var ui_font := SystemFont.new()
	ui_font.font_names = PackedStringArray(["Kaiti SC", "STKaiti", "Songti SC", "PingFang SC", "Hiragino Sans GB"])
	theme.default_font = ui_font
	theme.default_font_size = 19
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", TEXT)
	theme.set_color("font_focus_color", "Button", TEXT)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_focus_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_font_size("font_size", "Button", 19)
	theme.set_font_size("font_size", "LineEdit", 19)
	theme.set_stylebox("normal", "Button", _style(Color("e9e7dd"), 4, Color("aaa795"), 1))
	theme.set_stylebox("hover", "Button", _style(Color("f4ecd8"), 4, Color("69766f"), 2))
	theme.set_stylebox("pressed", "Button", _style(Color("dfcf9c"), 4, ACCENT, 2))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("normal", "LineEdit", _style(Color("f4ecd8"), 4, Color("b8af98"), 1))
	theme.set_stylebox("focus", "LineEdit", _style(Color("f4ecd8"), 4, Color("667d77"), 2))
	var paper_panel := _style(PANEL, 8, Color("b8af98"), 1)
	paper_panel.shadow_color = Color("80684942")
	paper_panel.shadow_size = 7
	paper_panel.shadow_offset = Vector2(5, 6)
	theme.set_stylebox("panel", "PanelContainer", paper_panel)
	theme.set_constant("separation", "VBoxContainer", 13)
	theme.set_constant("separation", "HBoxContainer", 11)
	self.theme = theme


func _build_ui() -> void:
	var background := PaperBackdrop.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)

	var page := VBoxContainer.new()
	margin.add_child(page)

	var title := Label.new()
	title.text = "let's make some noise"
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Times New Roman", "Georgia", "Songti SC"])
	title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 42)
	page.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "做一张属于你自己的唱片吧！"
	subtitle.add_theme_color_override("font_color", TEXT)
	subtitle.add_theme_font_size_override("font_size", 20)
	page.add_child(subtitle)
	var title_rule := ColorRect.new()
	title_rule.color = CORAL
	title_rule.custom_minimum_size = Vector2(520, 4)
	title_rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.add_child(title_rule)

	page.add_child(_spacer(4))
	page.add_child(_build_steps_guide())
	page.add_child(_spacer(4))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)

	var studio_panel := PanelContainer.new()
	studio_panel.add_theme_stylebox_override("panel", _paper_panel(PAPER_LIGHT))
	studio_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	studio_panel.size_flags_stretch_ratio = 3.25
	body.add_child(studio_panel)

	var studio_margin := MarginContainer.new()
	studio_margin.add_theme_constant_override("margin_left", 24)
	studio_margin.add_theme_constant_override("margin_right", 24)
	studio_margin.add_theme_constant_override("margin_top", 22)
	studio_margin.add_theme_constant_override("margin_bottom", 20)
	studio_panel.add_child(studio_margin)

	var studio := VBoxContainer.new()
	studio_margin.add_child(studio)

	studio.add_child(_build_sound_selector())
	studio.add_child(_spacer(2))

	var transport := HBoxContainer.new()
	studio.add_child(transport)

	play_button = _make_button("聆听", 108)
	play_button.pressed.connect(_toggle_playback)
	transport.add_child(play_button)

	var stop_button := _make_button("停止", 92)
	stop_button.pressed.connect(_stop_playback)
	transport.add_child(stop_button)

	var clear_button := _make_button("全部清空", 96)
	clear_button.pressed.connect(_clear_pattern)
	transport.add_child(clear_button)

	var tempo := Label.new()
	tempo.text = "一圈有 16 格 · 会自动重复"
	tempo.add_theme_color_override("font_color", MUTED)
	tempo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tempo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	transport.add_child(tempo)

	density_label = Label.new()
	density_label.add_theme_color_override("font_color", Color("667d77"))
	density_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	transport.add_child(density_label)

	studio.add_child(_spacer(2))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	studio.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = STEPS + 1
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 7)
	grid.custom_minimum_size = Vector2(1035, 500)
	scroll.add_child(grid)

	var corner := Label.new()
	corner.text = "点格子让声音出现"
	corner.custom_minimum_size = Vector2(195, 30)
	corner.add_theme_color_override("font_color", MUTED)
	grid.add_child(corner)

	for step in STEPS:
		var number := Label.new()
		number.text = str(step + 1)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.custom_minimum_size = Vector2(42, 30)
		number.add_theme_color_override("font_color", MUTED)
		header_labels.append(number)
		grid.add_child(number)

	for track in track_names.size():
		var name_label := Label.new()
		name_label.text = track_names[track]
		name_label.custom_minimum_size = Vector2(195, 42)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.tooltip_text = track_names[track]
		name_label.add_theme_color_override("font_color", track_colors[track])
		name_label.add_theme_font_size_override("font_size", 16)
		track_name_labels.append(name_label)
		grid.add_child(name_label)

		var row: Array = []
		for step in STEPS:
			var cell := Button.new()
			cell.toggle_mode = true
			cell.custom_minimum_size = Vector2(42, 42)
			cell.focus_mode = Control.FOCUS_NONE
			cell.tooltip_text = "%s · 第 %d 格" % [track_names[track], step + 1]
			cell.pressed.connect(_on_step_pressed.bind(track, step))
			row.append(cell)
			grid.add_child(cell)
		step_buttons.append(row)

	var note := Label.new()
	note.text = "上面四行每点一次就是开或关。下面五行从低到高排列；重复点击同一格，可切换：不响 → 短 → 稍长 → 长 → 很长。背景声音只用上方开关控制。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", MUTED)
	note.add_theme_font_size_override("font_size", 14)
	studio.add_child(note)

	var collection_panel := PanelContainer.new()
	collection_panel.add_theme_stylebox_override("panel", _paper_panel(PANEL_ALT))
	collection_panel.custom_minimum_size = Vector2(345, 0)
	collection_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_panel.size_flags_stretch_ratio = 1.0
	body.add_child(collection_panel)

	var collection_margin := MarginContainer.new()
	collection_margin.add_theme_constant_override("margin_left", 18)
	collection_margin.add_theme_constant_override("margin_right", 18)
	collection_margin.add_theme_constant_override("margin_top", 18)
	collection_margin.add_theme_constant_override("margin_bottom", 18)
	collection_panel.add_child(collection_margin)

	var collection := VBoxContainer.new()
	collection_margin.add_child(collection)

	var collection_title := Label.new()
	collection_title.text = "4  保存你的唱片"
	collection_title.add_theme_font_size_override("font_size", 24)
	collection.add_child(collection_title)

	var collection_hint := Label.new()
	collection_hint.text = "满意以后取个名字。保存过的唱片可以随时打开继续修改。"
	collection_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	collection_hint.add_theme_color_override("font_color", MUTED)
	collection_hint.add_theme_font_size_override("font_size", 14)
	collection.add_child(collection_hint)

	record_name = LineEdit.new()
	record_name.placeholder_text = "给这张唱片取名"
	record_name.max_length = 24
	collection.add_child(record_name)

	var save_button := _make_button("保存这张唱片", 0)
	save_button.pressed.connect(_save_record)
	collection.add_child(save_button)

	var separator := HSeparator.new()
	collection.add_child(separator)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection.add_child(list_scroll)

	records_list = VBoxContainer.new()
	records_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(records_list)

	empty_collection_label = Label.new()
	empty_collection_label.text = "这里还没有唱片。\n点一些格子，听听看，再保存第一张。"
	empty_collection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_collection_label.add_theme_color_override("font_color", MUTED)
	records_list.add_child(empty_collection_label)

	status_label = Label.new()
	status_label.text = "先选声音，再点格子。准备好后按“聆听”。"
	status_label.add_theme_color_override("font_color", MUTED)
	status_label.add_theme_font_size_override("font_size", 14)
	page.add_child(status_label)

	_add_tape(Vector2(438, 133), Vector2(104, 24), -3.0, Color("c9bd8599"))
	_add_tape(Vector2(1310, 132), Vector2(112, 25), 2.0, Color("d1b96f99"))
	_refresh_sound_selector()


func _build_steps_guide() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("e8e0c0"), 3, Color("b5aa91"), 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)
	var labels := ["1  选声音", "2  点格子", "3  聆听", "4  保存"]
	var colors := [CORAL, TEAL, GOLD, BLUE]
	for index in labels.size():
		var item := Label.new()
		item.text = labels[index]
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_theme_color_override("font_color", colors[index].darkened(0.25))
		item.add_theme_font_size_override("font_size", 15)
		row.add_child(item)
	return panel


func _build_sound_selector() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("e7dec5"), 5, Color("b8af98"), 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var melody_group := _make_selector_group("选择主声音", MELODY_NAMES, _on_melody_choice)
	melody_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(melody_group)
	melody_buttons = melody_group.get_meta("choice_buttons")
	for index in melody_buttons.size():
		if not _melody_timbre_ready(index):
			melody_buttons[index].disabled = true
			melody_buttons[index].text += " · 待音频"
			melody_buttons[index].tooltip_text = "五个从低到高的声音文件全部到位后，这个选项会自动开放。"

	var ambience_group := _make_selector_group("选择背景声音", AMBIENCE_NAMES, _on_ambience_choice)
	ambience_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ambience_group)
	ambience_buttons = ambience_group.get_meta("choice_buttons")
	ambience_toggle_button = _make_button("背景：开", 92)
	ambience_toggle_button.toggle_mode = true
	ambience_toggle_button.pressed.connect(_toggle_ambience)
	var ambience_row: HBoxContainer = ambience_group.get_meta("button_row")
	ambience_row.add_child(ambience_toggle_button)
	return panel


func _make_selector_group(title_text: String, choices: Array, handler: Callable) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 5)
	var title_label := Label.new()
	title_label.text = title_text
	title_label.add_theme_color_override("font_color", MUTED)
	title_label.add_theme_font_size_override("font_size", 13)
	group.add_child(title_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	group.add_child(row)
	var buttons: Array = []
	for index in choices.size():
		var button := _make_button(choices[index], 0)
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(handler.bind(index))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.append(button)
		row.add_child(button)
	group.set_meta("choice_buttons", buttons)
	group.set_meta("button_row", row)
	return group


func _build_audio() -> void:
	for path in RHYTHM_PATHS:
		rhythm_streams.append(_load_audio(path))
	for path in PERCUSSION_PATHS:
		percussion_streams.append(_load_audio(path))
	for path in AMBIENCE_PATHS:
		var ambience_stream := _load_audio(path)
		if ambience_stream is AudioStreamWAV:
			var loop_stream := ambience_stream.duplicate() as AudioStreamWAV
			loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop_stream.loop_begin = 0
			loop_stream.loop_end = int(round(loop_stream.get_length() * loop_stream.mix_rate))
			ambience_stream = loop_stream
		ambience_streams.append(ambience_stream)

	for timbre_name in MELODY_PREFIXES:
		var timbre_streams: Array = []
		for note_key in NOTE_KEYS:
			timbre_streams.append(_load_optional_audio("res://assets/audio/soulmere_tone_%s_%s.wav" % [timbre_name, note_key]))
		melody_streams.append(timbre_streams)

	for track in track_names.size():
		var pool: Array = []
		for voice_index in 5:
			var player := AudioStreamPlayer.new()
			player.name = "Voice_%d_%d" % [track, voice_index]
			player.volume_db = TRACK_VOLUME_DB[track]
			add_child(player)
			pool.append(player)
		audio_voices.append({"pool": pool, "cursor": 0})

	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "ContinuousAmbience"
	ambience_player.volume_db = AMBIENCE_VOLUME_DB[ambience_choice]
	add_child(ambience_player)


func _load_audio(path: String) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream == null:
		push_error("无法载入音频：%s" % path)
	return stream


func _load_optional_audio(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


func _melody_timbre_ready(index: int) -> bool:
	if index < 0 or index >= melody_streams.size():
		return false
	for stream in melody_streams[index]:
		if stream == null:
			return false
	return true


func _trigger_step(step: int) -> void:
	for track in patterns.size():
		if not patterns[track][step]:
			continue
		if track == 0:
			_play_voice(track, rhythm_streams[rhythm_choice])
		elif track < NOTE_TRACK_START:
			_play_voice(track, percussion_streams[track - 1], 0.36 if track == 1 else -1.0)
		else:
			var note_index := track - NOTE_TRACK_START
			var length := int(note_lengths[note_index][step])
			var gate_seconds := 60.0 / BPM / 4.0 * length
			_play_voice(track, melody_streams[melody_choice][note_index], gate_seconds)


func _play_voice(track: int, stream: AudioStream, gate_seconds: float = -1.0) -> void:
	if stream == null:
		return
	var voice_data: Dictionary = audio_voices[track]
	var pool: Array = voice_data["pool"]
	var cursor: int = voice_data["cursor"]
	var player: AudioStreamPlayer = pool[cursor]
	if player.has_meta("gate_tween"):
		var previous_tween: Tween = player.get_meta("gate_tween")
		if previous_tween and previous_tween.is_valid():
			previous_tween.kill()
	player.volume_db = TRACK_VOLUME_DB[track]
	player.stream = stream
	player.play()
	if gate_seconds > 0.0:
		var fade_time := minf(0.08, gate_seconds * 0.35)
		var tween := create_tween()
		tween.tween_interval(maxf(0.01, gate_seconds - fade_time))
		tween.tween_property(player, "volume_db", -50.0, fade_time)
		tween.tween_callback(player.stop)
		player.set_meta("gate_tween", tween)
	voice_data["cursor"] = (cursor + 1) % pool.size()
	audio_voices[track] = voice_data


func _on_melody_choice(index: int) -> void:
	if not _melody_timbre_ready(index):
		status_label.text = "B 家旧掌机还缺少五个从低到高的声音文件，暂时不能选择。"
		_refresh_sound_selector()
		return
	melody_choice = index
	_refresh_sound_selector()
	_play_voice(NOTE_TRACK_START, melody_streams[melody_choice][0], 0.75)
	status_label.text = "主声音已换成：%s。下面五行会一起使用它。" % MELODY_NAMES[melody_choice]


func _on_ambience_choice(index: int) -> void:
	ambience_choice = index
	_refresh_sound_selector()
	_sync_ambience_playback(true)
	status_label.text = "背景声音已换成：%s。打开右侧开关即可听到。" % AMBIENCE_NAMES[ambience_choice]


func _toggle_ambience() -> void:
	ambience_enabled = not ambience_enabled
	_refresh_sound_selector()
	_sync_ambience_playback(true)
	status_label.text = "背景声音已%s。" % ("打开" if ambience_enabled else "关闭")


func _refresh_sound_selector() -> void:
	for index in melody_buttons.size():
		melody_buttons[index].set_pressed_no_signal(index == melody_choice)
	for index in ambience_buttons.size():
		ambience_buttons[index].set_pressed_no_signal(index == ambience_choice)
	if ambience_toggle_button:
		ambience_toggle_button.text = "背景：开" if ambience_enabled else "背景：关"
		ambience_toggle_button.set_pressed_no_signal(ambience_enabled)
func _sync_ambience_playback(restart: bool = false) -> void:
	if not ambience_player:
		return
	if not ambience_enabled:
		ambience_player.stop()
		return
	ambience_player.volume_db = AMBIENCE_VOLUME_DB[ambience_choice]
	if restart or ambience_player.stream != ambience_streams[ambience_choice] or not ambience_player.playing:
		ambience_player.stream = ambience_streams[ambience_choice]
		ambience_player.play()


func _toggle_playback() -> void:
	if is_playing:
		is_playing = false
		_sync_ambience_playback()
		play_button.text = "继续听"
		status_label.text = "已经暂停。点“继续听”会从开头再来一圈。"
		return
	play_started_usec = Time.get_ticks_usec()
	last_absolute_step = -1
	current_step = -1
	is_playing = true
	_sync_ambience_playback(true)
	play_button.text = "暂停"
	status_label.text = "正在重复播放。现在点格子，下一圈就会听到变化。"


func _stop_playback() -> void:
	is_playing = false
	current_step = -1
	last_absolute_step = -1
	play_button.text = "聆听"
	_sync_ambience_playback()
	for track_data in audio_voices:
		for player in track_data["pool"]:
			player.stop()
	_refresh_grid()
	status_label.text = "已经停止并回到开头。"


func _on_step_pressed(track: int, step: int) -> void:
	if track >= NOTE_TRACK_START:
		var note_index: int = track - NOTE_TRACK_START
		var current_length: int = note_lengths[note_index][step]
		var next_index: int = (NOTE_LENGTHS.find(current_length) + 1) % NOTE_LENGTHS.size()
		var next_length: int = NOTE_LENGTHS[next_index]
		note_lengths[note_index][step] = next_length
		patterns[track][step] = next_length > 0
		_refresh_grid()
		if next_length > 0:
			var gate_seconds := 60.0 / BPM / 4.0 * next_length
			_play_voice(track, melody_streams[melody_choice][note_index], gate_seconds)
			status_label.text = "%s · 第 %d 格 · %s" % [track_names[track], step + 1, _length_label(next_length)]
		else:
			status_label.text = "%s · 第 %d 格已关闭" % [track_names[track], step + 1]
		return

	var will_enable: bool = not patterns[track][step]
	if will_enable and _active_steps_in_track(track) >= track_limits[track]:
		_refresh_grid()
		status_label.text = "%s最多放入 %d 次。留一点空白，听起来会更清楚。" % [track_names[track], track_limits[track]]
		return
	patterns[track][step] = will_enable
	_refresh_grid()
	if patterns[track][step]:
		if track == 0:
			_play_voice(track, rhythm_streams[rhythm_choice])
		else:
			_play_voice(track, percussion_streams[track - 1], 0.36 if track == 1 else -1.0)
	status_label.text = "%s · 第 %d 格%s" % [track_names[track], step + 1, "会响" if patterns[track][step] else "不响"]


func _length_label(length: int, compact: bool = false) -> String:
	match length:
		1:
			return "短"
		2:
			return "中" if compact else "稍长"
		4:
			return "长"
		8:
			return "很长"
		_:
			return "不响"


func _active_steps_in_track(track: int) -> int:
	var count := 0
	for active in patterns[track]:
		if active:
			count += 1
	return count


func _clear_pattern() -> void:
	for track in patterns.size():
		for step in STEPS:
			patterns[track][step] = false
	for note_index in note_lengths.size():
		for step in STEPS:
			note_lengths[note_index][step] = 0
	ambience_enabled = false
	_refresh_sound_selector()
	_sync_ambience_playback()
	_refresh_grid()
	status_label.text = "所有格子和背景声音都已清空。"


func _refresh_grid() -> void:
	var active_count := 0
	for step in header_labels.size():
		var header: Label = header_labels[step]
		header.add_theme_color_override("font_color", CORAL if step == current_step else MUTED)

	for track in step_buttons.size():
		for step in STEPS:
			var active: bool = patterns[track][step]
			if active:
				active_count += 1
			var cell: Button = step_buttons[track][step]
			cell.set_pressed_no_signal(active)
			if track >= NOTE_TRACK_START and active:
				cell.text = _length_label(note_lengths[track - NOTE_TRACK_START][step], true)
				cell.tooltip_text = "%s · 第 %d 格 · %s" % [track_names[track], step + 1, _length_label(note_lengths[track - NOTE_TRACK_START][step])]
			else:
				cell.text = "●" if active else ""
				cell.tooltip_text = "%s · 第 %d 格" % [track_names[track], step + 1]
			var color: Color = track_colors[track]
			var base: Color = color.lightened(0.20) if active else Color("eee8d5")
			var border: Color = CORAL if step == current_step else (color.darkened(0.28) if active else Color("b8b09b"))
			var width := 2 if step == current_step else 1
			cell.add_theme_color_override("font_color", TEXT)
			cell.add_theme_stylebox_override("normal", _style(base, 3, border, width))
			cell.add_theme_stylebox_override("hover", _style(base.lightened(0.08), 3, color.darkened(0.25), 2))
			cell.add_theme_stylebox_override("pressed", _style(color.lightened(0.08), 3, CORAL, 2))
	if density_label:
		density_label.text = "已放入 %d 个声音%s" % [active_count, " · 背景已开" if ambience_enabled else ""]


func _save_record() -> void:
	var active_count := 0
	for row in patterns:
		for active in row:
			active_count += 1 if active else 0
	if active_count == 0 and not ambience_enabled:
		status_label.text = "还没有放入声音。请先点亮至少一个格子，或打开背景声音。"
		return

	var title := record_name.text.strip_edges()
	if title.is_empty():
		title = "唱片 %02d" % (records.size() + 1)

	var saved_patterns: Array = []
	for row in patterns:
		saved_patterns.append(row.duplicate())
	var saved_note_lengths: Array = []
	for row in note_lengths:
		saved_note_lengths.append(row.duplicate())

	records.push_front({
		"schema_version": 4,
		"title": title,
		"created_at": Time.get_datetime_string_from_system(false, true),
		"bpm": int(BPM),
		"patterns": saved_patterns,
		"note_lengths": saved_note_lengths,
		"rhythm_choice": rhythm_choice,
		"melody_choice": melody_choice,
		"ambience_choice": ambience_choice,
		"ambience_enabled": ambience_enabled
	})
	_write_records()
	record_name.clear()
	_refresh_collection()
	status_label.text = "《%s》已经保存到右侧。" % title


func _load_record(index: int) -> void:
	if index < 0 or index >= records.size():
		return
	_stop_playback()
	var record: Dictionary = records[index]
	var source_patterns: Array = record.get("patterns", [])
	var source_note_lengths: Array = record.get("note_lengths", [])
	if source_note_lengths.size() != note_lengths.size():
		status_label.text = "这张唱片的数据版本不兼容。"
		return

	var loaded_patterns: Array = []
	var old_ambience_enabled := false
	if source_patterns.size() == patterns.size():
		for row in source_patterns:
			loaded_patterns.append(row.duplicate())
	elif source_patterns.size() == 8:
		# 兼容旧版：木门、翻书、风声、五条旋律。
		for _track in patterns.size():
			loaded_patterns.append([false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false])
		loaded_patterns[0] = source_patterns[0].duplicate()
		loaded_patterns[3] = source_patterns[1].duplicate()
		for step in STEPS:
			if bool(source_patterns[2][step]):
				old_ambience_enabled = true
		for note_index in 5:
			loaded_patterns[NOTE_TRACK_START + note_index] = source_patterns[3 + note_index].duplicate()
	else:
		status_label.text = "这张唱片的数据版本不兼容。"
		return

	for track in patterns.size():
		for step in STEPS:
			patterns[track][step] = bool(loaded_patterns[track][step])
	for note_index in note_lengths.size():
		for step in STEPS:
			note_lengths[note_index][step] = int(source_note_lengths[note_index][step])
	rhythm_choice = clampi(int(record.get("rhythm_choice", 0)), 0, RHYTHM_NAMES.size() - 1)
	if int(record.get("schema_version", 2)) < 4:
		# 旧版的 0 / 1 代表玻璃瓶 / 玩具簧片琴；玻璃瓶退出旋律组后统一迁移到玩具簧片琴。
		melody_choice = 0
	else:
		melody_choice = clampi(int(record.get("melody_choice", 0)), 0, MELODY_NAMES.size() - 1)
		if not _melody_timbre_ready(melody_choice):
			melody_choice = 0
	ambience_choice = clampi(int(record.get("ambience_choice", 0)), 0, AMBIENCE_NAMES.size() - 1)
	ambience_enabled = bool(record.get("ambience_enabled", old_ambience_enabled))
	_refresh_sound_selector()
	_sync_ambience_playback(true)
	_refresh_grid()
	status_label.text = "已打开《%s》，可以聆听或继续修改。" % records[index].get("title", "未命名")


func _delete_record(index: int) -> void:
	if index < 0 or index >= records.size():
		return
	var title: String = records[index].get("title", "未命名")
	records.remove_at(index)
	_write_records()
	_refresh_collection()
	status_label.text = "已删除《%s》。" % title


func _refresh_collection() -> void:
	if not records_list:
		return
	for child in records_list.get_children():
		child.queue_free()

	if records.is_empty():
		empty_collection_label = Label.new()
		empty_collection_label.text = "这里还没有唱片。\n点一些格子，听听看，再保存第一张。"
		empty_collection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_collection_label.add_theme_color_override("font_color", MUTED)
		records_list.add_child(empty_collection_label)
		return

	for index in records.size():
		var record: Dictionary = records[index]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color("eee7cf"), 3, Color("aaa38e"), 1))
		records_list.add_child(card)

		var card_margin := MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 12)
		card_margin.add_theme_constant_override("margin_right", 10)
		card_margin.add_theme_constant_override("margin_top", 10)
		card_margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(card_margin)

		var row := HBoxContainer.new()
		card_margin.add_child(row)

		var marker := ColorRect.new()
		marker.color = track_colors[index % track_colors.size()]
		marker.custom_minimum_size = Vector2(7, 42)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(marker)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)

		var title := Label.new()
		title.text = record.get("title", "未命名")
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		info.add_child(title)

		var meta := Label.new()
		meta.text = "保存于 %s" % record.get("created_at", "")
		meta.add_theme_color_override("font_color", MUTED)
		meta.add_theme_font_size_override("font_size", 10)
		info.add_child(meta)

		var load_button := _make_button("打开", 48)
		load_button.pressed.connect(_load_record.bind(index))
		row.add_child(load_button)

		var delete_button := _make_button("删除", 58)
		delete_button.tooltip_text = "删除唱片"
		delete_button.pressed.connect(_delete_record.bind(index))
		row.add_child(delete_button)


func _load_records() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		records = parsed


func _write_records() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(records, "  "))


func _make_button(label: String, width: float) -> Button:
	var button := Button.new()
	button.text = label
	if width > 0:
		button.custom_minimum_size = Vector2(width, 42)
	else:
		button.custom_minimum_size = Vector2(0, 44)
	return button


func _paper_panel(fill: Color) -> StyleBoxFlat:
	var paper := _style(fill, 7, Color("b5aa91"), 1)
	paper.shadow_color = Color("8068493b")
	paper.shadow_size = 6
	paper.shadow_offset = Vector2(5, 6)
	return paper


func _add_tape(at: Vector2, tape_size: Vector2, degrees: float, tape_color: Color) -> void:
	var tape := ColorRect.new()
	tape.color = tape_color
	tape.position = at
	tape.size = tape_size
	tape.rotation = deg_to_rad(degrees)
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tape)


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _style(fill: Color, radius: int, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.border_color = border
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.content_margin_left = 9
	box.content_margin_right = 9
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box
