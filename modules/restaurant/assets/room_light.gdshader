shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 paint = texture(TEXTURE, UV);
	vec2 room = UV * vec2(1600.0, 900.0);
	float window_light = exp(-dot((room - vec2(780.0, 380.0)) / vec2(620.0, 480.0), (room - vec2(780.0, 380.0)) / vec2(620.0, 480.0)));
	float counter_light = exp(-dot((room - vec2(920.0, 690.0)) / vec2(680.0, 195.0), (room - vec2(920.0, 690.0)) / vec2(680.0, 195.0)));
	// Retain the commissioned painting; broad bounced light softens the blue
	// cabinet's transition into the ochre wall, with no rectangular overlay.
	float cabinet_bounce = exp(-dot((room - vec2(350.0, 390.0)) / vec2(175.0, 380.0), (room - vec2(350.0, 390.0)) / vec2(175.0, 380.0)));
	vec3 pigment = paint.rgb * vec3(1.015, 0.993, 0.96);
	pigment = mix(pigment, vec3(0.93, 0.78, 0.58), cabinet_bounce * 0.10);
	pigment += vec3(0.022, 0.013, 0.004) * (window_light + counter_light * 0.55);
	float edge = smoothstep(0.30, 0.78, length((UV - vec2(0.52, 0.48)) * vec2(0.95, 0.72)));
	pigment *= 1.0 - edge * 0.08;
	COLOR = vec4(pigment, paint.a);
}
