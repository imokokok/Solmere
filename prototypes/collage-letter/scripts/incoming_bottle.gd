extends CanvasLayer
## A loose cork and a gravity-driven paper roll on an illustrated desk.
var g
var root:Control
var hint:Label
var stage:="LIFT"
var bottle:=Vector2(910,575)
var bottle_angle:=0.0
var cork:=Vector2(910,387)
var cork_angle:=0.0
var cork_velocity:=Vector2.ZERO
var cork_spin:=0.0
var cork_removed:=false
var paper:=Vector2(910,575)
var paper_angle:=0.0
var paper_slide:=0.0
var paper_speed:=0.0
var opening:=0.0
var landing:=0.0
var fall_origin:=Vector2.ZERO
var fall_angle:=0.0
var drag:=""
var pointer_offset:=Vector2.ZERO
var drag_start:=Vector2.ZERO
var tilt_start:=0.0
var bottle_start:=Vector2.ZERO
var last_pointer_time:=0
var preview:Texture2D
var preview_pending:=true
var closing:=false
const GLASS=[Vector2(-27,-183),Vector2(27,-183),Vector2(28,-117),Vector2(69,-71),Vector2(75,131),Vector2(64,153),Vector2(-63,153),Vector2(-75,131),Vector2(-69,-71),Vector2(-28,-117)]
func _ready()->void:
	layer=18;root=Control.new();root.size=Vector2(1440,900);root.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(root);root.draw.connect(draw_objects)
	hint=Label.new();hint.position=Vector2(300,111);hint.size=Vector2(1040,80);hint.add_theme_font_override("font",g.font);hint.add_theme_font_size_override("font_size",22);hint.add_theme_color_override("font_color",Color("f2e5c9"));root.add_child(hint)
	var back:=Button.new();back.position=Vector2(82,53);back.size=Vector2(146,39);back.text="放回桌上" if g.L.language=="zh" else "Put it back";back.add_theme_font_override("font",g.font);back.pressed.connect(close);root.add_child(back)
	refresh_hint();g.audio.play("SEA_WAVE",0.30);prepare_preview()
func prepare_preview()->void:
	var encoded:String=await g.SeaExample.artwork(g,false)
	preview_pending=false
	if closing:queue_free();return
	if not is_instance_valid(root) or encoded.is_empty():return
	var image:=Image.new()
	if image.load_png_from_buffer(Marshalls.base64_to_raw(encoded))==OK:preview=ImageTexture.create_from_image(image);root.queue_redraw()
func refresh_hint()->void:
	var zh={"LIFT":"① 拿起有信的漂流瓶，向桌面中央移一点。","UNCORK":"② 握住软木塞向上拔。拔出来后，可以把它放到一旁。","POUR":"③ 拖动瓶身向左或右倾斜，让瓶口朝下，纸卷会自己滑出来。","FALL":"纸卷落在桌上，正慢慢展开。瓶塞还可以拿起来玩。","READ":"信展开了。点一下信纸，看看里面写了什么。"}
	var en={"LIFT":"1. Bring the bottle toward the middle of the desk.","UNCORK":"2. Pull out the cork, then drop it beside you.","POUR":"3. Drag the bottle left or right to tip its mouth down. Let the paper slide out.","FALL":"The paper settles and gently opens. The loose cork is still yours to move.","READ":"The letter is open. Click the paper to read it."}
	hint.text=(zh if g.L.language=="zh" else en)[stage];root.queue_redraw()
func _process(dt:float)->void:
	if cork_removed and drag!="cork":
		cork_velocity.y+=650*dt;cork+=cork_velocity*dt;cork_angle+=cork_spin*dt
		if cork.y>741:
			cork.y=741
			if cork_velocity.y>75:g.audio.play("CORK_DROP",minf(.65,cork_velocity.y/700))
			cork_velocity.y=-cork_velocity.y*.25 if cork_velocity.y>35 else 0.0
			cork_velocity.x=move_toward(cork_velocity.x,0,500*dt);cork_spin=move_toward(cork_spin,0,6*dt)
		if cork.x<50 or cork.x>1390:cork.x=clampf(cork.x,50,1390);cork_velocity.x*=-.35
	if stage=="POUR":
		# Project gravity onto the neck axis. Upright bottles retain their paper.
		var gravity:float=-cos(bottle_angle)
		paper_speed=clampf(paper_speed+gravity*540*dt,-120,310)
		if absf(bottle_angle)<1.6:paper_speed=minf(paper_speed,-65)
		paper_slide=clampf(paper_slide+paper_speed*dt,0,322)
		paper=bottle+Vector2(0,-paper_slide).rotated(bottle_angle);paper_angle=bottle_angle
		if paper_slide>=320:
			stage="FALL";drag="";fall_origin=paper;fall_angle=paper_angle;landing=0;g.audio.play("PAPER_MOVE",.65);refresh_hint()
	elif stage=="FALL":
		landing+=dt
		# Set the empty bottle beside the landing paper, without an abrupt jump
		# or leaving the flattened letter visually resting on top of the glass.
		bottle=bottle.lerp(Vector2(1040,500),clampf(dt*3.5,0,1));bottle_angle=lerp_angle(bottle_angle,0,clampf(dt*3.5,0,1))
		var t:=clampf(landing/.85,0,1);var ease:=smoothstep(0,1,t)
		paper=fall_origin.lerp(Vector2(650,460),ease)+Vector2(0,-sin(t*PI)*38);paper_angle=lerp_angle(fall_angle,0,ease)
		opening=smoothstep(0,1,clampf((landing-.7)/1.25,0,1))
		if landing>=1.95:stage="READ";opening=1;g.audio.play("PAGE_TURN",.45);refresh_hint()
	root.queue_redraw()
func draw_roll(at:Vector2,angle:float)->void:
	root.draw_set_transform(at,angle)
	root.draw_style_box(g.Journal.rounded(Color("e5dab9"),9),Rect2(-17,-126,34,250))
	for i in 3:root.draw_line(Vector2(-10+i*8,-115),Vector2(-10+i*8,114),Color("c8b896"),1,true)
	root.draw_arc(Vector2(0,-118),12,0,TAU,24,Color("b7a889"),1,true);root.draw_set_transform(Vector2.ZERO)
func draw_objects()->void:
	root.draw_rect(Rect2(0,0,1440,900),Color(.20,.25,.23,.82))
	var glass:=PackedVector2Array(GLASS)
	root.draw_set_transform(bottle,bottle_angle);root.draw_colored_polygon(glass,Color("7caaa0"));root.draw_set_transform(Vector2.ZERO)
	if stage in ["LIFT","UNCORK","POUR"]:draw_roll(paper,paper_angle)
	root.draw_set_transform(bottle,bottle_angle);root.draw_colored_polygon(glass,Color(.51,.71,.66,.30));var rim:=glass.duplicate();rim.append(glass[0]);root.draw_polyline(rim,Color("bdcfc0"),2,true)
	root.draw_line(Vector2(-57,-63),Vector2(-56,104),Color(.89,.94,.83,.45),5,true);root.draw_line(Vector2(-27,-175),Vector2(27,-175),Color("bdd4bf"),4,true);root.draw_set_transform(Vector2.ZERO)
	if stage in ["FALL","READ"]:
		root.draw_set_transform(paper,paper_angle)
		var dimensions:=Vector2(34+opening*306,250+opening*230);var bounds:=Rect2(-dimensions*.5,dimensions)
		root.draw_style_box(g.Journal.rounded(Color(0,0,0,.12),5),Rect2(bounds.position+Vector2(5,7),bounds.size))
		g.LetterPaper.paint(root,bounds,1)
		if preview:root.draw_texture_rect(preview,bounds,false,Color(1,1,1,smoothstep(.25,.85,opening)))
		if opening<.99:
			var curl:=Rect2(bounds.end.x-18,bounds.position.y,25,bounds.size.y)
			root.draw_style_box(g.Journal.rounded(Color("d6c9a9"),8),curl);root.draw_line(curl.position+Vector2(7,5),curl.position+Vector2(7,curl.size.y-5),Color("b9aa8c"),1.2,true)
		root.draw_set_transform(Vector2.ZERO)
	root.draw_set_transform(cork,cork_angle)
	root.draw_style_box(g.Journal.rounded(Color("b98f62"),7),Rect2(-27,-25,54,48))
	for i in 12:root.draw_circle(Vector2(sin(i*2.3)*20,cos(i*3.7)*16),1.3,Color("96714e"))
	root.draw_set_transform(Vector2.ZERO)
func cork_hit(at:Vector2)->bool:return Rect2(-36,-34,72,68).has_point((at-cork).rotated(-cork_angle))
func bottle_hit(at:Vector2)->bool:return Geometry2D.is_point_in_polygon((at-bottle).rotated(-bottle_angle),PackedVector2Array(GLASS))
func _input(event:InputEvent)->void:
	if not event is InputEventMouse:return
	var at:Vector2=root.get_global_transform_with_canvas().affine_inverse()*event.position
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			if (cork_removed or stage=="UNCORK") and cork_hit(at):drag="cork";pointer_offset=cork-at;cork_velocity=Vector2.ZERO;last_pointer_time=Time.get_ticks_msec()
			elif stage=="READ" and Rect2(480,220,340,480).has_point(at):close();g.open_bottles();get_viewport().set_input_as_handled();return
			elif stage=="LIFT" and bottle_hit(at):drag="bottle";pointer_offset=bottle-at
			elif stage=="POUR" and bottle_hit(at):drag="tilt";drag_start=at;tilt_start=bottle_angle;bottle_start=bottle
		else:
			move(at)
			if drag=="bottle" and bottle.x<815:stage="UNCORK";g.audio.play("PAPER_PRESS",.3);refresh_hint()
			if not drag.is_empty():drag="";get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not drag.is_empty():move(at);get_viewport().set_input_as_handled()
func move(at:Vector2)->void:
	match drag:
		"bottle":bottle=(at+pointer_offset).clamp(Vector2(590,400),Vector2(1020,620));cork=bottle+Vector2(0,-188);paper=bottle
		"cork":
			var target:Vector2=(at+pointer_offset).clamp(Vector2(38,40),Vector2(1402,741))
			var elapsed:=clampf(float(Time.get_ticks_msec()-last_pointer_time)/1000,.016,.1);last_pointer_time=Time.get_ticks_msec()
			if target.distance_to(cork)>.5:cork_velocity=((target-cork)/elapsed).limit_length(1150);cork_spin=clampf(cork_velocity.x*.014,-9,9)
			if not cork_removed:target.x=bottle.x
			cork=target
			if not cork_removed and cork.y<bottle.y-248:
				cork_removed=true;stage="POUR";g.audio.play("CORK_OPEN",1.0);refresh_hint()
		"tilt":
			bottle_angle=clampf(tilt_start+(at.x-drag_start.x)/110,-2.8,2.8)
			bottle=(bottle_start+(at-drag_start)*.13).clamp(Vector2(490,390),Vector2(1080,520))
	root.queue_redraw()
func close()->void:
	g.dock_open=false;closing=true;hide();set_process(false);set_process_input(false)
	if not preview_pending:queue_free()
