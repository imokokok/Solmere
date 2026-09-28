shader_type canvas_item;
render_mode unshaded;
varying vec4 object_tint;
void vertex() { object_tint = COLOR; }
void fragment() {
	vec4 pigment = texture(TEXTURE,UV);
	float lightness = dot(pigment.rgb, vec3(0.299,0.587,0.114));
	float spread = max(max(pigment.r,pigment.g),pigment.b)-min(min(pigment.r,pigment.g),pigment.b);
	// Atlas background is a rendering matte, never part of the ingredient.
	if ((spread < 0.035 && lightness > 0.52) || (pigment.r>0.80 && pigment.b>0.80 && pigment.g<0.20)) pigment.a=0.0;
	pigment.rgb = mix(vec3(lightness),pigment.rgb,0.85) * vec3(0.99,0.96,0.90);
	COLOR = pigment * object_tint;
}
