extends "card.gd"

signal drag_started(card_id: String)
signal drag_released(card_id: String)
var movable := false
var locked := false
var dragging := false
var pressed := false
var press_at := Vector2.ZERO
var grab_offset := Vector2.ZERO
var LeftConnection: Marker2D
var RightConnection: Marker2D
var VisualAnchor: Marker2D
var LightAnchor: Marker2D
var StoryTags: Array = []

func _ready() -> void:
	super._ready()
	LeftConnection = anchor("LeftConnection", Vector2(0, size.y * 0.68))
	RightConnection = anchor("RightConnection", Vector2(size.x, size.y * 0.68))
	VisualAnchor = anchor("VisualAnchor", size * Vector2(0.5, 0.68))
	LightAnchor = anchor("LightAnchor", size * Vector2(0.5, 0.56))
	resized.connect(func():
		LeftConnection.position = Vector2(0, size.y * 0.68)
		RightConnection.position = Vector2(size.x, size.y * 0.68)
		VisualAnchor.position = size * Vector2(0.5, 0.68)
		LightAnchor.position = size * Vector2(0.5, 0.56))

func anchor(title: String, at: Vector2) -> Marker2D:
	var marker := Marker2D.new()
	marker.name = title
	marker.position = at
	add_child(marker)
	return marker

func _gui_input(event: InputEvent) -> void:
	if locked: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressed = true
			press_at = get_global_mouse_position()
			grab_offset = get_parent().get_local_mouse_position() - position
			accept_event()
		elif pressed:
			finish_pointer()
			accept_event()
	elif event is InputEventMouseMotion and pressed and movable:
		if not dragging and get_global_mouse_position().distance_to(press_at) > 7:
			dragging = true
			z_index = 5
			drag_started.emit(card_id)
		if dragging:
			position = get_parent().get_local_mouse_position() - grab_offset
			position.x = clampf(position.x, 260, 1190)
			position.y = clampf(position.y, 490, 660)
			rotation = 0.0
			accept_event()

func _input(event: InputEvent) -> void:
	# Release outside the control must also settle the card, never strand it.
	if pressed and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		finish_pointer()

func finish_pointer() -> void:
	pressed = false
	if dragging:
		dragging = false
		z_index = 0
		drag_released.emit(card_id)
	else:
		picked.emit(card_id)

func _get_drag_data(_at_position: Vector2) -> Variant:
	return null # Story mode moves the actual card, not a detached preview PNG.
