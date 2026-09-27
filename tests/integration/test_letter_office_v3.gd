extends SceneTree
var failures=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,why:String) -> void:
 if not ok:failures+=1;push_error(why)
func run() -> void:
 if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--isolated-save"):quit(2);return
 var state=root.get_node("GameState");state.begin_new_game("A")
 check(root.get_node("TravelSystem").travel("handcraft_shop","walk").ok,"Walk to real letter office")
 state.spend_time(690-state.current_minute)
 var system=root.get_node("GameplayModuleSystem")
 check(system.begin_session("ghostwriting","space:test:letter_office_v3"),"Host starts V3 in real business hours")
 var host=load("res://scenes/extension_host.tscn").instantiate();root.add_child(host)
 var office=host.experience
 while not office.ready_done:await process_frame
 check(office.save_path.begins_with("user://letter_office_v3_"),"Journey and character own an isolated V3 save")
 check(office.phase=="hub","Host opens letters directly without puzzle gate")
 check(office.audio.bank.size()>15,"Licensed recorded sounds are available inside host")
 check(office.drift_pool().size()==12,"Offline letters load through namespaced host resource paths")
 host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 for size in [Vector2(1600,900),Vector2(1280,720),Vector2(1920,1080)]:
  host.size=size;host._fit_experience()
  check(host.letter_viewport.size==Vector2i(1440,810),"V3 uses one 16:9 viewport")
  var bounds=Rect2(host.letter_container.position,Vector2(1440,810)*host.letter_container.scale)
  check(Rect2(Vector2.ZERO,size).grow(0.1).encloses(bounds) and bounds.position.y>=host.host_panel.size.y,"Art and input fit below host chrome")
 check(not host._experience_completed(),"Reading alone cannot settle a host commission")
 office.start_composer("HELP","Mara",false);office.composer.add_fragment({"id":"test","word":"JUNE 17","tags":{"SHARED_MEMORY":3},"fragment":true},Vector2(560,390));office.on_sent("Lemon")
 check(host._experience_completed(),"Accepted and postmarked NPC letter enables host completion")
 check(office.state.completed_cases.has("Mara"),"V3 receipt is saved locally")
 check(office.bottle_published_id==0,"Offline preview never pretends to publish a network letter")
 host.queue_free();system.cancel_session();await process_frame;await process_frame
 print("LETTER_OFFICE_V3_HOST_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures);quit(failures)
