extends Node2D
const Tape=preload("res://extensions/collage_letter/scripts/tape_art.gd")
var game: Node2D
func _draw() -> void:
	if game.stage!="WORKBENCH":return
	if game.tape_drawing:
		var endpoint:=game.get_global_mouse_position()
		var length:=minf(game.tape_start.distance_to(endpoint),500)
		draw_set_transform((game.tape_start+endpoint)*0.5,(endpoint-game.tape_start).angle())
		Tape.paint(self,PackedVector2Array([Vector2(-length/2,-11),Vector2(length/2,-11),Vector2(length/2,11),Vector2(-length/2,11)]),game.tape_style)
		draw_set_transform(Vector2.ZERO)
	if game.doodle_drawing and game.doodle_path.size()>1: draw_polyline(game.doodle_path,game.pen_color,game.pen_width,true)

	var pen=game.letter_text_node
	if game.tool=="write" and pen.pen_visible and pen.pen_alpha>0 and pen.waiting_page<0:
		var at:Vector2=pen.position+pen.pen_position+Vector2(2,-2)
		if not pen.reduce_motion and pen.pen_lift:at.y-=sin(PI*clampf(pen.pen_clock/pen.pen_duration,0,1))*5
		draw_set_transform(at,0.58)
		var a:float=pen.pen_alpha
		draw_line(Vector2(7,-14),Vector2(7,-109),Color(0.18,0.15,0.12,0.13*a),11,true)
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO,Vector2(-5,-18),Vector2(-4,-29),Vector2(4,-29),Vector2(5,-18)]),Color("ba9e65",a))
		draw_line(Vector2(0,-3),Vector2(0,-22),Color("4d5347",a),1,true)
		draw_line(Vector2(0,-28),Vector2(0,-116),Color("456454",a),10,true)
		draw_line(Vector2(-3,-31),Vector2(-3,-115),Color("8c9b7a",a),2,true)
		draw_line(Vector2(-5,-33),Vector2(5,-33),Color("c3a978",a),3,true)
		draw_circle(Vector2(0,-118),5,Color("344d42",a))
		draw_line(Vector2(4,-113),Vector2(4,-82),Color("c3a978",a),2,true)
		draw_set_transform(Vector2.ZERO)
