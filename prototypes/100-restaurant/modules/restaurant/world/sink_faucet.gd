extends Node2D
var controller: Node2D
var basin: Node2D
func _ready() -> void:
	basin = Node2D.new()
	basin.z_index = 2
	controller.world.add_child(basin)
	basin.draw.connect(_draw_basin)
func _process(_dt: float) -> void:
	basin.queue_redraw()
func _exit_tree() -> void:
	if is_instance_valid(basin): basin.queue_free()
func sink_surface_y() -> float:
	return lerpf(738.0, 698.0, clampf(controller.world.sink_water_ml/controller.world.SINK_HOLD_ML,0,1))
func _draw_basin() -> void:
	var fill: float=clampf(controller.world.sink_water_ml/controller.world.SINK_HOLD_ML,0,1)
	if fill <= 0.0001: return
	var lower := PackedVector2Array([Vector2(38,723),Vector2(334,723),Vector2(316,739),Vector2(21,739)])
	var upper := PackedVector2Array([Vector2(45,650),Vector2(422,650),Vector2(337,739),Vector2(17,739)])
	var shape:=PackedVector2Array()
	for i in 4: shape.append(lower[i].lerp(upper[i],fill))
	basin.draw_colored_polygon(shape,Color(0.45,0.64,0.66,minf(0.62,fill*2.0)))
	basin.draw_polyline(PackedVector2Array([shape[0],shape[1],shape[2]]),Color(0.79,0.9,0.85,0.4*fill),1.8,true)
	for i in 3:
		var y: float=lerpf(shape[0].y+7,735,float(i+1)/4)
		var x: float=80+i*65+sin(controller.world._time*1.7+i)*6
		basin.draw_line(Vector2(x,y),Vector2(x+42,y-1),Color(0.82,0.9,0.85,0.13*fill),1.4,true)
const HANDLE_RECT := Rect2(158, 593, 66, 52)
func _draw() -> void :
	# One angular blue-grey faucet, matching the supplied reference.
	draw_rect(Rect2(125, 612, 35, 35), Color("526471"))
	draw_rect(Rect2(132, 552, 22, 67), Color("536978"))
	draw_colored_polygon(PackedVector2Array([Vector2(132,552),Vector2(202,533),Vector2(202,551),Vector2(154,565)]), Color("637989"))
	draw_line(Vector2(135,552), Vector2(198,535), Color("8495a0"), 3, true)
	draw_rect(Rect2(193, 545, 13, 17), Color("3f535f"))
	var pivot := Vector2(158, 618)
	var tip := pivot + Vector2(40, 0).rotated(controller.faucet_amount * PI * 0.42)
	draw_line(pivot, tip, Color("344b58"), 11, true)
	draw_line(pivot + Vector2(0,-2), tip + Vector2(0,-2), Color("8293a0"), 3, true)
	if controller.faucet_on and controller.world.controls_enabled:
		var fill: float = controller.world.pan_fill_ratio()
		var surface: Vector2 = controller.point(preload("res://modules/restaurant/world/pan_geometry.gd").water_center(fill))
		var end_y: float = surface.y if controller.under_tap() else sink_surface_y()
		var stream := PackedVector2Array()
		var shine := PackedVector2Array()
		for i in 33:
			var t := float(i)/32.0
			var y := lerpf(562.0,end_y,t)
			var x: float = 200.0 + sin(controller.world._time*8.0-t*7.0)*0.45*t
			stream.append(Vector2(x,y))
			shine.append(Vector2(x-0.7,y))
		var width: float = 1.0+sqrt(controller.faucet_amount)*4.0
		draw_polyline(stream,Color(0.67,0.83,0.80,0.46),width,true)
		draw_polyline(shine,Color(0.93,0.96,0.87,0.5),width*0.25,true)
		for i in 3:
			var phase: float = fmod(controller.world._time*1.2+i/3.0,1.0)
			var ring := PackedVector2Array()
			for k in 33: ring.append(Vector2(200,end_y)+Vector2(cos(k*TAU/32.0),sin(k*TAU/32.0)*0.24)*(3+phase*14))
			draw_polyline(ring,Color(0.86,0.93,0.85,(1-phase)*0.25*controller.faucet_amount),1.0,true)

func overflow_path(side: float) -> PackedVector2Array:
	var geometry = preload("res://modules/restaurant/world/pan_geometry.gd")
	var lip_x: float = geometry.CENTER.x + side * 106.0
	var path := PackedVector2Array()
	for point in [geometry.CENTER + Vector2(side * 91.0, 18.0), Vector2(lip_x, geometry.front_y(lip_x)), geometry.CENTER + Vector2(side * 127.0, 33.0), geometry.CENTER + Vector2(side * 132.0, 69.0)]:
		path.append(controller.point(point))
	path.append(Vector2(path[-1].x + side * 5.0, maxf(741.0, path[-1].y + 20.0)))
	return path
