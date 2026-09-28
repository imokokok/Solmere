extends Control
## Shared paper surface for orders, writable pages and published recipes.
const TEXTURE_PATH := "res://modules/restaurant/assets/paper/ivory_fibers.png"
static var texture: Texture2D
var ruled := false
var folded := true

static func paint(item: CanvasItem, rect: Rect2, with_fold := true) -> void:
	if texture == null and ResourceLoader.exists(TEXTURE_PATH): texture = load(TEXTURE_PATH)
	var points := PackedVector2Array()
	for uv in [Vector2(0.006,0.006),Vector2(0.46,0),Vector2(0.993,0.009),Vector2(1,0.43),Vector2(0.994,0.975),Vector2(0.976,0.994),Vector2(0.4,1),Vector2(0.002,0.986),Vector2(0,0.36)]:
		points.append(rect.position + uv * rect.size)
	item.draw_colored_polygon(Transform2D(0,Vector2(3,5)) * points, Color("493d2b",0.14))
	var uvs := PackedVector2Array()
	for point in points: uvs.append((point - rect.position) / rect.size)
	item.draw_polygon(points, PackedColorArray([Color.WHITE if texture else Color("f4e7c9")]), uvs, texture)
	item.draw_colored_polygon(points,Color("fff3dc",0.52))
	var border := points.duplicate()
	border.append(points[0])
	item.draw_polyline(border,Color("b9a884",0.45),1,true)
	if with_fold:
		var p := rect.end - Vector2(3,3)
		item.draw_colored_polygon(PackedVector2Array([p-Vector2(22,0),p-Vector2(0,23),p]),Color("ddcfb1",0.75))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	paint(self,Rect2(Vector2.ZERO,size),folded)
	if ruled:
		for y in range(42,int(size.y)-18,32): draw_line(Vector2(22,y),Vector2(size.x-22,y+0.3),Color("9aada5",0.2),1,true)
