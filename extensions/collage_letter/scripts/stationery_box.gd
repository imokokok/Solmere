extends RefCounted
## Shared closed lid and open wooden tray; original flat painted geometry.
static func paint(c:CanvasItem,r:Rect2,opened:bool) -> void:
	c.draw_set_transform(r.position,0,r.size/Vector2(360,626 if opened else 220))
	var h:=626.0 if opened else 220.0
	var style:=StyleBoxFlat.new();style.bg_color=Color("8b6950");style.set_corner_radius_all(9);style.shadow_color=Color(0.20,0.15,0.10,0.25);style.shadow_size=7;style.shadow_offset=Vector2(4,9)
	c.draw_style_box(style,Rect2(0,9,360,h-9))
	c.draw_rect(Rect2(8,h-19,344,13),Color("634f3e"))
	c.draw_style_box(preload("res://extensions/collage_letter/scripts/journal_style.gd").rounded(Color("b18c63"),6),Rect2(5,3,350,h-20))
	c.draw_rect(Rect2(15,15,330,h-45),Color("786247") if opened else Color("8c9e88"))
	c.draw_line(Vector2(17,17),Vector2(342,17),Color("d9bd8d"),3,true)
	if opened:
		c.draw_rect(Rect2(21,56,318,144),Color("c1ab87"))
		for x in [100,181,262]:
			c.draw_line(Vector2(x,59),Vector2(x,197),Color("806849"),4,true)
			c.draw_line(Vector2(x+2,59),Vector2(x+2,197),Color("e1c79b"),2,true)
		c.draw_line(Vector2(23,130),Vector2(337,130),Color("816a4c"),4,true)
		c.draw_line(Vector2(23,132),Vector2(337,132),Color("e1c79b"),2,true)
		c.draw_rect(Rect2(20,210,320,h-242),Color("e2d2af"))
		for i in 3:c.draw_line(Vector2(23,213+i*2),Vector2(336,213+i*2),Color("bba781"),0.8,true)
		c.draw_line(Vector2(18,203),Vector2(342,203),Color("795f44"),5,true)
	else:
		for y in [23,190]:c.draw_line(Vector2(23,y),Vector2(337,y),Color("b9c4a4"),1.2,true)
		c.draw_line(Vector2(180,31),Vector2(180,50),Color("c5c9aa"),1.2,true)
		c.draw_arc(Vector2(180,39),9,0,TAU,26,Color("c5c9aa"),1.2,true)
		c.draw_rect(Rect2(164,193,32,17),Color("b7a06c"))
		c.draw_circle(Vector2(180,200),3,Color("6d664d"))
	for x in [26,312]:c.draw_rect(Rect2(x,4,20,10),Color("b6a16e"))
	c.draw_set_transform(Vector2.ZERO)
