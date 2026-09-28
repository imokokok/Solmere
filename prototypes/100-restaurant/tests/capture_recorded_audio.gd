extends SceneTree
## Real Godot audio-mixer capture, run without --headless. Controlled kitchen states.
var game
var recorder: AudioEffectRecord
var timeline: Array = []
var started := 0

func _initialize() -> void:
	root.size = Vector2i(1280, 757)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	Engine.max_fps = 60
	call_deferred("_run")

func _run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://audio_capture/book.json", "shift_seconds": 600.0})
	root.add_child(game)
	await process_frame
	game._start_shift()
	await process_frame
	var world = game.world
	var sound = world.audio
	# A separate QA window must not mute this capture halfway through when
	# the desktop tester switches apps. Ordinary focus/mute behaviour remains
	# covered by test_recorded_audio; only this controlled recorder is isolated.
	preload("res://tests/recording_focus_isolation.gd").attach(sound)
	sound.stop_all()
	var bus := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus, "KitchenRecordingQA")
	recorder = AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus, recorder)
	for player in sound.loops.values() + sound.effects.values(): player.bus = "KitchenRecordingQA"
	world.spawn_ingredient(game._definition("tomato"))
	var food: RigidBody2D = world._held
	world.drop_into_pan()
	await create_timer(0.8).timeout
	game.session.set_heating(true)
	await create_timer(0.1).timeout
	game.set_process(false)
	food.set_meta("cooking_heat", 3.0)
	world.reactions.set_physics_process(false)
	var thermal: Dictionary=world.reactions.ensure_state(food)
	thermal.faces_c=[140.0,120.0]
	sound.focused = true
	recorder.set_recording_active(true)
	started = Time.get_ticks_msec()
	for id in ["tomato", "egg", "beef"]:
		food.set_meta("definition", game._definition(id))
		await _stage("煎炒：" + str(game._definition(id).get("name")), 2.8)
	food.set_meta("surface_sauce", {"volume_ml": 25.0, "composition_ml": {"ketchup": 25.0}})
	await _stage("浓酱加热冒泡", 3.0)
	world.pan.water_ml = 500.0
	world.pan.water_heat = 100.0
	await _stage("清水煮沸", 3.0)
	world.set_cooking(false)
	world.pan.water_ml = 0.0
	for id in ["oil", "ketchup", "salt", "pepper"]:
		# UI dispense state is set only for the recording, as by actual plating.
		sound.ui_dispense_id = id
		sound.ui_dispense_mode = world.get_dispense_mode(game._definition(id))
		sound.ui_pressure = 0.8
		await _stage("出料：" + str(game._definition(id).get("name")), 2.5)
		sound.ui_dispense_mode = ""
	for id in ["egg_crack", "stir_wood", "stir_metal", "stir_water", "stir_pasta", "chop", "bell"]:
		sound.play_effect(id)
		await _stage("实际播放器：" + id, 1.6)
	sound.muted = true
	await _stage("静音检验", 0.5)
	recorder.set_recording_active(false)
	var clip := recorder.get_recording()
	var args := OS.get_cmdline_user_args()
	var destination := args[0] if not args.is_empty() else "user://recorded-kitchen-preview.wav"
	var error := clip.save_to_wav(destination)
	var file := FileAccess.open(destination + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"capture": "Actual Godot audio bus; controlled kitchen-state demo, not human listening approval", "stages": timeline}, "\t"))
	print("AUDIO MIX CAPTURE ", destination, " error ", error, " bytes ", clip.data.size())
	AudioServer.remove_bus(bus)
	game.queue_free()
	await create_timer(0.2).timeout
	quit(0 if error == OK and clip.data.size() > 100000 else 1)

func _stage(label: String, seconds: float) -> void:
	timeline.append({"seconds": (Time.get_ticks_msec() - started) / 1000.0, "label": label})
	game._notify(label)
	await create_timer(seconds).timeout
