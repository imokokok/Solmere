extends SceneTree
var failures:=0
const Locale=preload("res://scripts/localization.gd")
class FakePostOffice extends Node:
	var base_url:="http://localhost.invalid"
	var token:=""
	var display_name:="测试读者"
	var player: Dictionary={}
	var requests: Array=[]
	var artwork:=""
	func connect_service(_url: String,_nickname: String) -> Dictionary:
		await get_tree().process_frame;token="isolated-test-token";player={"id":41,"reply_required":false};return {"ok":true,"player":player}
	func request(path: String) -> Dictionary:
		requests.append(path);await get_tree().process_frame
		if path.begins_with("/v1/letters?"):
			var later:=path.contains("&before=3")
			return {"ok":true,"letters":[letter(4)] if later else [letter(1),letter(2),letter(3)],"next_before":null if later else 3}
		var id:=int(path.get_file());return {"ok":true,"letter":letter(id),"replies":[letter(4)] if id==1 else []}
	func letter(id: int) -> Dictionary:
		var zh:=Locale.language=="zh"
		return {"id":id,"title":"从海边捎给你的一封长信，关于今天经过公园时想起来的小事" if zh else "A letter from the coast, about something I remembered while walking through the park today","name":"林舟" if zh else "Lin Zhou","reply_count":1 if id==1 else 0,"is_seed":false,"is_own":id==3,"already_replied":id==4,"parent":1 if id==4 else null,"art_png":artwork if id==2 else "","caption":("亲爱的朋友：\n\n今天经过海边的公园时，我在长椅上坐了一会儿。雨刚停，树叶上的水顺着椅背慢慢落下来。\n\n街角的饭店还没有开门，老板正在把一篮柠檬搬到窗边。我记得你说过，日子里这样的小事也值得记下来。\n\n所以写了这封信。希望你今天也能遇见一个让你停留片刻的地方。\n\n不用急着回复。等你想说话的时候，我会在这里。\n\n祝好，\n林舟" if zh else "Dear friend,\n\nI sat on a bench by the sea for a while today. The rain had just stopped, and water was slowly dripping from the leaves onto the back of the bench.\n\nThe restaurant on the corner was not open yet. Its owner was carrying a basket of lemons over to the window. You once told me that small things like these were worth remembering.\n\nSo I wrote you this letter. I hope you find a place that makes you pause for a moment today, too.\n\nThere is no hurry to reply. When you feel like talking, I will be here.\n\nWarmly,\nLin Zhou")}
func check(ok: bool, why: String) -> void:
	if not ok:failures+=1;push_error(why)
func _initialize():
	process_frame.connect(func():RenderingServer.force_draw())
	call_deferred("run")
func capture(filename: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("COLLAGE_TEST_OUTPUT")
	if not folder.is_empty():root.get_texture().get_image().save_png(folder.path_join(filename+".png"))
func run() -> void:
	var game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true;game.conversation_open=false;game.build_ui()
	var fake:=FakePostOffice.new();root.add_child(fake)
	var blank:=Image.create(210,297,false,Image.FORMAT_RGBA8);blank.fill(Color("f4e4bd"));fake.artwork=Marshalls.raw_to_base64(blank.save_png_to_buffer())
	for locale in ["zh","en"]:
		Locale.language=locale;fake.token="";fake.player={}
		var dock=load("res://scripts/bottle_dock.gd").new();dock.client=fake;dock.font=game.font;game.add_child(dock);dock.open();await process_frame
		check(not game.ui.visible,"Desk labels are hidden while reading so no UI shines through")
		check(not dock.connection.visible and dock.side_scroll.visible,"Local reading opens before explicit post-office settings")
		dock.toggle_connection();check(dock.connection.visible and not dock.side_scroll.visible,"Opening settings uses reply area without covering the letter")
		check(dock.write_button.disabled,"Not connected cannot compose")
		await capture("drift-connection-"+locale)
		await dock.connect_now();await process_frame
		check(not dock.connection.visible and dock.letters_box.get_child_count()==3,"Connecting opens the mail tray")
		check(dock.previous_button.disabled and not dock.next_button.disabled,"First page button states")
		await dock.show_letter(1);await process_frame
		check(dock.detail_box.get_child_count()==2 and dock.detail_box.get_child(0).name=="ReceivedLetterText" and dock.detail_box.get_child(0).full_text==fake.letter(1).caption,"Text-only letter focuses actual prose on the sheet")
		var nav=dock.detail_box.get_child(1)
		check(nav.get_node("ReadingReplay").text==("重看书写" if locale=="zh" else "Replay Writing"),"Replay button follows reading language")
		check(nav.get_node("ReadingSkip").text==("跳过" if locale=="zh" else "Skip"),"Skip button follows reading language")
		check(nav.get_node("ReadingReplay").size.x>=150,"Replay label fits its button")
		check(dock.detail_box.size.x<=420 and dock.reading_side.size.x<=381,"Long titles and prose remain inside their own reading columns")
		check(not dock.detail_scroll.get_rect().intersects(dock.side_scroll.get_rect()),"Reply area never overlaps letter")
		await capture("drift-reading-"+locale)
		dock.next_button.pressed.emit();await process_frame;await process_frame
		check(dock.before==3 and dock.next_button.disabled and not dock.previous_button.disabled,"Next page retains cursor and updates controls")
		dock.previous_button.pressed.emit();await process_frame;await process_frame
		check(dock.before==null and dock.letters_box.get_child_count()==3,"Previous page returns to the first tray")
		await dock.show_letter(2);await process_frame
		check(dock.detail_box.get_child(0).name=="ReceivedLetterArtwork","Collaged letter keeps its original art")
		for child in dock.reading_side.get_children():
			if child is Button and child.text==("阅读文字" if locale=="zh" else "Read the words"):child.pressed.emit();break
		await process_frame
		check(dock.detail_box.get_child(0).name=="ReceivedLetterText","Reader can switch art to readable words")
		await dock.show_letter(4);check(dock.reading_letter.parent==1,"A reply retains navigation to its original")
		fake.player.reply_required=true;dock.lock(false);check(dock.write_button.disabled,"Reply debt disables another new letter")
		var result: Array=[];dock.compose_requested.connect(func(parent):result.append(parent));dock.compose_requested.connect(game.start_bottle)
		dock.compose_new();check(result.is_empty() and dock.active,"Reply debt cannot be bypassed by direct compose action")
		await dock.show_letter(1)
		for child in dock.reading_side.get_children():
			if child is Button and child.text==Locale.t("回到桌边，回复这封信"):child.pressed.emit();break
		check(result.size()==1 and int(result[0].id)==1 and not dock.active,"Reply returns to desk with exact original letter")
		check(game.ui.visible,"Closing the reader restores the desk controls")
		check(game.tool=="write" and game.letter_text_node.visible and is_instance_valid(game.desk.writing) and game.reply_parent.caption==fake.letter(1).caption,"Reply opens native input and the current paper renderer with the exact received original")
		dock.queue_free();await process_frame
	game.audio.shutdown();game.queue_free();fake.queue_free();await process_frame;await process_frame
	print("BOTTLE_DOCK_UI_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures);quit(failures)
