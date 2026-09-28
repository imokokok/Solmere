extends SceneTree
## GPU presentation fixtures. Temperatures/phases are staged deliberately;
## these images do not claim a manual playthrough or measured cooking time.
var game
var folder := "res://qa/20260928-art-ui-integration/"
func _initialize() -> void:
	root.size=Vector2i(1600,946)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	call_deferred("run")
func capture(name: String) -> void:
	game._update_hud()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder+name+".png") == OK)
func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	game=preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://material_visual_qa/book.json"})
	root.add_child(game)
	await process_frame
	game._start_shift()
	var w=game.world
	w.audio.muted=true
	w.spawn_ingredient(game._definition("cheese"))
	var cheese: RigidBody2D=w._held
	w.drop_into_pan()
	await create_timer(2).timeout
	await capture("cheese-cold-guide")
	w.reactions.set_physics_process(false)
	w.material_play.set_physics_process(false)
	var state: Dictionary=w.reactions.ensure_state(cheese)
	state.converted_kg=state.initial_kg*0.45
	state.liquid_kg=state.converted_kg
	state.core_c=64.0
	state.faces_c=[70.0,62.0]
	state.softness=0.8
	w.reactions.pan_c=95.0
	w.reactions._apply(cheese,state)
	game.session.dish[0].merge(w.describe_body(cheese),true)
	await capture("cheese-melted-guide")
	w.reactions.pan_c=238.0
	w.material_play.hot_oil=15.0
	w.cooking=true
	await capture("oil-overheat-guide")
	w.material_play.fire=0.75
	w.material_play.smoke=0.5
	w.material_play._overlay.queue_redraw()
	await capture("fire-recovery-guide")
	w.material_play.fire=0.0
	w.material_play.smoke=0.0
	w.material_play.foam=0.95
	w.material_play._overlay.queue_redraw()
	await capture("soap-foam")
	print("PASS GPU material presentation: five controlled states")
	quit()
