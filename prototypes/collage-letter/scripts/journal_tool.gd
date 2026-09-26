extends Button
## Simple original illustrated tool silhouettes; native vectors remain sharp at any window size.
var tool_id: String=""
var sample_style: int=-1
var paper_style_index: int=-1
var show_pigment:=false
var pigment_color:=Color.WHITE
const Tape=preload("res://scripts/tape_art.gd")
const LetterPaper=preload("res://scripts/letter_paper.gd")
func _draw() -> void:
	if show_pigment:
		var center:=size/2
		draw_circle(center+Vector2(0,1),17,Color("b8b6a1"));draw_circle(center,16,Color("fff6dd"))
		var shape:=PackedVector2Array();var coords:=PackedVector2Array()
		for i in 32:
			var vector:=Vector2.from_angle(i*TAU/32);shape.append(center+vector*(12+sin(i*2.7)*0.45));coords.append(vector*0.5+Vector2.ONE*0.5)
		draw_colored_polygon(shape,pigment_color)
		draw_polygon(shape,PackedColorArray([Color(pigment_color,0.35)]),coords,LetterPaper.texture(19))
	if paper_style_index>=0:LetterPaper.paint(self,Rect2(5,5,size.x-10,size.y-10),paper_style_index,false)
	if sample_style>=0:
		var shape:=PackedVector2Array([Vector2(6,8),Vector2(size.x-5,6),Vector2(size.x-7,13),Vector2(size.x-4,22),Vector2(6,25),Vector2(8,18)])
		Tape.paint(self,shape,sample_style)
	if tool_id.is_empty():return
	var ink:=Color("476258")
	draw_set_transform(Vector2(size.x*0.5,23),-0.10 if is_hovered() else 0.0)
	match tool_id:
		"brush":
			draw_line(Vector2(-8,9),Vector2(11,-16),Color("bd8f60"),6,true)
			draw_line(Vector2(-8,9),Vector2(-3,2),Color("95a8a1"),8,true)
			draw_colored_polygon(PackedVector2Array([Vector2(-12,9),Vector2(-16,18),Vector2(-6,17),Vector2(-2,11)]),Color("708f87"))
		"glue":
			draw_style_box(load("res://scripts/journal_style.gd").rounded(Color("94af86"),5),Rect2(-9,-8,18,27))
			draw_style_box(load("res://scripts/journal_style.gd").rounded(Color("fff3d8"),4),Rect2(-8,-17,16,13))
			draw_line(Vector2(-7,10),Vector2(7,10),Color("f3e4be"),4,true)
		"move":
			draw_colored_polygon(PackedVector2Array([Vector2(-12,-13),Vector2(-9,14),Vector2(-2,6),Vector2(5,16),Vector2(11,12),Vector2(4,3),Vector2(15,0)]),Color("fff6de"))
			draw_polyline(PackedVector2Array([Vector2(-12,-13),Vector2(-9,14),Vector2(-2,6),Vector2(5,16),Vector2(11,12),Vector2(4,3),Vector2(15,0),Vector2(-12,-13)]),ink,1.7,true)
		"rect","free":
			draw_line(Vector2(-11,10),Vector2(9,-12),Color("55796e"),9,true)
			draw_line(Vector2(-9,8),Vector2(9,-12),Color("9dc3b1"),4,true)
			draw_colored_polygon(PackedVector2Array([Vector2(-11,7),Vector2(-18,17),Vector2(-5,11)]),Color("f9eed7"))
			if tool_id=="rect":draw_rect(Rect2(7,4,10,9),ink,false,1)
			else:draw_arc(Vector2(12,9),6,0.1,4.7,16,ink,1.5,true)
		"tape":
			draw_colored_polygon(PackedVector2Array([Vector2(-7,3),Vector2(22,1),Vector2(19,12),Vector2(-7,14)]),Color("d5ad70"))
			draw_circle(Vector2(-5,0),14,Color("fff3d9"));draw_circle(Vector2(-5,0),11,Color("80b5a3"));draw_circle(Vector2(-5,0),6,Color("b68c69"));draw_arc(Vector2(-5,0),8,0,TAU,32,Color("ecdfb9"),1,true)
			for x in [4,10,16]:draw_line(Vector2(x,4),Vector2(x-2,10),Color("f6e6bd"),2,true)
		"pen","write":
			draw_line(Vector2(-11,11),Vector2(11,-12),Color("e1ae5b"),8,true)
			draw_line(Vector2(-10,9),Vector2(11,-12),Color("ffe3a6"),2,true)
			draw_colored_polygon(PackedVector2Array([Vector2(-15,10),Vector2(-18,19),Vector2(-8,15)]),Color("f5dcaa"))
			draw_line(Vector2(-18,19),Vector2(-16,16),ink,2,true)
			draw_line(Vector2(9,-10),Vector2(13,-14),Color("c9867d"),8,true)
	draw_set_transform(Vector2.ZERO)
