extends RefCounted



const MAX_MIX_COMPONENTS: = 8

static func make_batch(definition: Dictionary, volume_ml: float, source_id: String, pressure: float) -> Dictionary:
	var id: = str(definition.get("id", "sauce"))
	var amount: = maxf(0.0, volume_ml)
	return {
		"volume_ml": amount,
		"composition_ml": {id: amount},
		"source_id": source_id,
		"viscosity": clampf(float(definition.get("viscosity", 0.68 if definition.get("dispense_mode", "") == "squeeze" else 0.32)), 0.05, 1.0),
		"mixedness": 0.0,
		"layered": false,
		"pressure": clampf(pressure, 0.0, 1.0),
		"colour_model": "weighted_srgb_visual_approximation"
	}

static func transfer(source: Dictionary, destination: Dictionary, requested_ml: float) -> float:
	var available: = maxf(0.0, float(source.get("volume_ml", 0.0)))
	var moved: = minf(maxf(0.0, requested_ml), available)
	if moved <= 0.0:
		return 0.0
	var ratio: = moved / available
	var source_mix: Dictionary = source.get("composition_ml", {})
	var destination_mix: Dictionary = destination.get("composition_ml", {})
	for id in source_mix:
		var component: = float(source_mix[id]) * ratio
		source_mix[id] = maxf(0.0, float(source_mix[id]) - component)
		destination_mix[id] = float(destination_mix.get(id, 0.0)) + component
	source["composition_ml"] = source_mix
	destination["composition_ml"] = destination_mix
	source["volume_ml"] = available - moved
	destination["volume_ml"] = float(destination.get("volume_ml", 0.0)) + moved
	return moved

static func agitate(state: Dictionary, energy: float) -> void :
	var component_count: int = (state.get("composition_ml", {}) as Dictionary).size()
	if component_count <= 1:
		state["mixedness"] = 0.0
		state["layered"] = false
		return
	state["mixedness"] = clampf(float(state.get("mixedness", 0.0)) + maxf(0.0, energy), 0.0, 1.0)
	state["layered"] = float(state.mixedness) < 0.32

static func merge_into(target: Dictionary, incoming: Dictionary, agitation: float = 0.0) -> float:
	var before := float(target.get("volume_ml", 0.0))
	var moved: = transfer(incoming, target, float(incoming.get("volume_ml", 0.0)))
	if moved > 0.0:
		var v0: = float(target.get("viscosity", 0.5))
		var v1: = float(incoming.get("viscosity", v0))
		target["viscosity"] = clampf((v0 * before + v1 * moved) / (before + moved), 0.05, 1.0)
		target["layered"] = target.get("composition_ml", {}).size() > 1 and (absf(v0 - v1) > 0.22 or agitation < 0.12)
		agitate(target, agitation)
	return moved

static func total_components(state: Dictionary) -> float:
	var total: = 0.0
	for value in state.get("composition_ml", {}).values():
		total += float(value)
	return total
