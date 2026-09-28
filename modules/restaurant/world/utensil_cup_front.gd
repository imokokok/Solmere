extends Node2D
## Repaint the fixed cup from the same environment so resting handles sit inside.
func _ready() -> void:
	z_index = 43
func _draw() -> void:
	var room = preload("res://modules/restaurant/assets/kitchen_reference_playable.png")
	var destination := Rect2(550, 552, 78, 91)
	var ratio := room.get_size() / Vector2(1600, 900)
	draw_texture_rect_region(room, destination, Rect2(destination.position * ratio, destination.size * ratio))
