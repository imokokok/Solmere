extends CanvasLayer
const L=preload("res://scripts/localization.gd")
const ReadingArt=preload("res://scripts/bottle_reading_art.gd")

signal example_requested
var g
var example_revision:=0
var pending_previews:=0
signal compose_requested(parent: Dictionary)
signal closed
var client: Node
var font: Font
var root: Control
var message: Label
var letters_box: VBoxContainer
var detail_box: VBoxContainer
var reading_side: VBoxContainer
var detail_scroll: ScrollContainer
var side_scroll: ScrollContainer
var connection: PanelContainer
var address: LineEdit
var nickname: LineEdit
var debt_label: Label
var write_button: Button
var previous_button: Button
var next_button: Button
var view_picker: OptionButton
var network_buttons: Array[Button] = []
var row_buttons: Dictionary = {}
var reading_letter: Dictionary = {}
var show_plain_text:=false
var view := "ocean"
var before = null
var cursors: Array = []
var next_before = null
var active := false
var in_flight := false
var covered_controls: Array[Node] = []

func open() -> void:
	active=true;layer=20
	# Reading takes focus; desk labels and tool handles must not show through the overlay.
	for sibling in get_parent().get_children():
		if sibling!=self and (sibling is CanvasItem or sibling is CanvasLayer) and sibling.visible:covered_controls.append(sibling);sibling.hide()
	root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(root)
	var background:=ReadingArt.new();background.size=Vector2(1440,900);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(background)
	var title:=placed_label("漂流瓶邮局 / 海上的回声",Rect2(64,31,900,45),29);title.add_theme_color_override("font_color",Color("fff1d7"))
	var subtitle:=placed_label("在海里捡一封旧信，也留一封属于自己的。发出新信后，先回一封，再继续发信。",Rect2(65,88,1303,55),17);subtitle.add_theme_color_override("font_color",Color("f3e5ce"))
	placed_button("回到桌边",Rect2(1230,33,151,43),close,false)
	placed_button("邮局设置",Rect2(1051,33,163,43),toggle_connection,false)
	view_picker=OptionButton.new();view_picker.position=Vector2(77,174);view_picker.size=Vector2(279,37);view_picker.add_theme_font_size_override("font_size",16);root.add_child(view_picker)
	for item in ["海上来信","我的漂流瓶","收到的回复"]:view_picker.add_item(L.t(item))
	view_picker.item_selected.connect(func(index):view=["ocean","mine","inbox"][index];before=null;cursors.clear();reset_reading();refresh())
	var list_scroll:=ScrollContainer.new();list_scroll.position=Vector2(79,234);list_scroll.size=Vector2(279,528);list_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;root.add_child(list_scroll)
	letters_box=VBoxContainer.new();letters_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;letters_box.add_theme_constant_override("separation",8);list_scroll.add_child(letters_box)
	detail_scroll=ScrollContainer.new();detail_scroll.position=Vector2(466,193);detail_scroll.size=Vector2(420,607);detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;root.add_child(detail_scroll)
	detail_box=VBoxContainer.new();detail_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_box.add_theme_constant_override("separation",16);detail_scroll.add_child(detail_box)
	side_scroll=ScrollContainer.new();side_scroll.position=Vector2(975,190);side_scroll.size=Vector2(381,462);side_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;root.add_child(side_scroll)
	reading_side=VBoxContainer.new();reading_side.size_flags_horizontal=Control.SIZE_EXPAND_FILL;reading_side.add_theme_constant_override("separation",16);side_scroll.add_child(reading_side)
	previous_button=placed_button("‹",Rect2(80,776,58,35),func():
		if not cursors.is_empty():before=cursors.pop_back();refresh())
	previous_button.tooltip_text=L.t("上一页")
	next_button=placed_button("›",Rect2(295,776,58,35),func():
		if next_before!=null:cursors.append(before);before=next_before;refresh())
	next_button.tooltip_text=L.t("下一页")
	debt_label=placed_label("尚未连接。使用同一个邮局地址的玩家可以互相收信。",Rect2(976,676,377,68),16)
	write_button=placed_button("写一封自己的信",Rect2(974,760,382,44),compose_new)
	message=placed_label("作品只会在你点击最终「寄出」时上传到所连接的邮局。",Rect2(66,845,1313,42),15);message.add_theme_color_override("font_color",Color("f5e8d0"))
	build_connection();reset_reading();apply_theme(root);lock(false)
	var popup:=view_picker.get_popup();popup.add_theme_font_override("font",font);popup.add_theme_font_size_override("font_size",18);popup.add_theme_color_override("font_color",Color("415d51"));popup.add_theme_color_override("font_hover_color",Color("31493f"))
	var menu_skin:=StyleBoxFlat.new();menu_skin.bg_color=Color("ede0c4");menu_skin.set_corner_radius_all(6);menu_skin.set_content_margin_all(8);popup.add_theme_stylebox_override("panel",menu_skin)
	var menu_hover:=StyleBoxFlat.new();menu_hover.bg_color=Color("c2c4a8");menu_hover.set_corner_radius_all(4);popup.add_theme_stylebox_override("hover",menu_hover)
	connection.visible=false;side_scroll.visible=true
	add_example_row()
	show_example(false)
	if not client.token.is_empty():connect_now()

func build_connection() -> void:
	connection=PanelContainer.new();connection.position=Vector2(968,185);connection.size=Vector2(397,438);root.add_child(connection)
	var skin:=StyleBoxFlat.new();skin.bg_color=Color("eadbc0");skin.set_content_margin_all(12);connection.add_theme_stylebox_override("panel",skin)
	var fields:=VBoxContainer.new();fields.add_theme_constant_override("separation",15);connection.add_child(fields)
	add_label(fields,"邮局设置",23)
	add_label(fields,"尚未连接。使用同一个邮局地址的玩家可以互相收信。",17)
	address=LineEdit.new();address.text=client.base_url;address.custom_minimum_size=Vector2(0,42);address.size_flags_horizontal=Control.SIZE_EXPAND_FILL;address.placeholder_text="https://…";fields.add_child(address)
	nickname=LineEdit.new();nickname.text=client.display_name;nickname.placeholder_text=L.t("你的署名");nickname.max_length=24;nickname.custom_minimum_size=Vector2(0,42);fields.add_child(nickname)
	add_button(fields,"连接邮局",connect_now)

func toggle_connection() -> void:
	connection.visible=not connection.visible;side_scroll.visible=not connection.visible

func placed_label(text: String, rect: Rect2, font_size: int) -> Label:
	var label:=add_label(root,text,font_size);label.position=rect.position;label.size=rect.size;label.clip_text=true;return label

func placed_button(text: String, rect: Rect2, action: Callable, network: bool=true) -> Button:
	var button:=add_button(root,text,action,network);button.custom_minimum_size=Vector2.ZERO;button.position=rect.position;button.size=rect.size;return button

func add_label(parent: Node, text: String, font_size: int=20, authored: bool=true) -> Label:
	var label:=Label.new();label.text=L.t(text) if authored else text
	label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",Color("485950"));label.add_theme_constant_override("line_spacing",5)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(label);return label

func add_button(parent: Node, text: String, action: Callable, network: bool=true, authored: bool=true) -> Button:
	var button:=Button.new();button.text=L.t(text) if authored else text;button.custom_minimum_size=Vector2(0,42);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(action);parent.add_child(button);apply_theme(button)
	if network:network_buttons.append(button);button.disabled=in_flight
	return button

func apply_theme(node: Node) -> void:
	if node is Control:
		node.add_theme_font_override("font",font)
		if not node is Label:node.add_theme_font_size_override("font_size",17)
		if node is Button:
			for state in ["normal","hover","pressed","disabled","focus"]:
				var skin:=StyleBoxFlat.new();skin.bg_color=Color("ddd0b1") if state=="normal" else Color("c2c4a8");skin.set_corner_radius_all(7);skin.set_content_margin_all(8)
				if state=="disabled":skin.bg_color=Color("e2d7bf")
				if state=="focus":skin.bg_color=Color.TRANSPARENT;skin.border_color=Color("638474");skin.set_border_width_all(2)
				node.add_theme_stylebox_override(state,skin)
			node.add_theme_color_override("font_color",Color("415d51"));node.add_theme_color_override("font_hover_color",Color("31493f"));node.add_theme_color_override("font_pressed_color",Color("31493f"));node.add_theme_color_override("font_disabled_color",Color("8d8d79"))
		if node is LineEdit:
			var skin:=StyleBoxFlat.new();skin.bg_color=Color("f6ecd8");skin.set_corner_radius_all(5);skin.set_content_margin_all(9);skin.border_color=Color("b9aa8f");skin.set_border_width_all(1)
			for state in ["normal","focus"]:node.add_theme_stylebox_override(state,skin)
			node.add_theme_color_override("font_color",Color("40574c"));node.add_theme_color_override("caret_color",Color("40574c"))
	for child in node.get_children():apply_theme(child)

func lock(value: bool) -> void:
	in_flight=value
	network_buttons=network_buttons.filter(func(button):return is_instance_valid(button))
	for button in network_buttons:button.disabled=value
	if is_instance_valid(write_button):write_button.disabled=value or client.player.is_empty() or client.player.get("reply_required",false)
	if is_instance_valid(previous_button):previous_button.disabled=value or cursors.is_empty()
	if is_instance_valid(next_button):next_button.disabled=value or next_before==null
	if is_instance_valid(view_picker):view_picker.disabled=value
	if is_instance_valid(address):address.editable=not value;nickname.editable=not value

func connect_now() -> void:
	if in_flight:return
	lock(true);message.text=L.t("正在连接海岸邮局……")
	var result: Dictionary=await client.connect_service(address.text,nickname.text)
	if not active:return
	lock(false)
	if not result.ok:message.text=L.t(result.get("error","连接失败。"));return
	connection.hide();side_scroll.show();reset_reading();await refresh()

func refresh() -> void:
	if in_flight:return
	if client.token.is_empty():message.text=L.t("请先连接邮局。");return
	lock(true)
	var path: String="/v1/letters?view="+view
	if before!=null:path+="&before="+str(before)
	var result: Dictionary=await client.request(path)
	if not active:return
	lock(false)
	if not result.ok:message.text=L.t(result.get("error","暂时没有收到邮局的回应。"));return
	clear(letters_box);row_buttons.clear();add_example_row();next_before=result.get("next_before")
	debt_label.text=L.t("待完成：回复一封来信，才能再次自由发信。" if client.player.get("reply_required",false) else "可以自由发信，也可以继续回复海上的旧信。")
	for letter in result.get("letters",[]):
		var id: int=int(letter.id)
		var label: String=L.t("#%d  %s\n%s · %d 封回复")%[id,L.t(letter.title) if letter.is_seed else letter.title,L.t(letter.name) if letter.is_seed else letter.name,int(letter.reply_count)]
		var button:=add_button(letters_box,label,func():show_letter(id),true,false);button.custom_minimum_size=Vector2(0,78);button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.add_theme_font_size_override("font_size",16);button.tooltip_text=label;row_buttons[id]=button
		if reading_letter.get("id",-1)==id:highlight_row(id)
	if result.get("letters",[]).is_empty():add_label(letters_box,"暂时没有信件。",18)
	message.text=L.t("每封信会留在邮局。起航信是事务所准备的，不冒充玩家来信。");lock(false)

func reset_reading() -> void:
	reading_letter={};clear(detail_box);clear(reading_side)
	var spacer:=Control.new();spacer.custom_minimum_size=Vector2(0,167);detail_box.add_child(spacer)
	add_label(detail_box,"连接后，选择左边的一封信。\n原信与所有回复会保留，后来的人仍然可以读到。",23)
	add_label(reading_side,"海上来信",24)
	add_label(reading_side,"每封信会留在邮局。起航信是事务所准备的，不冒充玩家来信。",18)

func highlight_row(id: int) -> void:
	for key in row_buttons:
		var button: Button=row_buttons[key]
		var skin:=StyleBoxFlat.new();skin.bg_color=Color("c0c6a6") if key==id else Color("e6d7b9");skin.set_corner_radius_all(5);skin.set_content_margin_all(8);button.add_theme_stylebox_override("normal",skin)

func show_letter(id: int) -> void:
	if in_flight:return
	lock(true)
	var result: Dictionary=await client.request("/v1/letters/"+str(id))
	if not active:return
	lock(false)
	if not result.ok:message.text=L.t(result.get("error","打开失败。"));return
	reading_letter=result.letter;show_plain_text=false;render_letter();highlight_row(id);clear(reading_side)
	var letter:=reading_letter
	add_label(reading_side,L.t(letter.title) if letter.is_seed else letter.title,25,false)
	add_label(reading_side,(L.t(letter.name) if letter.is_seed else letter.name)+L.t(" · 事务所起航信" if letter.is_seed else " · 玩家来信"),16,false)
	if not letter.is_own and not letter.get("already_replied",false):add_button(reading_side,"回到桌边，回复这封信",func():close();compose_requested.emit(letter))
	if not str(letter.get("art_png","")).is_empty() and not str(letter.get("caption","")).is_empty():
		var toggle:=add_button(reading_side,"阅读文字" if L.language=="zh" else "Read the words",func():
			show_plain_text=not show_plain_text;render_letter(),false,false)
		toggle.pressed.connect(func():toggle.text=("查看信纸" if L.language=="zh" else "View the letter") if show_plain_text else ("阅读文字" if L.language=="zh" else "Read the words"))
	if letter.get("already_replied",false):add_label(reading_side,"你已回复过这封信，可以阅读后续回信。",17)
	if letter.parent!=null:
		var parent_id:=int(letter.parent);add_button(reading_side,"读原信 #"+str(parent_id),func():show_letter(parent_id))
	add_label(reading_side,"回声 / 最新回复",19)
	for reply in result.get("replies",[]):
		var reply_id:=int(reply.id);var reply_button:=add_button(reading_side,"#%d  %s / %s"%[reply_id,reply.title,reply.name],func():show_letter(reply_id),true,false);reply_button.tooltip_text=reply_button.text
	if result.get("replies",[]).is_empty():add_label(reading_side,"还没有回信。",17)
	side_scroll.scroll_vertical=0;lock(false)

func render_letter() -> void:
	clear(detail_box);detail_scroll.scroll_vertical=0
	if not show_plain_text and not str(reading_letter.get("art_png","")).is_empty():
		var image:=Image.new()
		if image.load_png_from_buffer(Marshalls.base64_to_raw(reading_letter.art_png))==OK:
			var art:=TextureRect.new();art.name="ReceivedLetterArtwork";art.texture=ImageTexture.create_from_image(image);art.custom_minimum_size=Vector2(0,minf(594,408.0*image.get_height()/maxi(1,image.get_width())));art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;detail_box.add_child(art);return
	show_readable_words(str(reading_letter.get("caption","")))

func compose_new() -> void:
	if client.player.is_empty() or client.player.get("reply_required",false):message.text=L.t("请先回复一封来信。");return
	close();compose_requested.emit({})

func clear(node: Node) -> void:
	for child in node.get_children():node.remove_child(child);child.queue_free()

func close() -> void:
	active=false;closed.emit()
	for control in covered_controls:
		if is_instance_valid(control) and not control.is_queued_for_deletion():control.show()
	covered_controls.clear()
	if is_instance_valid(root):root.queue_free()
	# Let any awaited HTTP response finish before this controller is freed.
	if in_flight:get_tree().create_timer(13).timeout.connect(queue_free)
	elif pending_previews==0:queue_free()

func add_example_row() -> void:
	if not is_instance_valid(g):return
	for index in 3:
		var cycle:int=index
		var example:=add_button(letters_box,str(g.SeaExample.data(cycle)["name_"+L.language])+"\n"+str(g.SeaExample.data(cycle)["title_"+L.language]),func():g.sample_cycle=cycle;g.audio.play("PAPER_MOVE",.45);show_example(false),false,false)
		example.name="LocalExampleLetter" if index==0 else "LocalExampleLetter"+str(index)
		example.custom_minimum_size.y=84;example.add_theme_font_size_override("font_size",14)
func show_example(reply:bool) -> void:
	if not is_instance_valid(g):return
	example_revision+=1;var revision:=example_revision
	clear(detail_box);clear(reading_side);connection.hide();side_scroll.show()
	add_label(reading_side,("预设回信" if L.language=="zh" else "Prepared reply") if reply else g.SeaExample.data(g.sample_cycle)["name_"+L.language],24,false)
	add_label(reading_side,"事务所写作示例 · 虚构来信\n本地体验，不会发给真实玩家。" if L.language=="zh" else "An original fictional exchange.\nThis local example is not sent to real players.",15,false)
	add_button(reading_side,("读原信" if reply else "查看预设回信") if L.language=="zh" else ("Read original" if reply else "View prepared reply"),func():show_example(not reply),false,false)
	add_button(reading_side,"打开回信，卷起寄出" if L.language=="zh" else "Open reply and bottle it",func():close();example_requested.emit(),false,false).name="PrepareExampleReply"
	var content:Dictionary=g.SeaExample.data(g.sample_cycle)
	add_button(reading_side,"阅读文字" if L.language=="zh" else "Read the words",func():clear(detail_box);show_readable_words(content[("reply_" if reply else "incoming_")+L.language]),false,false)
	message.text="先读一封信，再认真回一封；空瓶可以写自己的新信。" if L.language=="zh" else "Read a letter and leave a thoughtful reply. Use the empty bottle for a new letter."
	pending_previews+=1
	var encoded:String=await g.SeaExample.artwork(g,reply)
	pending_previews-=1
	if not active:
		if pending_previews==0 and not in_flight:queue_free()
		return
	if revision!=example_revision:return
	reading_letter={"art_png":encoded,"caption":content[("reply_" if reply else "incoming_")+L.language],"is_seed":true};render_letter()

func show_readable_words(value:String) -> void:
	var words=preload("res://scripts/letter_renderer.gd").new();words.name="ReceivedLetterText";words.custom_minimum_size=Vector2(360,480);words.size=Vector2(360,480);detail_box.add_child(words);words.load_text(value)
	var nav:=HBoxContainer.new();detail_box.add_child(nav)
	add_button(nav,"‹",func():words.turn_page(-1),false,false)
	add_button(nav,"›",func():words.turn_page(1),false,false)
	add_button(nav,"Replay Writing",func():words.play_letter_animation(value),false,false)
	add_button(nav,"Skip",words.skip,false,false)
	if is_instance_valid(g):words.audio=g.audio
