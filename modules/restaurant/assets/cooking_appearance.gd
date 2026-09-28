extends RefCounted
## Shared visual interpretation of the same dose used by dish evaluation.
## Heat is accumulated cooking dose in game seconds, not degrees Celsius.
static func state(definition: Dictionary, heat: float) -> Dictionary:
	var id := str(definition.get("id", ""))
	var tags: Array = definition.get("tags", [])
	var profile := 0
	if id in ["chicken", "pork", "beef", "sausage", "shrimp", "squid"] or "meat" in tags:
		profile = 1
	elif id in ["lettuce", "spinach", "cabbage", "broccoli", "seaweed"]:
		profile = 2
	return {"cooked": clampf(heat / 6.0, 0, 1), "browned": clampf((heat - 7.0) / 7.0, 0, 1), "charred": clampf((heat - 14.0) / 16.0, 0, 1), "food_profile": profile}

static func edge_color(definition: Dictionary, heat: float) -> Color:
	var result := Color(str(definition.get("color", "d9b18c"))).lightened(0.28)
	var appearance := state(definition, heat)
	if appearance.food_profile == 1:
		result = result.lerp(Color("d3b28a"), appearance.cooked)
	return result.lerp(Color("9e6335"), appearance.browned * 0.65).lerp(Color("30251c"), appearance.charred)

static func surface(definition: Dictionary,heat: float,thermal: Dictionary,coating: Dictionary) -> Dictionary:
	var result := state(definition,heat)
	if not thermal.is_empty():
		var face := 1-int(thermal.get("contact_face",0))
		result.cooked=float(thermal.get("cooked",0.0))
		result.browned=float(thermal.get("brown",[0.0,0.0])[face])
		result.charred=float(thermal.get("char",[0.0,0.0])[face])
		# A low-angle view also catches a little of the contact edge.
		result.browned=maxf(result.browned,float(thermal.get("brown",[0.0,0.0])[1-face])*0.2)
		result.charred=maxf(result.charred,float(thermal.get("char",[0.0,0.0])[1-face])*0.2)
	var mix: Dictionary = coating.get("composition_ml",{})
	var pigments := {"ketchup":Color("bf3924"),"chili_sauce":Color("bd472c"),"soy_sauce":Color("693b1e"),"mustard":Color("a3a138"),"mayonnaise":Color("f2dfac"),"cheese":Color("efd28a"),"blue_cheese":Color("dbd4a1"),"chocolate":Color("533223"),"tomato":Color("ce5034"),"honey":Color("b88624")}
	var color := Color(0,0,0,1)
	var weight := 0.0
	for id in pigments:
		var amount := float(mix.get(id,0.0))
		color.r+=pigments[id].r*amount; color.g+=pigments[id].g*amount; color.b+=pigments[id].b*amount
		weight+=amount
	if weight>0: color=Color(color.r/weight,color.g/weight,color.b/weight,1)
	var origin: Array = coating.get("origin",[0.5,0.35])
	result.merge({"film_color":color,"film_amount":clampf(weight/4.0,0.0,1.0),"film_spread":float(coating.get("spread",0.0)),"film_origin":Vector2(origin[0],origin[1]),"film_thin":float(mix.get("soy_sauce",0.0))/maxf(weight,0.001),"oil_gloss":clampf((float(mix.get("oil",0.0))+float(mix.get("sesame_oil",0.0))+float(mix.get("butter",0.0)))/4.0,0.0,1.0),"pepper_amount":clampf(float(mix.get("pepper",0.0))/1.5,0.0,1.0),"salt_amount":clampf(float(mix.get("salt",0.0))/2.0,0.0,1.0)},true)
	return result
