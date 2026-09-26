extends Node2D
## A selection frame in desk coordinates; paper geometry and ink remain untouched.
var game
var active:=""
var handle_index:=-1
var original_transform:=Transform2D.IDENTITY
var original_scale:=Vector2.ONE
var original_position:=Vector2.ZERO
var original_rotation:=0.0
var anchor:=Vector2.ZERO
var local_anchor:=Vector2.ZERO
var local_handle:=Vector2.ZERO
var start_angle:=0.0
const DIRECTIONS=[Vector2(0,0),Vector2(0.5,0),Vector2(1,0),Vector2(1,0.5),Vector2(1,1),Vector2(0.5,1),Vector2(0,1),Vector2(0,0.5)]
func available() -> bool:
	return is_instance_valid(game.selected) and game.stage=="WORKBENCH" and game.tool=="move" and not game.busy and not game.conversation_open and not game.dock_open and not game.help_open
func points() -> PackedVector2Array:
	var result:=PackedVector2Array();var piece=game.selected;var bounds:Rect2=piece.bounds()
	for direction in DIRECTIONS:result.append(piece.to_global(bounds.position+bounds.size*direction))
	return result
func rotate_point() -> Vector2:
	var p:=points();return p[1]+(p[1]-p[5]).normalized()*20.0
func remove_point() -> Vector2:
	var p:=points();return p[2]+(p[2]-p[6]).normalized()*20.0
func _draw() -> void:
	if not available():return
	if not game.dragging and active.is_empty() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):return
	var p:=points();var outline:=PackedVector2Array([p[0],p[2],p[4],p[6],p[0]])
	var hover:=get_global_mouse_position().distance_to(rotate_point())<12 or not active.is_empty()
	var ink:=Color(0.36,0.43,0.38,0.68 if hover else 0.38)
	draw_polyline(outline,Color(ink,0.28),0.75,true)
	draw_line(p[1],rotate_point(),Color(ink,0.28),0.75,true)
	for point in p:
		var near:=get_global_mouse_position().distance_to(point)<11
		var radius:=2.8 if near else 2.0
		draw_circle(point,radius,Color(0.99,0.96,0.87,0.75 if near else 0.5))
		draw_arc(point,radius,0,TAU,12,Color(ink,0.7 if near else 0.4),0.75,true)
	var turn:=rotate_point()
	draw_arc(turn,4,-2.2,1.5,16,ink,0.85,true)
	draw_line(turn+Vector2(0.2,4),turn+Vector2(3.3,3.0),ink,0.85,true)
	var remove:=remove_point()
	draw_line(remove+Vector2(-2.5,-2.5),remove+Vector2(2.5,2.5),ink,0.85,true)
	draw_line(remove+Vector2(-2.5,2.5),remove+Vector2(2.5,-2.5),ink,0.85,true)
func _process(_dt: float) -> void:queue_redraw()
func _input(event: InputEvent) -> void:
	if not available():active="";return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and not active.is_empty():
		game.selected.transform=original_transform;active="";game.changed();get_viewport().set_input_as_handled();return
	if not event is InputEventMouse:return
	var at:Vector2=game.get_canvas_transform().affine_inverse()*event.position
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			var p:=points();handle_index=-1
			if at.distance_to(remove_point())<10:game.delete_selected();get_viewport().set_input_as_handled();return
			if at.distance_to(rotate_point())<12:active="rotate"
			else:
				for i in p.size():
					if at.distance_to(p[i])<11:handle_index=i;break
				if handle_index<0:return
				active="resize"
			var piece=game.selected
			original_transform=piece.transform;original_scale=piece.scale;original_position=piece.position;original_rotation=piece.rotation
			start_angle=(at-piece.position).angle()
			if active=="resize":
				var rect:Rect2=piece.bounds()
				local_handle=rect.position+rect.size*DIRECTIONS[handle_index]
				local_anchor=rect.position+rect.size*(Vector2.ONE-DIRECTIONS[handle_index]);anchor=piece.to_global(local_anchor)
			game.dragging=false;game.audio.play("PAPER_MOVE",0.4)
		elif not active.is_empty():
			update_drag(at);active="";game.selected.release_lift();game.changed();game.audio.play("PAPER_PRESS",0.4)
		else:return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not active.is_empty():
		update_drag(at);get_viewport().set_input_as_handled()
func update_drag(at: Vector2) -> void:
	var piece=game.selected
	if active=="rotate":piece.rotation=original_rotation+wrapf((at-original_position).angle()-start_angle,-PI,PI)
	elif active=="resize":
		var displacement:Vector2=(at-anchor).rotated(-original_rotation)
		var span:=local_handle-local_anchor
		var next_scale:=original_scale
		if handle_index%2==0:
			var diagonal:=span*original_scale
			var factor:=clampf(displacement.dot(diagonal)/diagonal.length_squared(),0.05,20.0)
			var dimensions:Vector2=piece.bounds().size*original_scale.abs()
			factor=clampf(factor,maxf(16.0/dimensions.x,16.0/dimensions.y),minf(1100.0/dimensions.x,1100.0/dimensions.y))
			next_scale=original_scale*factor
		elif absf(span.x)>0.01:next_scale.x=signf(original_scale.x)*clampf(displacement.x/span.x*signf(original_scale.x),16.0/piece.bounds().size.x,1100.0/piece.bounds().size.x)
		else:next_scale.y=signf(original_scale.y)*clampf(displacement.y/span.y*signf(original_scale.y),16.0/piece.bounds().size.y,1100.0/piece.bounds().size.y)
		piece.scale=next_scale;piece.position=anchor-(local_anchor*next_scale).rotated(original_rotation)
	piece.queue_redraw();game.refresh_paper_stack();queue_redraw()
