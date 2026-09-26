extends SceneTree
var game
var failures:=0
class HostAtmosphere extends Node:
	var minute:=1080.0
	var rain:=0.0
	func ensure_initialized() -> void:pass
func _initialize() -> void:call_deferred("run")
func check(value: bool,why: String) -> void:
	if not value:failures+=1;push_error(why)
func capture(name: String) -> Image:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	var folder:=OS.get_environment("COLLAGE_TEST_OUTPUT")
	if not folder.is_empty():image.save_png(folder.path_join(name+".png"))
	return image
func difference(a: Image,b: Image) -> float:
	var sum:=0.0
	for y in range(250,700,17):
		for x in range(470,990,19):
			var ca:=a.get_pixel(x,y);var cb:=b.get_pixel(x,y)
			sum+=absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)
	return sum
func run() -> void:
	game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true;root.gui_disable_input=true
	preload("res://scripts/showcase_draft.gd").apply(game)
	var light=game.get_node("DeskLighting")
	var host:=HostAtmosphere.new();host.name="WorldAtmosphere";root.add_child(host)
	light.refresh(0)
	check(light.minute==1080,"Desk uses the host presentation clock")
	host.minute=720;light.refresh(0);game.blinds_open=0;game.queue_redraw()
	var closed:=await capture("light-day-closed")
	game.blinds_open=1;game.queue_redraw();var opened:=await capture("light-day-open")
	check(difference(closed,opened)>12,"Opening the blind visibly replaces slatted daylight with broad light")
	light.animation_time+=14;light.refresh(0);var moved:=await capture("light-day-drift")
	check(difference(opened,moved)>0.5,"Sunlight changes gently over time")
	host.minute=1110;light.refresh(0);var dusk:=await capture("light-dusk")
	check(difference(opened,dusk)>50,"Dusk follows the host and changes the rendered warm palette")
	host.minute=1260;light.refresh(0);var night:=await capture("light-night")
	check(light.sun_strength==0,"No sunlight is emitted at night")
	check(difference(dusk,night)>50,"Night has a distinct readable ambient palette")
	host.minute=720;host.rain=1;light.refresh(0);check(light.sun_strength<0.2,"Host rain dims direct sunlight")
	game.writing_preferences.reduce_motion=true;var before:float=light.animation_time;light.refresh(.1)
	check(light.animation_time==before,"Reduced motion stops light animation")
	for b in game.desk.find_children("*","Button",true,false):
		if b.name!="Object_notebook" and b.global_position.y<112 and b.global_position.x>1090:check(false,"Top-right utility buttons were removed")
	host.queue_free();game.audio.shutdown();game.queue_free();await process_frame;await process_frame
	print("DESK_LIGHTING_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures);quit(failures)
