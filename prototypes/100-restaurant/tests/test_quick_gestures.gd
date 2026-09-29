extends SceneTree
## Real input at the shipped small-window size, including queued quick releases.
var game
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	root.size = Vector2i(960, 568)
	Engine.max_fps = 120
	call_deferred("run")
func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://quick_%s/book.json" % Time.get_ticks_usec(),"shift_seconds":600})
	root.add_child(game)
	await process_frame
	game._start_shift()
	var w = game.world
	w.audio.muted = true
	for tool in w.utensils:
		mouse(tool.to_global(Vector2(-24,0)), "down")
		await process_frame
		expect(tool.active, tool.kind + " exposed head is selectable at 960 pixels")
		mouse(Vector2(680,440), "move")
		mouse(Vector2(680,440), "up")
		await process_frame
		expect(tool.releasing, tool.kind + " fast release is still completing its physical movement")
		var regrip_angle: float = tool.rigid.rotation
		mouse(tool.to_global(Vector2(-24,0)), "down")
		await process_frame
		expect(tool.active and not tool.releasing, tool.kind + " can be regripped immediately during release")
		expect(absf(wrapf(tool.grip.target_angle-regrip_angle,-PI,PI))<0.1,tool.kind + " regrip retains the current wrist pose")
		mouse(Vector2(680,440), "move")
		mouse(Vector2(680,440), "up")
		await create_timer(1.9).timeout
		expect(not tool.active and not tool.releasing and not tool.docked, tool.kind + " quick pull remains outside the cup")
		expect(tool.position.is_finite() and Rect2(40,80,1500,720).has_point(tool.position), tool.kind + " released tool remains reachable")
		mouse(tool.to_global(Vector2(-24,0)), "down")
		await process_frame
		expect(tool.active, tool.kind + " can be picked up again after settling")
		mouse(tool.CUP_MOUTH.get_center(), "move")
		mouse(tool.CUP_MOUTH.get_center(), "up")
		await create_timer(3.0).timeout
		expect(tool.docked and not tool.storing, tool.kind + " quick near-cup return completes smoothly")
		# Native-window discovery: an angled tool laid on the far rim used to
		# pull the whole skillet across the counter when returned to the cup.
		var pan_start: Vector2 = w.pan.rigid.position
		mouse(tool.to_global(Vector2(-24,0)),"down")
		mouse(w.pan.point(Vector2(948,532)),"move")
		mouse(w.pan.point(Vector2(948,532)),"up")
		await create_timer(1.8).timeout
		mouse(tool.to_global(Vector2(-24,0)),"down")
		await process_frame
		expect(tool.active,tool.kind + " remains selectable beside the rim")
		mouse(tool.CUP_MOUTH.get_center(),"move")
		mouse(tool.CUP_MOUTH.get_center(),"up")
		await create_timer(3.0).timeout
		expect(tool.docked,tool.kind + " lifts clear before returning to the cup")
		expect(w.pan.rigid.position.distance_to(pan_start)<8,tool.kind + " return does not drag the skillet off its burner")
	# Quick rack-to-pan release must not strand a lagging lid on the handle.
	mouse(w.lid.position,"down")
	await process_frame
	expect(w.lid.active,"rack lid responds to the real pointer")
	mouse(w.pan.point(Vector2(810,552)),"move")
	mouse(w.pan.point(Vector2(810,552)),"up")
	await create_timer(3.5).timeout
	expect(w.lid.covered and not w.lid.active and not w.lid.seating,"quick near-pan release completes physical lid seating")
	expect(w.pan.on_stove(),"putting the lid on does not shove the skillet off the burner")
	mouse(w.lid.position,"down")
	await process_frame
	mouse(w.lid.HOME,"move")
	mouse(w.lid.HOME,"up")
	await create_timer(3.5).timeout
	expect(w.lid.parked and not w.lid.returning,"quick pan-to-rack release returns the lid to its support")
	mouse(w.lid.position,"down")
	await process_frame
	expect(w.lid.active,"the returned lid remains selectable")
	mouse(Vector2(1400,240),"move")
	mouse(Vector2(1400,240),"up")
	await create_timer(1.2).timeout
	expect(Rect2(160,150,1280,650).has_point(w.lid.position),"a fast loose lid release stays reachable on screen")
	w.lid.rest_lid()
	# Pause during a single shelf-to-pan egg gesture, then resume the same mass.
	var slot: Button = game.storage_display.find_child("Ingredient_egg",true,false)
	mouse(slot.get_global_rect().get_center(),"down")
	await process_frame
	var egg: RigidBody2D = w._held
	expect(is_instance_valid(egg), "shelf press obtains the egg")
	if is_instance_valid(egg):
		var mass := egg.mass
		var target: Vector2 = w.pan.point(Vector2(809,546))
		mouse(target,"move")
		mouse(target,"up")
		await create_timer(0.8).timeout
		w.set_controls_enabled(false)
		await create_timer(1.0).timeout
		w.set_controls_enabled(true)
		await create_timer(1.0).timeout
		expect(egg.get_meta("thermal",{}).get("egg_opened",false), "one actual drag opens the egg, including pause/resume")
		expect(w._held == null and not egg.freeze and egg.get_meta("enrolled",false), "resumed egg becomes a live pan body")
		expect(w._egg_shells.get_child_count()==2, "one gesture creates only two shell halves")
		var total := egg.mass
		for shell in w._egg_shells.get_children(): total += shell.mass
		expect(absf(total-mass)<0.00001, "pause cannot duplicate or delete egg mass")
	w.clear_workspace()
	await process_frame
	expect(w.lid.parked and w.lid.position.distance_to(w.lid.HOME)<1.0,"parked lid remains on its rack after pause/resume")
	w.spawn_ingredient(game._definition("potato"))
	var whole: RigidBody2D = w._held
	whole.position=w._knife_visual.global_position+w.KNIFE_BLADE_MID+Vector2(0,45)
	w.drop_held(false)
	whole.stop_board_settle()
	await process_frame
	var handle: Vector2=w._knife_handle_rect().get_center()
	mouse(handle,"down")
	await process_frame
	expect(w._knife_held,"small-window knife handle actually picks the knife")
	# No final motion event: an OS-coalesced drag delivers its end on release.
	mouse(handle+Vector2(0,105),"up")
	await process_frame
	expect(w._foods.get_child_count()==2,"release position completes the missing final knife stroke")
	var pieces: Array=w._foods.get_children()
	w.spawn_ingredient(game._definition("tomato"))
	w._held.position=Vector2(1340,735)
	w.drop_held(false)
	var shift:=InputEventKey.new()
	shift.keycode=KEY_SHIFT
	shift.physical_keycode=KEY_SHIFT
	shift.pressed=true
	Input.parse_input_event(shift)
	mouse(pieces[0].position,"down")
	await process_frame
	expect(w._drag_group.is_empty(),"Shift selects only one slice")
	mouse(pieces[0].position,"up")
	shift.pressed=false
	Input.parse_input_event(shift)
	await create_timer(0.4).timeout
	mouse(pieces[0].position,"down")
	await process_frame
	expect(w._drag_group.size()==1,"ordinary pickup includes sibling, excludes unrelated tomato")
	var carried_mass: float = pieces[0].mass + pieces[1].mass
	mouse(Vector2(680,400),"move")
	mouse(Vector2(680,400),"up")
	await process_frame
	expect(w._pending_drop,"fast batch release retains its physical destination")
	mouse(pieces[0].position,"down")
	await process_frame
	expect(w._dragging and not w._pending_drop,"touching the moving portion resumes control immediately")
	expect(w._drag_group.size()==1 and absf(pieces[0].mass+pieces[1].mass-carried_mass)<0.000001,"regripping keeps the sibling and its original mass")
	w.discard_held()
	await process_frame
	expect(w._drag_group.is_empty() and not w.held_grip.enabled and w._foods.get_child_count()==1,"discarding a held portion frees every carried body and grip")
	w.clear_workspace()
	expect(w._drag_group.is_empty() and not w._dragging,"cleanup leaves no orphaned batch drag")
	# A bottle remains in the hand after seasoning. A fast click back on its
	# empty slot must retain that destination while the physical bottle catches up.
	var salt_slot: Button = game.storage_display.find_child("Ingredient_salt",true,false)
	mouse(salt_slot.get_global_rect().get_center(),"down")
	mouse(salt_slot.get_global_rect().get_center(),"up")
	await process_frame
	var bottle: RigidBody2D = w._held
	expect(is_instance_valid(bottle),"left counter salt can be picked up through its visible slot")
	if is_instance_valid(bottle):
		var uid: String = bottle.get_meta("instance_uid")
		var amount: float = bottle.get_meta("remaining_ml")
		bottle.position = w.pan.point(Vector2(810,430))
		w.held_grip.target = bottle.global_position
		await process_frame
		w._focus = "trash" # Previous hover must not override this click's target.
		mouse(salt_slot.get_global_rect().get_center(),"down")
		mouse(salt_slot.get_global_rect().get_center(),"up")
		await create_timer(2.6).timeout
		expect(w._held==null and bool(game._stock.get("salt",false)),"quick click back to the salt slot waits for physical return")
		expect(game._stock_bodies.get("salt")==bottle and bottle.get_meta("instance_uid")==uid,"return retains the same bottle without duplicating stock")
		expect(is_equal_approx(float(bottle.get_meta("remaining_ml")),amount),"return preserves remaining salt")
	game.queue_free()
	await process_frame
	await process_frame
	for message in failures: push_error(message)
	print("%s: small-window quick gestures, %d checks" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
func mouse(point: Vector2, kind: String) -> void:
	point = root.get_final_transform()*point
	if kind=="move":
		var e := InputEventMouseMotion.new()
		e.position=point
		e.global_position=point
		e.button_mask=MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(e)
	else:
		var e := InputEventMouseButton.new()
		e.position=point
		e.global_position=point
		e.button_index=MOUSE_BUTTON_LEFT
		e.pressed=kind=="down"
		e.button_mask=MOUSE_BUTTON_MASK_LEFT if e.pressed else 0
		Input.parse_input_event(e)
func expect(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message)
