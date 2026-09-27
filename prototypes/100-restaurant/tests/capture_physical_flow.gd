extends SceneTree
var game
var w
func _initialize():
	root.size=Vector2i(1600,946)
	root.title="厨房物理检查 · 流水与锅盖"
	Engine.max_fps=60
	call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/visual-"+name+".png")
func step(seconds: float):
	for i in int(seconds*120):
		w.pan.advance_water(1.0/120)
		w.pan.runoff.advance(1.0/120)
func run():
	game=preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://flow_capture_%s/book.json"%Crypto.new().generate_random_bytes(16).hex_encode(),"shift_seconds":3600})
	root.add_child(game)
	await process_frame
	game._start_shift()
	w=game.world
	w.audio.muted=true
	w.pan.set_physics_process(false)
	w.pan.runoff.set_physics_process(false)
	w.reactions.set_physics_process(false)
	w.pan.rigid.freeze=true
	w.pan.move_to(Vector2(w.pan.SINK_X-809,w.pan.HOME.y))
	w.pan.faucet_on=true
	step(4.0)
	await capture("filling")
	step(7.0)
	await capture("rim")
	step(8.0)
	await capture("sink-overflow")
	step(10.0)
	await capture("floor-pool")
	print("PASS: GPU finite water capture")
	quit()
