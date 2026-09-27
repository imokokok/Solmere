extends Node2D
## Standing water is fed by local floor arrivals, never spawned by a timer.
var world: Node2D
func _draw() -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.pan) or not is_instance_valid(world.pan.runoff): return
	var model=world.pan.runoff
	if model.floor_ml<=0.01: return
	var ratio: float=world.flood_ratio()
	var base: float=900.0+minf(46.0,model.floor_ml/2000.0*46.0)
	var surface:=PackedVector2Array()
	for x in 65:
		var local:=0.0
		for j in range(-2,3): local+=model.floor_cells[clampi(x+j,0,63)]/5.0
		var spread:=smoothstep(0.0,4.0,local)
		var depth:=minf(925.0,ratio*925.0)*spread
		var ripple: float=sin(x*0.67+model.clock*2.0)*minf(2.2,depth*0.04)
		surface.append(Vector2(x*25,minf(base-0.05,base-depth+ripple)))
	var shape:=surface.duplicate()
	shape.append(Vector2(1600,base))
	shape.append(Vector2(0,base))
	draw_colored_polygon(shape,Color(0.36,0.63,0.63,lerpf(0.18,0.49,ratio)))
	draw_polyline(surface,Color(0.80,0.90,0.80,0.65),1.7,true)
