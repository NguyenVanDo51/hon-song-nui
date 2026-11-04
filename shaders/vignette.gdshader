shader_type canvas_item;
// radial edge darkening: transparent inside 0.3·min(W,H), 60% black at 0.75·max(W,H)
uniform vec2 size = vec2(1600.0, 900.0);
void fragment() {
	vec2 p = UV * size;
	float d = length(p - size * 0.5);
	float r0 = min(size.x, size.y) * 0.3, r1 = max(size.x, size.y) * 0.75;
	COLOR = vec4(0.0, 0.0, 0.0, 0.6 * clamp((d - r0) / (r1 - r0), 0.0, 1.0));
}
