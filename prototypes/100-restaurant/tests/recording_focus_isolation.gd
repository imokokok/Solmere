extends RefCounted
## Capture-only host isolation: QA app switching must not close the faucet or
## release a held synthetic input. Load exact production sources in memory,
## disabling their OS-window notification callback and polling the virtual
## cursor that carries the same recorded input events. Temporary recording
## detachment keeps owned render/audio nodes alive; the original game cleanup
## remains untouched. Keep every existing
## script field/reference, physical body, renderer, cooking step and input method.
## Normal game scenes and regression tests still use the original scripts.
## _notification invokes all ancestors, so overriding it in a subclass cannot
## suppress the original handler (Godot Object notification documentation).
static var sources: Array[Script] = []
static var pointer := Vector2.ZERO

static func pointer_position() -> Vector2:
	return pointer

static func attach(node: Node) -> void:
	var original := {}
	for property in node.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			original[property.name]=node.get(property.name)
	var script:=GDScript.new()
	script.source_code=node.get_script().source_code.replace("func _notification(","func _capture_host_notification(").replace("get_global_mouse_position()", "_capture_mouse_position()").replace("func _exit_tree(","func _capture_host_exit_tree(")
	script.source_code += "\nvar _capture_pointer_provider: Callable\nfunc _capture_mouse_position() -> Vector2:\n\treturn _capture_pointer_provider.call()\n"
	assert(script.reload()==OK,"Capture input adapter must compile")
	sources.append(script)
	node.set_script(script)
	for key in original: node.set(key,original[key])
	node.set("_capture_pointer_provider", pointer_position)

static func install(world: Node) -> void:
	attach(world)
	for node in [world.pan,world.lid,world.cloth,world.sponge,world.plate,world.audio]: attach(node)
	for tool in world.utensils: attach(tool)
