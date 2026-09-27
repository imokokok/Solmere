extends SceneTree
## Automated pointer gestures in the production game, not raster/vector font glyphs.
const FPS := 15
var game
var caption: Label
var pointer: DemoPointer
var frame := 0
var timeline: Array = []
var folder := ""
var output := ""

class DemoPointer extends Control:
	var down := false
	func _draw() -> void:
		if down: draw_circle(Vector2(4,5),14,Color("ead3a0",.35))
		var arrow := PackedVector2Array([Vector2.ZERO,Vector2(2,23),Vector2(9,16),Vector2(15,21),Vector2(19,17),Vector2(13,11),Vector2(22,8)])
		draw_colored_polygon(arrow,Color("fff8e8")); arrow.append(Vector2.ZERO)
		draw_polyline(arrow,Color("314d43"),1.5,true)

func _initialize() -> void:
	root.size=Vector2i(1600,1008); root.content_scale_size=Vector2i(1600,1008)
	call_deferred("run")

func hold(seconds: float) -> void:
	for i in maxi(1,roundi(seconds*FPS)):
		await process_frame; RenderingServer.force_draw(false)
		var error := root.get_texture().get_image().save_jpg(folder.path_join("frame_%05d.jpg" % frame),0.94)
		if error!=OK: push_error("Cannot save frame"); quit(2); return
		frame+=1

func stage(words: String) -> void:
	caption.text=words; timeline.append({"seconds":float(frame)/FPS,"caption":words})
	print("RECIPE_DRAW_STAGE ",frame," ",words)

func require(ok: bool, words: String) -> bool:
	if not ok: push_error(words); quit(3)
	else: print("DRAW_CHECK ",words)
	return ok

func find_button(words: String, parent: Node = null) -> Button:
	if parent==null: parent=game.modal_body
	for child in parent.get_children():
		if child is Button and child.is_visible_in_tree() and not child.is_queued_for_deletion() and child.text.begins_with(words): return child
		var found := find_button(words,child)
		if found!=null: return found
	return null

func click(words: String) -> void:
	var control := find_button(words)
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
		if i%rate==0: await hold(1.0/FPS)
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
	var layer := CanvasLayer.new(); layer.layer=120; root.add_child(layer)
	var bar := ColorRect.new(); bar.position=Vector2(0,946); bar.size=Vector2(1600,62); bar.color=Color("193e37")
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(bar)
	caption=Label.new(); caption.position=Vector2(22,958); caption.size=Vector2(1240,38)
	caption.add_theme_font_override("font",preload("res://modules/restaurant/ui/paper_ink.gd").font()); caption.add_theme_font_size_override("font_size",25)
	caption.add_theme_color_override("font_color",Color("fff4d9")); caption.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(caption)
	var label := Label.new(); label.text="游戏内自动操作演示"; label.position=Vector2(1270,969)
	label.add_theme_font_override("font",preload("res://modules/restaurant/ui/paper_ink.gd").font()); label.add_theme_font_size_override("font_size",18)
	label.add_theme_color_override("font_color",Color("b6cbb9")); layer.add_child(label)
	pointer=DemoPointer.new(); pointer.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(pointer); pointer.hide()

func checkpoint(name: String) -> void:
	root.get_texture().get_image().save_png(output.path_join(name+".png"))

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=2 or DisplayServer.get_name()=="headless": quit(1); return
	folder=args[0]; output=args[1]
	DirAccess.make_dir_recursive_absolute(folder); DirAccess.make_dir_recursive_absolute(output)
	game=preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://drawing_video_"+Crypto.new().generate_random_bytes(16).hex_encode()+"/book.json","display_name":"小满"})
	root.add_child(game); await process_frame; game._start_shift(); game.world.audio.muted=true; setup_overlay()
	stage("图解菜谱 DIY：做法已经在纸上，菜名和配图由你用笔画")
	await hold(2.2); game._show_cookbook(); await hold(1)
	await click("新建 DIY 菜谱"); await hold(1.5)
	if not require(game._recipe_canvas.strokes.is_empty() and game._recipe_canvas.stickers.is_empty(),"page starts without pre-drawn names or pictures"): return
	checkpoint("01-printed-instructions")
	stage("① 用涂鸦笔在最上面手写菜名：给这一页取名「番茄面」")
	await click("细笔"); await color(0)
	# Explicit pen paths for 番、茄、面. Every path goes through the drawing input.
	await letter([[[10,6],[54,1]],[[32,5],[32,30]],[[3,20],[64,20]],[[12,9],[22,17]],[[55,8],[44,17]],[[32,22],[8,36]],[[32,22],[59,35]],[[13,38],[13,68]],[[13,38],[54,38],[54,68],[13,68]],[[13,53],[54,53]],[[32,38],[32,68]]],Vector2(128,34))
	await letter([[[4,12],[69,12]],[[22,2],[22,22]],[[50,2],[50,22]],[[27,28],[24,44],[17,59],[5,71]],[[4,35],[30,35],[28,64],[23,68]],[[42,34],[42,65]],[[42,34],[65,34],[65,65]],[[42,65],[65,65]]],Vector2(232,34))
	await letter([[[5,5],[68,5]],[[33,5],[28,18]],[[8,19],[8,69]],[[8,19],[65,19],[65,69]],[[25,20],[25,65]],[[48,20],[48,65]],[[25,37],[48,37]],[[25,52],[48,52]],[[8,69],[65,69]]],Vector2(336,34))
	pointer.hide(); await hold(1); checkpoint("02-handwritten-title")
	stage("② 第一步：旁边的做法已经写好，自己画番茄、刀和切块")
	await color(0); await ellipse(Vector2(322,265),Vector2(29,24))
	await path([[308,263],[314,272],[330,276]]); await ellipse(Vector2(397,274),Vector2(23,18))
	await path([[376,274],[397,281],[418,274]])
	await color(2); await path([[314,238],[322,242],[332,236],[327,246],[336,245]])
	await color(1); await path([[434,239],[472,223],[479,232],[441,253],[434,239]])
	await path([[472,223],[494,212],[500,219],[479,232]])
	await hold(.7); pointer.hide()
	stage("③ 第二步：画一口锅，把番茄小块画进锅里")
	await color(1); await ellipse(Vector2(378,384),Vector2(66,15))
	await path([[313,386],[326,412],[355,425],[402,423],[432,391]])
	await path([[441,381],[491,361],[498,368],[448,393]])
	await color(0)
	for p in [Vector2(348,378),Vector2(379,389),Vector2(408,381)]:
		await path([[p.x-8,p.y-4],[p.x+9,p.y-5],[p.x+7,p.y+7],[p.x-8,p.y+6],[p.x-8,p.y-4]])
	await hold(.7); pointer.hide()
	stage("④ 第三步：给煮面这一步画锅、水、面条和热气")
	await color(1); await ellipse(Vector2(145,514),Vector2(65,15))
	await path([[81,515],[85,548],[97,558],[194,558],[206,541],[210,515]])
	await path([[81,520],[62,520],[59,533],[83,533]]); await path([[210,520],[230,520],[232,532],[210,532]])
	await color(4); await path([[97,520],[124,525],[153,520],[181,523]])
	await color(3)
	for y in [505,511,517]: await path([[107,y],[123,y-3],[138,y+2],[158,y-2],[181,y+2]])
	await color(1)
	for x in [118,148,176]: await path([[x,493],[x-5,483],[x+3,475],[x-2,464]])
	await hold(.7); pointer.hide()
	stage("⑤ 第四步：画一碗做好的面，把这份做法补成完整图解")
	await color(1); await ellipse(Vector2(396,623),Vector2(74,14))
	await path([[322,624],[337,651],[356,674],[380,684],[407,684],[437,668],[458,646],[470,624]])
	await path([[379,685],[375,692],[413,692],[408,685]])
	await color(3)
	for y in [617,622,627]: await path([[346,y],[359,y-3],[375,y+2],[391,y-3],[408,y+2],[425,y-2],[443,y+1]])
	await color(0); await path([[358,614],[367,609],[376,615],[367,620],[358,614]])
	await path([[415,629],[423,625],[434,630],[426,636],[415,629]])
	await color(1); await path([[442,609],[470,580]]); await path([[449,611],[480,580]])
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
	var records: Array=game.repository.load_recipes()
	if not require(records.size()==1 and records[0].dish.ingredients.is_empty(),"one paper-only recipe saved without invented cooked food"): return
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
	await hold(4.5); checkpoint("05-final-page")
	var file := FileAccess.open(output.path_join("timeline.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps":FPS,"frames":frame,"duration":float(frame)/FPS,"timeline":timeline,"recipe":records[0]},"\t")); file.close()
	print("PASS: recipe drawing video, ",frame," frames, ",float(frame)/FPS," seconds")
	quit(0)
