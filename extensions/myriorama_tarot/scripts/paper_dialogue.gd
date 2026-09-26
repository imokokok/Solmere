extends PanelContainer

signal finished
signal line_changed(index: int)
var lines: Array[String] = []
var line_index := 0
var body: RichTextLabel
var speaker: Label
var advance: Button
var progress := 0.0
var last_tick := -1
var typing := false
var quiet_player: AudioStreamPlayer

func _ready() -> void:
	position = Vector2(80, 184)
	size = Vector2(470, 280)
	var paper := StyleBoxTexture.new()
	paper.texture = preload("res://extensions/myriorama_tarot/assets/reader-scene/speech-bubble-v2.png")
	add_theme_stylebox_override("panel",paper)
	var layout := Control.new()
	layout.custom_minimum_size = size
	add_child(layout)
	speaker = Label.new()
	speaker.text = "塔罗师"
	speaker.position = Vector2(31,27)
	speaker.add_theme_font_size_override("font_size",18)
	speaker.add_theme_color_override("font_color",Color("75624b"))
	layout.add_child(speaker)
	body = RichTextLabel.new()
	body.position = Vector2(31,57)
	body.size = Vector2(402,120)
	body.add_theme_font_size_override("normal_font_size",21)
	body.add_theme_color_override("default_color",Color("353650"))
	body.scroll_active = true
	layout.add_child(body)
	advance = Button.new()
	advance.position = Vector2(277,190)
	advance.size = Vector2(133,32)
	advance.flat = true
	advance.add_theme_font_size_override("font_size",18)
	advance.add_theme_color_override("font_color",Color("6f5c44"))
	for state in ["font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		advance.add_theme_color_override(state,Color("6f5c44"))
	advance.pressed.connect(next)
	layout.add_child(advance)
	quiet_player = AudioStreamPlayer.new()
	quiet_player.stream = load("res://extensions/myriorama_tarot/assets/audio/slide-tight-1.wav")
	quiet_player.volume_db = -37.0
	add_child(quiet_player)

func say(values: Array) -> void:
	lines.clear()
	# Page long guidance instead of hiding its last lines below the bubble.
	for value in values:
		var remaining:=str(value)
		while remaining.length()>64:
			var cut:=64
			for i in range(63,40,-1):
				if remaining[i] in ["。","！","？","\n"]: cut=i+1; break
			lines.append(remaining.substr(0,cut).strip_edges())
			remaining=remaining.substr(cut).strip_edges()
		if not remaining.is_empty(): lines.append(remaining)
	line_index = 0
	visible = true
	if lines.is_empty(): return
	show_line()

func show_line() -> void:
	body.text = lines[line_index]
	body.scroll_to_line(0)
	body.visible_characters = 0
	progress = 0
	last_tick = -1
	typing = true
	advance.disabled = false
	advance.text = "显示全文"
	line_changed.emit(line_index)

func next() -> void:
	if typing:
		typing = false
		body.visible_characters = -1
		advance.text = "继续 →" if line_index < lines.size()-1 else "知道了"
	elif line_index < lines.size()-1:
		line_index += 1
		show_line()
	else:
		advance.disabled = true
		finished.emit()

func _process(delta: float) -> void:
	if not typing: return
	advance.disabled = false
	progress += delta*29.0
	body.visible_characters = int(progress)
	var step := int(progress)/10
	if step != last_tick:
		last_tick = step
		if not quiet_player.playing and DisplayServer.get_name() != "headless": quiet_player.play()
	if body.visible_characters >= body.get_total_character_count():
		typing = false
		body.visible_characters = -1
		advance.text = "继续 →" if line_index < lines.size()-1 else "知道了"
