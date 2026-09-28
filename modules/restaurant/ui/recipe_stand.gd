extends Node2D
var page
var viewport: SubViewport
var record: Dictionary = {}

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(560, 760)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	page = preload("res://modules/restaurant/ui/recipe_page.gd").new()
	page.size = Vector2(560, 760)
	viewport.add_child(page)
	page.setup(record)
	queue_redraw()

func setup(value: Dictionary) -> void:
	record = value.duplicate(true)
	if is_instance_valid(page): page.setup(record)
	queue_redraw()

func _draw() -> void:
	if viewport == null: return
	draw_polygon(PackedVector2Array([Vector2(1129, 469), Vector2(1284, 470), Vector2(1346, 661), Vector2(1164, 663)]), PackedColorArray([Color.WHITE]), PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), viewport.get_texture())
