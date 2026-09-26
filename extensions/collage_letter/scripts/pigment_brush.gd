extends RefCounted
const COLORS=[Color("ab684d"),Color("6c8d79"),Color("607e9f"),Color("d3ac58"),Color("ae777d"),Color("85768e"),Color("493f39"),Color("ece0c4")]
var g
var scope:="page"
var radius:=18.0
var color_index:=0
var dilute:=false
var load_amount:=0.0
var active:=false
var target
var source_id: int=-1
var image: Image
var mask: Image
var previous: Image
var last:=Vector2.ZERO
var page_piece:=false
var grain: Image
var current_texture: ImageTexture
var bloom: Image
var page_mask:=PackedVector2Array()
func _init(game) -> void:
	g=game
	grain=load("res://extensions/collage_letter/assets/open_pack/paper/fibre-kraft.png").get_image();grain.resize(256,256)
	bloom=load("res://extensions/collage_letter/assets/open_pack/paper/watercolor_11_0.jpg").get_image();bloom.resize(256,256)
func dip(index: int) -> void:
	color_index=clampi(index,0,COLORS.size()-1);load_amount=1.0;g.audio.play("PAPER_PRESS",0.35);g.say("蘸好颜料了。可以落笔。")
func begin(at: Vector2) -> void:
	if load_amount<=0.02:g.say("笔上还没有颜料，先到文具盒蘸取颜色。");return
	source_id=-1;target=null;page_piece=false
	if scope=="material":
		if g.shelf_open and g.source_preview_id>=0 and g.sources[g.source_preview_id].has_point(at):
			source_id=g.source_preview_id;image=g.get_material_texture(source_id).get_image().duplicate()
		else:
			target=g.pick(at)
			if not is_instance_valid(target) or (target.source_id<0 and target.source_id!=-5):g.say("请选择一张纸片或照片，只涂素材会锁住它的边缘。");return
			image=target.texture.get_image().duplicate()
	else:
		if not g.LETTER.has_point(at):return
		target=g.Piece.new();target.source_id=-4;target.position=g.LETTER.get_center();target.polygon=PackedVector2Array([-g.LETTER.size/2,Vector2(g.LETTER.size.x/2,-g.LETTER.size.y/2),g.LETTER.size/2,Vector2(-g.LETTER.size.x/2,g.LETTER.size.y/2)]);target.uv=PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)]);target.paper_thickness=0;target.alpha_hit=true
		image=Image.create(int(g.LETTER.size.x),int(g.LETTER.size.y),false,Image.FORMAT_RGBA8);g.pieces_root.add_child(target);page_piece=true
	image.convert(Image.FORMAT_RGBA8);previous=image.duplicate();mask=image.duplicate();current_texture=ImageTexture.create_from_image(image)
	if source_id>=0:g.source_overrides[g.L.language+":"+str(source_id)]=current_texture;g.textures[source_id]=current_texture
	else:target.texture=current_texture
	page_mask=g.LetterPaper.outline(g.LETTER,g.letter_paper_style)
	active=true;last=at;dab(at);publish()
func pixel_at(at: Vector2) -> Vector2:
	if source_id>=0:return (at-g.sources[source_id].position)/g.sources[source_id].size*Vector2(image.get_size())
	if page_piece:return at-g.LETTER.position
	return (target.uv[0]+(target.to_local(at)-target.polygon[0])/Vector2(300,240))*Vector2(image.get_size())
func move(at: Vector2) -> void:
	if not active:return
	var distance:=last.distance_to(at)
	var steps:=clampi(ceili(distance/maxf(2,radius*0.28)),1,120)
	for i in range(1,steps+1):dab(last.lerp(at,float(i)/steps))
	last=at;publish()
	g.audio.play("BRUSH_DRAW",0.4)
func dab(at: Vector2) -> void:
	if load_amount<=0:return
	var center:=pixel_at(at)
	var r:=radius
	if not page_piece and source_id<0:r/=maxf(0.25,absf(target.scale.x))
	var area:=Rect2i(Vector2i(center-Vector2.ONE*r),Vector2i.ONE*ceili(r*2+1)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var pos:=Vector2(x,y);var dist:=pos.distance_to(center)/r
			if dist>=1:continue
			if page_piece and (x<6 or y<6 or x>image.get_width()-7 or y>image.get_height()-7):
				if not Geometry2D.is_point_in_polygon(pos+g.LETTER.position,page_mask):continue
			if scope=="material":
				if mask.get_pixel(x,y).a<0.12:continue
				if source_id<0:
					var local: Vector2=(pos/Vector2(image.get_size())-target.uv[0])*Vector2(300,240)+target.polygon[0]
					if not Geometry2D.is_point_in_polygon(local,target.polygon):continue
			var fiber:=grain.get_pixel(posmod(x*3,256),posmod(y*3,256)).r
			var pigment:=bloom.get_pixel(posmod(x,256),posmod(y,256)).get_luminance()
			var edge:=pow(1-dist,0.42)*(0.20+pigment*0.80)
			var amount:=edge*(0.025 if dilute else 0.10)*(0.28+fiber*0.72)*minf(1,load_amount*3)
			var paint: Color=COLORS[color_index];paint.a=amount
			image.set_pixel(x,y,image.get_pixel(x,y).blend(paint))
	load_amount=maxf(0,load_amount-0.0015)
func publish() -> void:
	current_texture.update(image)
	if is_instance_valid(target):target.hit_image=null;target.queue_redraw()
	g.queue_redraw()
func end() -> void:
	if not active:return
	active=false
	if is_instance_valid(target):target.painted_png=Marshalls.raw_to_base64(image.save_png_to_buffer())
	g.changed();g.save_game();g.say("颜料留在纸上了。整页可覆盖纸片，只涂素材会留在边缘内。")
func undo() -> void:
	if not previous:return
	if page_piece and is_instance_valid(target):g.pieces_root.remove_child(target);target.queue_free()
	elif source_id>=0:
		current_texture.update(previous);g.textures[source_id]=current_texture
	elif is_instance_valid(target):
		current_texture.update(previous);target.painted_png=Marshalls.raw_to_base64(previous.save_png_to_buffer());target.hit_image=null;target.queue_redraw()
	previous=null;g.changed();g.save_game()
