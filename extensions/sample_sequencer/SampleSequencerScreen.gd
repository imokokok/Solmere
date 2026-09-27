extends Control

const ArrangementModel = preload("res://extensions/sample_sequencer/SequencerArrangement.gd")
const STEPS := 16
const BARS_ON_RECORD := 4
const BPM := 78.0
const NOTE_TRACK_START := 3
const NOTE_LENGTHS := [0, 1, 2, 4, 8]
const TRACK_NAMES := [
	"社区中心木门", "书店书页", "瞭望台风声", "A家陶瓷花盆",
	"果蔬摊老式秤盘", "杂货店玻璃瓶", "公交站金属杆", "塔罗店饰品",
]
const TRACK_COLORS := [
	Color("bd5b49"), Color("3988a8"), Color("7558a8"), Color("839719"),
	Color("3d927c"), Color("b1812c"), Color("b55c83"), Color("557bb5"),
]
const TRACK_LIMITS := [6, 8, 3, 8, 8, 8, 8, 8]
const NOTE_FREQUENCIES := [130.81, 146.83, 164.81, 196.00, 220.00]

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

var timeline_studio: Control
var step_buttons: Array = []
var header_labels: Array = []
var voices: Array = []
var streams: Array = []
var play_button: Button
var status: Label
var density_label: Label
var is_playing := false
var play_started_usec := 0
var last_absolute_step := -1
var current_step := -1
var monitor_locked := false


func _ready() -> void:
	add_to_group("meta_modal")
	theme = preload("res://scripts/ui/components/interface_palette.gd").theme_for_tools()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	if has_node("/root/WorldSound"):
		get_node("/root/WorldSound").lock_monitor(true)
		monitor_locked = true
	_build_audio()
	_load_draft()
	_build_ui()
	_refresh_grid()
	set_process(true)


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("f3eddd")
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 42)
	scroll.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)

	var header := HBoxContainer.new()
	page.add_child(header)
	var title := label("唱片店 · 格子音序器", 32)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(button("返回时间线", _return_to_timeline))
	page.add_child(label("把收集到的声音排成一小段循环。旋律固定在 C、D、E、G、A，怎样组合都保持在同一套音阶里。", 17))

	var transport := HFlowContainer.new()
	transport.add_theme_constant_override("h_separation", 10)
	page.add_child(transport)
	play_button = button("▶ 播放", _toggle_playback)
	transport.add_child(play_button)
	transport.add_child(button("■ 停止", _stop_playback))
	transport.add_child(button("清空", _clear_pattern))
	transport.add_child(label("78 BPM · 4/4 · 编辑 1 小节 · 压片时循环 4 小节", 15))
	density_label = label("", 15)
	transport.add_child(density_label)

	var grid_scroll := ScrollContainer.new()
	grid_scroll.custom_minimum_size.y = 430
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	page.add_child(grid_scroll)
	var grid := GridContainer.new()
	grid.columns = STEPS + 1
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 7)
	grid.custom_minimum_size.x = 1020
	grid_scroll.add_child(grid)
	var corner := label("声音来源", 14)
	corner.custom_minimum_size = Vector2(190, 30)
	grid.add_child(corner)
	for step in STEPS:
		var number := label(str(step + 1), 13)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.custom_minimum_size = Vector2(42, 30)
		header_labels.append(number)
		grid.add_child(number)
	for track in TRACK_NAMES.size():
		var name_label := label(TRACK_NAMES[track], 14)
		name_label.custom_minimum_size = Vector2(190, 40)
		name_label.add_theme_color_override("font_color", TRACK_COLORS[track])
		grid.add_child(name_label)
		var row: Array = []
		for step in STEPS:
			var cell := button("", _on_step_pressed.bind(track, step))
			cell.custom_minimum_size = Vector2(42, 40)
			cell.focus_mode = Control.FOCUS_NONE
			row.append(cell)
			grid.add_child(cell)
		step_buttons.append(row)

	var footer := HBoxContainer.new()
	page.add_child(footer)
	var guide := label("节奏轨点击开关；五条旋律轨依次切换：关闭 → 1 → 2 → 4 → 8 格。\n制作唱片会生成约 12.3 秒的作品，再进入现有封面与压片流程。", 15)
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(guide)
	footer.add_child(button("制作唱片", request_visual))
	status = label("已载入一个平衡的起始循环，可以直接试听。", 15)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(status)


func label(text_value: String, font_size: int = 16) -> Label:
	var node := Label.new()
	node.text = LocalizationSystem.text(text_value)
	node.add_theme_font_size_override("font_size", maxi(18, font_size))
	return node


func button(text_value: String, action: Callable) -> Button:
	var node := preload("res://scripts/ui/components/solmere_button.gd").new()
	node.variant = "primary" if text_value in ["▶ 播放", "制作唱片"] else "paper"
	node.custom_minimum_size.y = 43
	node.add_theme_font_size_override("font_size", 20)
	node.text = LocalizationSystem.text(text_value)
	node.pressed.connect(action)
	return node


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


func _build_audio() -> void:
	streams = [[_synthesize("kick", 0.46)], [_synthesize("click", 0.18)], [_synthesize("texture", 1.65)], [], [], [], [], []]
	var step_duration := 60.0 / BPM / 4.0
	for note_index in NOTE_FREQUENCIES.size():
		for length_value in NOTE_LENGTHS.slice(1):
			var length := int(length_value)
			streams[NOTE_TRACK_START + note_index].append(_synthesize("note", step_duration * length + 0.32, NOTE_FREQUENCIES[note_index], note_index, step_duration * length))
	for track in TRACK_NAMES.size():
		var pool: Array = []
		for voice_index in 5:
			var player := AudioStreamPlayer.new()
			player.name = "SequencerVoice_%d_%d" % [track, voice_index]
			player.bus = "Music"
			player.volume_db = [-5.0, -11.0, -15.0, -14.0, -14.0, -14.0, -14.0, -15.0][track]
			add_child(player)
			pool.append(player)
		voices.append({"pool": pool, "cursor": 0})


func _trigger_step(step: int) -> void:
	for track in patterns.size():
		if not patterns[track][step]:
			continue
		var stream: AudioStream = streams[track][0]
		if track >= NOTE_TRACK_START:
			stream = _note_stream(track, note_lengths[track - NOTE_TRACK_START][step])
		_play_voice(track, stream)


func _note_stream(track: int, length: int) -> AudioStream:
	return streams[track][maxi(0, NOTE_LENGTHS.find(length) - 1)]


func _play_voice(track: int, stream: AudioStream) -> void:
	var data: Dictionary = voices[track]
	var pool: Array = data.pool
	var cursor: int = data.cursor
	var player: AudioStreamPlayer = pool[cursor]
	player.stream = stream
	player.play()
	data.cursor = (cursor + 1) % pool.size()
	voices[track] = data


func _toggle_playback() -> void:
	if is_playing:
		is_playing = false
		play_button.text = LocalizationSystem.text("▶ 继续")
		status.text = LocalizationSystem.text("已暂停。")
		return
	play_started_usec = Time.get_ticks_usec()
	last_absolute_step = -1
	current_step = -1
	is_playing = true
	play_button.text = LocalizationSystem.text("Ⅱ 暂停")
	status.text = LocalizationSystem.text("正在循环播放；修改会在下一次经过时生效。")


func _stop_playback() -> void:
	is_playing = false
	current_step = -1
	last_absolute_step = -1
	play_button.text = LocalizationSystem.text("▶ 播放")
	for data in voices:
		for player in data.pool:
			player.stop()
	_refresh_grid()


func _on_step_pressed(track: int, step: int) -> void:
	if track >= NOTE_TRACK_START:
		var note_index := track - NOTE_TRACK_START
		var current_length: int = note_lengths[note_index][step]
		var next_length: int = NOTE_LENGTHS[(NOTE_LENGTHS.find(current_length) + 1) % NOTE_LENGTHS.size()]
		note_lengths[note_index][step] = next_length
		patterns[track][step] = next_length > 0
		if next_length > 0:
			_play_voice(track, _note_stream(track, next_length))
	else:
		var will_enable: bool = not bool(patterns[track][step])
		if will_enable and _active_steps(track) >= TRACK_LIMITS[track]:
			status.text = LocalizationSystem.text("%s 最多使用 %d 格，留一点空间会更清楚。" % [TRACK_NAMES[track], TRACK_LIMITS[track]])
			_refresh_grid()
			return
		patterns[track][step] = will_enable
		if will_enable:
			_play_voice(track, streams[track][0])
	_save_draft(false)
	_refresh_grid()


func _active_steps(track: int) -> int:
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
	_save_draft(false)
	_refresh_grid()
	status.text = LocalizationSystem.text("编排已清空。")


func _refresh_grid() -> void:
	var active_count := 0
	for step in header_labels.size():
		header_labels[step].modulate = Color("8c761d") if step == current_step else Color.WHITE
	for track in step_buttons.size():
		for step in STEPS:
			var active: bool = patterns[track][step]
			if active:
				active_count += 1
			var cell: Button = step_buttons[track][step]
			cell.text = str(note_lengths[track - NOTE_TRACK_START][step]) if track >= NOTE_TRACK_START and active else ("●" if active else "")
			cell.modulate = TRACK_COLORS[track].lightened(0.35) if active else Color.WHITE
	if density_label:
		density_label.text = LocalizationSystem.text("%d 个触发点" % active_count)


func request_visual() -> void:
	var used_tracks := 0
	for track in patterns.size():
		if _active_steps(track) > 0:
			used_tracks += 1
	if used_tracks < 2:
		status.text = LocalizationSystem.text("至少使用两种声音，唱片才会有足够的层次。")
		return
	var check := GameplayModuleSystem.entry_check("sound_sampling", 60)
	if not bool(check.ok):
		status.text = str(check.reason)
		return
	_stop_playback()
	status.text = LocalizationSystem.text("正在生成四小节唱片音频……")
	var model := _build_arrangement()
	var audio: AudioStreamWAV = await model.mix_async()
	if audio == null:
		status.text = LocalizationSystem.text(model.error)
		return
	_save_draft(true)
	var visual = load("res://scripts/town_sound/visual/VisualRoom.gd").new()
	visual.studio = self
	visual.model = model
	visual.audio = audio
	get_parent().add_child(visual)
	hide()


func _build_arrangement() -> Arrangement:
	var model := ArrangementModel.new()
	model.prompt = "舒缓，温暖，来自小镇的日常声音，缓慢漂浮"
	model.seed_value = 27031996
	var step_duration := 60.0 / BPM / 4.0
	var bar_duration := step_duration * STEPS
	var total_duration := bar_duration * BARS_ON_RECORD
	var silence := _silent_stream(0.25)
	model.cache["sequencer_duration_anchor"] = _pcm_cache(silence)
	model.clips.append(_clip("sequencer_duration_anchor", "时长定位", 1, 0.0, total_duration, 0.25, 0.0, true))
	for track in patterns.size():
		for step in STEPS:
			if not patterns[track][step]:
				continue
			var source: AudioStreamWAV = streams[track][0]
			var sample_id := "sequencer_track_%d" % track
			if track >= NOTE_TRACK_START:
				var length_value: int = note_lengths[track - NOTE_TRACK_START][step]
				source = _note_stream(track, length_value)
				sample_id += "_length_%d" % length_value
			if not model.cache.has(sample_id):
				model.cache[sample_id] = _pcm_cache(source)
			var source_duration := float(source.data.size()) / 2.0 / float(source.mix_rate)
			for bar in BARS_ON_RECORD:
				var at := bar * bar_duration + step * step_duration
				var clip_duration := minf(source_duration, total_duration - at)
				model.clips.append(_clip(sample_id, TRACK_NAMES[track], _mix_track(track), at, clip_duration, source_duration, 0.78))
	return model


func _mix_track(track: int) -> int:
	if track <= 1:
		return 0
	if track == 2:
		return 1
	if track <= 5:
		return 2
	return 3


func _clip(sample_id: String, clip_name: String, track: int, at: float, length: float, source_end: float, volume: float, loop := false) -> Dictionary:
	return {"sample_id": sample_id, "name": clip_name, "track": track, "start": at, "source_start": 0.0,
		"source_end": source_end, "volume": volume, "speed": 1.0, "loop": loop,
		"fade_in": 0.01, "fade_out": 0.05, "length": length}


func _pcm_cache(stream: AudioStreamWAV) -> Dictionary:
	var pcm := PackedFloat32Array()
	pcm.resize(stream.data.size() / 2)
	for index in pcm.size():
		pcm[index] = float(stream.data.decode_s16(index * 2)) / 32768.0
	return {"pcm": pcm, "rate": stream.mix_rate}


func _silent_stream(duration: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = Arrangement.RATE
	wav.data = PackedByteArray()
	wav.data.resize(int(duration * wav.mix_rate) * 2)
	return wav


func _synthesize(kind: String, duration: float, frequency := 0.0, timbre := 0, gate_duration := 0.0) -> AudioStreamWAV:
	var sample_rate := Arrangement.RATE
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
				value = (sin(TAU * (65.41 * t - 15.0 * t * t)) * exp(-8.0 * t) + sin(TAU * 420.0 * t) * exp(-70.0 * t) * 0.10) * 0.82
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


func _save_draft(flush: bool) -> void:
	if not has_node("/root/GameState"):
		return
	var drafts: Dictionary = GameState.artifacts.get_or_add("minigame_drafts", {})
	drafts["sound_sequencer"] = {"version": 1, "patterns": patterns.duplicate(true), "note_lengths": note_lengths.duplicate(true)}
	if flush:
		SaveManager.save_or_report("格子音序器未能保存")


func _load_draft() -> void:
	if not has_node("/root/GameState"):
		return
	var draft: Dictionary = GameState.artifacts.get("minigame_drafts", {}).get("sound_sequencer", {})
	if draft.get("version", 0) != 1:
		return
	var saved_patterns = draft.get("patterns", [])
	var saved_lengths = draft.get("note_lengths", [])
	if saved_patterns is Array and saved_patterns.size() == patterns.size():
		patterns = saved_patterns.duplicate(true)
	if saved_lengths is Array and saved_lengths.size() == note_lengths.size():
		note_lengths = saved_lengths.duplicate(true)


func _return_to_timeline() -> void:
	_stop_playback()
	_save_draft(true)
	if is_instance_valid(timeline_studio):
		timeline_studio.show()
	queue_free()


func _exit_tree() -> void:
	if monitor_locked and has_node("/root/WorldSound"):
		get_node("/root/WorldSound").lock_monitor(false)
