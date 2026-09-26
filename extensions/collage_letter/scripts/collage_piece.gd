extends Node2D
class_name CollagePiece

const Tape=preload("res://extensions/collage_letter/scripts/tape_art.gd")
var alpha_hit:=false
var painted_png:=""
var is_glued:=false
var glue_coverage:=0.0
var glue_flash:=0.0
var back_visible:=false
var back_texture: ImageTexture
var glue_marks:=PackedVector2Array()
static var back_grain: Image
var silhouette_texture: ImageTexture
var lift:=0.0
var paper_thickness:=0.8
var stack_height:=0.0
var hit_image: Image
var settling: Tween
var tape_style:=0
var strokes:=PackedVector2Array()
var pen_color:=Color("40566b")
var pen_width:=3.0
var source_id := 0
var material_revision:=2
var source_language := "zh"
var texture_pending:=false
var texture: Texture2D:
	set(value):
		texture=value;hit_image=null;silhouette_texture=null;back_texture=null
		texture_pending=value is ViewportTexture
		if is_inside_tree():
			if texture_pending:finish_texture()
			queue_redraw()
var polygon := PackedVector2Array()
var uv := PackedVector2Array()
var is_taped := false
var selected := false
var handwriting := ""
var font: Font

func _ready() -> void:
	if texture_pending:finish_texture()

func finish_texture() -> void:
	# Newly generated catalogue pages are blank until their viewport has rendered.
	# A one-shot connection is automatically removed when a temporary cutout is
	# freed. A suspended coroutine would retain its viewport texture in bulk cuts.
	if not RenderingServer.frame_post_draw.is_connected(texture_rendered):
		RenderingServer.frame_post_draw.connect(texture_rendered,CONNECT_ONE_SHOT)

func texture_rendered() -> void:
	if not is_inside_tree() or not texture_pending:return
	texture_pending=false;hit_image=null;silhouette_texture=null;queue_redraw()
	var below: Array=[]
	for sibling in get_parent().get_children():
		if sibling is CollagePiece:sibling.refresh_stack(below);below.append(sibling)

func _draw() -> void:
	if polygon.size() < 3:
		return
	if source_id==-3:
		if strokes.size()>1: draw_polyline(strokes,pen_color,pen_width,true)
		return
	# Pigment washes lie on the surface; they must not acquire a paper rim.
	if source_id!=-4:
		prepare_silhouette()
		draw_paper_depth()
	# Lift the actual paper face along with its shadow, without changing saved layout.
	draw_set_transform(local_offset(Vector2(0,-lift*4)))
	if source_id == -2:
		Tape.paint(self,polygon,tape_style)
	elif texture:
		if back_visible and not back_texture:rebuild_back()
		draw_polygon(polygon,PackedColorArray([Color.WHITE]),uv,back_texture if back_visible else texture)
		if not alpha_hit:
			var rim:=polygon.duplicate();rim.append(rim[0])
			draw_polyline(rim,Color(1,0.97,0.87,0.36),0.55+paper_thickness*0.35,true)
	else:
		draw_colored_polygon(polygon,Color("f5eddb"))
		draw_string(font,Vector2(-bounds().size.x/2+10,9),handwriting,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("40566b"))
	if glue_flash>0 and texture:
		draw_polygon(polygon,PackedColorArray([Color(1,1,0.82,glue_flash*0.22)]),uv,texture)
	if selected and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var border := polygon.duplicate()
		border.append(polygon[0])
		draw_polyline(border,Color(0.96,0.9,0.75,0.5),0.8,true)
	draw_set_transform(Vector2.ZERO)

func local_offset(world_delta: Vector2) -> Vector2:
	# Window light stays at upper left even when a clipping is rotated or flipped.
	return global_transform.affine_inverse().basis_xform(world_delta)

func prepare_silhouette() -> void:
	if not alpha_hit or not texture or texture_pending or silhouette_texture:return
	var mask:=texture.get_image();mask.convert(Image.FORMAT_RGBA8)
	for y in mask.get_height():
		for x in mask.get_width():mask.set_pixel(x,y,Color(1,1,1,mask.get_pixel(x,y).a))
	silhouette_texture=ImageTexture.create_from_image(mask)

func depth_shape(offset: Vector2, color: Color) -> void:
	if alpha_hit and not silhouette_texture:return
	var contour:=PackedVector2Array()
	for p in polygon:contour.append(p+local_offset(offset))
	if alpha_hit and silhouette_texture:draw_polygon(contour,PackedColorArray([color]),uv,silhouette_texture)
	else:draw_colored_polygon(contour,color)

func draw_paper_depth() -> void:
	var thickness:=clampf(paper_thickness*absf(global_scale.y)*1.9,0.65,3.4)
	if source_id==-2:thickness=0.45
	var air:=0.25 if is_glued or is_taped else 1.1
	var height:=thickness+minf(stack_height,6.0)*0.36+air+lift*8.0
	# Two quiet cast-shadow bands and a close contact line, in the same warm 2D palette.
	depth_shape(Vector2(2.4+height*0.62,3.3+height*0.8),Color(0.27,0.23,0.18,0.075))
	depth_shape(Vector2(1.3+height*0.45,1.8+height*0.63),Color(0.27,0.23,0.18,0.12))
	depth_shape(Vector2(0.7+height*0.22,1.1+height*0.37),Color(0.25,0.22,0.17,0.19-lift*0.05))
	# Opaque paper cross-section: a shaded lower cut edge under a warm fibre edge.
	var face:=Vector2(0,-lift*4)
	depth_shape(face+Vector2(0.55,thickness+0.6),Color("a49a83"))
	depth_shape(face+Vector2(0.2,thickness*0.60),Color("e1d6bc"))
	depth_shape(face+Vector2(-0.30,-0.30),Color("f6eedb"))

func resting_height() -> float:
	if source_id in [-3,-4]:return 0.0
	return paper_thickness*absf(global_scale.y)

func refresh_stack(below: Array) -> void:
	var support:=0.0
	if source_id not in [-3,-4]:
		var rect:=bounds()
		var world_bounds:Rect2=global_transform*rect
		for lower in below:
			if lower.resting_height()<=0.0:continue
			if not world_bounds.intersects(lower.global_transform*lower.bounds()):continue
			# Alpha-aware overlap: transparent letter/sticker margins cannot support paper.
			var overlaps:=false
			for y in 5:
				for x in 5:
					var point:=to_global(rect.position+rect.size*Vector2((x+0.5)/5.0,(y+0.5)/5.0))
					if hit(point) and lower.hit(point):overlaps=true;break
				if overlaps:break
			if overlaps:support=maxf(support,lower.stack_height+lower.resting_height())
	if not is_equal_approx(support,stack_height):stack_height=support;queue_redraw()

func raise_paper() -> void:
	if settling and settling.is_running():settling.kill()
	settling=create_tween()
	settling.tween_property(self,"lift",1.0,0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	queue_redraw()

func bounds() -> Rect2:
	var rect := Rect2(polygon[0],Vector2.ZERO)
	for p in polygon:
		rect = rect.expand(p)
	return rect

func hit(point: Vector2) -> bool:
	if source_id==-3:
		for i in range(1,strokes.size()):
			if to_local(point).distance_to(Geometry2D.get_closest_point_to_segment(to_local(point),strokes[i-1],strokes[i]))<7: return true
		return false
	if not Geometry2D.is_point_in_polygon(to_local(point),polygon): return false
	if alpha_hit and texture:
		if texture_pending:return false
		if not hit_image: hit_image=texture.get_image()
		var pixel:=Vector2(150,119)+to_local(point)
		if source_id==-4:pixel=(to_local(point)-bounds().position)/bounds().size*Vector2(hit_image.get_size())
		return hit_image.get_pixelv(Vector2i(pixel).clamp(Vector2i.ZERO,hit_image.get_size()-Vector2i.ONE)).a>0.1
	return true

func serialize() -> Dictionary:
	var poly: Array = []
	var uvs: Array = []
	for p in polygon:
		poly.append([p.x,p.y])
	for p in uv:
		uvs.append([p.x,p.y])
	var points: Array=[]
	for p in strokes: points.append([p.x,p.y])
	var marks: Array=[]
	for p in glue_marks:marks.append([p.x,p.y])
	return {"material_revision":material_revision,"letter_page":int(get_meta("letter_page",0)),"back_visible":back_visible,"glue_marks":marks,"painted_png":painted_png,"glued":is_glued,"glue_coverage":glue_coverage,"paper_thickness":paper_thickness,"alpha_hit":alpha_hit,"strokes":points,"tape_style":tape_style,"pen_color":pen_color.to_html(),"pen_width":pen_width,"source":source_id,"source_language":source_language,"polygon":poly,"uv":uvs,"position":[position.x,position.y],"rotation":rotation,"scale":[scale.x,scale.y],"taped":is_taped,"text":handwriting}

func texture_point(local: Vector2, image_size: Vector2) -> Vector2:
	return (uv[0]+(local-polygon[0])/Vector2(300,240))*image_size
func add_glue(world: Vector2) -> void:
	var point:=to_local(world)
	if glue_marks.size()>0 and glue_marks[-1].distance_to(point)<8:return
	glue_marks.append(point)
	var covered:=0;var possible:=0
	var rect:=bounds()
	for y in 12:
		for x in 12:
			var sample:=rect.position+rect.size*Vector2((x+0.5)/12.0,(y+0.5)/12.0)
			if not hit(to_global(sample)):continue
			possible+=1
			for mark in glue_marks:
				if mark.distance_to(sample)<36:covered+=1;break
	glue_coverage=float(covered)/maxi(1,possible)
	back_texture=null;queue_redraw()
func rebuild_back() -> void:
	if not texture:return
	var image:=texture.get_image();image.convert(Image.FORMAT_RGBA8)
	if not back_grain:back_grain=load("res://extensions/collage_letter/assets/open_pack/paper/Papier13.png").get_image()
	var grain: Image=back_grain
	for y in image.get_height():
		for x in image.get_width():
			var alpha:=image.get_pixel(x,y).a
			var tone:=grain.get_pixel(x%grain.get_width(),y%grain.get_height()).r
			image.set_pixel(x,y,Color(0.91+tone*0.075,0.865+tone*0.08,0.74+tone*0.12,alpha))
	var dimensions:=Vector2(image.get_size())
	for mark in glue_marks:
		var center:=texture_point(mark,dimensions)
		var radius:=Vector2(36,36)/Vector2(300,240)*dimensions
		for y in range(maxi(0,int(center.y-radius.y)),mini(image.get_height(),int(center.y+radius.y)+1)):
			for x in range(maxi(0,int(center.x-radius.x)),mini(image.get_width(),int(center.x+radius.x)+1)):
				var distance:=((Vector2(x,y)-center)/radius).length()
				if distance>=1:continue
				var pixel:=image.get_pixel(x,y);var wet:=Color(0.99,0.98,0.85,pixel.a)
				image.set_pixel(x,y,pixel.lerp(wet,(1-distance)*0.46))
	if back_texture:back_texture.update(image)
	else:back_texture=ImageTexture.create_from_image(image)

func release_lift() -> void:
	if settling and settling.is_running(): settling.kill()
	settling=create_tween()
	settling.tween_property(self,"lift",0.0,0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	settling.tween_callback(queue_redraw)
func _process(delta: float) -> void:
	if glue_flash>0:glue_flash=maxf(0,glue_flash-delta);queue_redraw()
	if lift>0: queue_redraw()
