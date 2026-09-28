extends RefCounted
## Shared raster art adapter. Only presentation; ingredient IDs and physics stay unchanged.
static var _catalog: Array = []
static var _legacy_atlas_ids: Array = []
static var _cache: Dictionary = {}
static var _sheets: Dictionary = {}
const WHOLE := ["shrimp","mushroom","cheese","chicken","pork","beef","fish","tofu","potato","carrot","cucumber","corn","lotus_root","bread","sausage","salmon","watermelon","durian","century_egg","blue_cheese"]
static var _bounds: Dictionary = {}
static var _handdrawn: Dictionary = {}
static var _team_jpeg: Dictionary = {}
static var _supplementary: Dictionary = {}
static var _outlines: Dictionary = {}
static var _authored_pixels: Dictionary = {}
static var _hit_pixels: Dictionary = {}
const MYSTERY := ["baseball_bat","computer_mouse","slipper","sock","perfume","doll","lipstick","rubber_duck","rock"]
# Physical silhouettes share a common 30 cm skillet reference. The body
# polygon, held artwork and countertop artwork all use this one scale.
static var _physical_scales: Dictionary = {}
static var _physical_definitions: Dictionary = {}
static var _support_rects: Dictionary = {}
static var prepared_enabled := true
static var _prepared: Dictionary = {}

static func _prepared_texture(id: String) -> Texture2D:
	if not prepared_enabled: return null
	if _prepared.is_empty():
		const manifest := "res://modules/restaurant/assets/prepared_food_manifest.json"
		if not FileAccess.file_exists(manifest): return null
		_prepared = JSON.parse_string(FileAccess.get_file_as_string(manifest)).get("foods", {})
	if not _prepared.has(id): return null
	var key := "prepared:" + id
	if _cache.has(key): return _cache[key]
	var entry: Dictionary = _prepared[id]
	var texture: Texture2D = load(entry.path)
	if texture == null: return null
	var pixels := texture.get_image()
	if pixels.is_compressed(): pixels.decompress()
	_authored_pixels[id] = pixels
	pixels.generate_mipmaps()
	var result := ImageTexture.create_from_image(pixels)
	_cache[key] = result
	var b: Array = entry.support
	_support_rects[id] = Rect2(b[0],b[1],b[2],b[3])
	return result

static func support_rect(id: String) -> Rect2:
	if _support_rects.has(id): return _support_rects[id]
	var texture := food(id)
	if texture == null: return Rect2(-39, -39, 78, 78)
	var pixels := texture.get_image()
	if pixels.is_compressed(): pixels.decompress()
	var mask := BitMap.new()
	mask.create_from_image_alpha(pixels, 0.15)
	var used := Rect2i(pixels.get_width(), pixels.get_height(), 0, 0)
	var left := pixels.get_width()
	var top := pixels.get_height()
	var right := -1
	var bottom := -1
	for y in pixels.get_height():
		for x in pixels.get_width():
			if not mask.get_bit(x, y): continue
			left = mini(left, x); right = maxi(right, x)
			top = mini(top, y); bottom = maxi(bottom, y)
	used = Rect2i(left, top, right-left+1, bottom-top+1)
	var fitted := fit(texture, Vector2.ZERO, Vector2(78, 78))
	var scale := fitted.size / texture.get_size()
	var result := Rect2(fitted.position + Vector2(used.position) * scale, Vector2(used.size) * scale)
	_support_rects[id] = result
	return result
const CONTAINER_SCALES := {"oil":1.55, "pepper":1.13, "salt":0.68, "sugar":0.63, "soy_sauce":0.78,
	"ketchup":0.88, "mayonnaise":0.97, "mustard":0.90, "chili_sauce":0.90, "vinegar":0.92}
const LONGEST_SIDE_PX := {
	"carrot":84.0, "cucumber":99.0, "zucchini":99.0, "corn":92.0,
	"eggplant":88.0, "banana":88.0, "noodles":78.0,
	"cabbage":94.0, "lettuce":86.0, "pumpkin":108.0,
	"watermelon":116.0, "durian":115.0,
	"baseball_bat":143.0, "computer_mouse":62.0, "slipper":102.0,
	"sock":81.0, "paper":79.0, "resignation_letter":79.0,
	"toilet_paper":78.0, "toothpaste":69.0, "doll":85.0,
	"rock":79.0, "alarm_clock":71.0, "tennis_ball":45.0,
	"button":23.0, "eraser":33.0, "lipstick":43.0,
	"confetti":28.0, "sponge":44.0
}
static func physical_art_scale(id: String) -> float:
	# The artist's ten rack bottles are calibrated against their actual slots.
	if CONTAINER_SCALES.has(id): return float(CONTAINER_SCALES[id])
	if _physical_scales.has(id): return float(_physical_scales[id])
	if _physical_definitions.is_empty():
		for row in JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/data/ingredients.json")):
			_physical_definitions[str(row.id)] = row
	var definition: Dictionary = _physical_definitions.get(id, {})
	var mass_kg := maxf(0.015, float(definition.get("mass", 0.18)))
	# Cubic-root mass scales the longest visible side like a solid volume.
	# Long produce and irregular objects use measured silhouette overrides.
	var target_px := float(LONGEST_SIDE_PX.get(id, clampf(64.0 * pow(mass_kg / 0.18, 1.0 / 3.0), 35.0, 112.0)))
	var texture := food(id)
	var fit_size := fit(texture, Vector2.ZERO, Vector2(78, 78)).size if texture != null else Vector2(78, 78)
	var value := target_px / maxf(1.0, maxf(fit_size.x, fit_size.y))
	_physical_scales[id] = value
	return value
static func handdrawn_manifest() -> Dictionary:
	if _handdrawn.is_empty():
		_handdrawn = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/assets/handdrawn_manifest.json"))
	return _handdrawn

static func handdrawn_food(id: String) -> Texture2D:
	var entry: Dictionary = handdrawn_manifest().get(id, {})
	if entry.is_empty(): return null
	var prepared := _prepared_texture(id)
	if prepared != null: return prepared
	var key := "handdrawn:" + id
	if _cache.has(key): return _cache[key]
	var source: Texture2D = load(entry.path)
	if source == null: return null
	var pixels := source.get_image()
	if pixels.is_compressed(): pixels.decompress()
	var b: Array = entry.bounds
	# Original file and interior brushwork stay intact. The user's later edge
	# cleanup permission only affects the display copy's narrow matte fringe.
	var region := pixels.get_region(Rect2i(b[0], b[1], b[2], b[3]))
	_authored_pixels[id] = region.duplicate()
	_clean_outline_fringe(region)
	_bleed_matte_edge(region)
	region.generate_mipmaps()
	var result := ImageTexture.create_from_image(region)
	_cache[key] = result
	return result

static func team_jpeg_manifest() -> Dictionary:
	if _team_jpeg.is_empty():
		_team_jpeg = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/assets/team_jpeg_manifest.json"))
	return _team_jpeg

static func team_jpeg_food(id: String) -> Texture2D:
	var entry: Dictionary = team_jpeg_manifest().get(id, {})
	if entry.is_empty(): return null
	var prepared := _prepared_texture(id)
	if prepared != null: return prepared
	var key := "team_jpeg:" + id
	if _cache.has(key): return _cache[key]
	var source: Texture2D = load(entry.path) if ResourceLoader.exists(entry.path) else null
	var pixels := source.get_image() if source != null else Image.load_from_file(entry.path)
	if pixels == null or pixels.is_empty(): return null
	if pixels.is_compressed(): pixels.decompress()
	pixels.convert(Image.FORMAT_RGBA8)
	# The supplied originals are opaque JPEGs on black. Leave source files byte-identical;
	# derive downsampled alpha in memory for every presentation and collision path.
	var scale := minf(1.0, 768.0 / maxf(pixels.get_width(), pixels.get_height()))
	pixels.resize(maxi(1, roundi(pixels.get_width() * scale)), maxi(1, roundi(pixels.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	var width := pixels.get_width()
	var height := pixels.get_height()
	var rows := PackedInt32Array()
	var columns := PackedInt32Array()
	rows.resize(height)
	columns.resize(width)
	for y in height:
		for x in width:
			var c := pixels.get_pixel(x, y)
			if maxf(c.r, maxf(c.g, c.b)) > 0.16:
				rows[y] += 1
				columns[x] += 1
	var left := width
	var right := -1
	var top := height
	var bottom := -1
	for x in width:
		if columns[x] >= 3:
			left = mini(left, x)
			right = x
	for y in height:
		if rows[y] >= 3:
			top = mini(top, y)
			bottom = y
	if right < left or bottom < top: return null
	var box := Rect2i(maxi(0, left - 5), maxi(0, top - 5), mini(width - maxi(0, left - 5), right - left + 11), mini(height - maxi(0, top - 5), bottom - top + 11))
	var region := pixels.get_region(box)
	for y in region.get_height():
		for x in region.get_width():
			var c := region.get_pixel(x, y)
			var brightness := maxf(c.r, maxf(c.g, c.b))
			c.a = smoothstep(0.025, 0.125, brightness)
			if c.a < 0.015: c.a = 0.0
			region.set_pixel(x, y, c)
	_clean_outline_fringe(region)
	_bleed_matte_edge(region)
	region.generate_mipmaps()
	var result := ImageTexture.create_from_image(region)
	_cache[key] = result
	return result

static func supplementary_food(id: String) -> Texture2D:
	if _supplementary.is_empty():
		_supplementary = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/assets/supplementary_manifest.json"))
	var entry: Dictionary = _supplementary.get(id, {})
	if entry.is_empty(): return null
	var prepared := _prepared_texture(id)
	if prepared != null: return prepared
	var key := "supplementary:" + id
	if _cache.has(key): return _cache[key]
	var source: Texture2D = load(entry.path) if ResourceLoader.exists(entry.path) else null
	var sheet := source.get_image() if source != null else Image.load_from_file(entry.path)
	if sheet == null or sheet.is_empty(): return null
	if sheet.is_compressed(): sheet.decompress()
	var bounds: Array = entry.region
	var pixels := sheet.get_region(Rect2i(bounds[0], bounds[1], bounds[2], bounds[3]))
	_remove_atlas_gutter(pixels)
	_clean_outline_fringe(pixels)
	_bleed_matte_edge(pixels)
	pixels.generate_mipmaps()
	var result := ImageTexture.create_from_image(pixels)
	_cache[key] = result
	return result

static func _remove_atlas_gutter(pixels: Image) -> void:
	# Generated atlas cells can contain a few pixels from a neighbouring cell.
	# Never apply this component filter to the artists' multi-part originals.
	var mask := BitMap.new()
	mask.create_from_image_alpha(pixels, 0.08)
	var polygons := mask.opaque_to_polygons(Rect2i(Vector2i.ZERO, pixels.get_size()), 0.8)
	var largest := 0.0
	var areas: Array[float] = []
	for polygon in polygons:
		var area := 0.0
		for i in polygon.size(): area += polygon[i].cross(polygon[(i+1)%polygon.size()])
		areas.append(absf(area))
		largest = maxf(largest, absf(area))
	if largest <= 0.0: return
	var keep: Array[PackedVector2Array] = []
	for i in polygons.size():
		if areas[i] < largest * 0.12: continue
		var expanded := Geometry2D.offset_polygon(polygons[i], 2.0)
		keep.append_array(expanded)
	for y in pixels.get_height():
		for x in pixels.get_width():
			var c := pixels.get_pixel(x,y)
			if c.a <= 0.0: continue
			var inside := false
			for polygon in keep:
				if Geometry2D.is_point_in_polygon(Vector2(x,y), polygon): inside = true; break
			if not inside: c.a = 0.0; pixels.set_pixel(x,y,c)

static func supplied_tomato_food() -> Texture2D:
	var prepared := _prepared_texture("tomato")
	if prepared != null: return prepared
	const path := "res://modules/restaurant/assets/derived/tomato.png"
	if _cache.has("supplied:tomato"): return _cache["supplied:tomato"]
	var source: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if source == null:
		var pixels := Image.load_from_file(path)
		if pixels == null or pixels.is_empty(): return null
		source = ImageTexture.create_from_image(pixels)
	var display := source.get_image()
	if display.is_compressed(): display.decompress()
	_clean_outline_fringe(display)
	_bleed_matte_edge(display)
	display.generate_mipmaps()
	var result := ImageTexture.create_from_image(display)
	_cache["supplied:tomato"] = result
	return result

static func _clean_outline_fringe(pixels: Image) -> void:
	# Repair only achromatic black/white pixels on the outermost pixel ring.
	# Interior lines, pale flesh and the artists' coloured outline remain intact.
	var original := pixels.duplicate() as Image
	var size := original.get_size()
	for y in range(1, size.y - 1):
		for x in range(1, size.x - 1):
			var color := original.get_pixel(x, y)
			if color.a < 0.02: continue
			var light := color.get_luminance()
			if light > 0.15 and light < 0.87: continue
			if maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b)) > 0.12: continue
			var edge := false
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if original.get_pixelv(Vector2i(x,y) + d).a < 0.02: edge = true
			if not edge: continue
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var p: Vector2i = Vector2i(x,y) + d * 2
				if p.x < 1 or p.y < 1 or p.x >= size.x-1 or p.y >= size.y-1: continue
				var pigment := original.get_pixelv(p)
				if pigment.a < 0.98 or absf(pigment.get_luminance()-light) < 0.12: continue
				var solid := true
				for n in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if original.get_pixelv(p+n).a < 0.9: solid = false
				if not solid: continue
				pigment.a = color.a
				pixels.set_pixel(x,y,pigment)
				break

static func _bleed_matte_edge(pixels: Image) -> void:
	# Runtime decontamination only: retain alpha, opaque brushwork and archived
	# originals. Matte RGB at an antialiased edge must not be multiplied twice.
	var original := pixels.duplicate() as Image
	var near_solid := BitMap.new()
	near_solid.create_from_image_alpha(original, 0.98)
	near_solid.grow_mask(3, Rect2i(Vector2i.ZERO, original.get_size()))
	for y in pixels.get_height():
		for x in pixels.get_width():
			if not near_solid.get_bit(x, y): continue
			var edge := original.get_pixel(x, y)
			if edge.a >= 0.98: continue
			var best := INF
			var pigment := edge
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var distance := float(dx * dx + dy * dy)
					if distance >= best: continue
					var p := Vector2i(x + dx, y + dy)
					if p.x < 0 or p.y < 0 or p.x >= pixels.get_width() or p.y >= pixels.get_height(): continue
					var inside := original.get_pixelv(p)
					if inside.a < 0.98: continue
					best = distance
					pigment = inside
			pigment.a = edge.a
			pixels.set_pixel(x, y, pigment)

static func body_outline(id: String) -> PackedVector2Array:
	if _outlines.has(id): return _outlines[id]
	var texture := food(id)
	if texture == null: return PackedVector2Array()
	var mask := BitMap.new()
	var pixels := texture.get_image()
	if pixels.is_compressed(): pixels.decompress()
	mask.create_from_image_alpha(pixels, 0.1)
	var points := PackedVector2Array()
	var rect := fit(texture, Vector2.ZERO, Vector2(78, 78))
	for polygon in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO, mask.get_size()), 1.0):
		for point in polygon:
			points.append((rect.position + point / texture.get_size() * rect.size) * physical_art_scale(id))
	# Stable convex support approximation, sharing the rendered art's coordinates.
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[-1]): hull.remove_at(hull.size() - 1)
	_outlines[id] = hull
	return hull

static func authored_alpha_at(id: String, body_point: Vector2) -> float:
	var texture := handdrawn_food(id)
	if texture == null: return 0.0
	var rect := fit(texture, Vector2.ZERO, Vector2(78, 78))
	var uv := (body_point / physical_art_scale(id) - rect.position) / rect.size
	if uv.x < 0 or uv.y < 0 or uv.x >= 1 or uv.y >= 1: return 0.0
	var pixels: Image = _authored_pixels[id]
	return pixels.get_pixelv(Vector2i(uv * texture.get_size())).a

static func alpha_at(id: String, art_point: Vector2) -> float:
	if not art_point.is_finite(): return 0.0
	var texture := food(id)
	if texture == null: return 0.0
	var rect := fit(texture, Vector2.ZERO, Vector2(78, 78))
	var uv := (art_point - rect.position) / rect.size
	if uv.x < 0 or uv.y < 0 or uv.x >= 1 or uv.y >= 1: return 0.0
	if not _hit_pixels.has(id):
		var pixels := texture.get_image()
		if pixels.is_compressed(): pixels.decompress()
		_hit_pixels[id] = pixels
	return (_hit_pixels[id] as Image).get_pixelv(Vector2i(uv * texture.get_size())).a

static func food(id: String) -> Texture2D:
	# Existing Solmere procurement art, shared by the street and the real kitchen.
	if id in ["herbs", "sea_beans", "star_salt"]:
		return load("res://modules/restaurant/assets/procurement/%s.png" % id)
	# User-supplied tomato, cropped and given alpha without repainting its RGB.
	# This shared source reaches storage, bodies, plating, photographs and pages.
	if id == "tomato": return supplied_tomato_food()
	var authored := handdrawn_food(id)
	if authored != null: return authored
	var team_source := team_jpeg_food(id)
	if team_source != null: return team_source
	var new_art := supplementary_food(id)
	if new_art != null: return new_art
	if id in MYSTERY and id!="sock": return mapped_sprite("odd_objects",str(MYSTERY.find(id)))
	# The original atlas has a fixed authored order. Catalog additions and
	# removals must never shift another ingredient onto the wrong painting.
	if _legacy_atlas_ids.is_empty():
		_legacy_atlas_ids = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/assets/legacy_food_atlas_ids.json"))
	var index := _legacy_atlas_ids.find(id)
	if index < 0: return null
	var sheet := index/20+1
	var item := index%20
	if WHOLE.has(id):
		sheet = 5
		item = WHOLE.find(id)
	var key := "%d:%d" % [sheet,item]
	if _cache.has(key): return _cache[key]
	if _bounds.is_empty(): _bounds = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/assets/food_bounds.json"))
	if not _bounds.has(key): return null
	var values: Array = _bounds[key]
	var path := "res://modules/restaurant/assets/food_atlas_%d.png" % sheet
	if not ResourceLoader.exists(path): return null
	var texture := prepared_region(path,Rect2i(values[0],values[1],values[2],values[3]))
	_cache[key] = texture
	return texture

static func prepared_region(path: String,rect: Rect2i) -> Texture2D:
	# All consumers receive the same alpha-bearing texture, including photographs,
	# clipped physical slices and authoring stickers. Never rely on a scene shader.
	var key := path+str(rect)
	if _cache.has(key): return _cache[key]
	var texture: Texture2D = load(path)
	var pixels := texture.get_image()
	if pixels.is_compressed(): pixels.decompress()
	pixels = pixels.get_region(rect)
	pixels.convert(Image.FORMAT_RGBA8)
	var magenta := false
	var cyan := false
	var native_alpha := pixels.detect_alpha()!=Image.ALPHA_NONE
	for corner in [Vector2i.ZERO,Vector2i(pixels.get_width()-1,0),Vector2i(0,pixels.get_height()-1)]:
		var c := pixels.get_pixelv(corner)
		if c.r>0.8 and c.b>0.8 and c.g<0.25: magenta = true
		if c.g>0.8 and c.b>0.8 and c.r<0.25: cyan = true
	for y in pixels.get_height():
		for x in pixels.get_width():
			var c := pixels.get_pixel(x,y)
			if native_alpha:
				pass
			elif cyan:
				var amount := clampf(minf(c.g,c.b)-c.r,0,1)
				if amount>0.04:
					c.a*=1-amount
					if c.a>0.01:
						c.g=clampf((c.g-amount)/c.a,0,1)
						c.b=clampf((c.b-amount)/c.a,0,1)
						c.r=clampf(c.r/c.a,0,1)
			elif magenta:
				var key_amount := minf(c.r,c.b)-c.g
				if key_amount > 0.04:
					c.a *= 1.0-clampf(key_amount,0,1)
					if c.a>0.01:
						c.r = clampf((c.r-(1-c.a))/c.a,0,1)
						c.b = clampf((c.b-(1-c.a))/c.a,0,1)
						c.g = clampf(c.g/c.a,0,1)
			else:
				# Compatibility for retired checker-matte atlases during an import.
				if maxf(c.r,maxf(c.g,c.b))-minf(c.r,minf(c.g,c.b))<0.055 and c.get_luminance()>0.48: c.a=0
			# Quantized near-transparent atlas matte must not tint a rectangular
			# area behind the ingredient on bright countertops or photographs.
			if c.a<0.05: c=Color.TRANSPARENT
			pixels.set_pixel(x,y,c)
	var result := ImageTexture.create_from_image(pixels)
	_cache[key] = result
	return result

static func gear(index: int) -> Texture2D:
	return mapped_sprite("kitchen_props",str(index))

static func guest(id: String) -> Texture2D:
	var ids := ["lin","jiao","chen","qi","mei","xu","tao","mo","zhou"]
	return mapped_sprite("customers",str(maxi(0,ids.find(id))))

static func mapped_sprite(atlas: String, id: String) -> Texture2D:
	var path := "res://modules/restaurant/assets/"+atlas
	if not ResourceLoader.exists(path+".png") or not FileAccess.file_exists(path+".json"): return null
	var bounds = JSON.parse_string(FileAccess.get_file_as_string(path+".json"))
	if not bounds is Dictionary or not bounds.has(id): return null
	var r: Array = bounds[id]
	return prepared_region(path+".png",Rect2i(r[0],r[1],r[2],r[3]))

static func tile(path: String,index: int,grid: Vector2i) -> Texture2D:
	var key := path+":"+str(index)
	if _cache.has(key): return _cache[key]
	if not ResourceLoader.exists(path): return null
	if not _sheets.has(path):
		var texture: Texture2D = load(path)
		var image := texture.get_image()
		if image.is_compressed(): image.decompress()
		_sheets[path] = {"texture":texture,"image":image}
	var sheet: Dictionary = _sheets[path]
	var dimensions: Vector2i = sheet.image.get_size()
	var cell := Vector2i(dimensions.x/grid.x,dimensions.y/grid.y)
	var region := Rect2i(Vector2i(index%grid.x,index/grid.x)*cell,cell)
	var pixels: Image = sheet.image.get_region(region)
	var bounds := pixels.get_used_rect()
	if not bounds.has_area(): return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet.texture
	atlas.region = Rect2(region.position+bounds.position,bounds.size)
	atlas.filter_clip = true
	_cache[key] = atlas
	return atlas

static func fit(texture: Texture2D,center: Vector2,maximum: Vector2) -> Rect2:
	var dimensions := texture.get_size()
	var factor := minf(maximum.x/dimensions.x,maximum.y/dimensions.y)
	return Rect2(center-dimensions*factor/2,dimensions*factor)
