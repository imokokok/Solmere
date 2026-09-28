extends Control
## Instruction sketches reuse kitchen art. These are labelled state diagrams, not photos.
var stage := "raw"
var entries: Array = []
var catalog: Array = []
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	for i in range(mini(entries.size(), 6)):
		var item: Dictionary = entries[i]
		var definition: Dictionary = {}
		for data in catalog:
			if data.id == item.get("id", ""): definition = data
		var art = preload("res://modules/restaurant/assets/food_art.gd").new()
		art.definition = definition
		art.shadows = false
		art.heat = float(item.get("heat", 0)) if stage in ["cook", "plate"] else 0.0
		art.softness = float(item.get("softness", 0)) if stage in ["cook", "plate"] else 0.0
		if stage in ["cook","plate"]:
			art.thermal=item.get("thermal",{}).duplicate(true)
			art.coating=item.get("surface_sauce",{}).duplicate(true)
		var anchor := Node2D.new()
		anchor.position = Vector2(48 + (i % 3) * 52, 47 + (i / 3) * 24)
		if entries.size() == 1: anchor.position.x = 82
		add_child(anchor)
		art.scale = Vector2.ONE * 0.66
		if stage != "raw" and bool(item.get("cut", false)):
			for side in [-1, 1]:
				var mask := Polygon2D.new()
				mask.polygon = PackedVector2Array([Vector2(0, -31), Vector2(side * 31, -31), Vector2(side * 31, 31), Vector2(0, 31)])
				mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
				mask.position.x = side * 4
				anchor.add_child(mask)
				# Node.duplicate does not preserve non-exported script properties.
				# Reconstruct explicitly, otherwise every cut ingredient becomes tomato.
				var piece = preload("res://modules/restaurant/assets/food_art.gd").new()
				piece.definition = definition
				piece.shadows = false
				piece.heat = art.heat
				piece.softness = art.softness
				piece.thermal = art.thermal.duplicate(true)
				piece.coating = art.coating.duplicate(true)
				piece.cut = true
				piece.scale = art.scale
				mask.add_child(piece)
			art.free()
		else: anchor.add_child(art)

func _draw() -> void:
	if stage in ["pan", "cook", "water"]:
		draw_style_box(_oval(Color("d2b88d")), Rect2(6, 20, size.x - 12, 62))
		draw_style_box(_oval(Color("536963")), Rect2(8, 17, size.x - 16, 60))
		draw_style_box(_oval(Color("92b9af") if stage == "water" else Color("394b48")), Rect2(16, 22, size.x - 32, 40))
		if stage == "cook":
			for x in [40, 80, 120]:
				draw_polyline(PackedVector2Array([Vector2(x, 19), Vector2(x-4, 11), Vector2(x+2, 3)]), Color("a2afa0"), 2, true)
	elif stage == "plate":
		draw_style_box(_oval(Color("cab89a")), Rect2(8, 25, size.x - 16, 58))
		draw_style_box(_oval(Color("fff9df")), Rect2(6, 20, size.x - 12, 54))
	elif stage == "cut":
		draw_style_box(_oval(Color("dcae73")), Rect2(6, 25, size.x - 12, 56))
		draw_line(Vector2(size.x-24, 22), Vector2(size.x-55, 50), Color("d1d4c6"), 9, true)
		draw_line(Vector2(size.x-24, 22), Vector2(size.x-12, 10), Color("686652"), 7, true)

func _oval(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(32)
	return style
