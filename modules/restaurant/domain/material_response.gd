extends RefCounted
## Calibrated game profiles, NOT measured food-science constants.
## Godot owns rigid contact/CCD; these configure contact and the auxiliary support plane.
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/data/material_response.json"))

static func profile(definition: Dictionary) -> Dictionary:
	var item: Dictionary = data.items.get(str(definition.get("id", "")), {"family":"soft_produce"})
	var result: Dictionary = data.families[item.family].duplicate(true)
	result.merge(item, true)
	return result

static func effective(body: RigidBody2D) -> Dictionary:
	var p := profile(body.get_meta("definition", {}))
	var heat := clampf(float(body.get_meta("cooking_heat", body.get_meta("saved_heat", 0.0))) / 32.0, 0.0, 1.0)
	var soft := maxf(float(body.get_meta("softness", 0.0)), heat * float(p.get("heat_softening", 0.0)))
	var cut := bool(body.get_meta("cut", false))
	# Round whole produce rolls; a cut flat face, softened food and containers
	# settle by sliding friction instead. This controls the 2D board plane only.
	p["rolling"] = str(body.get_meta("id", "")) in ["tomato","potato","onion","apple","lemon","orange","egg","pumpkin","watermelon"] and not cut and not body.get_meta("is_container",false) and soft<0.35
	var coating: Dictionary = body.get_meta("surface_sauce", {})
	var composition: Dictionary = coating.get("composition_ml", {})
	var oil := float(composition.get("oil", 0.0)) + float(composition.get("sesame_oil", 0.0))
	var lubrication := clampf(oil / 3.0, 0.0, 0.7)
	p.friction = clampf(float(p.friction) * (1.0 - lubrication) * (1.18 if cut else 1.0), 0.05, 1.0)
	p.bounce = float(p.bounce) * (1.0 - soft * 0.8) * (0.55 if cut else 1.0)
	p.compliance = clampf(float(p.compliance) + soft * 0.1, 0.0, 0.25)
	p.angular_damp = float(p.angular_damp) * (1.5 if cut else 1.0) * (1.0 + soft)
	p.linear_damp = float(p.linear_damp) * (1.0 + soft * 0.5)
	if body.has_meta("thermal"):
		var state: Dictionary=body.get_meta("thermal")
		var melted := clampf(float(state.get("liquid_kg",0.0))/maxf(body.mass,0.000001),0.0,1.0)
		p.bounce*=1.0-melted
		p.linear_damp=lerpf(float(p.linear_damp),14.0,melted)
		p.angular_damp=lerpf(float(p.angular_damp),18.0,melted)
		# A spreading phase creeps and damps rotation; it cannot bounce like its block.
	return p

static func container_mass(definition: Dictionary, remaining_ml: float) -> float:
	var p := profile(definition)
	return float(p.get("tare_kg", 0.05)) + maxf(0.0, remaining_ml) * float(definition.get("density_g_ml", 1.03)) / 1000.0

static func flow_rate(definition: Dictionary, pressure: float, remaining_ml: float) -> float:
	var capacity := maxf(1.0, float(definition.get("container_ml", 240.0)))
	var fill := clampf(remaining_ml / capacity, 0.0, 1.0)
	if fill <= 0.0: return 0.0
	var mode := str(definition.get("dispense_mode", ""))
	var viscosity := float(definition.get("viscosity", 0.3))
	var drive := clampf(pressure, 0.0, 1.0)
	if mode == "squeeze": drive = maxf(0.0, drive - viscosity * 0.13) / (1.0 - viscosity * 0.13)
	var head := lerpf(0.22, 1.0, sqrt(fill)) if mode == "pour" else lerpf(0.6, 1.0, fill)
	return float(definition.get("flow_ml_s", 18.0)) * drive * head

static func utensil_impulse(body: RigidBody2D, desired_velocity: Vector2, spoon: bool) -> Vector2:
	# Finite utensil effective mass: a heavy whole pumpkin no longer receives
	# the same velocity change as a tiny slice. Limit only for numerical safety.
	var tool_mass := 0.12 if spoon else 0.24
	var reduced_mass := body.mass * tool_mass / (body.mass + tool_mass)
	return ((desired_velocity - body.linear_velocity) * reduced_mass * 1.6).limit_length(65.0)
