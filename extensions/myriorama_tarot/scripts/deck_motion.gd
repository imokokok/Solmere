extends RefCounted

# Extracted from table.gd. Both the existing case table and the reader room use
# the same packet trajectory, easing, flip midpoint and sampled sound timing.
static func move_packet(owner: Node, packet: Control, destination: Vector2, duration: float, tilt: float, sound: Node) -> void:
	var origin := packet.position
	var original_rotation := packet.rotation
	packet.get_parent().move_child(packet, -1)
	var tween := owner.create_tween()
	tween.tween_method(func(t: float):
		packet.position = origin.lerp(destination, t) + Vector2(0, -sin(t * PI) * 18.0)
		packet.rotation = lerpf(original_rotation, tilt, t) + sin(t * PI) * 0.025
		packet.scale = Vector2.ONE * (1.0 + sin(t * PI) * 0.025)
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): sound.play("place"))
	await tween.finished

static func shuffle(owner: Node, piles: Array, origin: Vector2, sound: Node) -> void:
	var tween := owner.create_tween()
	for _pass in range(3):
		tween.tween_callback(func(): sound.play("shuffle"))
		tween.tween_property(piles[2], "position", origin + Vector2(58, -7), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(piles[2], "position", origin + Vector2(6, 6), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	await move_packet(owner, piles[2], origin + Vector2(-170, 11), 0.43, -0.035, sound)
	await move_packet(owner, piles[1], origin + Vector2(180, 3), 0.43, 0.025, sound)
	await owner.get_tree().create_timer(0.16).timeout
	await move_packet(owner, piles[1], origin + Vector2(0, 3), 0.39, 0.0, sound)
	await move_packet(owner, piles[2], origin + Vector2(3, 0), 0.39, 0.0, sound)

static func flip(owner: Node, card: TextureRect, face: Texture2D, sound: Node) -> void:
	var tween := owner.create_tween()
	tween.tween_property(card, "scale:x", 0.02, 0.13)
	await tween.finished
	sound.play("flip")
	card.texture = face
	tween = owner.create_tween()
	tween.tween_property(card, "scale:x", 1.0, 0.16)
	await tween.finished

static func fan_pose(index: int, count: int, dimensions: Vector2) -> Dictionary:
	var theta := lerpf(-0.22, 0.22, float(index) / float(maxi(1, count - 1)))
	var midpoint := Vector2(800, 2380) + Vector2(sin(theta), -cos(theta)) * 1650.0
	return {"position": midpoint - dimensions / 2.0, "angle": theta}
