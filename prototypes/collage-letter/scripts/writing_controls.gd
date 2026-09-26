extends Control
var g
var counter: Label
var next: Button
var previous: Button
var options: Control
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	previous=g.desk.button("‹",Rect2(789,817,32,32),func():g.letter_text_node.turn_page(-1),false,self)
	counter=g.desk.label("",Rect2(824,822,53,25),13,self);counter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	next=g.desk.button("›",Rect2(879,817,32,32),func():g.letter_text_node.turn_page(1),false,self)
	refresh();g.letter_text_node.pages_changed.connect(refresh)
	if g.letter_mode in ["reply","example"]:build_original()
func refresh() -> void:
	var r=g.letter_text_node;var count:int=maxi(r.page_count,r.waiting_page+1)
	previous.visible=count>1;counter.visible=count>1;next.visible=count>1
	previous.disabled=r.page<=0;next.disabled=r.page>=count-1
	counter.text="%d / %d"%[r.page+1,count];next.tooltip_text="翻到下一张纸，继续书写" if g.L.language=="zh" else "Turn the page to continue"
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or g.dock_open or g.conversation_open:return
	if event.keycode==KEY_F1:toggle_options()
	elif event.keycode==KEY_F2:g.switch_language()
	elif event.keycode==KEY_F3:g.audio.toggle()
	else:return
	get_viewport().set_input_as_handled()
func toggle_options() -> void:
	if is_instance_valid(options):options.queue_free();options=null;return
	options=PanelContainer.new();options.z_index=200;options.position=Vector2(990,119);options.size=Vector2(385,276);add_child(options)
	var skin:=StyleBoxFlat.new();skin.bg_color=Color("efe3cd");skin.set_corner_radius_all(8);skin.set_content_margin_all(15);options.add_theme_stylebox_override("panel",skin)
	var rows:=VBoxContainer.new();options.add_child(rows)
	var title:=Label.new();title.text="书写反馈" if g.L.language=="zh" else "Writing feedback";rows.add_child(title)
	var speed:=OptionButton.new();rows.add_child(speed)
	var modes:=["Normal","Fast","Instant"]
	for mode in (["自然","快速","即时"] if g.L.language=="zh" else modes):speed.add_item(mode)
	speed.select(modes.find(g.writing_preferences.speed));speed.item_selected.connect(func(index):g.writing_preferences.speed=modes[index];g.apply_writing_preferences();g.save_game())
	var sound:=Label.new();sound.text="笔尖音量" if g.L.language=="zh" else "Pen sound volume";rows.add_child(sound)
	var volume:=HSlider.new();volume.min_value=0;volume.max_value=1;volume.step=0.05;volume.value=g.writing_preferences.volume;rows.add_child(volume);volume.value_changed.connect(func(value):g.writing_preferences.volume=value;g.apply_writing_preferences();g.save_game())
	var motion:=CheckButton.new();motion.text="减少书写运动" if g.L.language=="zh" else "Reduce writing motion";motion.button_pressed=g.writing_preferences.reduce_motion;rows.add_child(motion);motion.toggled.connect(func(value):g.writing_preferences.reduce_motion=value;g.apply_writing_preferences();g.save_game())
	var replay:=Button.new();replay.text="重看书写 · 点击信纸可跳过" if g.L.language=="zh" else "Replay · click page to skip";rows.add_child(replay)
	replay.pressed.connect(func():g.set_tool("write");g.letter_text_node.play_letter_animation(g.letter_text))
	var close:=Button.new();close.text="收起" if g.L.language=="zh" else "Close";rows.add_child(close);close.pressed.connect(toggle_options)
func build_original() -> void:
	var note:=PanelContainer.new();note.position=Vector2(53,624);note.size=Vector2(340,169);add_child(note)
	var skin:=StyleBoxFlat.new();skin.bg_color=Color("eee2c6");skin.set_content_margin_all(13);note.add_theme_stylebox_override("panel",skin)
	note.add_theme_color_override("font_color",Color("465346"))
	var column:=VBoxContainer.new();note.add_child(column)
	var title:=Label.new();title.text="放在手边的原信" if g.L.language=="zh" else "Their letter, beside yours";column.add_child(title)
	title.add_theme_font_override("font",g.font);title.add_theme_color_override("font_color",Color("465346"))
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(306,110);column.add_child(scroll)
	var words:=Label.new();words.text=g.reply_parent.get("caption","")
	if g.letter_mode=="example":words.text=g.SeaExample.data(g.sample_cycle)["incoming_"+g.L.language]
	words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;words.custom_minimum_size.x=290;words.add_theme_font_override("font",g.letter_text_node.HAND);words.add_theme_font_size_override("font_size",14);scroll.add_child(words)
	words.add_theme_color_override("font_color",Color("465346"))
