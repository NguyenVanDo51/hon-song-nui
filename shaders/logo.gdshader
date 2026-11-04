shader_type canvas_item;
// gold leaf text: 100° banded gradient sliding left (CSS shimmer, 250% background over 7 s)
uniform float width = 600.0;
varying vec2 lp;
void vertex() { lp = VERTEX; }
vec3 band(float t) {
	vec3 a = vec3(0.722, 0.529, 0.227), b = vec3(1.0, 0.914, 0.659), c = vec3(0.941, 0.788, 0.424), d = vec3(0.659, 0.467, 0.173), e = vec3(0.784, 0.584, 0.247);
	if (t < 0.22) return mix(a, b, t / 0.22);
	if (t < 0.38) return mix(b, c, (t - 0.22) / 0.16);
	if (t < 0.55) return mix(c, d, (t - 0.38) / 0.17);
	if (t < 0.72) return mix(d, b, (t - 0.55) / 0.17);
	return mix(b, e, (t - 0.72) / 0.28);
}
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float t = fract((lp.x + lp.y * 0.18) / (width * 2.5) + TIME / 7.0);
	COLOR = vec4(band(t), c.a);
}
