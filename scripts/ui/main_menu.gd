extends Control

const PAPER := Color("fff8eb")
const PAPER_SOFT := Color("f1dfc7")
const INK := Color("405653")
const MUTED := Color("526b77")
const TERRACOTTA := Color("c85f43")
const TEAL := Color("4f7d83")
const SAGE := Color("7d8f59")
const LINE := Color("b88963")
const COVER_BLUE := Color("3f78a4")
const Production = preload("res://scripts/ui/production_assets.gd")
const Motion = preload("res://scripts/ui/solmere_motion.gd")
const NAVIGATION_TITLES := {
	"Continue": "继续旅程",
	"NewGame": "新游戏",
	"Chapters": "章节",
	"Settings": "设置",
	"Credits": "致谢",
	"Quit": "退出",
}

var modal_overlay: ColorRect
var modal_panel: Panel
var pending_slot := 1
var entering := false
var navigation: Control
var navigation_ready := false


func _ready() -> void:
	# Export templates disallow CLI scene overrides. Keep preview opt-in and isolated.
	if OS.get_cmdline_user_args().has("--tarot-preview") and OS.get_cmdline_user_args().has("--isolated-save"):
		get_tree().change_scene_to_file.call_deferred("res://extensions/myriorama_tarot/main.tscn")
		return
	WorldSound.set_active(false)
	SettingsSystem.language_changed.connect(_refresh_navigation_language)
	_build_living_cover()
	_build_navigation()
	_build_modal_shell()
	if OS.get_cmdline_user_args().has("--fresh-preview"):
		_on_new_game_pressed()
	elif OS.get_cmdline_user_args().has("--live-preview"):
		if SaveManager.load_latest(): SceneRouter.town_day()
		else: _on_new_game_pressed()


func _draw() -> void:
	var sx := size.x / 1600.0
	var sy := size.y / 900.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))
	draw_rect(Rect2(0, 0, 1600, 900), COVER_BLUE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _build_living_cover() -> void:
	var cover := TextureRect.new(); cover.name="CoastalCover"
	cover.texture=preload("res://art/ui/title-screen-background.png")
	cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.set_anchors_and_offsets_preset(PRESET_FULL_RECT); cover.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(cover)
	# The existing illustration already carries the title; never print a second logo.
	var caption := _make_label(self,"海风、日常，和一些值得留下的小事。",Vector2(500,433),Vector2(720,38),22,Color("344f53"))
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER


func _process(_delta: float) -> void:
	if entering: return
	if not navigation_ready:
		navigation_ready = true
		navigation.modulate.a = 1.0
		for child in navigation.get_children():
			if child is Button:
				child.disabled = false
				child.focus_mode = Control.FOCUS_ALL

func _build_navigation() -> void:
	navigation=Control.new(); navigation.name="JourneyNavigation"; navigation.mouse_filter=Control.MOUSE_FILTER_IGNORE
	navigation.position=Vector2(452,580); navigation.size=Vector2(784,72); add_child(navigation)
	var titles := ["新游戏","章节","设置"]
	var names := ["NewGame","Chapters","Settings"]
	var actions := [_launch_new_game,_show_chapters,_show_settings]
	if SaveManager.has_any_save(): titles.push_front("继续旅程"); names.push_front("Continue"); actions.push_front(_continue_latest)
	var offset := (784-titles.size()*196)*.5
	for i in titles.size():
		var button := preload("res://scripts/ui/components/solmere_button.gd").new()
		button.name=names[i]; button.text=LocalizationSystem.text(titles[i]); button.variant="primary" if i==0 else "paper"
		button.position=Vector2(offset+i*196,0); button.size=Vector2(180,62)
		button.disabled=true; button.add_theme_font_size_override("font_size",24)
		navigation.add_child(button); button.pressed.connect(actions[i])
	for i in 2:
		var extra := preload("res://scripts/ui/components/solmere_button.gd").new()
		extra.name=["Credits","Quit"][i]; extra.variant="paper"; extra.text=LocalizationSystem.text(["致谢","退出"][i])
		extra.position=Vector2(1230+i*170,826); extra.size=Vector2(154,44); extra.add_theme_font_size_override("font_size",18)
		add_child(extra); extra.pressed.connect([_show_credits,_show_quit_confirmation][i])
	navigation.modulate.a=1


func _refresh_navigation_language(_locale := "") -> void:
	if not is_instance_valid(navigation):
		return
	for button_name in NAVIGATION_TITLES:
		var button := find_child(button_name, true, false) as Button
		if button != null:
			button.text = LocalizationSystem.text(NAVIGATION_TITLES[button_name])

func _launch_new_game() -> void:
	if entering: return
	entering = true
	_on_new_game_pressed()
	if not SceneRouter.transitioning: entering = false


func _show_chapters() -> void:
	_prepare_modal()
	modal_panel.position=Vector2(260,122); modal_panel.size=Vector2(1080,656)
	_make_label(modal_panel,"章节与存档",Vector2(30,25),Vector2(920,60),31,INK)
	var slots := preload("res://scripts/ui/components/save_slots.gd").new()
	slots.position=Vector2(30,113); slots.loaded.connect(_resume_chapter); slots.changed.connect(_show_chapters); modal_panel.add_child(slots)
	var back := _make_button(modal_panel,"返回",Vector2(438,578),Vector2(200,48),"regular"); back.pressed.connect(_hide_modal)


func _resume_chapter(slot: int) -> void:
	if SaveManager.load_slot(slot): SceneRouter.town_day()

func _build_modal_shell() -> void:
	modal_overlay = ColorRect.new()
	modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_overlay.color = Color(INK, 0.36)
	modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal_overlay)

	modal_panel = Panel.new()
	modal_panel.position = Vector2(505, 210)
	modal_panel.size = Vector2(590, 480)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("edf3f4",.98)
	style.border_color = Color(LINE, 0.92)
	style.set_border_width_all(0)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(INK, 0.30)
	style.shadow_size = 0
	style.shadow_offset = Vector2(0, 8)
	modal_panel.add_theme_stylebox_override("panel", Production.surface(Color("faf5e8"),20))
	modal_overlay.add_child(modal_panel)
	modal_overlay.visible = false


func _on_new_game_pressed() -> void:
	# Allocate automatically; preserve older journeys without showing empty slot UI.
	if not SaveManager.prepare_new_journey(): return
	ChapterSystem.start_new_game()
	if not SaveManager.save_or_report("新旅程保存失败"):
		return
	SceneRouter.town_day(.75)


func _show_settings() -> void:
	_prepare_modal()
	modal_panel.position = Vector2(505, 75)
	modal_panel.size.y = 750
	_make_label(modal_panel, "设置", Vector2(34, 20), Vector2(522, 42), 27, INK)
	_make_label(modal_panel, "语言", Vector2(34, 72), Vector2(160, 30), 16, MUTED)
	var language_picker := OptionButton.new()
	language_picker.position = Vector2(210, 62)
	language_picker.size = Vector2(300, 44)
	language_picker.add_item(LocalizationSystem.text("简体中文"))
	language_picker.set_item_metadata(0, "zh_CN")
	language_picker.add_item("English")
	language_picker.set_item_disabled(1,not FileAccess.file_exists("res://localization/en.json"))
	language_picker.set_item_metadata(1, "en")
	language_picker.select(0 if SettingsSystem.language() == "zh_CN" else 1)
	language_picker.add_theme_font_size_override("font_size", 17)
	modal_panel.add_child(language_picker)
	language_picker.item_selected.connect(func(index: int) -> void:
		SettingsSystem.set_language(str(language_picker.get_item_metadata(index)))
		_show_settings()
	)

	_make_label(modal_panel, "显示模式", Vector2(34, 128), Vector2(160, 30), 16, MUTED)
	var display_text := "切换为窗口模式" if SettingsSystem.fullscreen() else "切换为全屏模式"
	var display_button := _make_button(modal_panel, display_text, Vector2(210, 114), Vector2(300, 44), "teal")
	display_button.pressed.connect(_toggle_fullscreen)
	_add_settings_volume_slider("主音量", 182, SettingsSystem.master_volume(), SettingsSystem.set_master_volume)
	_add_settings_volume_slider("音乐音量", 230, SettingsSystem.music_volume(), SettingsSystem.set_music_volume)
	_add_settings_volume_slider("音效音量", 278, SettingsSystem.sound_effects_volume(), SettingsSystem.set_sound_effects_volume)
	var mute_text := "取消静音" if SettingsSystem.is_audio_muted() else "全部静音"
	var mute := _make_button(modal_panel, mute_text, Vector2(210, 316), Vector2(300, 40), "regular")
	mute.pressed.connect(func() -> void:
		SettingsSystem.set_audio_muted(not SettingsSystem.is_audio_muted())
		_show_settings())

	_make_label(modal_panel, "减少动态效果", Vector2(34, 384), Vector2(160, 30), 16, MUTED)
	var motion_text := "已开启" if SettingsSystem.reduced_motion() else "未开启"
	var motion := _make_button(modal_panel, motion_text, Vector2(210, 370), Vector2(300, 44), "regular")
	motion.pressed.connect(_toggle_reduced_motion)
	var hint := _make_label(modal_panel, "减少章节转场中的画面位移；不会跳过任何内容。", Vector2(34, 424), Vector2(522, 42), 14, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_make_label(modal_panel,"心声字号",Vector2(34,478),Vector2(160,30),16,MUTED)
	var voice_size := HSlider.new()
	voice_size.position = Vector2(210,472)
	voice_size.size = Vector2(300,38)
	voice_size.min_value = 17
	voice_size.max_value = 30
	voice_size.step = 1
	voice_size.value = SettingsSystem.values.get("voice_size",21)
	modal_panel.add_child(voice_size)
	voice_size.value_changed.connect(func(value: float) -> void:
		SettingsSystem.values.voice_size = int(value)
		SettingsSystem.save_settings())
	_make_label(modal_panel,"心声透明度",Vector2(34,532),Vector2(160,30),16,MUTED)
	var opacity := HSlider.new()
	opacity.position = Vector2(210,526)
	opacity.size = Vector2(300,38)
	opacity.min_value = 0
	opacity.max_value = 1
	opacity.step = .05
	opacity.value = SettingsSystem.values.get("voice_opacity",.86)
	modal_panel.add_child(opacity)
	opacity.value_changed.connect(func(value: float) -> void:
		SettingsSystem.values.voice_opacity = value
		SettingsSystem.save_settings())
	var close := _make_button(modal_panel, "完成", Vector2(200, 666), Vector2(190, 46), "primary")
	close.pressed.connect(_hide_modal)


func _add_settings_volume_slider(title: String, y: float, value: int, setter: Callable) -> void:
	_make_label(modal_panel, title, Vector2(34, y), Vector2(160, 30), 16, MUTED)
	var slider := HSlider.new()
	slider.position = Vector2(210, y - 9)
	slider.size = Vector2(275, 38)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = value
	slider.tooltip_text = LocalizationSystem.text("%s，0 到 100" % title)
	modal_panel.add_child(slider)
	var value_label := _make_label(modal_panel, "%d%%" % value, Vector2(500, y), Vector2(54, 28), 14, MUTED)
	slider.value_changed.connect(func(changed_value: float) -> void:
		setter.call(changed_value)
		value_label.text = "%d%%" % int(round(changed_value)))


func _show_credits() -> void:
	_prepare_modal()
	modal_panel.position=Vector2(360,83); modal_panel.size=Vector2(880,734)
	_make_label(modal_panel,"致谢",Vector2(42,32),Vector2(792,44),29,INK)
	var close := _make_button(modal_panel,"返回",Vector2(345,650),Vector2(190,46),"primary")
	close.pressed.connect(_hide_modal)


func _show_quit_confirmation() -> void:
	_prepare_modal()
	_make_label(modal_panel, "要离开小镇吗？", Vector2(34, 36), Vector2(522, 42), 27, INK)
	_make_label(modal_panel, "已保存的旅程不会丢失。", Vector2(34, 98), Vector2(522, 34), 16, MUTED)
	var yes := _make_button(modal_panel, "退出游戏", Vector2(92, 224), Vector2(190, 52), "danger")
	var no := _make_button(modal_panel, "再待一会", Vector2(308, 224), Vector2(190, 52), "regular")
	yes.pressed.connect(get_tree().quit)
	no.pressed.connect(_hide_modal)


func _prepare_modal() -> void:
	modal_panel.position = Vector2(505, 210)
	modal_panel.size = Vector2(590,480)
	for child in modal_panel.get_children():
		modal_panel.remove_child(child)
		child.queue_free()
	modal_overlay.visible = true
	Motion.paper_open.call_deferred(modal_panel,SettingsSystem.reduced_motion())
	WorldSound.play_ui("open")


func _hide_modal() -> void:
	modal_overlay.visible = false
	WorldSound.play_ui("close")


func _toggle_fullscreen() -> void:
	SettingsSystem.set_fullscreen(not SettingsSystem.fullscreen())
	_show_settings()


func _toggle_reduced_motion() -> void:
	SettingsSystem.set_reduced_motion(not SettingsSystem.reduced_motion())
	_show_settings()








func _unhandled_input(event: InputEvent) -> void:
	if modal_overlay.visible and event.is_action_pressed("ui_cancel"):
		_hide_modal()
		get_viewport().set_input_as_handled()


func _make_label(parent: Node, text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = LocalizationSystem.text(text_value)
	label.position = at
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _make_button(parent: Node, text_value: String, at: Vector2, button_size: Vector2, kind: String) -> Button:
	var button := preload("res://scripts/ui/components/solmere_button.gd").new()
	button.variant="outlined"; button.selected=kind in ["primary","teal"]
	button.text=LocalizationSystem.text(text_value); button.position=at; button.size=button_size; parent.add_child(button)
	return button


func _capture(filename: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/%s" % filename))
	get_tree().quit()

func _continue_latest() -> void:
	if SaveManager.load_latest():
		SceneRouter.town_day()
	else:
		_prepare_modal()
		_make_label(modal_panel,"这份旅程需要重新开始",Vector2(34,30),Vector2(522,54),27,INK)
		var notice := _make_label(modal_panel,SaveManager.last_error,Vector2(34,108),Vector2(522,200),20,MUTED)
		notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		_make_button(modal_panel,"返回，开始新旅程",Vector2(145,355),Vector2(300,52),"primary").pressed.connect(_hide_modal)

func _preview_role(role: String) -> void:
	GameState.begin_vertical_slice(role)
	SceneRouter.enter_space("home_a" if role == "A" else "home_b")
