extends Control

const CREAM := Color("fff6e5")
const INK := Color("31658b")
const TERRACOTTA := Color("31658b")
const SEA := Color("31658b")
const LETTER_DESIGN_SIZE := Vector2i(1440, 810)
const LETTER_HOST_BAR_HEIGHT := 72.0

var module_id := ""
var session_context: Dictionary = {}
var metadata: Dictionary = {}
var experience: Node
var complete_button: Button
var status_label: Label
var completion_ready := false
var submitting := false
var letter_container: SubViewportContainer
var letter_viewport: SubViewport
var host_panel: Panel


func _ready() -> void:
	WorldSound.set_location(GameState.current_location); WorldSound.set_active(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	module_id = GameplayModuleSystem.pending_module_id()
	session_context=GameplayModuleSystem.session_context()
	metadata = GameplayModuleSystem.modules.get(module_id, {})
	var scene_path := str(metadata.get("extension_scene_path", ""))
	if str(session_context.get("current_character",""))!=GameState.current_role or module_id.is_empty() or scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		call_deferred("_fail_and_return", "扩展场景不存在，已安全返回。")
		return
	var packed = load(scene_path)
	if not packed is PackedScene:
		call_deferred("_fail_and_return", "扩展场景无法读取，已安全返回。")
		return
	experience = packed.instantiate()
	experience.set_meta("solmere_context",session_context.duplicate(true))
	if module_id == "ghostwriting":
		# The letter uses both Node2D drawing and CanvasLayers. A Node2D offset
		# moves only its drawing, leaving controls and capture coordinates behind.
		letter_container = SubViewportContainer.new()
		letter_container.name = "LetterContainer"
		letter_container.stretch = false
		letter_container.mouse_filter = Control.MOUSE_FILTER_STOP
		letter_container.size = Vector2(LETTER_DESIGN_SIZE)
		add_child(letter_container)
		letter_viewport = SubViewport.new()
		letter_viewport.name = "LetterViewport"
		letter_viewport.size = LETTER_DESIGN_SIZE
		letter_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		letter_container.add_child(letter_viewport)
		letter_viewport.add_child(experience)
		resized.connect(_fit_experience)
	else:
		add_child(experience)
		resized.connect(_fit_experience)
	if module_id == "contemplation":
		experience.return_requested.connect(_cancel)
		experience.finish_requested.connect(_complete)
		ObservatoryAudio.set_stargazing(true)
	if module_id == "tarot" and experience.has_signal("exit_requested"):
		experience.exit_requested.connect(func():
			if _experience_completed(): _complete()
			else: _cancel())
	_fit_experience()
	_build_host_bar()
	_fit_experience()


func _fit_experience() -> void:
	if module_id == "ghostwriting" and is_instance_valid(letter_container):
		var available := Vector2(size.x, maxf(1.0, size.y - LETTER_HOST_BAR_HEIGHT))
		var fit := maxf(0.01, minf(available.x / LETTER_DESIGN_SIZE.x, available.y / LETTER_DESIGN_SIZE.y))
		letter_container.scale = Vector2.ONE * fit
		letter_container.position = Vector2((size.x - LETTER_DESIGN_SIZE.x * fit) * 0.5,
			LETTER_HOST_BAR_HEIGHT + (available.y - LETTER_DESIGN_SIZE.y * fit) * 0.5)
		if is_instance_valid(host_panel):
			host_panel.position = Vector2.ZERO
			host_panel.size = Vector2(size.x, LETTER_HOST_BAR_HEIGHT - 4)
		return
	if experience is Control:
		experience.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if module_id == "chess":
			experience.offset_top = LETTER_HOST_BAR_HEIGHT
			if is_instance_valid(host_panel):
				host_panel.position = Vector2.ZERO
				host_panel.size = Vector2(size.x, LETTER_HOST_BAR_HEIGHT - 4)
		if module_id == "tarot" and not experience.has_signal("exit_requested"):
			experience.offset_top = 60
			if not has_node("TableHeader"):
				var backdrop := ColorRect.new(); backdrop.name="TableHeader"; backdrop.color=Color("214860"); backdrop.size=Vector2(size.x,60); backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(backdrop)
	if experience is Node2D:
		if module_id == "translation":
			var fit := minf(size.x / 1280.0, maxf(1.0,size.y-100.0) / 960.0)
			experience.scale = Vector2.ONE * fit
			experience.position = Vector2((size.x-1280.0*fit)*0.5,100)


func _build_host_bar() -> void:
	if module_id == "tarot" and experience.has_signal("exit_requested"):
		status_label = experience.status
		return
	# The telescope owns its controls; route shared errors to its visible hint.
	if module_id == "contemplation":
		status_label = experience.hint
		return
	var layer := CanvasLayer.new()
	layer.layer = 500
	add_child(layer)
	var panel := Panel.new()
	host_panel = panel
	panel.position = Vector2(825, 12)
	panel.size = Vector2(755, 88)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("faf1dd")
	style.border_color = Color(TERRACOTTA, 0.85)
	style.set_border_width_all(0)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(INK, 0.2)
	style.shadow_size = 0
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var title := Label.new()
	title.text = LocalizationSystem.text(str(metadata.get("name", module_id)))
	title.position = Vector2(18, 10)
	title.size = Vector2(250, 28)
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", INK)
	panel.add_child(title)
	status_label = Label.new()
	status_label.text = LocalizationSystem.text(str(metadata.get("completion_hint", "完成这段经历后返回小镇。")))
	status_label.position = Vector2(18, 40)
	status_label.size = Vector2(370, 37)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", SEA)
	panel.add_child(status_label)
	var leave := _button(panel, "暂时离开", Vector2(405, 19), Vector2(145, 50), false)
	leave.pressed.connect(_cancel)
	complete_button = _button(panel, "完成并返回", Vector2(564, 19), Vector2(170, 50), true)
	complete_button.disabled = true
	complete_button.pressed.connect(_complete)
	if module_id in ["ghostwriting", "chess"]:
		panel.add_to_group("solid_hud")
		title.position = Vector2(18, 5)
		status_label.position = Vector2(18, 32)
		status_label.size = Vector2(1040, 26)
		status_label.add_theme_font_size_override("font_size", 18)
		status_label.clip_text = true
		leave.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		leave.position = Vector2(panel.size.x - 345, 9)
		leave.size = Vector2(145, 48)
		complete_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		complete_button.position = Vector2(panel.size.x - 186, 9)
		complete_button.size = Vector2(170, 48)
	if module_id in ["contemplation", "tarot"]:
		panel.position = Vector2(1210, 92)
		if module_id == "tarot": panel.position.y = 0
		panel.size = Vector2(360, 60)
		panel.add_to_group("scene_speech")
		panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		leave.text = LocalizationSystem.text("收起")
		complete_button.text = LocalizationSystem.text("带着回忆回去")
		title.hide()
		status_label.hide()
		leave.position = Vector2(8, 8)
		leave.size = Vector2(145, 44)
		complete_button.position = Vector2(166, 8)
		complete_button.size = Vector2(184, 44)


func _button(parent: Node, text_value: String, at: Vector2, button_size: Vector2, primary: bool) -> Button:
	var button := preload("res://scripts/ui/components/solmere_button.gd").new()
	button.variant="camera" if module_id in ["tarot","contemplation"] else "outlined"
	button.selected=primary; button.text=LocalizationSystem.text(text_value); button.position=at; button.size=button_size; parent.add_child(button)
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return button


func _process(_delta: float) -> void:
	if experience == null or complete_button == null:
		return
	var ready := _experience_completed()
	if module_id=="contemplation": complete_button.visible=ready
	if ready == completion_ready:
		return
	completion_ready = ready
	complete_button.disabled = not ready
	if ready:
		status_label.text = LocalizationSystem.text("这段经历已经完整，可以把结果带回 Solmere。")


func _experience_completed() -> bool:
	match module_id:
		"tarot":
			return bool(experience.get("solmere_completed"))
		"translation":
			return bool(experience.get("finished"))
		"ghostwriting":
			return bool(experience.get("solmere_completed"))
		"chess":
			return bool(experience.get("solmere_completed"))
		"contemplation":
			return bool(experience.get("solmere_completed"))
	return true


func _complete() -> void:
	if submitting or SceneRouter.transitioning or not _experience_completed():
		return
	submitting = true
	if module_id == "contemplation":
		experience.view_age=0
		status_label.modulate.a=1
	var money_before := GameState.money
	var rollback_snapshot := GameState.to_save_data().duplicate(true)
	var pending: Dictionary = GameState.shared_state.get("pending_module", {})
	var source_event_id := str(pending.get("source_event_id", ""))
	if source_event_id.begins_with("space:") or source_event_id.begins_with("street:"):
		var direct_minutes := int(metadata.get("direct_time_minutes", 0))
		if direct_minutes > 0 and not GameState.use_free_time(direct_minutes):
			submitting = false
			status_label.text = LocalizationSystem.text("当前时间块已不足 %d 分钟。进度保留在扩展内部，请暂时离开。" % direct_minutes)
			return
	var outcome := {
		"choice_id": "extension_complete",
		"label": str(metadata.get("name", module_id)),
		"source_event_id": source_event_id,
		"interaction": {"context":session_context.duplicate(true),"mode": "extension", "selected_labels": [str(metadata.get("name", module_id))]},
	}
	if module_id == "contemplation":
		outcome["interaction"].merge(experience.observation_result(),true)
	if module_id == "ghostwriting":
		# V3 completes after the local resident's accepted letter is postmarked.
		experience.save_game()
		outcome["letter"]={"preview_path":str(experience.preview_path),"title":str(experience.letter_title),"owner":GameState.current_role}
		outcome["contribution_accepted"] = bool(experience.get("solmere_completed"))
		outcome["acceptance"] = {"location":"handcraft_shop","source":"offline_letter_office_v3","external_id":"","stage":"POSTMARKED"}
	if not GameplayModuleSystem.complete_external(module_id, outcome, metadata.get("external_results", {})):
		GameState.load_save_data(rollback_snapshot)
		submitting = false
		status_label.text = LocalizationSystem.text("结果暂时无法写入主存档，请重试。")
		return
	if not SaveManager.save_or_report("玩法结果保存失败"):
		submitting = false
		GameState.load_save_data(rollback_snapshot)
		status_label.text = LocalizationSystem.text("存档写入失败，本次提交尚未生效；可以重试。")
		return
	WorldSound.play_ui("coin" if GameState.money > money_before else "dialogue")
	SceneRouter.return_from_gameplay()


func _cancel() -> void:
	if submitting or SceneRouter.transitioning: return
	if module_id == "contemplation":
		experience.view_age=0
		status_label.modulate.a=1
	var rollback_snapshot := GameState.to_save_data().duplicate(true)
	if module_id == "ghostwriting" and is_instance_valid(experience) and experience.has_method("save_game"):
		experience.save_game()
	var preserved_extension_state: Dictionary = {}
	var reader_state: Dictionary = {}
	var preserved_key := ""
	if module_id == "tarot" and is_instance_valid(experience) and experience.has_method("save_session"):
		experience.save_session()
		preserved_key = "myriorama_" + GameState.current_role
		preserved_extension_state = GameState.shared_state.get(preserved_key, {}).duplicate(true)
		reader_state = GameState.shared_state.get("tarot_reader_" + GameState.current_role, {}).duplicate(true)
	var extension_drafts: Dictionary=GameState.artifacts.get("minigame_drafts",{}).duplicate(true)
	GameplayModuleSystem.cancel_session()
	if not reader_state.is_empty(): GameState.shared_state["tarot_reader_" + GameState.current_role] = reader_state
	GameState.artifacts["minigame_drafts"]=extension_drafts
	if module_id == "contemplation" and is_instance_valid(experience):
		experience.preserve_after_cancel()
	if not preserved_key.is_empty() and not preserved_extension_state.is_empty():
		GameState.shared_state[preserved_key] = preserved_extension_state
		GameState.commit_active_role_state()
	if not SaveManager.save_or_report("取消玩法后保存失败"):
		GameState.load_save_data(rollback_snapshot)
		status_label.text = LocalizationSystem.text("存档暂时没能写入，仍留在当前小游戏。可以重试离开。")
		return
	SceneRouter.return_from_gameplay()


func _fail_and_return(message: String) -> void:
	push_error(message)
	GameplayModuleSystem.cancel_session()
	SceneRouter.return_from_gameplay()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		_cancel()

func _exit_tree() -> void:
	if module_id == "contemplation": ObservatoryAudio.set_stargazing(false)
