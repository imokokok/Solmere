class_name SequencerArrangement
extends Arrangement


func save_project() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("GameState"):
		return true
	var state: Node = tree.root.get_node("GameState")
	var drafts: Dictionary = state.artifacts.get_or_add("minigame_drafts", {})
	drafts["sound_sequencer_mix"] = {
		"version": 1,
		"clips": clips.duplicate(true),
		"muted": muted.duplicate(),
		"gains": gains.duplicate(),
		"prompt": prompt,
		"seed": seed_value,
	}
	return tree.root.get_node("SaveManager").save_or_report("格子音序器工程未能保存")
