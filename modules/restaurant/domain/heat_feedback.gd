extends RefCounted
## Read-only cooking advice. Temperature bands are game guidance, never triggers
## for combustion, lid impulses or food readiness: those remain in the simulation.
const Thermal = preload("res://modules/restaurant/domain/food_thermal.gd")

static func evaluate(items: Array, catalog: Array, vessel: Dictionary, recipe: Dictionary = {}) -> Dictionary:
	var definitions := {}
	for d in catalog: definitions[str(d.id)] = d
	var result := {"title":"锅里还空着", "advice":"先切好食材，再热锅。", "low":120.0, "high":175.0, "temperature":float(vessel.get("pan_c",22)), "method":"热锅", "risk":"", "severity":0, "ready":false}
	var wet := float(vessel.get("water_ml",0)) >= 80
	var names: Array[String] = []
	var melting := false
	var needs_heat := false
	var burned := false
	var changing := false
	var noodles := false
	var egg_white := -1.0
	var egg_yolk := 0.0
	var edible_count := 0
	var ready_count := 0
	var recipe_heat := 0.0
	var target_ids := {}
	for item in recipe.get("dish",{}).get("ingredients",[]):
		if item is Dictionary:
			recipe_heat = maxf(recipe_heat,float(item.get("heat",0)))
			var target_id := str(item.get("id",""))
			target_ids[target_id] = maxf(float(target_ids.get(target_id,0)),float(item.get("heat",0)))
	for item in items:
		var id := str(item.get("id",""))
		var d: Dictionary = definitions.get(id,{"id":id,"name":id})
		if d.get("category","") == "seasoning": continue
		if not names.has(str(d.get("name",id))): names.append(str(d.get("name",id)))
		var profile: Dictionary = Thermal.profile(d)
		if not profile.edible: continue
		edible_count += 1
		var state: Dictionary = item.get("thermal",{})
		if id == "egg" and bool(state.get("egg_opened",false)):
			egg_white = float(state.get("egg_white_set",0))
			egg_yolk = float(state.get("egg_yolk_set",0))
		var heat := float(item.get("heat",0))
		var charred := maxf(float(state.get("char",[0,0])[0]),float(state.get("char",[0,0])[1]))
		burned = burned or charred > 0.03 or heat > 14
		if float(profile.melt_c)>0:
			melting = true
			var fraction := float(state.get("converted_kg",0))/maxf(0.000001,float(state.get("initial_kg",1)))
			changing = changing or fraction > 0.02
			if fraction >= 0.35: ready_count += 1
			else: needs_heat = true
		elif id == "noodles":
			noodles = true
			if float(item.get("softness",state.get("softness",0))) >= 0.7: ready_count += 1
			else: needs_heat = true
		elif bool(d.get("needs_cook",false)):
			if float(state.get("cooked",clampf(heat/6,0,1)))>=0.99: ready_count += 1
			else: needs_heat = true
		else: ready_count += 1
		# Follow the saved dish's actual result when a recipe is selected. A cold
		# tomato must not count as the cooked tomato in a replayed soup recipe.
		if target_ids.has(id) and float(target_ids[id]) >= 0.5 and heat < minf(float(target_ids[id]),6.0)-0.2: needs_heat = true
	if wet or float(recipe.get("dish",{}).get("water_ml",0)) >= 80:
		result.merge({"low":90.0,"high":125.0,"method":"小火煮","advice":"煮开后转小火，留意水量。"},true)
	elif melting:
		result.merge({"low":65.0,"high":115.0,"method":"小火慢化","advice":"开小火，轻轻翻动；化开后就关火。"},true)
	elif noodles:
		result.merge({"low":90.0,"high":125.0,"method":"加水煮","advice":"先接水，再煮面；干烧不会把面煮软。"},true)
	elif not recipe.is_empty() and recipe_heat < 0.5:
		result.merge({"low":22.0,"high":40.0,"method":"不用加热","advice":"这页菜谱是凉菜，拌好就能装盘。"},true)
	else:
		result.method = "中火翻炒"
		result.advice = "开中火，翻动受热；变色后减火。"
		if recipe_heat > 6: result.high = 190.0
	if not names.is_empty():
		var state_name := "冷着，可直接吃"
		if edible_count == 0: state_name = "试试会发生什么"
		elif burned: state_name = "开始焦了"
		elif melting: state_name = "还没化开" if not changing else ("正在化开" if needs_heat else "已经化开")
		elif noodles: state_name = "还硬着" if needs_heat else "面条软了"
		elif egg_white >= 0:
			state_name = "蛋白还透明" if egg_white < 0.2 else ("蛋白正在凝固" if egg_white < 0.95 else ("蛋白凝固了，蛋黄还软" if egg_yolk < 0.8 else "蛋黄也凝固了"))
		elif needs_heat: state_name = "里面还没熟"
		elif float(vessel.get("pan_c",22)) > 60: state_name = "熟了，先关火"
		result.title = "、".join(names.slice(0,2)) + ("等" if names.size()>2 else "") + " · " + state_name
		result.ready = edible_count > 0 and ready_count == edible_count and not needs_heat and not burned
		if result.ready and melting: result.advice = "已经化开，关火后装盘；再烧容易粘底。"
		if egg_white >= 0 and not wet: result.advice = "中火煎，蛋白变白后减小火；留意边缘，别煎焦。"
	elif bool(vessel.get("heating",false)): result.title = "正在热锅"
	if float(result.temperature) > float(result.high)+15 and bool(vessel.get("heating",false)):
		result.risk = "锅太热了，减小火。" if wet else "锅太热了，继续烧容易焦。"
		result.severity = 1
	if burned:
		result.risk = "有焦边了，先关火、翻面。"
		result.severity = 2
	if bool(vessel.get("covered",false)) and float(vessel.get("lid_hot_seconds",0)) > float(vessel.get("lid_pop_seconds",8))*0.6:
		result.risk = "锅盖在积汽，继续大火会顶开；减火或揭盖。"
		result.severity = 2
	if float(vessel.get("oil_ml",0)) > 8 and float(result.temperature)>225 and not wet:
		result.risk = "油温太高，继续烧会起火；先关火。"
		result.severity = 2
	if float(vessel.get("fire",0))>0.15:
		result.risk = "着火了，关火、盖上锅盖。别往热油里倒水。"
		result.severity = 3
	if bool(vessel.get("power_out",false)):
		result.risk = "跳闸了，先关水，等积水退下去。"
		result.severity = 3
	if not str(result.risk).is_empty(): result.advice = result.risk
	return result
