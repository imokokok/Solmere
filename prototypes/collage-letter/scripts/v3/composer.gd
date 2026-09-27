extends Control
signal changed
signal picked
const Piece=preload("res://scripts/v3/paper_object.gd")
const Paper=preload("res://scripts/letter_paper.gd")
const PAGE=Rect2(568,154,414,585)
var fragments:Array=[]
var mode="HELP"
var owner_name="Mara"
var selected
var read_only=false
var paper_style=1
const CutStyle=preload("res://scripts/v3/cutout_style.gd")
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE;size=Vector2(1440,810)
func _draw() -> void:
 Paper.paint(self,PAGE,paper_style,true)
func add_fragment(d:Dictionary,at:Vector2=Vector2(545,355)):
 var p=Piece.new()
 var word=str(d.get("word",""))
 var shown=preload("res://scripts/v3/chinese.gd").show(word)
 var text_width=CutStyle.font_for(d).get_string_size(shown,HORIZONTAL_ALIGNMENT_LEFT,-1,27).x
 var dimensions=Vector2(clampf(text_width+16,36,340),43)
 if d.has("asset_path"):dimensions=Vector2(153,128) if d.kind=="photo" else Vector2(78,96)
 if d.get("kind","")=="tape":dimensions=Vector2(128,34)
 p.setup(d,at,dimensions);p.data.fragment=true;p.resizable=true;p.movable=not read_only
 if read_only:p.mouse_filter=Control.MOUSE_FILTER_IGNORE
 p.picked.connect(func(paper):selected=paper;picked.emit())
 p.changed.connect(func(_p):changed.emit())
 p.examined.connect(func(paper):selected=paper)
 p.dropped.connect(func(_p):changed.emit())
 add_child(p);fragments.append(p);changed.emit();return p
func placed() -> Array:
 var result=[]
 for p in fragments:
  if is_instance_valid(p) and PAGE.has_point(p.get_global_transform()*(p.size/2)):result.append(p.data)
 return result
func serialize() -> Array:
 var out=[]
 for p in get_children():
  if not p in fragments or not is_instance_valid(p):continue
  out.append({"data":p.data.duplicate(true),"position":[p.position.x,p.position.y],"rotation":p.rotation,"scale":[p.scale.x,p.scale.y]})
 return out
func restore(saved:Array) -> void:
 for p in fragments:if is_instance_valid(p):p.queue_free()
 fragments.clear()
 for d in saved:
  var p=add_fragment(d.data,Vector2(d.position[0],d.position[1]));p.rotation=float(d.rotation);p.scale=Vector2(d.scale[0],d.scale[1])
func remove_selected() -> void:
 if not is_instance_valid(selected):return
 fragments.erase(selected);selected.queue_free();selected=null;changed.emit()
func lower_selected() -> void:
 if is_instance_valid(selected):move_child(selected,0);changed.emit()

func split_selected() -> bool:
 if not is_instance_valid(selected) or selected.data.has("asset_path") or selected.data.get("kind","")=="tape":return false
 var old=selected;var word=preload("res://scripts/v3/chinese.gd").show(str(old.data.word))
 if word.length()<2:return false
 var at=old.position;var angle=old.rotation;var zoom=old.scale;var base=old.data.duplicate(true)
 var parent_id=str(base.get("instance_id",base.id))
 fragments.erase(old);old.queue_free();selected=null
 var offset_x=0.0
 for i in word.length():
  var part=base.duplicate(true);part.word=word[i];part.id=parent_id+"_char_"+str(i);part.instance_id=part.id
  part.phrase_id=parent_id;part.segment_index=i;part.segment_count=word.length();part.original_tags=base.get("tags",{});part.tags={}
  var piece=add_fragment(part,at+Vector2(offset_x,0).rotated(angle));piece.scale=zoom;piece.rotation=angle
  offset_x+=(piece.size.x+3)*zoom.x
 changed.emit();return true
