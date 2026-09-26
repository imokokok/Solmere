extends "main.gd"
# Original 1615f5d mechanics and art. Only isolate host saves by journey/role.
func _ready() -> void:
	var context: Dictionary=get_meta("solmere_context",{})
	var state=get_node_or_null("/root/GameState")
	if state and not context.is_empty():
		var key: String=(str(state.shared_state.get("journey_id","local"))+"_"+str(context.get("current_character","A"))).validate_filename()
		save_path="user://letter_original_"+key+".json"
		preview_path="user://letter_original_"+key+".png"
	await super._ready()

# Keep dynamic photographs in a stable order so saved piece source IDs cannot
# silently point at a different photo after a later roll is developed.
var host_photo_ids: Array=[]
var observatory_paths:Dictionary={}
func _load_host_materials() -> void:
	var film=get_node_or_null("/root/FilmSystem")
	if FileAccess.file_exists(save_path):
		var stored=JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if stored is Dictionary:
			host_photo_ids=stored.get("host_photo_ids",[]).duplicate()
			observatory_paths=stored.get("observatory_paths",{}).duplicate()
	var own_photos: Dictionary={}
	for photo in film.developed_photos() if film!=null else []:
		var id: String=str(photo.id)
		own_photos[id]=photo
		if not host_photo_ids.has(id): host_photo_ids.append(id)
	var folder:="res://extensions/observatory/assets/slideshow/"
	var directory:=DirAccess.open(folder)
	if directory:
		for filename in directory.get_files():
			if filename.get_extension().to_lower() in ["png","jpg","jpeg","webp"]:
				var path:=folder.path_join(filename)
				observatory_paths["observatory_"+path.sha256_text().left(16)]=path
	var observatory=get_node_or_null("/root/ObservatoryState")
	if observatory and not str(observatory.slide_file).is_empty():
		var path:String=str(observatory.slide_file)
		observatory_paths["observatory_"+path.sha256_text().left(16)]=path
	for id in observatory_paths:
		own_photos[id]={"developed_path":observatory_paths[id],"title":"观景台 · "+str(observatory_paths[id]).get_file().get_basename()}
		if not host_photo_ids.has(id):host_photo_ids.append(id)
	for id in host_photo_ids:
		var photo: Dictionary=own_photos.get(str(id),{})
		var path: String=str(photo.get("developed_path",""))
		var available: bool=not path.is_empty() and FileAccess.file_exists(path)
		var title: String=str(photo.get("title","这张照片"))+("" if available else "（原图暂不可用）")
		source_materials.append({"id":"host_"+str(id),"kind":"photo","category":"影像","asset":"paper/Papier6.png","image_path":path if available else "","photo_id":"" if str(id).begins_with("observatory_") else str(id),"title":title,"provenance_zh":"观景台的分享" if str(id).begins_with("observatory_") else "玩家冲洗的照片","provenance_en":"From the observatory" if str(id).begins_with("observatory_") else "Your developed photographs","tint":"ffffff","paper_form":0,"texture_strength":0.12})

func _host_save_data() -> Dictionary:
	var film=get_node_or_null("/root/FilmSystem")
	if film!=null and is_instance_valid(pieces_root):
		for piece in pieces_root.get_children():
			if piece.source_id<0 or piece.source_id>=materials.size(): continue
			var id: String=str(materials[piece.source_id].get("photo_id",""))
			if not id.is_empty() and not bool(film.photo(id).get("used_in_collage",false)): film.mark_photo_use(id,"collage")
	return {"host_photo_ids":host_photo_ids.duplicate(),"observatory_paths":observatory_paths.duplicate()}
