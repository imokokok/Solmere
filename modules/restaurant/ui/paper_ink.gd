extends RefCounted
const FONT = preload("res://modules/restaurant/assets/fonts/lxgw_wenkai_lite.ttf")
const FALLBACK = preload("res://modules/restaurant/assets/fonts/noto_sans_sc.ttf")
static var _font: FontVariation

static func font() -> Font:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = FONT
		_font.fallbacks = [FALLBACK]
	return _font

static func style(edit: Control, size_px := 24, ink := Color("514737")) -> void:
	edit.add_theme_font_override("font",font())
	edit.add_theme_font_size_override("font_size",size_px)
	for state in ["normal","focus","read_only"]:
		var skin := StyleBoxEmpty.new()
		skin.set_content_margin_all(4)
		edit.add_theme_stylebox_override(state,skin)
	for name in ["font_color","font_readonly_color","caret_color"]: edit.add_theme_color_override(name,ink)
	edit.add_theme_color_override("font_placeholder_color",Color("92866f",0.65))
	edit.add_theme_color_override("selection_color",Color("cfac70",0.3))
	edit.add_theme_color_override("font_selected_color",ink)
	edit.add_theme_constant_override("outline_size",0)
	if edit is TextEdit:
		edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		edit.add_theme_constant_override("line_spacing",3)
		edit.draw_tabs = false
		edit.draw_spaces = false
		edit.caret_blink = true
		edit.caret_blink_interval = 0.65
		edit.scroll_fit_content_height = true
		for bar in [edit.get_v_scroll_bar(),edit.get_h_scroll_bar()]:
			for state in ["scroll","scroll_focus","grabber","grabber_highlight","grabber_pressed"]: bar.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		edit.context_menu_enabled = false
	elif edit is LineEdit:
		edit.caret_blink = true
		edit.context_menu_enabled = false
