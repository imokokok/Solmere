extends Control
const Model = preload("res://scripts/town_sound/studio/Arrangement.gd")
const Timeline = preload("res://scripts/town_sound/studio/Timeline.gd")
const DragButton = preload("res://scripts/town_sound/studio/SoundCard.gd")
var model := Model.new()
var timeline: SoundTimeline
var player: AudioStreamPlayer
var status: Label
var inspector: VBoxContainer
var clock_label: Label
var selected := -1
var dirty := true
var mixdown: AudioStreamWAV
var paused_at := 0.0
var root_column: VBoxContainer
var region_start := -1.0
var region_end := -1.0
var region_track := 0
var mute_controls: Array[CheckButton] = []
var gain_controls: Array[HSlider] = []
var mixing := false
var tutorial: Label

var monitor_locked := false
var edit_history: Array=[]
var redo_history: Array=[]
var previous_edit: Dictionary={}
var restoring_history := false
var undo_button: Button
var redo_button: Button

var desk: Control
var mv: VisualCanvas
var mv_caption: Label
var play_control: Button
var make_control: Button
var cut_control: Button
var keep_control: Button
var has_listened := false
var revision := 0
var sample_row: HBoxContainer

func _ready() -> void:
	add_to_group("meta_modal")
	theme=preload("res://scripts/ui/components/interface_palette.gd").theme_for_tools()
	theme.set_constant("paragraph_spacing","Label",0)
	theme.set_constant("line_spacing","Label",2)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	if has_node("/root/GameState") and GameState.current_location != "record_store":
		set_process(false); queue_free(); return
	if has_node("/root/WorldSound"):
		WorldSound.lock_monitor(true); monitor_locked=true
	_configure_role_project()
	# Old hidden track controls must never leave an apparently silent workbench.
	# Bake old audible track gain into clips once, then expose only clip loudness.
	for clip in model.clips:
		clip.volume=clampf(float(clip.volume)*float(model.gains[int(clip.track)]),0,1.5)
	model.muted=[false,false,false,false]; model.gains=[1.0,1.0,1.0,1.0]
	previous_edit=_edit_snapshot()
	player=AudioStreamPlayer.new(); player.bus="Music"; add_child(player)
	player.finished.connect(func(): paused_at=0.0; play_control.text="▶ 听听看"; _guide())
	desk=Control.new(); desk.size=Vector2(1600,900); add_child(desk)
	var surface=preload("res://scripts/town_sound/studio/SoundDesk.gd").new()
	surface.size=Vector2(1600,900); desk.add_child(surface)
	resized.connect(_fit_desk); _fit_desk()
	_place(label("把今天，做成一张唱片",32),Vector2(56,30),Vector2(750,50))
	_place(label("声音手作桌  /  采集 → 剪贴 → 听一遍 → 制作",18),Vector2(58,87),Vector2(760,28))
	_place(button("收好，回店里",_leave_desk),Vector2(1342,35),Vector2(216,48))
	var guide_paper=preload("res://scripts/town_sound/PaperNote.gd").new()
	_place(guide_paper,Vector2(53,130),Vector2(808,77))
	tutorial=label("",21); tutorial.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_place(tutorial,Vector2(65,137),Vector2(777,72))
	_place(label("声音盒子 · 拿一卷，放到下面的纸带上",18),Vector2(65,211),Vector2(760,28))
	var sample_scroll:=ScrollContainer.new(); sample_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_place(sample_scroll,Vector2(64,246),Vector2(782,127))
	sample_row=HBoxContainer.new(); sample_row.name="SoundBox"; sample_row.add_theme_constant_override("separation",14); sample_scroll.add_child(sample_row)
	_refresh_sound_box()
	play_control=button("▶ 听听看",func():
		if player.playing: pause()
		else: play())
	_place(play_control,Vector2(65,377),Vector2(165,43))
	clock_label=label("",18); _place(clock_label,Vector2(250,383),Vector2(190,30))
	make_control=button("拿去做唱片 →",request_visual)
	_place(make_control,Vector2(598,377),Vector2(245,43))
	mv=VisualCanvas.new(); mv.name="AlwaysVisibleMV"; mv.mouse_filter=MOUSE_FILTER_IGNORE
	_place(mv,Vector2(922,126),Vector2(614,252))
	mv.profile=VisualCanvas.parse_prompt(model.prompt,model.seed_value); mv.model=model
	mv_caption=label("声音明信片 · 播放时，画面跟着声音走",17)
	_place(mv_caption,Vector2(929,390),Vector2(607,28))
	var shop_sources:=HBoxContainer.new(); shop_sources.name="ShopSoundSources"; shop_sources.add_theme_constant_override("separation",8)
	_place(shop_sources,Vector2(922,433),Vector2(614,45))
	for kind in ["wind","water","fire"]:
		var pick:=button("加入店内"+str({"wind":"风声","water":"水声","fire":"火声"}[kind]),_add_shop_sample.bind(kind))
		pick.name="ShopSource_"+kind; pick.tooltip_text="加入约 8 秒的店内声音，可以继续剪辑"; pick.size_flags_horizontal=SIZE_EXPAND_FILL; pick.add_theme_font_size_override("font_size",18); shop_sources.add_child(pick)
	var tools:=HBoxContainer.new(); tools.add_theme_constant_override("separation",12)
	_place(tools,Vector2(65,491),Vector2(970,48))
	var group:=ButtonGroup.new()
	var hand:=button("手 · 移动 / 修边",func(): timeline.selection_mode=false; _guide())
	hand.toggle_mode=true; hand.button_group=group; hand.button_pressed=true; tools.add_child(hand)
	var scissors:=button("剪刀 · 划出一段",func(): timeline.selection_mode=true; _guide())
	scissors.toggle_mode=true; scissors.button_group=group; tools.add_child(scissors)
	cut_control=button("剪掉",func(): edit_region(false)); tools.add_child(cut_control)
	keep_control=button("只留下这段",func(): edit_region(true)); tools.add_child(keep_control)
	undo_button=button("撤销",_undo_edit); redo_button=button("重做",_redo_edit)
	tools.add_child(undo_button); tools.add_child(redo_button)
	undo_button.disabled=true; redo_button.disabled=true
	timeline=Timeline.new(); timeline.arrangement=model
	timeline.view_seconds=clampf(ceilf(model.length()/4.0)*4.0+4.0,12,60)
	var scroll:=ScrollContainer.new(); scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_place(scroll,Vector2(68,545),Vector2(1190,293)); scroll.add_child(timeline)
	timeline.selected_changed.connect(func(index:int): selected=index; build_inspector(); _guide())
	timeline.edited.connect(changed)
	timeline.seek_requested.connect(func(seconds:float):
		paused_at=seconds
		if player.playing: player.seek(minf(seconds,model.length()))
		mv.time=seconds; mv.queue_redraw())
	timeline.region_selected.connect(func(begin:float,end:float,track:int):
		region_start=begin; region_end=end; region_track=track; _guide())
	inspector=VBoxContainer.new(); inspector.add_theme_constant_override("separation",12)
	_place(inspector,Vector2(1291,550),Vector2(236,271))
	status=label("改动会自动保存在本机。拖片段两端修剪；点击纸带上方刻度定位。",17)
	_place(status,Vector2(64,856),Vector2(1490,32))
	build_inspector(); _guide()

func _refresh_sound_box() -> void:
	for child in sample_row.get_children(): sample_row.remove_child(child); child.queue_free()
	for item in SampleStore.new().list_samples():
		var card:=DragButton.new(); card.sample=item; card.disabled=item.missing
		card.pressed.connect(func():
			selected=model.add_sample(item,0,minf(model.length(),59.8)); timeline.selected=selected; changed())
		sample_row.add_child(card)
	if sample_row.get_child_count()==0:
		sample_row.add_child(label("声音盒还是空的。\n先用右边的店内素材试一试，也可以带自己的录音来。",21))

func _add_shop_sample(kind: String) -> void:
	if mixing or GameState.current_location!="record_store" or kind not in ["wind","water","fire"]: return
	if model.length()>=59.9: status.text="纸带已经放满一分钟了，先剪短一段再添加。"; return
	var store:=SampleStore.new()
	var source_tag: String="shop_library_"+kind
	var existing:=store.list_samples().filter(func(item: Dictionary): return str(item.get("event_tag",""))==source_tag and not bool(item.get("missing",false)))
	var item: Dictionary={}
	if not existing.is_empty(): item=existing[0]
	else:
		var sound=preload("res://scripts/town_sound/data/SoundAtlas.gd").stream(kind)
		if not sound is AudioStreamWAV: status.text="这段店内素材暂时无法读取。"; return
		# Provide a short editable excerpt, leaving space for a second sound.
		# The approved source recording remains untouched on disk.
		var excerpt:=AudioStreamWAV.new()
		excerpt.format=sound.format; excerpt.mix_rate=sound.mix_rate; excerpt.stereo=sound.stereo
		excerpt.data=sound.data.slice(0,mini(sound.data.size(),sound.mix_rate*(4 if sound.stereo else 2)*8))
		var snapshot:=GameState.to_save_data().duplicate(true)
		item=store.save_sample(excerpt,"店内素材 · "+str({"wind":"风声","water":"水声","fire":"火声"}[kind]),{"source_mode":"shop_library","event_tag":source_tag,"sound_kind":kind,"location":"record_store","game_day":GameState.current_day,"game_minute":GameState.current_minute,"mv_seed":23817,"mv_version":3,"usage_scope":"shareable","consent_status":"provided_asset"})
		if item.is_empty(): status.text=store.last_error; return
		if not SaveManager.save_or_report("店内声音素材保存失败"):
			store.delete_sample(str(item.id)); GameState.load_save_data(snapshot)
			status.text="这段素材还没有存好，没有加入纸带。请再试一次。"; return
	selected=model.add_sample(item,0,model.length()); timeline.selected=selected
	_refresh_sound_box()
	if changed(): status.text="已加入"+str(item.name)+"。可以修短、换位置，再听一听。"

func _place(node:Control,at:Vector2,extent:Vector2) -> void:
	node.position=at; node.size=extent; desk.add_child(node)

func _fit_desk() -> void:
	if desk==null: return
	var factor:=minf(size.x/1600.0,size.y/900.0)
	desk.scale=Vector2.ONE*factor; desk.position=(size-Vector2(1600,900)*factor)*.5

func _leave_desk() -> void:
	if mixing: status.text="声音正在整理，稍等一下。"; return
	if not model.save_project(): status.text=model.error; return
	player.stop(); get_parent().show(); queue_free()

func _guide() -> void:
	if not is_instance_valid(tutorial) or timeline==null: return
	var empty:=model.clips.is_empty()
	play_control.disabled=empty or mixing; make_control.disabled=empty or mixing
	cut_control.disabled=region_start<0 or region_end-region_start<.01
	keep_control.disabled=cut_control.disabled
	if empty: tutorial.text="① 挑一段声音\n点选自己的小磁带，或从右边加入店内素材。"
	elif timeline.selection_mode and region_start>=0:
		tutorial.text="② 已圈出 %.1f—%.1f 秒\n选「剪掉」或「只留下这段」。剪错可以撤销。"%[region_start,region_end]
	elif timeline.selection_mode:
		tutorial.text="② 拿好了剪刀\n在下面的波形上按住并横向划出范围，再松手。"
	elif not has_listened:
		tutorial.text="② 摆好声音，听听看\n拖中间换位置，拖两端修短。点选纸条可调音量和速度。"
	else: tutorial.text="③ 喜欢这一段了吗？\n接着挑封面、压片，再亲手包装。"

func _configure_role_project() -> void:
	if has_node("/root/GameState"):
		model.hosted_role=GameState.current_role
		model.project_path="user://projects/"+str(GameState.shared_state.get("journey_id","journey"))+"_"+GameState.current_role+".json"
	model.load_project()

func label(text: String, font_size: int = 16) -> Label:
	var node := Label.new()
	node.text = LocalizationSystem.text(text)
	node.add_theme_font_size_override("font_size", maxi(18,font_size))
	node.add_theme_constant_override("paragraph_spacing",0)
	node.add_theme_constant_override("line_spacing",2)
	return node

func button(text: String, action: Callable) -> Button:
	var node := preload("res://scripts/ui/components/solmere_button.gd").new()
	node.variant="primary" if text in ["▶ 播放","制作唱片"] else "paper"; node.custom_minimum_size.y=43; node.add_theme_font_size_override("font_size",20)
	node.text = LocalizationSystem.text(text)
	node.pressed.connect(action)
	return node

func field(row: HBoxContainer, title: String, key: String, low: float, high: float, step: float) -> void:
	row.add_child(label(title, 13))
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = float(model.clips[selected][key])
	spin.custom_minimum_size.x = 92
	spin.value_changed.connect(func(value: float) -> void:
		if selected < 0:
			return
		model.clips[selected][key] = value
		_remember_edit()
		dirty = true
		stop()
		if not model.save_project(): status.text = LocalizationSystem.text(model.error))
	row.add_child(spin)

func build_inspector() -> void:
	for child in inspector.get_children(): inspector.remove_child(child); child.queue_free()
	if selected<0 or selected>=model.clips.size():
		inspector.add_child(label("点一张声音纸条\n调节它的大小声\n和播放速度。",18)); return
	inspector.add_child(label(str(model.clips[selected].name).left(10),20))
	var caption:=label("音量  %d%%"%roundi(float(model.clips[selected].volume)*100),18)
	inspector.add_child(caption)
	var gain:=HSlider.new(); gain.min_value=0; gain.max_value=1.5; gain.step=.05
	gain.value=float(model.clips[selected].volume); gain.custom_minimum_size=Vector2(210,34); gain.tooltip_text="左右拖动，调整这段声音的大小"
	inspector.add_child(gain)
	gain.value_changed.connect(func(value:float):
		if selected<0: return
		model.clips[selected].volume=value; caption.text="音量  %d%%"%roundi(value*100)
		dirty=true; revision+=1; stop()
		if not model.save_project(): status.text=model.error)
	gain.drag_ended.connect(func(_changed:bool): _remember_edit())
	gain.focus_exited.connect(_remember_edit)
	inspector.add_child(label("速度",18))
	var speed:=OptionButton.new(); speed.custom_minimum_size.y=38
	var values:=[.5,.75,1.0,1.25,1.5,2.0]
	for v in values: speed.add_item(str(v)+" ×"+("  原速" if v==1.0 else ""))
	speed.select(values.find(float(model.clips[selected].speed)))
	speed.item_selected.connect(func(index:int):
		var clip:=model.clips[selected]; var old:=float(clip.speed)
		clip.speed=values[index]; clip.length=minf(float(clip.length)*old/float(clip.speed),60.0-float(clip.start)); changed())
	inspector.add_child(speed)
	inspector.add_child(button("拿走这段",delete_clip))

func changed() -> bool:
	revision+=1
	has_listened=false
	if not restoring_history: _remember_edit()
	for i in mute_controls.size():
		mute_controls[i].set_pressed_no_signal(bool(model.muted[i]))
		gain_controls[i].set_value_no_signal(float(model.gains[i]))
	dirty = true
	stop()
	timeline.view_seconds=clampf(ceilf(model.length()/4.0)*4.0+4.0,12,60)
	timeline.queue_redraw()
	build_inspector()
	var saved: bool=model.save_project()
	if not saved: status.text = LocalizationSystem.text(model.error)
	_guide()
	return saved

func prepare_mix() -> bool:
	if mixing:
		status.text = LocalizationSystem.text("混音正在生成，请稍候。")
		return false
	if dirty or mixdown == null:
		mixing = true
		_guide()
		var mixing_revision:=revision
		status.text = LocalizationSystem.text("后台混音中……")
		mixdown = await model.mix_async()
		mixing = false
		dirty = revision!=mixing_revision
		_guide()
		if dirty:
			status.text="刚刚改过纸带，再点一次试听就能听到新版本。"
			return false
	if mixdown == null:
		status.text = LocalizationSystem.text(model.error)
		return false
	return true

func play() -> void:
	if not await prepare_mix():
		return
	player.stream = mixdown
	mv.configure(mixdown,model.prompt,model.seed_value); mv.model=model
	player.stream_paused = false
	player.play(paused_at if paused_at < model.length() else 0.0)
	has_listened=true; play_control.text="Ⅱ 暂停"; _guide()
	status.text = "正在播放你的声音纸带 · 右边的画面跟随剪辑位置变化。"

func pause() -> void:
	play_control.text="▶ 继续听"
	if player.playing:
		paused_at = player.get_playback_position()
		player.stop()

func stop() -> void:
	if is_instance_valid(play_control): play_control.text="▶ 听听看"
	player.stop()
	paused_at = 0
	if timeline != null:
		timeline.playhead = 0
		timeline.queue_redraw()

func _process(_delta: float) -> void:
	if player.playing:
		paused_at = maxf(0, player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())
	if not is_visible_in_tree(): return
	mv.time=paused_at; mv.queue_redraw()
	timeline.playhead = paused_at
	timeline.queue_redraw()
	clock_label.text = "%.1f / %.1f s" % [paused_at, model.length()]

func split_clip() -> void:
	if model.split(selected, paused_at):
		changed()
	else:
		status.text = LocalizationSystem.text("先把播放游标移到片段内部，再拆分。")

func duplicate_clip() -> void:
	selected = model.duplicate_clip(selected)
	timeline.selected = selected
	changed()

func delete_clip() -> void:
	if selected >= 0 and selected < model.clips.size():
		model.clips.remove_at(selected)
		selected = -1
		timeline.selected = -1
		changed()

func edit_region(keep: bool) -> void:
	if region_start < 0 or region_end - region_start < 0.01:
		status.text = LocalizationSystem.text("先点「剪刀 · 划出一段」，再在波形上拖选要剪辑的范围。")
		return
	if keep: model.keep_range(region_start, region_end, region_track)
	else: model.remove_range(region_start, region_end, region_track)
	selected = -1
	timeline.selected = -1
	timeline.range_begin = -1
	region_start = -1
	region_end = -1
	timeline.range_end = -1
	changed()
	status.text = LocalizationSystem.text("已保留选区内的声音。" if keep else "选区已剪掉，左右两段保留在原来的位置。")

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_D and event.is_command_or_control_pressed():
			duplicate_clip()
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			if timeline.selection_mode and region_start >= 0: edit_region(false)
			else: delete_clip()

func open_visual() -> void:
	var check := GameplayModuleSystem.entry_check("sound_sampling",60)
	if not bool(check.ok): status.text=str(check.reason); return
	if not await prepare_mix():
		return
	if not model.save_project():
		status.text = LocalizationSystem.text(model.error)
		return
	stop()
	var visual = load("res://scripts/town_sound/visual/VisualRoom.gd").new()
	visual.studio = self
	visual.model = model
	visual.audio = mixdown
	get_parent().add_child(visual)
	hide()

func request_visual() -> void:
	var check := GameplayModuleSystem.entry_check("sound_sampling",60)
	if not bool(check.ok): status.text=str(check.reason); return
	var confirmation := preload("res://scripts/ui/components/confirm_sheet.gd").new()
	confirmation.heading="制作并交付唱片"
	confirmation.description=("当前视角 "+GameState.current_role+"\n" if CharacterSystem.switch_unlocked() else "")+"封面与压片交付会用去 60 分钟。\n工程已保留；取消不会结算这段时间。"
	confirmation.confirm_text="开始制作"; add_child(confirmation)
	confirmation.accepted.connect(func(): confirmation.queue_free(); await open_visual())

func _exit_tree() -> void:
	if monitor_locked: get_node("/root/WorldSound").lock_monitor(false)

func _edit_snapshot() -> Dictionary:
	return {"clips":model.clips.duplicate(true),"muted":model.muted.duplicate(),"gains":model.gains.duplicate()}
func _remember_edit() -> void:
	var current := _edit_snapshot()
	if current==previous_edit: return
	edit_history.append(previous_edit.duplicate(true))
	if edit_history.size()>40: edit_history.pop_front()
	previous_edit=current; redo_history.clear()
	undo_button.disabled=false; redo_button.disabled=true
func _restore_edit(snapshot: Dictionary) -> void:
	restoring_history=true; model.clips.assign(snapshot.clips); model.muted=snapshot.muted.duplicate(); model.gains=snapshot.gains.duplicate()
	selected=-1; timeline.selected=-1; previous_edit=_edit_snapshot(); changed(); restoring_history=false
	undo_button.disabled=edit_history.is_empty(); redo_button.disabled=redo_history.is_empty()
func _undo_edit() -> void:
	if edit_history.is_empty(): return
	redo_history.append(_edit_snapshot()); _restore_edit(edit_history.pop_back())
func _redo_edit() -> void:
	if redo_history.is_empty(): return
	edit_history.append(_edit_snapshot()); _restore_edit(redo_history.pop_back())

func build_starter() -> void:
	if not model.clips.is_empty():
		status.text="时间轴已有作品。为避免覆盖，请先保存并清空片段，或直接继续编辑。"
		return
	var items:=SampleStore.new().list_samples().filter(func(item:Dictionary): return not bool(item.get("missing",true)) and float(item.get("duration",0))>=0.15 and float(item.get("signal_peak",1))>.0001)
	if items.size()<2:
		status.text="先保存至少两段真实采样。去公交站录风、饭店录火，或在书店录翻页。"
		return
	for i in mini(items.size(),4):
		var index:=model.add_sample(items[i],i,float(i)*2)
		model.clips[index].loop=true
		model.clips[index].length=16-float(i)*2
		model.clips[index].volume=.6
		model.clips[index].fade_in=.2
		model.clips[index].fade_out=.5
	changed()
	status.text="已用你的录音搭出 16 秒草稿。可撤销；试听后拖选裁剪，调整每种声音出现的位置。"
