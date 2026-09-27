extends Node
## CC0 field recordings only. Material routing is a documented acoustic approximation.

const LOOPS := {"runoff": -24.0, "flame": -26.0, "sizzle": -14.0, "sauce": -13.0, "boil": -12.0, "water": -15.0, "squeeze": -14.0, "pour": -14.0, "powder": -13.0}
const EFFECT_BANKS := {"ignite": "ignite", "tap": "tap", "bell": "bell", "pan": "pan", "chop": "chop", "chop_soft": "chop_soft", "chop_hard": "chop_hard", "stir": "stir_wood", "stir_wet": "stir_wet", "stir_meat": "stir_wet", "stir_dry": "stir_dry", "stir_hard": "pan", "stir_water": "stir_water", "stir_sauce": "stir_sauce", "stir_pasta": "stir_pasta", "stir_wood": "stir_wood", "stir_metal": "stir_metal", "drop": "drop", "drop_dry": "drop_dry", "drain": "drain", "pour": "drain", "wipe": "wipe", "paper": "paper", "serve": "serve", "toss": "toss", "hot_drop": "hot_drop"}
const OILS := ["oil", "butter", "olive_oil", "sesame_oil"]
const LID_LEVELS := {"lid_tick": -27.0, "lid_close": -20.0, "lid_pop": -13.0, "lid_land": -18.0, "lid_rebound": -23.0, "steam_release": -20.0}
const SAUCES := ["ketchup", "mayonnaise", "mustard", "chili_sauce", "soy_sauce", "soy", "cream", "milk", "honey"]
var muted := false:
	set(value):
		muted = value
		if value: stop_all()
var focused := true
var ui_dispense_mode := ""
var ui_dispense_id := ""
var ui_pressure := 0.0
var loops: Dictionary = {}
var effects: Dictionary = {}
var banks: Dictionary = {}
var loop_banks: Dictionary = {}
var _last_effect: Dictionary = {}
var _last_variant: Dictionary = {}
var _samples: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	banks = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/data/audio_bank.json"))
	for variants in banks.values():
		for path in variants: _samples[path] = load(path)
	for id in LOOPS:
		var player := AudioStreamPlayer.new()
		player.volume_db = LOOPS[id]
		add_child(player)
		loops[id] = player
	for id in EFFECT_BANKS:
		var player := AudioStreamPlayer.new()
		player.volume_db = -19.0 if id.begins_with("stir") or id.begins_with("drop") else -14.0
		add_child(player)
		effects[id] = player
	for id in LID_LEVELS:
		var player := AudioStreamPlayer.new()
		player.volume_db = LID_LEVELS[id]
		add_child(player)
		effects[id] = player

func _stream(group: String, looping: bool = false) -> AudioStreamWAV:
	var variants: Array = banks.get(group, [])
	if variants.is_empty():
		push_error("Missing recorded audio bank: " + group)
		return null
	var previous := int(_last_variant.get(group, -1))
	var index := _rng.randi_range(0, variants.size() - 1)
	if variants.size() > 1 and index == previous: index = (index + 1) % variants.size()
	_last_variant[group] = index
	var sample := (_samples[variants[index]] as AudioStreamWAV).duplicate() as AudioStreamWAV
	if looping:
		sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sample.loop_begin = 0
		var bytes_per_frame := (2 if sample.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if sample.stereo else 1)
		sample.loop_end = sample.data.size() / bytes_per_frame
	return sample

func _composition_amount(state: Dictionary, ids: Array) -> float:
	var amount := 0.0
	var composition: Dictionary = state.get("composition_ml", {})
	for id in ids: amount += float(composition.get(id, 0.0))
	return amount

func cooking_profile(world: Node2D) -> String:
	# The same 80 ml boundary as the cooking model, not a separate audio rule.
	if world.pan.water_ml >= 80.0:
		return "boil" if world.reactions.water_activity()>0.08 else ""
	var oil := 0.0
	var sauce := 0.0
	var frying := 0.0
	var simmer := 0.0
	var wet_mass := 0.0
	var egg_mass := 0.0
	var meat_mass := 0.0
	var food_mass := 0.0
	for body in world._foods.get_children():
		if body.is_queued_for_deletion() or not body.get_meta("enrolled", false) or body.get_meta("plated", false) or body.get_meta("is_container", false): continue
		if not world.pan.contains(body.position): continue
		var reaction: Dictionary = world.reactions.activity(body)
		frying=maxf(frying,float(reaction.fry))
		simmer=maxf(simmer,float(reaction.sauce))
		var definition: Dictionary = body.get_meta("definition", {})
		var id := str(definition.get("id", ""))
		for state in [body.get_meta("liquid_state", {}), body.get_meta("surface_sauce", {})]:
			oil += _composition_amount(state, OILS)
			sauce += _composition_amount(state, SAUCES)
		if body.has_meta("liquid_state"): continue
		if stir_profile(definition) == "hard": continue
		food_mass += body.mass
		if id == "egg": egg_mass += body.mass
		elif stir_profile(definition) == "meat": meat_mass += body.mass
		elif stir_profile(definition) == "wet": wet_mass += body.mass
	# One thermal state drives both the visible bubbles and these CC0 recordings.
	# Residual heat continues after switching the burner off or moving the pan.
	if simmer>0.08: return "simmer_sauce"
	if frying<0.08: return ""
	if food_mass <= 0.001: return "" # Clean oil alone is not an automatic loud sizzle.
	if egg_mass > 0 and egg_mass >= maxf(meat_mass, wet_mass): return "fry_egg"
	if meat_mass > 0 and meat_mass >= wet_mass: return "fry_meat"
	if wet_mass > 0 or oil >= 1.0: return "fry_vegetable"
	return ""

func _dispense_bank(mode: String, ingredient_id: String) -> String:
	if mode == "pour" and ingredient_id in OILS: return "pour_oil"
	if mode == "powder" and ingredient_id == "pepper": return "powder_pepper"
	return mode

func update_kitchen(world: Node2D) -> void:
	var audible := not muted and focused
	var profile := cooking_profile(world)
	var dispensing := ""
	var ingredient_id := ""
	if world._squeezing and is_instance_valid(world._held) and float(world._held.get_meta("remaining_ml", 0.0)) > 0.001:
		dispensing = world.get_dispense_mode(world._held.get_meta("definition", {}))
		ingredient_id = str(world._held.get_meta("id", ""))
	var desired := {"runoff": world.pan.outflow_ml_s > 3.0 or world.pan.runoff.recent_rate > 5.0, "flame": world.cooking, "sizzle": profile.begins_with("fry_"), "sauce": profile == "simmer_sauce", "boil": profile == "boil", "water": world.pan.faucet_on, "squeeze": dispensing == "squeeze", "pour": dispensing == "pour", "powder": dispensing == "powder"}
	for id in loops:
		var player: AudioStreamPlayer = loops[id]
		var ui_active: bool = ui_dispense_mode == id and id in ["squeeze", "pour", "powder"]
		var active: bool = audible and ((world.controls_enabled and desired[id]) or ui_active)
		if not active:
			player.stop()
			continue
		var group: String = profile if id in ["sizzle", "sauce"] else ("water" if id == "runoff" else str(id))
		if id in ["squeeze", "pour", "powder"]:
			group = _dispense_bank(id, ui_dispense_id if ui_active else ingredient_id)
			var pressure: float = ui_pressure if ui_active else world.squeeze_pressure
			player.volume_db = LOOPS[id] + lerpf(-9.0, 0.0, pressure)
		elif id == "runoff": player.volume_db = LOOPS[id] + linear_to_db(clampf(maxf(world.pan.outflow_ml_s,world.pan.runoff.recent_rate)/280.0,0.02,1.0))
		elif id == "water": player.volume_db = LOOPS[id] + lerpf(-8.0, 0.0, world.pan.faucet_amount)
		elif id in ["sizzle", "sauce", "boil", "flame"]:
			if id=="flame": player.volume_db=LOOPS[id]
			elif id=="boil": player.volume_db=LOOPS[id]+lerpf(-14.0,0.0,world.reactions.water_activity())
			else:
				var strength := 0.0
				for food in world._foods.get_children():
					if food is RigidBody2D and not food.is_queued_for_deletion():
						var activity: Dictionary=world.reactions.activity(food)
						strength=maxf(strength,float(activity.sauce if id=="sauce" else activity.fry))
				player.volume_db=LOOPS[id]+lerpf(-12.0,0.0,strength)
		if not player.playing or loop_banks.get(id, "") != group:
			player.stream = _stream(group, true)
			loop_banks[id] = group
			player.play()

func active_loop_count() -> int:
	var count := 0
	for player in loops.values():
		if player.playing: count += 1
	return count

func play_effect(id: String, strength: float = 1.0) -> void:
	if muted or not focused or not effects.has(id): return
	var now := Time.get_ticks_msec()
	var cooldown := 180 if id.begins_with("stir") else (160 if id.begins_with("drop") else 85)
	if now - int(_last_effect.get(id, -1000)) < cooldown: return
	var player: AudioStreamPlayer = effects[id]
	if id.begins_with("stir") and player.playing: return
	if id == "lid_tick" and player.playing: return
	_last_effect[id] = now
	var group: String = "lid_land" if id == "lid_rebound" else (id if LID_LEVELS.has(id) else EFFECT_BANKS[id])
	player.stream = _stream(group)
	player.pitch_scale = _rng.randf_range(0.992, 1.008) if LID_LEVELS.has(id) else _rng.randf_range(0.985, 1.015)
	var level: float = LID_LEVELS.get(id, -19.0 if id.begins_with("stir") or id.begins_with("drop") else -14.0)
	player.volume_db = level + linear_to_db(clampf(strength, 0.05 if LID_LEVELS.has(id) else 0.2, 1.0))
	player.play()

func stir_profile(definition: Dictionary) -> String:
	var id := str(definition.get("id", ""))
	var category := str(definition.get("category", ""))
	var tags: Array = definition.get("tags", [])
	if category == "odd" or id in ["baseball_bat", "computer_mouse", "slipper", "rock", "spring", "building_block", "candle"]: return "hard"
	if "meat" in tags or "seafood" in tags or id in ["egg", "tofu", "sausage"]: return "meat"
	if "vegetable" in tags or "fresh" in tags or id in ["tomato", "mushroom", "fruit", "watermelon"]: return "wet"
	return "dry"

func play_food_stir(body: RigidBody2D, utensil_kind: String, travel: float = 20.0) -> void:
	if muted or not focused or not is_instance_valid(body): return
	var world = get_parent()
	if not world.controls_enabled or travel < 3.0: return
	var now := Time.get_ticks_msec()
	# One contact event for a whole sweep, not one restart per fragment.
	if now - int(_last_effect.get("stir_contact", -1000)) < 180: return
	_last_effect["stir_contact"] = now
	var profile := "stir_" + stir_profile(body.get_meta("definition", {}))
	if world.pan.water_ml >= 80.0: profile = "stir_water"
	elif body.has_meta("liquid_state") or float(body.get_meta("surface_sauce", {}).get("volume_ml", 0.0)) > 1.0: profile = "stir_sauce"
	elif str(body.get_meta("id", "")) == "noodles" and float(body.get_meta("softness", 0.0)) > 0.25: profile = "stir_pasta"
	var strength := clampf(travel / 35.0, 0.3, 1.0)
	play_effect(profile, strength)
	play_effect("stir_metal" if utensil_kind == "black" else "stir_wood", strength * 0.65)

func play_chop(definition: Dictionary) -> void:
	var id := str(definition.get("id", ""))
	var group := "chop"
	if id in ["tomato", "tofu", "cheese", "egg", "mushroom"] or "meat" in definition.get("tags", []): group = "chop_soft"
	elif id in ["pumpkin", "carrot", "potato", "onion"]: group = "chop_hard"
	play_effect(group)

func play_food_drop(body: RigidBody2D) -> void:
	if not is_instance_valid(body): return
	var p := preload("res://modules/restaurant/domain/material_response.gd").profile(body.get_meta("definition", {}))
	var speed := maxf(body.linear_velocity.length(), float(body.get("impact_speed")))
	# px/s converted to a relative energy proxy; recordings remain CC0 samples.
	var energy := 0.5 * body.mass * pow(speed / 100.0, 2.0)
	var bank := str(p.impact_bank)
	if body.get_meta("dispensed", false):
		bank = "drop_dry" if body.get_meta("dispense_mode", "") == "powder" else "drop"
	play_effect(bank, clampf(sqrt(energy) * 0.8, 0.2, 1.0))
	var world = get_parent()
	if world.pan.on_stove() and world.pan.contains(body.position) and world.reactions.pan_c >= 115.0 and world.pan.water_ml < 80.0 and not body.get_meta("is_container", false) and not body.has_meta("liquid_state"):
		var thermal: Dictionary = world.reactions.ensure_state(body)
		if float(thermal.get("water_kg", 0.0)) > 0.0005:
			play_effect("hot_drop", clampf(sqrt(energy), 0.35, 0.85))

func stop_all() -> void:
	for player in loops.values() + effects.values(): player.stop()

func _exit_tree() -> void:
	stop_all()
	for player in loops.values() + effects.values(): player.stream = null
	loops.clear()
	effects.clear()
	_samples.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		focused = false
		ui_dispense_mode = ""
		stop_all()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN: focused = true
