extends RefCounted
## Reduced-order, time-compressed cooking. Temperatures are proxies, not safety guidance.
## Two exposed/contact faces exchange finite heat with a core. No mesh/CFD claim.
const AMBIENT := 22.0
const INERT := ["sock","paper","soap","eraser","button","spring","confetti","toy_brick","candle","baseball_bat","computer_mouse","slipper","perfume","doll","lipstick","rubber_duck","rock","resignation_letter","alarm_clock","yarn_ball","tennis_ball","dentures","sponge","toilet_paper","soap_smooth","toothpaste"]
static func profile(definition: Dictionary) -> Dictionary:
	var id := str(definition.get("id",""))
	var p := {"water":0.72,"soften":0.55,"shrink":0.12,"cp":3300.0,"thickness":1.0,"melt_c":0.0,"latent":0.0,"phase":"","edible":true}
	if id in INERT: p.merge({"water":0.0,"soften":0.0,"shrink":0.0,"cp":1600.0,"edible":false},true)
	elif id in ["oil","sesame_oil"]: p.merge({"water":0.0,"soften":0.0,"cp":2100.0},true)
	elif id in ["salt","sugar","pepper","cumin","curry"]: p.merge({"water":0.0,"soften":0.0,"shrink":0.0,"thickness":0.2},true)
	elif id in ["chicken","pork","beef","sausage","shrimp","squid","mussel"]: p.merge({"water":0.65,"soften":0.24,"shrink":0.21,"thickness":1.25},true)
	elif id in ["lettuce","spinach","cabbage","seaweed","bean_sprout","houttuynia"]: p.merge({"water":0.88,"soften":0.95,"shrink":0.36,"thickness":0.3},true)
	elif id == "mushroom": p.merge({"water":0.88,"soften":0.8,"shrink":0.29,"thickness":0.55},true)
	elif id == "onion": p.merge({"water":0.85,"soften":0.8,"shrink":0.17,"thickness":0.65},true)
	elif id == "tomato": p.merge({"water":0.92,"soften":0.95,"shrink":0.23,"phase":"puree"},true)
	elif id in ["carrot","potato","pumpkin","lotus_root"]: p.merge({"soften":0.42,"shrink":0.07,"thickness":1.4},true)
	elif id in ["tofu","stinky_tofu"]: p.merge({"water":0.82,"soften":0.35,"shrink":0.1,"thickness":0.8},true)
	elif id == "butter": p.merge({"water":0.16,"soften":0.9,"shrink":0.0,"cp":2200.0,"melt_c":34.0,"latent":65000.0,"phase":"fat"},true)
	elif id in ["cheese","blue_cheese"]: p.merge({"water":0.35,"soften":0.9,"shrink":0.0,"cp":2600.0,"melt_c":58.0,"latent":100000.0,"phase":"cheese"},true)
	elif id == "chocolate": p.merge({"water":0.02,"soften":0.9,"cp":2000.0,"melt_c":33.0,"latent":60000.0,"phase":"chocolate"},true)
	elif id == "ice_cream": p.merge({"water":0.6,"soften":0.9,"melt_c":2.0,"latent":150000.0,"phase":"cream"},true)
	elif id == "bread": p.merge({"water":0.25,"soften":0.2,"shrink":0.08,"thickness":0.55},true)
	elif id == "noodles": p.merge({"water":0.1,"soften":0.7,"shrink":0.03,"thickness":0.32},true)
	elif id == "egg": p.merge({"water":0.75,"soften":0.15,"shrink":0.08,"thickness":0.4},true)
	return p

static func make_state(definition: Dictionary, mass: float, fraction := 1.0) -> Dictionary:
	var p := profile(definition)
	var start := -5.0 if str(definition.get("id",""))=="ice_cream" else AMBIENT
	return {"version":1,"initial_kg":mass,"water_kg":mass*float(p.water),"evaporated_kg":0.0,"converted_kg":0.0,"liquid_kg":0.0,"phase_exported_kg":0.0,"absorbed_water_kg":0.0,"core_c":start,"faces_c":[start,start],"contact_face":0,"fraction":fraction,"cooked":0.0,"dose":0.0,"brown":[0.0,0.0],"char":[0.0,0.0],"softness":0.0,"stir_work":0.0,"spread":0.0,"phase":p.phase,"evap_rate":0.0,"egg_opened":false}

static func exchange(a: float,b: float,capacity_a: float,capacity_b: float,conductance: float,dt: float) -> float:
	# Exact bounded two-lump heat exchange. Returned joules move from a to b.
	var c1 := maxf(0.01,capacity_a)
	var c2 := maxf(0.01,capacity_b)
	return (a-b)/(1.0/c1+1.0/c2)*(1.0-exp(-conductance*(1.0/c1+1.0/c2)*dt))

static func advance(s: Dictionary, definition: Dictionary, dt: float, contact_c: float, bath_c: float, wet: bool, native_mass: float, exposed_c: float = AMBIENT, evaporation_scale: float = 1.0, contact_scale: float = 1.0) -> float:
	if dt<=0.0: return 0.0
	var p := profile(definition)
	var mass := maxf(native_mass,0.000001)
	var cp := float(p.cp)
	var face_cap := maxf(0.01,mass*cp*0.22)
	var core_cap := maxf(0.01,mass*cp*0.56)
	var thickness := float(p.thickness)*clampf(pow(float(s.fraction),0.55),0.16,1.0)
	var area := pow(maxf(mass,0.001)/0.15,0.66)
	var heat_in := 0.0
	var contact := int(s.contact_face)
	for f in 2:
		var environment := bath_c if wet else (contact_c if f==contact else exposed_c)
		var k := (18.0 if wet else (15.0*contact_scale if f==contact else (2.2 if exposed_c > AMBIENT else 0.8)))*area
		var q := (environment-float(s.faces_c[f]))*face_cap*(1.0-exp(-k/face_cap*dt*5.0))
		s.faces_c[f] += q/face_cap
		heat_in += q if (wet or f==contact or exposed_c > AMBIENT) else 0.0
		var inward := exchange(float(s.faces_c[f]),float(s.core_c),face_cap,core_cap,6.0*area/thickness,dt*5.0)
		s.faces_c[f]-=inward/face_cap
		s.core_c+=inward/core_cap
	s.evap_rate=0.0
	if not bool(p.edible): return heat_in
	var hottest := maxf(float(s.faces_c[0]),float(s.faces_c[1]))
	var cook_rate := clampf((float(s.core_c)-50.0)/45.0,0.0,1.25)
	s.dose=minf(60.0,float(s.dose)+dt*cook_rate*0.7)
	s.cooked=clampf(float(s.dose)/6.0,0.0,1.0)
	for f in 2:
		if not wet and str(definition.get("id","")) not in ["salt","pepper","cumin","curry"]:
			s.brown[f]=clampf(float(s.brown[f])+dt*maxf(0.0,float(s.faces_c[f])-125.0)/850.0,0.0,1.0)
			if float(s.brown[f])>0.55:
				s.char[f]=clampf(float(s.char[f])+dt*maxf(0.0,float(s.faces_c[f])-165.0)/1100.0,0.0,1.0)
	s.softness=maxf(float(s.softness),float(p.soften)*smoothstep(45.0,92.0,float(s.core_c)))
	# Water alone leaves the ingredient. Browning pigment and solids do not evaporate.
	if not wet and hottest>98.0:
		var loss := minf(float(s.water_kg),float(s.initial_kg)*dt*0.003*evaporation_scale*clampf((hottest-98.0)/65.0,0.0,1.0))
		loss=minf(loss,maxf(0.0,mass-float(s.liquid_kg)))
		mass-=loss
		s.water_kg-=loss
		s.evaporated_kg+=loss
		s.evap_rate=loss/maxf(dt,0.0001)
		# Latent heat is removed at the emitting face; saturation is a coarse model.
		s.faces_c[contact]=maxf(AMBIENT,float(s.faces_c[contact])-loss*2256000.0/face_cap)
	var converted := 0.0
	if float(p.melt_c)>0.0 and float(s.core_c)>float(p.melt_c):
		var energy := (float(s.core_c)-float(p.melt_c))*core_cap*(1.0-exp(-dt*0.6))
		converted=minf(maxf(0.0,mass-float(s.liquid_kg)),energy/float(p.latent))
		s.core_c-=converted*float(p.latent)/core_cap
	elif str(p.phase)=="puree" and float(s.softness)>0.6:
		var limit := float(s.initial_kg)*0.65*clampf(float(s.stir_work)/3.0,0.0,1.0)
		converted=minf(maxf(0.0,limit-float(s.converted_kg)),dt*float(s.initial_kg)*0.045)
		converted=minf(converted,maxf(0.0,mass-float(s.liquid_kg)))
	s.converted_kg+=converted
	s.liquid_kg+=converted
	return heat_in

static func stir(s: Dictionary, energy: float, turn: bool) -> void:
	s.stir_work=float(s.stir_work)+maxf(0.0,energy)
	s.spread=clampf(float(s.spread)+maxf(0.0,energy)*0.22,0.0,1.0)
	if turn: s.contact_face=1-int(s.contact_face)

static func split_state(s: Dictionary, ratio: float) -> Dictionary:
	var child := s.duplicate(true)
	for key in ["initial_kg","water_kg","evaporated_kg","converted_kg","liquid_kg","phase_exported_kg","residue_exported_kg","absorbed_water_kg","evap_rate"]: child[key]=float(child.get(key,0.0))*ratio
	child.fraction=float(child.fraction)*ratio
	return child

static func shape(s: Dictionary, definition: Dictionary) -> Vector2:
	var p := profile(definition)
	if str(definition.get("id", "")) == "egg" and bool(s.get("egg_opened", false)):
		# The white spreads as the shell appearance gives way to a fried egg.
		return Vector2(1.3, 0.68)
	var phase := clampf(float(s.get("converted_kg",0.0))/maxf(0.000001,float(s.get("initial_kg",0.1))),0.0,1.0)
	var shrink := float(p.shrink)*float(s.get("softness",0.0))
	return Vector2(1.0-shrink*0.35+phase*0.48,1.0-shrink-phase*0.67)

static func legacy_heat(s: Dictionary) -> float:
	# Compatibility display: time spent boiling must not label food as burnt.
	return float(s.cooked)*6.0+maxf(float(s.brown[0]),float(s.brown[1]))*7.0+maxf(float(s.char[0]),float(s.char[1]))*17.0
