extends SceneTree
var failures:=0
func check(ok: bool, why: String) -> void:
	if not ok:failures+=1;push_error(why)
func _initialize() -> void:call_deferred("run")
func capture(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("COLLAGE_TEST_OUTPUT")
	if not folder.is_empty():root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run() -> void:
	var game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true;game.conversation_open=false;game.shelf_open=false;game.tools_open=false
	game.letter_text="亲爱的阿宁：\n\n今天路过街角的小店，又想起了你。\n这里的海风很轻，柠檬也正当季。\n想把这些小小的日常，慢慢寄给你。\n\n希望你也有一个温柔的下午。"
	game.letter_text_node.text=game.letter_text;game.build_ui()
	game.take_material_whole(30,Vector2(682,523));var bottom=game.selected
	bottom.scale=Vector2(0.85,0.78);bottom.rotation=-0.08
	game.take_material_whole(31,Vector2(710,538));var middle=game.selected
	middle.scale=Vector2(0.71,0.64);middle.rotation=0.08
	game.take_material_whole(622,Vector2(730,532));var photo=game.selected
	photo.scale=Vector2(0.61,0.61);photo.rotation=-0.06
	await process_frame;await RenderingServer.frame_post_draw
	game.refresh_paper_stack();game.select(null)
	check(is_zero_approx(bottom.stack_height),"Bottom paper rests on the letter")
	check(middle.stack_height>0 and photo.stack_height>middle.stack_height,"Overlapping sheets accumulate supporting thickness")
	check(game.pick(photo.position)==photo,"Latest clipping stays above earlier paper")
	await capture("flat-painted-desk-stacked-paper")
	var height:float=photo.stack_height
	photo.position=Vector2(1030,500);game.refresh_paper_stack()
	check(is_zero_approx(photo.stack_height),"Removing a clipping from the pile removes support")
	photo.position=Vector2(730,532);game.refresh_paper_stack()
	check(is_equal_approx(photo.stack_height,height),"Returning to the pile restores support")
	photo.rotation=0.6;photo.scale.x*=-1
	var cast:Vector2=photo.global_transform.basis_xform(photo.local_offset(Vector2(3,5)))
	check(cast.distance_to(Vector2(3,5))<0.001,"Rotated and mirrored pieces keep the same window light direction")
	photo.rotation=-0.06;photo.scale.x=absf(photo.scale.x)
	photo.raise_paper();await photo.settling.finished
	check(photo.lift>0.9,"Picking up lifts the paper face")
	await capture("paper-lifted")
	photo.release_lift();await photo.settling.finished
	check(is_zero_approx(photo.lift),"Released paper settles completely")
	game.save_game(true);game.load_game(true)
	await process_frame;await RenderingServer.frame_post_draw;await process_frame
	check(game.pieces_root.get_child_count()==3,"Saving retains all three paper layers")
	photo=game.pieces_root.get_child(2)
	check(is_equal_approx(photo.stack_height,height),"Reload recomputes depth without changing saved positions")
	# A transparent sticker's rectangle must not cast an opaque rectangular shadow.
	var image:=Image.create(300,240,false,Image.FORMAT_RGBA8);image.fill(Color(1,1,1,0))
	image.fill_rect(Rect2i(100,75,100,90),Color.WHITE)
	photo.texture=ImageTexture.create_from_image(image);photo.silhouette_texture=null;photo.hit_image=null
	photo.prepare_silhouette()
	check(photo.silhouette_texture.get_image().get_pixel(10,10).a==0,"Shadow preserves fully transparent margins")
	check(photo.silhouette_texture.get_image().get_pixel(150,119).a==1,"Shadow preserves the opaque paper silhouette")
	game.audio.shutdown();game.queue_free();await process_frame;await process_frame
	print("PAPER_DEPTH_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures);quit(failures)
