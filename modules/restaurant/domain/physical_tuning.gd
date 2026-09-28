extends RefCounted
## Shared starting values, expressed in scene pixels, kg and ml; not lab constants.
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/data/physical_interaction.json"))
static func number(section: String, key: String) -> float:
	return float(data[section][key])
