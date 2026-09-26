extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok: failures+=1;push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--isolated-save"): quit(2);return
 var state=root.get_node("GameState")
 state.begin_new_game("A")
 check(root.get_node("TravelSystem").travel("handcraft_shop","walk").ok,"Walk to letter office")
 state.spend_time(690-state.current_minute)
 var gameplay=root.get_node("GameplayModuleSystem")
 check(gameplay.begin_session("ghostwriting","space:test:original_collage"),"Original letter session begins during opening hours")
 if failures>0: quit(failures);return
 var host=load("res://scenes/extension_host.tscn").instantiate()
 root.add_child(host)
 var letter=host.experience
 for frame in 600:
  if letter.ready_done: break
  await process_frame
 letter.smoke=true
 check(letter.ready_done and letter.materials.size()>=678,"Base library plus host photographs load")
 var host_photos:Dictionary={}
 for material in letter.source_materials.slice(678):
  check(material.kind=="photo","Host additions remain in the photo category")
  check(not host_photos.has(material.id),"Host photo source IDs are stable and unique")
  host_photos[material.id]=true
  if not str(material.get("image_path","")).is_empty():check(FileAccess.file_exists(material.image_path),"Host photo points at a readable original")
 check(letter.audio.pool.size()==10,"Fixed voice pool avoids accumulating audio nodes")
 for clip in letter.audio.bank.values():
  check(clip!=null and clip.get_length()>0,"Recorded sound loads")
 for event in ["KNIFE_SLICE","PAPER_CUT","PAPER_MOVE","TAPE_PULL","PAPER_FOLD","MATCH_STRIKE","STAMP_PRESS"]:
  letter.audio.play(event)
 check(letter.audio.pool.any(func(voice): return voice.playing),"Action events start recorded playback")
 letter.audio.toggle()
 check(not letter.audio.pool.any(func(voice): return voice.playing),"Mute stops playing effects immediately")
 letter.audio.toggle()
 check(letter.stage=="WORKBENCH","Commission opens in the workbench")
 check(letter.get_viewport()==host.letter_viewport and letter.ui.get_viewport()==host.letter_viewport,"Artwork and controls share viewport")
 for size in [Vector2(1600,900),Vector2(1280,720),Vector2(1920,1080)]:
  host.size=size;host._fit_experience()
  var bounds=Rect2(host.letter_container.position,Vector2(1440,900)*host.letter_container.scale)
  check(Rect2(Vector2.ZERO,size).encloses(bounds),"Original canvas fits host")
  check(bounds.position.y>=host.host_panel.size.y,"Host bar remains outside game")
  check(host.letter_viewport.size==Vector2i(1440,900),"Original canvas dimensions")
 host.size=Vector2(1600,900);host._fit_experience()
 await process_frame
 for type_name in {"图案":100,"纸张":96,"广告":160,"文字":120,"票据":121,"乐谱":17}:
  var expected={"图案":100,"纸张":96,"广告":160,"文字":120,"票据":121,"乐谱":17}
  check(letter.material_ids(type_name).size()==expected[type_name],"Material type count: "+type_name)
 letter.open_material_catalog()
 var cards=letter.catalog_layer.find_children("Material_*","Button",true,false)
 check(cards.size()==24,"Catalog renders 24 items per page")
 letter.select_catalog_material(5)
 check(letter.category=="图案" and 5 in [letter.primary,letter.secondary],"Catalog selection reveals the chosen source sheet")
 letter.select_catalog_material(66)
 check(letter.album_source==66 and letter.sources[66].position.x==1070,"Paintings use the right album without conflicting with left sheets")
 letter.select_catalog_material(3)
 check(letter.sources[3].position.x<400,"Private ticket belongs to left material stack")
 letter.category="自然";letter.update_material_slots()
 check(letter.category=="全部","Legacy saved theme safely falls back to All")
 letter.album_source=4;letter.material_page=0;letter.update_material_slots();letter.build_ui()
 # Check every imported source on the renderer and through the real crop action.
 var image_hashes := {}
 var atlas := Image.create(180*10,144*68,false,Image.FORMAT_RGBA8)
 var source_limit: int=24 if OS.get_cmdline_user_args().has("--quick") else 678
 for id in source_limit:
  letter.get_material_texture(id)
  await process_frame
  await RenderingServer.frame_post_draw
  var image: Image=letter.get_material_texture(id).get_image()
  check(not image.is_empty() and image.get_size()==Vector2i(300,240),"Source page renders: "+str(id))
  var hash=image_hash(image.get_data())
  check(not image_hashes.has(hash),"Distinct rendered material: "+str(id))
  image_hashes[hash]=true
  image.resize(180,144)
  atlas.blit_rect(image,Rect2i(0,0,180,144),Vector2i((id%10)*180,(id/10)*144))
  letter.tool="rect";letter.cutting_source=id
  letter.start=letter.sources[id].position+Vector2(70,55)
  letter.finish_cut(letter.start+Vector2(160,125))
  check(letter.selected.source_id==id and letter.selected.uv.size()>=4 and letter.selected.uv.size()==letter.selected.polygon.size(),"Replacement material can be cropped: "+str(id))
 var output=OS.get_environment("COLLAGE_TEST_OUTPUT")
 if not output.is_empty(): atlas.save_png(output.path_join("material-catalog.png"))
 for piece in letter.pieces_root.get_children():
  letter.pieces_root.remove_child(piece);piece.queue_free()
 letter.selected=null
 letter.tool="rect";letter.cutting_source=0;letter.start=Vector2(80,271);letter.finish_cut(Vector2(315,306))
 check(letter.pieces_root.get_child_count()==1,"Original rectangle cut creates a paper piece")
 letter.selected.position=Vector2(700,390)
 letter.tape_start=Vector2(650,380);letter.finish_tape(Vector2(750,400))
 await letter.complete_letter()
 check(letter.stage=="FOLDING" and letter.letter_preview!=null,"Original letter captures and folds")
 check(letter.save_path.begins_with("user://letter_original_"),"Host saves isolated by character and journey")
 letter.audio.shutdown();host.queue_free();gameplay.cancel_session();await process_frame
 print("ORIGINAL_COLLAGE_HOST_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures," sources=",source_limit)
 quit(failures)

func image_hash(bytes: PackedByteArray) -> String:
 var context:=HashingContext.new()
 context.start(HashingContext.HASH_SHA256);context.update(bytes)
 return context.finish().hex_encode()
