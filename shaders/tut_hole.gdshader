shader_type canvas_item;
// tutorial dim: dark everywhere except rounded holes (box = centre xy, half size zw; radii = corner radius), soft 6 px edge
uniform vec2 size = vec2(1280.0, 720.0);
uniform vec4 dim : source_color = vec4(0.08, 0.05, 0.02, 0.62);
uniform int count = 0;
uniform vec4 boxes[8];
uniform float radii[8];
void fragment() {
	vec2 p = UV * size;
	float a = 1.0;
	for (int i = 0; i < count; i++) {
		vec2 q = abs(p - boxes[i].xy) - boxes[i].zw + radii[i];
		float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radii[i];
		a = min(a, smoothstep(-1.0, 5.0, d));
	}
	COLOR = vec4(dim.rgb, dim.a * a);
}
