extends Node
## Shared visual grammar for controls created by every scene and extension.
const BLUE := Color("405653")
const WHITE := Color("faf7ee")
const YELLOW := Color("eed577")
const MUTED := Color("526b77")
var handwriting := SystemFont.new()
var body_font := SystemFont.new()
const Production = preload("res://scripts/ui/production_assets.gd")
const Motion = preload("res://scripts/ui/solmere_motion.gd")

func _ready() -> void:
	handwriting.font_names=PackedStringArray(["KaiTi","Microsoft YaHei","Noto Sans CJK SC"])
	body_font.font_names=PackedStringArray(["PingFang SC","Heiti SC","Microsoft YaHei","Noto Sans CJK SC","Arial"])
	Production.apply_theme(preload("res://art/ui/solmere_ui.tres"))
	get_tree().node_added.connect(_added)

func _added(node: Node) -> void:
	# The physical kitchen owns its paper controls, input and recorded audio.
	if _context(node,["restaurant_host.gd"]): return
	if node is BaseButton: Motion.attach_id.call_deferred(node.get_instance_id())
	if node is Control: preload("res://scripts/ui/ui_sound_bindings.gd").attach_id.call_deferred(node.get_instance_id())
	if node is Control and not _context(node,["workshop.gd"]):
		_style_id.call_deferred(node.get_instance_id())

func _style_id(instance_id: int) -> void:
	var node=instance_from_id(instance_id)
	if node is Control:
		_style(node)
		if not is_instance_valid(node) or node.is_queued_for_deletion(): return
		if node.get_script()!=null and node.get_script().resource_path.get_file() in ["shop_panel.gd","recipe_book_panel.gd","film_paper.gd","map_paper.gd","fish_journal.gd","transport_panel.gd"]:
			Motion.paper_open(node,SettingsSystem.reduced_motion())
			WorldSound.play_ui("open")

func _context(node: Node, names: Array) -> bool:
	var at := node
	while is_instance_valid(at):
		if at.get_script()!=null:
			var path: String = at.get_script().resource_path
			for name in names:
				if path.ends_with(str(name)): return true
		at=at.get_parent()
	return false

func speech(node: Node) -> bool:
	var at := node
	while is_instance_valid(at):
		if at.is_in_group("scene_speech"): return true
		at=at.get_parent()
	return _context(node,["conversation_panel.gd","ask_panel.gd","memory_view.gd"])

func button_style(button: Button, in_scene := false) -> void:
	for state in ["normal","hover","pressed","focus","disabled"]:
		button.add_theme_stylebox_override(state,Production.button_face("choice" if in_scene else "paper",state))
	for state in ["font_color","font_focus_color"]:
		button.add_theme_color_override(state,WHITE if in_scene else Production.INK)
	for state in ["font_hover_color","font_pressed_color","font_hover_pressed_color"]: button.add_theme_color_override(state,Production.INK)
	button.add_theme_color_override("font_disabled_color",Production.MUTED_INK)
	if DisplayServer.get_name()!="headless": button.add_theme_font_override("font",body_font)
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND


func _style(node: Control) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion(): return
	if _context(node,["restaurant_host.gd"]): return
	# These components provide opaque, readable surfaces and their own states.
	if _context(node,["elder_board/scripts/main.gd","elder_board/scripts/match.gd","elder_board/scripts/rules_panel.gd","elder_board/scripts/teaching_room.gd","elder_board/scripts/learned_match.gd","elder_board/scripts/elder_story.gd"]): return
	if _context(node,["map_paper.gd","fish_journal.gd","transport_panel.gd"]): return
	if _context(node,["direction_card.gd","goods_card.gd","gameplay_shell.gd"]): return
	if _context(node,["photo_print.gd","photo_inscription.gd","PhotoAlbum.gd"]): return
	if node.is_in_group("solid_hud"): return
	if _context(node,["star_gazing_controller.gd","constellation_controller.gd","economy_paper.gd","StudioScreen.gd","myriorama_tarot/scripts/table.gd","native_module_game.gd","save_slots.gd","shop_panel.gd","film_paper.gd","confirm_sheet.gd","travel_card.gd","main_menu.gd","PocketCamera.gd","recorder_lite.gd","shutter_button.gd","living_objects.gd","media_browser.gd","guidance_toasts.gd","runtime_menu.gd","solmere_button.gd","household_panel.gd","RecorderScreen.gd","paper_page.gd","portfolio_item.gd","runtime_debug.gd","flowing_thought.gd","workshop.gd"]): return
	if speech(node): return
	if node is Button:
		if node.has_theme_stylebox_override("normal"): return
		button_style(node,speech(node))
		if node.has_meta("paper_selected") and bool(node.get_meta("paper_selected")): selected_button(node,true)
	elif node is Panel or node is PanelContainer:
		if node.has_theme_stylebox_override("panel"): return
		var current := node.get_theme_stylebox("panel")
		var paper := StyleBoxFlat.new()
		if current is StyleBoxFlat:
			paper=current.duplicate()
		paper.shadow_size=0; paper.shadow_offset=Vector2.ZERO
		paper.set_corner_radius_all(10); paper.set_border_width_all(0)
		paper.border_color=Color(BLUE,.32)
		paper.bg_color=WHITE if _context(node,["journal.gd","economy_paper.gd"]) else Color("edf3f4")
		node.add_theme_stylebox_override("panel",Production.surface(WHITE,14))

	elif node is LineEdit or node is TextEdit:
		for state in ["normal","focus","read_only"]:
			var sheet := StyleBoxFlat.new()
			sheet.bg_color=WHITE; sheet.border_width_bottom=1; sheet.border_color=Color(BLUE,.35)
			node.add_theme_stylebox_override(state,sheet)
		node.add_theme_color_override("font_color",BLUE)
		node.add_theme_color_override("font_placeholder_color",MUTED)
		node.add_theme_color_override("caret_color",BLUE)
		node.add_theme_color_override("selection_color",Color(YELLOW,.65))
	elif node is Label:
		if node.has_theme_color_override("font_color"): return
		if DisplayServer.get_name()!="headless":
			node.add_theme_font_override("font",body_font)
		var color := node.get_theme_color("font_color")
		if color.a==0: return
		if speech(node):
			node.add_theme_color_override("font_color",WHITE)
			node.add_theme_color_override("font_outline_color",Color("173c5d",.9)); node.add_theme_constant_override("outline_size",3)
		elif _has_paper_parent(node) or color.r<.75 or color.g<.75 or color.b<.75:
			node.add_theme_color_override("font_color",Color(BLUE,color.a))
	elif node is ColorRect and node.color.a<.8 and node.size.x>800 and node.size.y>400:
		node.color=Color("234d68",minf(node.color.a,.24))

func _has_paper_parent(node: Node) -> bool:
	var at := node.get_parent()
	while is_instance_valid(at):
		if at is Panel or at is PanelContainer: return true
		at=at.get_parent()
	return false

func near_actor(stage: Node, extent: Vector2, world_x: float = -1.0) -> Vector2:
	if not is_instance_valid(stage): return Vector2((1600-extent.x)*.5,420-extent.y*.5)
	if world_x<0: world_x=float(stage.get("player_x"))
	var x := world_x-float(stage.get("camera_x"))
	var head := float(stage.call("_actor_ground_at",world_x))-float(stage.call("_actor_height"))
	return Vector2(clampf(x-extent.x*.5,24,1576-extent.x),clampf(head-extent.y-26,40,872-extent.y))

func selected_button(button: Button, selected: bool) -> void:
	button.set_meta("paper_selected",selected)
	button_style(button,speech(button))
	if selected:
		var face := StyleBoxFlat.new()
		face.bg_color=Color(YELLOW,.48); face.border_width_bottom=2; face.border_color=BLUE
		face.content_margin_left=10; face.content_margin_top=5; face.content_margin_bottom=5
		button.add_theme_stylebox_override("normal",face)
