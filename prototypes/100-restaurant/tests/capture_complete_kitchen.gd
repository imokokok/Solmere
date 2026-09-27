extends "res://tests/capture_player_tutorial.gd"
## Player-facing coverage of every implemented interaction family. All cooking,
## overflow, pressure and char are produced by real inputs and elapsed physics.
var coverage: Array = []
var laboratory := false

func closing_chapter() -> String:
	return "17 / 收班"

func prepare_recording_input() -> void:
	virtual_input=true
	preload("res://tests/recording_focus_isolation.gd").install(game.world)

func mark(id: String, result: String) -> void:
	coverage.append({"id":id,"seconds":float(frame)/FPS,"result":result})

func comprehensive_extras() -> bool:
	# Finish the soup transfer tutorial before an explicitly separate practice.
	if not game.session.dish.is_empty():
		stage("汤盛多了，可以倒回锅；盘里的同一批食物也能回锅继续料理")
		game._interact("plate"); await hold(1)
		var before: float=game.world.pan.water_ml
		await click("汤倒回锅"); await hold(2)
		if not require(game.world.pan.water_ml>before and game.session.presentation.get("broth_ml",0)==0,"bowl broth actually returned to original pot"): return false
		await click("完成摆盘，回厨房")
		game._interact("cook"); await hold(2)
		if not require(not game.world.plated,"same plated noodle returns to pot"): return false
		mark("broth-return-and-reheat","finite broth returned; original food re-enters pot")
	if "ending" in OS.get_cmdline_user_args():
		var start:=FileAccess.open(output.path_join("ending-start.json"),FileAccess.WRITE)
		start.store_string(JSON.stringify({"native_tail_skip_frames":frame+1,"script_tail_start_frame":frame},"  ")); start.close()
		await card("回到今天的营业", "料理与实验都看过了，最后收好厨房、查看结算",3)
		return true
	await card("10  自由练习与厨房实验", "接下来换到独立准备期，把工具与意外情况逐一试完",4)
	var service_game=game
	service_game.process_mode=Node.PROCESS_MODE_DISABLED
	root.remove_child(service_game)
	game=CaptureRestaurant.new()
	game.configure({"npc_profiles":JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/data/customers.json")),"repository_path":service_game.repository.storage_path,"display_name":"小满"})
	root.add_child(game); await frames(2); prepare_recording_input(); await click("先在厨房练习")
	laboratory=true
	if not await inventory_and_controls(): return false
	if not await materials_and_utensils(): return false
	if not await lid_and_char(): return false
	if not await complete_recipe_guide(): return false
	if not await flood_and_recovery(): return false
	if not await odd_experiment(): return false
	if not await paper_and_exchange(): return false
	game.world.audio.muted=true; game.queue_free(); await frames(2)
	game=service_game; root.add_child(game); game.process_mode=Node.PROCESS_MODE_INHERIT
	await card("回到今天的营业", "料理与实验都看过了，最后收好厨房、查看结算",3)
	var file:=FileAccess.open(output.path_join("coverage.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"chapters":coverage,"input_only":true,"practice_is_separate":true,"claims":"All implemented operation families; not all 104 ingredients cooked one by one, not unimplemented 3D/town features."},"  "))
	return true

func inventory_and_controls() -> bool:
	chapter_label.text="10 / 取放与快捷操作"
	stage("冷藏柜可以开合；TAB 的分类和搜索，与架子共用同一份有限库存")
	game.storage_display.fridge_open=false; await hold(2)
	game.storage_display.fridge_open=true; await hold(2)
	_key(KEY_TAB); await hold(1)
	for words in ["基础食材","调味料","甜品饮品","怪异材料"]:
		var button:=find_button(words)
		if button!=null: await click(words); await hold(1.5)
	game._close_modal()
	stage("拿错了还没处理的原料，拖回原来的空位，可以放回去")
	game.storage_display.reveal_ingredient("onion")
	var slot: Button=game.storage_display.find_child("Ingredient_onion",true,false)
	var original: Vector2=slot.get_global_rect().get_center()
	_mouse(original,"down"); await frames(3); await move_to(Vector2(1120,650),26)
	var source=game.world._held
	await hold(1); await move_to(original,26); _mouse(original,"up"); await frames(5)
	if not require(not is_instance_valid(game.world._held) and bool(game._stock.onion),"unprocessed original onion returned to finite shelf"): return false
	mark("inventory-return","same unprocessed ingredient restored to original slot")
	stage("空手点取，Q 放下；拿着食物按 G 可以投掷，E 对准工位进行操作")
	await _take("carrot"); await move_to(Vector2(1160,635),26); _key(KEY_Q); await frames(24)
	if not require(not is_instance_valid(game.world._held),"Q releases actual carried food"): return false
	await _take("potato"); await move_to(Vector2(1170,610),26); _key(KEY_G); await frames(38)
	if not require(not is_instance_valid(game.world._held),"G throws original potato"): return false
	await _take("mushroom"); await move_to(game.world.pan.point(Vector2(810,575)),28); await frames(3); _key(KEY_E); await frames(38)
	if not require(_dish_has("mushroom"),"E drops carried mushroom into targeted stove"): return false
	stage("拿着食材点「丢弃」只丢手上这一件；空手再点，会清理锅、盘和台面")
	await _take("bread"); await click("丢弃 / 清理台面",game.hud)
	if not require(not is_instance_valid(game.world._held) and _dish_has("mushroom"),"discard held food preserves other cooking"): return false
	await click("丢弃 / 清理台面",game.hud); await frames(10)
	if not require(game.session.dish.is_empty() and game.world._foods.get_child_count()==0,"workspace clear removes actual food and debris"): return false
	stage("暂停会停下厨房；操作说明随时可看，也可以在底栏开关游戏声音")
	await click("暂停 / 帮助",game.hud); await click("操作说明"); await hold(5); await click("知道了，回厨房")
	await click("声音 开",game.hud); await hold(1); await click("声音 关",game.hud); await hold(1)
	mark("controls-and-help","Q/G/E, held-only discard, clear, pause/help and sound toggle exercised")
	return true

func _take(id: String) -> bool:
	game.storage_display.reveal_ingredient(id)
	var slot: Button=game.storage_display.find_child("Ingredient_"+id,true,false)
	if not require(slot!=null and not slot.disabled,"stock available: "+id): return false
	var at: Vector2=slot.get_global_rect().get_center()
	_mouse(at,"down"); await frames(3); _mouse(at,"up"); await frames(4)
	return require(is_instance_valid(game.world._held),"picked up: "+id)

func reset_workspace() -> void:
	await fire("off")
	if game.modal.visible: game._close_modal()
	await click("丢弃 / 清理台面",game.hud); await frames(10)
	if is_instance_valid(game.world._held): await click("丢弃 / 清理台面",game.hud)
	if absf(game.world.pan.offset.x-game.world.pan.HOME.x)>5 or absf(game.world.pan.angle)>.05:
		await restore_pan()

func restore_pan() -> void:
	warp_pointer=false
	var handle: Vector2=game.world.pan.point(Vector2(1037,578))
	_mouse(handle,"down"); await frames(3)
	while game.world.pan.angle>.06: _wheel(MOUSE_BUTTON_WHEEL_UP); await frames(1)
	while game.world.pan.angle<-.06: _wheel(MOUSE_BUTTON_WHEEL_DOWN); await frames(1)
	var desired: Vector2=game.world.pan.HOME-game.world.pan.offset
	await move_to(previous_pointer+desired,42); _mouse(previous_pointer,"up"); await frames(36)
	warp_pointer=true

func materials_and_utensils() -> bool:
	chapter_label.text="11 / 材料变化与工具"
	await card("11  不同材料，不同变化", "融化 · 附着 · 撒粉 · 倾倒 · 挤酱 · 舀取",3)
	stage("黄油和芝士会受热软化、融化；它们仍来自原来的那块食材")
	for id in ["butter","cheese","tofu"]:
		if not await _drag_slot(id,game.world.pan.point(Vector2(765+(["butter","cheese","tofu"].find(id))*43,565)),32): return false
		await frames(30)
	await fire("medium")
	stage("加热等待 · 4 倍速：看黄油融开、芝士变软，不会换成固定成品图")
	Engine.time_scale=4
	var waits:=0
	while _liquid_fraction("butter")<.45 and waits<1600: await frames(1); waits+=1
	Engine.time_scale=1
	if not require(_liquid_fraction("butter")>=.45,"real burner produces finite butter liquid phase"): return false
	await fire("off"); await hold(3); checkpoint("12-melting")
	stage("盐罐撒粉，酱油倾倒，番茄酱挤出；按住出料，松开停止，都有余量")
	for id in ["salt","soy_sauce","ketchup"]:
		if not await seasoning(id,1.3): return false
		await hold(2)
	stage("木铲左右推拌，酱会逐渐沾到食物上；工具接触的是实际食材")
	await stir(); await hold(2)
	mark("phase-and-seasoning","butter/cheese/tofu, three dispensing modes and wooden stirring")
	stage("木勺能承托食物和酱；慢移可以带起，滚轮倾斜后会滑回锅中")
	warp_pointer=false
	var spoon=game.world.utensils[2]
	_mouse(spoon.to_global(Vector2(-24,0)),"down"); await frames(4)
	if not require(spoon.active,"spoon picked through exposed cup handle"): return false
	var sauce: RigidBody2D
	for body in game.world._foods.get_children():
		if body.has_meta("liquid_state") and body.get_meta("enrolled",false): sauce=body; break
	if not require(is_instance_valid(sauce),"actual sauce available to scoop"): return false
	var head: Vector2=Vector2(-25,1).rotated(spoon.rotation)
	await move_to(sauce.position-head-spoon._offset,60); await frames(12)
	var held_before: int=spoon.bowl_contents().size()
	var residue_before: float=spoon.liquid_inventory().get("volume_ml",0)
	await move_to(previous_pointer+Vector2(0,-40),60); await hold(2)
	checkpoint("13-spoon")
	for i in 7: _wheel(MOUSE_BUTTON_WHEEL_DOWN); await frames(4)
	if not require(spoon.rotation>.72,"wheel tilts actual wooden spoon"): return false
	await hold(2); _key(KEY_Q); _mouse(previous_pointer,"up"); await frames(30); warp_pointer=true
	if not require(not spoon.active and (held_before>0 or residue_before>0),"real spoon captured sauce before tilting and returning"): return false
	mark("spoon","native bowl capture, slow lift, wheel tilt and Q return")
	stage("盘子也能整只拖动；抬起锅离开炉灶，再靠重力把同一批料理倒进盘里")
	warp_pointer=false
	await drag(game.world.plate.center,Vector2(1420,708),48)
	var handle: Vector2=game.world.pan.point(Vector2(1037,578))
	_mouse(handle,"down"); await frames(3); await move_to(Vector2(1500,420),45)
	if not require(game.world.pan.active and not game.world.pan.on_stove(),"lifted original pan leaves stove"): return false
	_key(KEY_D); await frames(3); _key(KEY_A); await frames(3)
	for i in 2: _wheel(MOUSE_BUTTON_WHEEL_DOWN); await frames(4)
	if not require(game.world.pan.angle>.15,"mouse wheel rotates held original pan"): return false
	for i in 2: _wheel(MOUSE_BUTTON_WHEEL_UP); await frames(4)
	_right(true); await frames(72); _right(false); _mouse(previous_pointer,"up"); await frames(38)
	if not require(game.world.plated,"right button pouring plates original cooking through gravity"): return false
	await restore_pan(); warp_pointer=true; await hold(2)
	mark("pan-and-plate-physics","plate drag, pan lift, A/D rotation, held right tilt and actual gravity pour")
	game._interact("plate"); await hold(1)
	await click("全部装盘"); await arrange_plate(); await click("逆时针")
	await click("成品淋酱"); await plate_sauce(); await hold(2)
	stage("淋酱也能选择瓶子；清除酱线后再画，照片会记录最终摆好的这一盘")
	await click("清除酱汁"); await hold(1)
	var sauces:=find_sauce_selector(game.modal_body)
	if not require(sauces!=null,"native plate sauce chooser present"): return false
	sauces.select(4); sauces.item_selected.emit(4); await hold(2); await plate_sauce()
	await click("拍照并加入菜谱"); await hold(2)
	if not require(game._modal_kind=="recipe_editor" and not game._recipe_photo.is_empty(),"actual practice meal photo opens editable recipe"): return false
	await type_text(game._title_input,"融化与调味实验"); await type_text(game._notes_input,"黄油和芝士软化，豆腐挂酱。木勺舀取，倾锅装盘。")
	await click("加入料理照片"); await hold(2)
	await click("收进我的菜谱"); await hold(2)
	mark("photo-recipe","actual photo added to free collage recipe and saved")
	game._close_modal(); await reset_workspace()
	return true

func _liquid_fraction(id: String) -> float:
	var food:=_food(id)
	if not is_instance_valid(food): return 0
	var thermal: Dictionary=food.get_meta("thermal",{})
	return float(thermal.get("liquid_kg",0))/maxf(.000001,float(thermal.get("initial_kg",food.mass)))

func _right(down: bool) -> void:
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_RIGHT; event.pressed=down
	event.button_mask=MOUSE_BUTTON_MASK_LEFT | (MOUSE_BUTTON_MASK_RIGHT if down else 0)
	event.position=root.get_final_transform()*previous_pointer; event.global_position=event.position
	Input.parse_input_event(event)

func slice_once(id: String) -> bool:
	var food:=_food(id)
	if not require(is_instance_valid(food),"actual board target: "+id): return false
	var center: Vector2=food.position
	_mouse(game.world._knife_handle_rect().get_center(),"down"); await frames(4)
	var offset: Vector2=game.world._knife_drag_offset
	var blade:=Vector2(-50,-22)
	await move_to(center+Vector2(0,-55)-offset-blade,28)
	await move_to(center+Vector2(0,55)-offset-blade,20)
	_mouse(previous_pointer,"up"); await frames(30); _key(KEY_Q); await frames(5)
	return true

func lid_and_char() -> bool:
	chapter_label.text="12 / 锅盖与烧糊"
	await card("12  如果忘记看火候", "积汽预警 · 揭盖泄汽 · 顶飞锅盖 · 焦糊与余热",3)
	stage("把鸡肉拿到菜板切开，再拖一块，让同批切块一起落入锅中")
	if not await _drag_slot("chicken",Vector2(1200,725),30): return false
	await frames(40); await slice_once("chicken")
	var pieces:=_pieces("chicken")
	if not require(pieces.size()>=2,"actual knife produces chicken pieces"): return false
	await drag(pieces[0].position,game.world.pan.point(Vector2(805,560)),32); await frames(50)
	await drag(game.world.lid.HOME,game.world.pan.point(Vector2(810,582)),35)
	if not require(game.world.lid.covered,"lid genuinely seated for hazardous cooking"): return false
	await fire("high")
	stage("加热等待 · 6 倍速：盖住湿食材，盖沿冒汽、颤动和敲击会先提醒你")
	Engine.time_scale=6
	if not await wait_pressure(.57,1800): return false
	Engine.time_scale=1; await hold(3); checkpoint("14-lid-warning")
	stage("看到预警，可以拖开锅盖泄汽，或减火、移锅；揭盖会放出积聚的蒸汽")
	await drag(game.world.lid.position,game.world.lid.HOME,35); await hold(3)
	if not require(not game.world.lid.covered and game.world.lid.pressure==0,"opening actual lid vents real accumulated steam"): return false
	await fire("medium"); await hold(2); await fire("high")
	stage("这次故意继续大火：盖上再摇锅，危险会累积，食物不能穿过盖子")
	await drag(game.world.lid.HOME,game.world.pan.point(Vector2(810,582)),35)
	Engine.time_scale=5
	if not await wait_pressure(.65,1800): return false
	Engine.time_scale=1
	warp_pointer=false
	var handle: Vector2=game.world.pan.point(Vector2(1037,578))
	_mouse(handle,"down"); await frames(2); _mouse(handle+Vector2(0,-42),"move"); await frames(2); _mouse(previous_pointer,"up"); await frames(35)
	if not require(game.world.lid.covered,"lid follows the genuinely shaken pot"): return false
	stage("危险预警加重了，锅盖会被积汽顶起来；现在观察实际的上冲和落地")
	if not await wait_pressure(.84,1000): return false
	checkpoint("15-lid-danger")
	var count:=0
	while game.world.lid.burst_count==0 and count<1400: await frames(1); count+=1
	if not require(game.world.lid.burst_count==1,"real heat triggers one upward lid blast"): return false
	stage("砰！锅盖向上飞起、翻转，食物和汁水飞溅；落稳后盖子还能再用")
	await frames(12); checkpoint("16-lid-blast"); await frames(110)
	if not require(not game.world.lid._flight,"lid naturally lands after the blast"): return false
	for piece in pieces:
		if is_instance_valid(piece) and not game.world.pan.contains(piece.position):
			await drag(piece.position,game.world.pan.point(Vector2(800,560)),32); await frames(40)
	stage("故意忘记关火 · 6 倍速等待：同一块肉从焦黄继续变成焦糊")
	Engine.time_scale=6; count=0
	while max_char(pieces)<.72 and count<2400: await frames(1); count+=1
	Engine.time_scale=1
	if not require(max_char(pieces)>=.72,"real dry heating chars original meat surface"): return false
	stage("锅铲往上翻动，露出真正烧焦的底面；焦色、焦味提醒和烟一起出现")
	var tool=game.world.utensils[0]
	_mouse(tool.to_global(Vector2(-24,0)),"down"); await frames(5)
	if not require(tool.active,"black spatula selected from cup"): return false
	var center:=Vector2.ZERO
	for piece in pieces: center+=piece.position
	center/=pieces.size()
	_mouse(center+Vector2(-80,55)-tool._offset,"move"); await frames(8)
	_mouse(center+Vector2(85,-45)-tool._offset,"move"); await frames(40)
	_mouse(previous_pointer,"up"); await frames(8)
	if not require(visible_char(pieces)>=.7,"native spatula exposes actual charred face"): return false
	await hold(4); checkpoint("17-burnt-food")
	stage("及时关火；锅仍有余热，烧糊的历史不会因为关火或加水就恢复")
	await fire("off"); await hold(3); warp_pointer=true
	mark("lid-and-burning","real warnings, vent, shake, upward blast/landing, charred face flip and residual heat")
	game._show_pause(); await click("准备好了，开始营业")
	game._interact("plate"); await click("全部装盘"); await click("拍照并交给顾客"); await hold(2)
	await click("看看客人的反馈"); await hold(6); checkpoint("18-burnt-review")
	if not require(game.session.served==1,"charred actual meal reaches customer feedback"): return false
	await click("继续招待下一位"); await reset_workspace(); await clean_pan()
	mark("mistake-feedback","charred meal photographed/served, feedback read, dirty pot cleaned")
	return true

func wait_pressure(target: float,limit: int) -> bool:
	var count:=0
	while game.world.lid.pressure<target and game.world.lid.burst_count==0 and count<limit: await frames(1); count+=1
	return require(game.world.lid.pressure>=target,"actual heating reaches pressure warning "+str(target))

func max_char(foods: Array) -> float:
	var result:=0.0
	for food in foods:
		if is_instance_valid(food):
			var s: Dictionary=food.get_meta("thermal",{})
			if not s.is_empty(): result=maxf(result,maxf(float(s.char[0]),float(s.char[1])))
	return result

func visible_char(foods: Array) -> float:
	var result:=0.0
	for food in foods:
		if is_instance_valid(food):
			var s: Dictionary=food.get_meta("thermal",{})
			if not s.is_empty(): result=maxf(result,float(s.char[1-int(s.contact_face)]))
	return result

func flood_and_recovery() -> bool:
	chapter_label.text="14 / 溢水与水淹厨房"
	await card("14  水满了，会发生什么？", "水进入锅里 → 越过锅沿 → 水槽满溢 → 厨房水位上涨",4)
	stage("把空锅搬到水槽接水；这次持续打开水龙头，观察水先填满锅")
	await fill_pan()
	warp_pointer=false
	var handle: Vector2=game.world.pan.point(Vector2(1037,578))
	await drag(handle,handle+Vector2(-612,0),42); await frames(16)
	if not require(game.world.pan.under_tap(),"pot under faucet for real overflow"): return false
	await tap(true)
	var count:=0
	while not game.world.pan.overflowing and count<600: await frames(1); count+=1
	if not require(game.world.pan.overflowing and game.world.pan.water_ml>=1499,"real faucet fills 1500ml pot to its brim"): return false
	stage("锅满后，水从锅内越过两侧锅沿，沿外壁落进水槽；不是从锅底漏出")
	await hold(5); checkpoint("19-overflow-from-rim")
	var path: PackedVector2Array=game.world.pan.faucet_art.overflow_path(1)
	if not require(game.world.pan.contains(path[0]) and path[1].y<path[3].y,"visible overflow begins inside pot and crosses upper rim"): return false
	stage("忘了关水 · 2 倍速等待：水槽也满了，地面积水才开始往上淹")
	Engine.time_scale=2; count=0
	while game.world.flood_ratio()<.45 and count<1800: await frames(1); count+=1
	Engine.time_scale=1
	if not require(game.world.flood_ratio()>=.45,"actual overflow reaches rising room flood"): return false
	await hold(3); checkpoint("20-rising-water")
	stage("继续放水 · 2 倍速：整个厨房会被淹没，先去关水龙头")
	Engine.time_scale=2; count=0
	while game.world.flood_ratio()<1 and count<1800: await frames(1); count+=1
	Engine.time_scale=1
	if not require(game.world.flood_ratio()>=1,"actual runoff fully floods kitchen"): return false
	await hold(3); checkpoint("21-full-flood")
	await tap(false)
	var before: float=game.world.flood_water_ml
	stage("向上回转把手关闭水龙头，停止新进水；已经积起来的水会逐渐排走")
	await hold(4)
	if not require(not game.world.pan.faucet_on and game.world.flood_water_ml<before,"closing handle stops supply and drains existing water"): return false
	stage("排水等待 · 4 倍速：水位连续下降，锅里已经接到的水仍然保留")
	Engine.time_scale=4; count=0
	while (game.world.flood_water_ml>0 or game.world.sink_water_ml>0) and count<1800: await frames(1); count+=1
	Engine.time_scale=1
	if not require(game.world.flood_water_ml==0 and game.world.pan.water_ml>1490,"standing room water drains without erasing pot water"): return false
	await hold(3); checkpoint("22-drained-room")
	stage("客人也有等待时间；忙着处理厨房意外时，留意右上纸条与营业时钟")
	await hold(4)
	stage("锅里的水另行处理：按住锅柄，用右键倾锅，水越过低侧锅沿倒入水槽")
	_mouse(game.world.pan.point(Vector2(1037,578)),"down"); await frames(4)
	var retained: float=game.world.pan.water_ml
	var sink_before: float=game.world.sink_water_ml+game.world.flood_water_ml+game.world.drained_flood_ml
	_right(true)
	for i in 40:
		var correction: Vector2=Vector2(-612,game.world.pan.HOME.y)-game.world.pan.offset
		_mouse(previous_pointer+correction,"move"); await frames(1)
	_right(false); _mouse(previous_pointer,"up"); await frames(30)
	if not require(game.world.pan.water_ml==0,"right tilt actually drains retained pot water at sink"): return false
	if not require(absf(game.world.sink_water_ml+game.world.flood_water_ml+game.world.drained_flood_ml-sink_before-retained)<.01,"poured pot water is conserved in sink/floor/drain"): return false
	await restore_pan(); warp_pointer=true; await hold(2)
	mark("overflow-flood-and-drain","1500ml capacity, visible rim-origin overflow, sink/floor/full-room rise, tap shutoff, continuous drain, retained pot emptied separately")
	stage("洒到台面的调料也有实际用量；海绵拖过污渍可以擦掉，抹布负责锅内残味")
	if not await fill_pan(): return false
	# Nearly fill using the same faucet, then overfill with finite sauce.
	warp_pointer=false
	handle=game.world.pan.point(Vector2(1037,578)); await drag(handle,handle+Vector2(-612,0),42); await frames(15)
	await tap(true); count=0
	while game.world.pan.water_ml<1499 and count<500: await frames(1); count+=1
	await tap(false); await restore_pan(); warp_pointer=true
	if not await seasoning("mayonnaise",1.5,false): return false
	var spill: RigidBody2D
	for body in game.world._foods.get_children():
		if body.get_meta("overflow",false) and not body.is_queued_for_deletion(): spill=body; break
	if not require(is_instance_valid(spill),"full pot creates actual finite seasoning spill"): return false
	await hold(3); checkpoint("23-spill")
	warp_pointer=false
	var sponge=game.world.sponge
	_mouse(sponge.position,"down"); await frames(3); await move_to(spill.position-sponge.grab_offset,48); await frames(6)
	_mouse(previous_pointer,"up"); await frames(12); warp_pointer=true
	if not require(not is_instance_valid(spill),"sponge removes actual counter spill"): return false
	await reset_workspace(); await hold(2)
	mark("counter-spill-and-sponge","finite sauce overflows full pot; native sponge removes the spill")
	return true

func odd_experiment() -> bool:
	var served_before: int=game.session.served
	chapter_label.text="15 / 奇物与组合"
	await card("15  不按常规，也能试试", "软硬材质 · 不可切提示 · 奇物调料 · 自由出餐",3)
	stage("奇物架上也是可取用的东西：闹钟是硬质物件，菜刀切不开")
	if not await _drag_slot("alarm_clock",Vector2(1200,725),30): return false
	await frames(30); await slice_once("alarm_clock"); await hold(3)
	if not require(_pieces("alarm_clock").is_empty(),"actual knife cannot split hard alarm clock"): return false
	var clock:=_food("alarm_clock")
	await drag(clock.position,game.world.pan.point(Vector2(795,560)),36); await frames(35)
	stage("软材质奇物可以切开；这次把幻想袜子切开，与硬质物件一起实验")
	if not await _drag_slot("sock",Vector2(1200,725),30): return false
	await frames(30); await slice_once("sock")
	var pieces:=_pieces("sock")
	if not require(pieces.size()>=2,"soft strange material cut by real knife"): return false
	await drag(pieces[0].position,game.world.pan.point(Vector2(840,560)),34); await frames(40)
	stage("香水属于可倾倒的奇物；牙膏是有限余量软管，也能按住挤出")
	if not await seasoning("perfume",1.0): return false
	if not await seasoning("toothpaste",1.0): return false
	await stir(); await fire("medium"); await hold(4); await fire("off")
	if not require(_dish_has("alarm_clock") and _dish_has("sock") and _material_present("perfume") and _material_present("toothpaste"),"real odd combination remains in actual cooking"): return false
	checkpoint("24-odd-combination")
	stage("组合也能装盘与出餐；顾客的偏好、忌口和新奇程度会反映在评价里")
	game._interact("plate"); await hold(2)
	# Demonstrate selective batch transfer before the remaining food.
	var batch_button:=find_button("幻想袜子")
	if batch_button!=null: await click("幻想袜子"); await hold(2)
	await click("全部装盘"); await arrange_plate(); await click("拍照并交给顾客"); await hold(3)
	await click("看看客人的反馈"); await hold(6); checkpoint("25-odd-review")
	if not require(game.session.served==served_before+1,"odd experiment actually reviewed by third customer"): return false
	await click("继续招待下一位"); await click("回信",game.hud); await hold(4); game._close_modal()
	mark("odd-and-reviews","hard/soft strange materials, actual perfume/toothpaste, selective plating, photo, customer feedback and saved letters")
	await reset_workspace()
	return true

func paper_and_exchange() -> bool:
	chapter_label.text="16 / 拼贴与菜谱交换"
	await card("16  纸上还能怎么玩", "照片与材料 · 文字 · 胶带 · 剪贴 · 撤销 · 保存与分享",3)
	stage("除了手绘菜谱，海报和自由拼贴手记还可以贴实拍照片、材料与小装饰")
	await click("海报",game.hud)
	# First main session poster is held in its own live state, so this practice
	# begins on white paper; this button may be disabled, build our own poster.
	await click("加入料理照片"); await hold(2)
	var canvas=game._poster_canvas
	if not require(not canvas.stickers.is_empty(),"last actual odd meal photo added to poster"): return false
	await click("移动素材")
	await canvas_drag(canvas,canvas._pixel(canvas.stickers[0].position),Vector2(240,220),36)
	stage("选中照片后，滚轮改大小，边角柄调方向；照片和材料都能剪成自己的形状")
	var selected: int=canvas.selected_index
	var size_before: float=canvas.stickers[selected].scale
	for i in 2: canvas_wheel(canvas,MOUSE_BUTTON_WHEEL_UP); await frames(5)
	if not require(canvas.stickers[selected].scale>size_before,"poster wheel resizes actual photo"): return false
	var handles: Dictionary=canvas.transform_handles()
	if handles.has("rotate"):
		var pivot: Vector2=canvas._pixel(canvas.stickers[selected].position)
		await canvas_drag(canvas,handles.rotate,pivot+(handles.rotate-pivot).rotated(.25),26)
		if not require(absf(float(canvas.stickers[selected].get("rotation",0)))>.20,"native photo corner drag changes real rotation"): return false
	await click("剪出形状")
	var photo_center: Vector2=canvas._pixel(canvas.stickers[canvas.selected_index].position)
	for delta in [Vector2(-54,-28),Vector2(50,-30),Vector2(60,23),Vector2(-52,26)]:
		canvas_press(canvas,photo_center+delta); await hold(.6)
	canvas_key(canvas,KEY_ENTER); await hold(2)
	if not require(canvas.stickers[canvas.selected_index].has("mask"),"native point scissors create a real photo mask"): return false
	await click("恢复原图"); await hold(1)
	stage("恢复原图可以撤掉剪裁；复制、移到底层、删除，都可以再撤销和重做")
	await click("复制"); await hold(1); await click("移到底层"); await hold(1)
	await click("删除"); await hold(1); await click("撤销"); await hold(1); await click("重做"); await hold(1)
	stage("胶带和小贴纸能拖到纸上；选中后调颜色、长度和宽度，再摆到合适位置")
	var token: Control=find_named_token(game.modal_body,"tape")
	if not require(token!=null,"real decoration tray has tape"): return false
	var drag_payload: Dictionary=token.payload.duplicate(true)
	drag_payload["source"]="kitchen-collage"
	await move_to(token.get_global_rect().get_center(),14)
	pointer.down=true; pointer.queue_redraw()
	await move_to(canvas.get_global_transform_with_canvas()*Vector2(230,128),28)
	canvas._drop_data(Vector2(230,128),drag_payload); pointer.down=false; pointer.queue_redraw(); await hold(1)
	await canvas_drag(canvas,canvas._pixel(canvas.stickers[canvas.selected_index].position),Vector2(230,126),22)
	var length_slider: HSlider=game.modal_body.find_child("TapeLength",true,false)
	var width_slider: HSlider=game.modal_body.find_child("TapeWidth",true,false)
	length_slider.drag_started.emit(); length_slider.value=2.5; length_slider.drag_ended.emit(true)
	width_slider.drag_started.emit(); width_slider.value=1.45; width_slider.drag_ended.emit(true)
	var picker: ColorPickerButton=game.modal_body.find_child("CollageColor",true,false)
	picker.color=Color("bb8058"); picker.color_changed.emit(picker.color); await hold(2)
	var tape_settings: Dictionary=canvas.selected_decoration_settings()
	if not require(float(tape_settings.get("length",0))>2 and float(tape_settings.get("width",0))>1,"native tape controls change two dimensions"): return false
	stage("自己的图片也能导入；做过这餐的材料，可以作为保持原状态的贴纸放到纸上")
	var picture:=Image.new()
	if not require(picture.load_png_from_buffer(Marshalls.base64_to_raw(game._photo))==OK,"actual served photo decodes for local import"): return false
	var picture_path:=output.path_join("实验料理实拍.png")
	picture.save_png(picture_path)
	await click("导入照片"); await hold(1); choose_file(picture_path); await hold(2)
	await canvas_drag(canvas,canvas._pixel(canvas.stickers[canvas.selected_index].position),Vector2(610,285),28)
	var material: Button=game.modal_body.find_child("UsedIngredient_alarm_clock",true,false)
	if not require(material!=null,"actual used ingredient appears in paper material tray"): return false
	material.pressed.emit(); await hold(1)
	await canvas_drag(canvas,canvas._pixel(canvas.stickers[canvas.selected_index].position),Vector2(550,265),24)
	await hold(2)
	stage("在纸上写字，双击还能改写；细笔、铅笔和宽笔各有不同笔触")
	await click("纸上写字"); canvas_press(canvas,Vector2(440,65)); await frames(2)
	await type_text(canvas._text_editor,"欢迎来做一场厨房实验"); canvas.finish_text(); await hold(2)
	var text_index: int=canvas.stickers.size()-1
	var edit_event:=InputEventMouseButton.new(); edit_event.button_index=MOUSE_BUTTON_LEFT; edit_event.pressed=true; edit_event.double_click=true
	edit_event.position=canvas._pixel(canvas.stickers[text_index].position)
	canvas.mode="select"; canvas._gui_input(edit_event); await frames(2)
	if not require(is_instance_valid(canvas._text_editor),"double click reopens native poster text"): return false
	await type_text(canvas._text_editor,"欢迎来尝一场厨房实验"); canvas.finish_text(); await hold(2)

	await click("铅笔"); await canvas_path(canvas,[Vector2(395,110),Vector2(430,95),Vector2(461,111),Vector2(496,94)],3)
	await click("宽笔"); await canvas_path(canvas,[Vector2(405,120),Vector2(485,120)],4)
	await click("细笔"); await canvas_path(canvas,[Vector2(396,132),Vector2(501,132)],3)
	checkpoint("26-paper-craft")
	await click("贴出去：怪味特供"); await hold(3)
	if not require(not game._poster_data.is_empty(),"decorated photo poster actually published"): return false
	await click("海报",game.hud); await click("继续编辑已贴出的海报"); await hold(3)
	if not require(not game._poster_canvas.strokes.is_empty(),"published poster reopened with strokes and editable layers"): return false
	game._close_modal()
	mark("paper-craft","native photo move/resize/rotate, scissors/restore, duplicate/layers/delete/undo/redo, tape colour/dimensions, text, three pen widths, publish and re-edit")
	stage("菜谱翻页、点赞、导出与导入都在厨房手记里；本地文件可以带回游戏继续编辑")
	await click("菜谱",game.hud); await click("融化与调味实验"); await hold(2)
	await click("喜欢这道菜"); await hold(1); await click("← 上一页"); await hold(2); await click("下一页 →"); await hold(2)
	var recipe_count: int=game.repository.load_recipes().size()
	game._show_cookbook(); await click("导出菜谱文件"); await hold(1)
	var exchange:=output.path_join("厨房示范菜谱.json")
	choose_file(exchange); await hold(2)
	if not require(FileAccess.file_exists(exchange),"native cookbook export creates local JSON"): return false
	await click("导入其他人的菜谱"); await hold(1); choose_file(exchange); await hold(2)
	if not require(game.repository.load_recipes().size()==recipe_count,"import preserves recipes and deduplicates same IDs"): return false
	checkpoint("27-recipe-exchange"); game._close_modal()
	mark("recipe-exchange","recipe pages, like, full JSON export/import and same-ID deduplication")
	return true

func find_named_token(parent: Node,kind: String) -> Control:
	for node in parent.get_children():
		if node.get_script()==preload("res://modules/restaurant/ui/craft_token.gd") and node.payload.get("kind","")==kind: return node
		var found:=find_named_token(node,kind)
		if found!=null: return found
	return null

func choose_file(path: String) -> void:
	for node in game.modal.get_children():
		if node is FileDialog: node.file_selected.emit(path); return
	require(false,"native file dialog present")

func canvas_press(canvas,point: Vector2) -> void:
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true; event.position=point
	canvas._gui_input(event); pointer.position=canvas.get_global_transform_with_canvas()*point; pointer.show()
	event.pressed=false; canvas._gui_input(event)

func canvas_key(canvas,key: Key) -> void:
	var event:=InputEventKey.new(); event.keycode=key; event.pressed=true; canvas._gui_input(event)

func canvas_wheel(canvas,button: MouseButton) -> void:
	var event:=InputEventMouseButton.new(); event.button_index=button; event.pressed=true
	event.position=canvas._pixel(canvas.stickers[canvas.selected_index].position); canvas._gui_input(event)

func canvas_drag(canvas,from: Vector2,to: Vector2,count: int) -> void:
	var press:=InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=from
	canvas._gui_input(press); pointer.show(); pointer.down=true; pointer.queue_redraw()
	for i in count:
		var point:=from.lerp(to,float(i+1)/count)
		var motion:=InputEventMouseMotion.new(); motion.position=point; motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		if not canvas._transform_mode.is_empty():
			motion.position=canvas.get_global_transform_with_canvas()*point; canvas._input(motion)
		else: canvas._gui_input(motion)
		pointer.position=canvas.get_global_transform_with_canvas()*point; await frames(1)
	press.position=to; press.pressed=false
	if not canvas._transform_mode.is_empty():
		press.position=canvas.get_global_transform_with_canvas()*to; canvas._input(press)
	else: canvas._gui_input(press)
	pointer.down=false; pointer.queue_redraw(); await frames(3)

func canvas_path(canvas,points: Array,rate: int) -> void:
	var press:=InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=points[0]; canvas._gui_input(press)
	for i in points.size()-1:
		var from: Vector2=points[i]; var to: Vector2=points[i+1]
		for j in ceili(from.distance_to(to)/rate):
			var point:=from.move_toward(to,(j+1)*rate)
			var event:=InputEventMouseMotion.new(); event.position=point; event.button_mask=MOUSE_BUTTON_MASK_LEFT; canvas._gui_input(event)
			pointer.show(); pointer.position=canvas.get_global_transform_with_canvas()*point; await frames(1)
	press.pressed=false; canvas._gui_input(press); pointer.hide(); await frames(2)

func complete_recipe_guide() -> bool:
	chapter_label.text="13 / 真正照着菜谱做"
	await card("跟着一页菜谱，再做一餐", "提示随真正的取材、切配、熟度和盛汤推进",3)
	stage("选「番茄清汤面」，按「照着做」；底部提示会跟着真实操作变化")
	await click("菜谱",game.hud); await click("番茄清汤面"); await hold(2); await click("照着做这道菜"); await hold(2)
	if not await _drag_slot("tomato",Vector2(1200,725),32): return false
	await frames(35); await slice_once("tomato")
	var slices:=_pieces("tomato")
	if not require(slices.size()>=2,"guide tomato actually cut"): return false
	await drag(slices[0].position,game.world.pan.point(Vector2(795,560)),32); await frames(40)
	if not await fill_pan(): return false
	if not await _drag_slot("noodles",game.world.pan.point(Vector2(845,560)),30): return false
	await frames(40); await fire("high")
	stage("跟做煮面 · 4 倍速等待：番茄加热，面条吸水变软，满足做法才会完成")
	Engine.time_scale=4
	var count:=0
	while count<2000:
		await frames(1); count+=1
		game._update_recipe_guide()
		if game.recipe_guide.index>=game.recipe_guide.sequence.size()-1: break
	Engine.time_scale=1
	if not require(game.recipe_guide.index>=game.recipe_guide.sequence.size()-1,"native guide observes real take/cut/water/pan/cook success"): return false
	await fire("off"); await hold(2)
	game._interact("plate"); await click("全部装盘"); await click("汤碗")
	await click("从锅盛汤"); await click("从锅盛汤"); await click("从锅盛汤")
	await click("完成摆盘，回厨房"); await frames(10); game._update_recipe_guide()
	if not require(game.recipe_guide.index==game.recipe_guide.sequence.size(),"guide genuinely completes only after real food/broth plating"): return false
	stage("所有环节完成，提示才显示「这一餐做好了」；这碗面接着交给下一位客人")
	await hold(4); checkpoint("28-completed-guide")
	await click("收起引导",game.hud)
	game._interact("plate"); await click("拍照并交给顾客"); await hold(2); await click("看看客人的反馈"); await hold(5)
	await click("继续招待下一位"); await reset_workspace(); await clean_pan()
	mark("follow-complete","starter guide progresses on actual operations and completes after broth plating; second genuine served meal")
	return true

func find_sauce_selector(parent: Node) -> OptionButton:
	for child in parent.get_children():
		if child is OptionButton and child.item_count==6 and str(child.get_item_metadata(4))=="soy_sauce": return child
		var found:=find_sauce_selector(child)
		if found!=null: return found
	return null
