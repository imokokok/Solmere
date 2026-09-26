extends RefCounted
## A physical, resumable bottle ritual. Network publication happens only after sealing.
var g
var phase: String="ROLL"
var roll: float=0
var roll_at:=Vector2(490,420)
var cork_at:=Vector2(1000,329)
var bottle_at:=Vector2(1000,530)
var drag: String=""
var drag_offset:=Vector2.ZERO
var started_above_mouth:=false
var insertion: float=0
var time: float=0
var drift: float=0
var wave_clock:=0.0
var splash:=0.0
const SHEET=Rect2(350,270,280,396)
const MOUTH=Vector2(1000,350)
const FIBRE=preload("res://assets/open_pack/paper/Papier13.png")
func _init(game) -> void:g=game
func t(zh: String,en: String) -> String:return zh if g.L.language=="zh" else en
func hint() -> String:
	match phase:
		"ROLL":return t("从信纸下沿向上慢慢卷起。", "Gently roll the letter upward from its lower edge.")
		"UNCORK":return t("握住软木塞，向上拔出，放在旁边。", "Gently pull the cork upward and set it aside.")
		"INSERT":return t("把纸卷移到瓶口上方，再慢慢向下放入。", "Hold the rolled letter above the mouth, then lower it inside.")
		"CORK":return t("把软木塞放回瓶口，向下按紧。", "Return the cork to the mouth and press it down.")
		"SEA":return t("瓶子封好了。把它轻轻放到右侧的海水里。", "It is sealed. Gently place the bottle in the water to the right.")
		"WAIT":return t("让这一封信，慢慢抵达某个人。", "Let this letter find its way to someone, in its own time.")
	return ""
func tick(dt: float) -> void:
	time+=dt
	if phase in ["SEA","WAIT"]:
		wave_clock-=dt
		if wave_clock<=0:wave_clock=4.0;g.audio.play("SEA_WAVE",0.35)
	if phase=="WAIT":splash+=dt
	if phase=="WAIT":drift=minf(1,drift+dt*0.28)
func input(at: Vector2, down: bool) -> void:
	if g.busy:return
	if down:
		if phase=="ROLL" and Rect2(SHEET.position.x,SHEET.end.y-60-roll*SHEET.size.y,SHEET.size.x,90).has_point(at):drag="roll"
		elif phase=="UNCORK" and Rect2(cork_at-Vector2(30,29),Vector2(60,58)).has_point(at):drag="cork";drag_offset=cork_at-at
		elif phase=="INSERT" and Rect2(roll_at-Vector2(35,147),Vector2(70,294)).has_point(at):drag="letter";drag_offset=roll_at-at
		elif phase=="CORK" and Rect2(cork_at-Vector2(30,29),Vector2(60,58)).has_point(at):drag="cork";drag_offset=cork_at-at
		elif phase=="SEA" and Rect2(bottle_at-Vector2(78,235),Vector2(156,425)).has_point(at):drag="bottle";drag_offset=bottle_at-at
		if not drag.is_empty():g.audio.play("PAPER_MOVE",0.3)
		return
	move(at)
	if drag=="roll":
		if roll>=0.94:roll=1;phase="UNCORK";g.audio.play("PAPER_FOLD",0.45)
	elif drag=="cork" and phase=="UNCORK":
		if cork_at.y<270:phase="INSERT";g.audio.play("CORK_OPEN",0.35)
		else:cork_at=Vector2(1000,329)
	elif drag=="letter" and phase=="INSERT":
		if insertion>=0.98:roll_at=Vector2(1000,558);phase="CORK";g.audio.play("PAPER_MOVE",0.3)
	elif drag=="cork" and phase=="CORK":
		if cork_at.distance_to(Vector2(1000,329))<32:cork_at=Vector2(1000,329);phase="SEA";g.audio.play("CORK_CLOSE",0.4)
	elif drag=="bottle" and phase=="SEA":
		if Geometry2D.is_point_in_polygon(bottle_at,water_shape()):
			drag="";publish();return
	drag="";g.say(hint());g.save_game()
func move(at: Vector2) -> void:
	if drag=="roll":roll=clampf((SHEET.end.y-at.y)/SHEET.size.y,0,1)
	elif drag=="cork":
		cork_at=(at+drag_offset).clamp(Vector2(170,215),Vector2(1250,740))
	elif drag=="letter":
		var target:=at+drag_offset
		if absf(target.x-MOUTH.x)<45 and target.y<245:started_above_mouth=true
		if started_above_mouth and absf(target.x-MOUTH.x)<75:
			roll_at=Vector2(MOUTH.x,clampf(target.y,210,558));insertion=clampf((roll_at.y-210)/348,0,1)
		else:
			roll_at=target.clamp(Vector2(190,215),Vector2(1170,710));insertion=0;started_above_mouth=false
	elif drag=="bottle":bottle_at=(at+drag_offset).clamp(Vector2(180,280),Vector2(1370,660))
func publish() -> void:
	phase="WAIT";drift=0;splash=0;g.say(hint());g.save_game();g.audio.play("SEA_WAVE",0.55)
	g.busy=true
	await g.get_tree().create_timer(3.6).timeout
	g.busy=false
	await g.send_bottle()
	if g.stage=="BOTTLE":
		phase="SEA";drift=0;bottle_at=Vector2(1000,530);g.save_game();g.build_ui()
func serialize() -> Dictionary:
	return {"phase":"SEA" if phase=="WAIT" else phase,"roll":roll,"roll_at":[roll_at.x,roll_at.y],"cork_at":[cork_at.x,cork_at.y],"bottle_at":[bottle_at.x,bottle_at.y],"insertion":insertion,"started_above_mouth":started_above_mouth}
func restore(data: Dictionary) -> void:
	phase=str(data.get("phase","ROLL"));roll=clampf(float(data.get("roll",0)),0,1);insertion=clampf(float(data.get("insertion",0)),0,1)
	for key in ["roll_at","cork_at","bottle_at"]:
		var value: Array=data.get(key,[])
		if value.size()==2:set(key,Vector2(value[0],value[1]))
	started_above_mouth=bool(data.get("started_above_mouth",false))
func paper_roll(at: Vector2, height: float=280) -> void:
	var rect:=Rect2(at-Vector2(23,height/2),Vector2(46,height))
	g.draw_style_box(roll_style(Color(0.28,0.21,0.14,0.15)),Rect2(rect.position+Vector2(4,5),rect.size))
	g.draw_style_box(roll_style(Color("eee5ce")),rect)
	g.draw_texture_rect(FIBRE,rect.grow(-2),false,Color(1,1,1,0.3))
	g.draw_line(rect.position+Vector2(10,6),rect.position+Vector2(10,height-6),Color("faf2dd"),3,true)
	g.draw_line(rect.position+Vector2(40,6),rect.position+Vector2(40,height-6),Color("bcae92"),1.2,true)
	g.draw_arc(at-Vector2(0,height/2-4),18,0,TAU,32,Color("a99c81"),1.3,true)
	g.draw_arc(at-Vector2(0,height/2-4),9,0.1,PI*1.8,24,Color("c1b398"),1,true)
func roll_style(color: Color) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(13);return style
func cork() -> void:
	g.draw_style_box(roll_style(Color("ac8158")),Rect2(cork_at-Vector2(25,24),Vector2(50,47)))
	g.draw_line(cork_at+Vector2(-16,-13),cork_at+Vector2(16,-13),Color("d3b58b"),3,true)
	for i in 17:
		var p:=cork_at+Vector2(sin(i*2.39)*18,cos(i*3.12)*17)
		g.draw_line(p,p+Vector2(2+i%3,1),Color(0.35,0.25,0.16,0.3),1,true)
func water_shape() -> PackedVector2Array:
	return PackedVector2Array([Vector2(1440,263),Vector2(1370,282),Vector2(1315,320),Vector2(1280,366),Vector2(1248,424),Vector2(1215,492),Vector2(1197,573),Vector2(1186,671),Vector2(1156,768),Vector2(1124,844),Vector2(1092,900),Vector2(1440,900)])
func draw_water() -> void:
	var water:=water_shape()
	g.draw_colored_polygon(water,Color("a4c4bf"))
	# The shoreline enters the desk softly, with a narrow wash instead of a UI box.
	for band in 3:
		var wash:=PackedVector2Array()
		for i in range(1,water.size()-1):wash.append(water[i]+Vector2(-9+band*5,0))
		g.draw_polyline(wash,Color(0.88,0.91,0.79,0.17+band*0.06),8,true)
	for n in 16:
		var ripple:=PackedVector2Array()
		for x in range(1100,1441,7):
			var point:=Vector2(x,300+n*40+sin(x*0.025+time*0.55+n)*4)
			if Geometry2D.is_point_in_polygon(point,water):ripple.append(point)
		if ripple.size()>1:g.draw_polyline(ripple,Color(0.89,0.94,0.84,0.3),1.3,true)
func draw() -> void:
	if phase in ["SEA","WAIT"]:
		draw_water()
	if phase=="ROLL":
		var remaining:=maxf(1,SHEET.size.y*(1-roll))
		g.LetterPaper.paint(g,Rect2(SHEET.position,Vector2(SHEET.size.x,remaining)),g.letter_paper_style)
		if g.letter_preview:g.draw_texture_rect_region(g.letter_preview,Rect2(SHEET.position,Vector2(SHEET.size.x,remaining)),Rect2(Vector2.ZERO,Vector2(g.letter_preview.get_size())*Vector2(1,1-roll)))
		if roll>0.01:
			g.draw_style_box(roll_style(Color("e2d6bb")),Rect2(SHEET.position.x,SHEET.position.y+remaining-8,SHEET.size.x,22))
		g.text_at("↑",Vector2(480,SHEET.position.y+remaining+35),24)
	elif insertion==0 and phase in ["UNCORK","INSERT"]:paper_roll(roll_at)
	var offset:=bottle_at-Vector2(1000,530)
	if phase=="WAIT":offset+=Vector2(drift*100,-drift*50+sin(time)*3)
	g.draw_set_transform(offset)
	var shadow:=PackedVector2Array()
	for i in 32:shadow.append(Vector2(1004,709)+Vector2(cos(i*TAU/32)*76,sin(i*TAU/32)*11))
	g.draw_colored_polygon(shadow,Color(0.33,0.29,0.20,0.12))
	var glass:=PackedVector2Array([Vector2(970,350),Vector2(1030,350),Vector2(1031,389),Vector2(1034,405),Vector2(1045,417),Vector2(1065,434),Vector2(1069,459),Vector2(1073,675),Vector2(1070,690),Vector2(1064,700),Vector2(1050,707),Vector2(950,707),Vector2(937,701),Vector2(930,691),Vector2(927,675),Vector2(931,459),Vector2(935,434),Vector2(955,417),Vector2(966,405),Vector2(969,389)])
	g.draw_colored_polygon(glass,Color(0.44,0.66,0.59,0.25))
	# Paper behind the translucent glass; the mouth lip crosses it continuously.
	if insertion>0 or phase in ["CORK","SEA","WAIT"]:paper_roll(roll_at if phase=="INSERT" else Vector2(1000,558))
	g.draw_colored_polygon(glass,Color(0.62,0.79,0.71,0.15))
	var rim:=glass.duplicate();rim.append(glass[0]);g.draw_polyline(rim,Color("779e90"),2,true)
	g.draw_line(Vector2(946,447),Vector2(943,653),Color(0.96,0.98,0.90,0.5),6,true)
	g.draw_line(Vector2(1054,468),Vector2(1058,664),Color(0.28,0.47,0.40,0.15),3,true)
	g.draw_line(Vector2(974,355),Vector2(1026,355),Color("b4d2bc"),5,true)
	g.draw_line(Vector2(975,361),Vector2(1025,361),Color("7b9f8c"),1.5,true)
	if phase in ["SEA","WAIT"]:cork()
	g.draw_set_transform(Vector2.ZERO)
	if phase=="WAIT" and splash<2.0:
		for ring in 3:
			var radius:float=18+splash*51+ring*12;var curve:=PackedVector2Array()
			for i in 45:curve.append(bottle_at+Vector2(0,135)+Vector2(cos(i*TAU/44)*radius,sin(i*TAU/44)*radius*0.30))
			g.draw_polyline(curve,Color(0.91,0.95,0.84,(1.0-splash/2.0)*0.55),2,true)
	if phase not in ["SEA","WAIT"]:cork()
	if phase=="INSERT" and not started_above_mouth:g.draw_arc(Vector2(1000,219),28,0.15,PI-0.15,24,Color(0.40,0.55,0.42,0.3),1.5,true)
