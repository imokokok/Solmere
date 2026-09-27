extends RefCounted
## Modern printed scraps: common source stock, distinct weight, ink and cut edge.
const BASE=preload("res://assets/fonts/notosanssc/NotoSansSC.ttf")
const Paper=preload("res://scripts/letter_paper.gd")
static var fonts:Dictionary={}
static func variant(data:Dictionary) -> int:
 return int(data.get("print_variant",absi(str(data.get("source",data.get("id","paper")) ).hash())%7))
static func font_for(data:Dictionary) -> Font:
 var weight=[400,700,500,800,400,600,400][variant(data)%7]
 if not fonts.has(weight):
  var f=FontVariation.new();f.base_font=BASE;f.variation_opentype={2003265652:weight};fonts[weight]=f
 return fonts[weight]
static func ink(data:Dictionary) -> Color:
 return Color(["343735","315d54","383a39","eee9dc","494842","3d5261","45433d"][variant(data)%7])
static func paint(node:CanvasItem,r:Rect2,data:Dictionary,lift:float=0.0) -> void:
 var v=variant(data)%7
 var paper_color=Color(["f1efdf","e2e5d8","d3d7d2","394e48","dccbac","dde5e2","f5f2e9"][v])
 var poly=Paper.outline(r,23 if v in [2,4] else 1)
 for layer in range(3,0,-1):
  var shadow=PackedVector2Array()
  for p in poly:shadow.append(p+Vector2(0.8+layer*0.55,0.6+layer*0.7+lift*0.2))
  node.draw_colored_polygon(shadow,Color(0.16,0.14,0.1,0.045))
 var thickness=PackedVector2Array();var uv=PackedVector2Array()
 for p in poly:thickness.append(p+Vector2(0.3,1));uv.append((p-r.position)/r.size)
 node.draw_colored_polygon(thickness,paper_color.darkened(0.22))
 node.draw_colored_polygon(poly,paper_color)
 node.draw_polygon(poly,PackedColorArray([Color(1,1,1,0.10)]),uv,Paper.texture([1,21,3,2,0,6,1][v]))
 node.draw_line(r.position+Vector2(1,0.7),Vector2(r.end.x-1,r.position.y+0.7),Color(1,1,0.96,0.35),0.7,true)
