extends SceneTree
## Reproducible real gameplay recording; no rendered mock screens or network actors.
var game
var cursor:Control
var caption:Label
var pointer:=Vector2(980,785)
var down:=false
var quick:=false
var failures:=0
var chapter_index:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,why:String)->void:
	if not value:failures+=1;push_error(why)
func pause(seconds:float)->void:await create_timer(seconds*(0.10 if quick else 1.0)).timeout
func chapter(value:String)->void:
	caption.text=value;print("DEMO: ",value);await pause(2.5)
	chapter_index+=1;var output:=OS.get_environment("COLLAGE_TEST_OUTPUT")
	if not output.is_empty():await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join("tour-%02d.png"%chapter_index))
func mouse(at:Vector2,pressed:bool)->void:
	pointer=at;down=pressed;cursor.queue_redraw()
	var e:=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;root.push_input(e,true);await process_frame
func click(at:Vector2)->void:await mouse(at,true);await mouse(at,false)
func glide(at:Vector2,seconds:float=0.65)->void:
	var origin:=pointer;var frames:=maxi(2,int(seconds*30*(0.15 if quick else 1.0)))
	for i in range(1,frames+1):
		pointer=origin.lerp(at,smoothstep(0,1,float(i)/frames));cursor.queue_redraw()
		var e:=InputEventMouseMotion.new();e.position=pointer;e.global_position=pointer;e.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;root.push_input(e,true);await process_frame
func drag(a:Vector2,b:Vector2,seconds:float=0.8)->void:
	await glide(a,.3);await mouse(a,true);await glide(b,seconds);await mouse(b,false);await pause(.5)
func button(node:Button)->void:await glide(node.get_global_rect().get_center(),.35);await click(node.get_global_rect().get_center());await pause(.5)
func run()->void:
	quick="--tour-quick" in OS.get_cmdline_user_args()
	game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true;game.L.language="zh";game.audio.muted=false;game.get_node("DeskLighting").preview_minute=840
	var layer:=CanvasLayer.new();layer.layer=110;root.add_child(layer)
	cursor=Control.new();cursor.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(cursor)
	cursor.draw.connect(func():cursor.draw_circle(pointer+Vector2(1,2),7,Color(0.2,0.25,0.22,0.25));cursor.draw_circle(pointer,5 if down else 4,Color("fff4d5"));cursor.draw_arc(pointer,8 if down else 6,0,TAU,24,Color("647e6b"),1.4,true))
	var band:=ColorRect.new();band.color=Color(0.19,0.24,0.21,0.95);band.position=Vector2(0,865);band.size=Vector2(1440,35);band.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(band)
	caption=Label.new();caption.position=Vector2(65,868);caption.size=Vector2(1320,40);caption.add_theme_font_override("font",game.letter_text_node.HAND);caption.add_theme_font_size_override("font_size",18);caption.add_theme_color_override("font_color",Color("f5e8cc"));layer.add_child(caption)
	preload("res://scripts/showcase_draft.gd").apply(game);await pause(2)
	await chapter("Solmere · 用捡来的纸片，给某个人写一封信")
	await drag(Vector2(1080,241),Vector2(1080,274));await pause(2)
	await chapter("素材夹从桌上的本子展开；照片四张一页，经典文字一张一页")
	await button(game.desk.get_node("Object_folio"));await create_timer(1.2).timeout
	game.desk.change_book_group("照片");await create_timer(.8).timeout;await pause(3)
	await button(game.desk.shelf.get_node("BookNext"));await create_timer(.8).timeout
	game.desk.change_book_group("文字");await create_timer(.8).timeout;await pause(4)
	game.desk.change_book_group("票据");await create_timer(.8).timeout;await pause(3)
	await button(game.desk.shelf.get_node("BookNext"));await create_timer(.8).timeout;await pause(2)
	game.desk.toggle("shelf");await create_timer(1.2).timeout
	await chapter("每一张纸都是独立物件：拿起、叠放、拉伸、旋转，再轻轻放下")
	await drag(Vector2(773,648),Vector2(804,645));await pause(1)
	var handles=game.get_node("PieceHandles")
	if game.selected!=null:
		# Drag actual rendered handles, using their public hit geometry.
		var bounds:Rect2=game.selected.bounds();var p:Vector2=game.selected.to_global(bounds.end)
		await drag(p,p+Vector2(20,18))
		var turn:Vector2=handles.rotate_point();await drag(turn,game.selected.position+(turn-game.selected.position).rotated(0.12));await pause(1)
	game.select(null);await pause(2)
	await chapter("拼贴是主体。字句只是补充：称呼、今天的小事、最后的落款")
	game.set_tool("write");await process_frame
	game.desk.writing.position_caret(3);game.desk.writing.insert_text_at_caret("\n今天也想到了你。")
	await pause(4);game.choose_letter_ink(1);await pause(1);game.choose_letter_ink(0)
	game.set_tool("move");await pause(2)
	await chapter("打字机有自己的纸；按下字母键，再把打好的小纸片剪下来")
	await button(game.desk.get_node("Object_typewriter"));await process_frame
	var station=game.desk.get_node("TypewriterStation")
	for key in ["Key_s","Key_e","Key_a"]:await button(station.get_node(key))
	await pause(2)
	# Existing typed-sheet cut control opens a real crop gesture.
	station.get_node("CutTypedPage").pressed.emit();await process_frame
	await drag(station.global_position+Vector2(97,49),station.global_position+Vector2(279,139))
	game.typewriter_open=false;game.build_ui();await pause(2)
	await chapter("胶带、水粉与涂鸦留在纸上；纸片边缘会挡住涂色")
	game.tools_open=true;game.set_tool("tape");game.tape_style=5;await pause(2)
	await drag(Vector2(671,482),Vector2(735,494));await pause(1)
	game.set_tool("brush");game.paint.scope="material";game.paint.dip(3);await pause(2)
	await drag(Vector2(734,521),Vector2(787,537));await pause(1)
	game.tools_open=false;game.set_tool("move")
	# Restore the authored composition through the same standalone demo initializer.
	preload("res://scripts/showcase_draft.gd").apply(game);await pause(2)
	await chapter("写完的字留在纸上。折起、装进信封，再亲手封好")
	await button(game.desk.get_node("Object_envelope"));while game.busy:await process_frame
	check(game.stage=="FOLDING","Fold action opens after writing finish")
	await drag(Vector2(720,655),Vector2(720,430),1.5);await create_timer(.6).timeout
	await drag(Vector2(720,240),Vector2(720,455),1.5);await create_timer(.6).timeout
	await click(Vector2(720,450));await pause(1)
	await drag(Vector2(720,290),Vector2(720,650),2);await pause(1)
	check(game.finishing.inserted,"Folded paper slides into envelope")
	await drag(Vector2(720,270),Vector2(720,525),1.5)
	await chapter("划亮火柴，点烛、融蜡、倾倒、压下印章——每一步由你完成")
	await glide(Vector2(280,690));await mouse(pointer,true)
	await glide(Vector2(111,696));await glide(Vector2(221,696),1.0);await glide(Vector2(160,461),1.2);await mouse(pointer,false);await pause(1)
	check(game.finishing.candle,"Match lights candle")
	await drag(Vector2(310,600),Vector2(355,380))
	await drag(Vector2(355,380),Vector2(160,421));await create_timer(3.4).timeout
	await drag(Vector2(160,421),Vector2(720,470),1.6);await create_timer(1.3).timeout
	await glide(Vector2(1160,490));await mouse(pointer,true);await glide(Vector2(720,525),1.2);await create_timer(1.2).timeout;await mouse(pointer,false);await create_timer(2).timeout
	check(game.stage=="SEND","Wax cools before mailbox")
	await chapter("连同照片、文字和火漆，把这封信放进信箱，合上箱盖")
	await click(Vector2(475,535));await drag(Vector2(475,535),Vector2(1080,435),2);await create_timer(.95).timeout
	await drag(Vector2(1100,305),Vector2(1100,470),1.2);await pause(3)
	check(game.stage=="END","Mailbox finishes the envelope loop")
	game.restart();await pause(1)
	await chapter("海上有两只瓶子：一只带来别人的话，另一只等你写下自己的信")
	game.receive_bottle();await process_frame
	var incoming
	for child in game.get_children():
		if child.get_script()==preload("res://scripts/incoming_bottle.gd"):incoming=child
	await drag(Vector2(910,575),Vector2(720,560),1.4)
	await glide(Vector2(720,372));await mouse(pointer,true);await glide(Vector2(720,255),.9);await glide(Vector2(1140,390),.8);await mouse(pointer,false)
	await pause(1)
	await drag(incoming.bottle,incoming.bottle+Vector2(-285,-20),1.8)
	await create_timer(4.8).timeout
	check(incoming.stage=="READ","Tipped bottle releases its paper and the roll opens by itself")
	await click(Vector2(660,430));await pause(3)
	await chapter("小岸，十五岁：练习本上的飞船，是他还没舍得放下的梦想")
	await pause(7)
	var dock
	for child in game.get_children():
		if child.get_script()==game.BottleDock:dock=child
	await dock.show_example(true);await pause(5)
	for index in [1,2]:
		await button(dock.letters_box.get_node("LocalExampleLetter"+str(index)));await pause(6)
		await dock.show_example(true);await pause(5)
	await button(dock.letters_box.get_node("LocalExampleLetter"));await pause(2);dock.close()
	game.SeaExample.start_reply(game);await pause(2)
	await chapter("回信把原信放在手边。用一张远方的照片、一句‘船先留着’，认真回应他")
	await pause(5)
	await button(game.desk.get_node("Object_envelope"));while game.busy:await process_frame
	check(game.stage=="BOTTLE","Reply goes to bottle ritual")
	await chapter("从下沿慢慢卷起信纸，拔开软木塞，从瓶口放入，再按紧塞子")
	await drag(Vector2(490,650),Vector2(490,270),2)
	await drag(Vector2(1000,329),Vector2(1120,240),1.2)
	await glide(Vector2(490,420));await mouse(pointer,true);await glide(Vector2(1000,220),1.4);await glide(Vector2(1000,558),2);await mouse(pointer,false)
	await drag(Vector2(1120,240),Vector2(1000,329),1.3)
	check(game.bottle_finish.phase=="SEA","Paper is inside and cork is sealed")
	await chapter("海浪会带它走。认真回一封，再写一封，让这段交流继续")
	await drag(Vector2(1000,530),Vector2(1270,550),2);await create_timer(4.1).timeout;await pause(4)
	check(game.stage=="END" and game.bottle_published_id==0,"Local example completes without publishing")
	game.restart();await process_frame
	var conversation=game.ui.get_child(1)
	for i in conversation.lines.size()*2:
		if not game.conversation_open:break
		conversation.advance()
	await process_frame
	check(game.letter_text.is_empty() and game.pieces_root.get_child_count()==0,"Next task starts blank, with no demo scraps")
	await chapter("下一封任务是空白信纸。示例留在过去，接下来由你 DIY。")
	await pause(3)
	game.audio.shutdown();game.queue_free();await process_frame;await process_frame
	print("DEMO_TOUR: ","PASS" if failures==0 else "FAIL"," failures=",failures);quit(failures)
