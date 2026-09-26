extends CanvasLayer
## Presentation follows the host clock; it never advances gameplay time.
var game
var shade: ShaderMaterial
var preview_minute: float=-1.0 # Deterministic capture/test only; ordinary play reads the clock.
var minute:=720.0
var rain:=0.0
var phase:=Vector3.ONE
var sun_strength:=0.0
var animation_time:=0.0
func _ready() -> void:
	layer=2
	var panel:=ColorRect.new();panel.name="Daylight";panel.size=Vector2(1440,900);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shade=ShaderMaterial.new();shade.shader=preload("res://assets/shaders/desk_daylight.gdshader");panel.material=shade;add_child(panel)
	refresh(0)
func _process(delta: float) -> void:refresh(delta)
func clock_minute() -> float:
	if preview_minute>=0:return preview_minute
	var atmosphere=get_node_or_null("/root/WorldAtmosphere")
	if atmosphere!=null:
		atmosphere.ensure_initialized();rain=float(atmosphere.rain)
		return float(atmosphere.minute)
	var host=get_node_or_null("/root/GameState")
	if host!=null:return float(host.current_minute)
	var clock:=Time.get_time_dict_from_system()
	return float(clock.hour*60+clock.minute)+float(clock.second)/60.0
static func sky_weights(at: float) -> Vector3:
	# Same thresholds as Solmere WorldAtmosphere, including the dusk-to-night blend.
	var t:=fposmod(at,1440.0)
	if t<330:return Vector3(0,0,1)
	if t<480:
		var dawn:=smoothstep(330.0,480.0,t);return Vector3(dawn,0,1-dawn)
	if t<1020:return Vector3(1,0,0)
	if t<1110:
		var dusk:=smoothstep(1020.0,1110.0,t);return Vector3(1-dusk,dusk,0)
	if t<1200:
		var night:=smoothstep(1110.0,1200.0,t);return Vector3(0,1-night,night)
	return Vector3(0,0,1)
func refresh(delta: float) -> void:
	if shade==null:return
	minute=clock_minute();phase=sky_weights(minute)
	sun_strength=(phase.x+phase.y*0.55)*(1.0-clampf(rain,0,1)*0.85)
	if not bool(game.writing_preferences.get("reduce_motion",false)):animation_time+=minf(delta,0.1)
	shade.set_shader_parameter("blind_open",game.blinds_open)
	shade.set_shader_parameter("phase",phase)
	shade.set_shader_parameter("sun_strength",sun_strength)
	shade.set_shader_parameter("sun_shift",clampf((minute-720.0)/420.0,-1.0,1.0))
	shade.set_shader_parameter("drift",animation_time)
