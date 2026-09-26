extends Node2D

enum State { IDLE, WAITING, WATCHING_CARD, THINKING, SPEAKING, REACTING }
var state := State.IDLE
var portrait: Sprite2D
var elapsed := 0.0
var attention := 0.0
var focus_x := 800.0

func _ready() -> void:
	portrait = Sprite2D.new()
	portrait.name = "OriginalPortrait"
	portrait.texture = preload("res://extensions/myriorama_tarot/assets/reader-scene/tarot-reader-original.png")
	portrait.centered = false
	portrait.position = Vector2(368,-30)
	portrait.scale = Vector2.ONE * 0.4
	add_child(portrait)

func set_state(value: int, card_x: float = 800.0) -> void:
	state = value
	focus_x = card_x

func _process(delta: float) -> void:
	elapsed += delta
	var aimed := clampf((focus_x-800.0)/100.0, -3.0, 3.0) if state == State.WATCHING_CARD else 0.0
	attention = lerpf(attention, aimed, 1.0-exp(-delta*4.0))
	# Uniform translation only: original face, clothing, proportions and pixels
	# remain untouched. No generated blink/expression is substituted.
	portrait.position = Vector2(368 + attention, -30 + sin(elapsed*1.35)*1.3)
	if state == State.SPEAKING: portrait.position.y += sin(elapsed*2.4)*0.7
	if state == State.REACTING: portrait.position.y += sin(elapsed*3.0)*1.2
