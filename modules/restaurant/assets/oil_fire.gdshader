shader_type canvas_item;
render_mode unshaded;
uniform float intensity = 0.0;
uniform float clock = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
 // A continuous, advecting sheet rooted in the oil surface. No sprite rows.
 float y=1.0-UV.y;
 float height=mix(0.15,0.95,intensity);
 float bend=sin(y*4.0-clock*1.7)*y*0.11;
 vec2 p=vec2(UV.x+bend, y/height);
 float n=noise(p*vec2(7.0,3.0)-vec2(clock*0.23,clock*1.8));
 n+=noise(p*vec2(16.0,7.0)-vec2(0.0,clock*3.2))*0.3;
 float envelope=pow(max(0.0,1.0-abs(p.x-0.5)*2.1),0.6);
 float field=envelope*(0.55+n*0.5)-p.y;
 float alpha=smoothstep(-0.04,0.10,field)*smoothstep(0.0,0.07,y);
 alpha*=smoothstep(0.0,0.13,UV.x)*smoothstep(0.0,0.13,1.0-UV.x);
 vec3 pigment=mix(vec3(0.80,0.22,0.065),vec3(0.99,0.67,0.23),smoothstep(0.08,0.42,field));
 pigment=mix(pigment,vec3(1.0,0.87,0.55),smoothstep(0.40,0.68,field)*0.85);
 COLOR=vec4(pigment,alpha*min(intensity*6.0,0.91));
}
