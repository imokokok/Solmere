extends Control
## Real shared records; reading changes only discovery metadata, never ownership.
var detail: Label
var actions: GridContainer
var media: HBoxContainer
var audio: AudioStreamPlayer
func _ready() -> void:
	add_to_group("meta_modal")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme=preload("res://art/ui/solmere_ui.tres")
	var panel := PanelContainer.new(); panel.position=Vector2(360,155); panel.size=Vector2(880,590)
	var face := StyleBoxFlat.new(); face.bg_color=Color("faf7ee"); face.set_corner_radius_all(9); face.set_content_margin_all(28); panel.add_theme_stylebox_override("panel",face); add_child(panel)
	var rows := VBoxContainer.new(); rows.add_theme_constant_override("separation",16); panel.add_child(rows)
	var heading := Label.new(); heading.text=LocalizationSystem.text("起居角 · 唱片与纸张" if GameState.current_location in ["residence","dorm"] else "在小镇留下的记录"); heading.add_theme_font_size_override("font_size",28); rows.add_child(heading)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size.y=180; rows.add_child(scroll)
	actions=GridContainer.new(); actions.columns=3; actions.size_flags_horizontal=SIZE_EXPAND_FILL; actions.add_theme_constant_override("h_separation",10); actions.add_theme_constant_override("v_separation",10); scroll.add_child(actions)
	var traces := ChapterSystem.everyday_at(GameState.current_location)
	for trace in traces:
		var card := preload("res://scripts/ui/components/solmere_button.gd").new()
		card.name="Trace_"+str(trace.id); card.variant="goods"; card.tooltip_text=LocalizationSystem.text(str(trace.title)); card.custom_minimum_size=Vector2(250,171)
		var content := MarginContainer.new(); content.mouse_filter=MOUSE_FILTER_IGNORE; card.add_child(content); content.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		for edge in ["left","right","top","bottom"]: content.add_theme_constant_override("margin_"+edge,10)
		var stack := VBoxContainer.new(); stack.mouse_filter=MOUSE_FILTER_IGNORE; stack.add_theme_constant_override("separation",6); content.add_child(stack)
		var picture := TextureRect.new(); picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; picture.custom_minimum_size.y=104; picture.size_flags_vertical=SIZE_EXPAND_FILL; picture.mouse_filter=MOUSE_FILTER_IGNORE; picture.texture=preload("res://scripts/ui/components/everyday_shelf_display.gd").texture_for(trace); stack.add_child(picture)
		var caption := Label.new(); caption.text=LocalizationSystem.text(str(trace.title)); caption.custom_minimum_size.y=35; caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; caption.add_theme_font_size_override("font_size",18); caption.mouse_filter=MOUSE_FILTER_IGNORE; stack.add_child(caption)
		card.pressed.connect(_read.bind(str(trace.id))); actions.add_child(card)
	if traces.is_empty():
		var empty := Label.new(); empty.text=LocalizationSystem.text("桌面收拾得很干净。"); actions.add_child(empty)
	detail=Label.new(); detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; detail.custom_minimum_size=Vector2(800,95); rows.add_child(detail)
	media=HBoxContainer.new(); rows.add_child(media)
	audio=AudioStreamPlayer.new(); audio.bus="Music"; add_child(audio)
	var back := preload("res://scripts/ui/components/solmere_button.gd").new(); back.text=LocalizationSystem.text("放回柜里"); back.pressed.connect(queue_free); rows.add_child(back)
	back.grab_focus()
func _read(id: String) -> void:
	var snapshot := GameState.to_save_data()
	var trace := ChapterSystem.observe_everyday_object(id)
	if trace.is_empty(): return
	var payload: Dictionary=trace.payload
	audio.stop()
	for child in media.get_children(): media.remove_child(child); child.queue_free()
	var labels: Array=payload.get("interaction",{}).get("selected_labels",[])
	detail.text=LocalizationSystem.text_with_values("%s · 第 %d 天",[LocalizationSystem.text(str(trace.title)),int(trace.day)])
	var descriptions: Array[String]=[]
	if not str(payload.get("label","")).is_empty(): descriptions.append(LocalizationSystem.text(str(payload.label)))
	for label in labels:
		var translated:=LocalizationSystem.text(str(label))
		if not descriptions.has(translated): descriptions.append(translated)
	if not descriptions.is_empty(): detail.text+="\n"+" · ".join(descriptions)
	var service: Dictionary = payload.get("restaurant", {})
	if not service.is_empty():
		# The public record uses the meals actually served in the physical kitchen.
		var names: Dictionary = {}
		for ingredient in JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/data/ingredients.json")):
			names[str(ingredient.id)] = str(ingredient.name)
		for meal in service.get("meals", []).slice(0, 3):
			var foods: Array[String] = []
			for ingredient in meal.get("dish", {}).get("ingredients", []):
				var food := str(names.get(str(ingredient.get("id", "")), ""))
				if not food.is_empty() and not foods.has(food): foods.append(food)
			detail.text += "\n%s：%s" % [str(meal.get("customer", "客人")), "、".join(foods)]
			if not str(meal.get("feedback", "")).is_empty(): detail.text += " · " + str(meal.feedback)
	for card in actions.get_children():
		if card is Button: card.selected=card.name=="Trace_"+id
	for receipt in payload.get("receipts",[]):
		detail.text+="\n"+LocalizationSystem.text_with_values("%s · %s 元 · %s",[LocalizationSystem.text(str(receipt.get("shop_name","采购"))),str(receipt.get("total",receipt.get("amount",0))),LocalizationSystem.text(str(receipt.get("stamp","")))])
	if bool(ChapterSystem.story().get(GameState.current_role+"_noticing",false)) and str(trace.owner)!=GameState.current_role: detail.text+="\n"+LocalizationSystem.text("做法、日期和留下的纸张对得上，却不全是我的经历。")
	var record: Dictionary=payload.get("record",{})
	var path := str(record.get("final_audio_path",""))
	if FileAccess.file_exists(path):
		audio.stream=AudioStreamWAV.load_from_file(path)
		var play := preload("res://scripts/ui/components/solmere_button.gd").new(); play.text=LocalizationSystem.text("听听这张唱片"); media.add_child(play)
		play.pressed.connect(func():
			if audio.playing: audio.stop(); play.text=LocalizationSystem.text("听听这张唱片")
			else: audio.play(); play.text=LocalizationSystem.text("停止播放"))
		audio.finished.connect(func(): if is_instance_valid(play): play.text=LocalizationSystem.text("再听一次"),CONNECT_ONE_SHOT)
	var preview := str(payload.get("letter",{}).get("preview_path",record.get("cover_path","")))
	if FileAccess.file_exists(preview):
		var photo := TextureRect.new(); photo.texture=ImageTexture.create_from_image(Image.load_from_file(preview)); photo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; photo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; photo.custom_minimum_size=Vector2(180,125); media.add_child(photo)
	if not SaveManager.save_or_report("公共柜记录未能保存"):
		GameState.load_save_data(snapshot); detail.text=LocalizationSystem.text("暂时没能记下这次查看，可以再试一次。")
	GuidanceSystem.refresh()
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): queue_free(); get_viewport().set_input_as_handled()
