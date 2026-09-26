extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://Main.tscn").instantiate();root.add_child(game)
 while not game.ready_done:await process_frame
 game.smoke=true
 await create_timer(1).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("COLLAGE_TEST_OUTPUT").path_join("showcase-final.png"))
 game.audio.shutdown();game.queue_free();await process_frame;await process_frame;quit()
