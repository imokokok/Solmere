extends SceneTree
## Run: Godot --headless --path <project> --script res://modules/restaurant/domain/test_domain.gd

const Session = preload("res://modules/restaurant/domain/kitchen_session.gd")
var failures: Array = []
var checks: int = 0

func _initialize() -> void:
	_test_catalog()
	_test_cooking_and_tastes()
	_test_capacity_and_repeated_ingredients()
	_test_schedule_and_posters()
	_test_generous_wait_budgets()
	_test_settlement()
	if failures.is_empty():
		print("PASS: restaurant domain, %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(str(failure))
		print("FAIL: %d / %d checks" % [failures.size(), checks])
		quit(1)

func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _fresh() -> RefCounted:
	var session = Session.new()
	session.setup()
	return session

func _customer(id: String, kind: String = "regular") -> Dictionary:
	return {"id": id, "name": id, "kind": kind, "quote": "喜欢鲜味，不喜欢甜味。", "likes": ["umami"], "dislikes": ["sweet"], "available": true, "noticed_poster": false, "walk_in": true, "patience": 60.0, "base_payment": 50.0}

func _score(ids: Array, heat: float, kind: String = "regular", likes: Array = [], dislikes: Array = []) -> Dictionary:
	var session = _fresh()
	var profile: Dictionary = _customer("tester", kind)
	profile["likes"] = likes
	profile["dislikes"] = dislikes
	session.set_customers([profile])
	session.start_shift()
	for id in ids:
		session.add_ingredient(str(id))
	session.chop()
	if heat > 0.0:
		session.set_heating(true)
		session.tick(heat)
		session.set_heating(false)
	return session.serve()

func _test_catalog() -> void:
	var session = _fresh()
	_expect(session.ingredients.size() == 108, "catalog includes the three existing Solmere procurement ingredients")
	_expect(session.active_ingredients().size() == 106, "106 ingredients are available; fish stays disabled")
	var ids: Dictionary = {}
	var categories: Dictionary = {"basic": 0, "seasoning": 0, "sweet": 0, "odd": 0}
	for ingredient in session.ingredients:
		var id: String = str(ingredient["id"])
		_expect(not ids.has(id), "unique ingredient id: " + id)
		ids[id] = true
		var category: String = str(ingredient.get("category", ""))
		_expect(categories.has(category), "known category for " + id)
		if categories.has(category):
			categories[category] += 1
		_expect(float(ingredient.get("mass", 0.0)) > 0.0, "positive mass for " + id)
		_expect(float(ingredient.get("friction", -1.0)) >= 0.0 and float(ingredient.get("friction", 2.0)) <= 1.0, "friction range for " + id)
		_expect(float(ingredient.get("bounce", -1.0)) >= 0.0 and float(ingredient.get("bounce", 2.0)) <= 1.0, "bounce range for " + id)
	_expect(categories == {"basic": 41, "seasoning": 16, "sweet": 16, "odd": 35}, "catalog categories include team vegetables, odd items and procurement")

func _test_cooking_and_tastes() -> void:
	var raw: Dictionary = _score(["egg", "shrimp"], 0.0, "gourmet", ["protein", "umami"])
	var cooked: Dictionary = _score(["egg", "shrimp"], 8.0, "gourmet", ["protein", "umami"])
	var burnt: Dictionary = _score(["egg", "shrimp"], 16.0, "gourmet", ["protein", "umami"])
	_expect(int(cooked["score"]) > int(raw["score"]), "cooking required ingredients improves score")
	_expect(int(cooked["score"]) > int(burnt["score"]), "burning reduces score")
	_expect(int(raw["dish"]["raw_count"]) == 2 and not bool(raw["dish"]["burnt"]), "raw and burnt states are distinct")
	_expect(bool(burnt["dish"]["burnt"]), "burnt flag recorded")
	var normal_plain: Dictionary = _score(["bread"], 0.0)
	var normal_odd: Dictionary = _score(["sock"], 0.0)
	var adventurous_plain: Dictionary = _score(["bread"], 0.0, "adventurous")
	var adventurous_odd: Dictionary = _score(["sock"], 0.0, "adventurous")
	_expect(int(normal_plain["score"]) > int(normal_odd["score"]), "normal NPC penalizes odd ingredients")
	_expect(int(adventurous_odd["score"]) > int(adventurous_plain["score"]), "adventurous NPC rewards odd ingredients")
	var liked: Dictionary = _score(["grapes"], 0.0, "regular", ["sweet", "fruit"])
	var disliked: Dictionary = _score(["grapes"], 0.0, "regular", [], ["sweet", "fruit"])
	_expect(int(liked["score"]) > int(disliked["score"]), "same meal has customer-specific taste evaluation")
	var session = _fresh()
	session.add_ingredient("egg")
	session.set_heating(true)
	session.tick(8.0)
	session.add_ingredient("shrimp")
	_expect(float(session.dish[0]["heat"]) == 8.0 and float(session.dish[1]["heat"]) == 0.0, "late ingredients retain independent heat")
	_expect(session.elapsed == 0.0, "practice cooking does not advance service clock")
	session.set_heating(false)
	session.tick(5.0)
	_expect(float(session.dish[0]["heat"]) == 8.0, "turning off heat actually stops cooking")
	var snapshot: Dictionary = session.plate()
	snapshot["ingredients"][0]["heat"] = 999.0
	_expect(float(session.dish[0]["heat"]) == 8.0, "plate snapshots do not mutate live dish")

func _test_capacity_and_repeated_ingredients() -> void:
	var session = _fresh()
	for i in range(6):
		_expect(session.add_ingredient("bread"), "accept ingredient up to capacity %d" % i)
	_expect(not session.add_ingredient("bread") and session.dish.size() == 6, "seventh ingredient rejected without mutating dish")
	_expect(not session.add_ingredient("missing_id"), "unknown ingredient rejected")
	var one: Dictionary = _score(["bread"], 0.0, "regular", ["comfort", "grain"])
	var six: Dictionary = _score(["bread", "bread", "bread", "bread", "bread", "bread"], 0.0, "regular", ["comfort", "grain"])
	_expect(int(one["score"]) == int(six["score"]) and float(one["meal_fee"]) == float(six["meal_fee"]), "duplicate ingredients cannot multiply preference payment")
	session.start_shift()
	session.clear_dish()
	_expect(session.serve().is_empty() and session.revenue == 0.0, "empty plates cannot collect money")

func _test_schedule_and_posters() -> void:
	var session = _fresh()
	var walk: Dictionary = _customer("walk")
	var invited: Dictionary = _customer("invited")
	invited["walk_in"] = false
	invited["noticed_poster"] = true
	var busy: Dictionary = invited.duplicate(true)
	busy["id"] = "busy"
	busy["available"] = false
	var unseen: Dictionary = invited.duplicate(true)
	unseen["id"] = "unseen"
	unseen["noticed_poster"] = false
	var wrong_taste: Dictionary = invited.duplicate(true)
	wrong_taste["id"] = "wrong_taste"
	wrong_taste["likes"] = ["sweet"]
	session.set_customers([walk, invited, busy, unseen, wrong_taste])
	session.apply_poster(["umami"])
	session.start_shift()
	_expect(str(session.current_customer.get("id", "")) == "walk", "regular walk-in arrives")
	_expect(not bool(session.current_customer.get("preferences_known", false)), "preferences are hidden before conversation")
	session.talk()
	_expect(bool(session.current_customer.get("preferences_known", false)), "conversation reveals preferences")
	session.add_ingredient("bread")
	session.serve()
	session.tick(2.1)
	_expect(str(session.current_customer.get("id", "")) == "invited", "poster attracts available NPC who actually saw it")
	session.add_ingredient("bread")
	session.serve()
	session.apply_poster(["umami"])
	session.tick(3.0)
	_expect(session.current_customer.is_empty(), "busy, unseen, wrong-taste and already-visited NPCs do not appear")
	var waiting = _fresh()
	waiting.duration = 360.0
	var impatient: Dictionary = _customer("impatient")
	impatient["patience"] = 150.0
	waiting.set_customers([impatient])
	waiting.start_shift()
	waiting.tick(119.0)
	_expect(waiting.missed == 0 and not waiting.current_customer.is_empty() and waiting.customer_wait == 1.0, "customer stays until the final second of the longer budget")
	waiting.tick(1.0)
	_expect(waiting.missed == 1 and waiting.current_customer.is_empty(), "patience expiry leaves once")
	waiting.tick(10.0)
	_expect(waiting.missed == 1, "expired customer does not repeatedly count as missed")

func _test_generous_wait_budgets() -> void:
	var defaults = _fresh()
	for profile in defaults.customers:
		_expect(float(profile.get("patience", 0.0)) == 120.0, "demo NPC has a generous bounded wait: " + str(profile.get("id", "")))
		if profile.get("kind", "") == "regular":
			_expect(float(profile.get("patience", 0.0)) == 120.0, "ordinary demo guests wait two minutes")
	var omitted: Dictionary = _customer("default_wait")
	omitted.erase("patience")
	defaults.set_customers([omitted])
	defaults.start_shift()
	_expect(defaults.customer_wait == 120.0, "missing patience defaults to 120 seconds")
	for case in [[30.0,120.0],[210.0,120.0],[999.0,120.0],["later",120.0],[NAN,120.0]]:
		var custom = _fresh()
		var profile: Dictionary = _customer("custom_wait")
		profile["patience"] = case[0]
		custom.set_customers([profile])
		custom.start_shift()
		_expect(custom.customer_wait == float(case[1]), "injected patience is bounded or defaults safely: " + str(case[0]))
		_expect(float(custom.current_customer["patience"]) == custom.customer_wait, "visible NPC patience matches its effective budget")
	var closing = _fresh()
	closing.duration = 160.0
	var first: Dictionary = _customer("early_guest")
	first["patience"] = 240.0
	var late: Dictionary = _customer("late_guest")
	late["patience"] = 240.0
	closing.set_customers([first, late])
	closing.start_shift()
	closing.tick(100.0)
	closing.add_ingredient("bread")
	closing.serve()
	closing.tick(2.0)
	_expect(str(closing.current_customer.get("id", "")) == "late_guest" and closing.customer_wait == 120.0, "late-arriving customer receives a full independent wait budget")
	closing.tick(100.0)
	_expect(closing.phase == "closed" and closing.elapsed == 160.0, "long patience never extends the four-minute shift")
	_expect(closing.customer_wait == 62.0 and closing.missed == 0, "scheduled closing does not mislabel an unexpired guest as a patience timeout")

func _test_settlement() -> void:
	var session = _fresh()
	session.start_shift()
	session.add_ingredient("bread")
	var served: Dictionary = session.serve()
	var settlement: Dictionary = session.end_shift()
	var first_revenue: float = session.revenue
	_expect(float(served["payment"]) == first_revenue, "served payment recorded in revenue")
	_expect(is_equal_approx(float(settlement["share"]), snappedf(first_revenue * 0.30, 0.01)), "settlement pays 30 percent of revenue")
	settlement["share"] = 99999.0
	_expect(float(session.end_shift()["share"]) < 99999.0, "settlement snapshot protects authoritative result")
	_expect(not session.add_ingredient("bread") and session.serve().is_empty(), "closed session cannot cook or earn again")
	session.tick(300.0)
	session.start_shift()
	_expect(session.phase == "closed" and session.revenue == first_revenue and session.served == 1, "closed session stays settled after further ticks or starts")
	var timed = _fresh()
	timed.duration = 10.0
	timed.start_shift()
	timed.add_ingredient("egg")
	timed.set_heating(true)
	timed.tick(20.0)
	_expect(timed.phase == "closed" and timed.elapsed == 10.0, "large frame delta ends exactly at configured duration")
	_expect(not timed.heating and float(timed.dish[0]["heat"]) == 10.0, "cook simulation stops at shift boundary")
