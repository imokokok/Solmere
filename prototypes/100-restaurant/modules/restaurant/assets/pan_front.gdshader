shader_type canvas_item;
// The very same pan painting supplies the near wall. No second outline.
void fragment() {
	vec2 p = vec2(655.18,483.71) + UV * vec2(423.85,228.23);
	float u = (p.x-810.0)/124.0;
	float rim = 582.0 + 44.0*sqrt(max(0.0,1.0-u*u));
	if (abs(u)>1.005 || p.y<rim-1.7) discard;
}
