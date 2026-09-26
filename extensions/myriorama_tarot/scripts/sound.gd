extends Node

# Physical card sounds: Kenney Casino Audio (CC0). Synthesized tones only for UI.
const RATE := 44100
var muted := false
var clips: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var cursor := 0
var variants: Dictionary = {}

func _ready() -> void:
	for i in range(6):
		var player := AudioStreamPlayer.new()
		player.bus = "SoundEffects"
		player.volume_db = -10.0
		add_child(player)
		players.append(player)
	for kind in ["tap", "yes", "no", "complete"]:
		clips[kind] = synthesize(kind)
	var source_files := {"shuffle": ["shuffle-stroke"], "deal": ["fan-spread"], "flip": ["slide-tight-1", "slide-tight-2"], "place": ["place-tight-1", "place-tight-2"]}
	for kind in source_files:
		variants[kind] = []
		for filename in source_files[kind]:
			variants[kind].append(load("res://extensions/myriorama_tarot/assets/audio/" + filename + ".wav"))
		clips[kind] = variants[kind][0]

func play(kind: String) -> void:
	if muted or not clips.has(kind) or DisplayServer.get_name() == "headless":
		return
	var player := players[cursor % players.size()]
	cursor += 1
	player.stream = variants[kind].pick_random() if variants.has(kind) else clips[kind]
	# Fixed speed preserves the alignment to animation keyframes.
	player.pitch_scale = 1.0
	player.volume_db = -5.0 if variants.has(kind) else -17.0
	player.bus="TownWorldSoundEffects" if variants.has(kind) and AudioServer.get_bus_index("TownWorldSoundEffects")>=0 else "SoundEffects"
	player.play()
	if variants.has(kind) and has_node("/root/WorldSound"): get_node("/root/WorldSound").note_sound("paper")

func play_timed(kind: String, duration: float) -> void:
	play(kind)
	if muted or DisplayServer.get_name()=="headless" or not clips.has(kind): return
	var player:=players[(cursor-1)%players.size()]
	player.pitch_scale=player.stream.get_length()/maxf(0.01,duration)

func synthesize(kind: String) -> AudioStreamWAV:
	var duration := 0.24
	if kind == "deal":
		duration = 0.70
	elif kind == "complete":
		duration = 1.65
	elif kind in ["yes", "no"]:
		duration = 0.65
	var count := int(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = kind.hash()
	var low := 0.0
	for i in range(count):
		var t := float(i) / RATE
		var sample := 0.0
		var noise := random.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.13)
		if kind == "deal" or kind == "flip":
			var period := 0.13 if kind == "deal" else 0.24
			var phase := fmod(t, period) / period
			var envelope := pow(sin(phase * PI), 2.0)
			sample = ((noise - low) * 0.24 + low * 0.45) * envelope * (1.0 - t / duration)
		elif kind == "place" or kind == "tap":
			var frequency := 150.0 if kind == "place" else 360.0
			sample = sin(TAU * frequency * t) * exp(-t * 65.0) * 0.46 + low * exp(-t * 23.0) * 0.38
		else:
			var notes: Array = [659.25, 987.77] if kind == "yes" else [440.0, 349.23]
			if kind == "complete":
				notes = [523.25, 659.25, 783.99, 1046.50]
			for n in range(notes.size()):
				var local_t := t - n * 0.115
				if local_t >= 0:
					var attack := minf(local_t / 0.012, 1.0)
					var decay := exp(-local_t * (3.5 if kind == "complete" else 7.0))
					sample += sin(TAU * float(notes[n]) * local_t) * attack * decay * 0.19
		var fade := minf(t / 0.005, 1.0) * minf((duration - t) / 0.02, 1.0)
		bytes.encode_s16(i * 2, int(clampf(sample * fade, -0.95, 0.95) * 32767.0))
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = RATE
	clip.stereo = false
	clip.data = bytes
	return clip
