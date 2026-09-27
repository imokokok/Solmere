extends Node2D
## V3: one desk and one composer; a separate save preserves every legacy draft.
const Text=preload("res://extensions/collage_letter/scripts/v3/chinese.gd")
const Data=preload("res://extensions/collage_letter/scripts/v3/case_data.gd")
const Piece=preload("res://extensions/collage_letter/scripts/v3/paper_object.gd")
const Composer=preload("res://extensions/collage_letter/scripts/v3/composer.gd")
const CutSheet=preload("res://extensions/collage_letter/scripts/v3/cut_sheet.gd")
const Packing=preload("res://extensions/collage_letter/scripts/v3/packaging.gd")
const CutStyle=preload("res://extensions/collage_letter/scripts/v3/cutout_style.gd")
const Paper=preload("res://extensions/collage_letter/scripts/letter_paper.gd")
const FONT=preload("res://extensions/collage_letter/assets/fonts/xiaolai/Xiaolai-Regular.ttf")
const SERIF=preload("res://extensions/collage_letter/assets/fonts/librebaskerville/LibreBaskerville[wght].ttf")
const ROOM=preload("res://extensions/collage_letter/assets/illustrated_office/desk-room-v2.png")
var audio
var ui:Control
var papers:Control
var modal:Control
var composer
var packing
var hint_label:Label
var selected
var state:Dictionary={}
var save_path="user://solmere_letter_office_v3.json"
var preview_path="user://solmere_letter_office_v3.png"
var ready_done=false
var busy=false
var phase="hub"
var current="Mara"
var mode="HELP"
var directory_page=0
var consulted:Array=[]
var cut_source:Dictionary={}
var draft_key="HELP_Mara"
var source_page=0
var elapsed=0.0
var save_delay=-1.0
var book_busy=false
var solmere_completed=false
var stage="V3"
var letter_title="写给某个人的一封信"
var letter_mode="npc"
var bottle_published_id=0
var daylight=1.0
var blinds_open=1.0
var writing_preferences={"reduce_motion":false}
var ambient:AudioStreamPlayer
func new_state() -> Dictionary:
 return {"version":3,"phase":"hub","current":"Mara","mode":"HELP","groups":{},"recipients":{},"briefs":{},"consulted":[],"pieces":[],"drafts":{},"completed_cases":[],"paper_library":[],"received_fragments":[],"drift_letters_sent":[],"drift_letters_received":[],"shared_fragment_history":{},"unlocked_tools":["CUT"],"pending_replies":[],"day":1,"drift_index":0}
func _ready() -> void:
 if not has_node("/root/GameState"):call_deferred("set_window_title")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--profile="):save_path="user://solmere_v3_"+arg.trim_prefix("--profile=").validate_filename()+".json"
 state=new_state()
 if FileAccess.file_exists(save_path) and not OS.get_cmdline_user_args().has("--fresh"):
  var loaded=JSON.parse_string(FileAccess.get_file_as_string(save_path))
  if loaded is Dictionary and loaded.get("version",0)==3:state.merge(loaded,true)
 phase=str(state.phase);current=str(state.current);mode=str(state.mode);consulted=state.consulted.duplicate()
 # Host settlement belongs to a letter sent during this visit, never an old save.
 solmere_completed=false
 audio=preload("res://extensions/collage_letter/scripts/audio_manager.gd").new();add_child(audio)
 ambient=AudioStreamPlayer.new();ambient.stream=load("res://extensions/collage_letter/assets/open_pack/audio/ocean-waves.ogg");ambient.volume_db=-29;add_child(ambient);ambient.finished.connect(func():ambient.play());ambient.play()
 papers=Control.new();papers.mouse_filter=Control.MOUSE_FILTER_IGNORE;papers.size=Vector2(1440,810);add_child(papers)
 ui=Control.new();ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.size=Vector2(1440,810);add_child(ui)
 if phase=="compose":start_composer(mode,current,false)
 else:phase="hub" # Old arrival/puzzle saves continue at the letter tray, with drafts intact.
 build_ui();ready_done=true;set_process(true);queue_redraw()
func set_window_title() -> void:
 await get_tree().process_frame
 DisplayServer.window_set_title("Solmere · 书信事务所 · 中文 V3")
func _process(delta:float) -> void:
 elapsed+=delta
 if save_delay>=0:
  save_delay-=delta
  if save_delay<0:save_game()
 queue_redraw()
func defer_save() -> void:save_delay=0.45
func label(parent:Node,text:String,r:Rect2,font_size:int=20,color:Color=Color("41594f")) -> Label:
 var l=Label.new();l.text=Text.show(text);l.position=r.position;l.size=r.size;l.add_theme_font_override("font",FONT);l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(l);return l
func button(parent:Node,text:String,r:Rect2,action:Callable,quiet:bool=false) -> Button:
 var b=Button.new();b.text=Text.show(text);b.position=r.position;b.size=r.size;b.add_theme_font_override("font",FONT);b.add_theme_font_size_override("font_size",19);b.add_theme_color_override("font_color",Color("415b50"))
 b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
 for style_name in ["normal","hover","pressed","disabled"]:
  var s=StyleBoxFlat.new();s.bg_color=Color(0,0,0,0) if quiet else (Color("f0e5c9") if style_name=="normal" else Color("d6ddc6"));s.set_corner_radius_all(3)
  if not quiet:s.shadow_color=Color(0.23,0.18,0.12,0.13);s.shadow_size=3;s.shadow_offset=Vector2(2,3)
  b.add_theme_stylebox_override(style_name,s)
 b.pressed.connect(func():audio.play("TOOL_PICK",0.65);action.call());parent.add_child(b);return b
func clear_ui() -> void:
 for child in ui.get_children():ui.remove_child(child);child.queue_free()
func say(text:String) -> void:
 if is_instance_valid(hint_label):hint_label.text=Text.show(text)
func build_ui() -> void:
 clear_ui()
 label(ui,"SOLMERE",Rect2(52,40,250,45),32)
 label(ui,"用纸片，写给某个人",Rect2(55,83,285,28),18)
 if phase!="compose":button(ui,"工作札记",Rect2(53,260,161,102),open_notebook,true)
 hint_label=label(ui,"",Rect2(352,769,770,36),19,Color("384f43"));hint_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 button(ui,"",Rect2(450,0,590,173),func():blinds_open=1.0-blinds_open;audio.play("PAPER_SLIDE"),true)
 if phase=="hub":
  button(ui,"来信托盘",Rect2(54,457,230,116),open_tray,true)
  button(ui,"拼贴示例",Rect2(1190,388,190,45),open_example)
  button(ui,"寄一封自己的信",Rect2(1190,243,190,60),func():start_composer("SEND","",true),true)
  button(ui,"读海上来信",Rect2(1190,304,190,51),read_drift,true)
  button(ui,"纸片抽屉",Rect2(65,662,220,67),open_library,true)
  if not state.pending_replies.is_empty():button(ui,"收工 · 次日再来",Rect2(620,708,225,45),next_day)
  say("有些话适合剪下来，慢慢放在一起。")
 elif phase=="compose":
  label(ui,(current+" → "+Data.CASES[current].recipient) if mode=="HELP" else ("给海风中的某个人" if mode=="SEND" else "回一封海上来信"),Rect2(448,190,590,35),22)
  button(ui,"纸片抽屉",Rect2(62,666,223,64),open_library,true)
  button(ui,"剪开词条",Rect2(1190,571,167,40),split_selected)
  button(ui,"换张底纸",Rect2(939,323,199,42),cycle_paper)
  button(ui,"压到下面",Rect2(1190,620,167,37),func():composer.lower_selected();audio.play("PAPER_MOVE"))
  button(ui,"拿回纸片",Rect2(1190,665,167,37),func():recover_selected())
  button(ui,"留在桌上",Rect2(53,206,179,38),leave_composer)
  if mode=="HELP":button(ui,"再看看委托",Rect2(939,264,199,42),func():open_commission(current,true))
  var approved=bool(draft().get("approved",false))
  button(ui,("给 "+current+" 看看") if mode=="HELP" and not approved else "寄出  →",Rect2(932,711,202,49),show_recipient if mode=="HELP" and not approved else begin_packaging)
  say("点原件剪词 · 拖动拼贴 · 滚轮旋转 · 抓纸片右下角缩放")
  build_sources()
 queue_redraw()
func _draw() -> void:
 draw_texture_rect(ROOM,Rect2(0,-4,1440,902),false)
 # Warm light belongs to the room. The clock is read, never changed here.
 var minute=720.0
 var atmosphere=get_node_or_null("/root/WorldAtmosphere")
 if atmosphere!=null:minute=float(atmosphere.minute)
 var weights=preload("res://extensions/collage_letter/scripts/desk_lighting.gd").sky_weights(minute)
 daylight=weights.x+weights.y*0.45
 if blinds_open<0.5:
  for y in range(8,175,19):draw_rect(Rect2(407,y,683,13),Color("aa916c"))
 if daylight>0.02:
  for i in (8 if blinds_open<0.5 else 1):
   var x=360+i*64+sin(elapsed*0.18)*4
   var poly=PackedVector2Array([Vector2(x,230),Vector2(x+34 if blinds_open<0.5 else 875,230),Vector2(x+140 if blinds_open<0.5 else 1060,746),Vector2(x+60,746)])
   draw_colored_polygon(poly,Color(1,0.94,0.71,(0.08 if blinds_open<0.5 else 0.11)*daylight))
 if weights.z>0:draw_rect(Rect2(0,0,1440,810),Color(0.13,0.21,0.28,weights.z*0.30))
 if is_instance_valid(packing):return
 # Cloth-bound notebook and two different reference books, with page blocks.
 if phase!="compose":book_shape(Rect2(48,252,178,120),Color("788c78"),"FIELD NOTES")
 # Incoming letter tray, rather than a screen panel.
 draw_rect(Rect2(39,419,267,301),Color(0.28,0.18,0.1,0.18))
 draw_rect(Rect2(42,422,259,292),Color("a67d55"))
 draw_rect(Rect2(50,430,243,273),Color("cba574"))
 for i in 3:draw_line(Vector2(48,704+i*3),Vector2(297,704+i*3),Color("9a744f"),2)
 if phase=="hub":
  for i in 3:Paper.paint(self,Rect2(62+i*5,469+i*7,219,108),1,true)
 # A small physical drift box, not a community feed.
 draw_rect(Rect2(1184,231,204,123),Color(0.20,0.28,0.23,0.22))
 draw_rect(Rect2(1180,220,204,125),Color("738f87"))
 draw_rect(Rect2(1196,230,173,14),Color("344f4d"))
 draw_line(Vector2(1180,348),Vector2(1384,348),Color("a5b2a0"),4)
 if phase=="compose" or phase=="hub":
  draw_rect(Rect2(59,661,232,79),Color("946b46"));draw_rect(Rect2(63,657,224,72),Color("c49b69"));draw_arc(Vector2(175,696),17,0,PI,20,Color("674f3b"),3,true)
 if phase=="compose":
  draw_rect(Rect2(1177,555,194,157),Color("ac8157"));draw_rect(Rect2(1184,561,180,147),Color("d0ad7e"))
func book_shape(r:Rect2,color:Color,caption:String) -> void:
 draw_rect(Rect2(r.position+Vector2(5,7),r.size),Color(0.25,0.18,0.1,0.17))
 draw_rect(Rect2(r.position+Vector2(3,4),r.size),Color("e5d7b6"))
 for y in range(int(r.end.y),int(r.end.y+5),2):draw_line(Vector2(r.position.x+5,y),Vector2(r.end.x,y),Color("b4a487"),1)
 draw_rect(r,color);draw_line(r.position+Vector2(10,0),Vector2(r.position.x+10,r.end.y),color.darkened(0.18),2)
 draw_string(SERIF,r.position+Vector2(17,21),Text.show(caption),HORIZONTAL_ALIGNMENT_LEFT,r.size.x-24,10,Color("f6ebce"))
func begin_modal() -> Control:
 close_modal();modal=Control.new();modal.size=Vector2(1440,810);modal.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(modal)
 var shade=ColorRect.new();shade.color=Color(0.22,0.26,0.21,0.22);shade.size=modal.size;shade.mouse_filter=Control.MOUSE_FILTER_STOP;modal.add_child(shade)
 return modal
func modal_paper(r:Rect2) -> Control:
 var panel=Control.new();panel.position=r.position;panel.size=r.size;panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.draw.connect(func():Paper.paint(panel,Rect2(Vector2.ZERO,panel.size),1,true));modal.add_child(panel);return panel
func close_modal() -> void:
 if is_instance_valid(modal):remove_child(modal);modal.queue_free()
 modal=null;book_busy=false
func open_notebook() -> void:
 begin_modal();modal_paper(Rect2(429,181,556,532))
 label(modal,"用纸片，写给某个人",Rect2(467,211,486,46),28)
 label(modal,"先到来信托盘，读一份委托。\n她留下的票据与便笺，就在你的手边。\n\n剪下几个词，放到信纸上。\n试着叠一叠，转一点，留下些空白。\n字、词、句子，都从原件上剪下来。",Rect2(467,278,470,258),23)
 label(modal,"拖动拿起 · 滚轮旋转\n拖动时抓右下角，可以拉宽或缩小。\n没有标准排版，也没有拼贴评分。",Rect2(467,547,470,110),19)
 button(modal,"合上札记",Rect2(762,659,181,36),close_modal)
func open_commission(who:String,review:bool=false) -> void:
 begin_modal();modal_paper(Rect2(385,166,672,558))
 var stories={
  "Mara":"6 月 17 日，我和姐姐坐在柠檬咖啡馆的六号桌。第二天，我坐车去了马赛。\n\n她总问我什么时候回来。我还没有答案。可那一天，我一直记得。\n\n我自己一动笔，就忍不住解释。能不能用这些纸，替我留下那一天？",
  "Theo":"以前尼科总说，我写的歌只敢在房间里唱。那次我们吵得很难看。\n\n上周，我真的在唱片店唱了《夏日杂音》。他没有来。\n\n我想让他知道，又不想郑重其事地写一封道歉信。你们贴出来的信，或许刚好。",
  "June":"十五岁时，贝尔老师在我的课本旁边写：别因为房间太小，就让自己也变得渺小。\n\n我把那一页留到了现在。想谢谢她，却总写得像一次很郑重的告别。\n\n其实我还想约她喝茶。帮我拼一封轻一点的信，好吗？"}
 label(modal,who+" 想寄给 "+Data.CASES[who].recipient,Rect2(424,201,592,48),27)
 label(modal,stories[who],Rect2(424,272,590,276),24)
 label(modal,"想留下："+Data.CASES[who].matter+"\n请别写成："+Data.CASES[who].boundary,Rect2(424,561,590,92),20)
 button(modal,"先放回",Rect2(426,664,145,40),close_modal)
 button(modal,"回到拼贴" if review else "拿这些纸，开始拼贴",Rect2(741,664,273,40),func():
  close_modal()
  if not review:start_composer("HELP",who,false))
 audio.play("PAGE_TURN",0.6)
func clear_papers() -> void:
 for p in papers.get_children():papers.remove_child(p);p.queue_free()
func open_tray() -> void:
 begin_modal();modal_paper(Rect2(376,233,683,432))
 label(modal,"来信托盘",Rect2(415,258,580,45),30)
 for i in 3:
  var who=["Mara","Theo","June"][i];var done=state.completed_cases.has(who)
  var pending=reply_ready(who)
  button(modal,("For the Letter Office · "+who) if pending else (who+(" · 已寄出" if done else " · 想请你帮忙写封信")),Rect2(415,329+i*77,601,59),func():
   if pending:open_reply(who)
   elif not done:open_commission(who))
 button(modal,"放回托盘",Rect2(841,606,175,36),close_modal)
func draft() -> Dictionary:
 if not state.drafts.has(draft_key):state.drafts[draft_key]={"pieces":[],"cuts":{},"extras":[],"approved":false,"paper_style":2}
 return state.drafts[draft_key]
func start_composer(new_mode:String,person:String,transition:bool=true) -> void:
 close_modal();clear_papers()
 if is_instance_valid(composer):remove_child(composer);composer.queue_free()
 mode=new_mode;current=person if not person.is_empty() else "Mara";phase="compose";draft_key=mode+"_"+(current if mode=="HELP" else str(int(state.drift_index)) if mode=="REPLY" else "own")
 source_page=0
 composer=Composer.new();composer.mode=mode;composer.owner_name=current;add_child(composer);move_child(composer,papers.get_index())
 composer.paper_style=int(draft().get("paper_style",2));composer.restore(draft().pieces)
 composer.changed.connect(func():draft().approved=false;defer_save())
 composer.picked.connect(func():audio.play("PAPER_PICK",0.6))
 build_ui();save_game()
 if transition:
  say("现在，你知道她要说什么了。" if current!="Theo" else "现在，你知道他要说什么了。")
  await get_tree().create_timer(0.7).timeout
  if phase=="compose":say("用这些纸片，做成她的信。" if current!="Theo" else "用这些纸片，做成他的信。")
func sources() -> Array:
 var result=[]
 if mode=="HELP":
  for d in Data.objects():
   if Data.CASES[current].ids.has(d.id):result.append(d)
 for common in Data.library():
  if common.id=="common":result.append(common)
 for id in draft().extras:
  for d in Data.library():
   if d.id==id:result.append(d)
 return result
func build_sources() -> void:
 clear_papers()
 var entries=sources()
 source_page=clampi(source_page,0,maxi(0,(entries.size()-1)/2))
 for i in range(source_page*2,mini(entries.size(),source_page*2+2)):
  var d=entries[i];var p=Piece.new();p.setup(d,Vector2(67,282+(i%2)*174),Vector2(283,158));p.movable=false;papers.add_child(p)
  p.examined.connect(func(_p):open_cut(d));p.gui_input.connect(func(e):
   if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and e.pressed:open_cut(d))
 if entries.size()>2:
  button(ui,"‹",Rect2(67,625,62,35),func():source_page-=1;build_ui())
  button(ui,"›",Rect2(287,625,62,35),func():source_page+=1;build_ui())
  label(ui,str(source_page+1)+" / "+str(ceili(entries.size()/2.0)),Rect2(169,629,90,31),18)
 if entries.is_empty():label(ui,"抽屉里有小镇的纸。\n挑一张，剪几个词。",Rect2(71,459,228,110),23)
func open_cut(d:Dictionary) -> void:
 begin_modal();cut_source=d
 var sheet=CutSheet.new();sheet.data=d;sheet.position=Vector2(426,166);sheet.size=Vector2(555,495);sheet.removed=draft().cuts.get(d.id,[]).duplicate();modal.add_child(sheet)
 sheet.sound.connect(func(event):audio.play(event,0.6))
 sheet.cut.connect(func(region,index):
  var removed:Array=draft().cuts.get(d.id,[]);removed.append(index);removed.sort();draft().cuts[d.id]=removed
  var id=d.id+"_"+str(index)
  var count=composer.fragments.size()
  composer.add_fragment({"id":id,"instance_id":id,"word":region.word,"tags":region.tags,"fragment":true,"style":d.style,"print_variant":region.get("print_variant",CutStyle.variant(d)),"source":d.id,"cut_index":index},Vector2(531+(count%3)*43,315+((count/3)%6)*54));audio.play("PAPER_CUT");defer_save())
 button(modal,"拿起剪刀",Rect2(442,679,157,43),func():sheet.scissors=true;sheet.queue_redraw();audio.play("TOOL_PICK"))
 button(modal,"‹",Rect2(614,679,56,43),func():sheet.turn_page(-1))
 button(modal,"›",Rect2(686,679,56,43),func():sheet.turn_page(1))
 button(modal,"放回桌上",Rect2(783,679,183,43),func():close_modal();build_ui())
 label(modal,"拿起剪刀，点词剪下。放回桌上后，还能剪成单字。",Rect2(441,730,595,37),19,Color("f4eedc"))
 audio.play("PAPER_PICK")
func open_library() -> void:
 begin_modal();modal_paper(Rect2(372,175,711,540))
 label(modal,"PAPER DRAWER / 小镇的纸",Rect2(404,202,631,39),26)
 if phase=="compose":
  label(modal,"短句、词组、单字，都能剪下来重新组合。",Rect2(406,246,613,39),19)
  var entries=Data.library().filter(func(d):return d.id!="common")
  for i in entries.size():
   var d=entries[i];var used=draft().extras.has(d.id)
   var b=button(modal,d.title+(" · 已拿出" if used else ""),Rect2(406+(i%2)*318,299+(i/2)*65,303,52),func():borrow_source(d.id))
   b.disabled=used
  for i in state.paper_library.size():
   var word=str(state.paper_library[i]);button(modal,word,Rect2(407+i*163,586,153,46),func():take_library_word(word))
 else:
  label(modal,"收到的纸片会留在这里。\n\n"+"  /  ".join(state.paper_library),Rect2(405,352,621,210),26)
 button(modal,"推回抽屉",Rect2(856,657,175,42),close_modal);audio.play("PAPER_SLIDE")
 var target=modal.position;modal.position.y=45;modal.modulate.a=0.5
 var tw=create_tween();tw.tween_property(modal,"position",target,0.35);tw.parallel().tween_property(modal,"modulate:a",1.0,0.35)
func borrow_source(id:String) -> bool:
 if phase!="compose" or draft().extras.has(id):return false
 draft().extras.append(id);close_modal();build_ui();save_game();return true
func take_library_word(word:String) -> void:
 var id="library_"+word
 for p in composer.fragments:
  if p.data.id==id:say("这片已经在桌上了。");close_modal();return
 composer.add_fragment({"id":id,"word":word,"tags":{"CONTINUITY":2} if word=="STILL" else {},"fragment":true,"style":3},Vector2(535,360));close_modal();build_ui();save_game()
func recover_selected() -> void:
 if not is_instance_valid(composer.selected):say("先拿起想放回的纸片。");return
 var d=composer.selected.data
 if d.has("source") and d.has("cut_index"):
  var siblings=composer.fragments.filter(func(p):return p!=composer.selected and p.data.get("source","")==d.source and p.data.get("cut_index",-1)==d.cut_index)
  if siblings.is_empty():
   var removed:Array=draft().cuts.get(d.source,[]);removed.erase(d.cut_index);draft().cuts[d.source]=removed
 composer.remove_selected();audio.play("PAPER_SLIDE");save_game()
func split_selected() -> void:
 if not is_instance_valid(composer.selected):say("先拿起要剪开的词条，再用剪刀。");return
 if composer.split_selected():audio.play("PAPER_CUT");save_game();say("剪开的每个字，都可以重新排列。")
 else:say("这已经是一小片了。")
func cycle_paper() -> void:
 var styles=[2,1,15]
 composer.paper_style=styles[(styles.find(composer.paper_style)+1)%styles.size()]
 draft().paper_style=composer.paper_style;composer.queue_redraw();audio.play("PAPER_SLIDE");save_game()
func open_example() -> void:
 begin_modal()
 modal.get_child(0).color=Color(0.17,0.21,0.19,0.92)
 var preview=Composer.new();preview.read_only=true;preview.paper_style=2;modal.add_child(preview)
 for d in Data.example():
  var paper=preview.add_fragment(d.data,Vector2(d.at[0],d.at[1]));paper.scale=Vector2(d.zoom,d.zoom);paper.rotation_degrees=d.angle
 label(modal,"一封只用纸片拼成的信",Rect2(915,329,310,82),27,Color("f2ead9"))
 label(modal,"不同的字，从不同的纸上来。\n留一点空白，让它们一起说话。",Rect2(915,430,310,100),20,Color("f2ead9"))
 button(modal,"合上示例",Rect2(941,596,190,45),close_modal)
 audio.play("PAGE_TURN")
func show_recipient() -> bool:
 var case=Data.CASES[current];var verdict=Data.validate(composer.placed(),case.required,case.avoided)
 begin_modal();modal_paper(Rect2(417,318,610,278));label(modal,current,Rect2(451,337,527,32),23)
 var text_value="…这个可以。她会知道 June 17 是什么意思。"
 if not verdict.violations.is_empty():text_value="这听起来像我会回去。我不能答应她这个。" if current=="Mara" else ("我不想把这写成正式的道歉。" if current=="Theo" else "我还会去看她。别写成告别。")
 elif not verdict.missing.is_empty():text_value="我看不出 June 17 还在这里。那是我唯一想让她知道的。" if current=="Mara" else ("得让 Nico 知道，我真的唱过那首歌了。" if current=="Theo" else "我想谢谢她写在页边的那句话。")
 elif current!="Mara":text_value="对，就是这个。我自己一直没能这样说出来。"
 label(modal,text_value,Rect2(451,390,536,124),26)
 draft().approved=verdict.passed
 button(modal,"我再看看" if not verdict.passed else "收好，准备寄出",Rect2(753,530,235,42),func():close_modal();build_ui())
 save_game();return verdict.passed
func begin_packaging() -> void:
 if busy or phase!="compose":return
 if mode=="HELP" and not Data.validate(composer.placed(),Data.CASES[current].required,Data.CASES[current].avoided).passed:show_recipient();return
 if composer.placed().is_empty():say("先在信纸上留下一片纸，再让它出发。");return
 busy=true;save_game()
 await RenderingServer.frame_post_draw
 var image=get_viewport().get_texture().get_image().get_region(Rect2i(493,233,365,516));image.save_png(preview_path)
 var texture=ImageTexture.create_from_image(image);composer.hide();papers.hide();clear_ui()
 hint_label=label(ui,"拿住信纸下沿，轻轻向上折。",Rect2(387,210,724,48),24);hint_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 packing=Packing.new();packing.preview=texture;packing.mode=mode;packing.sound.connect(func(event):audio.play(event));packing.hint.connect(say);packing.finished.connect(on_sent);add_child(packing);move_child(packing,ui.get_index());busy=false
 button(ui,"先放回桌上",Rect2(65,717,190,42),cancel_packaging)
func cancel_packaging() -> void:
 if is_instance_valid(packing):packing.queue_free();packing=null
 composer.show();papers.show();build_ui();audio.play("PAPER_SLIDE")
func on_sent(stamp_name:String) -> void:
 var pieces=composer.serialize()
 if mode=="HELP":
  if not state.completed_cases.has(current):state.completed_cases.append(current);state.pending_replies.append({"who":current,"day":state.day+1})
  solmere_completed=true;letter_mode="npc"
 else:
  state.drift_letters_sent.append({"letter_id":"local_"+str(Time.get_unix_time_from_system()),"mode":mode,"reply_to":drift_letter().letter_id if mode=="REPLY" else "","fragment_list":pieces,"stamp":stamp_name,"paper_type":"cotton","day":state.day});audio.play("SEA_WAVE",0.75)
  if mode=="REPLY":state.drift_index=(int(state.drift_index)+1)%drift_pool().size()
 state.drafts.erase(draft_key)
 if is_instance_valid(packing):packing.queue_free();packing=null
 composer.queue_free();composer=null;papers.show();phase="hub";build_ui();save_game();say("Sent into Solmere. 信在路上了。")
func leave_composer() -> void:
 save_game();close_modal();composer.queue_free();composer=null;clear_papers();phase="hub";build_ui();save_game()
func next_day() -> void:
 if busy:return
 state.day+=1;audio.play("SEA_WAVE",0.55);save_game();open_tray()
func reply_ready(who:String) -> bool:
 for pending in state.pending_replies:
  if pending.who==who and pending.day<=state.day:return true
 return false
func open_reply(who:String) -> void:
 begin_modal();modal_paper(Rect2(438,197,572,502))
 label(modal,"FOR THE LETTER OFFICE",Rect2(475,225,491,45),25)
 label(modal,Data.CASES[who].reply,Rect2(475,300,486,215),25)
 var word=Data.CASES[who].reward
 label(modal,word,Rect2(554,540,318,61),36)
 button(modal,"留下这片纸",Rect2(723,633,237,43),func():
  if not state.paper_library.has(word):state.paper_library.append(word);state.received_fragments.append({"id":who+"_reply","word":word})
  for i in range(state.pending_replies.size()-1,-1,-1):
   if state.pending_replies[i].who==who:state.pending_replies.remove_at(i)
  close_modal();build_ui();save_game();audio.play("PAPER_PICK"))
func drift_pool() -> Array:
 var loaded=JSON.parse_string(FileAccess.get_file_as_string("res://extensions/collage_letter/assets/v3/DriftPool.json"));return loaded.letters
func drift_letter() -> Dictionary:return drift_pool()[int(state.drift_index)%drift_pool().size()]
func read_drift() -> void:
 if phase!="hub":return
 var entry=drift_letter();begin_modal();modal_paper(Rect2(441,183,567,544))
 label(modal,"海上来信 · 本地虚构示例",Rect2(477,208,490,39),20)
 for i in entry.fragment_list.size():
  var f=entry.fragment_list[i];var p=Piece.new();p.setup({"id":str(i),"word":f.word,"fragment":true,"style":int(f.get("style",1))},Vector2(474+f.position[0],269+f.position[1]),Vector2(maxf(94,str(f.word).length()*19+25),51));p.rotation_degrees=f.rotation;p.movable=false;modal.add_child(p)
 label(modal,"留下其中一片，回信给它的主人。",Rect2(478,610,473,35),19)
 for i in entry.shareable_fragments.size():
  var word=str(entry.shareable_fragments[i]);button(modal,word,Rect2(476+i*162,663,151,43),func():keep_shared(word))
 button(modal,"放回",Rect2(1046,222,96,41),close_modal)
 button(modal,"另一封 ›",Rect2(1046,284,120,41),func():state.drift_index=(int(state.drift_index)+1)%drift_pool().size();save_game();read_drift())
 if not state.drift_letters_received.has(entry.letter_id):state.drift_letters_received.append(entry.letter_id)
 save_game();audio.play("PAGE_TURN")
func keep_shared(word:String) -> bool:
 var entry=drift_letter()
 if not entry.shareable_fragments.has(word):return false
 var already=str(state.shared_fragment_history.get(entry.letter_id,""))
 if not already.is_empty() and already!=word:return false
 state.shared_fragment_history[entry.letter_id]=word
 start_composer("REPLY","",false)
 var id="shared_"+entry.letter_id
 var found=false
 for p in composer.fragments:found=found or p.data.id==id
 if not found:composer.add_fragment({"id":id,"word":word,"tags":{},"fragment":true,"style":3},Vector2(540,340))
 save_game();return true
func save_game() -> void:
 if state.is_empty():return
 state.phase=phase;state.current=current;state.mode=mode;state.consulted=consulted
 if phase=="compose" and is_instance_valid(composer):draft().pieces=composer.serialize()
 var temp_path=save_path+".tmp";var file=FileAccess.open(temp_path,FileAccess.WRITE)
 if file==null:say("这次还没存好，纸片仍在桌上。请稍后再试。");return
 file.store_string(JSON.stringify(state,"\t"));file.close()
 var error=DirAccess.rename_absolute(temp_path,save_path)
 if error!=OK:say("这次还没存好，纸片仍在桌上。")
func _notification(what:int) -> void:
 if what==NOTIFICATION_WM_CLOSE_REQUEST:save_game()
func _exit_tree() -> void:
 if is_instance_valid(ambient):ambient.stop()
 if is_instance_valid(audio):audio.shutdown()
