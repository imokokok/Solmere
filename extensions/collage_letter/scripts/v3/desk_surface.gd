extends RefCounted
## Physical desk props remain separate from click targets and live paper content.
const Paper=preload("res://extensions/collage_letter/scripts/letter_paper.gd")
const FONT=preload("res://extensions/collage_letter/assets/fonts/xiaolai/Xiaolai-Regular.ttf")
const PICTURE=preload("res://extensions/collage_letter/assets/open_pack/photos/lookout-terrace.jpg")
const SCISSORS=preload("res://extensions/collage_letter/assets/open_pack/icons/extra-scissors.svg")
static func rounded(n:CanvasItem,r:Rect2,color:Color,radius:float=12) -> void:
 var s=StyleBoxFlat.new();s.bg_color=color;s.set_corner_radius_all(int(radius));n.draw_style_box(s,r)
static func tray(n:CanvasItem,r:Rect2) -> void:
 rounded(n,Rect2(r.position+Vector2(7,11),r.size),Color(0.23,0.12,0.06,0.22),24)
 rounded(n,r,Color("865433"),23)
 rounded(n,Rect2(r.position+Vector2(3,3),r.size-Vector2(6,9)),Color("bd8754"),21)
 rounded(n,Rect2(r.position+Vector2(13,13),r.size-Vector2(26,27)),Color("926342"),15)
 rounded(n,Rect2(r.position+Vector2(18,20),r.size-Vector2(36,39)),Color("c09360"),13)
 for i in 8:
  var x=r.position.x+24+i*(r.size.x-48)/8
  n.draw_line(Vector2(x,r.position.y+24),Vector2(x+10,r.end.y-22),Color(0.41,0.23,0.12,0.07),2,true)
 n.draw_arc(r.position+Vector2(27,26),21,PI,PI*1.5,18,Color("dfb17d"),2,true)
 n.draw_line(Vector2(r.position.x+29,r.end.y-6),Vector2(r.end.x-29,r.end.y-6),Color("724b34"),2,true)
static func book(n:CanvasItem) -> void:
 var r=Rect2(116,127,353,405)
 rounded(n,Rect2(107,138,379,411),Color(0.19,0.16,0.12,0.22),5)
 rounded(n,Rect2(101,124,375,411),Color("536a81"),5)
 n.draw_line(Vector2(109,135),Vector2(109,520),Color("91a0b0"),3)
 for i in range(5,-1,-1):
  var page=Rect2(r.position+Vector2(i*2.1,i*2.7),r.size)
  Paper.paint(n,page,3 if i%2 else 1,i==5)
  n.draw_line(Vector2(page.end.x,page.position.y+15),Vector2(page.end.x,page.end.y-4),Color("c2b098"),0.8)
 # A sewn spine gives the stack a hinge, independent of the turning top sheet.
 for y in [206,351,479]:
  n.draw_arc(Vector2(118,y),9,0.15,PI*1.75,24,Color("b99b6e"),3,true)
static func note(n:CanvasItem,r:Rect2) -> void:
 Paper.paint(n,Rect2(r.position+Vector2(4,5),r.size),2,true)
 Paper.paint(n,r,1,true)
 for x in [r.position.x+32,r.end.x-51]:n.draw_rect(Rect2(x,r.position.y-4,24,13),Color(0.40,0.42,0.33,0.5))
static func tape_roll(n:CanvasItem,at:Vector2) -> void:
 n.draw_circle(at+Vector2(3,5),33,Color(0.24,0.18,0.12,0.15))
 n.draw_circle(at,32,Color("718998"));n.draw_circle(at,25,Color("eee1c3"));n.draw_circle(at,18,Color("9b7954"));n.draw_circle(at,13,Color("70553e"))
 for i in 12:
  var a=i*TAU/12;n.draw_line(at+Vector2.from_angle(a)*26,at+Vector2.from_angle(a+0.07)*31,Color("c8d0ce"),4,true)
static func tools(n:CanvasItem) -> void:
 tray(n,Rect2(1180,394,230,306))
 # Two compartments, filled by tools with matching interactive hit regions.
 n.draw_line(Vector2(1293,417),Vector2(1293,678),Color("855c3e"),6,true)
 n.draw_line(Vector2(1297,417),Vector2(1297,678),Color("d4a574"),2,true)
 # Separate steel blades and hollow handles read as a tool at normal play size.
 n.draw_colored_polygon(PackedVector2Array([Vector2(1346,573),Vector2(1314,487),Vector2(1328,501),Vector2(1355,570)]),Color("c0bba8"))
 n.draw_colored_polygon(PackedVector2Array([Vector2(1346,573),Vector2(1378,495),Vector2(1379,516),Vector2(1354,581)]),Color("9caaab"))
 n.draw_line(Vector2(1329,596),Vector2(1352,569),Color("504a40"),9,true)
 n.draw_line(Vector2(1370,607),Vector2(1346,569),Color("504a40"),9,true)
 n.draw_arc(Vector2(1326,614),20,0,TAU,48,Color("504a40"),9,true)
 n.draw_arc(Vector2(1373,628),22,0,TAU,48,Color("504a40"),9,true)
 n.draw_circle(Vector2(1350,573),5,Color("d0b884"))
 tape_roll(n,Vector2(1237,641))
 # A paper stack is the paper chooser, not a nonfunctional pen.
 for i in range(3,-1,-1):Paper.paint(n,Rect2(1200+i*3,431+i*3,66,96),[1,2,15,1][i],i==3)
 n.draw_line(Vector2(1318,442),Vector2(1374,442),Color("c0a26c"),7,true)
 n.draw_line(Vector2(1318,444),Vector2(1374,444),Color("e9c78a"),2,true)
static func scraps(n:CanvasItem) -> void:
 tray(n,Rect2(101,558,381,165))
static func side_mail(n:CanvasItem) -> void:
 for i in range(2,-1,-1):Paper.paint(n,Rect2(1211+i*4,159+i*5,162,190),[2,4,1][i],true)
 Paper.paint(n,Rect2(1243,244,137,93),1,true)
 n.draw_texture_rect(PICTURE,Rect2(1250,251,123,67),false,Color(0.90,0.88,0.78))
static func envelope_icon(n:CanvasItem,r:Rect2,color:Color) -> void:
 rounded(n,r,color,2)
 n.draw_polyline(PackedVector2Array([r.position+Vector2(3,3),r.get_center()+Vector2(0,1),Vector2(r.end.x-3,r.position.y+3)]),Color("eddbb9"),2,true)
