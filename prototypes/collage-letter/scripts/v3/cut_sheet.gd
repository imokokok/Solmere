extends Control
signal cut(region:Dictionary,index:int)
signal sound(event:String)
const Text=preload("res://scripts/v3/chinese.gd")
const Paper=preload("res://scripts/letter_paper.gd")
const FONT=preload("res://assets/fonts/xiaolai/Xiaolai-Regular.ttf")
const CutStyle=preload("res://scripts/v3/cutout_style.gd")
var data:Dictionary={}
var removed:Array=[]
var scissors=false
var active=-1
var node_index=0
var tracing=false
var page=0
func region_rect(index:int) -> Rect2:
 var local=index%6
 return Rect2(30+(local%2)*254,198+(local/2)*86,241,62)
func visible_indices() -> Array:
 return range(page*6,mini(data.get("cuts",[]).size(),page*6+6))
func turn_page(direction:int) -> void:
 var target=clampi(page+direction,0,maxi(0,(data.get("cuts",[]).size()-1)/6))
 if target==page:return
 page=target;tracing=false;active=-1;sound.emit("PAGE_TURN");queue_redraw()
func path(index:int) -> Array:
 var r=region_rect(index)
 return [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y),r.position]
func _draw() -> void:
 # Paint only the remaining strips: cut-outs really reveal the desk below.
 # Draw a perforated sheet as strips around each cut, leaving genuine holes.
 var stock=int(data.get("style",1))
 Paper.paint(self,Rect2(0,0,size.x,198),stock,false)
 for row in 3:
  var top=198+row*86
  Paper.paint(self,Rect2(0,top,30,62),stock,false)
  Paper.paint(self,Rect2(271,top,13,62),stock,false)
  Paper.paint(self,Rect2(525,top,30,62),stock,false)
  for col in 2:
   var idx=page*6+row*2+col
   if not removed.has(idx):Paper.paint(self,region_rect(idx),stock,false)
  Paper.paint(self,Rect2(0,top+62,size.x,24),stock,false)
 Paper.paint(self,Rect2(0,456,size.x,size.y-456),stock,false)
 draw_string(FONT,Vector2(36,40),Text.show(str(data.title)),HORIZONTAL_ALIGNMENT_LEFT,size.x-72,24,Color("455c56"))
 draw_multiline_string(FONT,Vector2(36,77),Text.show(str(data.body)),HORIZONTAL_ALIGNMENT_LEFT,size.x-72,18,4,Color("6a6657"))
 draw_string(FONT,Vector2(442,483),str(page+1)+" / "+str(maxi(1,ceili(data.get("cuts",[]).size()/6.0))),HORIZONTAL_ALIGNMENT_RIGHT,80,16,Color("6a6657"))
 for i in visible_indices():
  if removed.has(i):continue
  var r=region_rect(i)
  var appearance=data.cuts[i].duplicate();appearance.id=data.id;appearance.print_variant=appearance.get("print_variant",CutStyle.variant(data))
  CutStyle.paint(self,r.grow(-6),appearance)
  var word=Text.show(str(data.cuts[i].word));var face=CutStyle.font_for(appearance);var fs=27
  while fs>16 and face.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x>r.size.x-28:fs-=1
  draw_string(face,r.position+Vector2(14,(r.size.y-face.get_height(fs))*0.5+face.get_ascent(fs)),word,HORIZONTAL_ALIGNMENT_CENTER,r.size.x-28,fs,CutStyle.ink(appearance))
  if scissors:
   var p=path(i)
   for n in 4:draw_dashed_line(p[n],p[n+1],Color(0.30,0.39,0.35,0.28),1,6)
   draw_circle(p[0],4,Color("768c75"))
   if active==i:
    for n in node_index:draw_line(p[n],p[n+1],Color("527864"),2,true)
    draw_circle(p[mini(node_index+1,4)],5,Color("ad7152"))
func _gui_input(e:InputEvent) -> void:
 if not scissors:return
 if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
  if e.pressed:
   for i in visible_indices():
    if not removed.has(i) and e.position.distance_to(path(i)[0])<26:
     active=i;node_index=0;tracing=true;sound.emit("TOOL_PICK");queue_redraw();accept_event();return
    elif not removed.has(i) and region_rect(i).has_point(e.position):
     removed.append(i);removed.sort();cut.emit(data.cuts[i].duplicate(true),i);sound.emit("PAPER_CUT");queue_redraw();accept_event();return
  else:tracing=false
 elif e is InputEventMouseMotion and tracing and active>=0:
  var points=path(active)
  if e.position.distance_to(points[node_index+1])<27:
   node_index+=1;sound.emit("KNIFE_SLICE");queue_redraw()
   if node_index==4:
    removed.append(active);removed.sort();cut.emit(data.cuts[active].duplicate(true),active);tracing=false;active=-1;queue_redraw()
  accept_event()
