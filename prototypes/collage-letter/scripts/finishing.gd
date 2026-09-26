extends RefCounted
# One finishing controller owns hit tests, persistent physical state and draw order.
const L=preload("res://scripts/localization.gd")
var g: Node2D
var paper_atlas: Texture2D=preload("res://assets/open_pack/stationery/painted-papers.png")
var envelope_fibre: Texture2D=preload("res://assets/open_pack/paper/Papier13.png")
var botanical_mark: Texture2D=preload("res://assets/open_pack/icons/tree.svg")
var letter_pos:=Vector2(720,290)
var inserted:=false
var flap:=0.0
var phase:="MATCH"
var drag:=""
var pointer:=Vector2.ZERO
var previous:=Vector2.ZERO
var match_pos:=Vector2(280,690)
var match_lit:=false
var match_life:=0.0
var strike:=0.0
var candle:=false
var pellets:=false
var spoon:=Vector2(355,380)
var heat:=0.0
var pour:=0.0
var pool:=Vector2(720,525)
var pour_good:=false
var pour_committed:=false
var stamp:=Vector2(1160,490)
var press_time:=0.0
var impressed:=false
var impression_good:=false
var cool:=0.0
var mailbox:=0.0
var mailed:=0.0
var mail_pos:=Vector2(475,535)
var mail_start:=Vector2.ZERO
var delivery_ready:=false
var closing:=false
var time:=0.0
const SEAM=Vector2(720,525)
const WICK=Vector2(160,461)
const BOX=Rect2(104,685,133,28)
const MOUTH=Rect2(944,388,282,94)
func _init(host: Node2D) -> void: g=host
func active() -> bool: return g.stage in ["ENVELOPE","WAX_SEAL","SEND"]
func hint() -> String:
	if g.stage=="ENVELOPE":
		return "把折好的信放进信封，轻轻送入一半就好。" if not inserted else "拖住上方三角翻盖，向下拉到封口。"
	if g.stage=="SEND":
		if closing: return "正在关上信箱，交给邮差。"
		if mailed>=1: return "信已放进信箱。将打开的箱盖向下拉，完成投递。"
		return "先点击封好的信打开信箱，再将信拖进右侧投信口。" if mailbox<0.9 else "信箱已打开。将整封信拖进右侧投信口。"
	match phase:
		"MATCH": return "拖起火柴，在火柴盒侧面划过，再把火苗移到烛芯。"
		"PELLETS": return "拖一份蜡粒到小勺的凹槽里。"
		"MELT": return "将勺子放在烛火上方，让蜡粒完全融化。"
		"POUR": return "把融蜡勺移到封口圆标上方后松手。倒下的蜡无法收回。"
		"POURING": return "正在倾倒。蜡迹会永久留在落下的位置。"
		"STAMP": return "拖起印章，将底座压在蜡上，按住至少一秒再松开。" if pour_good else "蜡倒偏了，痕迹会保留。仍可盖章并寄出这封信。"
		_: return "等待火漆冷却。印记已定型，不能重盖。"
func say() -> void: g.say(hint())
func mouse_move(p: Vector2) -> void:
	previous=pointer;pointer=p
	match drag:
		"letter":
			letter_pos=p.clamp(Vector2(535,265),Vector2(905,665))
			if absf(letter_pos.x-720)<90 and letter_pos.y>365: letter_pos.x=lerpf(letter_pos.x,720,0.5)
		"flap": flap=clampf((p.y-270)/255.0,0,1)
		"match":
			match_pos=p
			if BOX.grow(9).has_point(p):
				strike+=absf(p.x-previous.x)
				if strike>65 and not match_lit:
					match_lit=true;match_life=24;g.audio.play("MATCH_STRIKE")
			elif not match_lit: strike=0
			if match_lit and p.distance_to(WICK)<34:
				candle=true;phase="PELLETS";g.audio.play("FIRE_LOOP");say()
		"spoon": spoon=p.clamp(Vector2(75,210),Vector2(1250,750))
		"stamp": stamp=p.clamp(Vector2(400,270),Vector2(1240,730))
		"mail": mail_pos=p.clamp(Vector2(250,270),Vector2(1250,690))
		"lid": mailbox=1-clampf((p.y-305)/160.0,0,1)
	g.queue_redraw()
func input(p: Vector2, down: bool) -> void:
	pointer=p;previous=p
	if g.stage=="ENVELOPE":
		if down:
			if not inserted and Rect2(letter_pos-Vector2(150,65),Vector2(300,130)).has_point(p): drag="letter"
			elif inserted and p.distance_to(Vector2(720,270+flap*255))<125: drag="flap"
		else:
			if drag=="letter":
				inserted=absf(letter_pos.x-720)<80 and letter_pos.y>=535
				if inserted: g.envelope_inserted=true;g.audio.play("ENVELOPE_INSERT")
			elif drag=="flap" and flap>=0.94:
				flap=1;g.stage="WAX_SEAL";g.flap_visual=1;g.audio.play("ENVELOPE_CLOSE");g.build_ui()
			drag="";say();g.changed()
	elif g.stage=="WAX_SEAL": wax_input(p,down)
	elif g.stage=="SEND": mail_input(p,down)
func wax_input(p: Vector2, down: bool) -> void:
	if phase in ["POURING","COOL"]: return
	if down:
		if phase=="MATCH" and (p.distance_to(match_pos)<65 or BOX.has_point(p)):
			drag="match";match_pos=p;strike=0
		elif phase=="PELLETS" and p.distance_to(Vector2(310,600))<58: drag="pellets"
		elif phase in ["MELT","POUR"] and (p.distance_to(spoon)<56 or p.distance_to(spoon+Vector2(65,-24))<48): drag="spoon"
		elif phase=="STAMP" and (p.distance_to(stamp)<65 or p.distance_to(stamp-Vector2(0,65))<55): drag="stamp";press_time=0
	else:
		if drag=="match":
			match_pos=Vector2(280,690)
			if candle: match_lit=false
		elif drag=="pellets" and p.distance_to(spoon)<39:
			pellets=true;phase="MELT";g.audio.play("PAPER_PRESS")
		elif drag=="spoon" and phase=="POUR" and p.x>440 and p.y>350:
			pool=p+Vector2(0,55);pour=0;pour_committed=true
			pour_good=pool.distance_to(SEAM)<=25 and heat>=0.95
			phase="POURING";g.audio.play("WAX_POUR")
		elif drag=="stamp":
			if stamp.distance_to(pool)<52:
				impressed=true;impression_good=pour_good and press_time>=1.0 and stamp.distance_to(pool)<=23
				phase="COOL";cool=0;g.audio.play("STAMP_RELEASE")
			stamp=Vector2(1160,490)
		drag="";say();g.changed()
func mail_input(p: Vector2, down: bool) -> void:
	if closing or (mailed>0 and mailed<1): return
	if down:
		if mailed==0 and Rect2(mail_pos-Vector2(165,112),Vector2(330,200)).has_point(p):
			if mailbox<0.9: mailbox=1;say();g.audio.play("ENVELOPE_CLOSE")
			else: drag="mail"
		elif mailed>=1 and Rect2(920,245,330,260).has_point(p):
			if mailbox<0.1: mailbox=1;say()
			else: drag="lid"
	else:
		if drag=="mail" and MOUTH.grow(35).has_point(p):
			mail_start=mail_pos;mailed=0.001;g.audio.play("ENVELOPE_INSERT")
		elif drag=="lid" and mailbox<0.15:
			closing=true;delivery_ready=true;mailbox=0;g.audio.play("MAIL_DROP")
			g.send_letter()
			delivery_ready=false;closing=false
		drag="";say();g.changed()
func tick(delta: float) -> void:
	time+=delta
	if not active(): return
	if inserted and g.stage=="ENVELOPE":letter_pos=letter_pos.lerp(Vector2(720,650),1-exp(-delta*8))
	if phase in ["STAMP","COOL"]:spoon=spoon.lerp(Vector2(340,380),1-exp(-delta*5))
	if match_lit:
		match_life-=delta
		if match_life<=0: match_lit=false
	if phase=="MELT" and candle and spoon.distance_to(WICK-Vector2(0,40))<52:
		heat=minf(1,heat+delta/3.2)
		if heat>=1: phase="POUR";say();g.changed()
	if phase=="POURING":
		pour=minf(1,pour+delta/1.15)
		if pour>=1: phase="STAMP";pellets=false;say();g.changed()
	if phase=="STAMP" and drag=="stamp":
		if stamp.distance_to(pool)<23: press_time+=delta
		else: press_time=0
	if phase=="COOL":
		cool+=delta
		if cool>=1.8 and g.stage=="WAX_SEAL": g.stage="SEND";g.build_ui();say();g.changed()
	if mailed>0 and mailed<1:
		mailed=minf(1,mailed+delta/0.85)
		mail_pos=mail_start.lerp(Vector2(1080,565),smoothstep(0,1,mailed))
		if mailed>=1: say();g.changed()
func serialize() -> Dictionary:
	var state: Dictionary={}
	for key in ["inserted","flap","phase","candle","pellets","heat","pour","pool","pour_good","pour_committed","impressed","impression_good","cool","mailbox","mailed","letter_pos","spoon","mail_pos"]:
		var value=get(key)
		state[key]=[value.x,value.y] if value is Vector2 else value
	return state
func restore(state: Dictionary) -> void:
	for key in state:
		if key not in serialize(): continue
		var value=state[key]
		set(key,Vector2(value[0],value[1]) if value is Array else value)
	if mailed>0 and mailed<1: mail_start=mail_pos
	if g.stage=="ENVELOPE" and inserted: letter_pos=Vector2(720,650)
func ellipse(center: Vector2, radius: Vector2, color: Color) -> void: g.draw_ellipse_custom(center,radius,color)
func poly(points: Array, color: String) -> void: g.painted_polygon(PackedVector2Array(points),Color(color),0.22)
func flame(at: Vector2, scale: float = 1.0) -> void:
	var sway:=sin(time*7.3)*4+sin(time*13)*2
	for layer in 3:
		var factor: float=[1.0,0.65,0.34][layer]*scale*(0.97+sin(time*5.8+layer)*.055)
		var points:=PackedVector2Array()
		for i in 25:
			var a:=TAU*i/24.0
			var y:=cos(a)
			points.append(at+Vector2(sin(a)*11*(1-y*0.55)+sway*(y+1)*0.4,-20-y*24)*factor)
		g.draw_colored_polygon(points,[Color("df873b"),Color("ffc963"),Color("fff2b3")][layer])
	ellipse(at+Vector2(0,-13)*scale,Vector2(28,34)*scale,Color(1,0.65,0.19,0.035))
func bead(at: Vector2, size: float = 1.0, seed_value: int = 0) -> void:
	var points:=PackedVector2Array()
	for i in 7:
		var angle:=TAU*i/7+seed_value*0.21
		points.append(at+Vector2(cos(angle)*9,sin(angle)*6)*size)
	g.draw_colored_polygon(points,Color("893d35"))
	ellipse(at+Vector2(-1,-2)*size,Vector2(6,3)*size,Color("b6634a"))
	g.draw_line(at+Vector2(-4,-3)*size,at+Vector2(1,-4)*size,Color("d18d6a"),1.2)
func candle_art() -> void:
	ellipse(Vector2(165,632),Vector2(57,14),Color(0.2,0.15,0.1,0.18))
	ellipse(Vector2(160,625),Vector2(51,12),Color("495f55"))
	ellipse(Vector2(160,610),Vector2(42,10),Color("b89b68"))
	g.painted_polygon(soft_contour(PackedVector2Array([Vector2(130,481),Vector2(158,477),Vector2(191,482),Vector2(190,542),Vector2(188,601),Vector2(164,608),Vector2(133,603),Vector2(131,536)])),Color("ddc9a0"),0.24)
	g.draw_rect(Rect2(136,482,12,122),Color("f4e3bf"))
	g.draw_rect(Rect2(179,482,7,121),Color("bba47c"))
	ellipse(Vector2(160,603),Vector2(27,7),Color("ddc9a0"))
	ellipse(Vector2(160,480),Vector2(31,10),Color("f8e7c4"))
	ellipse(Vector2(160,479),Vector2(16,5),Color("b4a081"))
	for n in 3:
		g.draw_line(Vector2(139+n*16,483),Vector2(139+n*16,501+n*9),Color("f4e3bf"),5,true)
	g.draw_line(Vector2(160,480),WICK,Color("50453a"),3,true)
	poly([Vector2(116,576),Vector2(122,619),Vector2(143,628),Vector2(180,628),Vector2(199,617),Vector2(205,575)],"708575")
	ellipse(Vector2(160,576),Vector2(44,10),Color("acb59a"))
	ellipse(Vector2(160,575),Vector2(35,6),Color("d7c397"))
	g.draw_arc(Vector2(211,594),17,-PI*.5,PI*.5,24,Color("aab394"),5,true)
	g.draw_line(Vector2(128,587),Vector2(131,612),Color("96a28a"),3,true)
	if candle: flame(WICK)
func stamp_art(at: Vector2) -> void:
	ellipse(at+Vector2(6,9),Vector2(41,12),Color(0.2,0.15,0.1,0.15))
	g.draw_rect(Rect2(at-Vector2(33,8),Vector2(66,16)),Color("9f7a40"))
	ellipse(at+Vector2(0,8),Vector2(33,10),Color("9e753c"))
	ellipse(at-Vector2(0,8),Vector2(33,10),Color("d6b36e"))
	var outline:=PackedVector2Array()
	var levels: Array=[[-13,-14],[-10,-40],[-20,-58],[-24,-80],[-18,-99],[0,-106],[18,-99],[24,-80],[20,-58],[10,-40],[13,-14]]
	for v in levels: outline.append(at+Vector2(v[0],v[1]))
	outline=soft_contour(outline)
	g.painted_polygon(outline,Color("825b43"),0.34)
	g.draw_polyline(outline,Color("634531"),1.5,true)
	for offset in [-6,1,7]:
		var grain:=PackedVector2Array()
		for y in range(-94,-22,4):grain.append(at+Vector2(offset+sin(y*0.06)*3,y))
		g.draw_polyline(grain,Color(0.36,0.23,0.15,0.23),1.2,true)
	g.draw_polyline(PackedVector2Array([at+Vector2(-11,-20),at+Vector2(-6,-43),at+Vector2(-15,-65),at+Vector2(-16,-85),at+Vector2(-9,-95)]),Color("a97850"),4,true)
	ellipse(at-Vector2(0,15),Vector2(15,4),Color("b3935a"))
func wax_art() -> void:
	if not pour_committed: return
	var amount:=maxf(0.06,pour)
	var radius:=33*sqrt(amount)
	var points:=PackedVector2Array()
	for i in 49:
		var a:=TAU*i/48
		var r:=radius*(1+0.08*sin(a*5)+0.05*sin(a*9+pool.x))
		points.append(pool+Vector2(cos(a)*r,sin(a)*r*0.8))
	var shadow:=PackedVector2Array()
	for point in points: shadow.append(point+Vector2(1,3))
	g.draw_colored_polygon(shadow,Color("6f352e"))
	g.draw_colored_polygon(points,Color("a55140") if cool<1.8 else Color("914335"))
	g.draw_arc(pool,radius*0.78,3.5,5.5,24,Color("d5906a"),2,true)
	if impressed:
		if impression_good:
			g.draw_arc(pool,23,0,TAU,48,Color("d49975"),1.5,true)
			for n in 3: g.draw_arc(pool+Vector2((n-1)*10,0),6,PI,TAU,15,Color("dfaa81"),2,true)
		else:
			g.draw_arc(pool+Vector2(10,4),23,0.4,4.0,28,Color("c48260"),2,true)
			g.draw_line(pool-Vector2(18,9),pool+Vector2(14,15),Color("6b342a"),2)
func envelope(at: Vector2 = Vector2(720,545), scale: float = 1.0, show_letter: bool = false) -> void:
	g.draw_set_transform(at-Vector2(720,545)*scale,0,Vector2.ONE*scale)
	g.paper(Rect2(500,430,440,245),Color("cbc5b6"))
	if flap<=0:
		envelope_paper([Vector2(500,430),Vector2(940,430),Vector2(720,270+flap*255)],"e6e3d6")
		g.draw_line(Vector2(505,431),Vector2(720,274+flap*250),Color("b19a73"),1.5)
	g.draw_rect(Rect2(510,431,420,213),Color("e3cfa8") if flap>=0.95 else Color("ae9879"))
	if show_letter:
		var visible_height:=minf(130,665-(letter_pos.y-65))
		g.paper(Rect2(letter_pos-Vector2(150,65),Vector2(300,maxf(0,visible_height))),Color("f5eddc"))
		if g.letter_preview:
			g.draw_texture_rect_region(g.letter_preview,Rect2(letter_pos-Vector2(143,58),Vector2(286,maxf(0,minf(116,visible_height-7)))),Rect2(Vector2.ZERO,Vector2(g.letter_preview.get_size())*Vector2(1,0.333*minf(1,(visible_height-7)/116))))
		if letter_pos.y-45<665: g.draw_line(letter_pos+Vector2(-144,-45),letter_pos+Vector2(144,-45),Color("d8ccb1"))
	# Front pocket occludes the letter continuously as it crosses the opening.
	envelope_paper([Vector2(500,430),Vector2(720,575),Vector2(940,430),Vector2(940,675),Vector2(500,675)],"dedbcf")
	envelope_paper([Vector2(500,675),Vector2(720,511),Vector2(940,675)],"edeadd")
	g.draw_line(Vector2(503,672),Vector2(720,513),Color("c3ac86"),1.4)
	g.draw_line(Vector2(937,672),Vector2(720,513),Color("c3ac86"),1.4)
	if flap>0:
		envelope_paper([Vector2(500,430),Vector2(940,430),Vector2(720,270+flap*255)],"e8e5d8")
		g.draw_line(Vector2(500,430),Vector2(720,270+flap*255),Color("b8a07d"),1.4)
		g.draw_line(Vector2(940,430),Vector2(720,270+flap*255),Color("b8a07d"),1.4)
	if flap>0.8:
		g.draw_texture_rect(botanical_mark,Rect2(704,452,32,43),false,Color(0.26,0.31,0.25,clampf((flap-0.8)*5,0,0.8)))
	if Rect2(500,430,440,245).has_point(pool): wax_art()
	g.draw_set_transform(Vector2.ZERO)
func envelope_paper(vertices: Array, color: String) -> void:
	var points:=PackedVector2Array(vertices);var coords:=PackedVector2Array()
	for point in points:coords.append((point-Vector2(500,270))/Vector2(440,405))
	g.draw_colored_polygon(points,Color(color));g.draw_polygon(points,PackedColorArray([Color(1,1,1,0.48)]),coords,envelope_fibre)
	var edge:=points.duplicate();edge.append(points[0]);g.draw_polyline(edge,Color(0.99,0.98,0.92,0.65),1.2,true)
func draw() -> void:
	if g.stage=="ENVELOPE": envelope(Vector2(720,545),1,true)
	elif g.stage=="WAX_SEAL":
		envelope()
		if not Rect2(500,430,440,245).has_point(pool): wax_art()
		candle_art()
		# Matchbox: lid, drawer and rough striking surface are separate visible layers.
		g.paper(Rect2(99,658,145,57),Color("c38c5f"))
		g.draw_rect(Rect2(106,651,132,38),Color("e9d4a6"))
		g.draw_rect(BOX,Color("725b48"))
		for x in range(110,232,6): g.draw_line(Vector2(x,690),Vector2(x+3,706),Color("a58a67"),1)
		g.text_at("火柴盒",Vector2(131,678),15)
		var mp:=match_pos
		g.draw_line(mp+Vector2(51,20),mp,Color("b9a079"),5,true)
		g.draw_circle(mp,5,Color("9c4b39"))
		if match_lit: flame(mp,0.65)
		# Wax pellets have bevelled, irregular silhouettes rather than placeholder dots.
		g.paper(Rect2(268,568,89,66),Color("b9a383"))
		for n in 9: bead(Vector2(282+n%3*26,582+n/3*16),0.9,n)
		g.text_at("蜡粒",Vector2(284,659),17)
		if drag=="pellets":
			for n in 5: bead(pointer+Vector2((n%3-1)*13,(n/3)*11),0.8,n)
		g.draw_line(spoon+Vector2(19,-3),spoon+Vector2(105,-38),Color("696763"),12,true)
		g.draw_line(spoon+Vector2(22,-6),spoon+Vector2(104,-41),Color("c2b9a3"),3,true)
		ellipse(spoon+Vector2(0,3),Vector2(40,24),Color("6b6861"))
		ellipse(spoon,Vector2(39,22),Color("c1b9a7"))
		ellipse(spoon-Vector2(0,2),Vector2(31,16),Color("615d55"))
		if pellets:
			ellipse(spoon-Vector2(0,1),Vector2(27,13),Color("a65343"))
			for n in 6: bead(spoon+Vector2((n%3-1)*15,(n/3)*9-6),maxf(0.05,0.8*(1-heat)),n)
		# Front rim stays in front of the wax; the bowl never disappears under it.
		var rim:=PackedVector2Array()
		for i in 25:rim.append(spoon+Vector2(cos(PI*i/24.0)*36,sin(PI*i/24.0)*19+2))
		g.draw_polyline(rim,Color("b9ab8d"),3,true)
		if phase=="POURING": g.draw_line(spoon+Vector2(0,8),pool,Color("b96649"),3+sin(pour*PI)*3,true)
		if phase=="POUR": g.draw_arc(SEAM,25,0,TAU,48,Color(0.55,0.32,0.2,0.45),1,true)
		stamp_art(stamp)
		g.text_at("火漆印章",Vector2(1098,543),18)
		if phase=="MELT" or (phase=="STAMP" and drag=="stamp"):
			g.draw_rect(Rect2(528,742,385,6),Color("b5aa93"))
			g.draw_rect(Rect2(528,742,385*(heat if phase=="MELT" else minf(1,press_time)),6),Color("a65343"))

	elif g.stage=="SEND": draw_mailbox()
	var hint_skin:=preload("res://scripts/journal_style.gd").rounded(Color("efe3c8"),7)
	g.draw_style_box(hint_skin,Rect2(345,184,750,60))
	g.draw_string(g.font,Vector2(368,221),g.L.t(hint()),HORIZONTAL_ALIGNMENT_LEFT,708,17,Color("403f32"))
func draw_mailbox() -> void:
	# Back, letter, then front lip. The envelope and attached wax share one transform.
	ellipse(Vector2(1090,700),Vector2(190,22),Color(0.2,0.17,0.12,0.19))
	poly([Vector2(911,374),Vector2(1252,374),Vector2(1280,397),Vector2(1280,675),Vector2(1250,693),Vector2(911,687)],"334f50")
	g.draw_style_box(preload("res://scripts/journal_style.gd").rounded(Color("456466"),12),Rect2(915,376,335,310))
	g.draw_rect(Rect2(940,394,285,193),Color("263f42"))
	var lid_y:=376-mailbox*120
	poly([Vector2(915,376),Vector2(1250,376),Vector2(1235,lid_y),Vector2(930,lid_y)],"6e8d88")
	g.draw_line(Vector2(930,lid_y),Vector2(1235,lid_y),Color("b3beb0"),3,true)
	if mailed<1: envelope(mail_pos,lerpf(0.68,0.48,mailed))
	g.draw_rect(Rect2(915,480,335,206),Color("4c6c6b"))
	g.draw_rect(Rect2(921,482,323,9),Color("91a59a"))
	g.draw_rect(Rect2(970,555,222,72),Color("ddd2b9"))
	g.text_at("海岸邮局",Vector2(987,598),19)
	if mailbox<0.01:
		g.draw_rect(Rect2(915,376,335,112),Color("6e8d88"))
		g.draw_line(Vector2(950,430),Vector2(1217,430),Color("304d50"),8,true)
		g.draw_circle(Vector2(1080,462),7,Color("ba9a62"))
	g.draw_line(Vector2(929,501),Vector2(929,670),Color("8fa298"),2,true)
	for x in [935,1228]:
		for y in [507,665]:g.draw_circle(Vector2(x,y),3,Color("a2af9c"))
	g.draw_rect(Rect2(1037,638,88,26),Color("355452"))
	g.draw_circle(Vector2(1080,652),4,Color("b5a174"))
	g.text_at("SOLMERE · POST",Vector2(987,730),17)

func soft_contour(points: PackedVector2Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for i in points.size():
		var a:=points[posmod(i-1,points.size())];var b:=points[i]
		var c:=points[(i+1)%points.size()];var d:=points[(i+2)%points.size()]
		for step in 6:
			var t:=step/6.0
			result.append(0.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
	result.append(result[0])
	return result
