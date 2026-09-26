extends RefCounted
## A separate, editable exhibition draft; never repopulate the player's next task.
static func apply(game) -> void:
	game.showcase_seen=true
	game.letter_text="小满：\n寄你一点海边的风。" if game.L.language=="zh" else "Dear Xiaoman,\nA little sea breeze, for you."
	game.letter_paper_style=1;game.letter_text_node.load_text(game.letter_text);game.letter_text_node.page=0
	game.letter_data=preload("res://scripts/letter_data.gd").fresh();game.letter_data.sender="林舟";game.letter_data.recipient="小满"
	for child in game.pieces_root.get_children():game.pieces_root.remove_child(child);child.queue_free()
	add(game,32,Vector2(714,479),Vector2(.84,.77),-.065)
	add(game,34,Vector2(686,565),Vector2(.71,.76),.045)
	add(game,622,Vector2(724,487),Vector2(.70,.70),-.065)
	add(game,36,Vector2(670,657),Vector2(.71,.67),-.04)
	add(game,2,Vector2(631,620),Vector2(.39,.39),-.085)
	add(game,620,Vector2(774,655),Vector2(.63,.63),.05)
	for i in 3:add(game,[662,634,626][i],Vector2(665+i*35,404),Vector2(.22,.22),[-.05,.08,-.06][i])
	game.tape_style=3;game.tape_start=Vector2(624,424);game.finish_tape(Vector2(673,430))
	game.tape_style=0;game.tape_start=Vector2(802,588);game.finish_tape(Vector2(850,598))
	tag(game,"走慢一点" if game.L.language=="zh" else "Take the long way",Vector2(659,714),-.04)
	tag(game,"林舟 · 九月" if game.L.language=="zh" else "Lin · September",Vector2(800,772),.015)
	game.select(null);game.tool="move";game.shelf_open=false;game.tools_open=false;game.source_preview_id=-1;game.conversation_open=false;game.refresh_paper_stack();game.build_ui();game.changed()
	game.say("可以改动这封示例信。寄出后，下一封会从空白信纸开始。" if game.L.language=="zh" else "An editable example. The next letter starts on a blank page.")
static func add(game,id:int,at:Vector2,scale:Vector2,rotation:float)->void:
	game.take_material_whole(id,at);game.selected.scale=scale;game.selected.rotation=rotation
static func tag(game,value:String,at:Vector2,angle:float=0)->void:
	var note=game.Piece.new();note.source_id=-1;note.font=game.letter_text_node.HAND;note.handwriting=value;note.position=at;note.rotation=angle;note.scale=Vector2.ONE*.7;note.polygon=game.roughen(PackedVector2Array([Vector2(-88,-22),Vector2(88,-22),Vector2(88,22),Vector2(-88,22)]));game.pieces_root.add_child(note)
