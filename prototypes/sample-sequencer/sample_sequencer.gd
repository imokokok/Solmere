extends Control

const STEPS := 16
const BPM := 78.0
const NOTE_START := 3
const NOTE_LENGTHS := [0, 1, 2, 4, 8]
const SAVE_PATH := "user://sequencer_draft.json"
const TRACK_NAMES := [
	"社区中心木门", "书店书页", "瞭望台风声", "A家陶瓷花盆",
	"果蔬摊老式秤盘", "杂货店玻璃瓶", "公交站金属杆", "塔罗店饰品",
]
const TRACK_COLORS := [
	Color("e56f58"), Color("65b9df"), Color("9b7bd5"), Color("d7e74a"),
	Color("62d1b4"), Color("e8b957"), Color("dc86ab"), Color("7da4e2"),
]
const NOTE_FREQUENCIES := [130.81, 146.83, 164.81, 196.00, 220.00]

const BG := Color("0b0e12")
const PANEL := Color("131820")
const CELL := Color("11171e")
const LINE := Color("2a323d")
const TEXT := Color("e7e5df")
const MUTED := Color("8e98a6")
const ACCENT := Color("e8ff59")

var patterns := [
	[true, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false],
	[false, false, true, false, false, false, true, false, false, false, true, false, false, false, true, false],
	[true, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false],
	[true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true],
	[false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false],
	[false, false, false, false, true, false, false, false, false, false, true, false, false, false, false, false],
	[false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false],
	[false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false],
]
var note_lengths := [
	[4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
	[0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0],
]

var step_buttons: Array = []
var step_labels: Array = []
var streams: Array = []
var voices: Array = []
var play_button: Button
var status_label: Label
var density_label: Label
var is_playing := false
var play_started_usec := 0
var last_absolute_step := -1
var current_step := -1


func _ready() -> void:
	_build_theme()
	_build_audio()
	_build_ui()
	_refresh_grid()


func _process(_delta: float) -> void:
	if not is_playing:
		return
	var step_duration := 60.0 / BPM / 4.0
	var elapsed := (Time.get_ticks_usec() - play_started_usec) / 1000000.0
	var target_step := int(floor(elapsed / step_duration))
	for absolute_step in range(maxi(last_absolute_step + 1, target_step - 1), target_step + 1):
		_trigger_step(absolute_step % STEPS)
	last_absolute_step = target_step
	var next_step := target_step % STEPS
	if next_step != current_step:
		current_step = next_step
		_refresh_grid()


func _build_theme() -> void:
	var ui_theme := Theme.new()
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC", "Arial Unicode MS"])
	ui_theme.default_font = system_font
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", TEXT)
	ui_theme.set_color("font_color", "Button", TEXT)
	ui_theme.set_stylebox("normal", "Button", _style(Color("181e27"), 8, LINE, 1))
	ui_theme.set_stylebox("hover", "Button", _style(Color("202936"), 8, MUTED, 1))
	ui_theme.set_stylebox("pressed", "Button", _style(Color("2a3440"), 8, ACCENT, 2))
	ui_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme = ui_theme


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	background.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 42)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)

	var eyebrow := Label.new()
	eyebrow.text = "SOULMERE PROTOTYPE  /  声音采样"
	eyebrow.add_theme_color_override("font_color", ACCENT)
	page.add_child(eyebrow)
	var title := Label.new()
	title.text = "把小镇的声音排成一段循环"
	title.add_theme_font_size_override("font_size", 34)
	page.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "节奏与环境音点击开关；五条旋律轨固定为 C3、D3、E3、G3、A3。"
	subtitle.add_theme_color_override("font_color", MUTED)
	page.add_child(subtitle)

	var transport := HBoxContainer.new()
	transport.add_theme_constant_override("separation", 10)
	page.add_child(transport)
	play_button = _button("▶ 播放", _toggle_playback, 120)
	transport.add_child(play_button)
	transport.add_child(_button("■ 停止", _stop_playback, 100))
	transport.add_child(_button("清空", _clear, 90))
	transport.add_child(_button("保存草稿", _save_draft, 120))
	transport.add_child(_button("载入草稿", _load_draft, 120))
	var tempo := Label.new()
	tempo.text = "78 BPM  ·  4/4  ·  16 格"
	tempo.size_flags_horizontal = SIZE_EXPAND_FILL
	tempo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tempo.add_theme_color_override("font_color", MUTED)
	transport.add_child(tempo)
	density_label = Label.new()
	density_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	density_label.add_theme_color_override("font_color", ACCENT)
	transport.add_child(density_label)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PANEL, 14, LINE, 1))
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	page.add_child(panel)
	var panel_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		panel_margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(panel_margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel_margin.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = STEPS + 1
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 9)
	grid.custom_minimum_size = Vector2(1120, 460)
	scroll.add_child(grid)
	var corner := Label.new()
	corner.text = "声音来源"
	corner.custom_minimum_size = Vector2(210, 30)
	corner.add_theme_color_override("font_color", MUTED)
	grid.add_child(corner)
	for step in STEPS:
		var number := Label.new()
		number.text = str(step + 1)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.custom_minimum_size = Vector2(46, 30)
		number.add_theme_color_override("font_color", MUTED)
		step_labels.append(number)
		grid.add_child(number)
	for track in TRACK_NAMES.size():
		var track_name := Label.new()
		track_name.text = TRACK_NAMES[track]
		track_name.custom_minimum_size = Vector2(210, 44)
		track_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		track_name.add_theme_color_override("font_color", TRACK_COLORS[track])
		grid.add_child(track_name)
		var row: Array = []
		for step in STEPS:
			var cell := _button("", _on_cell.bind(track, step), 46)
			cell.custom_minimum_size.y = 44
			cell.focus_mode = Control.FOCUS_NONE
			row.append(cell)
			grid.add_child(cell)
		step_buttons.append(row)

	var help := Label.new()
	help.text = "旋律格循环：关闭 → 1 → 2 → 4 → 8 格时值。固定五声音阶让自由组合仍保持舒缓、和谐。"
	help.add_theme_color_override("font_color", MUTED)
	page.add_child(help)
	status_label = Label.new()
	status_label.text = "已载入平衡的起始编排，可以直接播放。"
	status_label.add_theme_color_override("font_color", MUTED)
	page.add_child(status_label)


func _button(text_value: String, action: Callable, width: float) -> Button:
	var node := Button.new()
	node.text = text_value
	node.custom_minimum_size = Vector2(width, 42)
	node.pressed.connect(action)
	return node


func _build_audio() -> void:
	streams = [[_synth("kick", 0.46)], [_synth("click", 0.18)], [_synth("texture", 1.65)], [], [], [], [], []]
	var step_duration := 60.0 / BPM / 4.0
	for note_index in NOTE_FREQUENCIES.size():
		for length_value in NOTE_LENGTHS.slice(1):
			var length := int(length_value)
			streams[NOTE_START + note_index].append(_synth("note", step_duration * length + 0.32, NOTE_FREQUENCIES[note_index], note_index, step_duration * length))
	for track in TRACK_NAMES.size():
		var pool: Array = []
		for voice_index in 5:
			var player := AudioStreamPlayer.new()
			player.name = "Voice_%d_%d" % [track, voice_index]
			player.volume_db = [-5.0, -11.0, -15.0, -14.0, -14.0, -14.0, -14.0, -15.0][track]
			add_child(player)
			pool.append(player)
		voices.append({"pool": pool, "cursor": 0})


func _trigger_step(step: int) -> void:
	for track in patterns.size():
		if not patterns[track][step]:
			continue
		var stream: AudioStream = streams[track][0]
		if track >= NOTE_START:
			stream = _note_stream(track, note_lengths[track - NOTE_START][step])
		_play_voice(track, stream)


func _note_stream(track: int, length: int) -> AudioStream:
	return streams[track][maxi(0, NOTE_LENGTHS.find(length) - 1)]


func _play_voice(track: int, stream: AudioStream) -> void:
	var voice: Dictionary = voices[track]
	var player: AudioStreamPlayer = voice.pool[voice.cursor]
	player.stream = stream
	player.play()
	voice.cursor = (int(voice.cursor) + 1) % voice.pool.size()
	voices[track] = voice


func _toggle_playback() -> void:
	if is_playing:
		is_playing = false
		play_button.text = "▶ 继续"
		status_label.text = "已暂停。"
		return
	play_started_usec = Time.get_ticks_usec()
	last_absolute_step = -1
	current_step = -1
	is_playing = true
	play_button.text = "Ⅱ 暂停"
	status_label.text = "正在循环播放。"


func _stop_playback() -> void:
	is_playing = false
	current_step = -1
	last_absolute_step = -1
	play_button.text = "▶ 播放"
	for voice in voices:
		for player in voice.pool:
			player.stop()
	_refresh_grid()
	status_label.text = "已停止并回到开头。"


func _on_cell(track: int, step: int) -> void:
	if track >= NOTE_START:
		var note_index := track - NOTE_START
		var current: int = note_lengths[note_index][step]
		var next: int = NOTE_LENGTHS[(NOTE_LENGTHS.find(current) + 1) % NOTE_LENGTHS.size()]
		note_lengths[note_index][step] = next
		patterns[track][step] = next > 0
		if next > 0:
			_play_voice(track, _note_stream(track, next))
	else:
		patterns[track][step] = not bool(patterns[track][step])
		if patterns[track][step]:
			_play_voice(track, streams[track][0])
	_refresh_grid()


func _clear() -> void:
	for track in patterns.size():
		for step in STEPS:
			patterns[track][step] = false
	for note_index in note_lengths.size():
		for step in STEPS:
			note_lengths[note_index][step] = 0
	_refresh_grid()
	status_label.text = "编排已清空。"


func _refresh_grid() -> void:
	var count := 0
	for step in step_labels.size():
		step_labels[step].add_theme_color_override("font_color", ACCENT if step == current_step else MUTED)
	for track in step_buttons.size():
		for step in STEPS:
			var active: bool = patterns[track][step]
			if active:
				count += 1
			var cell: Button = step_buttons[track][step]
			cell.text = str(note_lengths[track - NOTE_START][step]) if track >= NOTE_START and active else ("●" if active else "")
			var base: Color = TRACK_COLORS[track].darkened(0.68) if active else CELL
			var border: Color = ACCENT if step == current_step else (TRACK_COLORS[track] if active else LINE)
			cell.add_theme_color_override("font_color", TRACK_COLORS[track].lightened(0.2))
			cell.add_theme_stylebox_override("normal", _style(base, 8, border, 2 if step == current_step else 1))
	if density_label:
		density_label.text = "%d 个触发点" % count


func _save_draft() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		status_label.text = "草稿保存失败。"
		return
	file.store_string(JSON.stringify({"version": 1, "patterns": patterns, "note_lengths": note_lengths}, "  "))
	status_label.text = "草稿已保存到这个 Prototype 的用户目录。"


func _load_draft() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		status_label.text = "还没有保存过草稿。"
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary or parsed.get("version", 0) != 1:
		status_label.text = "草稿格式无法读取。"
		return
	var saved_patterns = parsed.get("patterns", [])
	var saved_lengths = parsed.get("note_lengths", [])
	if not saved_patterns is Array or saved_patterns.size() != patterns.size() or not saved_lengths is Array or saved_lengths.size() != note_lengths.size():
		status_label.text = "草稿结构不完整。"
		return
	patterns = saved_patterns.duplicate(true)
	note_lengths = saved_lengths.duplicate(true)
	_refresh_grid()
	status_label.text = "草稿已载入。"


func _synth(kind: String, duration: float, frequency := 0.0, timbre := 0, gate_duration := 0.0) -> AudioStreamWAV:
	var sample_rate := 44100
	var sample_count := int(duration * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 27031996
	for index in sample_count:
		var t := float(index) / sample_rate
		var value := 0.0
		match kind:
			"kick":
				value = (sin(TAU * (65.41 * t - 15.0 * t * t)) * exp(-8.0 * t) + sin(TAU * 420.0 * t) * exp(-70.0 * t) * 0.1) * 0.82
			"click":
				value = (rng.randf_range(-1.0, 1.0) * 0.32 + (sin(TAU * 920.0 * t) + sin(TAU * 1380.0 * t) * 0.35) * 0.42) * exp(-22.0 * t) * 0.52
			"texture":
				var texture_envelope: float = minf(1.0, t / 0.08) * exp(-1.55 * t)
				value = (sin(TAU * 65.41 * t) * 0.28 + sin(TAU * 98.0 * t) * 0.18 + rng.randf_range(-1.0, 1.0) * 0.025) * texture_envelope
			"note":
				var body := sin(TAU * frequency * t)
				if timbre == 1: body += sin(TAU * frequency * 2.0 * t) * 0.20
				elif timbre == 2: body += sin(TAU * frequency * 2.01 * t) * 0.14 + rng.randf_range(-1.0, 1.0) * 0.018
				elif timbre == 3: body += sin(TAU * frequency * 2.01 * t) * 0.16 + sin(TAU * frequency * 3.98 * t) * 0.045
				elif timbre == 4: body = body * 0.84 + sin(TAU * frequency * 2.0 * t) * 0.07 + rng.randf_range(-1.0, 1.0) * 0.012
				else: body += sin(TAU * frequency * 2.0 * t) * 0.08
				var release := exp(-9.0 * (t - gate_duration)) if t > gate_duration else 1.0
				value = body * minf(1.0, t / (0.022 + timbre * 0.004)) * release * (0.84 + 0.16 * exp(-1.4 * t)) * 0.44
		bytes.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav


func _style(fill: Color, radius: int, border := Color.TRANSPARENT, border_width := 0) -> StyleBoxFlat:
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
