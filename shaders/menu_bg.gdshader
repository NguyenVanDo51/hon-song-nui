shader_type canvas_item;
// menu backdrop: dusk sky, sun, three drifting mountain ridges with mist, dark river (port of drawBg in screens.js)
uniform vec2 size = vec2(1600.0, 900.0);

vec3 sky(float t) {
	vec3 c0 = vec3(0.071, 0.031, 0.024); // #120806
	vec3 c1 = vec3(0.227, 0.102, 0.063); // #3a1a10
	vec3 c2 = vec3(0.420, 0.180, 0.090); // #6b2e17
	vec3 c3 = vec3(0.102, 0.047, 0.031); // #1a0c08
	if (t < 0.45) return mix(c0, c1, t / 0.45);
	if (t < 0.7) return mix(c1, c2, (t - 0.45) / 0.25);
	return mix(c2, c3, (t - 0.7) / 0.3);
}

float ridge(float x, float W, float H, float ly, float amp, float sp, float f, float i) {
	float u = x / W * f + TIME * sp + i * 10.0;
	return H * (ly - amp * (0.55 * abs(sin(u * 2.1)) + 0.3 * sin(u * 5.3 + 1.0) + 0.15 * sin(u * 11.7)));
}

void fragment() {
	float W = size.x, H = size.y;
	vec2 p = UV * size;
	vec3 col = sky(p.y / H);
	// sun glow
	vec2 sun = vec2(W * 0.72, H * 0.5);
	float d = length(p - sun) / (H * 0.45);
	vec4 g;
	if (d < 0.15) g = mix(vec4(1.0, 0.745, 0.431, 0.55), vec4(1.0, 0.588, 0.314, 0.25), d / 0.15);
	else g = mix(vec4(1.0, 0.588, 0.314, 0.25), vec4(1.0, 0.47, 0.235, 0.0), clamp((d - 0.15) / 0.85, 0.0, 1.0));
	col = mix(col, g.rgb, g.a);
	float sd = length(p - sun) - min(W, H) * 0.045;
	col = mix(col, vec3(1.0, 0.863, 0.627), 0.9 * (1.0 - smoothstep(-1.0, 1.0, sd)));
	// ridges back to front: y, amp, colour, speed, freq
	float LY[3] = float[](0.52, 0.6, 0.7);
	float AMP[3] = float[](0.12, 0.1, 0.08);
	float SP[3] = float[](0.004, 0.008, 0.014);
	float FR[3] = float[](1.3, 2.1, 3.2);
	vec3 LC[3] = vec3[](vec3(0.290, 0.125, 0.082), vec3(0.200, 0.086, 0.063), vec3(0.133, 0.055, 0.039));
	for (int i = 0; i < 3; i++) {
		float ry = ridge(p.x, W, H, LY[i], AMP[i], SP[i], FR[i], float(i));
		col = mix(col, LC[i], smoothstep(ry - 0.8, ry + 0.8, p.y));
		float m0 = H * (LY[i] - 0.02);
		float k = (p.y - m0) / (H * 0.14);
		if (k > 0.0 && k < 1.0) col = mix(col, vec3(1.0, 0.667, 0.471), 0.07 * (1.0 - abs(k - 0.5) * 2.0));
	}
	// river
	float rv = H * 0.82;
	if (p.y >= rv) col = mix(vec3(0.165, 0.102, 0.102), vec3(0.043, 0.024, 0.02), (p.y - rv) / (H - rv));
	COLOR = vec4(col, 1.0);
}
