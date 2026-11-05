shader_type spatial;
// KayKit texture with the faction colour: saturated cloth hues (not skin / leather / gold) take the team hue,
// so both sides field the same troops in red or blue. Texture sampled raw (sRGB) so the thresholds match the art.
uniform sampler2D albedo_tex : filter_linear_mipmap, repeat_enable;
uniform float team_hue = 0.0;
uniform float team_on = 1.0;
uniform float team_sat = 0.75;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	vec3 h = rgb2hsv(c);
	bool warm = h.x > 0.03 && h.x < 0.17; // skin, leather, wood, gold stay
	if (team_on > 0.5 && h.y > 0.35 && h.z > 0.18 && !warm) {
		c = hsv2rgb(vec3(team_hue, max(h.y, team_sat), h.z));
	}
	ALBEDO = pow(c, vec3(2.2));
	ROUGHNESS = 0.85;
}
