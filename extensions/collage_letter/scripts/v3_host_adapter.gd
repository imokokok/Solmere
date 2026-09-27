extends "v3/letter_office.gd"
## Each journey/character owns its V3 progress; legacy creative saves are untouched.
func _ready() -> void:
 var context:Dictionary=get_meta("solmere_context",{})
 var host=get_node_or_null("/root/GameState")
 if host!=null:
  var key=(str(host.shared_state.get("journey_id","local"))+"_"+str(context.get("current_character",host.current_role))).validate_filename()
  save_path="user://letter_office_v3_"+key+".json"
  preview_path="user://letter_office_v3_"+key+".png"
 super._ready()
