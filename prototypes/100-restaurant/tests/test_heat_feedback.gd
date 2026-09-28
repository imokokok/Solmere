extends SceneTree
const Feedback = preload("res://modules/restaurant/domain/heat_feedback.gd")
const Thermal = preload("res://modules/restaurant/domain/food_thermal.gd")
var failures: Array[String] = []
var count := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	count += 1
	if not ok: failures.append(message)
func run() -> void:
	var catalog: Array = [{"id":"cheese","name":"芝士","needs_cook":false},{"id":"chicken","name":"鸡肉","needs_cook":true},{"id":"tomato","name":"番茄","needs_cook":false},{"id":"noodles","name":"面条","needs_cook":true}]
	var cheese := {"id":"cheese","heat":0.0,"thermal":Thermal.make_state(catalog[0],0.15)}
	var vessel := {"pan_c":22.0,"water_ml":0.0,"heating":false,"covered":false,"lid_hot_seconds":0.0,"lid_pop_seconds":8.0,"oil_ml":0.0,"fire":0.0,"power_out":false}
	var before := cheese.duplicate(true)
	var cold := Feedback.evaluate([cheese],catalog,vessel)
	expect(not cold.ready and cold.title.contains("没化开"),"cold cheese is not falsely complete")
	expect(cold.method == "小火慢化" and cold.high < 120,"melting uses a gentle target band")
	expect(cheese == before,"advice does not mutate food")
	cheese.thermal.converted_kg = 0.06
	var melted := Feedback.evaluate([cheese],catalog,vessel)
	expect(melted.ready and melted.title.contains("已经化开"),"phase conversion determines melted readiness")
	var chicken := {"id":"chicken","heat":0.0,"thermal":Thermal.make_state(catalog[1],0.15)}
	expect(not Feedback.evaluate([cheese,chicken],catalog,vessel).ready,"melted topping does not hide raw meat")
	chicken.thermal.cooked = 1.0
	chicken.thermal.char = [0.2,0.0]
	expect(Feedback.evaluate([chicken],catalog,vessel).severity == 2,"one burnt face is a visible warning")
	vessel.pan_c = 240.0; vessel.heating = true
	var dry := Feedback.evaluate([cheese],catalog,vessel)
	expect(dry.risk.contains("容易焦") and not dry.risk.contains("起火"),"temperature alone does not invent an oil fire")
	vessel.oil_ml = 10.0
	expect(Feedback.evaluate([cheese],catalog,vessel).risk.contains("起火"),"hot oil changes the consequence")
	vessel.water_ml = 300.0; vessel.pan_c = 105.0
	var wet := Feedback.evaluate([cheese],catalog,vessel)
	expect(wet.method == "小火煮" and wet.high == 125,"water changes the target band")
	vessel.covered = true; vessel.lid_hot_seconds = 6.0
	expect(Feedback.evaluate([cheese],catalog,vessel).risk.contains("顶开"),"sustained covered boiling warns about the actual lid mechanism")
	vessel.fire = 0.5
	expect(Feedback.evaluate([cheese],catalog,vessel).severity == 3,"active fire takes priority")
	vessel.power_out = true
	expect(Feedback.evaluate([cheese],catalog,vessel).risk.contains("跳闸"),"power failure has its own recovery instruction")
	var tomato := {"id":"tomato","heat":0.0}
	var soup := {"dish":{"water_ml":250.0,"ingredients":[{"id":"tomato","heat":6.0}]}}
	expect(not Feedback.evaluate([tomato],catalog,{},soup).ready,"selected cooked recipe does not accept cold tomato")
	var salad := {"dish":{"ingredients":[{"id":"tomato","heat":0.0}]}}
	expect(Feedback.evaluate([tomato],catalog,{},salad).method == "不用加热","cold recipe does not ask player to heat it")
	var game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://heat_feedback_qa/book.json"})
	root.add_child(game)
	await process_frame
	game._start_shift()
	await process_frame
	var guide: Control = game.heat_guide
	var dock: Control = game.hud.get_node("KitchenActionDock")
	expect(not guide.get_rect().intersects(dock.get_rect()),"cooking guidance and navigation do not overlap")
	expect(guide.feedback.has("temperature") and guide.size.y>=82,"thermometer has temperature, method and warning space")
	for f in failures: push_error(f)
	print("%s heat feedback: %d checks" % ["PASS" if failures.is_empty() else "FAIL",count])
	quit(0 if failures.is_empty() else 1)
