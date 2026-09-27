extends Node2D

signal shift_completed(result: Dictionary)
signal exit_requested
signal recipe_published(record: Dictionary)
signal poster_published(data: Dictionary)

const Session = preload("res://modules/restaurant/domain/kitchen_session.gd")
const Repository = preload("res://modules/restaurant/storage/recipe_repository.gd")
const KitchenWorld = preload("res://modules/restaurant/world/kitchen_world.gd")
const PosterCanvas = preload("res://modules/restaurant/ui/poster_canvas.gd")
const PosterStore = preload("res://modules/restaurant/ui/poster_store.gd")
const StorageDisplay = preload("res://modules/restaurant/ui/storage_display.gd")
const MoodIcon = preload("res://modules/restaurant/ui/mood_icon.gd")
const RecipeMethod = preload("res://modules/restaurant/domain/recipe_method.gd")
const PaperAction = preload("res://modules/restaurant/ui/paper_action.gd")
const RecipeVignette = preload("res://modules/restaurant/ui/recipe_vignette.gd")
const FONT = preload("res://modules/restaurant/assets/fonts/noto_serif_sc.ttf")
const CREAM: = Color("284b47")
const MUTED: = Color("64756a")
const ACCENT: = Color("d7653e")
const DARK: = Color("173f3d")

var session = Session.new()
var repository
var poster_store
var world
var context: Dictionary = {}
var session_id: String = ""
var layer: CanvasLayer
var hud: Control
var modal: Control
var modal_panel: PanelContainer
var modal_body: VBoxContainer
var clock_label: Label
var money_label: Label
var hint_label: Label
var _fire_buttons: Dictionary = {}
var _order_paper: Control
var customer_label: Label
var customer_mood_icon: Control
var dish_label: Label
var heat_bar: ProgressBar
var toast_label: Label
var toast_time: float = 0.0
var last_customer: String = ""
var last_model_notice: String = ""
var _result_emitted: bool = false
var _saved_mouse_mode: int
var _started: bool = false
var _modal_kind: String = ""
var _pantry_category: String = "all"
var _pantry_search: String = ""
var _pantry_grid: GridContainer
var _last_dish: Dictionary = {}
var _pending_serve_result: Dictionary = {}
var _recipe_pages: Array[Dictionary] = []
var _recipe_page_index := 0
var _recipe_turning := false
var _photo: String = ""
var _poster_data: Dictionary = {}
var _poster_canvas
var _recipe_canvas
var _recipe_dish: Dictionary = {}
var _plating_canvas: Control
var _plating_revision: = 0
var _plating_photo_revision: = -1
var _photo_is_plating: = false
var _recipe_photo: String = ""
var _editing_recipe_id: String = ""
var _recipe_drafts: Dictionary = {}
var _active_recipe_draft_key := ""
var _editor_status: Label
var _title_input: LineEdit
var _author_input: LineEdit
var _notes_input: TextEdit
var _recipe_selected: Dictionary = {}
var _letters: Array = []
const LETTER_PATH := "user://100_restaurant_letters.json"
var _food_by_physics: Dictionary = {}
var storage_display
var _stock: Dictionary = {}
var _stock_bodies: Dictionary = {}
var _recipe_stand
var recipe_guide = RecipeMethod.new()
var _guide_bar: PanelContainer
var _guide_text: Label
var _guide_timer := 0.0

func configure(entry_context: Dictionary) -> void :
	assert ( not is_inside_tree(), "Configure before adding the minigame to the scene tree.")
	context = entry_context.duplicate(true)

func _ready() -> void :
	_saved_mouse_mode = Input.mouse_mode
	session_id = "%s-%s" % [Time.get_ticks_usec(), randi()]
	session.setup()
	session.duration = clampf(float(context.get("shift_seconds", 720.0)), 30.0, 3600.0)
	if context.has("npc_profiles"):
		session.set_customers(context["npc_profiles"])
	repository = Repository.new(str(context.get("repository_path", "user://after_hours_kitchen/cookbook.json")))
	session.set_menu_recipes(repository.load_recipes())
	_load_letters()
	poster_store = PosterStore.new(repository.storage_path.get_basename() + "_poster.json")
	_poster_data = poster_store.load_poster()
	if not _poster_data.is_empty():
		session.apply_poster(_poster_data.get("tags", []))
	world = KitchenWorld.new()
	add_child(world)
	if not _poster_data.is_empty():
		world.set_poster(_poster_data)
	world.interaction.connect(_interact)
	world.focus_changed.connect(_focus)
	world.held_changed.connect( func(title: String):
		if not title.is_empty():
			_notify("手中：" + title + "   /   松手或点击台面放下")
		elif is_instance_valid(toast_label) and toast_label.text.begins_with("手中："):
			toast_time = 0
			toast_label.visible = false)
	if world.has_signal("food_entered_pan"):
		world.food_entered_pan.connect(_food_entered)
	if world.has_signal("food_removed_from_pan"):
		world.food_removed_from_pan.connect(_food_removed)
	_build_ui()
	world.set_controls_enabled(false)
	_show_intro()

func _exit_tree() -> void :
	Input.mouse_mode = _saved_mouse_mode

func _process(delta: float) -> void :

	if not is_instance_valid(modal) or not modal.visible:
		session.heat_contact = world.pan.on_stove()
		session.water_ml = world.pan.water_ml
		session.water_heat = world.pan.water_heat
		for item in session.dish:
			var food = _food_by_physics.get(int(item.get("physics_id", 0)))
			if is_instance_valid(food):
				item["off_heat"] = food.get_meta("plated", false) or not world.pan.contains(food.position)
				world.synchronize_body_state(food, item)
		session.tick(delta)
	if session.phase == "closed" and not _result_emitted:
		_settle()
	_update_hud()
	if is_instance_valid(hint_label): hint_label.visible = toast_time <= 0
	if toast_time > 0:
		toast_time -= delta
		toast_label.visible = toast_time > 0
	if session.last_notice != last_model_notice:
		last_model_notice = session.last_notice
		if session.phase == "service":
			_notify(last_model_notice)
	var customer_id: String = str(session.current_customer.get("id", ""))
	if customer_id != last_customer:
		last_customer = customer_id
		world.set_customer(session.current_customer)
		if not customer_id.is_empty():
			world._backdrop.ring_bell()
			world.audio.play_effect("bell")
	world.set_cooking(session.heating)
	world.set_heat_level(session.heat_level)
	world.set_dish(session.dish, session.ingredients)
	world.plate_presentation = session.presentation
	_guide_timer -= delta
	if _guide_timer <= 0:
		_guide_timer = 0.15
		_update_recipe_guide()

func _unhandled_input(event: InputEvent) -> void :
	if event is InputEventKey and event.pressed and not event.echo:
		if modal.visible and _modal_kind == "recipe" and event.keycode in [KEY_LEFT, KEY_RIGHT]:
			_turn_recipe(-1 if event.keycode == KEY_LEFT else 1)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			if modal.visible and _modal_kind != "intro" and _modal_kind != "result":
				_close_modal()
			elif not modal.visible:
				_show_pause()
			get_viewport().set_input_as_handled()
		if not modal.visible:
			match event.keycode:
				KEY_TAB: _show_pantry()
				KEY_J: _show_cookbook()
				KEY_F1: _show_help()
				KEY_P: _show_poster()

func _build_ui() -> void :
	layer = CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	var theme: = Theme.new()
	var readable_font: = FontVariation.new()
	readable_font.base_font = FONT
	readable_font.variation_opentype = {2003265652: 400.0}
	theme.default_font = readable_font
	theme.default_font_size = 18
	# Native tooltips otherwise inherit dark ink over Godot's dark popup panel.
	# Keep the same warm paper and readable ink as the kitchen's other notes.
	var tooltip_paper := StyleBoxFlat.new()
	tooltip_paper.bg_color = Color("f3e3c2")
	tooltip_paper.border_color = Color("b99a71")
	tooltip_paper.set_border_width_all(1)
	tooltip_paper.set_content_margin_all(10)
	tooltip_paper.shadow_color = Color(0.16,0.12,0.09,0.2)
	tooltip_paper.shadow_size = 3
	theme.set_stylebox("panel", "TooltipPanel", tooltip_paper)
	theme.set_color("font_color", "TooltipLabel", Color("44392c"))
	theme.set_font_size("font_size", "TooltipLabel", 16)
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", DARK)
	theme.set_color("font_pressed_color", "Button", DARK)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_stylebox("normal", "Button", _style(Color("f3dfa1"), 0))
	theme.set_stylebox("hover", "Button", _style(Color("ffe9a0"), 0))
	theme.set_stylebox("pressed", "Button", _style(Color("e6c86f"), 0))
	theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), 10, ACCENT))
	theme.set_stylebox("normal", "LineEdit", _style(Color("fffaf0"), 8))
	theme.set_color("font_color", "LineEdit", CREAM)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_stylebox("normal", "TextEdit", _style(Color("fffaf0"), 8))
	theme.set_color("font_color", "TextEdit", CREAM)
	theme.set_color("font_placeholder_color", "TextEdit", MUTED)
	hud.theme = theme
	var footer: = ColorRect.new()
	footer.name = "DedicatedInstructionBar"
	footer.position = Vector2(0, 900)
	footer.size = Vector2(1600, 46)
	footer.color = Color("302e2b")
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(footer)
	storage_display = StorageDisplay.new()
	hud.add_child(storage_display)
	storage_display.setup(session.active_ingredients())
	storage_display.ingredient_chosen.connect(_take_ingredient)
	storage_display.browse_requested.connect(_show_pantry)
	world.storage_return_handler = _return_to_storage
	clock_label = _label(hud, "准备营业", Vector2(366, 36), 20, Color("fff0b8"))
	money_label = _label(hud, "¥ 0.00", Vector2(1230, 34), 20, Color("f7d96f"))
	var settings: = _dock_button(hud, "暂停 / 帮助", _show_pause, 130)
	settings.position = Vector2(1440, 28)
	_recipe_stand = preload("res://modules/restaurant/ui/recipe_stand.gd").new()
	hud.add_child(_recipe_stand)
	_recipe_stand.visible = false # Keep the shared page renderer for the open cookbook.
	_refresh_recipe_stand()
	var trash: = _dock_button(hud, "丢弃 / 清理台面", func():
		if is_instance_valid(world._held): world.discard_held()
		else: _interact("trash"), 130)
	trash.position = Vector2(1440, 832)
	_order_paper = preload("res://modules/restaurant/ui/customer_order_paper.gd").new()
	_order_paper.position = Vector2(1068,130)
	_order_paper.size = Vector2(237,317)
	hud.add_child(_order_paper)
	customer_label = _order_paper.body
	customer_mood_icon = _order_paper.mood
	_order_paper.opened.connect(_show_order_paper)
	var fire_row: = HBoxContainer.new()
	fire_row.name = "StoveHeatControls"
	fire_row.position = Vector2(718, 750)
	fire_row.add_theme_constant_override("separation", 8)
	hud.add_child(fire_row)
	var fire_group: = ButtonGroup.new()
	for option in [["low", "小火"], ["medium", "中火"], ["high", "大火"], ["off", "关火"]]:
		var fire_button: = _dock_button(fire_row, option[1], func(): _change_heat(option[0]), 48)
		fire_button.toggle_mode = true
		fire_button.button_group = fire_group
		_fire_buttons[option[0]] = fire_button
	dish_label = _label(hud, "", Vector2(477, 812), 15, Color("fff1bd"))
	dish_label.size = Vector2(651, 23)
	dish_label.clip_text = true
	heat_bar = ProgressBar.new()
	heat_bar.position = Vector2(477, 837)
	heat_bar.size = Vector2(651, 3)
	heat_bar.max_value = 16.0
	heat_bar.show_percentage = false
	hud.add_child(heat_bar)
	var dock: = HBoxContainer.new()
	dock.name = "KitchenActionDock"
	dock.position = Vector2(477, 849)
	dock.add_theme_constant_override("separation", 12)
	hud.add_child(dock)
	_dock_button(dock, "食材柜", _show_pantry, 112)
	_dock_button(dock, "菜谱", _show_cookbook, 62)
	_dock_button(dock, "海报", _show_poster, 62)
	_dock_button(dock, "聊聊口味", func(): _interact("talk"), 104)
	_dock_button(dock, "出餐", func(): _interact("serve"), 72)
	_dock_button(dock, "回信", _show_letters, 62)
	var sound: = _dock_button(dock, "声音 开", func(): world.audio.muted = not world.audio.muted, 88)
	sound.pressed.connect( func(): sound.text = "声音 关" if world.audio.muted else "声音 开")
	hint_label = _label(hud, "", Vector2(40, 912), 14, Color("fff3c4"))
	hint_label.size = Vector2(1520, 28)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.clip_text = true
	toast_label = _label(hud, "", Vector2(40, 912), 14, Color("ffe28a"))
	toast_label.size = Vector2(1520, 28)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.clip_text = true
	_build_recipe_guide()
	# Flood water crosses the whole screen, including shelves and HUD. Modals
	# added afterwards remain legible above it, and input still reaches controls.
	world.flood_art.reparent(hud)
	world.flood_art.z_index = 0
	modal = Control.new()
	modal.theme = theme
	# Reserve a high layer for paper dialogs: shelf captions use positive Z so
	# they stay legible over shelf art, but must never cross an open recipe page.
	modal.z_index = 100
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(modal)
	var shade: = ColorRect.new()
	shade.color = Color(0.05, 0.18, 0.17, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	modal_panel = PanelContainer.new()
	modal_panel.add_theme_stylebox_override("panel", _style(Color("fff5dc"), 0, Color("79a59a")))
	modal.add_child(modal_panel)
	modal_body = VBoxContainer.new()
	modal_body.add_theme_constant_override("separation", 14)
	modal_panel.add_child(modal_body)
	modal.visible = false

func _style(color: Color, _radius: int = 0, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(0)
	style.set_content_margin_all(18)
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0 else 0)
	return style

func _panel_at(parent: Control, rect: Rect2) -> Panel:
	var panel: = Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color("fff7e5"), 0))
	parent.add_child(panel)
	return panel

func _label(parent: Node, text: String, pos: Vector2 = Vector2.ZERO, font_size: int = 18, color: Color = CREAM) -> Label:
	var label: = Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _text(text: String, font_size: int = 18, color: Color = MUTED) -> Label:
	var label: = _label(modal_body, text, Vector2.ZERO, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(parent: Node, text: String, callback: Callable, min_width: float = 0) -> Button:
	var button: = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(min_width, 48)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _paper_action(parent: Node, title: String, callback: Callable, symbol: String = "book", width: float = 210) -> Button:
	var button := PaperAction.new()
	button.text = title
	button.symbol = symbol
	button.custom_minimum_size = Vector2(width, 58)
	button.pressed.connect(func(): world.audio.play_effect("paper"); callback.call())
	parent.add_child(button)
	return button

func _paper_modal() -> void:
	var skin := _style(Color("fff2d6"))
	skin.set_corner_radius_all(12)
	skin.set_content_margin_all(28)
	skin.shadow_color = Color("352d20", 0.25)
	skin.shadow_size = 16
	skin.shadow_offset = Vector2(0, 8)
	modal_panel.add_theme_stylebox_override("panel", skin)
	modal_panel.position.y = 40

func _row(parent: Node) -> HBoxContainer:
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	return row

func _open_modal(kind: String, title: String, width: float = 800) -> void :
	_stash_recipe_draft()
	if is_instance_valid(_plating_canvas): _plating_canvas.stop_gesture()
	modal_panel.theme = null
	modal_panel.add_theme_stylebox_override("panel", _style(Color("fff5dc"), 0, Color("79a59a")))
	modal_body.add_theme_constant_override("separation", 14)
	for child in modal_body.get_children():
		modal_body.remove_child(child)
		child.queue_free()
	if kind != "recipe": _recipe_turning = false
	_modal_kind = kind
	modal.visible = true
	if is_instance_valid(_guide_bar): _guide_bar.visible = false
	modal_panel.position = Vector2((1600.0 - width) / 2.0, 80)
	modal_panel.size = Vector2(width, 0)
	world.set_controls_enabled(false)
	var title_row: = _row(modal_body)
	var heading := Label.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.clip_text = true
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.tooltip_text = title
	heading.add_theme_font_size_override("font_size", 30)
	heading.text = title
	title_row.add_child(heading)
	if kind != "intro" and kind != "result" and kind != "dish_showcase":
		if kind in ["recipe", "cookbook", "recipe_editor", "poster", "order_paper"]: _paper_action(title_row, "合上手记", _close_modal, "arrow", 175)
		else: _button(title_row, "关闭  ×", _close_modal)

func _close_modal() -> void :
	if _modal_kind == "recipe": _recipe_turning = false
	if _modal_kind == "dish_showcase":
		_show_serve_feedback()
		return
	_stash_recipe_draft()
	if is_instance_valid(_plating_canvas): _plating_canvas.stop_gesture()
	if session.phase == "closed" and _modal_kind != "intro":
		_settle()
		return
	modal.visible = false
	_modal_kind = ""
	world.set_controls_enabled(true)
	_update_recipe_guide()

func _show_intro() -> void :
	_open_modal("intro", "100饭店", 820)
	_text("100 RESTAURANT  /  自由烹饪", 14, ACCENT)
	_text("老板把今天的厨房交给你。\n给客人做一顿正常的午餐，或者一场意想不到的味觉实验。", 23, CREAM)
	_text("客人会说出想吃的味道。直接从冰箱、架子和篮子取材，在砧板用刀切开，放入锅里控制火候，再装盘出餐。收班获得营业收入的 30%。")
	_text("营业时间显示为 10:00—14:00；默认约 12 分钟的实际游玩对应这 4 小时。准备期不限时。", 16)
	_text("%d 种可用材料  ·  拿取 / 切配 / 下锅  ·  自由组合\n原创菜谱留存  ·  手绘海报  ·  各有偏好的街坊" % session.active_ingredients().size())
	var row: = _row(modal_body)
	_button(row, "开始今天的营业", _start_shift, 270)
	_button(row, "先在厨房练习", func(): _started = true;_close_modal();_notify("准备期不限时。点击右上角“暂停 / 帮助”可开始营业。"), 240)
	_paper_action(row, "收起围裙", _request_exit, "arrow", 180)
	_text("操作：鼠标拖拽 · 松手放下 · 点击工具操作\n拿刀切配 / 单击盘子摆盘，按住可拖动 · 拖锅时按住右键倾倒", 16)

func _start_shift() -> void :
	_started = true
	session.start_shift()
	_close_modal()
	_notify("营业开始。点击食材架，或按 TAB 选择食材。")

func _show_pause() -> void :
	_open_modal("pause", "休息一下", 710)
	_text("小游戏内的时间已暂停。")
	_button(modal_body, "继续操作", _close_modal)
	if session.phase == "prep":
		_button(modal_body, "准备好了，开始营业", _start_shift)
	_button(modal_body, "操作说明", _show_help)
	_button(modal_body, "提前收班并结算", _settle)
	_paper_action(modal_body, "收班，收起围裙", func(): _settle(false);_request_exit(), "arrow")

func _show_help() -> void :
	_open_modal("help", "从一颗番茄开始", 870)
	_text("01  取材", 22, ACCENT)
	_text("%d 种材料分层放在冰箱和奇物架上，箭头可翻层。每件取出后原位留空。点击拿取，再点击放下；台面上的食材可以拖拽。TAB 可搜索。" % session.active_ingredients().size())
	_text("02  切配与入锅", 22, ACCENT)
	_text("食材放在固定的右侧菜板。按住刀柄，沿箭头让刀刃标记从食材一侧划到另一侧；落刀位置决定薄片厚度，提刀返回不会切。拿刀时按 R 转刀 90°，滚轮微调角度，对准切片横向划切成块。松手放刀；拖住其中一片可把同批切块一起送入锅中。")
	_text("03  掌握火候", 22, ACCENT)
	_text("在灶台选火力，观察变色、焦边与沸腾。每块独立受热；锅容纳 6 份原料、最多 48 个切块，总容量 1500 ml。拿起铲子推拌；调料瓶口对准锅，按住出料、松开停止。")
	_text("04  留下你的招牌", 22, ACCENT)
	_text("点击盘子装盘、旋转或淋酱，也可拖锅时按住右键倾倒。拍下成品，在菜谱纸上画画、贴照片、写做法。保存后点“分享这一页”，朋友用浏览器就能看，也能导回游戏。")
	_text("05  下一锅之前", 22, ACCENT)
	_text("关火并装盘后，拖起水槽旁的抹布，在水流下打湿，再拖过空锅擦掉残留。脏抹布可冲洗；未清洁的锅会把上一道菜的味道带进下一道菜。海绵用来擦台面溢出的水和调料。")
	_button(modal_body, "知道了，回厨房", _close_modal)

func _focus(title: String, hint: String) -> void :
	hint_label.text = (title + " · " + hint) if not title.is_empty() else "拖拽食材到锅里，点击工具操作"

func _notify(message: String) -> void :
	if is_instance_valid(toast_label):
		toast_label.text = message
		toast_label.visible = true
		toast_time = 4.2
		if is_instance_valid(hint_label): hint_label.hide()

func _interact(action: String, payload: String = "") -> void :
	if modal.visible:
		return
	match action:
		"pantry", "ingredient": _show_pantry()
		"cook":
			if world.plated:
				if float(session.presentation.get("broth_ml", 0.0)) > world.pan_free_ml() + 0.001:
					_notify("锅里空间不够，先倒出一些汤再让料理回锅。")
					return
				_return_broth_to_pan()
				world.return_to_pan()
				_notify("料理已回锅。食材落稳后，再点灶台开火。")
			else:
				session.set_heating( not session.heating)
				_notify(session.last_notice)
		"chop": _notify("食材放在菜板上，按住刀柄顺箭头压切；按 R 转刀横切成块。")
		"plate":
			session.set_heating(false)
			_show_plating()
		"serve": _serve()
		"talk":
			_notify(session.talk())
			_update_hud()
		"trash":
			session.clear_dish()
			world.clear_workspace()
			_food_by_physics.clear()
			recipe_guide.reset()
			_notify("已清理锅、盘和台面上的食材与洒漏。")
		"cookbook": _show_cookbook()
		"poster": _show_poster()
		"notice": _notify(payload)

func _food_entered(id: String, cut: bool, body: RigidBody2D) -> void :
	var accepted: bool = session.add_ingredient(id, world.describe_body(body))
	if accepted: _plating_changed()
	if accepted:
		var key: int = body.get_instance_id()
		session.dish[-1]["cut"] = cut
		session.dish[-1]["heat"] = float(body.get_meta("saved_heat", 0.0))
		session.dish[-1]["physics_id"] = key
		_food_by_physics[key] = body
	world.accept_food(body, accepted)
	if accepted: session.dish[-1].merge(world.describe_body(body), true)
	_notify(session.last_notice)

func _food_removed(body: RigidBody2D) -> void :
	_plating_changed()
	var key: int = body.get_instance_id()
	for i in range(session.dish.size() - 1, -1, -1):
		if int(session.dish[i].get("physics_id", 0)) == key:
			body.set_meta("saved_heat", session.dish[i].get("heat", 0.0))
			body.set_meta("cut", session.dish[i].get("cut", false))
			session.dish.remove_at(i)
	_food_by_physics.erase(key)
	world.leave_pan_residue(body)
	if session.dish.is_empty() and not body.get_meta("poured", false):
		session.set_heating(false)

func _update_hud() -> void :
	if not is_instance_valid(clock_label):
		return
	var shift_minute := 10 * 60 + roundi(240.0 * clampf(session.elapsed / maxf(session.duration, 1.0), 0.0, 1.0))
	clock_label.text = "准备营业  /  不限时" if session.phase == "prep" else "日班  %02d:%02d—14:00" % [shift_minute / 60, shift_minute % 60]
	money_label.text = "¥ %.2f" % session.revenue
	var npc: Dictionary = session.current_customer
	_order_paper.update_order(npc,session.customer_wait,_preference_text(npc) + "\n" + str(npc.get("habit","")))
	var names: PackedStringArray = []
	var max_heat: float = 0.0
	for item in session.dish:
		var def: Dictionary = _definition(str(item["id"]))
		var heat: float = float(item.get("heat", 0))
		max_heat = maxf(max_heat, heat)
		var state: = "已焦" if heat > 14 else ("已熟" if heat >= 6 else ("未熟" if def.get("needs_cook", false) else "可直接食用"))
		var thermal: Dictionary=item.get("thermal",{})
		if not thermal.is_empty():
			if def.get("needs_cook",false) and float(thermal.cooked)<0.99: state="内部未熟"
			if float(thermal.get("liquid_kg",0.0))>float(thermal.get("initial_kg",1.0))*0.12:
				state="逐渐化开" if str(thermal.get("phase",""))!="puree" else "软烂出汁"
		if str(item.get("id", "")) == "noodles" and float(item.get("softness", 0.0)) > 0.02:
			state += "·变软%d%%" % roundi(float(item.get("softness", 0.0)) * 100.0)
		names.append("%s%s · %s" % [def.get("name", item["id"]), "·切" if item.get("cut", false) else "", state])
	var fire_name: String = {"low": "小火", "medium": "中火", "high": "大火"}[session.heat_level]
	dish_label.text = "%s · %s" % [fire_name + "加热" if session.heating else ("已关火 · 锅有余热" if world.reactions.pan_c>65.0 else "已关火"), " / ".join(names) if not names.is_empty() else "把食材拖进锅中，拿刀在菜板切配，点击盘子摆盘"]
	for level in _fire_buttons:
		_fire_buttons[level].set_pressed_no_signal(level == (session.heat_level if session.heating else "off"))
		_fire_buttons[level].disabled = session.phase == "closed"
	if max_heat > 14:
		dish_label.text += "\n有食材已经焦了！"
	heat_bar.value = max_heat

func _change_heat(level: String) -> void :
	if modal.visible or session.phase == "closed": return
	if level == "off":
		session.set_heating(false)
	elif world.plated:
		_notify("料理已装盘。先点击平底锅回锅，再调整火力。")
		return
	elif session.set_heat_level(level):
		session.set_heating(true)
	world.set_cooking(session.heating)
	_notify(session.last_notice)
	_update_hud()
	if is_instance_valid(hint_label): hint_label.visible = toast_time <= 0

func _preference_text(npc: Dictionary) -> String:
	var tags: = {"fresh": "清爽", "vegetable": "蔬菜", "protein": "蛋白质", "comfort": "家常", "spicy": "辣味", "sweet": "甜味", "odd": "怪味", "seafood": "海鲜", "dairy": "奶香", "umami": "鲜味", "rich": "浓郁", "sour": "酸味", "herbal": "草本", "bold": "浓烈", "fruit": "水果", "grain": "主食"}
	var like_names: PackedStringArray = []
	var dislike_names: PackedStringArray = []
	for tag in npc.get("likes", []): like_names.append(str(tags.get(tag, _definition(str(tag)).get("name", tag))))
	for tag in npc.get("dislikes", []): dislike_names.append(str(tags.get(tag, _definition(str(tag)).get("name", tag))))
	return "喜欢：%s  /  不爱：%s" % ["、".join(like_names), "、".join(dislike_names)]

func _definition(id: String) -> Dictionary:
	for entry in session.ingredients:
		if entry.get("id") == id: return entry
	return {}

func _show_pantry() -> void :
	_open_modal("pantry", "食材架  /  自由搭配", 1120)
	_text("每种原料本班备一件；未加工原料和调料瓶可拖回原位，用过的瓶子保留余量。", 16)
	var search: = LineEdit.new()
	search.placeholder_text = "搜索食材，例如：番茄、虾、袜子…"
	search.text = _pantry_search
	search.custom_minimum_size.y = 44
	modal_body.add_child(search)
	search.text_changed.connect( func(value): _pantry_search = value;_refresh_pantry())
	var tabs: = _row(modal_body)
	var cats: = {"all": "全部", "basic": "基础食材", "seasoning": "调味料", "sweet": "甜品饮品", "odd": "怪异材料"}
	for key in cats:
		_button(tabs, cats[key], func(): _pantry_category = key;_refresh_pantry(), 190)
	var scroll: = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1050, 427)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_body.add_child(scroll)
	_pantry_grid = GridContainer.new()
	_pantry_grid.columns = 5
	_pantry_grid.add_theme_constant_override("h_separation", 10)
	_pantry_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_pantry_grid)
	_refresh_pantry()

func _refresh_pantry() -> void :
	for child in _pantry_grid.get_children():
		_pantry_grid.remove_child(child)
		child.queue_free()
	for entry in session.active_ingredients():
		if _pantry_category != "all" and entry.get("category", "basic") != _pantry_category: continue
		if not _pantry_search.is_empty() and not str(entry.get("name", "")).contains(_pantry_search) and not str(entry.get("id", "")).contains(_pantry_search): continue
		var button: = _button(_pantry_grid, "%s\n%.0f g  ·  %s" % [entry["name"], float(entry.get("mass", 0.15)) * 1000.0, "需做熟" if entry.get("needs_cook", false) else "自由处理"], func(): _take_ingredient(entry), 198)
		button.custom_minimum_size.y = 162
		button.name = "Pantry_" + str(entry.id)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.disabled = not bool(_stock.get(str(entry.id), true))
		button.text += "\n剩余 1 件" if not button.disabled else "\n已取走"
		button.add_theme_font_size_override("font_size", 15)
		var thumbnail := preload("res://modules/restaurant/assets/food_art.gd").new()
		thumbnail.name = "FoodArt"
		thumbnail.definition = entry.duplicate(true)
		thumbnail.position = Vector2(99, 42)
		thumbnail.scale = Vector2.ONE * 0.82
		thumbnail.visible = not button.disabled
		button.add_child(thumbnail)
		var color: = Color(str(entry.get("color", "f0bf7d")))
		button.add_theme_stylebox_override("normal", _style(Color("e8ddc4").lerp(color, 0.12), 9, color.darkened(0.3)))
		# Reserve a separate image area so wide quantities and ingredient names
		# never draw over the artwork, including in hover/disabled states.
		for state in ["normal", "hover", "pressed", "disabled"]:
			var card := button.get_theme_stylebox(state).duplicate() as StyleBox
			card.content_margin_top = 82
			card.content_margin_bottom = 8
			button.add_theme_stylebox_override(state, card)
		button.tooltip_text = "质量 %.2f kg · 摩擦 %.2f · 弹性 %.2f\n怪异度 %d%%" % [entry.get("mass", 0.15), entry.get("friction", 0.6), entry.get("bounce", 0.1), int(float(entry.get("weirdness", 0)) * 100)]
		if not world.get_dispense_mode(entry).is_empty():
			button.tooltip_text += "\n" + world.ingredient_operation_hint(entry)

func _take_ingredient(entry: Dictionary, press_position := Vector2.INF) -> void :
	var id := str(entry.get("id", ""))
	if id.is_empty() or id in Session.BLOCKED_INGREDIENT_IDS: return
	if not bool(_stock.get(id, true)):
		_notify("这件%s已取走，请使用台面上的那一件。" % entry.get("name", "食材"))
		return
	var success := false
	if _stock_bodies.has(id) and is_instance_valid(_stock_bodies[id]):
		if not is_instance_valid(world._held) and not world._knife_held and not world.has_active_utensil() and not world.pan.active and world._foods.get_child_count() < 64:
			var stored: RigidBody2D = _stock_bodies[id]
			stored.reparent(world._foods)
			stored.visible = true
			world._pickup(stored)
			_stock_bodies.erase(id)
			success = true
	else:
		success = world.spawn_ingredient(entry)
	if success:
		_stock[id] = false
		storage_display.reveal_ingredient(id)
		storage_display.set_available(id, false)
		_close_modal()
		if press_position != Vector2.INF:
			world.begin_food_drag(world.get_global_transform_with_canvas().affine_inverse() * press_position, true)
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			world.begin_food_drag(world.get_local_mouse_position(), true)
		if not world.get_dispense_mode(entry).is_empty():
			_notify(world.ingredient_operation_hint(entry))
		else:
			_notify("拿起%s。移动到台面点击放下；拖进锅里下锅。" % entry["name"])
	else:
		if modal.visible:
			_text("请先把手里的物品放下；台面最多保留 64 个实体。", 17, ACCENT)
		else:
			_notify("先把手里的物品放到台面。台面最多保留 64 个实体。")

func _return_to_storage(body: RigidBody2D) -> bool:
	var id := str(body.get_meta("id", ""))
	if bool(_stock.get(id, true)): return false
	if not storage_display.slot_at(id, body.global_position): return false
	if body.get_meta("cut", false) or body.get_meta("dispensed", false) or float(body.get_meta("saved_heat", 0.0)) > 0.0 or float(body.get_meta("surface_sauce", {}).get("volume_ml", 0.0)) > 0.0:
		_notify("加工过的食材请留在菜板、锅或盘子里，不能放回原料格。")
		return false
	world._held = null
	world._sync_held_foreground()
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	body.visible = false
	body.reparent(self)
	_stock_bodies[id] = body
	_stock[id] = true
	storage_display.set_available(id, true)
	world.held_changed.emit("")
	_notify("已放回%s，保留原来的物品和余量。" % body.get_meta("title", "物品"))
	return true

func _plating_bottle(id: String) -> RigidBody2D:
	for body in world._foods.get_children():
		if body is RigidBody2D and not body.is_queued_for_deletion() and str(body.get_meta("id", "")) == id and bool(body.get_meta("is_container", false)):
			return body
	return null

func _dispense_plating_sauce(id: String, requested_ml: float) -> float:
	if requested_ml <= 0.0 or not is_finite(requested_ml): return 0.0
	var bottle := _plating_bottle(id)
	if bottle == null: return 0.0
	var remaining := maxf(0.0, float(bottle.get_meta("remaining_ml", 0.0)))
	var accepted := session.add_garnish(id, minf(requested_ml, remaining))
	if accepted <= 0.0: return 0.0
	bottle.set_meta("remaining_ml", remaining - accepted)
	bottle.refresh_response() # Packaging mass plus the actual remaining sauce.
	return accepted

func _serve() -> void :
	if not world.plated:
		_notify("请先把实际做好的食物装进餐具，再交给客人。")
		return
	for body in world._foods.get_children():
		if body.get_meta("enrolled", false) and not body.get_meta("plated", false) and not body.is_queued_for_deletion():
			_notify("还有食物没装盘。点击餐具，把本单料理装好后再出餐。")
			return
	var snapshot: Dictionary = session.plate()
	var result: Dictionary = session.serve()
	if result.is_empty():
		_notify(session.last_notice)
		return
	recipe_guide.active = false
	_update_recipe_guide()
	world.audio.play_effect("serve")
	world._backdrop.ring_bell()
	world.audio.play_effect("bell")
	_last_dish = snapshot
	if not (_photo_is_plating and _plating_photo_revision == _plating_revision): _photo = ""
	_pending_serve_result = result.duplicate(true)
	_open_modal("dish_showcase", "这道菜，做好了", 1030)
	_paper_modal()
	modal_panel.position.y = 24
	_label(modal_body, "从锅里到盘中，每一块都是刚才亲手做的。", Vector2.ZERO, 21, MUTED)
	var showcase := preload("res://modules/restaurant/ui/plating_canvas.gd").new()
	showcase.name = "FinishedDishShowcase"
	showcase.game = self
	showcase.render_only = true
	showcase.custom_minimum_size = Vector2(920, 475)
	modal_body.add_child(showcase)
	_label(modal_body, _dish_names(snapshot), Vector2.ZERO, 25, CREAM)
	var actions := _row(modal_body)
	_button(actions, "看看客人的反馈  →", _show_serve_feedback, 310)

func _show_serve_feedback() -> void:
	if _pending_serve_result.is_empty(): return
	var result: Dictionary = _pending_serve_result.duplicate(true)
	_pending_serve_result.clear()
	world.clear_food()
	_food_by_physics.clear()
	_open_modal("feedback", "这一口，客人怎么说", 860)
	var feedback_head := _row(modal_body)
	var sketch = preload("res://modules/restaurant/ui/customer_sketch.gd").new()
	sketch.customer_id = str(result.get("customer_id", "guest"))
	feedback_head.add_child(sketch)
	var feedback_title := VBoxContainer.new()
	feedback_head.add_child(feedback_title)
	_label(feedback_title, "%s  /  %d 分" % [result.get("customer", "客人"), result.get("score", 0)], Vector2.ZERO, 25, ACCENT)
	_label(feedback_title, "画在反馈纸上的小像  ·  %s" % result.get("role", "食客"), Vector2.ZERO, 17, MUTED)
	_text("%s  ·  %s" % [result.get("role", "食客"), result.get("reaction", "")], 18)
	var mood_row: = _row(modal_body)
	var before_icon: = MoodIcon.new()
	before_icon.mood = float(result.get("mood_before", 50))
	mood_row.add_child(before_icon)
	_label(mood_row, "餐前 %d" % result.get("mood_before", 50), Vector2.ZERO, 18)
	var after_icon: = MoodIcon.new()
	after_icon.mood = float(result.get("mood_after", 50))
	mood_row.add_child(after_icon)
	_label(mood_row, "餐后 %d   变化 %+d" % [result.get("mood_after", 50), result.get("mood_delta", 0)], Vector2.ZERO, 18, ACCENT)
	if not str(result.get("ordered_recipe_title", "")).is_empty():
		_text("点单：《%s》  /  与菜谱实材匹配 %d%%" % [result.ordered_recipe_title, roundi(maxf(0.0, float(result.get("recipe_match", 0.0))) * 100.0)], 18)
	_text("“%s”" % result.get("feedback", "谢谢招待。"), 25, CREAM)
	if not str(result.get("detail", "")).is_empty(): _text(str(result.detail), 20)
	_text("这次做得好，我会直接夸你；没做到的地方也写清楚，下次再一起试。" if int(result.get("score", 0)) < 80 else "这顿饭让我记住了，我愿意把这份称赞留在纸上。", 17, MUTED)
	_text("餐费 ¥%.2f   小费 ¥%.2f   赔偿 ¥%.2f\n本单净收入 ¥%.2f   本班合计 ¥%.2f" % [result.get("meal_fee", 0), result.get("tip", 0), result.get("compensation", 0), result.get("payment", 0), session.revenue], 22)
	var letter_index := _record_feedback(result)
	var reply := TextEdit.new()
	reply.placeholder_text = "写给这位客人的回复……"
	reply.custom_minimum_size = Vector2(790, 62)
	modal_body.add_child(reply)
	var row: = _row(modal_body)
	_button(row, "保存回复", func(): _save_reply(letter_index, reply.text), 160)
	_button(row, "继续招待下一位", _close_modal, 280)
	_button(row, "把这道菜写入菜谱", _show_recipe_editor, 320)

func _new_diy_recipe() -> void :
	_show_recipe_editor({},true)

func _show_recipe_editor(record: Dictionary = {}, illustrated: bool = false) -> void :
	world.audio.play_effect("paper")
	_open_authoring("recipe_editor", "厨房手作 · 留住这一餐")
	illustrated=illustrated or record.get("poster",{}).has("recipe_sheet")
	_editing_recipe_id = str(record.get("id", ""))
	_active_recipe_draft_key = _editing_recipe_id if not _editing_recipe_id.is_empty() else ("new_illustrated" if illustrated else "new")
	var paper_record: Dictionary = _recipe_drafts.get(_active_recipe_draft_key,record).duplicate(true)
	if record.is_empty():
		_recipe_dish = (session.plate() if not session.dish.is_empty() else _last_dish).duplicate(true)
		if _recipe_dish.is_empty(): _recipe_dish = {"ingredients": []}
		_recipe_photo = _photo if (_photo_is_plating and _plating_photo_revision == _plating_revision) or session.dish.is_empty() else ""
	else:
		_recipe_dish = record.get("dish", {"ingredients": []}).duplicate(true)
		_recipe_photo = str(record.get("thumbnail", ""))
	if _recipe_drafts.has(_active_recipe_draft_key):
		_recipe_dish = paper_record.dish.duplicate(true)
		_recipe_photo = str(paper_record.get("thumbnail",""))
	_recipe_canvas = PosterCanvas.new()
	modal_body.add_child(_recipe_canvas)
	if paper_record.has("poster"): _recipe_canvas.import_data(paper_record.poster)
	var desk
	if illustrated:
		if _recipe_canvas.recipe_sheet.is_empty():
			_recipe_canvas.recipe_sheet=preload("res://modules/restaurant/ui/recipe_sheet.gd").from_dish(_recipe_dish,session.ingredients)
			_recipe_canvas._rebuild_layers()
		desk=preload("res://modules/restaurant/ui/recipe_drawing_workbench.gd").new()
		modal_body.add_child(desk)
		desk.build(self,_recipe_canvas,paper_record)
	else:
		desk=preload("res://modules/restaurant/ui/craft_workbench.gd").new()
		modal_body.add_child(desk)
		desk.build(self,_recipe_canvas,paper_record,_recipe_dish)
	_title_input=desk.title_input
	_author_input=desk.author_input
	_notes_input=desk.notes_input
	_editor_status=desk.status
	if _recipe_drafts.has(_active_recipe_draft_key): _editor_status.text="接着写刚才那一页。收进菜谱后会永久保存。"
	var actions := _row(modal_body)
	_paper_action(actions,"保存修改" if not _editing_recipe_id.is_empty() else "收进我的菜谱",_save_recipe,"book",220)
	if not _editing_recipe_id.is_empty(): _paper_action(actions,"另存为新菜谱",func(): _save_recipe(true),"book",220)
	_paper_action(actions,"先收起纸页",_close_modal,"arrow",190)

func _stash_recipe_draft() -> void:
	if _modal_kind != "recipe_editor" or _active_recipe_draft_key.is_empty() or not is_instance_valid(_recipe_canvas) or not is_instance_valid(_title_input): return
	var poster: Dictionary = _recipe_canvas.export_data()
	if _recipe_canvas.has_content() or poster.has("recipe_sheet") or not _title_input.text.strip_edges().is_empty() or not _notes_input.text.strip_edges().is_empty():
		_recipe_drafts[_active_recipe_draft_key] = {"title":_title_input.text,"author":_author_input.text,"notes":_notes_input.text,"dish":_recipe_dish.duplicate(true),"thumbnail":_recipe_photo,"poster":poster}

func _show_order_paper() -> void:
	_open_modal("order_paper","客人留的小纸条",650)
	var paper=preload("res://modules/restaurant/ui/paper_surface.gd").new()
	paper.custom_minimum_size=Vector2(590,520)
	modal_body.add_child(paper)
	var words=Label.new()
	words.text=_order_paper.full_text
	words.add_theme_font_override("font",preload("res://modules/restaurant/ui/paper_ink.gd").font())
	words.add_theme_font_size_override("font_size",27)
	words.add_theme_color_override("font_color",Color("5b4935"))
	words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var scroll=ScrollContainer.new()
	scroll.position=Vector2(32,28)
	scroll.size=Vector2(526,462)
	paper.add_child(scroll)
	scroll.add_child(words)

func _open_authoring(kind: String, title: String) -> void :
	_open_modal(kind, title, 1400)
	modal_panel.add_theme_stylebox_override("panel", _style(Color("c9b793"), 0, Color("aa9576")))
	modal_panel.position.y = 12
	modal_body.add_theme_constant_override("separation",6)

func _tool_button(parent: Node, text: String, callback: Callable, width: float = 0) -> Button:
	var button: = _button(parent, text, callback, width)
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size", 16)
	var normal: StyleBoxFlat = _style(Color("f3dfa1"))
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("ffe9a0")
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("e6c86f")
	button.add_theme_stylebox_override("pressed", pressed)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button

func _import_collage_photo(canvas) -> void :
	var dialog: = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; 图片素材"])
	modal.add_child(dialog)
	dialog.file_selected.connect( func(path: String):
		if not is_instance_valid(canvas):
			dialog.queue_free()
			return
		var source: = Image.load_from_file(path)
		if source == null or source.is_empty():
			_editor_status.text = "这张图片未能读取，请选择 PNG、JPG 或 WebP。"
		else:
			var previous_count: int = canvas.stickers.size()
			canvas.add_photo(ImageTexture.create_from_image(source))
			_editor_status.text = "图片已加入。可移动、缩放、旋转或剪成形状。" if canvas.stickers.size() > previous_count else "未加入图片：纸面最多 32 个素材，请删除一些或换一张较小的图。"
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(1000, 640))

func _add_dish_photo(canvas) -> void :
	if session.dish.is_empty() and _last_dish.is_empty():
		_editor_status.text = "先做一道菜，再拍摄料理；也可以导入自己的图片。"
		return
	if _photo.is_empty() or not _photo_is_plating or _plating_photo_revision != _plating_revision:
		_editor_status.text = "请先到装盘台摆好实际食物，选择“拍照并加入菜谱”。"
		return
	if not is_instance_valid(canvas): return
	if _photo.is_empty():
		_editor_status.text = "暂时无法拍摄。"
		return
	var source: = Image.new()
	if source.load_png_from_buffer(Marshalls.base64_to_raw(_photo)) == OK:
		if is_instance_valid(_recipe_canvas) and canvas == _recipe_canvas: _recipe_photo = _photo
		var previous_count: int = canvas.stickers.size()
		canvas.add_photo(ImageTexture.create_from_image(source))
		_editor_status.text = "实拍照片已加入纸面，可以继续剪贴。" if canvas.stickers.size() > previous_count else "纸面已满，最多 32 个素材；请先删除不需要的内容。"

func _capture_photo() -> void :
	await _snapshot_photo()
	if _modal_kind == "recipe_editor": _recipe_photo = _photo
	if is_instance_valid(_editor_status):
		_editor_status.text = "照片已拍好，将随这道菜一起保存。"

func _snapshot_photo() -> void :
	_photo_is_plating = false
	if DisplayServer.get_name() == "headless":
		_photo = ""
		return
	layer.visible = false
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	img.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	_photo = Marshalls.raw_to_base64(img.save_png_to_buffer())
	layer.visible = true

func _save_recipe(as_copy: bool = false) -> void :
	var poster: Dictionary=_recipe_canvas.export_data()
	var title: String=_title_input.text.strip_edges()
	var notes: String=_notes_input.text.left(2000)
	if poster.has("recipe_sheet"):
		var sheet=preload("res://modules/restaurant/ui/recipe_sheet.gd")
		if not sheet.has_title(poster):
			_editor_status.text="先用涂鸦笔，在纸页顶部手写菜名。"; return
		if not sheet.has_drawing(poster):
			_editor_status.text="再给一道步骤画上自己的配图。"; return
		if title.is_empty() or as_copy: title="手绘菜谱 %d" % (repository.load_recipes().size()+1)
		notes="材料：\n"+str(poster.recipe_sheet.materials)
		for i in 4: notes+="\n%d. %s" % [i+1,poster.recipe_sheet.steps[i]]
	elif title.is_empty():
		_editor_status.text = "先在纸页上方写下菜名，再收进菜谱。"
		return
	var clean_dish: Dictionary = _recipe_dish.duplicate(true)
	for entry in clean_dish.get("ingredients", []):
		if entry is Dictionary:
			entry.erase("physics_id")
			entry.erase("off_heat")
	var record: = {"title": title, "author": _author_input.text.strip_edges(), "notes": notes, "dish": clean_dish, "thumbnail": _recipe_photo, "poster": poster}
	var target_id: String = "" if as_copy else _editing_recipe_id
	if not target_id.is_empty(): record["id"] = target_id
	if repository.save_recipe(record):
		_recipe_drafts.erase(_active_recipe_draft_key)
		_active_recipe_draft_key=""
		var saved: Array = repository.load_recipes()
		session.set_menu_recipes(saved)
		if not saved.is_empty(): _recipe_selected = saved[-1] if target_id.is_empty() else record
		_refresh_recipe_stand()
		if target_id.is_empty():
			if not saved.is_empty(): recipe_published.emit(saved[-1].duplicate(true))
		else:
			for entry in saved:
				if str(entry.get("id", "")) == target_id:
					recipe_published.emit(entry.duplicate(true))
					break
		_recipe_photo = ""
		_show_cookbook()
	else:
		_editor_status.text = "保存失败：" + repository.get_last_error()

func _dish_names(data: Dictionary) -> String:
	var names: PackedStringArray = []
	for entry in data.get("ingredients", []):
		var id: String = str(entry) if entry is String else str(entry.get("id", entry.get("ingredient_id", "")))
		var title := str(_definition(id).get("name", id))
		if not title in names: names.append(title)
	return " + ".join(names) if not names.is_empty() else "尚未记录实际用料"

func _refresh_recipe_stand() -> void:
	var records: Array = repository.load_recipes()
	var selected: Dictionary = records[-1] if not records.is_empty() else RecipeMethod.starter()
	if _recipe_selected.get("reference", false): selected = _recipe_selected
	for entry in records:
		if entry.get("id", "") == _recipe_selected.get("id", "__none__"):
			selected = entry
	_recipe_selected = selected
	_recipe_stand.setup(selected)

func _recipe_page_preview(parent: Node, dimensions: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.name = "SharedRecipePage"
	picture.texture = _recipe_stand.viewport.get_texture()
	picture.custom_minimum_size = dimensions
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	return picture

func _show_cookbook() -> void :
	_refresh_recipe_stand()
	_open_modal("cookbook", "厨房手记", 1190)
	_paper_modal()
	_text("翻到想做的那一页，带着它回厨房。", 18)
	var row: = _row(modal_body)
	_paper_action(row, "新建 DIY 菜谱", _new_diy_recipe, "book", 260)
	_paper_action(row,"自由拼贴手记",func(): _show_recipe_editor(),"book",190)
	_button(row, "导出菜谱文件", func(): _file_dialog(true), 210)
	_button(row, "导入其他人的菜谱", func(): _file_dialog(false), 240)
	var recipes: Array = repository.load_recipes()
	var columns := _row(modal_body)
	_recipe_page_preview(columns, Vector2(395, 536))
	var scroll: = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(710, 536)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	var list: = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	_label(list, "先从一碗热面开始", Vector2.ZERO, 23, CREAM)
	_paper_action(list, "番茄清汤面  ·  厨房示范", func(): _view_recipe(RecipeMethod.starter()))
	_label(list, "我的菜谱  /  %d 页" % recipes.size(), Vector2.ZERO, 21, ACCENT)
	if recipes.is_empty():
		var empty: = _label(list, "还没有写下自己的菜谱。\n\n做好一道菜、拍张照片，\n把今天的做法记在这里。", Vector2.ZERO, 21, MUTED)
		empty.custom_minimum_size.y = 210
	for record in recipes:
		var button: = _button(list, "%s    /    %s\n%s" % [record.get("title", "未命名"), record.get("author", "匿名主厨"), _dish_names(record.get("dish", {}))], func(): _view_recipe(record))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.custom_minimum_size.y = 90

func _view_recipe(record: Dictionary) -> void :
	_recipe_pages.clear()
	_recipe_pages.append(RecipeMethod.starter())
	for saved in repository.load_recipes(): _recipe_pages.append(saved)
	_recipe_page_index = 0
	for index in _recipe_pages.size():
		if str(_recipe_pages[index].get("id", "")) == str(record.get("id", "")):
			_recipe_page_index = index
			break
	_recipe_selected = record
	_recipe_stand.setup(record)
	if record.get("poster",{}).has("recipe_sheet"):
		_view_drawing_recipe(record); return
	_open_modal("recipe", str(record.get("title", "菜谱")), 1230)
	_paper_modal()
	modal_body.add_theme_constant_override("separation", 10)
	var columns := _row(modal_body)
	_recipe_page_preview(columns, Vector2(418, 567))
	var divider := VSeparator.new()
	columns.add_child(divider)
	var scroll := ScrollContainer.new()
	scroll.name = "RecipeMethodScroll"
	scroll.custom_minimum_size = Vector2(704, 567)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	var method := VBoxContainer.new()
	method.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	method.add_theme_constant_override("separation", 15)
	scroll.add_child(method)
	var full_title := Label.new()
	full_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	full_title.custom_minimum_size.x = 660
	full_title.size.x = 660
	full_title.text = str(record.get("title", ""))
	full_title.add_theme_font_size_override("font_size", 23)
	method.add_child(full_title)
	var ingredients := _label(method, _dish_names(record.get("dish", {})), Vector2.ZERO, 20, CREAM)
	ingredients.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(method, "厨房示范 · 状态示意" if record.get("reference", false) else "按成品状态整理 · 过程图为做法示意", Vector2.ZERO, 16, MUTED)
	var sequence := RecipeMethod.steps(record, session.ingredients)
	for i in range(sequence.size()):
		var step: Dictionary = sequence[i]
		var line := _row(method)
		var sketch := RecipeVignette.new()
		sketch.stage = step.art
		sketch.catalog = session.ingredients
		sketch.entries = [step.target] if step.has("target") else ([] if step.kind == "water" else RecipeMethod.targets(record))
		sketch.custom_minimum_size = Vector2(166, 88)
		line.add_child(sketch)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(words)
		var heading := _label(words, "%02d  %s" % [i + 1, step.title], Vector2.ZERO, 22, CREAM)
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var detail := _label(words, step.detail, Vector2.ZERO, 17, MUTED)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _recipe_stand.page._image != null:
		_label(method, "这次做好的样子 · 实拍", Vector2.ZERO, 21, CREAM)
		var photo := TextureRect.new()
		photo.name = "ActualRecipePhoto"
		photo.texture = _recipe_stand.page._image
		photo.custom_minimum_size = Vector2(620, 285)
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		method.add_child(photo)
	if not str(record.get("notes", "")).is_empty():
		_label(method, "主厨的叮嘱", Vector2.ZERO, 20, ACCENT)
		var notes := _label(method, record.notes, Vector2.ZERO, 18, MUTED)
		notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var page_row := _row(modal_body)
	var previous_page := _paper_action(page_row, "← 上一页", func(): _turn_recipe(-1), "arrow", 175)
	previous_page.disabled = _recipe_page_index == 0
	_label(page_row, "第 %d / %d 页" % [_recipe_page_index + 1, _recipe_pages.size()], Vector2.ZERO, 19, MUTED)
	var next_page := _paper_action(page_row, "下一页 →", func(): _turn_recipe(1), "arrow", 175)
	next_page.disabled = _recipe_page_index >= _recipe_pages.size() - 1

	var row: = _row(modal_body)
	var follow := _paper_action(row, "照着做这道菜", func(): _start_recipe_guide(record), "check", 245)
	follow.name = "FollowRecipe"
	var retired_ingredient := _recipe_has_retired_ingredient(record)
	follow.disabled = sequence.is_empty() or session.phase == "closed" or retired_ingredient
	follow.tooltip_text = "这道旧菜谱含已下架的米饭，仍可翻阅和分享。" if retired_ingredient else ("收班后可翻阅，重新进入厨房后再跟做。" if session.phase == "closed" else "按真实切配、入锅和熟度推进；不会替你做菜。")
	if not record.get("reference", false):
		if not retired_ingredient:
			_paper_action(row, "继续 DIY", func(): _show_recipe_editor(record), "book", 180)
		_paper_action(row, "分享这一页", func(): _share_recipe_page(record), "book", 180)
		_button(row, "喜欢这道菜", func():
			var liked: bool = repository.like_recipe(str(record.get("id", "")))
			_notify("谢谢，你的喜欢已记下。" if liked else "这次没有新增喜欢：" + repository.get_last_error()), 150)
	_paper_action(row, "翻到目录", _show_cookbook, "arrow", 210)
	if session.phase == "closed": _text("今天已经收班。先收好做法，下次营业再试。", 16)

func _view_drawing_recipe(record: Dictionary) -> void:
	_open_modal("recipe","翻开亲手画的菜谱",1230)
	_paper_modal()
	var columns := _row(modal_body)
	_recipe_page_preview(columns,Vector2(485,658))
	var words := VBoxContainer.new(); words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation",22); columns.add_child(words)
	_label(words,"菜名和配图，都是你的笔迹",Vector2.ZERO,27,CREAM)
	_text_in(words,"材料与步骤留在纸上，\n下次做菜，翻开这一页就能看。",21)
	_label(words,"主厨 · "+str(record.get("author","主厨")),Vector2.ZERO,20,MUTED)
	_label(words,"尚未记录实际用料" if record.get("dish",{}).get("ingredients",[]).is_empty() else _dish_names(record.dish),Vector2.ZERO,18,MUTED)
	_paper_action(words,"继续 DIY",func(): _show_recipe_editor(record),"book",240)
	_paper_action(words,"分享这一页",func(): _share_recipe_page(record),"book",240)
	if not record.get("dish",{}).get("ingredients",[]).is_empty():
		_paper_action(words,"照着做这道菜",func(): _start_recipe_guide(record),"check",240)
	_paper_action(words,"翻到目录",_show_cookbook,"arrow",240)
	var row := _row(modal_body)
	var previous := _paper_action(row,"← 上一页",func(): _turn_recipe(-1),"arrow",175)
	previous.disabled=_recipe_page_index==0
	_label(row,"第 %d / %d 页" % [_recipe_page_index+1,_recipe_pages.size()],Vector2.ZERO,19,MUTED)
	var next := _paper_action(row,"下一页 →",func(): _turn_recipe(1),"arrow",175)
	next.disabled=_recipe_page_index>=_recipe_pages.size()-1

func _text_in(parent: Node, words: String, font_size: int) -> void:
	var label := _label(parent,words,Vector2.ZERO,font_size,CREAM)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x=620

func _turn_recipe(direction: int) -> void:
	if _recipe_turning or _modal_kind != "recipe" or _recipe_pages.is_empty(): return
	var target := _recipe_page_index + direction
	if target < 0 or target >= _recipe_pages.size(): return
	_recipe_turning = true
	var page := modal_body.find_child("SharedRecipePage", true, false) as TextureRect
	if is_instance_valid(page):
		page.pivot_offset = page.size * 0.5
		var fold := create_tween()
		fold.tween_property(page, "scale:x", 0.05, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await fold.finished
		if _modal_kind != "recipe":
			_recipe_turning = false
			return
	_view_recipe(_recipe_pages[target])
	await get_tree().process_frame
	page = modal_body.find_child("SharedRecipePage", true, false) as TextureRect
	if is_instance_valid(page):
		page.pivot_offset = page.size * 0.5
		page.scale.x = 0.05
		var unfold := create_tween()
		unfold.tween_property(page, "scale:x", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await unfold.finished
	_recipe_turning = false
func _share_recipe_page(record: Dictionary) -> void:
	var dialog := FileDialog.new()
	dialog.title = "分享这一页 · 朋友用浏览器就能看"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.html ; 图文菜谱（内附可编辑菜谱文件）", "*.json ; 只导出这一页的可编辑菜谱"])
	dialog.current_file = "kitchen_recipe.html"
	dialog.size = Vector2i(1000, 660)
	modal.add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		var error: Error
		if path.get_extension().to_lower() == "json":
			error = repository.export_recipe_to(str(record.id), path)
		else:
			var image: Image = _recipe_stand.viewport.get_texture().get_image()
			var png := "" if image == null else Marshalls.raw_to_base64(image.save_png_to_buffer())
			error = repository.export_reading_page(str(record.id), path, png, session.ingredients)
		_text("这一页已保存。把文件发给朋友即可观看；页面下方也能下载菜谱带回游戏。" if error == OK else "未能保存：" + repository.get_last_error(), 17, ACCENT)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _build_recipe_guide() -> void:
	_guide_bar = PanelContainer.new()
	_guide_bar.name = "RecipeGuideFooter"
	_guide_bar.position = Vector2(0, 900)
	_guide_bar.size = Vector2(1600, 46)
	var skin := _style(Color("eae0bd"))
	skin.content_margin_top = 3
	skin.content_margin_bottom = 3
	_guide_bar.add_theme_stylebox_override("panel", skin)
	hud.add_child(_guide_bar)
	var row := _row(_guide_bar)
	_guide_text = _label(row, "", Vector2.ZERO, 15, DARK)
	_guide_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guide_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_guide_text.clip_text = true
	var view := _button(row, "看做法", func(): _view_recipe(recipe_guide.record), 90)
	var stop := _button(row, "收起引导", func(): recipe_guide.active = false; _update_recipe_guide(), 108)
	for button in [view, stop]:
		button.custom_minimum_size.y = 38
		var flat := StyleBoxEmpty.new()
		flat.set_content_margin_all(4)
		button.add_theme_stylebox_override("normal", flat)
		button.add_theme_font_size_override("font_size", 15)
	_guide_bar.visible = false

func _recipe_has_retired_ingredient(record: Dictionary) -> bool:
	var dish: Dictionary = record.get("dish", {})
	for item in dish.get("ingredients", []):
		var ingredient_id: String = str(item.get("id", item.get("ingredient_id", ""))) if item is Dictionary else str(item)
		if ingredient_id in repository.RETIRED_INGREDIENT_IDS: return true
	return false

func _start_recipe_guide(record: Dictionary) -> void:
	if session.phase == "closed" or _recipe_has_retired_ingredient(record): return
	recipe_guide.start(record, session.ingredients)
	_close_modal()
	_update_recipe_guide()

func _recipe_snapshot() -> Dictionary:
	var foods: Array = []
	for body in world._foods.get_children():
		if body.is_queued_for_deletion() or body.get_meta("overflow", false) or body.get_meta("rejected", false) or not body.visible: continue
		var item: Dictionary = world.describe_body(body)
		item.merge({"id":str(body.get_meta("id", "")), "cut":body.get_meta("cut", false), "is_container":body.get_meta("is_container", false), "enrolled":body.get_meta("enrolled", false), "plated":body.get_meta("plated", false), "heat":body.get_meta("saved_heat", 0.0)}, true)
		for current in session.dish:
			if int(current.get("physics_id", 0)) == body.get_instance_id():
				item.heat = float(current.get("heat", 0))
				item["softness"] = float(current.get("softness", 0))
		foods.append(item)
	return {"foods":foods, "water_ml":world.pan.water_ml, "plated_water_ml":float(session.presentation.get("broth_ml", 0.0)), "heating":session.heating, "garnishes":session.garnishes}

func _update_recipe_guide() -> void:
	if not is_instance_valid(_guide_bar): return
	_guide_bar.visible = recipe_guide.active and session.phase != "closed" and not modal.visible
	if not recipe_guide.active: return
	recipe_guide.update(_recipe_snapshot())
	if recipe_guide.index >= recipe_guide.sequence.size():
		_guide_text.text = "这一餐做好了  ·  可以拍照留作菜谱，或出餐给客人。"
	else:
		var step: Dictionary = recipe_guide.sequence[recipe_guide.index]
		_guide_text.text = "%d / %d  %s  ·  %s" % [recipe_guide.index + 1, recipe_guide.sequence.size(), step.title, step.detail]
		if step.kind == "take" and not bool(_stock.get(str(step.target.id), true)):
			_guide_text.text += " 这份若已丢弃或用完，需要下次营业再备。"
		for item in session.dish:
			if float(item.get("heat", 0)) <= 14: continue
			for target in RecipeMethod.targets(recipe_guide.record):
				if item.id == target.id and target.heat <= 14:
					_guide_text.text = "火候超过这页的做法了，先关火。可以保留这次实验自由出餐，或收起引导下次再试。"
	_guide_text.tooltip_text = _guide_text.text

func _file_dialog(exporting: bool) -> void :
	var dialog: = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if exporting else FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.json ; 菜谱交换文件"])
	dialog.current_file = "after_hours_cookbook.json" if exporting else ""
	dialog.size = Vector2i(1000, 660)
	modal.add_child(dialog)
	dialog.file_selected.connect( func(path: String):
		if exporting:
			var error: Error = repository.export_to(path)
			_text("菜谱已导出，可把 JSON 文件发给朋友。" if error == OK else "导出失败：" + repository.get_last_error(), 17, ACCENT)
		else:
			var result: Dictionary = repository.import_from(path)
			_show_cookbook()
			_text("导入 %d 道菜谱。%s" % [result.get("added", 0), result.get("error", "")], 17, ACCENT)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _show_poster() -> void :
	world.audio.play_effect("paper")
	_open_authoring("poster", "海报工作台  /  从一张白纸开始")
	_poster_canvas = PosterCanvas.new()
	modal_body.add_child(_poster_canvas)
	var desk = preload("res://modules/restaurant/ui/craft_workbench.gd").new()
	modal_body.add_child(desk)
	var current: Dictionary = session.plate() if not session.dish.is_empty() else _last_dish
	desk.build(self,_poster_canvas,{},current,false)
	_editor_status=desk.status
	var tag_row := _row(modal_body)
	var load_previous = _paper_action(tag_row,"继续编辑已贴出的海报",func(): _poster_canvas.import_data(_poster_data),"book",260)
	load_previous.disabled=_poster_data.is_empty()
	_button(tag_row, "贴出去 · 家常料理", func(): _publish_poster(["comfort", "fresh", "vegetable"]), 300)
	_button(tag_row, "贴出去 · 怪味特供", func(): _publish_poster(["odd", "bold"]), 300)
	_button(tag_row, "贴出去 · 甜点小食", func(): _publish_poster(["sweet", "dairy"]), 300)

func _publish_poster(tags: Array) -> void :
	_poster_data = _poster_canvas.export_data()
	_poster_data["tags"] = tags
	if not poster_store.save_poster(_poster_data):
		_text("海报未能保存：" + poster_store.get_last_error(), 16, ACCENT)
		return
	world.set_poster(_poster_data)
	session.apply_poster(tags)
	poster_published.emit(_poster_data.duplicate(true))
	_close_modal()
	_notify("海报已贴出。有空、路过看见并感兴趣的客人才会来。")

func _settle(show_result: bool = true) -> void :
	var result: Dictionary = session.end_shift().duplicate(true)
	result["session_id"] = session_id
	result["player_id"] = str(context.get("player_id", "local_demo"))
	if not _result_emitted:
		_result_emitted = true
		shift_completed.emit(result.duplicate(true))
	world.set_cooking(false)
	if not show_result: return
	_open_modal("result", "今天也好好做饭了", 790)
	_paper_modal()
	modal_panel.position.y = 188
	_text("100饭店   /   今日小记", 18, ACCENT)
	var receipt := HSeparator.new()
	modal_body.add_child(receipt)
	_text("营业收入    ¥ %.2f\n主厨收入    ¥ %.2f" % [result.get("revenue", 0), result.get("share", 0)], 32, CREAM)
	_text("成功招待 %d 位  ·  离开 %d 位\n分成按营业收入的 30%% 计算。" % [result.get("served", 0), result.get("missed", 0)], 20)
	_text("你留下的菜谱还在，下一位主厨可以接着做。", 18)
	var actions := _row(modal_body)
	var leave := _paper_action(actions, "收起围裙", _request_exit, "arrow", 280)
	leave.tooltip_text = "结算已保存，返回游戏入口。"
	_paper_action(actions, "翻开厨房手记", _show_cookbook, "book", 360)

func _request_exit() -> void :
	if not _result_emitted: _settle(false)
	world.set_controls_enabled(false)
	Input.mouse_mode = _saved_mouse_mode
	exit_requested.emit()

func _plating_changed() -> void :
	_plating_revision += 1

func _set_serving_vessel(vessel: String) -> void:
	if vessel not in ["plate", "bowl"]: return
	if vessel == "plate" and float(session.presentation.get("broth_ml", 0.0)) > 0.001:
		_plating_canvas.status.emit("碗里还有汤；请先倒回锅，再换平盘。")
		return
	session.presentation["vessel"] = vessel
	world.plate.queue_redraw()
	_plating_canvas.queue_redraw()
	_plating_canvas.changed.emit()
	_plating_canvas.status.emit("已换成汤碗，可以盛汤。" if vessel == "bowl" else "已换成平盘。")

func _transfer_broth_to_bowl(requested_ml: float) -> float:
	if not is_instance_valid(_plating_canvas) or str(session.presentation.get("vessel", "plate")) != "bowl": return 0.0
	var previous := float(session.presentation.get("broth_ml", 0.0))
	var amount := minf(maxf(0.0, requested_ml), minf(world.pan.water_ml, maxf(0.0, 750.0 - previous)))
	if amount <= 0.001: return 0.0
	var previous_c := float(session.presentation.get("broth_c", 22.0))
	session.presentation["broth_ml"] = previous + amount
	session.presentation["broth_c"] = (previous * previous_c + amount * world.pan.water_heat) / (previous + amount)
	world.pan.water_ml -= amount
	session.water_ml = world.pan.water_ml
	world.plate.queue_redraw()
	_plating_canvas.queue_redraw()
	_plating_canvas.changed.emit()
	_plating_canvas.status.emit("从锅里盛出 %.0f ml 汤；碗中共 %.0f ml。" % [amount, previous + amount])
	return amount

func _return_broth_to_pan() -> float:
	var amount := float(session.presentation.get("broth_ml", 0.0))
	if amount <= 0.001: return 0.0
	if amount > world.pan_free_ml() + 0.001: return 0.0
	var old_pan: float = world.pan.water_ml
	world.pan.water_heat = (old_pan * world.pan.water_heat + amount * float(session.presentation.get("broth_c", 22.0))) / (old_pan + amount)
	world.pan.water_ml += amount
	session.water_ml = world.pan.water_ml
	session.presentation.erase("broth_ml")
	session.presentation.erase("broth_c")
	world.plate.queue_redraw()
	if is_instance_valid(_plating_canvas):
		_plating_canvas.queue_redraw()
		_plating_canvas.changed.emit()
	return amount

func _pour_broth_action() -> void:
	if _transfer_broth_to_bowl(100.0) <= 0.0:
		_plating_canvas.status.emit("先选汤碗，并确认锅里有汤；汤碗最多盛 750 ml。")

func _return_broth_action() -> void:
	if _return_broth_to_pan() <= 0.0:
		_plating_canvas.status.emit("锅里空间不够，先倒出一些汤。" if float(session.presentation.get("broth_ml", 0.0)) > 0.001 else "汤碗里还没有汤。")

func _show_plating() -> void :
	_open_modal("plating", "摆盘工作台  /  让这一餐成为你的作品", 1100)
	modal_panel.position.y = 140
	var columns: = _row(modal_body)
	_plating_canvas = preload("res://modules/restaurant/ui/plating_canvas.gd").new()
	_plating_canvas.game = self
	columns.add_child(_plating_canvas)
	_plating_canvas.changed.connect(_plating_changed)
	var tools: = VBoxContainer.new()
	tools.custom_minimum_size.x = 330
	tools.add_theme_constant_override("separation", 8)
	var tools_scroll: = ScrollContainer.new()
	tools_scroll.custom_minimum_size = Vector2(340, 360)
	tools_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(tools_scroll)
	tools_scroll.add_child(tools)
	_label(tools, "选用成品容器", Vector2.ZERO, 19)
	var vessel_row := _row(tools)
	_tool_button(vessel_row, "平盘", func(): _set_serving_vessel("plate"), 138)
	_tool_button(vessel_row, "汤碗", func(): _set_serving_vessel("bowl"), 138)
	_tool_button(tools, "从锅盛汤（100 ml）", _pour_broth_action, 280)
	_tool_button(tools, "汤倒回锅", _return_broth_action, 280)
	_label(tools, "按同一次切出的整组装盘", Vector2.ZERO, 19)
	var all_food: Array = []
	var batches: Dictionary = {}
	for body in world._foods.get_children():
		if body.is_queued_for_deletion() or not body.get_meta("enrolled", false): continue
		all_food.append(body)
		var batch_uid := str(body.get_meta("batch_uid", body.get_meta("instance_uid", body.get_instance_id())))
		if not batches.has(batch_uid): batches[batch_uid] = []
		batches[batch_uid].append(body)
	if not all_food.is_empty():
		_tool_button(tools, "全部装盘（%d 块）" % all_food.size(), func(): _plate_bodies(all_food), 280)
	for batch_uid in batches:
		var batch_bodies: Array = batches[batch_uid]
		var title := str(batch_bodies[0].get_meta("title", "食物"))
		_tool_button(tools, "%s × %d" % [title, batch_bodies.size()], func(): _plate_bodies(batch_bodies), 280)
	var modes: = _row(tools)
	_tool_button(modes, "移动食物", func(): _plating_canvas.mode = "move", 144)
	_tool_button(modes, "成品淋酱", func(): _plating_canvas.mode = "sauce", 144)
	var sauces: = OptionButton.new()
	sauces.custom_minimum_size = Vector2(300, 38)
	var first_available_sauce := -1
	for id in ["ketchup", "mayonnaise", "mustard", "chili_sauce", "soy_sauce", "honey"]:
		var bottle := _plating_bottle(id)
		var remaining := float(bottle.get_meta("remaining_ml", 0.0)) if bottle != null else 0.0
		sauces.add_item("%s  %.0f ml" % [_definition(id).get("name", id), remaining])
		sauces.set_item_metadata(sauces.item_count - 1, id)
		sauces.set_item_disabled(sauces.item_count - 1, remaining <= 0.001)
		if first_available_sauce < 0 and remaining > 0.001: first_available_sauce = sauces.item_count - 1
	if first_available_sauce >= 0:
		sauces.select(first_available_sauce)
		_plating_canvas.sauce_id = str(sauces.get_item_metadata(first_available_sauce))
	sauces.item_selected.connect( func(index: int): _plating_canvas.stop_gesture();_plating_canvas.sauce_id = str(sauces.get_item_metadata(index));_plating_canvas.mode = "sauce")
	tools.add_child(sauces)
	var rotation_row: = _row(tools)
	_tool_button(rotation_row, "逆时针", func(): _plating_canvas.rotate_selected( - PI / 12), 95)
	_tool_button(rotation_row, "顺时针", func(): _plating_canvas.rotate_selected(PI / 12), 95)
	_tool_button(rotation_row, "清除酱汁", _plating_canvas.clear_sauce, 110)
	var description: = _label(tools, "拖动食物；按钮或滚轮旋转。\n先从架上取出酱瓶，淋酱会扣瓶内余量。\n淋酱时按住鼠标，松手停止。", Vector2.ZERO, 16, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 300
	var status_label: = _label(modal_body, "照片只记录当前餐具中的实际食物和汤。选择交给客人，或带进 DIY 菜谱继续拼贴。", Vector2.ZERO, 17, MUTED)
	_plating_canvas.status.connect( func(message: String): status_label.text = message)
	var actions: = _row(modal_body)
	_button(actions, "拍照并交给顾客", func(): await _photograph_and_serve(status_label), 280)
	_button(actions, "拍照并加入菜谱", func(): await _photograph_and_recipe(status_label), 280)
	_button(actions, "完成摆盘，回厨房", _close_modal, 280)

func _plate_bodies(bodies: Array) -> void:
	if not is_instance_valid(_plating_canvas): return
	_plating_canvas.mode = "move"
	for body in bodies:
		if is_instance_valid(body) and body.get_meta("enrolled", false):
			_plating_canvas.add_to_plate(body)

func _photograph_and_serve(status_label: Label) -> void:
	await _photograph_plating()
	if _photo.is_empty():
		status_label.text = "照片没有生成，请再试一次。"
		return
	_close_modal()
	_serve()

func _photograph_and_recipe(status_label: Label) -> void:
	await _photograph_plating()
	if _photo.is_empty():
		status_label.text = "照片没有生成，请再试一次。"
		return
	_last_dish = session.plate()
	_show_recipe_editor()
	await get_tree().process_frame
	if is_instance_valid(_recipe_canvas):
		await _add_dish_photo(_recipe_canvas)

func _load_letters() -> void:
	_letters.clear()
	if not FileAccess.file_exists(LETTER_PATH): return
	var value = JSON.parse_string(FileAccess.get_file_as_string(LETTER_PATH))
	if value is Array:
		for entry in value.slice(-40):
			if entry is Dictionary: _letters.append(entry.duplicate(true))

func _persist_letters() -> void:
	var file := FileAccess.open(LETTER_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_letters, "  "))

func _record_feedback(result: Dictionary) -> int:
	_letters.append({"customer": str(result.get("customer", "客人")), "customer_id": str(result.get("customer_id", "guest")), "score": int(result.get("score", 0)), "feedback": str(result.get("feedback", "")), "detail": str(result.get("detail", "")), "reply": "", "time": Time.get_datetime_string_from_system()})
	if _letters.size() > 40: _letters.pop_front()
	_persist_letters()
	return _letters.size() - 1

func _save_reply(index: int, words: String) -> void:
	if index < 0 or index >= _letters.size(): return
	_letters[index]["reply"] = words.strip_edges().left(600)
	_persist_letters()
	_notify("回复已经收进工作台。")

func _show_letters() -> void:
	_open_modal("letters", "顾客反馈与回信工作台", 980)
	_text("客人的反馈纸会留在这里。写下回复并保存，下次仍能继续查看。", 17, MUTED)
	if _letters.is_empty():
		_text("目前还没有反馈。完成一份料理并交给顾客后，这里会收到第一张纸。", 20)
		return
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(920, 600)
	modal_body.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 890
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	for index in range(_letters.size() - 1, -1, -1):
		var entry: Dictionary = _letters[index]
		var paper := PanelContainer.new()
		paper.add_theme_stylebox_override("panel", _style(Color("fff8df"), 0, Color("e3bd58")))
		list.add_child(paper)
		var body := VBoxContainer.new()
		paper.add_child(body)
		_label(body, "%s  ·  %d 分  ·  %s" % [entry.customer, entry.score, entry.get("time", "")], Vector2.ZERO, 20, ACCENT)
		_label(body, "“%s”\n%s" % [entry.feedback, entry.detail], Vector2.ZERO, 17, CREAM).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var edit := TextEdit.new()
		edit.text = str(entry.get("reply", ""))
		edit.placeholder_text = "写回复……"
		edit.custom_minimum_size = Vector2(820, 55)
		body.add_child(edit)
		_button(body, "保存这封回复", func(): _save_reply(index, edit.text), 180)

func _photograph_plating() -> void :
	if not is_instance_valid(_plating_canvas): return
	_plating_canvas.stop_gesture()
	if DisplayServer.get_name() == "headless": return
	var viewport: = SubViewport.new()
	viewport.size = Vector2i(860, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var photo = preload("res://modules/restaurant/ui/plating_canvas.gd").new()
	photo.game = self
	photo.render_only = true
	photo.size = Vector2(860, 480)
	viewport.add_child(photo)
	add_child(viewport)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture: = viewport.get_texture().get_image()
	picture.resize(640, 357, Image.INTERPOLATE_LANCZOS)
	_photo = Marshalls.raw_to_base64(picture.save_png_to_buffer())
	_photo_is_plating = true
	_plating_photo_revision = _plating_revision
	viewport.queue_free()
	world.audio.play_effect("tap")

func _hotspot(node_name: String, rect: Rect2, tip: String, callback: Callable) -> void :
	var button: = Button.new()
	button.name = node_name
	button.position = rect.position
	button.size = rect.size
	button.tooltip_text = tip
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(callback)
	hud.add_child(button)

func _dock_button(parent: Node, text: String, callback: Callable, width: float) -> Button:
	var button: = _button(parent, text, callback, width)
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed"]:
		var box: = StyleBoxFlat.new()
		box.bg_color = Color("393029e6") if state == "normal" else Color("6a5440")
		box.border_color = Color("806b52")
		box.set_border_width_all(1)
		box.set_content_margin_all(6)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Color("ecd6b6"))
	button.add_theme_color_override("font_hover_color", Color("fff0ce"))
	button.add_theme_color_override("font_pressed_color", Color("fff0ce"))
	return button
