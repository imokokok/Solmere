extends Node2D
## Constrained tabletop tool. Contact removes actual spill bodies and volume.
var world: Node2D
var active := false
var grab_offset := Vector2.ZERO
var absorbed_ml := 0.0
const CAPACITY_ML := 150.0

func _physics_process(dt: float) -> void:
	if not active or not world.controls_enabled: return
	if world.pan.faucet_on and Rect2(110,620,240,145).has_point(position):
		var drained := minf(absorbed_ml,dt*80.0)
		absorbed_ml -= drained
		world.pan.runoff.wiped_ml -= drained
		world.pan.runoff.drained_ml += drained
	queue_redraw()

func _ready() -> void:
	position = Vector2(372, 750)
	z_index = 43

func _draw() -> void:
	paint(self)

func paint(target: Node2D) -> void:
	target.draw_rect(Rect2(-28,-9,56,23), Color("e1b454").darkened(absorbed_ml/CAPACITY_ML*0.25))
	target.draw_rect(Rect2(-28,-16,56,7), Color("486f61"))
	for i in range(7): target.draw_circle(Vector2(-21+i*6, 2+(i%2)*5), 1.1, Color("c49542"))

func _input(event: InputEvent) -> void:
	if not world.controls_enabled: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
		if not event.pressed and active:
			release_tool()
			get_viewport().set_input_as_handled()
		elif event.pressed and Rect2(position-Vector2(30,18),Vector2(60,36)).has_point(point) and not is_instance_valid(world._held) and not world._knife_held and not world.has_active_utensil() and not world.pan.active:
			active = true
			grab_offset = position-point
			world.held_changed.emit("清洁海绵")
			world.focus_changed.emit("清洁海绵", "按住拖过台面的水渍或调料，松手放下")
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and active:
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			release_tool()
			return
		var point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
		var before := position
		position = (point+grab_offset).clamp(Vector2(32,550),Vector2(1560,766))
		var steps := maxi(1,ceili(position.distance_to(before)/12.0))
		for step in steps:
			var contact := before.lerp(position,(step+0.5)/steps)
			var taken: float = world.pan.runoff.wipe(contact,minf(12.0,maxf(0.0,CAPACITY_ML-absorbed_ml)))
			absorbed_ml += taken
			if taken>0.01: world.audio.play_effect("wipe",0.45)
		for body in world._foods.get_children():
			if body.is_queued_for_deletion() or not body.get_meta("overflow", false): continue
			var nearest := Geometry2D.get_closest_point_to_segment(body.position, before, position)
			if nearest.distance_to(body.position) < 35: world._wipe_spill_at(body.position, true)
		get_viewport().set_input_as_handled()

func release_tool() -> void:
	if not active: return
	active = false
	world.held_changed.emit("")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: release_tool()
