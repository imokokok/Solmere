extends SceneTree
## Exercise actual bodies, pointer selection, carried renderers and volume ledgers.
const Art = preload("res://modules/restaurant/assets/sprite_library.gd")
const Geometry = preload("res://modules/restaurant/world/pan_geometry.gd")
var game
var checks := 0
var failures: Array[String] = []
var prefix := ""

func _initialize() -> void:
	root.size = Vector2i(1440, 851)
	Engine.max_fps = 120
	call_deferred("run")

func run() -> void:
	if not OS.get_cmdline_user_args().is_empty(): prefix = OS.get_cmdline_user_args()[0]
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://spatial_qa_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode(), "shift_seconds":900.0})
	root.add_child(game)
	await process_frame
	game._start_shift()
	game.set_process(false)
	var w = game.world
	var opening_width: float = w.pan.point(Geometry.CENTER + Vector2(Geometry.RADIUS.x, 0)).distance_to(w.pan.point(Geometry.CENTER - Vector2(Geometry.RADIUS.x, 0)))
	expect(opening_width >= 315.0 and opening_width <= 335.0, "skillet has a roughly 32 cm visual opening at the shared kitchen scale")
	var tomato_size: Rect2 = polygon_bounds(Art.body_outline("tomato"))
	var egg_size: Rect2 = polygon_bounds(Art.body_outline("egg"))
	var pumpkin_size: Rect2 = polygon_bounds(Art.body_outline("pumpkin"))
	expect(tomato_size.size.x > egg_size.size.x and pumpkin_size.size.x > tomato_size.size.x, "small egg, tomato and pumpkin follow coherent physical size ordering")
	expect(tomato_size.size.x / opening_width > 0.13 and tomato_size.size.x / opening_width < 0.28, "whole tomato occupies a credible fraction of the skillet")
	w.audio.muted = true
	w.reactions.set_physics_process(false)
	var handle_tip: Vector2 = w.pan.point(Vector2(1035,586))
	expect(w.pan.can_grab(handle_tip), "pan handle tip above the board remains grabbable")
	if DisplayServer.get_name() != "headless":
		await process_frame
		RenderingServer.force_draw(false)
		var pixel: Vector2i = Vector2i(root.get_final_transform()*w.get_global_transform_with_canvas()*handle_tip)
		var handle_visible := root.get_texture().get_image().get_pixelv(pixel)
		w.cutting_board.hide()
		await process_frame
		RenderingServer.force_draw(false)
		var without_board := root.get_texture().get_image().get_pixelv(pixel)
		expect(handle_visible.r < 0.4 and handle_visible.g < 0.4, "GPU displays dark handle grip over the wooden board")
		expect(Vector3(handle_visible.r,handle_visible.g,handle_visible.b).distance_to(Vector3(without_board.r,without_board.g,without_board.b)) < 0.015, "board visibility does not obscure the rendered handle tip")
		w.cutting_board.show()
		await snapshot("handle-fixed")
	game._notify("空间检查")
	expect(not game.hint_label.visible and game.toast_label.visible, "status notice and pointer hint never occupy the footer simultaneously")
	await snapshot("kitchen")
	# Real falling solids previously changed to collision mask 1 on enrollment.
	w.spawn_ingredient(game._definition("tomato"))
	var tomato: RigidBody2D = w._held
	w.drop_into_pan()
	var tomato_release_x := tomato.position.x
	await create_timer(0.7).timeout
	w.spawn_ingredient(game._definition("egg"))
	var egg: RigidBody2D = w._held
	w.drop_into_pan()
	expect(egg.position.x - tomato_release_x > 70.0, "shortcut drops whole ingredients into separate pan spaces")
	var total_mass := tomato.mass + egg.mass
	await create_timer(1.5).timeout
	expect(tomato.get_meta("enrolled", false) and egg.get_meta("enrolled", false), "both real drops enroll in the pan")
	expect(tomato.position.distance_to(egg.position) > 22.0, "solid ingredients settle separately rather than occupying the same center")
	expect(absf(tomato.mass + egg.mass - total_mass) < 0.000001, "solid contacts do not create or remove mass")
	await snapshot("solids")
	tomato.freeze = true
	egg.freeze = true
	tomato.position = w.pan.point(Vector2(800,575))
	egg.position = tomato.position + Vector2(0,4)
	tomato.set_deferred("position",tomato.position)
	egg.set_deferred("position",egg.position)
	w.set_process(false)
	await physics_frame
	await process_frame
	# Search an actual opaque overlap; selection must follow visible depth.
	var overlap := Vector2.INF
	for y in range(-10,11):
		for x in range(-10,11):
			var p := tomato.position + Vector2(x,y)
			if w.food_hit(tomato,p) and w.food_hit(egg,p): overlap=p
	expect(overlap != Vector2.INF and w._food_at(overlap) == egg, "click selects the visible front ingredient in an opaque overlap")
	egg.position = tomato.position + Vector2(0,-4)
	expect(overlap.is_finite() and w._food_at(overlap) == tomato, "selection changes with depth rather than creation order")
	# Finite bottle micro-doses: rounding every remaining value used to invent liquid.
	w.spawn_ingredient(game._definition("oil"))
	var bottle: RigidBody2D = w._held
	var initial_ml := float(bottle.get_meta("remaining_ml"))
	var initial_mass := bottle.mass
	for i in 1000: w._dispense_seasoning(0.0014)
	var released_ml := 0.0
	var released_kg := 0.0
	var portion: RigidBody2D
	for body in w._foods.get_children():
		if body.has_meta("liquid_state") and not body.is_queued_for_deletion():
			released_ml += float(body.get_meta("liquid_state").volume_ml)
			released_kg += body.mass
			portion = body
	expect(absf(released_ml - 1.4) < 0.000001, "1000 small doses yield exactly the requested finite volume")
	expect(absf(initial_ml - float(bottle.get_meta("remaining_ml")) - released_ml) < 0.000001, "bottle and emitted portions conserve liquid without repeated decimal rounding")
	expect(absf(initial_mass - bottle.mass - released_kg) < 0.000001, "bottle tare plus remaining contents and emitted mass balance")
	expect(float(w.describe_body(portion).mass_kg) > 0, "tiny physical portions never serialize as zero mass")
	w.discard_held()
	await process_frame
	# A sauce film has its own density, not the density of the coated food.
	portion.position = tomato.position
	portion.freeze = true
	game._food_entered("oil",false,portion)
	var before_volume: float = w.pan_contents_ml()
	var before_mass := tomato.mass+portion.mass
	var transferred: float = w.reactions.coat(portion,tomato,0.0007)
	expect(transferred > 0, "test transfers real oil mass onto tomato")
	# RigidBody2D mass is engine real_t precision; allow 0.0001 ml at this scale.
	print("MEASURED film displacement error ml: %.9f" % absf(w.pan_contents_ml()-before_volume))
	expect(absf(w.pan_contents_ml()-before_volume) < 0.0001, "moving oil onto a food surface preserves occupied pan volume")
	expect(absf(tomato.mass+portion.mass-before_mass) < 0.00000002, "sub-milligram film transfer does not create mass through a minimum-body-mass clamp")
	# Held pan proxy must preserve live food state on every frame.
	w.pan.grab(w.pan.point(Vector2(1000,577)))
	w.pan.move_pointer(w.pan.point(Vector2(1000,577))+Vector2(-130,-190))
	await process_frame
	var floating = w.get_node("FloatingTools")
	var source = tomato.get_node("FoodArt")
	var copy = floating.copies.get(source.get_instance_id(),{}).get("proxy")
	expect(copy != null and copy.coating == source.coating and copy.thermal == source.thermal, "lifting the pan keeps actual coating and cooking state")
	source.heat = 47.0
	source.coating = {"volume_ml":0.0007,"spread":0.7,"composition_ml":{"oil":0.0007}}
	await process_frame
	expect(copy != null and copy.heat == 47.0 and copy.coating.spread == 0.7, "carried food proxy updates rather than freezing its old appearance")
	await snapshot("carried")
	w.pan.release_pan()
	await create_timer(1.4).timeout
	w.clear_workspace()
	await process_frame
	w.pan.angle = 0
	w.pan.move_to(w.pan.HOME)
	# Every authored rack bottle shares its displayed, held and physical scale.
	for id in ["oil","pepper","salt","sugar","soy_sauce","ketchup","mayonnaise","mustard","chili_sauce","vinegar"]:
		var slot = game.storage_display.find_child("Ingredient_"+id,true,false)
		w.spawn_ingredient(game._definition(id))
		var body: RigidBody2D = w._held
		var rack_size: Vector2 = slot.get_node("FoodArt").get_global_transform_with_canvas().get_scale()
		var held_size: Vector2 = body.get_node("FoodArt").get_global_transform_with_canvas().get_scale()
		expect(rack_size.distance_to(held_size) < 0.001, id+" does not change size when lifted off its shelf")
		var polygon: PackedVector2Array = body.get_meta("fragment_polygon")
		expect(polygon == Art.body_outline(id), id+" collision outline follows the same displayed silhouette")
		w.discard_held()
		await process_frame
	# Opaque foreground wall must win both pixel visibility and pointer selection.
	w.spawn_ingredient(game._definition("ketchup"))
	var sauce: RigidBody2D = w._dispense_seasoning(20)
	w.discard_held()
	sauce.freeze = true
	game._food_entered("ketchup",false,sauce)
	sauce.position = w.pan.point(Vector2(810,627))
	sauce.set_deferred("position",sauce.position)
	await physics_frame
	await process_frame
	w._update_food_depth()
	expect(w._food_at(sauce.position) == null, "opaque pan wall blocks selecting a hidden sauce portion")
	if DisplayServer.get_name() != "headless":
		# The liquid renderer projects a puddle away from the rigid body's centre.
		# Use a known pigment probe at an interior wall point to test occlusion,
		# independent of the puddle projection or the pan painting's rim colour.
		var probe := Polygon2D.new()
		probe.polygon = PackedVector2Array([Vector2(-4,-4), Vector2(4,-4), Vector2(4,4), Vector2(-4,4)])
		probe.color = Color("e84b35")
		probe.position = w.pan.point(Vector2(810, 644))
		probe.z_index = 7
		w.add_child(probe)
		await process_frame
		RenderingServer.force_draw(false)
		var sample: Vector2i = Vector2i(root.get_final_transform()*w.get_global_transform_with_canvas()*probe.position)
		var covered := root.get_texture().get_image().get_pixelv(sample)
		w.pan.pan_front.hide()
		await process_frame
		RenderingServer.force_draw(false)
		var exposed := root.get_texture().get_image().get_pixelv(sample)
		print("MEASURED pan wall pixel: ", sample, " covered=", covered, " exposed=", exposed)
		expect(Vector3(covered.r,covered.g,covered.b).distance_to(Vector3(exposed.r,exposed.g,exposed.b)) > 0.1, "GPU pan wall occludes a known pigment behind its near wall")
		probe.queue_free()
		w.pan.pan_front.show()
		await snapshot("rim")
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: visual spatial consistency, %d checks" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func snapshot(label: String) -> void:
	if prefix.is_empty() or DisplayServer.get_name() == "headless": return
	game._update_hud()
	await process_frame
	RenderingServer.force_draw(false)
	expect(root.get_texture().get_image().save_png(prefix+"-"+label+".png") == OK,"GPU snapshot saved: "+label)

func polygon_bounds(points: PackedVector2Array) -> Rect2:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)

func expect(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
