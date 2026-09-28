extends Control
## A thermometer with a moving target band, not a completion/progress bar.
var feedback: Dictionary = {}
var font := preload("res://modules/restaurant/ui/paper_ink.gd").font()
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func present(value: Dictionary) -> void:
	feedback = value
	queue_redraw()
func _draw() -> void:
	if feedback.is_empty(): return
	var ink := Color("f2e3c5")
	var risk := Color("eea278") if int(feedback.severity)>0 else Color("d1c1a7")
	draw_string(font,Vector2(0,19),str(feedback.title),HORIZONTAL_ALIGNMENT_LEFT,size.x,20,ink)
	draw_string(font,Vector2(0,42),str(feedback.advice),HORIZONTAL_ALIGNMENT_LEFT,size.x,17,risk)
	var track := Rect2(0,56,size.x,6)
	draw_style_box(_skin(Color("645c4e")),track)
	var low := clampf(float(feedback.low)/300.0,0,1)
	var high := clampf(float(feedback.high)/300.0,0,1)
	draw_style_box(_skin(Color("87a56c")),Rect2(low*size.x,56,maxf(4,(high-low)*size.x),6))
	draw_style_box(_skin(Color("aa6550")),Rect2(minf(1,high+0.1)*size.x,56,(1-minf(1,high+0.1))*size.x,6))
	var x := clampf(float(feedback.temperature)/300.0,0,1)*size.x
	draw_colored_polygon(PackedVector2Array([Vector2(x-4,48),Vector2(x+4,48),Vector2(x,54)]),Color("fff0cc"))
	draw_string(font,Vector2(0,82),"锅温 %d°" % roundi(feedback.temperature),HORIZONTAL_ALIGNMENT_LEFT,125,15,ink)
	draw_string(font,Vector2(135,82),"绿色："+str(feedback.method),HORIZONTAL_ALIGNMENT_LEFT,size.x-255,15,Color("bace9e"))
	draw_string(font,Vector2(size.x-100,82),"过热",HORIZONTAL_ALIGNMENT_RIGHT,100,15,Color("dea283"))
func _skin(color: Color) -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = color
	skin.set_corner_radius_all(3)
	return skin
