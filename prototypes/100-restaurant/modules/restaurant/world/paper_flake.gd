extends Node2D
var index := 0
func paint(target: Node2D) -> void:
	var color: Color = [Color("e258a1"),Color("57b4c8"),Color("deb542"),Color("96bb59"),Color("9a78ce")][index%5]
	target.draw_colored_polygon(PackedVector2Array([Vector2(-4,-3),Vector2(3,-4),Vector2(5,3),Vector2(-2,4)]),color)
	target.draw_line(Vector2(-2,-2),Vector2(3,-3),color.lightened(0.25),1,true)
func _draw() -> void: paint(self)
