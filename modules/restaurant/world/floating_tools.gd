extends CanvasLayer

var world: Node2D
var copies: Dictionary = {}
var cup_mask: Node2D

func _ready() -> void :
	layer = 2
	cup_mask = preload("res://modules/restaurant/world/utensil_cup_front.gd").new()
	add_child(cup_mask)
	cup_mask.z_index = 6
	cup_mask.hide()

func _process(_delta: float) -> void :
	# Occlusion is already present while the handle enters the cup, so the
	# final foreground-to-storage handoff cannot visibly jump behind its wall.
	cup_mask.visible = world.controls_enabled and world.utensils.any(func(tool): return tool.storing)
	cup_mask.transform = world.get_global_transform_with_canvas()
	var wanted: Array[Node2D] = []
	if world.controls_enabled:
		# Loose objects in front of cupboards stay in front after mouse release.
		# Hand off to the world only at the worktop or actual pan mouth.
		for body in world._foods.get_children():
			if body == world._held or body.is_queued_for_deletion() or body.get_meta("egg_cracking", false) or body.get_meta("plated", false): continue
			if body.get_meta("batch_carried", false) or (body.position.y < 620.0 and not world.pan.contains(body.position)):
				var art: Node2D = body.get_node_or_null("FoodArt")
				if art: wanted.append(art)
		if world.pan.active or world.pan.falling:
			wanted.append(world.pan.pan_back)
			wanted.append(world.pan.pan_front)
			wanted.append(world.pan.pan_surface)
			for body in world._foods.get_children():
				if body == world._held or body.is_queued_for_deletion(): continue
				if world.pan.is_carrying(body) or (body.get_meta("poured", false) and not body.get_meta("plated", false)):
					var art: Node2D = body.get_node_or_null("FoodArt")
					if art == null: art = body.get_node_or_null("SauceBlob")
					if art: wanted.append(art)
		for tool in world.utensils:
			if not tool.docked:
				wanted.append(tool)
				if tool.kind == "spoon":
					for body in tool.bowl_contents():
						var art: Node2D = body.get_node_or_null("FoodArt")
						if art: wanted.append(art)
					if is_instance_valid(tool._rim_visual): wanted.append(tool._rim_visual)
		if world.lid.active or world.lid.returning or world.lid.seating or world.lid._flight or world.lid._settling > 0.0 or (world.lid.covered and (world.pan.active or world.pan.falling)):
			wanted.append(world.lid)
		if world._knife_held: wanted.append(world._knife_visual)
		if world.sponge.active: wanted.append(world.sponge)
		if world.cloth.active: wanted.append(world.cloth)
		if world.plate.active:
			wanted.append(world.plate)
			for body in world._foods.get_children():
				if body.is_queued_for_deletion() or not body.get_meta("plated", false): continue
				var art: Node2D = body.get_node_or_null("FoodArt")
				if art == null: art = body.get_node_or_null("SauceBlob")
				if art: wanted.append(art)
	for id in copies.keys():
		var entry: Dictionary = copies[id]
		if not is_instance_valid(entry.source) or not wanted.has(entry.source):
			if is_instance_valid(entry.source): entry.source.visible = true
			entry.proxy.queue_free()
			copies.erase(id)
	for source in wanted:
		var id: = source.get_instance_id()
		if not copies.has(id):
			var proxy: = Node2D.new()
			if world.utensils.has(source) or source.has_method("paint"):
				proxy.set_script(preload("res://modules/restaurant/world/utensil_proxy.gd"))
				proxy.source = source
			else:
				proxy.set_script(source.get_script())
				for property in source.get_property_list():
					if str(property.name) in ["controller", "definition", "cut", "heat", "softness", "thermal", "coating", "compression", "shadows", "polygon", "art_offset", "dispense_mode", "liquid_state", "cut_style", "cut_variant", "source_fraction", "crack_progress", "flex", "dangling", "motion_time"]:
						proxy.set(property.name, source.get(property.name))
			add_child(proxy)
			copies[id] = {"source": source, "proxy": proxy}
		var visual: Node2D = copies[id].proxy
		visual.modulate = source.modulate
		visual.transform = source.get_global_transform_with_canvas()
		if source == world.lid:
			visual.transform = world.get_global_transform_with_canvas() * world.lid.display_transform()
		# Proxies remain views of the live food, including while it keeps cooking.
		for property_name in ["cut", "heat", "softness", "thermal", "coating", "compression", "liquid_state", "crack_progress", "flex", "dangling", "motion_time"]:
			if property_name in source and property_name in visual: visual.set(property_name, source.get(property_name))
		var spoon_rim: = source.name == "SpoonFrontRim"
		var spoon_food: = source.get_parent() is RigidBody2D and _spoon_holds(source.get_parent())
		var plate_food: bool = source.get_parent() is RigidBody2D and bool(source.get_parent().get_meta("plated", false))
		if source == world.pan.pan_back: visual.z_index = 0
		elif source == world.plate: visual.z_index = 1
		elif plate_food: visual.z_index = 2 if source.name == "SauceBlob" else 3
		elif source in [world._knife_visual, world.sponge, world.cloth, world.lid]: visual.z_index = 8
		elif spoon_rim: visual.z_index = 7
		elif spoon_food: visual.z_index = 6
		elif world.utensils.has(source): visual.z_index = 5
		elif source == world.pan.pan_front: visual.z_index = 4
		elif source == world.pan.pan_surface: visual.z_index = 3
		else: visual.z_index = 1 if source.name == "SauceBlob" else 2
	# Keep overlapping carried pieces in the same depth order as the kitchen.
	var ordered := copies.values()
	ordered.sort_custom(func(a, b): return a.source.get_global_transform_with_canvas().origin.y < b.source.get_global_transform_with_canvas().origin.y)
	for index in ordered.size():
		if ordered[index].proxy.get_index() != index: move_child(ordered[index].proxy, index)
	for entry in copies.values():
		entry.proxy.queue_redraw()
		entry.source.visible = false

func _exit_tree() -> void :
	for entry in copies.values():
		if is_instance_valid(entry.source): entry.source.visible = true
	copies.clear()

func _spoon_holds(body: RigidBody2D) -> bool:
	for tool in world.utensils:
		if tool.kind == "spoon" and tool.bowl_contains(body): return true
	return false
