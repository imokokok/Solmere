extends StyleBox
## One quiet, textured sheet shared by menus, orders and the host's closing page.
const Paper = preload("res://modules/restaurant/ui/paper_surface.gd")

func _init() -> void:
	set_content_margin_all(28)

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	# StyleBox draws through RenderingServer, so reuse the same source texture
	# as the editable pages rather than introducing another paper material.
	var texture: Texture2D = load(Paper.TEXTURE_PATH)
	RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(rect.position + Vector2(3, 6), rect.size), Color("392f23", 0.18))
	RenderingServer.canvas_item_add_texture_rect(to_canvas_item, rect, texture.get_rid(), false, Color("fff5dd"))
	RenderingServer.canvas_item_add_rect(to_canvas_item, rect, Color("fff3dc", 0.48))
