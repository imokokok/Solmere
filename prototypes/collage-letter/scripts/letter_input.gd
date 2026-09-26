extends TextEdit
## Native editing owns IME, selection, undo and the authoritative String.
## Glyphs/caret/scrollbars never paint the final page; LetterRenderer does.
var game
var renderer
var syncing:=false
func _ready() -> void:
	wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	add_theme_font_override("font",renderer.HAND);add_theme_font_size_override("font_size",renderer.font_size)
	add_theme_constant_override("line_spacing",5)
	for key in ["font_color","font_readonly_color","caret_color","selection_color","font_selected_color"]:add_theme_color_override(key,Color.TRANSPARENT)
	for skin in ["normal","focus","read_only"]:add_theme_stylebox_override(skin,StyleBoxEmpty.new())
	caret_blink=false;scroll_fit_content_height=false
	get_v_scroll_bar().modulate.a=0;get_h_scroll_bar().modulate.a=0
	get_v_scroll_bar().mouse_filter=Control.MOUSE_FILTER_IGNORE;get_h_scroll_bar().mouse_filter=Control.MOUSE_FILTER_IGNORE
	text=game.letter_text;text_changed.connect(committed);caret_changed.connect(caret_moved)
	focus_exited.connect(func():renderer.composition="";game.save_game())
	grab_focus()

func committed() -> void:
	if syncing:return
	game.letter_text=text;renderer.submit(text);game.queue_redraw()

func offset_for(line: int, column: int) -> int:
	var offset:=column
	for i in line:offset+=get_line(i).length()+1
	return offset

func caret_moved() -> void:
	if syncing:return
	renderer.follow_caret(offset_for(get_caret_line(),get_caret_column()))
	if has_selection():
		renderer.selection_from=offset_for(get_selection_from_line(),get_selection_from_column());renderer.selection_to=offset_for(get_selection_to_line(),get_selection_to_column())
	else:renderer.selection_from=-1;renderer.selection_to=-1

func position_caret(offset: int) -> void:
	var preceding:=text.substr(0,offset).split("\n")
	set_caret_line(preceding.size()-1);set_caret_column(preceding[-1].length());caret_moved()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		if renderer.replaying:renderer.skip()
		else:grab_focus();deselect();position_caret(renderer.hit_offset(event.position))
		accept_event()
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_ESCAPE and renderer.replaying:renderer.skip();accept_event()
		elif event.keycode==KEY_BACKSPACE and not has_selection() and not event.ctrl_pressed and not event.alt_pressed:
			# Explicit grapheme-safe deletion, including ZWJ emoji and combining marks.
			var at:=offset_for(get_caret_line(),get_caret_column());var parts:Array=renderer.graphemes(text.substr(0,at))
			if not parts.is_empty():
				var old_at:int=at-str(parts[-1]).length();position_caret(old_at)
				var from_line:=get_caret_line();var from_column:=get_caret_column();position_caret(at)
				select(from_line,from_column,get_caret_line(),get_caret_column());insert_text_at_caret("")
			accept_event()

func _process(_delta: float) -> void:
	editable=renderer.state<renderer.State.FINISHING
	if has_focus() and has_ime_text():
		renderer.composition=DisplayServer.ime_get_text()
		DisplayServer.window_set_ime_position(get_global_transform_with_canvas()*(renderer.pen_position+Vector2(0,5)))
	elif not renderer.composition.is_empty():renderer.composition=""
