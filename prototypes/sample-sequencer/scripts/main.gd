extends Control

const STEPS := 16
const BPM := 78.0
const SAVE_PATH := "user://sample_records.json"
const NOTE_TRACK_START := 3
const NOTE_LENGTHS := [0, 1, 2, 4, 8]

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
	[false, false, true, false, false, false, true, false, false, false, true, false, false, false, true, false],
	[true, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false],
	[true, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true],
	[false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false],
	[false, false, false, false, true, false, false, false, false, false, true, false, false, false, false, false],
	[false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false],
	[false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false]
]

# 五条音轨分别锁定 C3、D3、E3、G3、A3；每个起音可持续 1、2、4 或 8 格。
var note_frequencies := [130.81, 146.83, 164.81, 196.00, 220.00]
var note_lengths := [
	[4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
	[0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0]
]
var track_names := [
	"社区中心木门",
	"书店书页",
	"瞭望台风声",
	"A家陶瓷花盆",
	"果蔬摊老式秤盘",
	"杂货店玻璃瓶",
	"公交站金属杆",
	"塔罗店饰品"
]
var track_colors := [CORAL, BLUE, VIOLET, ACCENT, TEAL, GOLD, PINK, Color("8fb4ff")]
# 节奏轨保持原有密度限制；固定音高轨允许更自由地实验。
var track_limits := [6, 8, 3, 8, 8, 8, 8, 8]

var step_buttons: Array = []
var header_labels: Array = []
var audio_voices: Array = []
var streams: Array = []
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
	title.text = "把今天，做成一张唱片"
	title.add_theme_font_size_override("font_size", 38)
	page.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "声音手作桌  /  采样 → 排列 → 听一遍 → 收藏"
	subtitle.add_theme_color_override("font_color", MUTED)
	subtitle.add_theme_font_size_override("font_size", 18)
	page.add_child(subtitle)
	var title_rule := ColorRect.new()
	title_rule.color = CORAL
	title_rule.custom_minimum_size = Vector2(430, 4)
	title_rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.add_child(title_rule)

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

	var transport := HBoxContainer.new()
	studio.add_child(transport)

	play_button = _make_button("播放", 108)
	play_button.pressed.connect(_toggle_playback)
	transport.add_child(play_button)

	var stop_button := _make_button("停止", 92)
	stop_button.pressed.connect(_stop_playback)
	transport.add_child(stop_button)

	var clear_button := _make_button("清空", 72)
	clear_button.pressed.connect(_clear_pattern)
	transport.add_child(clear_button)

	var tempo := Label.new()
	tempo.text = "78 BPM  ·  4/4  ·  16 格"
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
	grid.custom_minimum_size = Vector2(1035, 430)
	scroll.add_child(grid)

	var corner := Label.new()
	corner.text = "声音来源"
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
	note.text = "固定音高：C3 · D3 · E3 · G3 · A3　｜　每格依次切换：关闭 → 1 → 2 → 4 → 8 格"
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
	collection_title.text = "唱片收藏夹"
	collection_title.add_theme_font_size_override("font_size", 24)
	collection.add_child(collection_title)

	var collection_hint := Label.new()
	collection_hint.text = "为这段排列记下名字，之后可以载入继续修改。"
	collection_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	collection_hint.add_theme_color_override("font_color", MUTED)
	collection_hint.add_theme_font_size_override("font_size", 14)
	collection.add_child(collection_hint)

	record_name = LineEdit.new()
	record_name.placeholder_text = "给这张唱片取名"
	record_name.max_length = 24
	collection.add_child(record_name)

	var save_button := _make_button("保存为唱片", 0)
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
	empty_collection_label.text = "还没有唱片。\n调整格子后保存第一张作品。"
	empty_collection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_collection_label.add_theme_color_override("font_color", MUTED)
	records_list.add_child(empty_collection_label)

	status_label = Label.new()
	status_label.text = "已铺好一段起始排列。点击格子调整，播放后再保存。"
	status_label.add_theme_color_override("font_color", MUTED)
	status_label.add_theme_font_size_override("font_size", 14)
	page.add_child(status_label)

	_add_tape(Vector2(438, 133), Vector2(104, 24), -3.0, Color("c9bd8599"))
	_add_tape(Vector2(1310, 132), Vector2(112, 25), 2.0, Color("d1b96f99"))


func _build_audio() -> void:
	streams = [
		[_make_kick_stream()],
		[_make_click_stream()],
		[_make_texture_stream()],
		[], [], [], [], []
	]
	var step_duration := 60.0 / BPM / 4.0
	for note_index in note_frequencies.size():
		for length_value in NOTE_LENGTHS.slice(1):
			var length: int = int(length_value)
			streams[NOTE_TRACK_START + note_index].append(
				_make_note_stream(float(note_frequencies[note_index]), step_duration * length, note_index)
			)

	for track in track_names.size():
		var pool: Array = []
		for voice_index in 5:
			var player := AudioStreamPlayer.new()
			player.name = "Voice_%d_%d" % [track, voice_index]
			player.volume_db = [-5.0, -11.0, -15.0, -14.0, -14.0, -14.0, -14.0, -15.0][track]
			add_child(player)
			pool.append(player)
		audio_voices.append({"pool": pool, "cursor": 0})


func _trigger_step(step: int) -> void:
	for track in patterns.size():
		if not patterns[track][step]:
			continue
		var stream: AudioStream = streams[track][0]
		if track >= NOTE_TRACK_START:
			var duration: int = int(note_lengths[track - NOTE_TRACK_START][step])
			stream = _note_stream_for_length(track, duration)
		_play_voice(track, stream)


func _note_stream_for_length(track: int, length: int) -> AudioStream:
	var stream_index: int = NOTE_LENGTHS.find(length) - 1
	if stream_index < 0:
		stream_index = 0
	return streams[track][stream_index]


func _play_voice(track: int, stream: AudioStream) -> void:
	var voice_data: Dictionary = audio_voices[track]
	var pool: Array = voice_data["pool"]
	var cursor: int = voice_data["cursor"]
	var player: AudioStreamPlayer = pool[cursor]
	player.stream = stream
	player.play()
	voice_data["cursor"] = (cursor + 1) % pool.size()
	audio_voices[track] = voice_data


func _toggle_playback() -> void:
	if is_playing:
		is_playing = false
		play_button.text = "继续"
		status_label.text = "已暂停。"
		return
	play_started_usec = Time.get_ticks_usec()
	last_absolute_step = -1
	current_step = -1
	is_playing = true
	play_button.text = "暂停"
	status_label.text = "正在循环播放。修改格子会在下一次经过时生效。"


func _stop_playback() -> void:
	is_playing = false
	current_step = -1
	last_absolute_step = -1
	play_button.text = "播放"
	for track_data in audio_voices:
		for player in track_data["pool"]:
			player.stop()
	_refresh_grid()
	status_label.text = "已停止并回到开头。"


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
			_play_voice(track, _note_stream_for_length(track, next_length))
			status_label.text = "%s · 第 %d 格 · 持续 %d 格" % [track_names[track], step + 1, next_length]
		else:
			status_label.text = "%s · 第 %d 格已关闭" % [track_names[track], step + 1]
		return

	var will_enable: bool = not patterns[track][step]
	if will_enable and _active_steps_in_track(track) >= track_limits[track]:
		_refresh_grid()
		status_label.text = "%s最多使用 %d 格，留一点空间会更清楚。" % [track_names[track], track_limits[track]]
		return
	patterns[track][step] = will_enable
	_refresh_grid()
	if patterns[track][step]:
		_play_voice(track, streams[track][0])
	status_label.text = "%s · 第 %d 格%s" % [track_names[track], step + 1, "已点亮" if patterns[track][step] else "已关闭"]


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
	_refresh_grid()
	status_label.text = "编排已清空。"


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
				cell.text = str(note_lengths[track - NOTE_TRACK_START][step])
				cell.tooltip_text = "%s · 第 %d 格 · 持续 %d 格" % [track_names[track], step + 1, note_lengths[track - NOTE_TRACK_START][step]]
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
		density_label.text = "%d 个触发点" % active_count


func _save_record() -> void:
	var active_count := 0
	for row in patterns:
		for active in row:
			active_count += 1 if active else 0
	if active_count == 0:
		status_label.text = "空白编排不会生成唱片，请先点亮至少一个格子。"
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
		"schema_version": 2,
		"title": title,
		"created_at": Time.get_datetime_string_from_system(false, true),
		"bpm": int(BPM),
		"patterns": saved_patterns,
		"note_lengths": saved_note_lengths
	})
	_write_records()
	record_name.clear()
	_refresh_collection()
	status_label.text = "《%s》已压制成唱片并放入收藏。" % title


func _load_record(index: int) -> void:
	if index < 0 or index >= records.size():
		return
	_stop_playback()
	var source_patterns: Array = records[index].get("patterns", [])
	var source_note_lengths: Array = records[index].get("note_lengths", [])
	if source_patterns.size() != patterns.size() or source_note_lengths.size() != note_lengths.size():
		status_label.text = "这张唱片的数据版本不兼容。"
		return
	for track in patterns.size():
		for step in STEPS:
			patterns[track][step] = bool(source_patterns[track][step])
	for note_index in note_lengths.size():
		for step in STEPS:
			note_lengths[note_index][step] = int(source_note_lengths[note_index][step])
	_refresh_grid()
	status_label.text = "已载入《%s》，可以播放或继续修改。" % records[index].get("title", "未命名")


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
		empty_collection_label.text = "还没有唱片。\n调整格子后保存第一张作品。"
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
		meta.text = "%s · %s BPM" % [record.get("created_at", ""), record.get("bpm", int(BPM))]
		meta.add_theme_color_override("font_color", MUTED)
		meta.add_theme_font_size_override("font_size", 10)
		info.add_child(meta)

		var load_button := _make_button("载入", 48)
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


func _make_kick_stream() -> AudioStreamWAV:
	return _synthesize("kick", 0.46)


func _make_click_stream() -> AudioStreamWAV:
	return _synthesize("click", 0.18)


func _make_note_stream(frequency: float, gate_duration: float, timbre: int) -> AudioStreamWAV:
	return _synthesize("note", gate_duration + 0.32, frequency, timbre, gate_duration)


func _make_texture_stream() -> AudioStreamWAV:
	return _synthesize("texture", 1.65)


func _synthesize(kind: String, duration: float, frequency: float = 0.0, timbre: int = 0, gate_duration: float = 0.0) -> AudioStreamWAV:
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
				var envelope := exp(-8.0 * t)
				var phase := TAU * (65.41 * t - 15.0 * t * t)
				var click := sin(TAU * 420.0 * t) * exp(-70.0 * t) * 0.10
				value = sin(phase) * envelope * 0.82 + click
			"click":
				var noise := rng.randf_range(-1.0, 1.0)
				var metallic := sin(TAU * 920.0 * t) + sin(TAU * 1380.0 * t) * 0.35
				value = (noise * 0.32 + metallic * 0.42) * exp(-22.0 * t) * 0.52
			"note":
				var body := sin(TAU * frequency * t)
				match timbre:
					0: # C：圆润，接近柔和正弦音。
						body += sin(TAU * frequency * 2.0 * t) * 0.08
					1: # D：略空心的木质感。
						body += sin(TAU * frequency * 2.0 * t) * 0.20
					2: # E：带一点柔和颗粒。
						body += sin(TAU * frequency * 2.01 * t) * 0.14
						body += rng.randf_range(-1.0, 1.0) * 0.018
					3: # G：很轻的钟感。
						body += sin(TAU * frequency * 2.01 * t) * 0.16
						body += sin(TAU * frequency * 3.98 * t) * 0.045
					4: # A：更薄、更有空气感。
						body = body * 0.84 + sin(TAU * frequency * 2.0 * t) * 0.07
						body += rng.randf_range(-1.0, 1.0) * 0.012
				var attack: float = minf(1.0, t / (0.022 + timbre * 0.004))
				var release := 1.0
				if t > gate_duration:
					release = exp(-9.0 * (t - gate_duration))
				var gentle_decay := 0.84 + 0.16 * exp(-1.4 * t)
				value = body * attack * release * gentle_decay * 0.44
			"texture":
				# 开放五度 C2 + G2，与 C 大调五声音阶保持一致。
				var shimmer := sin(TAU * 65.41 * t) * 0.28 + sin(TAU * 98.0 * t) * 0.18
				var dust := rng.randf_range(-1.0, 1.0) * 0.025
				var texture_envelope: float = minf(1.0, t / 0.08) * exp(-1.55 * t)
				value = (shimmer + dust) * texture_envelope
		value = clampf(value, -1.0, 1.0)
		var encoded := int(value * 32767.0)
		if encoded < 0:
			encoded += 65536
		bytes[index * 2] = encoded & 0xff
		bytes[index * 2 + 1] = (encoded >> 8) & 0xff

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav


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
