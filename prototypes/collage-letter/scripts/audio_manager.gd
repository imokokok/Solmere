extends Node

const ROOT := "res://assets/open_pack/audio/"
var muted := false
var bank: Dictionary = {}
var pool: Array[AudioStreamPlayer] = []
var cooldown: Dictionary = {}
var ages: Dictionary = {}
var durations: Dictionary = {}
var cursor := 0
var last_clip := ""
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for i in 10:
		var voice := AudioStreamPlayer.new()
		voice.bus="SoundEffects" if AudioServer.get_bus_index("SoundEffects") >= 0 else "Master"
		add_child(voice);pool.append(voice)
	for name in ["paper","strokes","rustle","scissors","stamp","tear","match"]:
		bank[name]=load(ROOT+name+".mp3")
	bank["ocean"]=load(ROOT+"ocean-waves.ogg")
	bank["cork_pop"]=load(ROOT+"cork-pop.wav")
	bank["cork_close"]=load(ROOT+"cork-close.wav")
	bank["pencil"]=load(ROOT+"pencil.ogg")
	for i in range(1,7):bank["pen_write_%02d"%i]=load(ROOT+"pen_write_%02d.ogg"%i)
	bank["pen_erase"]=load(ROOT+"pen_erase.ogg")
	bank["tape"]=load(ROOT+"tape.mp3")
	for i in range(1,6): bank["click"+str(i)]=load(ROOT+"click"+str(i)+".ogg")
	for i in range(1,5):bank["typewriter"+str(i)]=load(ROOT+"typewriter"+str(i)+".wav")

func _process(delta: float) -> void:
	for voice in pool:
		if voice.playing:
			ages[voice] = ages.get(voice,0.0)+delta
			var remaining: float=durations.get(voice,0.3)-ages[voice]
			voice.volume_db=float(voice.get_meta("gain_db",-16.0))+linear_to_db(clampf(remaining/0.035,0.001,1.0))
			if ages[voice] > durations.get(voice,0.3): voice.stop()

func play(event: String, strength: float = 1.0) -> void:
	if muted: return
	var now := Time.get_ticks_msec()
	if now-int(cooldown.get(event,-10000)) < (100 if event=="PENCIL_DRAW" else 75): return
	cooldown[event]=now
	var clip := "rustle"
	var duration := 0.27
	var offset := 0.0
	match event:
		"SEA_WAVE":clip="ocean";duration=4.0
		"PAGE_TURN": clip="paper";offset=0.36;duration=0.85
		"GLUE_BRUSH":clip="strokes";offset=0.6;duration=0.25
		"TOOL_PICK":clip="click2";duration=0.18
		"TYPE_KEY": clip="typewriter"+str([2,4][rng.randi_range(0,1)]);duration=0.32;offset=0.025
		"CORK_OPEN": clip="cork_pop";duration=0.60
		"CORK_CLOSE": clip="cork_close";duration=0.49
		"CORK_DROP": clip="cork_close";duration=0.22;offset=0.1
		"KNIFE_SLICE":
			clip="scissors";offset=0.12;duration=0.35
		"PAPER_CUT": clip="tear";duration=0.21;offset=0.2
		"TAPE_TEAR": clip="tape";offset=2.1;duration=0.65
		"TAPE_PULL": clip="tape";offset=0.25;duration=0.8
		"BRUSH_DRAW": clip="strokes";offset=rng.randf_range(0.1,0.5);duration=0.32
		"PENCIL_DRAW": clip="pencil";offset=rng.randf_range(0.1,0.7);duration=0.3
		"WRITE_INK": clip="pencil";offset=rng.randf_range(0.12,0.72);duration=0.24
		"STAMP_PRESS", "STAMP_RELEASE", "PAPER_PRESS", "TAPE_STICK": clip="stamp";duration=0.22
		"MATCH_STRIKE": clip="match";duration=0.48
		"FIRE_LOOP": return # This pack contains no candle loop recording.
		"WAX_PELLETS", "DIALOGUE_ADVANCE", "MAIL_DROP": clip="click"+str(rng.randi_range(1,5));duration=0.3
		"WAX_POUR": clip="rustle";duration=0.24
		_: offset=rng.randf_range(0.1,2.0)
	var voice := pool[cursor]
	cursor=(cursor+1)%pool.size()
	voice.stop();voice.stream=bank[clip]
	voice.pitch_scale=rng.randf_range(0.96,1.04)
	last_clip=clip
	voice.volume_db=-5+linear_to_db(clampf(strength,0.1,1.4))
	voice.set_meta("gain_db",voice.volume_db)
	ages[voice]=0.0;durations[voice]=duration
	var length: float = voice.stream.get_length()
	voice.play(clampf(offset,0,maxf(0,length-duration)))

func toggle() -> void:
	muted=not muted
	if muted:
		for voice in pool: voice.stop()

func shutdown() -> void:
	muted=true
	for voice in pool: voice.stop();voice.stream=null
	bank.clear()

func _exit_tree() -> void:
	shutdown()

func play_pen(kind: String, volume: float) -> void:
	if muted or volume<=0:return
	var clip: String="pen_write_%02d"%rng.randi_range(1,6)
	if kind=="erase":clip="pen_erase"
	elif kind=="paper_move":clip="rustle"
	elif kind=="pen_tap":clip="click2"
	var voice:=pool[cursor];cursor=(cursor+1)%pool.size();voice.stop();voice.stream=bank[clip]
	voice.bus="TownWorldSoundEffects" if AudioServer.get_bus_index("TownWorldSoundEffects")>=0 else ("SoundEffects" if AudioServer.get_bus_index("SoundEffects")>=0 else "Master")
	voice.pitch_scale=rng.randf_range(0.94,1.06);voice.volume_db=linear_to_db(volume)+rng.randf_range(-3,0)
	voice.set_meta("gain_db",voice.volume_db);ages[voice]=0.0;durations[voice]=0.14 if kind!="paper_move" else 0.20;last_clip=clip;voice.play()
