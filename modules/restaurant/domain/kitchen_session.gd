extends RefCounted



const INGREDIENT_PATH: = "res://modules/restaurant/data/ingredients.json"
const CUSTOMER_PATH: = "res://modules/restaurant/data/customers.json"
const CAPACITY: = 6
const PHYSICAL_PIECE_CAPACITY := 48
const COOKED_AT: = 6.0
const BURNT_AFTER: = 14.0
const DEFAULT_CUSTOMER_WAIT: = 120.0
const MIN_CUSTOMER_WAIT: = 120.0
const MAX_CUSTOMER_WAIT: = 120.0
const BLOCKED_INGREDIENT_IDS: = ["fish", "salmon", "rice"]

var ingredients: Array = []
var customers: Array = []
var dish: Array = []
var elapsed: float = 0.0
var duration: float = 720.0
var phase: String = "prep"
var revenue: float = 0.0
var served: int = 0
var missed: int = 0
var current_customer: Dictionary = {}
var customer_wait: float = 0.0
var player_share: float = 0.3
var poster_bonus: bool = false
var heating: bool = false
var heat_contact: bool = true
var water_ml: float = 0.0
var water_heat: float = 0.0
var garnishes: Array = []
var plating_waste_ml: float = 0.0
var presentation: Dictionary = {}
const HEAT_RATES: = {"low": 0.55, "medium": 1.0, "high": 1.65}
var heat_level: = "medium"
var last_notice: String = "先认识食材，再开始今天的营业。"

var payment_rng: = RandomNumberGenerator.new()
var _catalog: Dictionary = {}
var _queue: Array = []
var _visited: Dictionary = {}
var _poster_tags: Array = []
var _arrival_delay: float = 0.0
var _settlement: Dictionary = {}
var served_meals: Array = []
var _menu_recipes: Array = []
var _talk_turn: = 0
var _custom_customer_profiles := false

func setup() -> void :
	payment_rng.randomize()
	ingredients = _read_array(INGREDIENT_PATH)
	customers = _read_array(CUSTOMER_PATH)
	_custom_customer_profiles = false
	_catalog.clear()
	for ingredient in ingredients:
		_catalog[str(ingredient.get("id", ""))] = ingredient
	dish.clear()
	garnishes.clear()
	plating_waste_ml = 0.0
	presentation.clear()
	elapsed = 0.0
	phase = "prep"
	revenue = 0.0
	served = 0
	missed = 0
	current_customer = {}
	customer_wait = 0.0
	heating = false
	heat_contact = true
	water_ml = 0
	water_heat = 0
	heat_level = "medium"
	poster_bonus = false
	_poster_tags.clear()
	_visited.clear()
	_queue.clear()
	_settlement.clear()
	served_meals.clear()
	_arrival_delay = 0.0
	last_notice = "先认识食材，再开始今天的营业。"
	_rebuild_queue()

func start_shift() -> void :
	if phase != "prep":
		return
	_rebuild_queue()
	phase = "service"
	elapsed = 0.0
	last_notice = "开始营业！先和客人聊聊，再自由搭配一道菜。"
	_arrive()

func set_customers(profiles: Array) -> void :


	if phase != "prep":
		return
	customers = profiles.duplicate(true)
	_custom_customer_profiles = true
	_rebuild_queue()

func active_ingredients() -> Array:
	var result: Array = []
	for ingredient in ingredients:
		if str(ingredient.get("id", "")) not in BLOCKED_INGREDIENT_IDS and bool(ingredient.get("available", true)):
			result.append(ingredient)
	return result

func set_menu_recipes(records: Array) -> void :
	_menu_recipes.clear()
	for record in records:
		if not record is Dictionary or not record.get("dish", {}).get("ingredients", []) is Array or record.dish.ingredients.is_empty():
			continue
		var contains_fish: = false
		for item in record.dish.ingredients:
			var ingredient_id: = str(item.get("id", "") if item is Dictionary else item)
			if ingredient_id in BLOCKED_INGREDIENT_IDS:
				contains_fish = true
				break
		if not contains_fish:
			_menu_recipes.append(record.duplicate(true))

func tick(delta: float) -> void :
	if phase == "closed" or delta <= 0.0:
		return

	var step: float = delta
	if phase == "service":
		step = minf(delta, maxf(0.0, duration - elapsed))
	if heating and heat_contact:
		for item in dish:
			if item.has("thermal"): continue # Physical world owns continuous thermal state.
			if item.get("off_heat", false): continue
			var heat_gain: = step * float(HEAT_RATES[heat_level])

			if water_ml >= 80.0:
				# A shared water bath is an explicit 2D approximation. Cold water
				# cannot cook food; wet cooking does not create dry-pan browning.
				heat_gain *= 0.45 * clampf((water_heat - 60.0) / 40.0, 0, 1)
				var prior := float(item.get("heat", 0.0))
				# Adding water must never erase an already burnt surface.
				item["heat"] = maxf(prior, minf(7.0, prior + heat_gain))
			else:
				item["heat"] = minf(60.0, float(item.get("heat", 0.0)) + heat_gain)

	if water_ml >= 80.0 and water_heat >= 85.0:
		var boil_factor: = inverse_lerp(85.0, 100.0, minf(water_heat, 100.0))
		for item in dish:
			if item.has("thermal"): continue # Hydration debits actual pan water in the world.
			if str(item.get("id", "")) != "noodles" or item.get("off_heat", false): continue
			var hydration: = clampf(float(item.get("hydration", 0.0)) + step * 0.11 * boil_factor, 0.0, 1.0)
			item["hydration"] = hydration
			item["softness"] = smoothstep(0.08, 0.88, hydration)
	if phase != "service":
		return
	elapsed += step
	if not current_customer.is_empty():
		customer_wait = maxf(0.0, customer_wait - step)
		if customer_wait <= 0.0:
			last_notice = "%s：%s" % [str(current_customer.get("name", "客人")), str(current_customer.get("leave_quote", "等得有点久，我先走了。"))]
			missed += 1
			current_customer = {}
			_arrival_delay = 2.0
	else:
		_arrival_delay = maxf(0.0, _arrival_delay - step)
		if _arrival_delay <= 0.0 and elapsed < duration:
			_arrive()
	if elapsed >= duration:
		end_shift()

func add_ingredient(id: String, physical_state: Dictionary = {}) -> bool:
	if phase == "closed":
		last_notice = "本班次已结束。"
		return false
	if not _catalog.has(id):
		last_notice = "找不到这种食材。"
		return false
	if dish.size() >= PHYSICAL_PIECE_CAPACITY:
		last_notice = "锅里已经没有容纳更多切块的空间了。"
		return false
	var incoming_batch := str(physical_state.get("batch_uid", physical_state.get("instance_uid", "")))
	var known_batches: Dictionary = {}
	for index in dish.size():
		var item: Dictionary = dish[index]
		if item.has("liquid_state"): continue
		var batch := str(item.get("batch_uid", item.get("instance_uid", "entry_%d" % index)))
		known_batches[batch] = true
	# One ingredient may become many physical pieces.  Capacity limits distinct
	# source ingredients, not the number of cuts made by the player.
	if not physical_state.has("liquid_state") and ((incoming_batch.is_empty() and known_batches.size() >= CAPACITY) or (not incoming_batch.is_empty() and not known_batches.has(incoming_batch) and known_batches.size() >= CAPACITY)):
		last_notice = "料理最多容纳 6 份食材，先出餐或清空吧。"
		return false
	var entry: = {"id": id, "cut": false, "heat": 0.0}
	entry.merge(physical_state, true)
	dish.append(entry)
	last_notice = "加入了%s。" % str(_catalog[id].get("name", id))
	return true

func chop() -> bool:
	if phase == "closed" or dish.is_empty():
		last_notice = "先放入食材，才能切配。"
		return false
	var changed: bool = false
	for item in dish:
		if not bool(item.get("cut", false)):
			item["cut"] = true
			changed = true
	last_notice = "切配完成，摆盘会更整齐。" if changed else "这些食材已经切配过了。"
	return changed

func set_heating(enabled: bool) -> void :
	if phase == "closed":
		heating = false
		return
	if enabled and dish.is_empty() and water_ml <= 0:
		heating = false
		last_notice = "锅里还是空的，先加点食材。"
		return
	heating = enabled
	last_notice = "正在加热：注意食材熟度；火力越大，熟得越快，也越容易焦。" if heating else "已经关火，可以装盘出餐。"

func set_heat_level(level: String) -> bool:
	if phase == "closed" or not HEAT_RATES.has(level): return false
	heat_level = level
	return true

func plate() -> Dictionary:
	var tags: Array = []
	var carryover: Dictionary = {}
	var unique: Dictionary = {}
	var quality_sum: float = 0.0
	var weird_sum: float = 0.0
	var burnt: bool = false
	var raw_count: int = 0
	var cut_count: int = 0
	var combined: Array = dish + garnishes
	for item in combined:
		for trace_id in item.get("pan_carryover", {}):
			var trace: Dictionary = item.pan_carryover[trace_id]
			if not carryover.has(trace_id):
				carryover[trace_id] = trace.duplicate(true)
				carryover[trace_id].mass_kg = 0.0
			carryover[trace_id].mass_kg += float(trace.get("mass_kg", 0))
		var id: String = str(item.get("id", ""))
		if not _catalog.has(id):
			continue
		var data: Dictionary = _catalog[id]
		var heat: float = float(item.get("heat", 0.0))
		var needs_cook: bool = bool(data.get("needs_cook", false))
		var cut: bool = bool(item.get("cut", false))
		var ingredient_quality: float = 0.86
		var thermal: Dictionary = item.get("thermal",{})
		var underdone := heat < COOKED_AT if thermal.is_empty() else float(thermal.get("cooked",0.0)) < 0.99
		var scorched := heat > BURNT_AFTER if thermal.is_empty() else maxf(float(thermal.get("char",[0,0])[0]),float(thermal.get("char",[0,0])[1])) > 0.15
		if needs_cook:
			if underdone:
				var internal_done := heat / COOKED_AT if thermal.is_empty() else float(thermal.get("cooked",0.0))
				ingredient_quality = 0.22 + clampf(internal_done,0.0,1.0) * 0.35
				raw_count += 1
			elif heat <= 11.0:
				ingredient_quality = 1.0
			else:
				ingredient_quality = 0.84
		if scorched:
			ingredient_quality = 0.18
			burnt = true
		if cut:
			cut_count += 1
			ingredient_quality = minf(1.0, ingredient_quality + 0.06)
		quality_sum += ingredient_quality


		if not unique.has(id):
			unique[id] = true
			weird_sum += float(data.get("weirdness", 0.0))
			for tag in data.get("tags", []):
				if not tags.has(tag):
					tags.append(tag)
	for trace in carryover.values():
		if float(trace.mass_kg) >= 0.00005:
			for tag in trace.get("tags", []):
				if not tags.has(tag): tags.append(tag)
	var count: int = combined.size()
	var weirdness: float = 0.0
	if not unique.is_empty():
		weirdness = clampf(weird_sum / sqrt(float(unique.size())), 0.0, 1.0)

		if tags.has("sweet") and tags.has("seafood"):
			weirdness = minf(1.0, weirdness + 0.18)
	return {
		"pan_carryover": carryover,
		"ingredients": combined.duplicate(true),
		"presentation": presentation.duplicate(true),
		# Only broth actually transferred to the serving vessel belongs to the dish.
		"water_ml": float(presentation.get("broth_ml", 0.0)),
		"quality": quality_sum / float(count) if count > 0 else 0.0,
		"weirdness": weirdness,
		"tags": tags,
		"burnt": burnt,
		"raw_count": raw_count,
		"cut_count": cut_count,
		"unique_count": unique.size()
	}

func serve() -> Dictionary:
	if phase != "service":
		last_notice = "开始营业后才可以给客人出餐。" if phase == "prep" else "班次结束，不能继续收款。"
		return {}
	if current_customer.is_empty():
		last_notice = "现在还没有客人，稍等一会儿。"
		return {}
	if dish.is_empty():
		last_notice = "空盘不能出餐，先加入食材吧。"
		return {}
	var snapshot: Dictionary = plate()
	var evaluation: Dictionary = _evaluate(snapshot, current_customer)
	var payment: float = float(evaluation["payment"])
	revenue = snappedf(revenue + payment, 0.01)
	served += 1
	var result: Dictionary = {
		"score": evaluation["score"],
		"payment": payment,
		"meal_fee": evaluation.get("meal_fee", 0),
		"tip": evaluation.get("tip", 0),
		"compensation": evaluation.get("compensation", 0),
		"feedback": evaluation["feedback"],
		"detail": evaluation.get("detail", ""),
		"reaction": evaluation.get("reaction", ""),
		"role": evaluation.get("role", ""),
		"reason": evaluation.get("reason", ""),
		"mood_before": evaluation.get("mood_before", 50),
		"mood_after": evaluation.get("mood_after", 50),
		"mood_delta": evaluation.get("mood_delta", 0),
		"recipe_match": evaluation.get("recipe_match", -1.0),
		"ordered_recipe_title": evaluation.get("ordered_recipe_title", ""),
		"customer": current_customer.get("name", "客人"),
		"customer_id": current_customer.get("id", ""),
		"dish": snapshot
	}
	served_meals.append(result.duplicate(true))
	last_notice = "%s：%s  本单 ¥%.2f" % [str(result["customer"]), str(result["feedback"]), payment]
	dish = []
	garnishes.clear()
	presentation.clear()
	heating = false
	current_customer = {}
	customer_wait = 0.0
	_arrival_delay = 2.0
	return result

func clear_dish() -> void :
	if phase == "closed":
		return
	dish = []
	garnishes.clear()
	presentation.clear()
	heating = false
	last_notice = "清空了工作台，重新试一种搭配。"

func talk() -> String:
	if current_customer.is_empty():
		last_notice = "现在没有客人可以聊天。"
		return last_notice
	current_customer["preferences_known"] = true
	var name: = str(current_customer.get("name", "客人"))
	var today: = str(current_customer.get("today_story", current_customer.get("quote", "今天由你来决定吃什么吧。")))
	var past: = str(current_customer.get("past_story", "以前路过这里时，我总会记住厨房里飘出来的味道。"))
	var likes: Array[String] = []
	var dislikes: Array[String] = []
	for tag in current_customer.get("likes", []): likes.append(_tag_label(str(tag)))
	for tag in current_customer.get("dislikes", []): dislikes.append(_tag_label(str(tag)))
	var order_line: = "今天没有固定菜名，你可以按刚才聊的做。"
	if current_customer.has("ordered_recipe"):
		order_line = "我今天想点你菜谱里的《%s》，做法有变化也可以，但我会尝得出来。" % current_customer.ordered_recipe.get("title", "招牌菜")
	var cut_line := "切块大小由你决定，我更在意味道。"
	if str(current_customer.get("cut_preference", "")) == "small":
		cut_line = "如果方便，请切得细小一点；大小不匀，我一入口就能感觉到。"
	var poster_line := "我没有在街口看到海报，是顺路闻着香味来的。"
	if bool(current_customer.get("noticed_poster", false)):
		poster_line = "我路过时看见了你贴的海报，纸上的手绘让我想进来尝尝。"
	var heat_line := "火候稳一些就好，生的和烧苦的我都不想勉强。"
	if bool(current_customer.get("likes_burnt", false)):
		heat_line = "我确实喜欢焦边，但里面必须熟；焦香和夹生是两回事。"
	var lines: = [
		today,
		past,
		str(current_customer.get("quote", "你也说说今天想怎么做？")),
		"我吃饭有个习惯：%s。" % str(current_customer.get("habit", "看食材决定")),
		"合口的通常是%s；%s最好少一点。" % ["、".join(likes) if not likes.is_empty() else "有新意的味道", "、".join(dislikes) if not dislikes.is_empty() else "没有特别忌口"],
		cut_line,
		heat_line,
		poster_line,
		"我不是来催你快做，剩余时间里把每一步做清楚就好。",
		order_line,
		"做好后把实际那一盘递给我吧，我会告诉你哪一口最好，也会认真说哪里还能改。"
	]
	var spoken: String = lines[_talk_turn % lines.size()]
	current_customer["last_chat"] = spoken
	last_notice = "%s：%s" % [name, spoken]
	_talk_turn += 1
	return last_notice

func _tag_label(tag: String) -> String:
	return str({"comfort": "暖胃家常", "grain": "谷物", "spicy": "辣味", "odd": "怪异材料", "starchy": "焦香淀粉", "sweet": "甜味", "umami": "鲜味", "vegetable": "蔬菜", "bold": "大胆搭配", "herbal": "香草", "fruit": "水果", "fresh": "清爽", "dairy": "奶制品", "protein": "蛋白质", "soft": "软嫩口感"}.get(tag, tag))

func end_shift() -> Dictionary:
	if not _settlement.is_empty():
		return _settlement.duplicate(true)
	phase = "closed"
	heating = false
	_settlement = {
		"revenue": revenue,
		"share": snappedf(revenue * player_share, 0.01),
		"served": served,
		"missed": missed,
		"elapsed_seconds": elapsed,
		"duration_seconds": duration,
		"meals": served_meals.duplicate(true)
	}
	last_notice = "收工！本班次营业额 ¥%.2f，你获得 30%% 分成 ¥%.2f。" % [revenue, float(_settlement["share"])]
	return _settlement.duplicate(true)

func apply_poster(tags: Array) -> void :
	if phase == "closed":
		last_notice = "本班次已结束，下次营业再贴海报吧。"
		return
	_poster_tags = tags.duplicate()
	poster_bonus = not tags.is_empty()
	_rebuild_queue()
	last_notice = "海报已贴出。只有经过海报、当晚有空且口味相合的客人才会被吸引。"

func _read_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("Restaurant catalog not found: " + path)
		return []
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(value) != TYPE_ARRAY:
		push_error("Restaurant catalog is not a JSON array: " + path)
		return []
	return value

func _rebuild_queue() -> void :
	_queue.clear()
	for customer in customers:
		var id: String = str(customer.get("id", ""))
		if _visited.has(id) or not bool(customer.get("available", false)):
			continue
		if bool(customer.get("walk_in", false)):
			_queue.append(customer.duplicate(true))
			continue
		if not poster_bonus or not bool(customer.get("noticed_poster", false)):
			continue
		for tag in customer.get("likes", []):
			if _poster_tags.has(tag):
				_queue.append(customer.duplicate(true))
				break
	# A short shift cannot reach all twelve in fixed file order. Each new shift
	# draws from the authored roster; externally supplied test/host order stays intact.
	if not _custom_customer_profiles and customers.size() == 12:
		_queue.shuffle()

func _arrive() -> void :
	if _queue.is_empty() or not current_customer.is_empty():
		return
	current_customer = _queue.pop_front()
	current_customer["preferences_known"] = false
	_talk_turn = 0
	var seed: int = absi(str(current_customer.get("id", "guest")).hash())
	current_customer["mood_before"] = clampi(int(current_customer.get("mood_base", 48)) + seed % 17 - 8, 15, 88)
	if not _menu_recipes.is_empty():
		current_customer["ordered_recipe"] = _menu_recipes[seed % _menu_recipes.size()].duplicate(true)
	_visited[str(current_customer.get("id", ""))] = true


	var configured_wait: Variant = current_customer.get("patience", DEFAULT_CUSTOMER_WAIT)
	var wait_budget: float = DEFAULT_CUSTOMER_WAIT
	if (configured_wait is int or configured_wait is float) and is_finite(float(configured_wait)):
		wait_budget = clampf(float(configured_wait), MIN_CUSTOMER_WAIT, MAX_CUSTOMER_WAIT)
	current_customer["patience"] = wait_budget
	customer_wait = wait_budget
	last_notice = "%s 来了，聊聊再决定今晚的主厨推荐。" % str(current_customer.get("name", "客人"))

func _evaluate(snapshot: Dictionary, customer: Dictionary) -> Dictionary:
	var quality: float = float(snapshot["quality"])
	var likes_burnt: = bool(customer.get("likes_burnt", false))
	if likes_burnt and bool(snapshot["burnt"]):

		var total: = 0.0
		var entries: Array = snapshot.get("ingredients", [])
		for entry in entries:
			var heat: = float(entry.get("heat", 0))
			total += (1.0 if heat <= 28 else 0.5) if heat > BURNT_AFTER else quality
		quality = total / maxf(1, entries.size())
	var weirdness: float = float(snapshot["weirdness"])
	var tags: Array = snapshot["tags"]
	var likes: int = 0
	var dislikes: int = 0
	for tag in customer.get("likes", []):
		if tags.has(tag):
			likes += 1
	for tag in customer.get("dislikes", []):
		if tags.has(tag):
			dislikes += 1
	var liked_bonus: float = minf(float(likes) * 10.0, 20.0)
	var dislike_penalty: float = minf(float(dislikes) * 18.0, 36.0)
	var score: float = 20.0 + quality * 60.0 + liked_bonus - dislike_penalty
	var kind: String = str(customer.get("kind", "regular"))
	if kind == "adventurous":
		score = 10.0 + quality * 40.0 + weirdness * 42.0 + liked_bonus - dislike_penalty
	elif kind == "gourmet":
		score = 5.0 + quality * 64.0 + liked_bonus - dislike_penalty - weirdness * 36.0
		if int(snapshot["cut_count"]) == snapshot.get("ingredients", []).size():
			score += 6.0
		if bool(customer.get("preferences_known", false)):
			score += 5.0
	else:
		score -= weirdness * 50.0
	if int(snapshot["raw_count"]) > 0:
		score -= minf(24.0, float(snapshot["raw_count"]) * 10.0)
	if bool(snapshot["burnt"]):
		score += 14.0 if likes_burnt else -18.0
	elif likes_burnt:
		score -= 12.0
	if str(customer.get("cut_preference", "")) == "small":
		score += 8.0 if int(snapshot["cut_count"]) > 0 else -8.0
	if str(customer.get("cut_preference", "")) == "whole":
		score += 6.0 if int(snapshot["cut_count"]) == 0 else -6.0
	var recipe_match: = -1.0
	if customer.has("ordered_recipe"):
		recipe_match = _recipe_match(snapshot, customer.ordered_recipe)
		score += lerpf(-18.0, 14.0, recipe_match)
	var final_score: int = clampi(roundi(score), 0, 100)
	var charges: = payment_for_score(final_score, customer)
	var review: Dictionary = preload("res://modules/restaurant/domain/customer_review.gd").compose(snapshot, customer, _catalog, final_score)
	review["score"] = final_score
	var mood_before: = int(customer.get("mood_before", 50))
	var requested_mood_delta: = clampi(roundi((final_score - 50) * 0.42), -24, 24)
	var mood_after: = clampi(mood_before + requested_mood_delta, 0, 100)
	var mood_delta: = mood_after - mood_before
	review["mood_before"] = mood_before
	review["mood_delta"] = mood_delta
	review["mood_after"] = mood_after
	review["recipe_match"] = recipe_match
	review["ordered_recipe_title"] = str(customer.get("ordered_recipe", {}).get("title", ""))
	review.merge(charges)
	return review

func _recipe_match(snapshot: Dictionary, recipe: Dictionary) -> float:
	var expected: Dictionary = {}
	var actual: Dictionary = {}
	for pair in [[recipe.get("dish", {}).get("ingredients", []), expected], [snapshot.get("ingredients", []), actual]]:
		if not pair[0] is Array: continue
		for value in pair[0]:
			if not value is Dictionary and not value is String: continue
			var item: Dictionary = {"id": value} if value is String else value
			var id := str(item.get("id", ""))
			if id.is_empty() or id in BLOCKED_INGREDIENT_IDS: continue
			var key := id + ("_garnish" if bool(item.get("garnish", false)) else "_cooked")
			var grouped: Dictionary = pair[1]
			var state: Dictionary = grouped.get(key, {"mass_kg": 0.0, "volume_ml": 0.0, "cut": false, "heat": 0.0, "softness": 0.0,
				"portion_weight": 0.0, "cut_weight": 0.0, "heat_sum": 0.0, "softness_sum": 0.0, "scorched_weight": 0.0})
			var mass := maxf(0.0, float(item.get("mass_kg", 0.0)))
			var volume := maxf(0.0, float(item.get("volume_ml", item.get("amount_ml", 0.0))))
			var weight := mass if mass > 0.0 else (volume / 1000.0 if volume > 0.0 else 1.0)
			state.mass_kg += mass
			state.volume_ml += volume
			state.cut = bool(state.cut) or bool(item.get("cut", false))
			state.heat = maxf(float(state.heat), float(item.get("heat", 0.0)))
			state.softness = maxf(float(state.softness), float(item.get("softness", 0.0)))
			state.portion_weight += weight
			if bool(item.get("cut", false)): state.cut_weight += weight
			state.heat_sum += weight * maxf(0.0, float(item.get("heat", 0.0)))
			state.softness_sum += weight * maxf(0.0, float(item.get("softness", 0.0)))
			if float(item.get("heat", 0.0)) > BURNT_AFTER: state.scorched_weight += weight
			grouped[key] = state
	if expected.is_empty(): return 0.0
	var matched := 0.0
	for key in expected:
		if not actual.has(key): continue
		var target: Dictionary = expected[key]
		var served: Dictionary = actual[key]
		var similarity := 1.0
		for field in ["mass_kg", "volume_ml"]:
			var required := float(target[field])
			if required <= 0.0: continue # Older recipes may omit quantities.
			var received := float(served[field])
			if received <= 0.0:
				similarity = 0.0
			else:
				# The recipe guide also allows roughly 35% measuring tolerance.
				similarity *= minf(1.0, minf(received / (required * 0.65), required * 1.35 / received))
		var served_weight := maxf(0.000001, float(served.portion_weight))
		if bool(target.cut): similarity *= clampf(float(served.cut_weight) / served_weight, 0.0, 1.0)
		if float(target.heat) >= COOKED_AT:
			similarity *= clampf(float(served.heat_sum) / served_weight / maxf(COOKED_AT, float(target.heat) - 1.0), 0.0, 1.0)
			if float(target.heat) <= BURNT_AFTER:
				similarity *= 1.0 - 0.75 * clampf(float(served.scorched_weight) / served_weight, 0.0, 1.0)
		if float(target.softness) > 0.1:
			similarity *= clampf(float(served.softness_sum) / served_weight / float(target.softness), 0.0, 1.0)
		matched += similarity
	# Broth is a separate measured ingredient and must reach the serving bowl.
	var target_water := float(recipe.get("dish", {}).get("water_ml", 0.0))
	var served_water := float(snapshot.get("water_ml", 0.0))
	var water_slots := 0
	if target_water > 0.0:
		water_slots = 1
		if served_water > 0.0:
			matched += minf(1.0, minf(served_water / (target_water * 0.8), target_water * 1.2 / served_water))
	elif served_water > 0.0:
		water_slots = 1
	# Extra ingredients occupy part of the served dish rather than disappearing
	# from the denominator when every requested ID is present.
	return clampf(matched / float(maxi(expected.size(), actual.size()) + water_slots), 0.0, 1.0)

func add_garnish(id: String, ml: float) -> float:
	if phase == "closed" or not _catalog.has(id) or ml <= 0 or not is_finite(ml): return 0.0
	if not str(_catalog[id].get("dispense_mode", "")) in ["squeeze", "pour"]: return 0.0
	var total: = 0.0
	var existing: Dictionary = {}
	for item in garnishes:
		total += float(item.get("amount_ml", 0))
		if item.id == id: existing = item
	var accepted: = minf(ml, maxf(0, 120 - total))
	if accepted <= 0: return 0.0
	if existing.is_empty():
		if garnishes.size() >= 12: return 0.0
		existing = {"id": id, "amount_ml": 0.0, "heat": 0.0, "cut": false, "garnish": true,
			"liquid_state": {"volume_ml": 0.0, "composition_ml": {id: 0.0}, "mixedness": 0.0, "layered": false, "colour_model": "weighted_srgb_visual_approximation"}}
		garnishes.append(existing)
	existing.amount_ml = float(existing.amount_ml) + accepted
	existing.liquid_state.volume_ml = float(existing.amount_ml)
	existing.liquid_state.composition_ml[id] = float(existing.amount_ml)
	return accepted

func payment_for_score(score: int, customer: Dictionary) -> Dictionary:
	var bounded: = clampi(score, 0, 100)
	var budget: = maxf(0, float(customer.get("base_payment", 36)))
	var meal: = 0.0
	var tip: = 0.0
	var compensation: = 0.0
	if bounded < 20:
		compensation = maxf(1, snappedf(budget * (20 - bounded) / 40.0, 0.01))
	else:
		meal = snappedf(budget * bounded / 100.0, 0.01)
		if bounded > 80:
			var low: = clampf(float(customer.get("tip_min", 0.05)), 0, 1)
			var high: = clampf(float(customer.get("tip_max", 0.18)), low, 1)
			tip = snappedf(budget * payment_rng.randf_range(low, high), 0.01)
	return {"meal_fee": meal, "tip": tip, "compensation": compensation, "payment": snappedf(meal + tip - compensation, 0.01)}
