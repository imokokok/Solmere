extends RefCounted
## Finite flavor residue in kilograms. Food -> pan -> cloth/drain or next food.
var components: Dictionary = {}
var waste_kg := 0.0

func total_kg() -> float:
	var total := 0.0
	for value in components.values(): total += float(value.mass_kg)
	return total

func deposit(body: RigidBody2D) -> float:
	if float(body.get_meta("cooking_heat", body.get_meta("saved_heat", 0.0))) < 1.0: return 0.0
	if body.get_meta("residue_deposited", false): return 0.0
	var amount := minf(body.mass * 0.006, 0.0006)
	if amount <= 0.000001: return 0.0
	var definition: Dictionary = body.get_meta("definition", {})
	var id := str(body.get_meta("id", ""))
	if not components.has(id):
		components[id] = {"mass_kg":0.0, "title":str(definition.get("name", id)), "tags":definition.get("tags", []).duplicate(), "color":str(definition.get("color", "885333"))}
	components[id].mass_kg += amount
	var ratio := amount / body.mass
	body.mass -= amount
	var film: Dictionary = body.get_meta("surface_sauce",{})
	var film_mass := float(film.get("mass_kg",0.0))
	if not film.is_empty():
		film["volume_ml"]=float(film.get("volume_ml",0.0))*(1.0-ratio)
		film["mass_kg"]=film_mass*(1.0-ratio)
		for key in film.get("composition_ml",{}): film.composition_ml[key]*=1.0-ratio
		body.set_meta("surface_sauce",film)
	if body.has_meta("thermal"):
		var state: Dictionary=body.get_meta("thermal")
		state["residue_exported_kg"]=float(state.get("residue_exported_kg",0.0))+maxf(0.0,amount-film_mass*ratio)
		state.water_kg*=1.0-ratio
		state.liquid_kg*=1.0-ratio
	if body.has_meta("liquid_state"):
		var liquid: Dictionary = body.get_meta("liquid_state")
		liquid.volume_ml *= 1.0 - ratio
		for key in liquid.get("composition_ml", {}): liquid.composition_ml[key] *= 1.0 - ratio
	# Trace substances are part of body mass; transfer their proportional share too.
	var traces: Dictionary = body.get_meta("pan_carryover", {})
	for key in traces:
		var moved: float = float(traces[key].mass_kg) * ratio
		traces[key].mass_kg -= moved
		components[id].mass_kg -= moved
		if not components.has(key):
			components[key] = traces[key].duplicate(true)
			components[key].mass_kg = 0.0
		components[key].mass_kg += moved
	body.set_meta("pan_carryover", traces)
	body.set_meta("residue_deposited", true)
	return amount

func transfer_to_food(body: RigidBody2D) -> float:
	var total := total_kg()
	if total <= 0.000001: return 0.0
	var ratio := minf(total * 0.5, 0.0015) / total
	var traces: Dictionary = body.get_meta("pan_carryover", {}).duplicate(true)
	var moved := 0.0
	for id in components:
		var amount: float = components[id].mass_kg * ratio
		if not traces.has(id):
			traces[id] = components[id].duplicate(true)
			traces[id].mass_kg = 0.0
		traces[id].mass_kg += amount
		components[id].mass_kg -= amount
		moved += amount
	body.mass += moved
	body.set_meta("pan_carryover", traces)
	return moved

func wipe(amount_kg: float) -> float:
	var total := total_kg()
	if total <= 0.0: return 0.0
	var moved := clampf(amount_kg, 0.0, total)
	for id in components.keys():
		components[id].mass_kg *= 1.0 - moved / total
		if components[id].mass_kg < 0.00000001: components.erase(id)
	return moved
