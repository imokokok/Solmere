extends Button
## Individually interactive original stationery silhouettes, not an image of a desk.
const Paper=preload("res://extensions/collage_letter/scripts/letter_paper.gd")
const AssetTexture=preload("res://extensions/collage_letter/scripts/asset_texture.gd")
const TOOLS_PATH="res://extensions/collage_letter/assets/illustrated_office/tool-roll-v2.png"
var tools_art: Texture2D
var kind: String="folio"
var bottle_edition:=0
var caption: String=""
var font: Font
var accent:=Color("788b80")
func _ready() -> void:
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw);button_up.connect(queue_redraw)
func poly(points: Array, color: Color) -> void:draw_colored_polygon(PackedVector2Array(points),color)
func shadow(points: Array, offset: Vector2=Vector2(4,6)) -> void:
	var cast: Array=[]
	for point in points:cast.append(point+offset)
	poly(cast,Color(0.25,0.19,0.13,0.23))
func stitches(a: Vector2,b: Vector2,color: Color) -> void:
	var steps:=maxi(1,int(a.distance_to(b)/7))
	for i in steps:draw_line(a.lerp(b,float(i)/steps),a.lerp(b,(i+0.47)/steps),color,0.8,true)
func _draw() -> void:
	var lift:=Vector2(0,-3 if is_hovered() else 0)
	draw_set_transform(lift)
	var w:=size.x;var h:=size.y
	match kind:
		"folio":
			draw_folio(w,h)
		"tray":
			var tray: Array=[Vector2(4,18),Vector2(w-9,7),Vector2(w,h-12),Vector2(11,h)]
			shadow(tray);poly(tray,Color("927456"))
			poly([Vector2(13,23),Vector2(w-17,16),Vector2(w-10,h-29),Vector2(19,h-16)],Color("685747"))
			for i in 3:
				var at:=Vector2(23+i*4,27-i*6);var extent:=Vector2(w-53,h-46)
				Paper.paint(self,Rect2(at+Vector2(2,3),extent),i+1,false)
				Paper.paint(self,Rect2(at,extent),i+1,false)
				draw_polyline(PackedVector2Array([at+Vector2(1,2),at+Vector2(extent.x/2,extent.y*0.55),at+Vector2(extent.x-1,0)]),Color("b9aa8e"),1,true)
				if i==2:
					draw_line(at+Vector2(17,extent.y-18),at+Vector2(75,extent.y-18),Color("a2a38d"),1,true)
					draw_line(at+Vector2(17,extent.y-12),at+Vector2(56,extent.y-12),Color("b4ad95"),1,true)
			poly([Vector2(4,18),Vector2(13,23),Vector2(19,h-16),Vector2(11,h)],Color("b78f68"))
			poly([Vector2(w-9,7),Vector2(w-17,16),Vector2(w-10,h-29),Vector2(w,h-12)],Color("826347"))
			poly([Vector2(9,h-33),Vector2(w-2,h-42),Vector2(w,h-12),Vector2(11,h)],Color("ab8560"))
			draw_line(Vector2(11,h-32),Vector2(w-3,h-41),Color("d4b28a"),2,true)
			for i in 3:draw_line(Vector2(w*0.51,h-29+i*5),Vector2(w-15,h-33+i*5),Color(0.37,0.27,0.18,0.16),0.8,true)
			label_at(caption,Vector2(29,h-13),15)
		"notebook":
			var cover: Array=[Vector2(9,8),Vector2(w-3,1),Vector2(w-7,h-6),Vector2(6,h)]
			shadow(cover);poly(cover,Color("667b75"))
			for i in 3:
				Paper.paint(self,Rect2(20+i,10+i*2,w-34,h-24),i+1,false)
			Paper.paint(self,Rect2(19,9,w-34,h-28),1,false)
			for y in range(25,int(h)-26,11):draw_line(Vector2(35,y),Vector2(w-31,y-1),Color(0.35,0.38,0.32,0.14),1,true)
			draw_line(Vector2(13,12),Vector2(11,h-9),Color("3f5852"),4,true)
			for y in range(23,int(h)-19,24):
				draw_arc(Vector2(23,y),6,PI*0.56,PI*1.72,14,Color("958569"),1.5,true)
				draw_line(Vector2(22,y-6),Vector2(26,y-6),Color("cfbda0"),1,true)
			poly([Vector2(w-37,h-22),Vector2(w-25,h-23),Vector2(w-25,h+4),Vector2(w-31,h-1),Vector2(w-37,h+5)],Color("bb846b"))
			label_at(caption,Vector2(32,h*0.54),11)
		"bottle_full","bottle_empty":
			draw_set_transform(lift+Vector2(w*0.5,0),0,Vector2(w/114.0,(h-22)/152.0))
			var glass:=PackedVector2Array([Vector2(-13,23),Vector2(13,23),Vector2(14,48),Vector2(34,66),Vector2(38,132),Vector2(31,146),Vector2(-31,146),Vector2(-38,132),Vector2(-34,66),Vector2(-14,48)])
			shadow(Array(glass),Vector2(3,4));poly(Array(glass),Color("95b9aa"))
			if kind=="bottle_full":
				draw_style_box(preload("res://extensions/collage_letter/scripts/journal_style.gd").rounded(Color("e8dbbd"),5),Rect2(-9,55,18,76));draw_line(Vector2(3,60),Vector2(3,123),Color("b8a484"),1,true)
			poly(Array(glass),Color(0.66,0.78,0.69,0.20));var rim:=glass.duplicate();rim.append(glass[0]);draw_polyline(rim,Color("628c7f"),1.4,true)
			if kind=="bottle_full":
				var roll_color:Color=[Color("e4d6b7"),Color("d1d7bf"),Color("dcc7b4")][bottle_edition%3]
				draw_colored_polygon(PackedVector2Array([Vector2(-12,58),Vector2(9,55),Vector2(13,128),Vector2(-8,132)]),roll_color)
				draw_line(Vector2(5,60),Vector2(9,125),Color("b0a17e"),1,true)
				draw_line(Vector2(-9,88),Vector2(11,86),Color("a48662"),2,true)
			draw_line(Vector2(-26,71),Vector2(-24,123),Color("dae5ca"),3,true)
			draw_style_box(preload("res://extensions/collage_letter/scripts/journal_style.gd").rounded(Color("b18b5f"),3),Rect2(-14,8,28,20))
			for i in 5:draw_circle(Vector2(-9+i*4,13+i%2*7),0.9,Color("805f43"))
			draw_set_transform(lift);centered_caption(Vector2(w/2,h-5),13)
		"typewriter":
			preload("res://extensions/collage_letter/scripts/typewriter_art.gd").paint(self,Rect2(lift,Vector2(w,h-12)))
			label_at(caption,Vector2(w*0.38,h-2),15)
		"tools":
			draw_stationery_box(Rect2(0,0,w,h),false)
			centered_caption(Vector2(w*0.5,h*0.55),17)
		"envelope":
			Paper.paint(self,Rect2(6,7,w-12,h-16),2)
			draw_line(Vector2(17,20),Vector2(28,20),Color("9b7453"),1.5,true)
			draw_circle(Vector2(19,20),2.5,Color("715a43"))
			centered_caption(Vector2(w/2,h/2),20)

	draw_set_transform(Vector2.ZERO)
	if has_focus():draw_arc(size/2,minf(w,h)*0.43,0.1,TAU-0.1,32,Color("e9c687"),1.4,true)
func draw_fitted_art(texture: Texture2D,source: Rect2) -> Rect2:
	# Runtime source regions omit transparent padding; the raster files stay intact.
	var extent:=source.size*minf(size.x/source.size.x,size.y/source.size.y)
	var destination:=Rect2((size-extent)*0.5,extent)
	draw_texture_rect_region(texture,destination,source)
	return destination
func centered_caption(center: Vector2,font_size: int) -> void:
	if font:
		var width:=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		label_at(caption,center+Vector2(-width*0.5,font_size*0.34),font_size)
func draw_folio(w: float,h: float) -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(w/366.0,h/520.0))
	var skin:=preload("res://extensions/collage_letter/scripts/journal_style.gd").rounded(Color("809383"),8)
	skin.shadow_color=Color(0.23,0.18,0.12,0.23);skin.shadow_size=5;skin.shadow_offset=Vector2(4,6)
	draw_style_box(skin,Rect2(0,0,366,520))
	for i in range(4,0,-1):
		Paper.paint(self,Rect2(17+i,10+i*1.5,337-i,493),1,false)
	draw_style_box(preload("res://extensions/collage_letter/scripts/journal_style.gd").rounded(Color("809383"),7),Rect2(0,0,361,510))
	draw_rect(Rect2(8,9,22,493),Color("a66f50"))
	draw_line(Vector2(34,15),Vector2(34,495),Color("667b69"),3,true)
	draw_polyline(PackedVector2Array([Vector2(42,14),Vector2(348,14),Vector2(348,496),Vector2(43,496)]),Color("a4b49a"),1.5,true)
	for entry in [["bd886e",139],["73939c",288],["cfb47e",438]]:draw_rect(Rect2(359,entry[1],12,27),Color(entry[0]))
	Paper.paint(self,Rect2(92,113,182,63),1,false)
	if font:draw_string(font,Vector2(135,154),caption,HORIZONTAL_ALIGNMENT_LEFT,170,25,Color("465d50"))
	draw_line(Vector2(172,395),Vector2(199,308),Color("d1d4af"),2,true)
	for i in 4:
		var q:=Vector2(180+i*5,367-i*17)
		poly([q,q+Vector2(-25,-10),q+Vector2(-30,-26),q+Vector2(-9,-20)],Color("c3cba6"))
		poly([q+Vector2(3,-8),q+Vector2(26,-37),q+Vector2(31,-28),q+Vector2(24,-13)],Color("c3cba6"))
	draw_polyline(PackedVector2Array([Vector2(362,265),Vector2(379,289),Vector2(395,331),Vector2(382,316),Vector2(379,289),Vector2(389,361)]),Color("d9ceaf"),5,true)
	draw_set_transform(Vector2.ZERO)
func draw_tool_roll(w: float,h: float) -> void:
	var cloth: Array=[Vector2(2,26),Vector2(w-13,14),Vector2(w-4,h-10),Vector2(10,h)]
	shadow(cloth);poly(cloth,Color("728a80"))
	for i in 11:
		var y:=32+i*(h-48)/11
		draw_line(Vector2(8,y),Vector2(w-12,y-6),Color(0.89,0.88,0.72,0.07),1,true)
	# Individual bristles, metal blade, scissors and glue cap emerge from the pockets.
	var brush_x:=31.0
	draw_line(Vector2(brush_x,52),Vector2(brush_x+4,h-32),Color("ad795a"),9,true)
	poly([Vector2(brush_x-6,27),Vector2(brush_x+6,27),Vector2(brush_x+4,50),Vector2(brush_x-4,50)],Color("bcbba7"))
	for i in 7:draw_line(Vector2(brush_x-5+i*1.6,27),Vector2(brush_x-6+i*1.8,9+absf(i-3)*1.6),Color("685c49"),1.6,true)
	var knife_x:=w*0.38
	draw_line(Vector2(knife_x,62),Vector2(knife_x+3,h-32),Color("686f68"),10,true)
	poly([Vector2(knife_x-5,61),Vector2(knife_x+5,60),Vector2(knife_x+7,25),Vector2(knife_x-3,37)],Color("c6c4b4"))
	draw_line(Vector2(knife_x+5,30),Vector2(knife_x+3,57),Color("ece5cd"),1,true)
	var scissors_x:=w*0.63
	for side in [-1,1]:
		draw_arc(Vector2(scissors_x+side*7,38),8,0,TAU,24,Color("987c5b"),4,true)
		draw_line(Vector2(scissors_x+side*4,48),Vector2(scissors_x-side*8,h*0.58),Color("b9bbb0"),4,true)
	draw_circle(Vector2(scissors_x,67),3,Color("7b7463"))
	var glue_x:=w*0.83
	draw_line(Vector2(glue_x,40),Vector2(glue_x,h-32),Color("ded8bd"),19,true)
	draw_line(Vector2(glue_x,26),Vector2(glue_x,47),Color("bd8c69"),21,true)
	draw_line(Vector2(glue_x-5,31),Vector2(glue_x-5,43),Color("dec1a0"),1.3,true)
	poly([Vector2(9,h*0.50),Vector2(w-6,h*0.48),Vector2(w-4,h-10),Vector2(10,h)],Color("9eae97"))
	draw_line(Vector2(10,h*0.51),Vector2(w-8,h*0.49),Color("c6ccb0"),2,true)
	for i in 4:
		var x:=15+i*(w-22)/4
		stitches(Vector2(x,h*0.54),Vector2(x+4,h-17),Color("688374"))
	stitches(Vector2(17,h-13),Vector2(w-10,h-22),Color("e1d8b4"))
	label_at(caption,Vector2(20,h-25),15)
func label_at(value: String, at: Vector2, font_size: int) -> void:
	if font:draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("484e43"))

func draw_stationery_box(rect:Rect2,opened:bool) -> void:
	preload("res://extensions/collage_letter/scripts/stationery_box.gd").paint(self,rect,opened)
