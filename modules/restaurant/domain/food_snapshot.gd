extends RefCounted
## Validate new nested visual state at import boundaries; legacy records remain valid.
const MAX_GEOMETRY_POINTS := 128
static func number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value>=minimum and value<=maximum

static func valid(value: Dictionary) -> bool:
	if value.has("geometry"):
		var polygon = value.geometry
		if not polygon is Array or polygon.size() > MAX_GEOMETRY_POINTS: return false
		for point in polygon:
			if not point is Array or point.size() != 2: return false
			for coordinate in point:
				if not number(coordinate, -2000, 2000): return false
	if value.has("thermal") and not thermal_valid(value.thermal): return false
	if value.has("surface_sauce") and not coating_valid(value.surface_sauce): return false
	return true

static func thermal_valid(s: Variant) -> bool:
	if not s is Dictionary: return false
	if s.is_empty(): return true
	if not number(s.get("version"),1,1) or not number(s.get("contact_face"),0,1): return false
	if floorf(float(s.contact_face))!=float(s.contact_face): return false
	if not number(s.get("core_c"),-100,1000): return false
	for key in ["faces_c","brown","char"]:
		var a=s.get(key)
		if not a is Array or a.size()!=2: return false
		for v in a:
			if not number(v,-100 if key=="faces_c" else 0,1000 if key=="faces_c" else 1): return false
	for key in ["cooked","softness","spread","fraction"]:
		if not number(s.get(key),0,1): return false
	for key in ["initial_kg","water_kg","evaporated_kg","converted_kg","liquid_kg","phase_exported_kg","absorbed_water_kg","evap_rate","dose","stir_work"]:
		if not number(s.get(key),0,100000): return false
	if s.has("residue_exported_kg") and not number(s.residue_exported_kg,0,100000): return false
	return s.get("phase") in ["","fat","cheese","chocolate","cream","puree"]

static func coating_valid(s: Variant) -> bool:
	if not s is Dictionary: return false
	if not number(s.get("volume_ml",0.0),0,1500): return false
	if not number(s.get("mass_kg",0.0),0,10): return false
	if not number(s.get("spread",0.0),0,1): return false
	var origin=s.get("origin",[0.5,0.35])
	if not origin is Array or origin.size()!=2: return false
	for v in origin:
		if not number(v,0,1): return false
	var mix=s.get("composition_ml",{})
	if not mix is Dictionary or mix.size()>100: return false
	var total:=0.0
	for id in mix:
		if not id is String or id.length()>80 or not number(mix[id],0,1500): return false
		total+=float(mix[id])
	return absf(total-float(s.get("volume_ml",0.0)))<0.01

static func copy(source: Dictionary, destination: Dictionary) -> void:
	if not valid(source): return
	for key in ["thermal","surface_sauce"]:
		if source.has(key): destination[key]=source[key].duplicate(true)
