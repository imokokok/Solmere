extends RefCounted
static func data(cycle:int=0) -> Dictionary:
	var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/sea_example.json"))
	if cycle%3>0:source.merge(source.exchanges[cycle%3-1],true)
	return source
static func artwork(game, reply:bool) -> String:
	var content:=data(game.sample_cycle);var locale:String=game.L.language
	var view:=SubViewport.new();view.size=Vector2i(420,594);view.disable_3d=true;view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;game.add_child(view)
	var paper:=Control.new();view.add_child(paper);paper.draw.connect(func():game.LetterPaper.paint(paper,Rect2(0,0,420,594),1 if reply else 3,false))
	var words=preload("res://scripts/letter_renderer.gd").new();view.add_child(words)
	if reply:
		# Use the same composition and text metrics as the editable A4 draft.
		var ratio:=420.0/354.0
		words.position=Vector2(28,35)*ratio;words.size=Vector2(298,430);words.scale=Vector2.ONE*ratio
		words.load_text(content["reply_"+locale])
		var cutouts:=Node2D.new();cutouts.scale=Vector2.ONE*ratio;cutouts.position=-game.LETTER.position*ratio;view.add_child(cutouts)
		populate_reply(game,cutouts,content)
	else:
		words.position=Vector2(28,28);words.size=Vector2(364,398);words.font_size=17 if locale=="zh" else 15;words.load_text(content["incoming_"+locale])
		var scraps:=Node2D.new();view.add_child(scraps)
		preview_piece(game,scraps,32,Vector2(204,503),Vector2(.98,.46),-.035)
		preview_piece(game,scraps,34,Vector2(127,506),Vector2(.59,.47),.035)
		preview_piece(game,scraps,int(content.photo),Vector2(289,511),Vector2(.51,.46),-.06)
		preview_piece(game,scraps,int(content.cutout),Vector2(114,503),Vector2(.4,.4),-.12)
		var note:=Control.new();note.position=Vector2(35,562);view.add_child(note)
		note.draw.connect(func():note.draw_string(game.font,Vector2.ZERO,str(content["title_"+locale]),HORIZONTAL_ALIGNMENT_LEFT,344,14,Color("536d65")))
	await RenderingServer.frame_post_draw
	if not is_instance_valid(view) or view.is_queued_for_deletion():return ""
	var encoded:=Marshalls.raw_to_base64(view.get_texture().get_image().save_png_to_buffer());view.queue_free();return encoded
static func start_reply(game) -> void:
	# Separate save slot: opening a demonstration never overwrites an actual letter.
	if game.example_return.is_empty():
		game.save_game(true);game.example_return={"save":game.save_path,"preview":game.preview_path}
		game.save_path=game.save_path.get_basename()+"_sea_example.json";game.preview_path=game.preview_path.get_basename()+"_sea_example.png"
	game.select(null)
	for piece in game.pieces_root.get_children():game.pieces_root.remove_child(piece);piece.queue_free()
	game.stage="WORKBENCH";game.letter_mode="example";game.letter_paper_style=1;game.letter_ink_color=game.INK;game.letter_text=data(game.sample_cycle)["reply_"+game.L.language];game.letter_title=("给"+data(game.sample_cycle).name_zh+"的回信") if game.L.language=="zh" else "A reply"
	game.letter_data=preload("res://scripts/letter_data.gd").fresh();game.letter_data.sender="Solmere";game.letter_data.recipient=data(game.sample_cycle)["name_"+game.L.language]
	game.conversation_open=false;game.typewriter_open=false;game.shelf_open=false;game.tools_open=false;game.source_preview_id=-1;game.bottle_published_id=0;game.bottle_request_id="";game.compose_server="";game.reply_parent={"id":-15,"title":data(game.sample_cycle)["title_"+game.L.language]}
	var sample:=data(game.sample_cycle)
	populate_reply(game,game.pieces_root,sample)

	game.select(null);game.tool="move";game.changed();game.build_ui()
	game.say("示例回信已摆好。可以修改，或点「寄出 →」开始装瓶。" if game.L.language=="zh" else "The example reply is ready. Edit it, or choose Roll & send to bottle it.")
static func return_to_letter(game) -> void:
	if game.example_return.is_empty() or game.busy:return
	game.save_game(true);var paths:Dictionary=game.example_return.duplicate();game.example_return={};game.save_path=paths.save;game.preview_path=paths.preview;game.load_game(true);game.load_voyage();game.conversation_open=false;game.tool="move";game.typewriter_open=false;game.build_ui()

static func preview_piece(game,parent:Node,id:int,at:Vector2,piece_scale:Vector2,angle:float)->void:
	var piece=game.Piece.new();piece.source_id=id;piece.source_language=game.L.language;piece.texture=game.get_material_texture(id);piece.font=game.font
	piece.polygon=PackedVector2Array([Vector2(-150,-120),Vector2(150,-120),Vector2(150,120),Vector2(-150,120)])
	piece.uv=PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)]);piece.alpha_hit=true;piece.position=at;piece.scale=piece_scale;piece.rotation=angle
	piece.paper_thickness=1.3 if game.materials[id].kind in ["photo","art"] else .65;parent.add_child(piece)
static func populate_reply(game,parent:Node,sample:Dictionary)->void:
	preview_piece(game,parent,32,Vector2(722,635),Vector2(.83,.72),-.035)
	preview_piece(game,parent,34,Vector2(718,654),Vector2(.75,.76),.04)
	preview_piece(game,parent,int(sample.photo),Vector2(735,628),Vector2(.69,.69),-.03)
	preview_piece(game,parent,int(sample.cutout),Vector2(615,658),Vector2(.3,.3),-.12)
	preview_piece(game,parent,2,Vector2(779,733),Vector2(.34,.25),.075)
	var tape=game.Piece.new();tape.source_id=-2;tape.tape_style=0;tape.font=game.font;tape.position=Vector2(670,571);tape.rotation=.142;tape.is_taped=true
	tape.polygon=PackedVector2Array([Vector2(-28,-10),Vector2(28,-9),Vector2(27,10),Vector2(-27,9)]);parent.add_child(tape)
	var note=game.Piece.new();note.source_id=-1;note.font=preload("res://scripts/letter_renderer.gd").HAND;note.handwriting=sample["tag_"+game.L.language];note.position=Vector2(698,726);note.rotation=-.045;note.scale=Vector2.ONE*.7
	note.polygon=PackedVector2Array([Vector2(-88,-22),Vector2(88,-21),Vector2(86,22),Vector2(-87,21)]);parent.add_child(note)
	var below:Array=[]
	for piece in parent.get_children():piece.refresh_stack(below);below.append(piece)
