extends RefCounted
## Original flat enamel silhouette, shared by the desk object and working keyboard.
const KEY_ROWS=["1234567890","qwertyuiop","asdfghjkl","zxcvbnm,."]
static func key_center(row:int,column:int)->Vector2:
	return Vector2(67+(10-KEY_ROWS[row].length())*16+column*34,192+row*23)
static func paint(c:CanvasItem, rect:Rect2, paper:bool=true) -> void:
	c.draw_set_transform(rect.position,0,rect.size/Vector2(440,330))
	var shell:=PackedVector2Array([Vector2(43,113),Vector2(393,113),Vector2(419,253),Vector2(437,297),Vector2(425,319),Vector2(17,319),Vector2(3,297),Vector2(24,250)])
	var shadow:=PackedVector2Array()
	for p in shell:shadow.append(p+Vector2(5,8))
	c.draw_colored_polygon(shadow,Color(0.24,0.20,0.16,0.20))
	if paper:
		c.draw_colored_polygon(PackedVector2Array([Vector2(91,107),Vector2(97,2),Vector2(344,6),Vector2(352,109)]),Color("f3e8cc"))
		c.draw_polyline(PackedVector2Array([Vector2(98,4),Vector2(102,98),Vector2(343,102)]),Color("c3b89b"),1.2,true)
	c.draw_line(Vector2(39,110),Vector2(400,110),Color("313e3a"),19,true)
	for x in [23,414]:
		c.draw_circle(Vector2(x,109),16,Color("3c443d"));c.draw_arc(Vector2(x,109),12,-1.9,1.7,20,Color("868b75"),2,true)
	c.draw_line(Vector2(36,91),Vector2(397,91),Color("b8b49a"),4,true)
	c.draw_line(Vector2(29,92),Vector2(11,59),Color("858c7c"),4,true)
	c.draw_line(Vector2(11,59),Vector2(66,54),Color("455950"),7,true)
	c.draw_colored_polygon(shell,Color("526f64"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(43,113),Vector2(393,113),Vector2(398,158),Vector2(363,180),Vector2(74,180),Vector2(36,158)]),Color("7d9480"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(71,182),Vector2(368,182),Vector2(405,277),Vector2(39,277)]),Color("344a42"))
	c.draw_polyline(PackedVector2Array([Vector2(20,292),Vector2(35,302),Vector2(416,302),Vector2(425,291)]),Color("a4ac8f"),2,true)
	c.draw_arc(Vector2(219,107),66,0,PI,34,Color("263d35"),14,true)
	for i in 17:
		var direction:=Vector2.from_angle(float(i)/16*PI)
		c.draw_line(Vector2(219,107)+direction*23,Vector2(219,107)+direction*61,Color("a4a18a"),1.3,true)
	c.draw_line(Vector2(169,141),Vector2(270,141),Color("a55e51"),5,true)
	c.draw_colored_polygon(PackedVector2Array([Vector2(214,111),Vector2(225,111),Vector2(224,129),Vector2(216,129)]),Color("c1bca3"))
	for row in KEY_ROWS.size():
		for col in KEY_ROWS[row].length():
			var at:=key_center(row,col)
			c.draw_circle(at+Vector2(0,3),10,Color("172d28"));c.draw_circle(at,9,Color("b8b298"));c.draw_circle(at,7.4,Color("e3d4b1"))
			c.draw_string(ThemeDB.fallback_font,at+Vector2(-3.5,3.5),KEY_ROWS[row][col].to_upper(),HORIZONTAL_ALIGNMENT_LEFT,10,10,Color("394a41"))

	c.draw_line(Vector2(136,279),Vector2(307,279),Color("c9bc9b"),10,true)
	c.draw_set_transform(Vector2.ZERO)
