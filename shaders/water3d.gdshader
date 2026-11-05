shader_type spatial;
// river surface on the 3D board: vertex colour = theme water colour, slow swell + drifting ripples + glints
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 1.6 + wp.x * 2.3 + wp.z * 1.7) * 0.012;
}

void fragment() {
	float w = sin(TIME * 1.1 + wp.x * 4.0 + sin(wp.z * 3.0 + TIME) * 1.5);
	float glint = smoothstep(0.93, 1.0, sin(TIME * 2.0 + wp.x * 9.1 + wp.z * 7.3) * sin(TIME * 1.3 + wp.z * 5.7));
	vec3 base = pow(COLOR.rgb, vec3(2.2)); // vertex colour is sRGB
	ALBEDO = base * (0.95 + 0.12 * w) + vec3(glint * 0.45);
	EMISSION = base * 0.45; // the board's light is low; keep the river bright like the KayKit art
	ROUGHNESS = 0.22;
	SPECULAR = 0.7;
}
