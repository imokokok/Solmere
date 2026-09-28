extends Control
## The actual kitchen, with its own viewport/physics space and no duplicate HUD.
const Kitchen = preload("res://modules/restaurant/restaurant.tscn")
const Bridge = preload("res://scripts/core/restaurant_bridge.gd")
const DESIGN := Vector2i(1600, 946)
var kitchen: Node
var viewport: SubViewport
var container: SubViewportContainer
var context: Dictionary = {}
var result: Dictionary = {}
var planned_minutes := 90
var submitting := false
var previous_ticks := 60
var previous_steps := 8
var previous_audio := true

func _ready() -> void:
	context = GameplayModuleSystem.session_context()
	if GameplayModuleSystem.pending_module_id() != "cooking" or str(context.get("current_character", "")) != GameState.current_role:
		SceneRouter.return_from_gameplay()
		return
	previous_ticks = Engine.physics_ticks_per_second
	previous_steps = Engine.max_physics_steps_per_frame
	Engine.physics_ticks_per_second = 120
	Engine.max_physics_steps_per_frame = 16
	previous_audio = WorldSound.active
	WorldSound.set_active(false)
	planned_minutes = int(EconomySystem.cooking_cost({"minutes":90}).get("minutes",90))
	var background := ColorRect.new()
	background.color = Color("302e2b")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)
	container = SubViewportContainer.new()
	container.name = "RestaurantViewportContainer"
	container.size = Vector2(DESIGN)
	container.stretch = false
	add_child(container)
	viewport = SubViewport.new()
	viewport.name = "RestaurantViewport"
	viewport.size = DESIGN
	viewport.world_2d = World2D.new()
	viewport.handle_input_locally = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	kitchen = Kitchen.instantiate()
	var note := ""
	var order := EconomySystem.active_order()
	if bool(order.get("delivered", false)) and not bool(order.get("paid", false)):
		var names: Array[String] = []
		for id in order.get("items", []): names.append(EconomySystem.ingredient_name(str(id)))
		note = "今天交来的：%s。食材柜里可以找到，出餐用上才算交单。" % "、".join(names)
	kitchen.configure({"player_id":GameState.current_role,"display_name":"我的菜谱",
		"repository_path":Bridge.storage_path(), "letters_path":Bridge.storage_path().get_base_dir()+"/letters.json",
		"procurement_note":note, "start_minute":GameState.current_minute,"shift_minutes":planned_minutes,"shift_seconds":720.0})
	kitchen.shift_completed.connect(func(value: Dictionary): result=value.duplicate(true))
	kitchen.exit_requested.connect(_leave)
	viewport.add_child(kitchen)
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	if not is_instance_valid(container): return
	var fit_scale := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	container.scale = Vector2.ONE * fit_scale
	container.position = (size - Vector2(DESIGN) * fit_scale) * 0.5

func _leave() -> void:
	if submitting or SceneRouter.transitioning: return
	submitting = true
	var committed := Bridge.settle(result, context, planned_minutes)
	if not bool(committed.ok):
		submitting = false
		kitchen.resume_exit(str(committed.message))
		return
	SceneRouter.return_from_gameplay()

func _exit_tree() -> void:
	if is_instance_valid(viewport):
		Engine.physics_ticks_per_second = previous_ticks
		Engine.max_physics_steps_per_frame = previous_steps
		WorldSound.set_active(previous_audio)
