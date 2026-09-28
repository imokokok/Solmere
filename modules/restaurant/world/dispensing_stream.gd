extends Node2D
var world: Node2D
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	if is_instance_valid(world): world._draw_dispensing_stream(self, true)
