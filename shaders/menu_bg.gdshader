shader_type canvas_item;
// menu backdrop (F1 "storybook" reskin): parchment page, paper fibre, a woodcut landscape in sepia ink
// (three drifting hill ridges with hatch lines, a pale sun ring), darker toasted edges
uniform vec2 size = vec2(1600.0, 900.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float ridge(float x, float W, float H, float ly, float amp, float sp, float f, float i) {
	float u = x / W * f + TIME * sp + i * 10.0;
	return H * (ly - amp * (0.55 * abs(sin(u * 2.1)) + 0.3 * sin(u * 5.3 + 1.0) + 0.15 * sin(u * 11.7)));
}

void fragment() {
	float W = size.x, H = size.y;
	vec2 p = UV * size;
	// parchment: warm centre, toasted edges, fibres + grain
	vec2 c = (UV - vec2(0.5, 0.42)) * vec2(1.0, 1.25);
	float r = length(c);
	vec3 col = mix(vec3(0.965, 0.914, 0.788), vec3(0.902, 0.816, 0.627), smoothstep(0.15, 0.75, r));
	col = mix(col, vec3(0.776, 0.635, 0.420), smoothstep(0.62, 1.05, r));
	float fib = noise(vec2(p.x * 0.012, p.y * 0.2)) * 0.6 + noise(p * 0.08) * 0.4;
	col *= 0.965 + 0.05 * fib;
	col -= 0.035 * step(0.985, hash(floor(p * 0.5)));
	// pale sun ring (printed, not glowing)
	vec2 sun = vec2(W * 0.74, H * 0.36);
	float sd = abs(length(p - sun) - min(W, H) * 0.07);
	col = mix(col, vec3(0.86, 0.66, 0.36), 0.55 * (1.0 - smoothstep(1.0, 2.6, sd)));
	col = mix(col, vec3(0.96, 0.85, 0.62), 0.35 * (1.0 - smoothstep(0.0, min(W, H) * 0.07, length(p - sun))));
	// woodcut ridges back to front: y, amp, ink tone, speed, freq
	float LY[3] = float[](0.6, 0.68, 0.78);
	float AMP[3] = float[](0.12, 0.1, 0.08);
	float SP[3] = float[](0.004, 0.008, 0.014);
	float FR[3] = float[](1.3, 2.1, 3.2);
	vec3 LC[3] = vec3[](vec3(0.89, 0.80, 0.62), vec3(0.84, 0.73, 0.54), vec3(0.78, 0.66, 0.46));
	for (int i = 0; i < 3; i++) {
		float ry = ridge(p.x, W, H, LY[i], AMP[i], SP[i], FR[i], float(i));
		float inside = smoothstep(ry - 0.8, ry + 0.8, p.y);
		// hatch lines inside the ridge, like an engraving
		float hatch = step(0.82, fract((p.x + p.y * 0.6) / (7.0 + float(i) * 2.0)));
		vec3 fill = mix(LC[i], LC[i] * 0.86, hatch * 0.6);
		col = mix(col, fill, inside);
		// ink contour on the ridge line
		col = mix(col, vec3(0.30, 0.21, 0.14), 0.75 * (1.0 - smoothstep(0.6, 1.8, abs(p.y - ry))));
	}
	COLOR = vec4(col, 1.0);
}
