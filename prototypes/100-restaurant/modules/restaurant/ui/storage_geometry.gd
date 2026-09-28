extends RefCounted
## Shared support planes and front-wall depths, in the painted room's coordinates.
## The original room supplies the walls. Clip only the stored object, never
## repaint the rear box across a pan or a tool carried in front of it.
static func support(surface: String, slot: Rect2) -> Dictionary:
	var lip := slot.end.y
	var depth := 0.0
	match surface:
		"rack": lip = 590.0; depth = 14.0
		"counter": lip = 616.0; depth = 7.0
		"fridge": depth = 3.0
		"odd": depth = 5.0
	return {"floor": lip + depth, "lip": lip, "depth": depth,
		"opening": Rect2(slot.position.x + 1, slot.position.y - 160, slot.size.x - 2, lip - slot.position.y + 160)}
