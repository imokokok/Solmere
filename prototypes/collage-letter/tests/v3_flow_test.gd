extends SceneTree
var game
var failures=0
var checks=0
var output=""
func _initialize() -> void:call_deferred("run")
func check(ok:bool,why:String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(why)
func mouse(at:Vector2,down:bool) -> void:
 var e=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true);await process_frame
func move(at:Vector2) -> void:
 var e=InputEventMouseMotion.new();e.position=at;e.global_position=at;e.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(e,true);await process_frame
func click(at:Vector2) -> void:await mouse(at,true);await mouse(at,false)
func drag(a:Vector2,b:Vector2) -> void:
 await move(a);await mouse(a,true)
 for i in range(1,8):await move(a.lerp(b,float(i)/7.0))
 await mouse(b,false);await create_timer(0.15).timeout
func clue(id:String):
 for p in game.papers.get_children():
  if p.data.id==id:return p
 return null
func drag_paper(p,target:Vector2) -> void:
 # Select a paper on top as a player can, then use actual viewport events.
 p.move_to_front();await process_frame
 var grab=p.position+p.size/2
 await drag(grab,grab+target-p.position)
func snap_pair(left_id:String,right_id:String) -> void:
 var left=clue(left_id);var right=clue(right_id)
 await drag_paper(left,Vector2(454,343))
 await drag_paper(right,left.position+Vector2(left.size.x,0).rotated(left.rotation))
 check(left.source_ids.size()==2,"Torn halves snap through real mouse input: "+left_id)
func snap(name_text:String) -> void:
 if output.is_empty():return
 await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join(name_text+".png"))
func cut_word(source_id:String,index:int) -> void:
 var d
 for candidate in game.sources():
  if candidate.id==source_id:d=candidate
 check(d!=null,"Cut source is actually available: "+source_id)
 if d==null:return
 game.open_cut(d);await process_frame
 var sheet
 for node in game.modal.get_children():
  if node.get_script()==preload("res://scripts/v3/cut_sheet.gd"):sheet=node
 sheet.page=index/6;sheet.queue_redraw();await process_frame
 await click(Vector2(530,700))
 var points=sheet.path(index)
 await mouse(sheet.position+points[0],true)
 for i in range(1,5):await move(sheet.position+points[i])
 await mouse(sheet.position+points[4],false)
 check(sheet.removed.has(index),"Tracing four corners cuts an actual word: "+source_id)
 await snap("cut-"+source_id)
 game.close_modal();game.build_ui();await process_frame
func run() -> void:
 output=OS.get_environment("COLLAGE_TEST_OUTPUT")
 game=load("res://Main.tscn").instantiate();root.add_child(game);await process_frame
 check(game.phase=="hub","Default desk opens directly to letters, without a puzzle")
 check(not game.has_method("check_group") and not game.has_method("assign_recipient"),"Sorting and recipient puzzle APIs are removed")
 check(not game.ui.find_children("*","Button",true,false).any(func(b):return "名录" in b.text or "核对" in b.text),"No puzzle buttons remain")
 await snap("01-direct-desk")
 await click(Vector2(166,542));await process_frame
 await click(Vector2(717,358));await process_frame
 check(game.modal.find_children("*","Label",true,false).any(func(l):return "六号桌" in l.text),"Player first reads the resident's personal reason")
 await snap("02-mara-request")
 await click(Vector2(866,685));await process_frame
 check(game.phase=="compose" and game.current=="Mara","Read request and immediately start collage")
 for who in ["Theo","June"]:
  game.leave_composer();game.open_commission(who);await process_frame
  await click(Vector2(866,685));await process_frame
  check(game.phase=="compose" and game.current==who,"Every commission opens without prerequisites: "+who)
 game.leave_composer();game.start_composer("HELP","Mara",false);await process_frame
 check(game.composer.fragments.is_empty(),"DIY starts with a genuinely blank paper")
 check(not game.has_method("open_typing"),"Typing entry and its callable implementation are removed")
 check(game.find_children("*","LineEdit",true,false).is_empty(),"No keyboard writing field exists")
 var vocabulary=[]
 for source in game.Data.library():
  for region in source.cuts:vocabulary.append(game.Text.show(region.word))
 check(vocabulary.size()>90,"Modern paper vocabulary has enough words and connective scraps")
 for example in game.Data.example():check(vocabulary.has(example.data.word),"Example is achievable from real cuttable materials: "+example.data.word)
 game.open_example();await snap("03-pure-collage-example");game.close_modal()
 check(game.sources().any(func(d):return d.id=="receipt"),"Same original receipt carries into composer")
 await snap("04-blank-composer")
 await cut_word("receipt",0)
 check(game.composer.fragments.size()==1,"One cut creates one fragment")
 check(game.borrow_source("flyer"),"First extra material allowed")
 check(game.borrow_source("daily"),"Second extra material allowed")
 check(game.borrow_source("menu"),"Pure collage does not impose arbitrary two-source limits")
 await cut_word("flyer",0)
 var f=game.composer.fragments[0];await drag_paper(f,Vector2(528,346));var f2=game.composer.fragments[1];await drag_paper(f2,Vector2(588,468))
 var old_scale=f2.scale;await drag(f2.position+f2.size-Vector2(7,7),f2.position+f2.size+Vector2(28,12));check(f2.scale!=old_scale,"Direct corner handle resizes without side-panel buttons")
 check(game.composer.placed().size()==2,"Fragments sit on letter")
 game.composer.selected=f2
 check(game.composer.split_selected(),"A printed word can be cut into independently draggable characters")
 check(game.composer.fragments.size()==3,"Cutting a two-character word preserves two separate paper pieces")
 for part in game.composer.fragments.duplicate():
  if part.data.has("phrase_id"):
   game.composer.selected=part;game.recover_selected()
 check(not game.draft().cuts.flyer.has(0),"Source word returns only after all cut letters are returned")
 await cut_word("flyer",0);await drag_paper(game.composer.fragments.back(),Vector2(600,480))
 var segmented=[{"id":"p0","phrase_id":"phrase","segment_index":0,"segment_count":2,"original_tags":{"SHARED_MEMORY":3}},{"id":"p1","phrase_id":"phrase","segment_index":1,"segment_count":2,"original_tags":{"SHARED_MEMORY":3}}]
 check(game.Data.validate(segmented,{"SHARED_MEMORY":2},{}).passed,"Complete cut phrase retains its meaning")
 check(not game.Data.validate([segmented[0]],{"SHARED_MEMORY":2},{}).passed,"One letter alone cannot pretend to carry a whole phrase")
 check(game.show_recipient(),"Mara accepts shared memory without return promise")
 await snap("05-mara-response");game.close_modal();game.build_ui()
 # Three independent valid layouts; arbitrary typed text cannot satisfy the brief.
 var a={"id":"a","tags":{"SHARED_MEMORY":3}};var b={"id":"b","tags":{"CONTINUITY":2}};var c={"id":"c","tags":{"RETURN":-2}};var d={"id":"d","tags":{"SHARED_MEMORY":2}}
 for arrangement in [[a,b,c],[a,d,b],[d,b,c]]:check(game.Data.validate(arrangement,{"SHARED_MEMORY":2},{"RETURN":3}).passed,"Distinct composition passes without a single correct sentence")
 check(not game.Data.validate([{"id":"typed","typed":true,"tags":{"SHARED_MEMORY":9}}],{"SHARED_MEMORY":2},{}).passed,"Typing does not game semantic validation")
 check(not game.Data.validate([a,{"id":"r","tags":{"RETURN":3}}],{"SHARED_MEMORY":2},{"RETURN":3}).passed,"Promise to return violates explicit boundary")
 game.save_game();var before=game.composer.serialize();check(before.size()==2,"Composition serializes all transforms")
 await snap("06-collage")
 await game.begin_packaging();await process_frame
 await drag(Vector2(580,673),Vector2(580,553));await create_timer(0.7).timeout
 check(game.packing.stage==1,"First fold uses bottom edge")
 await drag(Vector2(580,481),Vector2(580,364));await create_timer(0.7).timeout
 check(game.packing.stage==2,"Second fold produces small letter")
 await drag(Vector2(580,350),Vector2(944,431));await create_timer(1.0).timeout
 check(game.packing.stage==3,"Partial envelope overlap accepts insertion")
 await click(Vector2(634,687));check(game.packing.stage==4,"A stamp is chosen")
 await snap("07-stamp")
 await click(Vector2(1217,708));await create_timer(1.8).timeout
 check(game.phase=="hub" and game.state.completed_cases.has("Mara"),"Postmark completes delivery without a stuck mailbox")
 check(not game.reply_ready("Mara"),"Reply is not instantaneous")
 game.next_day();check(game.reply_ready("Mara"),"Reply arrives next day in incoming tray")
 game.open_reply("Mara");await process_frame;await snap("08-reply");await click(Vector2(820,654))
 check(game.state.paper_library.has("STILL"),"Mara reply grants permanent paper piece")
 game.start_composer("SEND","",false);game.take_library_word("STILL");check(game.composer.placed().size()==1,"Free mode can reuse permanent reward")
 check(game.composer.mode=="SEND","Free letter uses the same composer class")
 await game.begin_packaging();await process_frame;check(game.packing!=null,"Free letter never needs semantic approval");game.cancel_packaging();game.leave_composer()
 var original=game.drift_letter().duplicate(true);game.read_drift();await snap("09-drift")
 check(game.keep_shared("HOME"),"Reply copies one shareable fragment")
 check(game.composer.mode=="REPLY","Reply uses same composer")
 check(game.drift_letter()==original,"Received collage remains unchanged")
 check(not game.keep_shared("LEAVING"),"A second different gift is not farmable")
 var first_id=game.composer.fragments[0].data.id;game.leave_composer();check(game.keep_shared("HOME"),"Reopening same reply is allowed")
 check(game.composer.fragments.filter(func(p):return p.data.id==first_id).size()==1,"Reopening cannot duplicate granted fragment")
 check(game.drift_pool().size()>=12,"Twelve distinct offline fictional letters")
 game.save_game();var save=JSON.parse_string(FileAccess.get_file_as_string(game.save_path));check(save.shared_fragment_history.size()==1,"Share history persisted locally")
 var saved_path=game.save_path;game.queue_free();await process_frame;await process_frame
 var restored=load("res://scripts/v3/letter_office.gd").new()
 # --fresh is a test runner option; feed the persisted data after a real file read.
 root.add_child(restored);await process_frame;restored.state=save;restored.consulted=save.consulted
 restored.start_composer("REPLY","",false);await process_frame
 check(restored.composer.fragments.size()==1 and restored.composer.fragments[0].data.id==first_id,"Saved reply restores its existing paper rather than regranting")
 check(restored.state.paper_library.has("STILL"),"Permanent reward survives restoration")
 restored.queue_free();await process_frame;await process_frame
 print("V3_FLOW_TEST: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures);quit(failures)
