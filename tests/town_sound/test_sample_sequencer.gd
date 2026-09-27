extends SceneTree

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var screen = load("res://extensions/sample_sequencer/SampleSequencerScreen.gd").new()
	screen._build_audio()
	var model: Arrangement = screen._build_arrangement()
	check(model.clips.size() > 10, "Default pattern did not create enough clips")
	var expected_length := 60.0 / 78.0 * 4.0 * 4.0
	check(absf(model.length() - expected_length) < 0.01, "Rendered record is not four bars long: %.3f != %.3f" % [model.length(), expected_length])
	var audio: AudioStreamWAV = model.mix()
	check(audio != null, "Sequencer mix failed: " + model.error)
	if audio != null:
		check(audio.get_length() >= 12.3, "Mixed record is shorter than the pressing minimum")
	check(model.cache.has("sequencer_track_0"), "Rhythm source was not cached")
	check(model.cache.has("sequencer_track_7_length_2"), "Melody duration source was not cached")
	screen.free()
	print("SAMPLE_SEQUENCER_TESTS: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)
