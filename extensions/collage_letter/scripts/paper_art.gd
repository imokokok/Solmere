extends Node2D
const AssetTexture=preload("res://extensions/collage_letter/scripts/asset_texture.gd")
static var font_bank: Dictionary={}
var kind: int = 0
var sheet_data: Dictionary
var font: Font
var asset_root := "res://extensions/collage_letter/assets/open_pack/"
var art: Texture2D
var illustration: Texture2D
var backing: Texture2D
var photo_region:=Rect2()
var paper_shape:=PackedVector2Array()
var ink := Color("344c50")
func _ready() -> void:
	var image_path: String=str(sheet_data.get("image_path",""))
	if not image_path.is_empty() and FileAccess.file_exists(image_path):
		var photo:=Image.load_from_file(image_path)
		if photo!=null and not photo.is_empty(): art=AssetTexture.from_image(photo,2048)
	if art==null: art=AssetTexture.get_texture(asset_root+sheet_data.asset,0 if sheet_data.kind=="letter" else (2048 if sheet_data.kind=="photo" else 1024))
	if sheet_data.kind=="photo":
		photo_region=Rect2(art.get_image().get_used_rect())
		if photo_region.size.x/photo_region.size.y>3:photo_region=Rect2(Vector2(photo_region.size.x*0.25,0),Vector2(photo_region.size.y*1.5,photo_region.size.y))
	if sheet_data.kind=="letter": texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var variant:=str(sheet_data.get("font_style","print"))
	var locale:=str(sheet_data.get("display_locale","zh"))
	var font_key:=locale+":"+variant
	if font_bank.has(font_key):font=font_bank[font_key]
	else:
		if locale=="en":
			if variant=="handwritten": font=load("res://extensions/collage_letter/assets/fonts/caveat/Caveat[wght].ttf")
			elif variant=="typewriter": font=load("res://extensions/collage_letter/assets/fonts/specialelite/SpecialElite-Regular.ttf")
			elif variant=="serif": font=load("res://extensions/collage_letter/assets/fonts/librebaskerville/LibreBaskerville[wght].ttf")
		elif variant in ["handwritten","serif","typewriter"]:
			var face:=SystemFont.new()
			face.font_names=PackedStringArray(["KaiTi" if variant=="handwritten" else ("FangSong" if variant=="typewriter" else "SimSun"),"Microsoft YaHei"])
			font=face
		font_bank[font_key]=font
	if sheet_data.has("illustration"): illustration=AssetTexture.get_texture(asset_root+sheet_data.illustration)
	if sheet_data.kind in ["score","photo","art"]: backing=AssetTexture.get_texture(asset_root+"paper/Papier6.png")
	queue_redraw()
func text(value: String, at: Vector2, size: int = 18, width: float = 246, color: Color = Color("344c50")) -> void:
	var fitted:=size
	while fitted>8 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted).x>width: fitted-=1
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,fitted,color)
func lines(value: String, at: Vector2, size: int = 15, width: float = 242, max_lines: int = 5) -> void:
	var cursor:=at
	var count:=0
	for paragraph in value.split("\n"):
		var row:=""
		var units:=PackedStringArray()
		if paragraph.to_utf8_buffer().size()==paragraph.length():
			for word in paragraph.split(" "):units.append(word+" ")
		else:
			for character in paragraph:units.append(character)
		for character in units:
			if font.get_string_size(row+character,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
				text(row,cursor,size,width);cursor.y+=size+6;count+=1;row=""
				if count>=max_lines: return
			row+=character
		text(row,cursor,size,width);cursor.y+=size+6;count+=1
		if count>=max_lines: return
func _draw() -> void:
	var type: String=sheet_data.kind

	if type in ["decoration","letter"]:
		var fit:=minf(170.0/art.get_width(),165.0/art.get_height())
		var dimensions:=art.get_size()*fit
		draw_texture_rect(art,Rect2(Vector2(150,119)-dimensions*0.5,dimensions),false)
		return
	var form:=int(sheet_data.get("paper_form",0))
	var dimensions: Vector2=[Vector2(276,216),Vector2(262,193),Vector2(220,216),Vector2(281,161),Vector2(245,200),Vector2(270,175),Vector2(234,213),Vector2(284,201),Vector2(258,208)][form%9]
	draw_set_transform(Vector2(150,120)-dimensions*0.5,0,dimensions/Vector2(276,216))
	draw_set_transform(Vector2(150,120)-dimensions*0.5-Vector2(12,12)*dimensions/Vector2(276,216),0,dimensions/Vector2(276,216))
	var bounds:=Rect2(12,12,276,216)
	var tint:=Color(sheet_data.get("color","#faf2df"))
	if type=="photo":tint=Color("fff9eb")
	var corners: Array=[Vector2(12,12),Vector2(288,12),Vector2(288,228),Vector2(12,228)]
	var random:=RandomNumberGenerator.new();random.seed=int(sheet_data.get("edge_seed",kind*97+31))
	paper_shape.clear()
	var coordinates:=PackedVector2Array()
	for side in 4:
		for step in 28:
			var point: Vector2=corners[side].lerp(corners[(side+1)%4],step/28.0)
			var rough:=0.5 if form==0 else (4.2 if form in [1,4,6] else 1.8)
			point+=Vector2(random.randf_range(-rough,rough),random.randf_range(-rough,rough))
			if form==3 and side%2==1: point.x+=sin(step*PI/2)*3.3
			paper_shape.append(point);coordinates.append((point-Vector2(12,12))/Vector2(276,216))
	if type=="paper" and sheet_data.has("paper_style"):
		preload("res://extensions/collage_letter/scripts/letter_paper.gd").paint(self,bounds,int(sheet_data.paper_style),false)
		paper_pattern(str(sheet_data.pattern));return
	draw_colored_polygon(paper_shape,tint)
	draw_polygon(paper_shape,PackedColorArray([Color(tint,0.16 if type=="photo" else float(sheet_data.get("texture_strength",0.75)))]),coordinates,backing if backing else art)
	var edge:=paper_shape.duplicate();edge.append(edge[0]);draw_polyline(edge,Color(0.95,0.88,0.72,0.6),1.2,true)
	if type in ["art","photo"]:
		var region:=photo_region if type=="photo" else Rect2(Vector2.ZERO,art.get_size())
		var art_dimensions:=region.size*minf(250.0/region.size.x,179.0/region.size.y)
		draw_texture_rect_region(art,Rect2(Vector2(150,111)-art_dimensions*0.5,art_dimensions),region)
		text(sheet_data.title,Vector2(24,218),10,248)
		return
	match type:
		"paper": paper_pattern(str(sheet_data.pattern))
		"advert": advert()
		"score":
			var region: Array=sheet_data.get("scan_region",[0.06,0.08,0.88,0.8])
			draw_texture_rect_region(art,Rect2(23,23,254,190),Rect2(Vector2(region[0],region[1])*art.get_size(),Vector2(region[2],minf(region[3],0.98-region[1]))*art.get_size()),Color("e8d6af"))
			if backing: draw_texture_rect(backing,Rect2(23,23,254,190),false,Color(1,0.95,0.85,0.12))
		"ticket": ticket()
		_: printed()
func paper_pattern(pattern: String) -> void:
	var faint:=Color(0.24,0.43,0.45,0.28)
	if pattern in ["grid","ruled","margin"]:
		for y in range(30,217,18): draw_line(Vector2(20,y),Vector2(280,y),faint)
		if pattern=="grid":
			for x in range(30,281,18): draw_line(Vector2(x,20),Vector2(x,221),faint)
		if pattern=="margin": draw_line(Vector2(56,18),Vector2(56,222),Color(0.65,0.26,0.22,0.4),1.5)
	elif pattern=="dot":
		for x in range(30,281,18):
			for y in range(30,217,18): draw_circle(Vector2(x,y),1,faint)
	elif pattern=="postal":
		for x in range(20,270,24):
			for y in [19,219]: draw_line(Vector2(x,y),Vector2(x+12,y),Color("a76d5b") if x%48==20 else Color("618387"),4)
	elif pattern=="diagonal":
		for x in range(18,270,14): draw_line(Vector2(x,220),Vector2(mini(x+80,280),maxi(20,220-(280-x)*2)),faint)
	elif pattern=="scallop":
		for x in range(30,276,24):
			for y in [24,216]: draw_arc(Vector2(x,y),10,0,PI,16,faint,1,true)
func advert() -> void:
	var accent:=Color(sheet_data.get("accent","#a85740"))
	var layout:=int(sheet_data.get("layout",0))
	text(str(sheet_data.brand),Vector2(27,39),16,246,accent)
	if layout==0:
		draw_rect(Rect2(24,48,252,48),accent)
		text(str(sheet_data.headline),Vector2(33,79),24,234,Color("fff6df"))
		lines(str(sheet_data.body),Vector2(29,121),17,240,3)
		text(str(sheet_data.badge),Vector2(29,193),18,240,accent)
	elif layout==1:
		draw_rect(Rect2(22,47,256,147),accent,false,2)
		text(str(sheet_data.headline),Vector2(32,78),23,236,accent)
		text(str(sheet_data.badge),Vector2(32,110),25,236,accent)
		lines(str(sheet_data.body),Vector2(32,139),14,234,3)
		for x in range(27,276,12): draw_circle(Vector2(x,200),1.4,accent)
	elif layout==2:
		draw_line(Vector2(26,52),Vector2(274,52),accent,3)
		text(str(sheet_data.headline),Vector2(27,84),24,246,accent)
		lines(str(sheet_data.body),Vector2(29,115),16,239,3)
		draw_rect(Rect2(25,175,250,26),Color(accent,0.13))
		text(str(sheet_data.badge),Vector2(32,194),17,235,accent)
	else:
		draw_rect(Rect2(24,50,70,145),accent)
		lines(str(sheet_data.body),Vector2(105,104),15,164,4)
		text(str(sheet_data.headline),Vector2(104,75),22,169,accent)
		text(str(sheet_data.badge),Vector2(104,187),19,169,accent)
		if illustration: draw_texture_rect(illustration,Rect2(32,88,55,55),false,Color("f4e2bb"))
	text(str(sheet_data.footer),Vector2(27,218),10,246,accent)
func printed() -> void:
	if sheet_data.get("classic",false):
		text(str(sheet_data.headline),Vector2(28,39),12,242)
		var english:bool=str(sheet_data.body).to_utf8_buffer().size()<str(sheet_data.body).length()*1.4
		lines(str(sheet_data.body),Vector2(28,77),23 if english else 26,243,5)
		text(str(sheet_data.footer),Vector2(28,218),11,242,Color("746750"))
		return
	var layout:=int(sheet_data.get("layout",0))%6
	text(str(sheet_data.headline),Vector2(28,45),19,242)
	if layout==1 or layout==5:
		# Handwritten fragments have quiet, imperfect ruling, without a ticket border.
		for y in range(76,205,23):draw_line(Vector2(28,y),Vector2(273,y+0.5),Color(ink,0.08),0.7)
	elif layout==2:
		draw_line(Vector2(28,54),Vector2(271,54),Color(ink,0.48),1)
		draw_line(Vector2(28,57),Vector2(271,57),Color(ink,0.2),0.6)
	elif layout==3:draw_line(Vector2(27,68),Vector2(27,193),Color("a89076"),2,true)
	var inset:=39.0 if layout==3 else 28.0
	fit_body(str(sheet_data.body),Vector2(inset,76),15,270-inset,125)
	text(str(sheet_data.get("footer","")),Vector2(28,217),9,242,Color("84755f"))
func ticket() -> void:
	var layout:=int(sheet_data.get("ticket_style",0))%8
	var accent:=Color("8b5745") if layout%2 else ink
	text(str(sheet_data.get("brand","SOLMERE")),Vector2(28,33),11,240,accent)
	if layout in [0,4,7]:
		draw_rect(Rect2(23,41,254,25),Color(accent,0.12))
		for y in range(23,223,8):draw_line(Vector2(279,y),Vector2(279,y+3),Color(accent,0.35),1)
	elif layout in [1,5]:
		draw_rect(Rect2(22,20,256,201),Color(accent,0.4),false,0.8)
	elif layout==6:
		for y in range(72,196,19):draw_line(Vector2(25,y),Vector2(275,y),Color(accent,0.13),0.7)
	text(str(sheet_data.headline),Vector2(28,60),19,242,accent)
	fit_body(str(sheet_data.body),Vector2(28,84),13,243,109)
	for x in range(24,278,9):draw_line(Vector2(x,200),Vector2(x+4,200),Color(accent,0.5),0.8)
	text(str(sheet_data.get("footer","")),Vector2(27,216),9,183,accent)
	if layout in [2,3]:
		for n in 20:draw_line(Vector2(204+n*3.3,205),Vector2(204+n*3.3,220),Color(accent,0.7),1 if n%3 else 2)
	else:text("%04d"%(kind+1),Vector2(224,217),12,50,accent)
func fit_body(value: String, at: Vector2, font_size: int, width: float, height: float) -> void:
	var fitted:=font_size
	while fitted>8 and body_rows(value,fitted,width)*(fitted+6)>height:fitted-=1
	lines(value,at,fitted,width,ceili(height/(fitted+6)))
func body_rows(value: String, font_size: int, width: float) -> int:
	var rows:=0
	for paragraph in value.split("\n"):
		var row:=""
		var units:=paragraph.split(" ") if paragraph.to_utf8_buffer().size()==paragraph.length() else paragraph.split("")
		var separator: String=" " if paragraph.to_utf8_buffer().size()==paragraph.length() else ""
		for unit in units:
			var next: String=unit+separator
			if font.get_string_size(row+next,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width:rows+=1;row=""
			row+=next
		rows+=1
	return rows
