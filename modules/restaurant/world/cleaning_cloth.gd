extends Node2D
## One reusable cloth; travel while in contact transfers finite residue into the cloth.
var world: Node2D
var active := false
var wetness := 0.0
var absorbed_kg := 0.0
var _last_sound := -10.0
const HOME := Vector2(455, 742)
const CAPACITY_KG := 0.01

func _ready() -> void:
	position = HOME
	z_index = 42

func _draw() -> void:
	paint(self)

func paint(target: Node2D) -> void:
	var paper := Color("efdfbf").darkened(wetness * 0.14)
	var shape := PackedVector2Array([Vector2(-48,-19),Vector2(40,-22),Vector2(48,19),Vector2(-42,24)])
	target.draw_colored_polygon(shape, paper)
	for x in [-24, 4, 28]: target.draw_line(Vector2(x,-18),Vector2(x+5,19),Color("bb705f"),5,true)
	target.draw_line(Vector2(-40,16),Vector2(42,13),Color("c6b493"),2,true)
	if absorbed_kg > 0.000001:
		for i in range(4): target.draw_circle(Vector2(-18+i*12, sin(i*2.0)*8), 5, Color("735038",clampf(absorbed_kg*300,0.12,0.6)))

func _process(delta: float) -> void:
	if not world.controls_enabled: return
	if active and world.pan.faucet_on and Rect2(100, 615, 245, 165).has_point(position):
		wetness = minf(1.0, wetness + delta * 1.4)
		var removed := minf(absorbed_kg, delta * 0.004)
		absorbed_kg -= removed
		world.pan.residue.waste_kg += removed
		queue_redraw()

func wipe_segment(from: Vector2, to: Vector2) -> float:
	if world.cooking or world.pan.active or world.pan.falling or not world.pan.is_empty_for_cleaning(): return 0.0
	# Clip the motion by sampling actual contact. Merely holding still cannot clean.
	var distance := from.distance_to(to)
	if distance < 0.5: return 0.0
	var steps := maxi(1, ceili(distance / 5.0))
	var contact := 0.0
	for i in steps:
		var local: Vector2 = world.pan.local_point(from.lerp(to, (i + 0.5) / steps))
		if ((local - Vector2(810,576)) / Vector2(107,29)).length() <= 1.0: contact += distance / steps
	var wanted := contact * (0.000007 if wetness > 0.25 else 0.0000015)
	var moved: float = world.pan.residue.wipe(minf(wanted, maxf(0.0, CAPACITY_KG - absorbed_kg)))
	absorbed_kg += moved
	if moved > 0.0:
		wetness = maxf(0.0, wetness - contact * 0.00025)
		if world._time - _last_sound > 0.18:
			world.audio.play_effect("wipe")
			_last_sound = world._time
		world.focus_changed.emit("擦净锅底", "还剩 %.1f g 残留 · 抹布脏了可在水龙头下冲洗" % (world.pan.residue.total_kg()*1000))
		queue_redraw()
	return moved

func _input(event: InputEvent) -> void:
	if not world.controls_enabled: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
		if not event.pressed and active:
			release_tool()
			get_viewport().set_input_as_handled()
		elif event.pressed and Rect2(position-Vector2(50,26), Vector2(100,52)).has_point(point) and not is_instance_valid(world._held) and not world._knife_held and not world.has_active_utensil() and not world.pan.active:
			active = true
			world.held_changed.emit("抹布")
			world.focus_changed.emit("抹布", "先关火、装盘；在水龙头下打湿，再按住拖过空锅的残留")
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and active:
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			release_tool()
			return
		var next: Vector2 = (world.get_global_transform_with_canvas().affine_inverse() * event.position).clamp(Vector2(50,530),Vector2(1550,765))
		wipe_segment(position, next)
		position = next
		get_viewport().set_input_as_handled()

func release_tool() -> void:
	active = false
	position = HOME
	world.held_changed.emit("")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: release_tool()
