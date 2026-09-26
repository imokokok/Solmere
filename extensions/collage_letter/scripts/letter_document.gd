extends Node
## A live paper composition, shared by folding, insertion and export. String and
## editable collage remain the document; raster snapshots are thumbnail caches.
var pages: Array[SubViewport]=[]
func build(game) -> void:
	for old in pages:old.queue_free()
	pages.clear()
	for index in game.letter_text_node.page_count:
		var view:=SubViewport.new();view.size=Vector2i(396,560);view.disable_3d=true;view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(view);pages.append(view)
		var sheet:=Node2D.new();sheet.name="LetterPaper";view.add_child(sheet)
		var surface:=Control.new();sheet.add_child(surface)
		var style:int=game.letter_paper_style
		surface.draw.connect(func():game.LetterPaper.paint(surface,Rect2(0,0,396,560),style,false))
		var renderer=preload("res://extensions/collage_letter/scripts/letter_renderer.gd").new();renderer.name="LetterText";renderer.position=Vector2(28,35);renderer.size=Vector2(340,490);renderer.ink=game.letter_ink_color;sheet.add_child(renderer);renderer.load_text(game.letter_text);renderer.page=index
		for original in game.pieces_root.get_children():
			if int(original.get_meta("letter_page",0))!=index:continue
			var piece=game.Piece.new()
			for key in ["source_id","source_language","font","texture","polygon","uv","alpha_hit","handwriting","strokes","pen_color","pen_width","tape_style","paper_thickness","painted_png","is_taped","is_glued","glue_coverage","stack_height"]:
				piece.set(key,original.get(key))
			piece.position=original.position-game.LETTER.position;piece.scale=original.scale;piece.rotation=original.rotation;sheet.add_child(piece)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
func first_page() -> Texture2D:return pages[0].get_texture()
