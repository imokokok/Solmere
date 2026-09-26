extends RefCounted
## Real paper scans rendered flat, with distinct deckled / trimmed silhouettes.
const NAMES=["手工纤维纸", "暖白棉纸", "牛皮纸", "旧信笺", "细方格纸", "横线信纸", "半透明描图纸", "叶脉压纹纸", "咖啡渍信纸", "海雾晕染纸", "玫瑰晕染纸", "晨光水彩纸", "丁香云纹纸", "落日流纹纸", "彩色流纹纸", "炭灰水墨纸", "靛蓝刷纹纸", "朱红刷纹纸", "大理石纹纸", "盐花水彩纸", "浅色流纹纸", "细帘纹纸", "航空信纸", "毛边旧纸"]
const FILES=["fibre-kraft.png", "Papier13.png", "Papier9.png", "old-scan.jpg", "Papier11.png", "Papier12.png", "Papier4.png", "Papier13.png", "old-scan.jpg", "watercolor_1_0.jpg", "watercolor_2_0.jpg", "watercolor_3_0.jpg", "watercolor_4_0.jpg", "watercolor_5_0.jpg", "watercolor_6_0.jpg", "watercolor_7_0.jpg", "watercolor_8_0.jpg", "watercolor_9_0.jpg", "watercolor_10_0.jpg", "watercolor_11_0.jpg", "watercolor_12_0.jpg", "Papier5.png", "Papier4.png", "old-scan.jpg"]
const DEPTH=[3.4,1.8,1.1,2.8,0.25,0.45,0.15,1.3,3.1,2.5,1.8,2.1,3.0,2.2,1.5,3.8,0.7,2.8,0.8,4.2,1.2,0.4,0.5,5.2]
const AssetTexture=preload("res://extensions/collage_letter/scripts/asset_texture.gd")
static func texture(index: int) -> Texture2D:
	index=posmod(index,NAMES.size())
	return AssetTexture.get_texture("res://extensions/collage_letter/assets/open_pack/paper/"+FILES[index])

static func outline(rect: Rect2, style: int) -> PackedVector2Array:
	var points:=PackedVector2Array()
	var corners: Array=[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	var depth: float=DEPTH[posmod(style,NAMES.size())]
	depth=minf(depth,minf(rect.size.x,rect.size.y)*0.15)
	for side in 4:
		var a: Vector2=corners[side];var b: Vector2=corners[(side+1)%4]
		var steps:=maxi(3,int(a.distance_to(b)/5))
		for k in steps:
			var t:=float(k)/steps
			# Only normal displacement, always inside the page's export rectangle.
			var inward: Vector2=(b-a).normalized().orthogonal()*-1
			var wobble: float=(0.42+0.30*sin(k*0.83+side*4)+0.20*sin(k*2.13+side))*depth
			points.append(a.lerp(b,t)+inward*wobble*sin(t*PI))
	return points

static func paint(node: CanvasItem, rect: Rect2, style: int, shadow: bool=true) -> void:
	if rect.size.x<=0.01 or rect.size.y<=0.01:return
	style=posmod(style,NAMES.size())
	var poly:=outline(rect,style)
	var coords:=PackedVector2Array()
	for p in poly:coords.append((p-rect.position)/rect.size)
	if shadow:
		for layer in range(3,0,-1):
			var shade:=PackedVector2Array()
			for p in poly:shade.append(p+Vector2(1.5+layer,2.2+layer*1.9))
			node.draw_colored_polygon(shade,Color(0.24,0.18,0.12,0.045+0.012*(4-layer)))
		var thickness:=PackedVector2Array()
		for p in poly:thickness.append(p+Vector2(.7,1.6 if style!=6 else .3))
		node.draw_colored_polygon(thickness,Color("b9ac90"))

	node.draw_colored_polygon(poly,Color(0.99,0.96,0.88,0.42 if style==6 else 1.0))
	node.draw_polygon(poly,PackedColorArray([Color(1,1,1,0.15 if style==6 else (0.63 if style>=9 and style<=20 else 0.77))]),coords,texture(style))
	# An opaque warm wash keeps the photographic scan quiet in the illustrated world.
	if style==0:node.draw_colored_polygon(poly,Color(1.0,0.95,0.80,0.30))
	decoration(node,rect,style)
	var edge:=poly.duplicate();edge.append(edge[0])
	node.draw_polyline(edge,Color(1,0.97,0.86,0.64),0.9,true)
	if style in [0,1,3] and rect.size.x>100:
		# Sparse fraying on the silhouette, not noise printed across the writing area.
		for i in range(0,poly.size()-1,4):
			var direction: Vector2=(poly[i]-rect.get_center()).normalized()
			node.draw_line(poly[i]-direction*0.6,poly[i]+direction*1.1,Color(1,0.96,0.83,0.42),0.7,true)

static func decoration(node: CanvasItem, rect: Rect2, style: int) -> void:
	if style==7:
		var leaf: Texture2D=AssetTexture.get_texture("res://extensions/collage_letter/assets/open_pack/icons/leaves.svg")
		for i in 4:
			var at:=rect.position+rect.size*Vector2(0.08+(i%2)*0.50,0.10+(i/2)*0.47)
			var box:=Rect2(at,rect.size*Vector2(0.31,0.27))
			node.draw_texture_rect(leaf,Rect2(box.position+Vector2.ONE,box.size),false,Color(1,0.98,0.89,0.32))
			node.draw_texture_rect(leaf,box,false,Color(0.48,0.45,0.31,0.13))
	elif style==8:
		# Original stain outlines over a real paper scan, rather than synthetic paper noise.
		var at:=rect.position+rect.size*Vector2(0.77,0.79)
		for ring in 3:
			var points:=PackedVector2Array()
			for i in 65:
				var a:=i/64.0*TAU
				points.append(at+Vector2(cos(a),sin(a))*rect.size.x*(0.115+ring*0.002+sin(a*7)*0.002))
			node.draw_polyline(points,Color(0.40,0.25,0.12,0.07),maxf(0.7,rect.size.x*0.004),true)
	elif style==21:
		for i in 60:
			var y:=rect.position.y+rect.size.y*(i+1)/62.0
			node.draw_line(Vector2(rect.position.x+4,y),Vector2(rect.end.x-4,y),Color(0.98,0.93,0.78,0.14),0.6,true)
	elif style==22:
		for i in 24:
			var x:=rect.position.x+rect.size.x*(i+0.2)/24
			for y in [rect.position.y+7,rect.end.y-7]:
				node.draw_line(Vector2(x,y),Vector2(x+rect.size.x/40,y),Color("bc7867") if i%2==0 else Color("6b8d99"),maxf(2,rect.size.y*0.007),true)
