extends CanvasLayer
## Developer overlay only. It reads the same state used by play, not a duplicate model.
var world: Node2D
var panel: Label

func _ready() -> void:
	layer = 20
	panel = Label.new()
	panel.position = Vector2(14,100)
	panel.add_theme_font_override("font",preload("res://modules/restaurant/assets/fonts/noto_sans_sc.ttf"))
	panel.add_theme_font_size_override("font_size",17)
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.08,0.13,0.13,0.92)
	style.content_margin_left=12
	style.content_margin_right=12
	style.content_margin_top=10
	style.content_margin_bottom=10
	panel.add_theme_stylebox_override("normal",style)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.visible=false
	add_child(panel)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_F3 or event.keycode==KEY_F3):
		panel.visible=not panel.visible
		get_viewport().set_input_as_handled()

func _process(_dt: float) -> void:
	if not panel.visible: return
	var ledger: Dictionary=world.pan.runoff.inventory()
	var body: RigidBody2D=world._held if is_instance_valid(world._held) else world._food_at(world.get_global_mouse_position())
	panel.text="物理检查 · F3 收起\nGodot 2D · %d Hz · %d FPS\n碰撞对 %d · 活动 %d · 物理 %.2f ms\n锅 %.3f kg · %.1f °C · 倾角 %.1f°\n水 %.2f ml · 沿口 %.2f ml · 流速 %.1f ml/s\n在途 %.2f · 台面 %.2f · 地面 %.2f ml\n排水 %.2f · 海绵 %.2f ml\n锅盖压力代理 %.1f · 开口 %.1f px" % [Engine.physics_ticks_per_second,Engine.get_frames_per_second(),int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)),int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)),Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,world.pan.rigid.mass,world.reactions.pan_c,rad_to_deg(world.pan.angle),world.pan.water_ml,world.pan.rim_water_ml,world.pan.outflow_ml_s,ledger.flight_ml,ledger.surface_ml,ledger.floor_ml,ledger.drained_ml,ledger.wiped_ml,world.pan.lid.pressure_pa,world.pan.lid.gap]
	if is_instance_valid(body):
		panel.text += "\n\n%s · %s\n质量 %.4f kg · 速度 %.1f px/s\n摩擦 %.2f · 回弹 %.2f · 接触 %d\n休眠 %s · CCD %s\n抓力 %.1f · 锚点 %s" % [body.get_meta("title","食材"),body.get_meta("instance_uid",""),body.mass,body.linear_velocity.length(),body.physics_material_override.friction if body.physics_material_override else 0.0,body.physics_material_override.bounce if body.physics_material_override else 0.0,body.get_contact_count(),body.sleeping,body.continuous_cd,world.held_grip.last_force.length(),world.held_grip.local_anchor]
