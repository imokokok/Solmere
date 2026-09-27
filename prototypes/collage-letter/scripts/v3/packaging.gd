extends Control
signal finished(stamp:String)
signal sound(event:String)
signal hint(text:String)
const Text=preload("res://scripts/v3/chinese.gd")
const Paper=preload("res://scripts/letter_paper.gd")
const FONT=preload("res://assets/fonts/xiaolai/Xiaolai-Regular.ttf")
var preview:Texture2D
var stage=0
var progress=0.0
var busy=false
var dragging=false
var start=Vector2.ZERO
var letter_position=Vector2(450,300)
var stamp=""
var mode="HELP"
var shift=Vector2.ZERO
var flap_closure=0.0
func _ready() -> void:
 size=Vector2(1440,810);mouse_filter=Control.MOUSE_FILTER_STOP
 hint.emit("拿住信纸下沿，轻轻向上折。")
func letter_rect() -> Rect2:
 return Rect2(letter_position,Vector2(270,382 if stage==0 else (191 if stage==1 else 96)))
func envelope_rect() -> Rect2:return Rect2(835,400,365,240)
func animate_fold() -> void:
 if busy:return
 busy=true;sound.emit("PAPER_FOLD")
 var tw=create_tween();tw.tween_method(func(v):progress=v;queue_redraw(),0.0,1.0,0.6)
 tw.tween_callback(func():
  stage+=1;progress=0;busy=false;queue_redraw()
  hint.emit("再折一次，让这封信小一点。" if stage==1 else "把折好的信，放进敞开的信封。"))
func _gui_input(e:InputEvent) -> void:
 if busy:return
 if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
  if e.pressed:
   if stage<2 and Rect2(letter_rect().position+Vector2(0,letter_rect().size.y-48),Vector2(270,60)).has_point(e.position):dragging=true;start=e.position
   elif stage==2 and letter_rect().grow(18).has_point(e.position):dragging=true;shift=e.position-letter_position;sound.emit("PAPER_PICK")
   elif stage==3:
    for i in 3:
     if Rect2(442+i*140,648,104,80).has_point(e.position):
      stamp=["Lemon","Lighthouse","Train"][i];stage=4;sound.emit("STAMP_RELEASE");hint.emit("最后，在邮戳上按一下。Solmere 会收好这封信。");queue_redraw()
   elif stage==4 and Rect2(1150,670,150,90).has_point(e.position):postmark()
  else:
   if dragging and stage==2:
    if letter_rect().intersection(envelope_rect().grow(25)).get_area()>letter_rect().get_area()*0.15:insert_letter()
    else:
     var tw=create_tween();tw.tween_property(self,"letter_position",Vector2(450,400),0.25);tw.parallel().tween_method(func(_v):queue_redraw(),0.0,1.0,0.25)
   dragging=false
 elif e is InputEventMouseMotion and dragging:
  if stage<2 and start.y-e.position.y>65:dragging=false;animate_fold()
  elif stage==2:letter_position=e.position-shift;queue_redraw()
func insert_letter() -> void:
 busy=true;sound.emit("PAPER_SLIDE")
 var tw=create_tween();tw.tween_property(self,"letter_position",Vector2(880,458),0.45).set_trans(Tween.TRANS_SINE)
 tw.parallel().tween_method(func(_v):queue_redraw(),0.0,1.0,0.45)
 tw.tween_callback(func():stage=3;sound.emit("PAPER_FOLD"))
 tw.tween_method(func(v):flap_closure=v;queue_redraw(),0.0,1.0,0.42).set_trans(Tween.TRANS_SINE)
 tw.tween_callback(func():busy=false;hint.emit("挑一枚邮票，留在这次出发上。");queue_redraw())
func postmark() -> void:
 if stage!=4 or busy:return
 busy=true;stage=5;sound.emit("STAMP_PRESS");queue_redraw()
 hint.emit("寄往海风里的某个人。" if mode!="HELP" else "已交给 Solmere 邮局。")
 var tw=create_tween();tw.tween_interval(0.7);tw.tween_method(func(v):progress=v;queue_redraw(),0.0,1.0,0.9)
 tw.tween_callback(func():finished.emit(stamp))
func _draw() -> void:
 var paper=letter_rect();paper.size.y*=1.0-progress*0.5 if stage<2 else 1.0
 if stage<3:
  Paper.paint(self,paper,1,true)
  if preview and stage==0:draw_texture_rect(preview,paper.grow(-5),false)
  if stage<2:
   draw_line(paper.position+Vector2(0,paper.size.y/2),paper.position+Vector2(paper.size.x,paper.size.y/2),Color(0.50,0.44,0.30,0.20),1)
   draw_line(Vector2(paper.position.x+85,paper.end.y-9),Vector2(paper.end.x-85,paper.end.y-9),Color("a39374"),2,true)
 var env=envelope_rect()
 if stage==5:env.position+=Vector2(90,-180)*progress;modulate.a=1-progress
 if stage>=2:
  Paper.paint(self,env,1,true)
  var flap=PackedVector2Array([env.position,env.position+Vector2(env.size.x/2,-110),Vector2(env.end.x,env.position.y)])
  if stage==2:draw_colored_polygon(flap,Color("eee1bf"));draw_polyline(flap,Color("c8b893"),1,true)
  # Front pocket joins precisely on the same fold, without disconnected seams.
  var front=PackedVector2Array([env.position,env.position+Vector2(env.size.x/2,125),Vector2(env.end.x,env.position.y),env.end,Vector2(env.position.x,env.end.y)])
  draw_colored_polygon(front,Color("ede0be"))
  draw_line(env.position,env.position+Vector2(env.size.x/2,125),Color("baae8e"),1)
  draw_line(Vector2(env.end.x,env.position.y),env.position+Vector2(env.size.x/2,125),Color("baae8e"),1)
  if stage>=3:
   var tip=lerpf(-110,126,flap_closure)
   if absf(tip)>0.1:draw_colored_polygon(PackedVector2Array([env.position,Vector2(env.end.x,env.position.y),env.position+Vector2(env.size.x/2,tip)]),Color("f4e8cb"))
   draw_string(FONT,env.position+Vector2(30,194),"索尔米尔 · 书信事务所",HORIZONTAL_ALIGNMENT_LEFT,260,21,Color("667265"))
 if stage in [3,4]:
  for i in 3:
   var r=Rect2(442+i*140,648,104,80);Paper.paint(self,r,1,true)
   draw_stamp(r.position+Vector2(52,28),i,1.0)
   draw_string(FONT,r.position+Vector2(6,64),["柠檬","灯塔","火车"][i],HORIZONTAL_ALIGNMENT_CENTER,92,15,Color("57665a"))
 if stage>=4:
  var sr=Rect2(env.position+Vector2(275,20),Vector2(64,75));Paper.paint(self,sr,1,false)
  draw_stamp(sr.position+Vector2(32,27),["Lemon","Lighthouse","Train"].find(stamp),0.78);draw_string(FONT,sr.position+Vector2(4,61),Text.show(stamp),HORIZONTAL_ALIGNMENT_CENTER,56,11,Color("526057"))
 if stage==4:
  paint_oval(Rect2(1168,718,102,26),Color("3f4e46"));draw_rect(Rect2(1197,678,44,48),Color("92674c"));draw_circle(Vector2(1219,678),24,Color("ad8057"))
 if stage==5:
  draw_arc(env.position+Vector2(279,71),47,0,TAU,50,Color("5b746d"),2,true)
  draw_arc(env.position+Vector2(279,71),42,0,TAU,50,Color("5b746d"),1,true)
  draw_string(FONT,env.position+Vector2(228,76),"索尔米尔",HORIZONTAL_ALIGNMENT_CENTER,104,14,Color("5b746d"))
func draw_stamp(at:Vector2,kind:int,factor:float) -> void:
 draw_set_transform(at,0,Vector2.ONE*factor)
 match kind:
  0:
   draw_colored_polygon(PackedVector2Array([Vector2(-25,0),Vector2(-12,-14),Vector2(8,-14),Vector2(26,0),Vector2(14,17),Vector2(-9,17)]),Color("d8b65a"))
   draw_line(Vector2(0,-14),Vector2(11,-25),Color("72865e"),3,true);draw_circle(Vector2(14,-24),6,Color("85936d"))
  1:
   draw_colored_polygon(PackedVector2Array([Vector2(-13,18),Vector2(-7,-18),Vector2(6,-18),Vector2(13,18)]),Color("f6edcd"))
   draw_rect(Rect2(-8,-19,17,8),Color("b67854"));draw_line(Vector2(-16,19),Vector2(18,19),Color("729395"),3,true);draw_line(Vector2(-23,25),Vector2(25,25),Color("729395"),2,true)
   draw_colored_polygon(PackedVector2Array([Vector2(-12,-19),Vector2(0,-29),Vector2(13,-19)]),Color("82775c"))
  _:
   draw_rect(Rect2(-24,-8,34,23),Color("9c7056"));draw_rect(Rect2(8,-22,18,37),Color("8a9a8b"));draw_rect(Rect2(12,-17,9,12),Color("f4dfb6"))
   draw_rect(Rect2(-18,-19,7,13),Color("746b55"));draw_circle(Vector2(-13,17),6,Color("56685c"));draw_circle(Vector2(17,17),6,Color("56685c"))
 draw_set_transform(Vector2.ZERO)
func paint_oval(r:Rect2,color:Color) -> void:
 draw_set_transform(r.get_center(),0,r.size/2);draw_circle(Vector2.ZERO,1,color);draw_set_transform(Vector2.ZERO)
