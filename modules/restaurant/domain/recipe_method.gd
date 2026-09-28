extends RefCounted
## Read-only recipe interpretation. Never mutates food, stock, heat or recipe data.
## Old saves have final states, not action chronology; these are reconstruction hints.
static func starter() -> Dictionary:
	return {"id": "kitchen_tomato_noodles", "title": "番茄清汤面", "author": "100饭店 · 厨房示范", "reference": true,
		"notes": "番茄切开，面条在沸水中慢慢散开。关火后装进汤碗，从锅里盛入热汤。", "dish": {"water_ml": 250.0,
		"ingredients": [{"id":"tomato", "cut":true, "heat":6.0}, {"id":"noodles", "heat":6.0, "softness":0.8}]}}

static func targets(record: Dictionary) -> Array:
	var grouped: Dictionary = {}
	for value in record.get("dish", {}).get("ingredients", []):
		var item: Dictionary = {"id":value} if value is String else value
		var id := str(item.get("id", item.get("ingredient_id", "")))
		if id.is_empty(): continue
		var key := id + ("_garnish" if item.get("garnish", false) else "_cooked")
		if not grouped.has(key): grouped[key] = {"id":id, "cut":false, "heat":0.0, "softness":0.0, "mass_kg":0.0, "volume_ml":0.0, "garnish":false}
		var target: Dictionary = grouped[key]
		target.cut = target.cut or bool(item.get("cut", false))
		target.heat = maxf(target.heat, float(item.get("heat", 0)))
		target.softness = maxf(target.softness, float(item.get("softness", 0)))
		target.mass_kg += float(item.get("mass_kg", 0))
		target.volume_ml += float(item.get("volume_ml", item.get("amount_ml", 0)))
		target.garnish = target.garnish or bool(item.get("garnish", false))
	return grouped.values()

static func name_of(id: String, catalog: Array) -> String:
	for definition in catalog:
		if definition.get("id", "") == id: return str(definition.get("name", id))
	return id

static func steps(record: Dictionary, catalog: Array) -> Array:
	var materials := targets(record)
	if materials.is_empty(): return []
	var result: Array = []
	for item in materials:
		if item.garnish: continue
		var title := name_of(item.id, catalog)
		var source := "从食材柜取出，放到台面。"
		for definition in catalog:
			if str(definition.get("id", "")) == item.id and str(definition.get("category", "")) == "seasoning":
				source = "从锅后的调料架取出，瓶身留在手中。"
				break
		result.append({"kind":"take", "target":item, "title":"取出" + title, "detail":source, "art":"raw"})
		if item.cut:
			result.append({"kind":"cut", "target":item, "title":"切开" + title, "detail":"放在右侧菜板，握住刀柄，让刀刃划过食材。", "art":"cut"})
	var water := clampf(float(record.get("dish", {}).get("water_ml", 0)), 0, 1500)
	if water >= 80:
		result.append({"kind":"water", "amount":water, "title":"给锅接水", "detail":"把锅口移到水流下，转动下方把手；接约 %d ml 后关水，锅放回炉灶。" % roundi(water), "art":"water"})
	for item in materials:
		if item.garnish: continue
		var title := name_of(item.id, catalog)
		var quantity := ""
		if item.volume_ml > 0: quantity = "约 %d ml" % roundi(item.volume_ml)
		elif item.mass_kg > 0: quantity = "约 %d g" % roundi(item.mass_kg * 1000)
		var instruction := "把食材拖进锅口，松手后等它落稳。"
		if item.cut: instruction = "逐片拿起下锅，也可以用锅铲收拢。"
		if item.volume_ml > 0: instruction = "瓶口对准锅内，持续按住出料，达到用量后松开。"
		result.append({"kind":"pan", "target":item, "title":title + "下锅", "detail":instruction + quantity, "art":"pan"})
	for item in materials:
		if item.garnish or (item.heat < 0.5 and item.softness < 0.1): continue
		var title := name_of(item.id, catalog)
		var state := "熟透" if item.heat >= 6 else "稍稍加热"
		if item.heat > 14: state = "形成焦色（原菜的火候）"
		var detail := "锅放在炉灶上，开中火；留意变色，不要烧焦。全部食材做好后再关火。"
		if item.softness > 0.1: detail = "把水烧开，保持水量；等面条吸水、散开变软。"
		result.append({"kind":"cook", "target":item, "title":title + " · " + state, "detail":detail, "art":"cook"})
	result.append({"kind":"plate", "title":"关火，慢慢装盘", "detail":"点击盘子打开摆盘，选择汤碗，把做好的食材和锅里的热汤实际盛进去。" if water >= 80 else "点击盘子打开摆盘，把做好的食材装进去；拍下这一餐，也可以直接出餐。", "art":"plate", "water_ml":water})
	for item in materials:
		if item.garnish:
			result.append({"kind":"garnish", "target":item, "title":"淋上" + name_of(item.id, catalog), "detail":"在摆盘页选择对应的酱，按住鼠标淋到盘里。", "art":"plate"})
	return result

static func enough(items: Array, target: Dictionary, kind: String) -> bool:
	var candidates: Array = []
	for item in items:
		if str(item.get("id", "")) != target.id: continue
		if kind == "cut" and not item.get("cut", false): continue
		if kind in ["pan", "cook", "plate"] and not item.get("enrolled", false): continue
		if kind == "pan" and item.get("plated", false): continue
		if kind == "plate" and not item.get("plated", false): continue
		if kind != "take" and item.get("is_container", false): continue
		if kind in ["cook", "plate"]:
			var heat := float(item.get("heat", 0))
			var target_heat := float(target.get("heat", 0))
			if heat < (maxf(6, target_heat - 1.0) if target_heat >= 6 else maxf(0, target_heat - 0.2)): continue
			# Burning a normal recipe is a visible mistake, never a completed target.
			if target_heat <= 14 and heat > 14: continue
			if float(item.get("softness", 0)) < maxf(0, float(target.get("softness", 0)) - 0.1): continue
			if target.get("cut", false) and not item.get("cut", false): continue
		candidates.append(item)
	if candidates.is_empty(): return false
	if kind == "take": return true
	var mass := 0.0
	var volume := 0.0
	for item in candidates:
		mass += float(item.get("mass_kg", 0))
		volume += float(item.get("volume_ml", item.get("amount_ml", 0)))
	# A generous replay tolerance; never count one tiny fragment as an entire dish.
	if float(target.get("volume_ml", 0)) > 0: return volume >= target.volume_ml * 0.65
	if float(target.get("mass_kg", 0)) > 0: return mass >= target.mass_kg * 0.65
	return true

static func satisfied(step: Dictionary, snapshot: Dictionary, materials: Array) -> bool:
	match step.kind:
		"water": return float(snapshot.get("water_ml", 0)) >= float(step.amount) * 0.8
		"plate":
			if snapshot.get("heating", false): return false
			if float(step.get("water_ml", 0.0)) >= 80.0 and float(snapshot.get("plated_water_ml", 0.0)) < float(step.water_ml) * 0.8: return false
			for item in materials:
				if not item.garnish and not enough(snapshot.get("foods", []), item, "plate"): return false
			return true
		"garnish": return enough(snapshot.get("garnishes", []), step.target, "garnish")
		_: return enough(snapshot.get("foods", []), step.target, step.kind)

var record: Dictionary = {}
var sequence: Array = []
var completed: Dictionary = {}
var index := 0
var active := false

func start(value: Dictionary, catalog: Array) -> void:
	record = value.duplicate(true)
	sequence = steps(record, catalog)
	completed.clear()
	index = 0
	active = not sequence.is_empty()

func update(snapshot: Dictionary) -> void:
	if not active: return
	var materials := targets(record)
	# Observe successful actions even if the player performs them in a different order.
	# Plating always revalidates the present food, quantity, cut and heat state.
	for i in range(sequence.size()):
		if sequence[i].kind in ["plate", "garnish"]:
			completed[i] = satisfied(sequence[i], snapshot, materials)
		elif not completed.get(i, false):
			completed[i] = satisfied(sequence[i], snapshot, materials)
	index = 0
	while index < sequence.size() and completed.get(index, false): index += 1

func reset() -> void:
	completed.clear()
	index = 0
