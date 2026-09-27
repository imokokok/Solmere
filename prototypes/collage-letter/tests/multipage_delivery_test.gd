extends SceneTree
## Real rendered pages, saved sealed draft, HTTP delivery and reader navigation.
var failures:=0
var game
class LegacyPostOffice extends Node:
	var base_url:="http://legacy.invalid"
	var player:Dictionary={"id":"test"}
	var published:=false
	func request(_path:String)->Dictionary:return {"ok":true,"version":2}
	func publish(_payload:Dictionary)->Dictionary:
		published=true;return {"ok":true,"letter_id":999}
class IncompletePostOffice extends LegacyPostOffice:
	func request(_path:String)->Dictionary:return {"ok":true,"version":3,"capabilities":["art_pages"]}
	func publish(_payload:Dictionary)->Dictionary:
		published=true;return {"ok":true,"letter_id":999,"page_count":1}
func _initialize()->void:
	# A background macOS test window may not draw on its own.
	process_frame.connect(func():RenderingServer.force_draw())
	call_deferred("run")
func check(ok:bool,why:String)->void:
	if not ok:failures+=1;push_error(why)
func capture(name:String)->void:
	await process_frame;await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("COLLAGE_TEST_OUTPUT")
	if not folder.is_empty():root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func decoded(encoded:String)->Image:
	var image:=Image.new();check(image.load_png_from_buffer(Marshalls.base64_to_raw(encoded))==OK,"Page is a real PNG");return image
func run()->void:
	var url:=OS.get_environment("COLLAGE_TEST_URL")
	if url.is_empty():push_error("Use an isolated HTTP test server via COLLAGE_TEST_URL");quit(2);return
	game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true;game.bottle.identity_path="user://multipage_test_identity.json";game.bottle.identities={}
	var connected:Dictionary=await game.bottle.connect_service(url,"多页测试读者")
	check(connected.ok,"Connect to temporary post office")
	game.start_bottle({})
	game.letter_text="海边的风很轻。\n".repeat(18);game.letter_text_node.load_text(game.letter_text)
	check(game.letter_text_node.page_count==2,"Regression text spans two editing pages")
	game.letter_text_node.page=1
	game.take_material_whole(620,game.LETTER.position+game.LETTER.size*Vector2(.8,.8))
	game.selected.rotation=.2;game.selected.scale=Vector2(.45,.62)
	var original=game.selected
	game.letter_text_node.page=2;game.take_material_whole(621,game.LETTER.get_center())
	await process_frame;await RenderingServer.frame_post_draw
	var edited_lines:Array=[]
	for line in game.letter_text_node.lines:edited_lines.append([line.range,line.page,line.y])
	await game.complete_letter()
	check(game.stage=="BOTTLE" and game.live_document.pages.size()==3,"Finish keeps prose plus collage-only third page")
	for index in game.live_document.pages.size():
		var view=game.live_document.pages[index]
		var sheet=view.get_node("LetterPaper");var renderer=sheet.get_node("LetterText")
		check(view.size==Vector2i(game.LETTER.size),"Finished paper uses editing dimensions")
		var finished_lines:Array=[]
		for line in renderer.lines:finished_lines.append([line.range,line.page,line.y])
		check(finished_lines==edited_lines and renderer.page==index,"Exact text ranges and page breaks survive composition")
		if index==1:
			var piece=sheet.get_child(sheet.get_child_count()-1)
			check(piece.position.is_equal_approx(original.position-game.LETTER.position),"Second-page clipping retains position")
			check(piece.scale==original.scale and is_equal_approx(piece.rotation,original.rotation),"Second-page clipping retains scale and rotation")
	var frozen:Array=game.letter_page_pngs.duplicate()
	check(frozen.size()==3 and frozen[0]!=frozen[1] and frozen[1]!=frozen[2],"Three distinct finished pages are cached")
	game.save_game(true);game.letter_page_pngs.clear();game.letter_preview=null;game.load_game(true)
	check(game.stage=="BOTTLE" and game.letter_page_pngs==frozen and game.letter_preview!=null,"Sealed restart preserves all outgoing bytes")
	await game.send_bottle()
	check(game.stage=="END" and game.bottle_published_id>0,"Only confirmed complete delivery reaches END")
	var result:Dictionary=await game.bottle.request("/v1/letters/"+str(game.bottle_published_id))
	check(result.ok and result.letter.art_pages==frozen,"Real HTTP returns every original rendered page in order")
	check(result.letter.caption==game.letter_text,"Original Unicode prose survives HTTP")
	var dock=game.BottleDock.new();dock.client=game.bottle;dock.font=game.font;game.add_child(dock);dock.open()
	while dock.in_flight:await process_frame
	await dock.show_letter(game.bottle_published_id)
	await capture("received-page-1")
	var page_nav=dock.detail_box.get_node("ReceivedPageNavigation")
	check(dock.detail_scroll.get_global_rect().encloses(page_nav.get_global_rect()),"Artwork page controls fit completely without scrolling")
	check(dock.detail_box.get_node("ReceivedPageNavigation/ReceivedPagePrevious").disabled,"First page cannot turn backwards")
	for index in range(1,3):
		dock.detail_box.get_node("ReceivedPageNavigation/ReceivedPageNext").pressed.emit();await process_frame
		var received:Image=dock.detail_box.get_node("ReceivedLetterArtwork").texture.get_image()
		check(received.get_data()==decoded(frozen[index]).get_data(),"Reader shows exact later-page collage "+str(index))
		await capture("received-page-"+str(index+1))
	check(dock.detail_box.get_node("ReceivedPageNavigation/ReceivedPageNext").disabled,"Last page cannot turn forwards")
	dock.detail_box.get_node("ReceivedPageNavigation/ReceivedPagePrevious").pressed.emit();await process_frame
	check(dock.reading_page==1,"Reader can return to an earlier art page")
	for locale in ["zh","en"]:
		game.L.language=locale;dock.show_plain_text=true;dock.render_letter();await process_frame
		var nav=dock.detail_box.get_child(1)
		check(nav.get_node("ReadingReplay").text==("重看书写" if locale=="zh" else "Replay Writing"),"Replay is localized")
		check(nav.get_node("ReadingSkip").text==("跳过" if locale=="zh" else "Skip"),"Skip is localized")
		check(nav.get_node("ReadingReplay").size.x>=150,"Replay has room for its complete label")
		await capture("reading-controls-"+locale)
	dock.reading_letter={"art_png":frozen[0],"caption":"旧版单页"};dock.show_plain_text=false;dock.render_letter();await process_frame
	check(dock.detail_box.get_child_count()==1 and dock.detail_box.has_node("ReceivedLetterArtwork"),"Legacy single-page artwork is still readable")
	dock.close();await process_frame
	game.L.language="zh"
	var current_client=game.bottle;var legacy:=LegacyPostOffice.new();game.add_child(legacy)
	game.bottle=legacy;game.compose_server=legacy.base_url;game.stage="BOTTLE";game.bottle_published_id=0
	await game.send_bottle()
	check(not legacy.published and game.stage=="BOTTLE" and game.letter_page_pngs==frozen,"Old servers never silently accept only the first page")
	var incomplete:=IncompletePostOffice.new();game.add_child(incomplete);game.bottle=incomplete
	var request_id:String=game.bottle_request_id
	await game.send_bottle()
	check(incomplete.published and game.stage=="BOTTLE" and game.bottle_published_id==0 and game.bottle_request_id==request_id and game.letter_page_pngs==frozen,"Incomplete page acknowledgement preserves draft and exact retry ID")
	# An older sealed save contains editable pages but no outgoing PNG array.
	game.bottle=legacy;game.letter_page_pngs.clear();game.letter_preview=null
	await game.send_bottle()
	check(not legacy.published and game.stage=="BOTTLE" and game.letter_page_pngs.size()==3 and game.letter_preview!=null,"Legacy sealed draft rebuilds every page before capability check")
	game.bottle=current_client
	game.audio.shutdown();game.queue_free();await process_frame;await process_frame
	print("MULTIPAGE_DELIVERY_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures);quit(failures)
