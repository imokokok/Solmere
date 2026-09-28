extends Node2D
var source: Node2D
func _draw() -> void :
	if is_instance_valid(source) and source.has_method("paint"): source.paint(self)
