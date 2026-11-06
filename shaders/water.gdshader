shader_type canvas_item;
// board water: the old per-frame GDScript ripples (3 antialiased 7-point polylines + a sparkle per tile), same curves

uniform sampler2D mask : filter_nearest; // 1 texel per tile: r = water, g / b = sparkle spot (hash01 n = 3 / 4)
uniform float tile = 64.0; // T, canvas units per tile
uniform float ph = 0.0; // FX.now() / 1100, wrapped to [0, TAU)
uniform float width = 2.3; // line width, canvas units (max(1, T / 28))
uniform float feather = 1.25; // antialias fringe of an antialiased polyline, canvas units

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float h = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	return length(p - a - ab * h);
}

float wave_pt(float j, float i, vec2 cell) {
	return tile * (0.22 + 0.28 * i) + sin(ph * 2.0 + j * 1.1 + cell.x * 0.9 + i * 2.0 + cell.y) * tile * 0.035;
}

void fragment() {
	ivec2 sz = textureSize(mask, 0);
	vec2 cell = floor(local / tile);
	ivec2 ci = clamp(ivec2(cell), ivec2(0), sz - 1);
	vec4 m = texelFetch(mask, ci, 0);
	if (m.r < 0.5) {
		discard;
	}
	vec2 p = local - cell * tile;
	float step_x = tile / 6.0;
	float k = clamp(floor(p.x / step_x), 0.0, 5.0);
	float wa = 0.0;
	for (int ii = 0; ii < 3; ii++) {
		float i = float(ii);
		float d = 1e9;
		for (int o = -1; o <= 1; o++) {
			float j = k + float(o);
			if (j < 0.0 || j > 5.0) {
				continue;
			}
			vec2 a = vec2(step_x * j, wave_pt(j, i, cell));
			vec2 b = vec2(step_x * (j + 1.0), wave_pt(j + 1.0, i, cell));
			d = min(d, seg_dist(p, a, b));
		}
		wa = max(wa, clamp(1.0 - (d - width * 0.5) / feather, 0.0, 1.0));
	}
	wa *= 0.33;
	float spk = (sin(ph * 3.0 + cell.x * 7.1 + cell.y * 3.3) + 1.0) / 2.0;
	float sa = 0.0;
	if (spk > 0.85 && length(p - vec2(m.g, m.b) * tile) <= tile * 0.03) {
		sa = (spk - 0.85) * 4.0;
	}
	vec3 wave = vec3(0.498, 0.722, 0.831);
	float a = sa + wa * (1.0 - sa);
	if (a <= 0.0) {
		discard;
	}
	COLOR = vec4((vec3(1.0) * sa + wave * wa * (1.0 - sa)) / a, a);
}
