extends Node2D

var cooking: = false
var customer: Dictionary = {}
var knife_held: = false
var time: = 0.0
var bell_time := 0.0
const ROOM = preload("res://modules/restaurant/assets/kitchen_reference_no_recipe_stand.png")
const FONT = preload("res://modules/restaurant/assets/fonts/noto_serif_sc.ttf")
func _ready() -> void:
	var room := Sprite2D.new()
	room.texture = ROOM
	room.centered = false
	room.scale = Vector2(1600, 900) / ROOM.get_size()
	room.z_index = -1
	var light := ShaderMaterial.new()
	light.shader = preload("res://modules/restaurant/assets/room_light.gdshader")
	room.material = light
	add_child(room)

func _draw() -> void :
	# Only replace the old baked-in towel rectangle. The rest is the approved room.
	var patch: Texture2D = preload("res://modules/restaurant/assets/cut_states/counter_patch.png")
	# Keep the original diagonal basin rim. The old rectangular towel patch
	# extended into the bowl and left an obvious blue square over the sink.
	var outline := PackedVector2Array([Vector2(433,685.5),Vector2(581.2,685.5),Vector2(581.2,812.1),Vector2(342.7,812.1),Vector2(342.7,752),Vector2(370,752)])
	var uv := PackedVector2Array()
	for point in outline: uv.append((Vector2(329,780)+(point-Vector2(342.7,685.5))/Vector2(238.5,126.6)*Vector2(229,144))/patch.get_size())
	draw_polygon(outline,PackedColorArray([Color.WHITE]),uv,patch)
	# Separate small signs leave the illustrated room and chalkboard visible.
	draw_string(FONT, Vector2(58, 55), "100饭店", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("fff0b8"))
	draw_string(FONT, Vector2(58, 80), "好好吃饭，也好好生活", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("eadbc4"))
	draw_rect(Rect2(0, 798, 1600, 102), Color("393632", 0.96))
	draw_string(FONT, Vector2(48, 832), "街角厨房", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("fff1bd"))
	# The original reference already contains the paper and clipboard.
	_draw_bell()

func ring_bell() -> void:
	bell_time = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	if bell_time > 0.0:
		bell_time = maxf(0.0, bell_time - delta)
		queue_redraw()

func _draw_bell() -> void:
	var pivot := Vector2(1028, 151)
	var swing := sin((1.0 - bell_time) * 32.0) * bell_time * 0.18
	var center := pivot + Vector2(0, 29).rotated(swing)
	draw_line(pivot, center + Vector2(0, -11).rotated(swing), Color("355a52"), 5.0, true)
	var bell := PackedVector2Array()
	for point in [Vector2(-14, 10), Vector2(-10, -9), Vector2(0, -16), Vector2(10, -9), Vector2(14, 10)]:
		bell.append(center + point.rotated(swing))
	draw_colored_polygon(bell, Color("e5b83d"))
	draw_polyline(bell, Color("9a6634"), 2.0, true)
	draw_circle(center + Vector2(0, 13).rotated(swing), 4.0, Color("d7653e"))
