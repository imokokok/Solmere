extends SceneTree
var game
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	root.size=Vector2i(1600,946)
	Engine.max_fps=120
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func run() -> void:
	game=preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://comfort_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode(),"shift_seconds":600})
	root.add_child(game)
	await process_frame
	game._start_shift()
	game.world.audio.muted=true
	var s=game.session
	expect(s.customer_wait==120,"waiting budget is exactly 120 seconds")
	expect(game.hint_label.position.y>=900 and game.toast_label.position.y>=900,"instructions are outside the room canvas")
	for score in [0,19,20,80,81,100]:
		var bill: Dictionary=s.payment_for_score(score,{"base_payment":50,"tip_min":0.1,"tip_max":0.3})
		expect(bill.payment<0 if score<20 else bill.payment>=0,"signed fee boundary %d"%score)
		expect(bill.tip>0 if score>80 else bill.tip==0,"tip boundary %d"%score)
		expect(is_equal_approx(bill.payment,bill.meal_fee+bill.tip-bill.compensation),"bill balances %d"%score)
	var snap={"ingredients":[{"id":"bread","heat":18,"cut":false}],"quality":0.18,"weirdness":0.0,"tags":["grain","comfort"],"raw_count":0,"cut_count":0,"burnt":true}
	var regular: Dictionary=s._evaluate(snap,s.customers[0])
	var charred: Dictionary=s._evaluate(snap,s.customers[1])
	expect(charred.score>regular.score+30,"char lover meaningfully prefers browned food")
	expect(charred.feedback!=regular.feedback,"individual reviews reflect different preferences")
	var tips: Dictionary={}
	for i in range(24): tips[s.payment_for_score(95,{"base_payment":50,"tip_min":0.1,"tip_max":0.3}).tip]=true
	expect(tips.size()>1,"excellent service receives varying tips")
	var w=game.world
	expect(game.storage_display.find_child("MysteryStock", true, false) == null, "removed mystery box has no visible hotspot")
	var odd_slot = game.storage_display.find_child("Ingredient_sock", true, false)
	expect(odd_slot != null, "strange items remain available on their physical shelf")
	game._take_ingredient(game._definition("sock"))
	expect(is_instance_valid(w._held) and w._held.get_meta("id", "") == "sock", "the shelf still supplies the finite physical strange item")
	w.discard_held()
	await process_frame
	# A real drag from the visible stock to the board, then a real knife gesture.
	var tomato_button=game.hud.find_child("Ingredient_tomato",true,false)
	expect(tomato_button!=null,"tomato stock is an actual visible interactive sprite")
	var source: Vector2=tomato_button.get_global_rect().get_center()
	motion(source)
	await process_frame
	mouse(source,true)
	await process_frame
	motion(Vector2(1200,735))
	await create_timer(1.2).timeout
	mouse(Vector2(1200,735),false)
	await physics_frame
	await process_frame
	expect(not w._dragging,"mouse release ends active pointer tracking")
	# A queued release may arrive before the force-driven hand reaches the board.
	# Wait for its bounded completion, then verify the actual support and knife flow.
	await create_timer(1.8).timeout
	expect(w._held==null,"food drag releases")
	expect(w._foods.get_child_count()==1,"one stock drag creates one body")
	if w._foods.get_child_count() == 0:
		print("Storage diagnostic: disabled=%s stock=%s held=%s source=%s modal=%s controls=%s" % [tomato_button.disabled, game._stock.get("tomato", true), w._held, source, game.modal.visible, w.controls_enabled])
		for f in failures: push_error(f)
		quit(1)
		return
	var food: RigidBody2D=w._foods.get_child(0)
	expect(not food.get_meta("cut") and food.get_meta("on_board",false),"food is intact and stable on board")
	expect(not game.modal.visible,"board has no enlarged modal")
	var mass:=food.mass
	var food_pos:=food.position
	var grip: Vector2=w._knife_handle_rect().get_center()
	mouse(grip,true)
	await process_frame
	expect(w._knife_held,"actual handle picks up knife")
	# Put the blade above the ingredient without crossing it, then slice down.
	var offset: Vector2=w._knife_drag_offset+Vector2(-50,-22)
	motion(food_pos+Vector2(0,-70)-offset)
	await process_frame
	motion(food_pos+Vector2(0,60)-offset)
	await process_frame
	mouse(food_pos+Vector2(0,60)-offset,false)
	await process_frame
	expect(not w._knife_held,"knife release ends tracking")
	var pieces: Array=[]
	var total:=0.0
	for body in w._foods.get_children():
		if body.is_queued_for_deletion(): continue
		pieces.append(body)
		total+=body.mass
	expect(pieces.size()>=2,"pointer knife gesture splits actual bodies")
	expect(absf(total-mass)<0.0001,"cut conserves mass")
	for body in pieces: expect(body.freeze and body.get_meta("cut"),"cut pieces remain stable until moved")
	var first: RigidBody2D=pieces[0]
	mouse(first.position,true)
	await process_frame
	motion(w.pan.point(Vector2(810,520)))
	await create_timer(1.0).timeout
	mouse(w.pan.point(Vector2(810,520)),false)
	await create_timer(1.0).timeout
	expect(s.dish.size()==pieces.size(),"one drag moves the complete freshly cut portion")
	expect(first.position.distance_to(w.pan.point(Vector2(810,579)))<100,"food stays near the cooking surface")
	var pan=w.pan
	var pan_grip: Vector2=pan.point(Vector2(1000,566))
	mouse(pan_grip,true)
	await process_frame
	motion(pan_grip+Vector2(-80,-170))
	await create_timer(1.0).timeout
	expect(pan.active and pan.is_carrying(first),"pan carries enrolled body")
	expect(pan.point(Vector2(1000,566)).distance_to(pan_grip+Vector2(-80,-170))<8,"scaled pan grip approaches the pointer through bounded forces")
	mouse(pan_grip+Vector2(-80,-170),false)
	await create_timer(1.3).timeout
	expect(not pan.active and not pan.falling,"pan release settles")
	pan.move_to(pan.HOME)
	# Plate drag and click are different actual gestures.
	var old_center: Vector2=w.plate.center
	mouse(old_center,true)
	motion(old_center+Vector2(-75,30))
	mouse(old_center+Vector2(-75,30),false)
	await process_frame
	expect(w.plate.center.distance_to(old_center)>60 and not game.modal.visible,"dragging moves plate without opening modal")
	mouse(w.plate.center,true)
	mouse(w.plate.center,false)
	await process_frame
	expect(game.modal.visible and game._modal_kind=="plating","single click opens plating")
	game._close_modal()
	for tool in w.utensils:
		mouse(tool.to_global(Vector2(-24,0)),true)
		await process_frame
		expect(tool.active,"visible utensil can be picked up: "+tool.title)
		motion(Vector2(700,400))
		await create_timer(0.65).timeout
		mouse(Vector2(1510,35),false)
		await process_frame
		expect(not tool.active,"utensil release over HUD ends drag: "+tool.title)
		await create_timer(2.0).timeout
		expect(not tool.storing, "smooth storage completes before the next pickup: " + tool.title)
	# The sink drawing has matching physical support; dropped food stays in-basin.
	w.spawn_ingredient(s._catalog["potato"])
	var sink_food: RigidBody2D = w._held
	sink_food.position = Vector2(170, 570)
	w.drop_held(false)
	await create_timer(1.2).timeout
	expect(sink_food.position.x > 40 and sink_food.position.x < 350 and sink_food.position.y > 660 and sink_food.position.y < 744,"food dropped into sink rests inside the reference image basin")
	w._pickup(sink_food)
	w.discard_held()
	# Multiple calm drops cannot inject a throwing impulse or escape the table.
	for id in ["potato","onion","carrot","egg","broccoli"]:
		w.spawn_ingredient(s._catalog[id])
		w._held.position=Vector2(600,680)
		w.drop_held(false)
		await create_timer(0.15).timeout
	await create_timer(3).timeout
	for body in w._foods.get_children():
		expect(body.position.is_finite() and body.position.x>=0 and body.position.x<=1600 and body.position.y<810,"body remains within worktop bounds")
		expect(body.linear_velocity.length()<40,"resting food settles without flying")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../100饭店_实机验证.png")
	game.queue_free()
	await process_frame
	for f in failures: push_error(f)
	print("%s comfort release: %d checks"%["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
func mouse(p: Vector2,down: bool) -> void:
	var e:=InputEventMouseButton.new()
	e.position=root.get_final_transform()*p
	e.global_position=e.position
	e.button_index=MOUSE_BUTTON_LEFT
	e.pressed=down
	e.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e)
func motion(p: Vector2) -> void:
	var e:=InputEventMouseMotion.new()
	e.position=root.get_final_transform()*p
	e.global_position=e.position
	e.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
