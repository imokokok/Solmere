extends Control
signal opened(data)
const Paper=preload("res://extensions/collage_letter/scripts/letter_paper.gd")
const Style=preload("res://extensions/collage_letter/scripts/v3/cutout_style.gd")
const Text=preload("res://extensions/collage_letter/scripts/v3/chinese.gd")
const Photo=preload("res://extensions/collage_letter/assets/open_pack/photos/lookout-terrace.jpg")
var data:Dictionary={}
var cut_indices:Array=[]
var artwork:Texture2D
func _ready() -> void:
 if data.has("asset_path"):artwork=load(data.asset_path)
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 tooltip_text="点开这一页，剪下喜欢的词或图像。"
func _gui_input(e:InputEvent) -> void:
 if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and e.pressed:opened.emit(data);accept_event()
func _draw() -> void:
 var face=Style.font_for({"print_variant":0});var bold=Style.font_for({"print_variant":1})
 Paper.paint(self,Rect2(Vector2.ZERO,size),1,false)
 draw_string(bold,Vector2(20,37),Text.show(str(data.get("title","小镇的纸"))),HORIZONTAL_ALIGNMENT_LEFT,size.x-40,22,Color("383d39"))
 draw_line(Vector2(20,48),Vector2(size.x-20,48),Color("746b58"),1)
 draw_string(face,Vector2(20,69),"SOLMERE  /  可剪取的原件",HORIZONTAL_ALIGNMENT_LEFT,size.x-40,10,Color("766e60"))
 if data.has("asset_path"):
  var destination=Rect2(24,95,size.x-48,207) if data.kind=="photo" else Rect2(103,113,147,171)
  draw_texture_rect(artwork,destination,false)
  draw_multiline_string(face,Vector2(24,335),str(data.body),HORIZONTAL_ALIGNMENT_LEFT,size.x-48,17,3,Color("4e5147"))
  return
 var body=Text.show(str(data.get("body","")))
 if data.id in ["daily","coast","novel","neighbor"]:
  draw_texture_rect(Photo,Rect2(size.x-157,89,132,125),false,Color(0.87,0.88,0.83))
  draw_multiline_string(face,Vector2(21,112),body.replace("，","，\n").replace("。","。\n"),HORIZONTAL_ALIGNMENT_LEFT,143,17,5,Color("44483e"))
 else:draw_multiline_string(face,Vector2(22,105),body,HORIZONTAL_ALIGNMENT_LEFT,size.x-44,19,5,Color("44483e"))
 draw_line(Vector2(20,232),Vector2(size.x-20,232),Color("b7a68e"),1)
 var cuts=data.get("cuts",[])
 for i in mini(4,cuts.size()):
  var r=Rect2(22+(i%2)*159,251+(i/2)*59,146,45)
  if cut_indices.has(i):
   draw_rect(r,Color("ad865d"));draw_rect(r.grow(1),Color(0.30,0.24,0.15,0.18),false,1)
   continue
  var appearance=cuts[i].duplicate();appearance.id=data.id;appearance.print_variant=appearance.get("print_variant",Style.variant(data))
  Style.paint(self,r,appearance)
  var word=Text.show(str(cuts[i].word));var font=Style.font_for(appearance);var fs=22
  while fs>13 and font.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x>r.size.x-12:fs-=1
  draw_string(font,r.position+Vector2(6,30),word,HORIZONTAL_ALIGNMENT_CENTER,r.size.x-12,fs,Style.ink(appearance))
 draw_string(face,Vector2(22,size.y-12),"点开原件 · 字词还可以继续剪开",HORIZONTAL_ALIGNMENT_LEFT,size.x-44,13,Color("787260"))
