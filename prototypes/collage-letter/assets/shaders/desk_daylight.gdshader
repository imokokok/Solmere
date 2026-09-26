shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D desk_screen : hint_screen_texture, filter_linear;
uniform float blind_open = 0.75;
uniform vec3 phase = vec3(1.0,0.0,0.0);
uniform float sun_strength = 1.0;
uniform float sun_shift = 0.0;
uniform float drift = 0.0;
void fragment() {
	vec2 p=UV*vec2(1440.0,900.0);
	vec3 base=texture(desk_screen,SCREEN_UV).rgb;
	float table=smoothstep(286.0,316.0,p.y)*(1.0-smoothstep(828.0,888.0,p.y));
	float depth=clamp((p.y-300.0)/540.0,0.0,1.0);
	float sway=sin(drift*0.13)*7.0+sin(drift*0.071)*4.0;
	float centre=735.0+sun_shift*115.0*depth+sway;
	float width=mix(305.0,380.0,depth);
	float field=(1.0-smoothstep(width-35.0,width+38.0,abs(p.x-centre)))*table;
	float q=mod(p.y-(p.x-720.0)*0.23+sun_shift*50.0+sway,43.0);
	float slat=smoothstep(0.0,4.5,q)*(1.0-smoothstep(11.0,16.0,q));
	float breath=0.94+0.035*sin(drift*0.17)+0.025*sin(drift*0.09+1.4);
	float open= smoothstep(0.0,1.0,blind_open);
	float broad=0.08+0.09*exp(-pow((p.x-centre+(p.y-500.0)*0.25-sin(drift*0.12)*45.0)/210.0,2.0));
	float strength=mix(slat*0.19,broad,open)*sun_strength*field*breath;
	vec3 ambient=vec3(1.0)*phase.x+vec3(0.96,0.83,0.73)*phase.y+vec3(0.51,0.58,0.69)*phase.z;
	vec2 near_letter=(p-vec2(720.0,550.0))/vec2(415.0,400.0);
	float lamp=exp(-dot(near_letter,near_letter)*1.7)*table;
	// Warm reflected room light keeps the letter readable after the sun has set.
	ambient=mix(ambient,vec3(0.94,0.86,0.73),lamp*phase.z*0.8);
	vec3 result=base*ambient;
	vec3 sunlight=mix(vec3(1.0,0.91,0.69),vec3(1.0,0.65,0.38),phase.y);
	result=mix(result,sunlight,strength);
	result=mix(result,vec3(1.0,0.94,0.79),lamp*0.015*sun_strength);
	// The outdoor view becomes blue/dim, rather than retaining the daytime sky.
	float window_mask=step(407.0,p.x)*step(p.x,1067.0)*step(p.y,142.0);
	result=mix(result,result*vec3(0.32,0.48,0.66),window_mask*phase.z*open);
	COLOR=vec4(result,1.0);
}
