shader_type canvas_item;
// night: dark veil with soft holes around our units / buildings / fallen soldiers, plus warm torch light near our buildings.
// premultiplied output so the darkening (alpha) and the torch glow (added colour) happen in one pass.
render_mode blend_premul_alpha;

uniform vec2 board_px = vec2(100.0);
uniform float tile = 48.0;
uniform float time_ms = 0.0;
uniform int n_lights = 0;
uniform vec3 lights[128]; // x, y (tiles), radius (tiles)
uniform int n_torches = 0;
uniform vec2 torches[64];

void fragment() {
	vec2 p = UV * board_px;
	float a = 0.66;
	for (int i = 0; i < n_lights; i++) {
		vec3 l = lights[i];
		float flick = 1.0 + sin(time_ms / 130.0 + l.x * 3.0 + l.y) * 0.03;
		float d = distance(p, (l.xy + 0.5) * tile) / (l.z * tile * flick);
		float g = d < 0.55 ? mix(1.0, 0.75, d / 0.55) : (d < 1.0 ? mix(0.75, 0.0, (d - 0.55) / 0.45) : 0.0);
		a *= 1.0 - g;
	}
	vec3 warm = vec3(0.0);
	for (int i = 0; i < n_torches; i++) {
		float d = distance(p, (torches[i] + vec2(0.5, 0.6)) * tile) / (tile * 1.1);
		warm += vec3(1.0, 0.59, 0.235) * 0.22 * max(0.0, 1.0 - d);
	}
	COLOR = vec4(vec3(0.024, 0.039, 0.125) * a + warm, a);
}
