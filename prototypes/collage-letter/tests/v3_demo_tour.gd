extends "v3_flow_test.gd"
## Deterministic live gameplay capture, including recorded in-game sound.
var pointer=Vector2(710,740)
var cursor:Control
var captions:Label
func pause(seconds:float) -> void:await create_timer(seconds).timeout
func chapter(text_value:String) -> void:
 captions.text=text_value;print("V3 TOUR: ",text_value);await pause(2.4)
func mouse(at:Vector2,down:bool) -> void:
 pointer=at;cursor.queue_redraw();await super.mouse(at,down)
func move(at:Vector2) -> void:
 pointer=at;cursor.queue_redraw();await super.move(at)
func drag(a:Vector2,b:Vector2) -> void:
 await move(a);await mouse(a,true)
 for i in range(1,25):await move(a.lerp(b,smoothstep(0,1,float(i)/24)))
 await mouse(b,false);await pause(0.6)
func finish_current_letter() -> void:
 await game.begin_packaging();await pause(2)
 await drag(Vector2(580,673),Vector2(580,553));await pause(1)
 await drag(Vector2(580,481),Vector2(580,364));await pause(1)
 await drag(Vector2(580,350),Vector2(944,431));await pause(1.4)
 await click(Vector2(634,687));await pause(1.5)
 await click(Vector2(1217,708));await pause(2)
func cut_word(source_id:String,index:int) -> void:
 await super.cut_word(source_id,index);await pause(0.8)
func lay_fragment(index:int,at:Vector2,zoom:float=0.76) -> void:
 var p=game.composer.fragments[index]
 await drag_paper(p,at)
 var corner=p.position+p.size-Vector2(7,7)
 await drag(corner,corner+p.size*(zoom-1.0))
func run() -> void:
 game=load("res://Main.tscn").instantiate();root.add_child(game);await process_frame
 var layer=CanvasLayer.new();layer.layer=20;root.add_child(layer)
 cursor=Control.new();cursor.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(cursor)
 cursor.draw.connect(func():cursor.draw_circle(pointer,5,Color("f6efd9"));cursor.draw_arc(pointer,8,0,TAU,24,Color("52685d"),1,true))
 var backing=ColorRect.new();backing.position=Vector2(0,761);backing.size=Vector2(1440,49);backing.color=Color("3f5148");backing.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(backing)
 captions=game.label(layer,"",Rect2(65,771,1310,38),21,Color("f3ecd9"));captions.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 await chapter("索尔米尔书信事务所 · 中文实时玩法演示（本地虚构来信）")
 await chapter("纯拼贴：不打字，不手写。每一个字，都从真实可剪的素材里来。")
 game.open_example();await pause(7);game.close_modal()
 await chapter("左侧纸签就是素材分类；翻页时，纸始终留在书脊上。")
 await click(Vector2(61,176));await pause(2);await click(Vector2(428,546));await pause(2)
 await chapter("不用解谜。打开来信，读清她想说的话，就能开始拼贴。")
 await click(Vector2(1286,206));await pause(2);await click(Vector2(717,358));await pause(7)
 await chapter("玛拉记得与姐姐在咖啡馆的那一天，但还不能答应回家。")
 await click(Vector2(866,685));await pause(3)
 await chapter("咖啡票、车票、旧便笺就在手边。剪几个词，开始你的信。")
 game.borrow_source("novel");game.borrow_source("menu");game.borrow_source("thanks")
 await cut_word("novel",0);await cut_word("receipt",0);await cut_word("receipt",1)
 await cut_word("menu",7);await cut_word("thanks",2);await cut_word("menu",0)
 var positions=[Vector2(610,238),Vector2(661,309),Vector2(599,424),Vector2(733,443),Vector2(625,538),Vector2(608,636)]
 for i in game.composer.fragments.size():await lay_fragment(i,positions[i],0.76)
 await chapter("照片也能拼进去。点开相册，把它从收纳盘放到信上。")
 await click(Vector2(67,416));await pause(1);await click(Vector2(428,546));await pause(1);await click(Vector2(300,300));await pause(1)
 await drag_paper(game.composer.fragments.back(),Vector2(764,535))
 await click(Vector2(1237,641));await pause(1);await drag_paper(game.composer.fragments.back(),Vector2(783,528))
 await chapter("字句不必很多。只要让她认出，那一天仍留在这里。")
 game.show_recipient();await pause(4);game.close_modal();game.build_ui()
 await chapter("折两次，放进信封，贴上一枚灯塔邮票，再盖下邮戳。")
 await finish_current_letter()
 check(game.state.completed_cases.has("Mara"),"Recorded tour sends first request")
 await chapter("第二天，来信托盘里多了一封回信。她留下的「依然」，也会成为你的纸片。")
 game.next_day();game.open_reply("Mara");await pause(5);await click(Vector2(820,654));await pause(2)
 game.start_composer("SEND","",false)
 game.borrow_source("daily");game.borrow_source("novel");game.borrow_source("coast");game.borrow_source("menu")
 await cut_word("daily",3);await cut_word("novel",8);await cut_word("daily",4)
 await cut_word("menu",8);await cut_word("flyer",0) if game.borrow_source("flyer") else await pause(0.1)
 await cut_word("common",23);await cut_word("coast",0)
 var free_positions=[Vector2(599,241),Vector2(760,253),Vector2(648,347),Vector2(599,456),Vector2(760,457),Vector2(640,573),Vector2(776,587)]
 for i in game.composer.fragments.size():await lay_fragment(i,free_positions[i])
 await chapter("也可以寄自己的心事。自由信件没有评分，不要求猜中谁的意思。")
 await finish_current_letter();check(game.state.drift_letters_sent.size()==1,"Recorded free letter actually sends")
 await chapter("读一封本地示例来信。保留其中的一片，再拼一封回信。")
 game.read_drift();await pause(5);game.keep_shared("HOME");game.take_library_word("STILL")
 game.borrow_source("novel");await cut_word("novel",10);await lay_fragment(2,Vector2(602,551),0.86)
 await drag_paper(game.composer.fragments[0],Vector2(611,245));await drag_paper(game.composer.fragments[1],Vector2(721,383))
 await pause(4);await finish_current_letter();check(game.state.drift_letters_sent.size()==2,"Recorded reply actually sends")
 await chapter("自己的下一封信仍是空白。留下的纸片会一直在，等待你新的拼贴。")
 game.start_composer("SEND","",false);await pause(4)
 game.queue_free();layer.queue_free();await process_frame;await process_frame
 print("V3_DEMO_TOUR: ","PASS" if failures==0 else "FAIL"," failures=",failures);quit(failures)
