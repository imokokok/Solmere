extends Node2D
## One fixed-step state owner for contact heating, phase change and coating exchange.
const Thermal = preload("res://modules/restaurant/domain/food_thermal.gd")
const Sauce = preload("res://modules/restaurant/domain/sauce_state.gd")
var world: Node2D
var pan_c := 22.0
var evaporated_water_ml := 0.0
var clock := 0.0

func _physics_process(delta: float) -> void:
	if world.controls_enabled: advance(delta)
	queue_redraw()

func _eligible(body: Node) -> bool:
	return body is RigidBody2D and not body.is_queued_for_deletion() and not body.get_meta("is_container",false) and not body.get_meta("overflow",false)

func ensure_state(body: RigidBody2D) -> Dictionary:
	if not body.has_meta("thermal"):
		var state := Thermal.make_state(body.get_meta("definition",{}),body.mass,float(body.get_meta("source_fraction",1.0)))
		state.dose=float(body.get_meta("cooking_heat",body.get_meta("saved_heat",0.0)))
		var old_heat := float(state.dose)
		state.cooked=clampf(old_heat/6.0,0.0,1.0)
		state.brown=[clampf((old_heat-6.0)/7.0,0.0,1.0),clampf((old_heat-6.0)/7.0,0.0,1.0)]
		state.char=[clampf((old_heat-13.0)/17.0,0.0,1.0),clampf((old_heat-13.0)/17.0,0.0,1.0)]
		# Composition quantities own liquid portions. Do not evaporate arbitrary solutes.
		if body.has_meta("liquid_state"): state.water_kg=0.0
		body.set_meta("thermal",state)
	return body.get_meta("thermal")

func advance(dt: float) -> void:
	if dt<=0.0: return
	# A bounded subdivision also makes deterministic fixture stepping equivalent to play.
	var remaining := dt
	while remaining>0.000001:
		var step := minf(remaining,1.0/60.0)
		_step(step)
		remaining-=step

func _step(dt: float) -> void:
	clock+=dt
	var vapor_ml := 0.0
	var moist_food := false
	var covered: bool = is_instance_valid(world.lid) and world.lid.covered
	var burner: float = {"low":1100.0,"medium":1800.0,"high":2600.0}.get(world.heat_level,1800.0) if world.cooking and world.pan.on_stove() else 0.0
	pan_c=clampf(pan_c+(burner-(7.0 if covered else 10.0)*(pan_c-22.0))*dt*4.0/450.0,22.0,300.0)
	if world.pan.water_ml>0.0:
		var capacity: float = maxf(1.0,world.pan.water_ml*4.18)
		var q := Thermal.exchange(pan_c,world.pan.water_heat,450.0,capacity,38.0,dt*4.0)
		pan_c-=q/450.0
		var next_temp: float = world.pan.water_heat+q/capacity
		var excess := maxf(0.0,next_temp-100.0)*capacity
		var evaporated: float = minf(world.pan.water_ml,excess/2256.0)
		world.pan.water_ml-=evaporated
		evaporated_water_ml+=evaporated
		vapor_ml+=evaporated
		world.pan.water_heat=clampf(next_temp,22.0,100.0)
		world.pan.water_heat=lerpf(world.pan.water_heat,22.0,1.0-exp(-dt*0.012))
	var solids: Array = []
	var liquids: Array = []
	for body in world._foods.get_children():
		if not _eligible(body): continue
		if not body.get_meta("enrolled",false) and not body.has_meta("thermal"): continue
		var state := ensure_state(body)
		var definition: Dictionary = body.get_meta("definition",{})
		var in_pan: bool = body!=world._held and body.get_meta("enrolled",false) and not body.get_meta("plated",false) and world.pan.contains(body.position)
		var wet: bool = in_pan and world.pan.water_ml>=80.0
		var local: Vector2 = world.pan.local_point(body.position)
		# Contact belongs to the lower edge of the actual food outline. Looking
		# only at its centre left a cracked egg balanced on tomato pieces raw.
		var bottom := local.y
		if in_pan:
			var outline: PackedVector2Array = body.get_meta("fragment_polygon", PackedVector2Array())
			for vertex in outline:
				bottom = maxf(bottom, world.pan.local_point(body.to_global(vertex)).y)
		var touches_metal: bool = body.get_colliding_bodies().has(world.pan.rigid)
		var contact: bool = in_pan and (touches_metal or bottom>=585.0) and not world.utensil_holds(body)
		var env := pan_c if contact else 22.0
		var before := float(state.evaporated_kg)
		var film: Dictionary = body.get_meta("surface_sauce",{})
		var native := maxf(0.000001,body.mass-float(film.get("mass_kg",0.0)))
		var exposed := minf(100.0, lerpf(22.0, pan_c, 0.62)) if covered and in_pan else 22.0
		var absorbed_heat := Thermal.advance(state,definition,dt,env,world.pan.water_heat,wet,native,exposed,0.65 if covered and in_pan else 1.0,1.0 if contact else 0.055)
		if in_pan:
			vapor_ml += (float(state.evaporated_kg)-before)*1000.0
			moist_food = moist_food or (bool(Thermal.profile(definition).edible) and float(state.water_kg)>0.0001)
		if in_pan:
			if wet:
				world.pan.water_heat=maxf(22.0,world.pan.water_heat-absorbed_heat/maxf(1.0,world.pan.water_ml*4.18))
			elif contact or covered: pan_c=maxf(22.0,pan_c-absorbed_heat/450.0)
		body.mass=maxf(0.000001,body.mass-(float(state.evaporated_kg)-before))
		if str(definition.get("id","")) in ["noodles","bread"] and wet and world.pan.water_heat>=80.0:
			var limit := float(state.initial_kg)*(0.8 if str(definition.id)=="noodles" else 0.25)
			var absorbed := minf(maxf(0.0,limit-float(state.absorbed_water_kg)),float(state.initial_kg)*dt*0.025)
			absorbed=minf(absorbed,world.pan.water_ml/1000.0)
			state.absorbed_water_kg+=absorbed
			state.water_kg+=absorbed
			world.pan.water_ml-=absorbed*1000.0
			body.mass+=absorbed
			body.set_meta("hydration",clampf(float(state.absorbed_water_kg)/maxf(limit,0.0001),0.0,1.0))
		if in_pan:
			if body.has_meta("liquid_state"): liquids.append(body)
			else: solids.append(body)
		_apply(body,state)
		var charred := maxf(float(state.char[0]),float(state.char[1]))
		if in_pan and charred>0.15 and not body.get_meta("burn_warning",false):
			body.set_meta("burn_warning",true)
			world.interaction.emit("notice", "%s已经开始焦糊！翻面和减小火力可以减缓，焦味无法消除。" % str(definition.get("name","食材")))
	_exchange_food_heat(solids,dt)
	world.lid.advance(dt,vapor_ml,pan_c,moist_food or world.pan.water_ml>0.0)
	# Pools only wet nearby ingredients. Falling streams select the first hit food.
	for source in liquids:
		var previous: Vector2 = source.get_meta("reaction_previous",source.position-Vector2(0,4))
		for food in solids:
			var nearest := Geometry2D.get_closest_point_to_segment(food.position,previous,source.position)
			var radius := clampf(float(food.get_meta("cut_radius",22.0)),7.0,30.0)
			if nearest.distance_to(food.position)<=radius+9.0:
				coat(source,food,dt*3.5)
				break
		source.set_meta("reaction_previous",source.position)
	for food in solids:
		var state: Dictionary = food.get_meta("thermal")
		if float(state.liquid_kg)>0.00001:
			for other in solids:
				if other!=food and other.position.distance_to(food.position)<35.0: coat_phase(food,other,dt*0.8)

func _exchange_food_heat(solids: Array, dt: float) -> void:
	# Each real contact exchanges a finite amount once. A stacked ingredient
	# warms from its neighbour, without pretending it touches the hot metal.
	for i in solids.size():
		var a: RigidBody2D = solids[i]
		var contacts := a.get_colliding_bodies()
		for j in range(i+1,solids.size()):
			var b: RigidBody2D = solids[j]
			if not contacts.has(b): continue
			var sa := ensure_state(a)
			var sb := ensure_state(b)
			var ca := maxf(0.01,a.mass*float(Thermal.profile(a.get_meta("definition")).cp)*0.56)
			var cb := maxf(0.01,b.mass*float(Thermal.profile(b.get_meta("definition")).cp)*0.56)
			var area := pow(maxf(0.001,minf(a.mass,b.mass))/0.15,0.66)
			var q := Thermal.exchange(float(sa.core_c),float(sb.core_c),ca,cb,5.0*area,dt*5.0)
			sa.core_c-=q/ca
			sb.core_c+=q/cb
			_apply(a,sa)
			_apply(b,sb)

func _apply(body: RigidBody2D,state: Dictionary) -> void:
	body.set_meta("thermal",state)
	body.set_meta("cooking_heat",Thermal.legacy_heat(state))
	body.set_meta("saved_heat",Thermal.legacy_heat(state))
	var soft := maxf(float(state.softness),float(body.get_meta("hydration",0.0)))
	body.set_meta("softness",soft)
	var art := body.get_node_or_null("FoodArt")
	if art:
		art.set("thermal",state.duplicate(true))
		art.set("coating",body.get_meta("surface_sauce",{}).duplicate(true))
		art.set("heat",Thermal.legacy_heat(state))
		art.set("softness",soft)
	var blob := body.get_node_or_null("SauceBlob")
	if blob:
		blob.set("liquid_state",body.get_meta("liquid_state",{}))
		blob.queue_redraw()
	# Shape and art share the same deforming support envelope, never scale the body.
	var deform := Thermal.shape(state,body.get_meta("definition",{}))
	if str(body.get_meta("id",""))=="noodles":
		world._apply_noodle_collision(body,soft)
	elif not body.has_meta("liquid_state") and deform.distance_to(body.get_meta("thermal_shape",Vector2.ONE))>0.025:
		var polygon: PackedVector2Array = body.get_meta("fragment_polygon",PackedVector2Array())
		var collision := body.get_node_or_null("CollisionShape2D")
		if collision and polygon.size()>=3:
			var shape := ConvexPolygonShape2D.new()
			var points := PackedVector2Array()
			for p in polygon: points.append(p*deform)
			shape.points=points
			collision.set_deferred("shape",shape)
			body.set_meta("thermal_shape",deform)

func coat(source: RigidBody2D,food: RigidBody2D,requested: float) -> float:
	if not source.has_meta("liquid_state") or source.is_queued_for_deletion(): return 0.0
	var liquid: Dictionary = source.get_meta("liquid_state")
	var density := source.mass/maxf(0.000001,float(liquid.get("volume_ml",0.0)))
	ensure_state(food) # original mass is recorded before any incoming coating
	var coating: Dictionary = food.get_meta("surface_sauce",{"volume_ml":0.0,"composition_ml":{}})
	var capacity := maxf(0.8,pow(food.mass/0.15,0.66)*9.0)
	var moved := Sauce.transfer(liquid,coating,minf(requested,maxf(0.0,capacity-float(coating.get("volume_ml",0.0)))))
	if moved<=0.0: return 0.0
	var kg := moved*density
	coating.mass_kg=float(coating.get("mass_kg",0.0))+kg
	coating.origin=[clampf((source.position.x-food.position.x)/48.0+0.5,0.12,0.88),0.27]
	coating.spread=float(coating.get("spread",0.0))
	food.mass+=kg
	# An arbitrarily large minimum mass creates material during tiny transfers.
	# Godot requires positive mass; only an effectively empty body uses epsilon.
	source.mass=maxf(0.000000000001,source.mass-kg)
	food.set_meta("surface_sauce",coating)
	source.set_meta("volume_ml",liquid.volume_ml)
	if float(liquid.volume_ml)<=0.00001:
		source.visible=false
		source.collision_layer=0
		source.collision_mask=0
		# A completely absorbed portion is no longer a second ingredient/plate item.
		if source.get_meta("enrolled",false): world.food_removed_from_pan.emit(source)
		source.set_meta("enrolled",false)
		source.queue_free()
	_apply(food,ensure_state(food))
	return moved

func coat_phase(source: RigidBody2D,food: RigidBody2D,requested: float) -> float:
	var s := ensure_state(source)
	var available := float(s.liquid_kg)
	ensure_state(food)
	if available<=0.000001: return 0.0
	var film: Dictionary = food.get_meta("surface_sauce",{"volume_ml":0.0,"composition_ml":{}})
	var moved := minf(available,minf(requested/1000.0,maxf(0.0,9.0-float(film.get("volume_ml",0.0)))/1000.0))
	if moved<=0.0: return 0.0
	var id := str(source.get_meta("id",""))
	var batch := Sauce.make_batch({"id":id,"viscosity":0.8},moved*1000.0,str(source.get_meta("instance_uid","")),0.0)
	Sauce.merge_into(film,batch,0.01)
	film.mass_kg=float(film.get("mass_kg",0.0))+moved
	film.origin=[0.5,0.65]
	film.spread=float(film.get("spread",0.0))
	food.mass+=moved
	s.water_kg=maxf(0.0,float(s.water_kg)-moved*float(s.water_kg)/maxf(source.mass,0.000001))
	s.liquid_kg-=moved
	s.phase_exported_kg+=moved
	source.mass=maxf(0.000000000001,source.mass-moved)
	food.set_meta("surface_sauce",film)
	_apply(source,s)
	_apply(food,ensure_state(food))
	return moved*1000.0

func stir(body: RigidBody2D, distance: float, lift: bool) -> void:
	var state := ensure_state(body)
	Thermal.stir(state,clampf(distance/160.0,0.05,0.7),lift)
	var coating: Dictionary = body.get_meta("surface_sauce",{})
	coating.spread=clampf(float(coating.get("spread",0.0))+distance/500.0,0.0,1.0)
	Sauce.agitate(coating,distance/700.0)
	body.set_meta("surface_sauce",coating)
	_apply(body,state)

func activity(body: RigidBody2D) -> Dictionary:
	var s: Dictionary = body.get_meta("thermal",{})
	if s.is_empty() or not world.pan.contains(body.position) or body.get_meta("plated",false): return {"fry":0.0,"sauce":0.0}
	var temperature := maxf(float(s.faces_c[0]),float(s.faces_c[1]))
	var film: Dictionary = body.get_meta("surface_sauce",{})
	var mixture: Dictionary = film.get("composition_ml",{})
	if body.has_meta("liquid_state"): mixture=body.get_meta("liquid_state").get("composition_ml",{})
	var sauce := 0.0
	for id in ["ketchup","soy_sauce","chili_sauce","mayonnaise","milk","mustard","honey"]: sauce+=float(mixture.get(id,0.0))
	var oil := float(mixture.get("oil",0.0))+float(mixture.get("sesame_oil",0.0))+float(mixture.get("butter",0.0))
	var wet: bool = world.pan.water_ml>=80.0
	var moisture := float(s.water_kg)/maxf(0.000001,float(s.initial_kg))
	var frying := 0.0 if wet else clampf((temperature-96.0)/38.0,0.0,1.0)*clampf(moisture*4.0*(1.0+minf(oil,3.0)*0.15),0.0,1.0)
	# A clean pool of oil has no food moisture to drive frying noise/bubbles.
	if body.has_meta("liquid_state") and str(body.get_meta("id","")) in ["oil","sesame_oil"]: frying=0.0
	return {"fry":frying,"sauce":0.0 if wet else clampf((temperature-86.0)/22.0,0.0,1.0)*clampf(sauce/5.0,0.0,1.0)}

func water_activity() -> float:
	if world.pan.water_ml<80.0: return 0.0
	return smoothstep(92.0,100.0,world.pan.water_heat)

func _draw() -> void:
	if world==null: return
	for body in world._foods.get_children():
		if not _eligible(body) or not body.get_meta("enrolled",false): continue
		var response := activity(body)
		var strength := maxf(float(response.fry),float(response.sauce))
		if strength<0.08 or world.lid.covered: continue
		var center: Vector2 = body.position
		if body.has_node("SauceBlob"): center=world.to_local(body.get_node("SauceBlob").global_position)
		for i in 5:
			var phase := fmod(clock*(1.8 if response.sauce>0.2 else 3.8)+i*0.217,1.0)
			var point := center+Vector2(sin(i*5.17)*18.0,cos(i*4.3)*7.0+7.0-phase*2.0)
			if world.pan.local_point(point).y>594.0: continue
			draw_arc(point,(1.0+phase*(3.0 if response.sauce>0.2 else 1.5))*strength,0,TAU,12,Color(1.0,0.86,0.59,(1.0-phase)*0.7),0.9,true)
		if body.get_meta("thermal",{}).get("evap_rate",0.0)>0.00001:
			for i in 2:
				var rise := fmod(clock*0.6+i*0.5,1.0)
				var points := PackedVector2Array()
				for j in 6: points.append(center+Vector2(sin(rise*5.0+j*0.7+i)*4.0+i*8.0,-8.0-rise*18.0-j*3.0))
				draw_polyline(points,Color(0.96,0.92,0.82,(1.0-rise)*0.24),1.8,true)
