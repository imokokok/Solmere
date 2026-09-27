extends Control
## A single physical paper surface, shared by clues and all composer modes.
signal picked(paper)
signal dropped(paper)
signal examined(paper)
signal changed(paper)
enum State { FLAT, HOVERED, HELD, DRAGGING, SNAPPED, FIXED }
const Text=preload("res://scripts/v3/chinese.gd")
const Paper = preload("res://scripts/letter_paper.gd")
const FONT = preload("res://assets/fonts/xiaolai/Xiaolai-Regular.ttf")
const CutStyle=preload("res://scripts/v3/cutout_style.gd")
const TYPE = preload("res://assets/fonts/specialelite/SpecialElite-Regular.ttf")
var data:Dictionary={}
var state=State.FLAT
var reverse=false
var offset=Vector2.ZERO
var start=Vector2.ZERO
var source_ids:Array=[]
var movable=true
var resizable=false
var resizing=false
var lift=0.0
var held_scale=Vector2.ONE
var cut_indices:Array=[]
var turn=0.0
func setup(d:Dictionary,at:Vector2,dimensions:Vector2=Vector2(162,128)) -> void:
 data=d.duplicate(true);position=at;size=dimensions;pivot_offset=size/2
 source_ids=d.get("source_ids",[d.id]).duplicate()
 mouse_filter=Control.MOUSE_FILTER_STOP
func _ready() -> void:
 mouse_entered.connect(func():
  if state==State.FLAT:state=State.HOVERED;lift=3;queue_redraw())
 mouse_exited.connect(func():
  if state==State.HOVERED:state=State.FLAT;lift=0;queue_redraw())
func _gui_input(e:InputEvent) -> void:
 if e is InputEventMouseButton:
  if e.button_index==MOUSE_BUTTON_LEFT and e.pressed:
   if e.double_click:examined.emit(self);accept_event();return
   if not movable:return
   state=State.HELD;start=get_global_transform()*e.position;offset=start-global_position;held_scale=scale
   resizing=resizable and e.position.x>size.x-25 and e.position.y>size.y-25
   lift=8;move_to_front();picked.emit(self);queue_redraw();accept_event()
  elif e.button_index==MOUSE_BUTTON_RIGHT and e.pressed and not data.get("fragment",false):
   flip();accept_event()
  elif e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   if movable:rotation_degrees+=2 if e.button_index==MOUSE_BUTTON_WHEEL_UP else -2;changed.emit(self);queue_redraw()
   accept_event()
func _input(e:InputEvent) -> void:
 if state not in [State.HELD,State.DRAGGING]:return
 if e is InputEventMouseMotion:
  state=State.DRAGGING
  if resizing:
   var delta=e.position-start
   scale=Vector2(clampf(held_scale.x+delta.x/size.x,0.35,2.2),clampf(held_scale.y+delta.y/size.y,0.35,2.2))
  else:global_position=e.position-offset
  queue_redraw();get_viewport().set_input_as_handled()
 elif e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and not e.pressed:
  state=State.FLAT;resizing=false
  var tw=create_tween();tw.tween_property(self,"lift",0.0,0.12);tw.parallel().tween_method(func(_v):queue_redraw(),0.0,1.0,0.12)
  position.x=clampf(position.x,-size.x*0.25,1400-size.x*0.35);position.y=clampf(position.y,200,790-size.y*0.3)
  dropped.emit(self);changed.emit(self);queue_redraw();get_viewport().set_input_as_handled()
func flip() -> void:
 if turn>0:return
 turn=1;var tw=create_tween();var original=scale.x
 tw.tween_property(self,"scale:x",0.02,0.16)
 tw.tween_callback(func():reverse=not reverse;queue_redraw();changed.emit(self))
 tw.tween_property(self,"scale:x",original,0.18);tw.tween_callback(func():turn=0)
func _draw() -> void:
 if data.is_empty():return
 var r=Rect2(Vector2(0,-lift),size)
 if lift>0:draw_rect(Rect2(Vector2(4,6+lift),size),Color(0.22,0.15,0.1,0.16))
 if str(data.get("kind","")).begins_with("tear") and not reverse:
  var poly=PackedVector2Array();var edge=[]
  for n in 18:
   var y=float(n)/17*size.y-lift
   var jag=(sin(n*2.4)+sin(n*0.9))*4.0*sin(float(n)/17*PI)
   edge.append(Vector2(jag,y))
  if data.kind=="tear_left":
   poly.append(Vector2(0,-lift))
   for p in edge:poly.append(p+Vector2(size.x,0))
   poly.append(Vector2(0,size.y-lift))
  else:
   poly.append(Vector2(size.x,-lift));poly.append(Vector2(size.x,size.y-lift))
   for n in range(edge.size()-1,-1,-1):poly.append(edge[n])
  var shadow=PackedVector2Array();var uv=PackedVector2Array()
  for p in poly:shadow.append(p+Vector2(3,5));uv.append((p+Vector2(0,lift))/size)
  draw_colored_polygon(shadow,Color(0.25,0.18,0.1,0.18));draw_colored_polygon(poly,Color("f5ebce"));draw_polygon(poly,PackedColorArray([Color(1,1,1,0.7)]),uv,Paper.texture(int(data.get("style",1))))
 elif data.get("fragment",false):CutStyle.paint(self,r,data,lift)
 else:Paper.paint(self,r,int(data.get("style",1)),true)
 var ink=Color("405b63") if str(data.id).begins_with("mara") else Color("4c493f")
 if str(data.id).begins_with("june") or data.id=="literature":ink=Color("98584c")
 if reverse:
  draw_multiline_string(FONT,Vector2(12,25-lift),Text.show(str(data.get("back","纸背的纤维，透出浅浅的墨迹。"))),HORIZONTAL_ALIGNMENT_LEFT,size.x-24,19,7,ink)
  return
 if data.get("fragment",false):
  var f=CutStyle.font_for(data)
  var fs=27
  var word=Text.show(str(data.get("word","")))
  while fs>13 and f.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x>size.x-14:fs-=1
  draw_string(f,Vector2(7,(size.y-f.get_height(fs))*0.5+f.get_ascent(fs)-lift),word,HORIZONTAL_ALIGNMENT_CENTER,size.x-14,fs,CutStyle.ink(data))
 else:
  draw_string(FONT,Vector2(12,20-lift),Text.show(str(data.get("title",""))),HORIZONTAL_ALIGNMENT_LEFT,size.x-24,12,ink)
  draw_line(Vector2(12,28-lift),Vector2(size.x-12,28-lift),Color(0.36,0.36,0.30,0.25),1)
  var lines=str(data.get("body","")).count("\n")+1
  var fs=mini(15 if size.x<210 else 21,maxi(10,int((size.y-53)/maxi(1,lines)*0.78)))
  draw_multiline_string(FONT,Vector2(12,49-lift),Text.show(str(data.get("body",""))),HORIZONTAL_ALIGNMENT_LEFT,size.x-24,fs,9,ink)
  if data.get("kind","")=="receipt":
   for x in range(8,int(size.x-8),7):draw_line(Vector2(x,size.y-6-lift),Vector2(x+3,size.y-6-lift),Color("b7aa89"),1)
  if data.get("kind","").begins_with("tear"):
   var x= size.x-2 if data.kind=="tear_left" else 2
   for y in range(4,int(size.y-5),8):draw_line(Vector2(x,y-lift),Vector2(x+(-4 if x>5 else 4),y+4-lift),Color("b3a98f"),1)
 if state in [State.HELD,State.DRAGGING]:
  draw_rect(r.grow(3),Color(0.28,0.39,0.37,0.45),false,1)
  if resizable:draw_circle(size-Vector2(5,5),4,Color("57746d"))
