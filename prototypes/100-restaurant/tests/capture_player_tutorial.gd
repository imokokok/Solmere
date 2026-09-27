extends SceneTree
## Automated pointer gestures in the production game, not raster/vector font glyphs.
const FPS := 24
var game
var caption: Label
var pointer: DemoPointer
var frame := 0
var timeline: Array = []
var folder := ""
var output := ""
var pilot := false
var capture_probe := false
var previous_pointer := Vector2.ZERO
var original_pointer := Vector2.ZERO
var held_mouse := false
var warp_pointer := true
var chapter_label: Label
var overlay: CanvasLayer
var checks := 0

class CaptureRestaurant extends "res://modules/restaurant/restaurant.gd":
	# Recording-only storage isolation. Gameplay and all renderers are inherited.
	func _load_letters() -> void:
		_letters.clear()
	func _persist_letters() -> void:
		var target: String=repository.storage_path.get_base_dir().path_join("letters.json")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
		var file:=FileAccess.open(target,FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(_letters,"  "))

class DemoPointer extends Control:
	var down := false
	func _draw() -> void:
		if down: draw_circle(Vector2(4,5),14,Color("ead3a0",.35))
		var arrow := PackedVector2Array([Vector2.ZERO,Vector2(2,23),Vector2(9,16),Vector2(15,21),Vector2(19,17),Vector2(13,11),Vector2(22,8)])
		draw_colored_polygon(arrow,Color("fff8e8")); arrow.append(Vector2.ZERO)
		draw_polyline(arrow,Color("314d43"),1.5,true)

func _initialize() -> void:
	root.size=Vector2i(1352,852); root.content_scale_size=Vector2i(1600,1008)
	call_deferred("run")

func hold(seconds: float) -> void:
	await frames(maxi(1,roundi(seconds*FPS*(0.12 if pilot else 0.80))))

func frames(count: int) -> void:
	for i in count:
		await process_frame
		RenderingServer.force_draw(false)
		await create_timer(0.000001).timeout
		frame+=1
		if capture_probe and is_instance_valid(caption): caption.text="录制验证 · 帧 %d" % frame

func stage(words: String) -> void:
	caption.text=words; timeline.append({"seconds":float(frame)/FPS,"caption":words})
	print("TUTORIAL_STAGE ",frame," ",words)

func require(ok: bool, words: String) -> bool:
	checks+=1
	if not ok:
		push_error(words)
		if is_instance_valid(game):
			print("REPOSITORY_ERROR: ",game.repository.get_last_error())
			if is_instance_valid(game._editor_status): print("EDITOR_STATUS: ",game._editor_status.text)
			var failure:=FileAccess.open(output.path_join("failure-dish.json"),FileAccess.WRITE)
			failure.store_string(JSON.stringify(game._recipe_dish,"  "))
			checkpoint("failure")
		quit(3)
	else: print("TUTORIAL_CHECK ",words)
	return ok

func find_button(words: String, parent: Node = null) -> Button:
	if parent==null: parent=game.modal_body
	for child in parent.get_children():
		if child is Button and child.is_visible_in_tree() and not child.is_queued_for_deletion() and child.text.begins_with(words): return child
		var found := find_button(words,child)
		if found!=null: return found
	return null

func click(words: String, parent: Node = null) -> void:
	var control := find_button(words,parent)
	if not require(control!=null,"button: "+words): return
	pointer.position=control.get_global_rect().get_center(); pointer.show(); await hold(.25)
	pointer.down=true; pointer.queue_redraw(); control.pressed.emit(); await hold(.15)
	pointer.down=false; pointer.queue_redraw(); await hold(.35); pointer.hide()

func color(index: int) -> void:
	var control: Button=game.modal_body.find_child("RecipeInk%d" % index,true,false)
	pointer.position=control.get_global_rect().get_center(); pointer.show(); await hold(.15)
	control.pressed.emit(); await hold(.15); pointer.hide()

func path(vertices: Array, rate := 3, eraser := false) -> void:
	var canvas=game._recipe_canvas
	var points: Array = []
	for i in vertices.size()-1:
		var start := Vector2(vertices[i][0],vertices[i][1])
		var end := Vector2(vertices[i+1][0],vertices[i+1][1])
		var count := maxi(1,ceili(start.distance_to(end)/4.0))
		for j in count: points.append(start.lerp(end,float(j)/count))
	points.append(Vector2(vertices[-1][0],vertices[-1][1]))
	canvas.mode="erase" if eraser else "draw"
	pointer.show(); pointer.down=true; pointer.queue_redraw()
	var press := InputEventMouseButton.new(); press.position=points[0]; press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true
	canvas._gui_input(press)
	for i in points.size():
		var motion := InputEventMouseMotion.new(); motion.position=points[i]; motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		canvas._gui_input(motion); pointer.position=canvas.get_global_transform_with_canvas()*points[i]
		if i%(rate*12 if pilot else rate)==0: await hold(1.0/FPS)
	press.position=points[-1]; press.pressed=false; canvas._gui_input(press)
	pointer.down=false; pointer.queue_redraw(); await hold(.08)

func ellipse(center: Vector2, radius: Vector2, steps := 34) -> void:
	var vertices: Array = []
	for i in steps+1:
		var p := center+Vector2(cos(float(i)/steps*TAU),sin(float(i)/steps*TAU))*radius
		vertices.append([p.x,p.y])
	await path(vertices)

func letter(strokes: Array, origin: Vector2) -> void:
	for stroke in strokes:
		var points: Array=[]
		for p in stroke: points.append([origin.x+p[0]*.9,origin.y+p[1]*.9])
		await path(points,2)

func setup_overlay() -> void:
	overlay=CanvasLayer.new(); overlay.layer=120; root.add_child(overlay)
	var bar := ColorRect.new(); bar.position=Vector2(0,946); bar.size=Vector2(1600,62); bar.color=Color("193e37")
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE; overlay.add_child(bar)
	caption=Label.new(); caption.position=Vector2(26,958); caption.size=Vector2(1220,38)
	caption.add_theme_font_override("font",preload("res://modules/restaurant/ui/paper_ink.gd").font()); caption.add_theme_font_size_override("font_size",24)
	caption.add_theme_color_override("font_color",Color("fff4d9")); caption.mouse_filter=Control.MOUSE_FILTER_IGNORE; overlay.add_child(caption)
	chapter_label=Label.new(); chapter_label.text="100 饭店 · 上手指南"; chapter_label.position=Vector2(1265,971); chapter_label.size.x=310
	chapter_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	chapter_label.add_theme_font_override("font",preload("res://modules/restaurant/ui/paper_ink.gd").font()); chapter_label.add_theme_font_size_override("font_size",18)
	chapter_label.add_theme_color_override("font_color",Color("b6cbb9")); chapter_label.mouse_filter=Control.MOUSE_FILTER_IGNORE; overlay.add_child(chapter_label)
	pointer=DemoPointer.new(); pointer.mouse_filter=Control.MOUSE_FILTER_IGNORE; overlay.add_child(pointer); pointer.hide()

func card(title: String, subtitle: String, seconds := 2.5) -> void:
	pointer.hide()
	var previous_mode: int=game.process_mode
	game.process_mode=Node.PROCESS_MODE_DISABLED
	var shade:=ColorRect.new(); shade.size=Vector2(1600,946); shade.color=Color("183e36",0); shade.mouse_filter=Control.MOUSE_FILTER_IGNORE; overlay.add_child(shade)
	var box:=VBoxContainer.new(); box.position=Vector2(180,340); box.size=Vector2(1240,280); box.add_theme_constant_override("separation",24); shade.add_child(box)
	for pair in [["100 RESTAURANT",20],[title,58],[subtitle,27]]:
		var label:=Label.new(); label.text=pair[0]; label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font",preload("res://modules/restaurant/ui/paper_ink.gd").font()); label.add_theme_font_size_override("font_size",pair[1]); label.add_theme_color_override("font_color",Color("fff1d2")); box.add_child(label)
	for i in 12:
		shade.color.a=float(i+1)/12*.94; box.modulate.a=float(i+1)/12; await frames(1)
	await hold(seconds)
	for i in 12:
		shade.color.a=(1-float(i+1)/12)*.94; box.modulate.a=1-float(i+1)/12; await frames(1)
	shade.queue_free(); game.process_mode=previous_mode

func checkpoint(name: String) -> void:
	root.get_texture().get_image().save_png(output.path_join(name+".png"))

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name()=="headless": quit(1); return
	output=args[0]; pilot=args.size()>1 and args[1]=="pilot"
	capture_probe=args.size()>1 and args[1]=="probe"
	DirAccess.make_dir_recursive_absolute(output)
	game=CaptureRestaurant.new()
	var roster: Array=JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/data/customers.json"))
	game.configure({"npc_profiles":roster,"repository_path":"user://player_tour_"+Crypto.new().generate_random_bytes(16).hex_encode()+"/book.json","display_name":"小满"})
	root.add_child(game); await process_frame
	original_pointer=root.get_mouse_position(); setup_overlay()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true)
	stage("欢迎来到 100 饭店：今天，从一颗番茄做出自己的第一道菜")
	await card("把这一餐，做成自己的作品", "取材 · 切配 · 烹饪 · 摆盘 · 留下你的招牌",5)
	await hold(3)
	if args.size()>1 and args[1]=="probe":
		print("PROBE_DONE ",frame); quit(0); return
	await click("先在厨房练习"); await hold(2)
	chapter_label.text="01 / 认识厨房"
	stage("第一次来，可以先在准备期练习；准备期不限时，熟悉以后再开始营业")
	await hold(5)
	stage("冰箱找食材，右侧菜板切配；左边水槽，中间炉灶，盘子用来装盘")
	await card("01  认识厨房与取材", "熟悉取材和工具，再开始今天的营业")
	for point in [Vector2(227,282),Vector2(1240,725),Vector2(210,690),Vector2(790,687),Vector2(603,744)]:
		await move_to(point,12); await hold(.8)
	stage("冰箱和奇物架可以翻层；每件食材取出后，原位会留空")
	game.storage_display._scroll_fridge(1); await hold(2)
	game.storage_display._turn_page("fridge",1); await hold(2)
	game.storage_display._turn_page("odd",1); await hold(3); checkpoint("02-storage")
	game.storage_display._turn_page("odd",-1)
	stage("除了家常食材，还有奇物可以试；先用番茄和鸡蛋做一餐")
	await hold(2)
	stage("按 TAB 打开食材柜，也可以直接搜索想找的原料")
	_key(KEY_TAB); await hold(1)
	var search:=find_edit(game.modal_body,"LineEdit")
	await type_text(search,"番茄"); search.text_changed.emit(search.text); await hold(3); game._close_modal()
	chapter_label.text="02 / 真实切配"
	await card("02  切片，再切成块", "按住刀柄，让刀刃划过真正的食材")
	stage("把番茄放到右侧菜板；按住刀柄，顺箭头从一侧压切到另一侧")
	if not await _drag_slot("tomato",Vector2(1200,725),32): return
	await hold(3)
	if not await cutting(): return
	checkpoint("03-cut-and-toss")
	stage("鸡蛋在锅沿轻敲两次：先裂壳，再让蛋液落进锅里")
	if not await _crack_egg_from_shelf(): return
	await hold(3)
	if not require(_dish_has("egg"),"actual cracked egg admitted to pan"): return
	stage("食材准备好了，再开始今天的营业；记得先听听客人的想法")
	game._show_pause(); await hold(2); await click("准备好了，开始营业")
	stage("先看看客人留的小纸条：今天的经历、想吃的味道，都在这里")
	game._show_order_paper(); await hold(9); checkpoint("01-order")
	game._close_modal()
	stage("点击「聊聊口味」，还能听客人说今天的故事")
	await click("聊聊口味",game.hud); await hold(4)
	await click("聊聊口味",game.hud); await hold(4)
	chapter_label.text="03 / 火候与调味"
	await card("03  看食物变化，掌握火候", "翻炒、加料和调味，都会留在这一餐里")
	stage("点击灶台的大火开始加热；看蛋液凝固和食材变色")
	await fire("high"); await hold(3)
	var egg:=_food("egg")
	var waits:=0
	var reduced:=false
	if pilot: Engine.time_scale=3
	while is_instance_valid(egg) and float(egg.get_meta("thermal",{}).get("cooked",0))<.99 and waits<1800:
		if waits==168: stage("火候需要一点耐心；锅温升高后，会听到真实的煎炒声")
		if not reduced and float(egg.get_meta("thermal",{}).get("cooked",0))>=.65:
			reduced=true; await fire("medium")
			stage("鸡蛋逐渐成形，转中火继续；留意中心熟度，别只看表面颜色")
		await frames(1); waits+=1
	Engine.time_scale=1
	if not require(is_instance_valid(egg) and float(egg.get_meta("thermal",{}).get("cooked",0))>=.99,"real heat cooks the same egg"): return
	await fire("low"); await hold(1)
	stage("做好后及时关火，让余热继续工作；烧焦的食物不会自动恢复")
	await fire("off"); await hold(2)
	stage("瓶口对准锅内，按住挤出番茄酱；松开，就会停止出料")
	if not await seasoning("ketchup",2.4): return
	await hold(2)
	stage("拿起木铲轻轻推拌，让切块和酱汁碰到一起")
	if not await stir(): return
	await hold(2); checkpoint("04-cooked")
	chapter_label.text="04 / 摆盘与摄影"
	await card("04  从锅里，到盘中", "同一批食物，摆成你喜欢的样子")
	stage("点击盘子进入摆盘；选择「全部装盘」，每一块都来自刚才那口锅")
	game._interact("plate"); await hold(3)
	await click("全部装盘"); await hold(4)
	if not require(game.world.plated,"real bodies are plated"): return
	stage("在盘中拖动食物，选中后还能旋转；摆盘也能自由调整")
	await arrange_plate(); await hold(3)
	stage("切到「成品淋酱」，在盘边画一条酱汁；用量会从瓶中扣除")
	await click("成品淋酱"); await plate_sauce(); await hold(3)
	checkpoint("05-plating")
	stage("拍照并交给顾客：照片记录当前这一盘，不会换成预制菜图")
	await click("拍照并交给顾客"); await hold(3)
	if not require(not game._photo.is_empty() and game._photo_is_plating and game._modal_kind=="dish_showcase","real plate photographed and served"): return
	checkpoint("06-dish-photo"); await hold(3)
	chapter_label.text="05 / 顾客与回信"
	stage("顾客各有口味，反馈会告诉你哪里能改；评分、心情和收入也会留下")
	await click("看看客人的反馈"); await hold(8); checkpoint("07-feedback")
	if not require(game.session.served==1 and game._letters.size()==1,"one actual customer reviewed the served meal"): return
	stage("也可以写一封回复；这些反馈会留在「回信」里")
	var reply:=find_edit(game.modal_body,"TextEdit")
	if reply!=null: await type_text(reply,"谢谢你的认真评价，下次再来尝尝我的新菜！")
	await click("保存回复"); await hold(2)
	await click("继续招待下一位")
	chapter_label.text="06 / 手绘菜谱"
	await card("06  留下自己的招牌菜谱", "名字亲手写，配图亲手画；下一次还可以接着改")
	stage("打开菜谱，选择「新建 DIY 菜谱」，把刚刚做的这一餐留下来")
	game._show_cookbook(); await hold(2); await click("新建 DIY 菜谱"); await hold(2)
	if not require(not game._recipe_dish.ingredients.is_empty(),"DIY starts from the actual served dish"): return
	stage("做法文字已经在纸上，也能按自己的习惯修改；配图仍由你来画")
	await click("改材料和步骤")
	var printed=game._recipe_canvas._recipe_sheet_layer.fields
	await type_text(printed[0],"番茄一颗\n鸡蛋一颗\n番茄酱：入锅、淋酱")
	var instructions=["番茄切片，\n横向再切成块。","番茄下锅，\n鸡蛋在锅沿敲开。","调火煎熟，\n关火加酱翻拌。","摆成喜欢的样子，\n再淋少量酱汁。"]
	for i in 4:
		printed[i+1].text=instructions[i]; printed[i+1].text_changed.emit()
	await hold(2)
	stage("先用细笔，在最上面手写菜名：这次叫它「番茄蛋」")
	await click("细笔"); await color(0)
	var records: Array=[]
	# Explicit pen paths for 番、茄、蛋. Every path goes through the drawing input.
	await letter([[[10,6],[54,1]],[[32,5],[32,30]],[[3,20],[64,20]],[[12,9],[22,17]],[[55,8],[44,17]],[[32,22],[8,36]],[[32,22],[59,35]],[[13,38],[13,68]],[[13,38],[54,38],[54,68],[13,68]],[[13,53],[54,53]],[[32,38],[32,68]]],Vector2(128,34))
	await letter([[[4,12],[69,12]],[[22,2],[22,22]],[[50,2],[50,22]],[[27,28],[24,44],[17,59],[5,71]],[[4,35],[30,35],[28,64],[23,68]],[[42,34],[42,65]],[[42,34],[65,34],[65,65]],[[42,65],[65,65]]],Vector2(232,34))
	await letter([[[7,5],[62,5],[53,16]],[[34,13],[34,28]],[[34,23],[15,33],[5,37]],[[34,23],[47,32],[65,36]],[[19,21],[14,20]],[[18,44],[58,44],[58,61],[18,61],[18,44]],[[38,39],[38,70]],[[9,72],[65,72]],[[53,65],[62,74]]],Vector2(336,34))
	pointer.hide(); await hold(1); checkpoint("02-handwritten-title")
	stage("做法文字会按这餐的成品状态整理；旁边的番茄和刀，由你来画")
	await color(0); await ellipse(Vector2(322,265),Vector2(29,24))
	await path([[308,263],[314,272],[330,276]]); await ellipse(Vector2(397,274),Vector2(23,18))
	await path([[376,274],[397,281],[418,274]])
	await color(2); await path([[314,238],[322,242],[332,236],[327,246],[336,245]])
	await color(1); await path([[434,239],[472,223],[479,232],[441,253],[434,239]])
	await path([[472,223],[494,212],[500,219],[479,232]])
	await hold(.7); pointer.hide()
	stage("换一支颜色，画出锅里的番茄和鸡蛋")
	await color(1); await ellipse(Vector2(378,384),Vector2(66,15))
	await path([[313,386],[326,412],[355,425],[402,423],[432,391]])
	await path([[441,381],[491,361],[498,368],[448,393]])
	await color(0)
	for p in [Vector2(348,378),Vector2(379,389),Vector2(408,381)]:
		await path([[p.x-8,p.y-4],[p.x+9,p.y-5],[p.x+7,p.y+7],[p.x-8,p.y+6],[p.x-8,p.y-4]])
	await color(3); await ellipse(Vector2(405,383),Vector2(11,7))
	await hold(.7); pointer.hide()
	stage("第三步画锅铲和热气，把翻炒的动作记下来")
	await color(1); await ellipse(Vector2(145,514),Vector2(65,15))
	await path([[81,515],[85,548],[97,558],[194,558],[206,541],[210,515]])
	await path([[81,520],[62,520],[59,533],[83,533]]); await path([[210,520],[230,520],[232,532],[210,532]])
	await color(1); await path([[108,480],[131,514],[141,512],[116,475],[108,480]])
	await color(0); await path([[156,506],[174,506],[175,520],[155,520],[156,506]])
	await color(3); await ellipse(Vector2(188,514),Vector2(9,6))
	await color(1)
	for x in [118,148,176]: await path([[x,493],[x-5,483],[x+3,475],[x-2,464]])
	await hold(.7); pointer.hide()
	stage("最后画一盘完成的料理：这是自己的图解，不是固定贴图")
	await color(1); await ellipse(Vector2(396,623),Vector2(74,14))
	await path([[322,624],[337,640],[365,649],[410,649],[442,639],[470,624]])
	await color(1); await ellipse(Vector2(397,621),Vector2(28,11))
	await color(3); await ellipse(Vector2(397,622),Vector2(12,7))
	await color(0); await path([[358,614],[367,609],[376,615],[367,620],[358,614]])
	await path([[415,629],[423,625],[434,630],[426,636],[415,629]])
	await color(2); await path([[444,614],[453,601],[460,610],[468,600]])
	pointer.hide(); await hold(1.4); checkpoint("03-completed-drawings")
	stage("画错了，橡皮擦只擦自己的笔画；预写文字会留下来")
	await color(1); await path([[476,656],[490,677]])
	await click("橡皮擦"); await path([[477,657],[490,677]],2,true)
	pointer.hide(); await hold(.7)
	stage("⑥ 收进菜谱：手写菜名和四幅配图会原样保存")
	var expected: Dictionary=game._recipe_canvas.export_data()
	if not require(preload("res://modules/restaurant/ui/recipe_sheet.gd").has_title(expected),"name consists of actual ink strokes"): return
	if not require(expected.stickers.is_empty(),"illustrations contain no prefab stickers, photos or font title layers"): return
	await click("收进我的菜谱"); await hold(1.2)
	records=game.repository.load_recipes()
	if not require(records.size()==1 and not records[0].dish.ingredients.is_empty(),"saved page contains the actual cooked dish"): return
	if not require(records[0].poster.recipe_sheet.materials=="番茄一颗\n鸡蛋一颗\n番茄酱：入锅、淋酱","edited printed materials survive saving"): return
	await click("手绘菜谱 1"); await hold(2); checkpoint("04-saved-reader")
	stage("⑦ 保存后还能继续画；重新打开，完整笔迹和做法都在")
	await click("继续 DIY"); await hold(.7)
	if not require(game._recipe_canvas.strokes.size()==expected.strokes.size(),"reopen restores every title and picture stroke"): return
	await color(0); await path([[113,105],[237,106],[451,104]],5)
	pointer.hide(); await hold(.8); await click("保存修改"); await hold(.8)
	records=game.repository.load_recipes()
	if not require(records.size()==1,"continuing the drawing updates the same page"): return
	await click("手绘菜谱 1"); await hold(1)
	stage("完成：上面是亲手写的菜名，下面是自己画的四步做法")
	await hold(3); checkpoint("05-final-page")
	chapter_label.text="07 / 菜谱与宣传"
	stage("材料和步骤也能修改；笔迹、文字和这一餐的记录都会一起保存")
	await click("继续 DIY"); await click("改材料和步骤"); await hold(3)
	await click("保存修改"); await click("手绘菜谱 1"); await hold(2)
	records=game.repository.load_recipes()
	stage("「分享这一页」可导出图文文件；朋友用浏览器就能看这份菜谱")
	await click("分享这一页"); await hold(2)
	for node in game.modal.get_children():
		if node is FileDialog:
			node.file_selected.emit(output.path_join("我的番茄蛋菜谱.html"))
			break
	await hold(2)
	stage("保存过实际料理的菜谱还能「跟做」；提示会随取材、切配、装盘推进")
	await click("照着做这道菜"); await hold(3)
	game._show_cookbook(); await click("番茄清汤面"); await hold(3)
	stage("厨房也有示范菜谱，想做汤面时可以先翻一翻")
	await hold(3); game._close_modal(); game.recipe_guide.active=false; game._update_recipe_guide()
	stage("再给小店做张海报：放上刚拍的照片，写下今天的主厨推荐")
	game._show_poster(); await hold(2)
	await click("纸上写字")
	var poster=game._poster_canvas
	poster.begin_text(Vector2(430,75)); await frames(2)
	await type_text(poster._text_editor,"今日推荐 · 番茄蛋"); poster.finish_text(); await frames(2)
	await click("加入料理照片"); await hold(2)
	game._poster_canvas.add_sticker("heart"); await hold(1)
	await click("贴出去 · 家常料理"); await hold(2)
	if not require(not game._poster_data.is_empty(),"actual photo poster saved and published in kitchen"): return
	checkpoint("08-poster")
	chapter_label.text="08 / 下一锅之前"
	await card("08  下一锅，先收拾厨房", "关火 · 擦净残留 · 冲洗抹布")
	stage("上一餐的残味会留在锅里；抹布打湿后，拖过空锅来清理")
	if not await clean_pan(): return
	checkpoint("09-cleaning")
	stage("海绵负责台面洒漏；想丢掉拿错的东西，也可以用右下角清理按钮")
	warp_pointer=false; await drag(game.world.sponge.position,Vector2(1010,740),40); warp_pointer=true; await hold(3)
	chapter_label.text="09 / 汤与锅盖"
	await card("09  还想试试煮汤？", "锅能搬到水槽接水，汤要盛进真正的汤碗")
	stage("按住锅柄把锅搬到水槽；向下转动水龙头把手，接好水就关上")
	if not await fill_pan(): return
	stage("盖上锅盖再加热，留意蒸汽；游戏里持续大火还可能把锅盖顶飞")
	if not await lid_and_bowl(): return
	chapter_label.text="10 / 收班"
	stage("忙完以后，在「暂停 / 帮助」里提前收班，查看今天的结算")
	game._show_pause(); await hold(2); await click("提前收班并结算"); await hold(5)
	checkpoint("11-receipt")
	if not require(game.session.phase=="closed" and game.session.served==1,"shift settles the one real meal"): return
	stage("从一颗番茄开始，把你的料理和故事，都留在这间小店")
	await card("下一道招牌菜，交给你了", "自由搭配 · 慢慢做饭 · 画下你的做法",5)
	stage("实机画面 · 自动操作录制 · 字幕与转场为视频编排")
	await hold(2)
	var file:=FileAccess.open(output.path_join("timeline.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps":FPS,"frames":frame,"duration":float(frame)/FPS,"timeline":timeline,"checks":checks,"recipe":records[0],"note":"Production scene and input paths; chapters pause simulation; pilot accelerates the first heat wait; final first dish is normal speed. The soup wait is explicitly shown at 4x. Original licensed gameplay audio."},"\t")); file.close()
	print("PASS: player tutorial, ",checks," checks, ",frame," frames, ",float(frame)/FPS," seconds")
	game.world.audio.muted=true
	if DisplayServer.get_name()!="headless": Input.warp_mouse(original_pointer)
	quit(0)

func cutting() -> bool:
	await frames(60)
	var tomato := _food("tomato")
	if not require(is_instance_valid(tomato), "tomato reaches the cutting board"): return false
	var tomato_center: Vector2 = tomato.position
	var knife_start: Vector2 = game.world._knife_handle_rect().get_center()
	_mouse(knife_start, "down")
	await frames(6)
	var drag_offset: Vector2 = game.world._knife_drag_offset
	var blade_offset := Vector2(-50, -22)
	var book_pointer: Vector2 = Vector2(1220, 600) - drag_offset
	for i in 16:
		_mouse(knife_start.lerp(book_pointer, (i + 1) / 16.0), "move")
		await frames(1)
	await frames(18)
	var floating: Node = game.world.get_node("FloatingTools")
	if not require(floating.copies.has(game.world._knife_visual.get_instance_id()), "held knife is visible over the cleared countertop"): return false
	var cut_start: Vector2 = tomato_center + Vector2(0, -55) - drag_offset - blade_offset
	for i in 12:
		_mouse(book_pointer.lerp(cut_start, (i + 1) / 12.0), "move")
		await frames(1)
	await frames(12)
	_mouse(tomato_center + Vector2(0, 55) - drag_offset - blade_offset, "move")
	await frames(6)
	_mouse(Vector2(1180, 690), "up")
	await frames(32)
	var pieces := _pieces("tomato")
	if not require(pieces.size() >= 2, "knife creates physical tomato pieces"): return false
	# Regrip and aim across the slice's actual settled orientation. The R key
	# makes the broad turn; wheel steps show the same fine aiming a player uses.
	stage("拿刀时按 R 转 90°，滚轮微调；横向再切一次，就能切成块")
	await hold(5)
	var target: RigidBody2D = pieces[0]
	var previous_axis: Vector2 = target.get_meta("cut_axis", Vector2.LEFT)
	var stroke_direction: Vector2 = -previous_axis.rotated(target.rotation).normalized()
	var cross_center: Vector2 = target.position
	_mouse(game.world._knife_handle_rect().get_center(), "down")
	await frames(5)
	_key(KEY_R)
	await frames(5)
	var desired_rotation := wrapf(stroke_direction.angle() - PI / 2.0, -PI, PI)
	var turn_steps := roundi(wrapf(desired_rotation - game.world._knife_visual.rotation, -PI, PI) / deg_to_rad(15.0))
	for index in absi(turn_steps):
		_wheel(MOUSE_BUTTON_WHEEL_DOWN if turn_steps > 0 else MOUSE_BUTTON_WHEEL_UP)
		await frames(2)
	var cross_offset: Vector2 = game.world.KNIFE_BLADE_MID.rotated(game.world._knife_visual.rotation)
	var cross_drag: Vector2 = game.world._knife_drag_offset
	_mouse(cross_center - stroke_direction * 64.0 - cross_drag - cross_offset, "move")
	await frames(8)
	_mouse(cross_center + stroke_direction * 64.0 - cross_drag - cross_offset, "move")
	await frames(8)
	_mouse(Vector2(1180, 690), "up")
	await frames(24)
	pieces = _pieces("tomato")
	if not require(pieces.size() >= 3 and pieces.any(func(item): return item.get_meta("cut_style", "") == "dice"), "player-driven crosscut makes diced tomato pieces"): return false
	stage("拖住同批的一片，就能把这一组切块一起送进锅口")
	await hold(4)
	var first: RigidBody2D = pieces[0]
	_mouse(first.position, "move")
	game.world._pickup(first)
	game.world.begin_food_drag(first.position)
	var from: Vector2 = first.position
	var to: Vector2 = game.world.pan.point(Vector2(805, 580))
	for i in 25:
		_mouse(from.lerp(to, (i + 1) / 25.0), "move")
		await frames(1)
	_mouse(to, "up")
	for i in 240:
		if not game.session.dish.is_empty(): break
		await frames(1)
	if not require(not game.session.dish.is_empty(), "tomato pieces enter the pan through physics"): return false
	stage("按住锅柄，向上轻甩；食材会跟着锅翻起来")
	await hold(3)
	# The pan carries the actual tomato pieces during an upward toss.
	var pan_handle: Vector2 = game.world.pan.point(Vector2(1037, 578))
	_mouse(pan_handle, "down")
	await frames(3)
	if not require(game.world.pan.active, "pan handle can be held for a real toss"): return false
	_mouse(pan_handle + Vector2(0, -42), "move")
	await frames(3)
	_mouse(pan_handle + Vector2(0, -42), "up")
	await frames(50)
	if not require(game.world.pan._last_toss_msec > 0, "physical food lifts and turns when the pan is tossed"): return false
	await hold(2)
	return true

func move_to(to: Vector2, steps:=24) -> void:
	var start:=previous_pointer
	for i in steps:
		_mouse(start.lerp(to,float(i+1)/steps),"move"); await frames(1)

func drag(from: Vector2,to: Vector2,steps:=30) -> void:
	_mouse(from,"down"); await frames(3); await move_to(to,steps); _mouse(to,"up"); await frames(3)

func fire(id: String) -> void:
	var control: Button=game._fire_buttons[id]
	pointer.show(); pointer.position=control.get_global_rect().get_center(); pointer.down=true; pointer.queue_redraw(); control.pressed.emit(); await hold(.3); pointer.down=false; pointer.queue_redraw()

func seasoning(id: String,seconds: float) -> bool:
	game.storage_display.reveal_ingredient(id)
	var slot: Button=game.storage_display.find_child("Ingredient_"+id,true,false)
	if not require(slot!=null,"seasoning available on physical rack"): return false
	slot.tooltip_text=""
	var origin:=slot.get_global_rect().get_center()
	_mouse(origin,"down"); await frames(2); _mouse(origin,"up"); await frames(6)
	if not require(is_instance_valid(game.world._held),"real bottle picked up"): return false
	await move_to(game.world.pan.point(Vector2(800,535)),28)
	_mouse(previous_pointer,"down"); await frames(2)
	if not require(game.world._squeezing,"bottle dispenses through real press"): return false
	await frames(roundi(seconds*FPS)); _mouse(previous_pointer,"up"); await frames(24)
	if not require(_dish_has(id),"real seasoning reaches pan"): return false
	await move_to(Vector2(1090,740),24)
	_mouse(previous_pointer,"down"); await frames(2); _mouse(previous_pointer,"up")
	if not require(not is_instance_valid(game.world._held),"bottle left on worktop for plate sauce"): return false
	await frames(6); return true

func stir() -> bool:
	warp_pointer=false
	var tool=game.world.utensils[1]
	_mouse(tool.home,"down"); await frames(4)
	if not require(tool.active,"wooden tool selected by input"): return false
	var start: Vector2=game.world.pan.point(Vector2(755,580))-tool._offset
	await move_to(start,24)
	for i in 2:
		await move_to(game.world.pan.point(Vector2(855,574))-tool._offset,24)
		await move_to(start,24)
	_mouse(previous_pointer,"up"); await frames(45); warp_pointer=true; return true

func arrange_plate() -> void:
	var canvas=game._plating_canvas
	var solids: Array=[]
	for value in canvas._visuals.values():
		if not value.body.has_meta("liquid_state"): solids.append(value)
	for i in mini(solids.size(),4):
		var value: Dictionary=solids[i]
		var from: Vector2=canvas.get_global_transform_with_canvas()*value.art.position
		var uv: Vector2=[Vector2(-.33,-.15),Vector2(.28,-.15),Vector2(-.22,.28),Vector2(.3,.24)][i]
		var to: Vector2=canvas.get_global_transform_with_canvas()*(canvas.center()+uv*canvas.radius())
		await drag(from,to,24)
	await click("顺时针")

func plate_sauce() -> void:
	var canvas=game._plating_canvas
	var local: Vector2=canvas.center()+Vector2(-.6,.45)*canvas.radius()
	_mouse(canvas.get_global_transform_with_canvas()*local,"down"); await frames(8)
	for i in 45:
		var uv:=Vector2(-.6+float(i)/45*1.15,.48+sin(float(i)/45*PI)*.1)
		_mouse(canvas.get_global_transform_with_canvas()*(canvas.center()+uv*canvas.radius()),"move"); await frames(1)
	_mouse(previous_pointer,"up"); await frames(6)
	require(not game.session.presentation.get("strokes",[]).is_empty(),"finite bottle sauce placed on real plate")

func find_edit(parent: Node,type: String) -> Control:
	for node in parent.get_children():
		if node.get_class()==type: return node
		var found:=find_edit(node,type)
		if found!=null: return found
	return null

func type_text(edit: Control,words: String) -> void:
	if edit==null: require(false,"text field present"); return
	edit.grab_focus(); edit.text=""
	if edit is TextEdit: edit.text_changed.emit()
	elif edit is LineEdit: edit.text_changed.emit(edit.text)
	for letter_text in words:
		edit.text+=letter_text
		if edit is TextEdit: edit.text_changed.emit()
		elif edit is LineEdit: edit.text_changed.emit(edit.text)
		await frames(2)
	edit.release_focus(); pointer.hide()

func tap(open: bool) -> void:
	await drag(Vector2(190,570) if open else Vector2(190,632),Vector2(190,680) if open else Vector2(190,570),18)
	# The broad rectangular handle accepts either starting height.
	if game.world.pan.faucet_on!=open:
		await drag(Vector2(190,618),Vector2(190,680) if open else Vector2(190,550),18)
	require(game.world.pan.faucet_on==open,"faucet handle reaches requested position")

func clean_pan() -> bool:
	await fire("off"); await tap(true); warp_pointer=false
	_mouse(game.world.cloth.HOME,"down"); await frames(3); await move_to(Vector2(215,687),32); await frames(28)
	if not require(game.world.cloth.wetness>.25,"cloth wetted in running water"): return false
	_mouse(previous_pointer,"up"); await frames(5); await tap(false)
	_mouse(game.world.cloth.HOME,"down"); await frames(3)
	var before: float=game.world.pan.residue.total_kg()
	await move_to(game.world.pan.point(Vector2(735,576)),36)
	for i in 3:
		await move_to(game.world.pan.point(Vector2(875,576)),30)
		await move_to(game.world.pan.point(Vector2(735,576)),30)
	_mouse(previous_pointer,"up"); await frames(5); await tap(true)
	_mouse(game.world.cloth.HOME,"down"); await frames(3)
	await move_to(Vector2(215,687),34); await frames(30); _mouse(previous_pointer,"up"); await frames(5)
	await tap(false); warp_pointer=true; await hold(2)
	return require(game.world.pan.residue.total_kg()<before or before<.000001,"real strokes remove finite pan residue")

func fill_pan() -> bool:
	warp_pointer=false
	var from: Vector2=game.world.pan.point(Vector2(1037,578))
	await drag(from,from+Vector2(-587,0),42); await hold(2)
	if not game.world.pan.under_tap():
		var correction: Vector2=Vector2(-612,game.world.pan.HOME.y)-game.world.pan.offset
		var handle: Vector2=game.world.pan.point(Vector2(1037,578))
		await drag(handle,handle+correction,30); await frames(8)
	if not require(game.world.pan.under_tap(),"pan carried under tap"): return false
	await tap(true); await frames(52); await tap(false); warp_pointer=true; await hold(2)
	if not require(game.world.pan.water_ml>250,"finite water supplied by faucet"): return false
	var now: Vector2=game.world.pan.point(Vector2(1037,578))
	await drag(now,now+Vector2(587,0),42); await hold(2)
	warp_pointer=true
	return require(game.world.pan.on_stove(),"water-filled pan returned to stove")

func lid_and_bowl() -> bool:
	if not await _drag_slot("noodles",game.world.pan.point(Vector2(800,550)),30): return false
	await hold(1)
	await drag(game.world.lid.HOME,game.world.pan.point(Vector2(810,582)),35)
	if not require(game.world.lid.covered,"real lid seats on pan"): return false
	await fire("high")
	stage("煮汤等待 · 4 倍速：水会受热，面条逐渐吸水变软")
	Engine.time_scale=4
	var waits:=0
	while (game.world.pan.water_heat<96 or game.world.lid.steam_ml<.7) and waits<1200:
		await frames(1); waits+=1
	Engine.time_scale=1
	if not require(game.world.pan.water_heat>=96 and game.world.lid.steam_ml>=.7,"real heat produces boiling water and visible lid steam"): return false
	await hold(2); checkpoint("10-lid-steam")
	stage("汤烧开以后，拖开锅盖放出蒸汽，再把火关掉")
	await drag(game.world.lid.position,game.world.lid.HOME,36); await fire("off"); await hold(2)
	game._interact("plate"); await hold(1); await click("全部装盘"); await click("汤碗")
	stage("做汤时选「汤碗」；从锅里盛汤，碗里的汤就是锅里减少的那部分")
	var before: float=game.world.pan.water_ml
	await click("从锅盛汤"); await click("从锅盛汤"); await hold(4)
	if not require(game.session.presentation.get("broth_ml",0)>0 and game.world.pan.water_ml<before,"real broth moved into bowl"): return false
	checkpoint("10-soup-bowl")
	game._close_modal(); return true

func _drag_slot(id: String, destination: Vector2, steps: int) -> bool:
	game.storage_display.reveal_ingredient(id)
	var slot := game.storage_display.find_child("Ingredient_" + id, true, false) as Button
	if slot!=null: slot.tooltip_text=""
	if not require(slot != null, id + " has a visible storage slot"): return false
	var origin: Vector2 = slot.get_global_rect().get_center()
	_mouse(origin, "down")
	await frames(3)
	if not require(is_instance_valid(game.world._held), id + " is picked up"): return false
	for i in steps:
		_mouse(origin.lerp(destination, (i + 1) / float(steps)), "move")
		await frames(1)
	_mouse(destination, "up")
	await frames(4)
	return require(not is_instance_valid(game.world._held), id + " is put down")

func _crack_egg_from_shelf() -> bool:
	game.storage_display.reveal_ingredient("egg")
	var slot := game.storage_display.find_child("Ingredient_egg", true, false) as Button
	if not require(slot != null, "egg has a visible storage slot"): return false
	var origin: Vector2 = slot.get_global_rect().get_center()
	var rim: Vector2 = game.world.pan.point(Vector2(809, 546))
	_mouse(origin, "down")
	await frames(3)
	if not require(is_instance_valid(game.world._held), "whole egg is picked up"): return false
	for i in 28:
		_mouse(origin.lerp(rim, (i + 1) / 28.0), "move")
		await frames(1)
	_mouse(rim, "up")
	await frames(28)
	if not require(is_instance_valid(game.world._held) and int(game.world._held.get_meta("egg_taps", 0)) == 1, "first rim strike cracks the held shell"): return false
	_mouse(rim, "down")
	await frames(4)
	_mouse(rim, "up")
	await frames(34)
	return require(game.world._egg_shells.get_child_count() == 2 and not is_instance_valid(game.world._held), "second strike pours egg and launches two shell pieces")

func _food(id: String) -> RigidBody2D:
	for body in game.world._foods.get_children():
		if not body.is_queued_for_deletion() and body.get_meta("id", "") == id: return body
	return null

func _pieces(id: String) -> Array:
	var result: Array = []
	for body in game.world._foods.get_children():
		if not body.is_queued_for_deletion() and body.get_meta("id", "") == id and int(body.get_meta("cut_depth", 0)) > 0: result.append(body)
	return result

func _dish_has(id: String) -> bool:
	for item in game.session.dish:
		if str(item.get("id", "")) == id: return true
	return false

func _mouse(point: Vector2, kind: String) -> void:
	pointer.show(); pointer.position=point
	if kind != "move": held_mouse=kind=="down"; pointer.down=held_mouse; pointer.queue_redraw()
	var window_point: Vector2 = root.get_final_transform() * point
	if warp_pointer and DisplayServer.get_name() != "headless": Input.warp_mouse(window_point)
	if kind == "move":
		var motion := InputEventMouseMotion.new()
		motion.position = window_point
		motion.global_position = window_point
		motion.relative = window_point - root.get_final_transform() * previous_pointer
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT if held_mouse else 0
		Input.parse_input_event(motion)
	else:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if kind == "down" else 0
		button.pressed = kind == "down"
		button.position = window_point
		button.global_position = window_point
		Input.parse_input_event(button)
	previous_pointer = point

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)

func _wheel(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = root.get_final_transform() * previous_pointer
	event.global_position = event.position
	Input.parse_input_event(event)
