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
	w.discard_held()
	await process_frame
	expect(w._drag_group.is_empty() and not w.held_grip.enabled and w._foods.get_child_count()==1,"discarding a held portion frees every carried body and grip")
	w.clear_workspace()
	expect(w._drag_group.is_empty() and not w._dragging,"cleanup leaves no orphaned batch drag")
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
