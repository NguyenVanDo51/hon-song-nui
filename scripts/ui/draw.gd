class_name Draw
extends RefCounted
## canvas helpers the Canvas2D original had for free: ellipses, multi-stop radial / linear gradients (vertex colors), curves.

## font sizes text is rasterised at: each distinct (size, outline) is a glyph cache that is never freed, so other
## sizes are drawn at the next step up and scaled down
const SIZES := [
	6,
	7,
	8,
	9,
	10,
	11,
	12,
	13,
	14,
	15,
	16,
	17,
	18,
	19,
	20,
	21,
	22,
	23,
	24,
	25,
	26,
	27,
	28,
	29,
	30,
	31,
	32,
	36,
	40,
	44,
	48,
	56,
	64,
	72,
	80,
	96,
	112,
	128,
	160,
	192,
	256,
]
## transform the current item is drawn with. draw_set_transform* is absolute, so nested helpers compose with this
## (painters that set a transform go through set_xf; every Layer resets it at the start of its _draw)
static var xf := Transform2D.IDENTITY
static var _pal := { }
static var _cols := { }

static func set_xf(ci: CanvasItem, m: Transform2D) -> void:
	xf = m
	ci.draw_set_transform_matrix(m)

## smallest step >= size
static func font_size(size: float) -> int:
	var n := ceili(size - 0.01)
	for q: int in SIZES:
		if q >= n:
			return q
	return SIZES[SIZES.size() - 1]

## "#rrggbb" -> Color, parsed once
static func col(hex: String) -> Color:
	var c: Variant = _cols.get(hex)
	if c == null:
		c = Color(hex)
		_cols[hex] = c
	return c

## theme colour that may still be a "#rrggbb" string (Content.terrain) or already a Color (Draw.pal)
static func to_col(v: Variant) -> Color:
	if v is Color:
		return v
	var hex: String = v
	return Color(hex)

## the theme with every "#..." string pre-parsed into a Color (factions, terrain, units); built once
static func pal() -> Dictionary:
	if _pal.is_empty():
		_pal = _parse(Content.theme())
	return _pal

static func _parse(v: Variant) -> Variant:
	if v is Dictionary:
		var out := { }
		for k: Variant in v:
			out[k] = _parse(v[k])
		return out
	if v is String:
		var str_v: String = v
		if str_v.begins_with("#") and Color.html_is_valid(str_v):
			return Color(str_v)
	return v

static func arc_points(c: Vector2, rx: float, ry: float, a0 := 0.0, a1 := TAU, rot := 0.0, seg := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rt := Transform2D(rot, c)
	for i in seg + 1:
		var a := a0 + (a1 - a0) * i / seg
		pts.append(rt * Vector2(cos(a) * rx, sin(a) * ry))
	return pts

static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color, rot := 0.0, seg := 28) -> void:
	var pts := arc_points(c, rx, ry, 0.0, TAU, rot, seg)
	pts.remove_at(pts.size() - 1)
	ci.draw_colored_polygon(pts, color)

## filled arc segment closed by its chord (canvas ellipse(..., a0, a1) + fill)
static func ellipse_arc(ci: CanvasItem, c: Vector2, rx: float, ry: float, a0: float, a1: float, color: Color, seg := 20) -> void:
	ci.draw_colored_polygon(arc_points(c, rx, ry, a0, a1, 0.0, seg), color)

static func ellipse_line(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color, width: float, rot := 0.0, seg := 32) -> void:
	ci.draw_polyline(arc_points(c, rx, ry, 0.0, TAU, rot, seg), color, width, true)

## radial gradient disc: stops = [[t 0..1, Color], ...] from centre to rim r. `focus` shifts the centre stop (canvas two-circle gradient)
static func radial(ci: CanvasItem, c: Vector2, r: float, stops: Array, seg := 28, squash := Vector2.ONE, focus := Vector2.ZERO) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	pts.append(c + focus)
	var c0: Color = stops[0][1]
	cols.append(c0)
	var prev_ring := -1
	for si in range(1, stops.size()):
		var t: float = stops[si][0]
		var stop_col: Color = stops[si][1]
		var base := pts.size()
		for i in seg:
			var a := TAU * i / seg
			var p := Vector2(cos(a) * r * t * squash.x, sin(a) * r * t * squash.y)
			pts.append(c + p + focus * (1.0 - t))
			cols.append(stop_col)
		for i in seg:
			var j := (i + 1) % seg
			if prev_ring < 0:
				idx.append_array([0, base + i, base + j])
			else:
				idx.append_array([prev_ring + i, base + i, base + j, prev_ring + i, base + j, prev_ring + j])
		prev_ring = base
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)

## soft round light: colour at centre fading to transparent at r
static func glow(ci: CanvasItem, c: Vector2, r: float, color: Color, squash := Vector2.ONE) -> void:
	radial(ci, c, r, [[0.0, color], [1.0, Color(color, 0.0)]], 24, squash)

## castle flame (premise "Ngọn Lửa Lâu Đài"): flickering teardrop, 3 tones + ink edge + glow + rising embers.
## b = base point, h = height px, t = ms, sd = per-castle phase, boost = 0..1 flare just after a capture
static func flame(ci: CanvasItem, b: Vector2, h: float, t: float, sd: float, boost := 0.0) -> void:
	h *= 1.0 + 0.07 * sin(t / 90.0 + sd) + 0.05 * sin(t / 53.0 + sd * 2.0) + boost * 1.1
	var w := h * 0.42
	glow(ci, b + Vector2(0, -h * 0.35), h * (0.9 + boost * 0.6), Color(1.0, 0.62, 0.24, 0.32 + boost * 0.3))
	var sway := w * 0.35 * sin(t / 140.0 + sd)
	var tones := [[1.0, Color("#2b2220")], [0.9, Color("#e2462c")], [0.66, Color("#ff9a3c")], [0.38, Color("#ffe48a")]]
	for tone: Array in tones:
		var k: float = tone[0]
		var tc: Color = tone[1]
		var hh := h * k
		var ww := w * k
		var base := b + Vector2(0, -(1.0 - k) * h * 0.12)
		var tip := base + Vector2(sway * k, -hh)
		var left := cubic(tip, base + Vector2(-ww * 0.25, -hh * 0.6), base + Vector2(-ww * 1.05, -hh * 0.25), base, 10)
		var right := cubic(base, base + Vector2(ww * 1.05, -hh * 0.25), base + Vector2(ww * 0.25, -hh * 0.6), tip, 10)
		left.append_array(right.slice(1, right.size() - 1))
		ci.draw_colored_polygon(left, tc)
	for i in 3:
		var ph := fposmod(t / 900.0 + i / 3.0 + sd * 0.13, 1.0)
		var at := b + Vector2(sin(t / 300.0 + i * 2.1 + sd) * w * 0.5, -h * (0.7 + ph * 0.9))
		ci.draw_circle(at, maxf(1.0, h * 0.045 * (1.0 - ph)), Color(1.0, 0.8, 0.4, 1.0 - ph))

## thin smoke over a put-out castle: 3 grey puffs rising + drifting; boost = 0..1 big puff just after it fell
static func smoke(ci: CanvasItem, b: Vector2, h: float, t: float, sd: float, boost := 0.0) -> void:
	for i in 3:
		var ph := fposmod(t / 2200.0 + i / 3.0 + sd * 0.11, 1.0)
		var at := b + Vector2(sin(t / 700.0 + i * 1.7 + sd) * h * 0.12 + ph * h * 0.25, -h * ph * (1.0 + boost))
		var r := h * (0.08 + ph * 0.14) * (1.0 + boost * 1.5)
		ci.draw_circle(at, r, Color(0.25, 0.23, 0.27, minf(0.85, 0.62 * (1.0 - ph) * (1.0 + boost))))

## axis-aligned rect with a multi-stop gradient; vertical = top -> bottom
static func gradient_rect(ci: CanvasItem, r: Rect2, stops: Array, vertical := true) -> void:
	for i in stops.size() - 1:
		var t0: float = stops[i][0]
		var t1: float = stops[i + 1][0]
		var c0: Color = stops[i][1]
		var c1: Color = stops[i + 1][1]
		var pts: PackedVector2Array
		var cols: PackedColorArray
		if vertical:
			var y0 := r.position.y + r.size.y * t0
			var y1 := r.position.y + r.size.y * t1
			pts = PackedVector2Array([Vector2(r.position.x, y0), Vector2(r.end.x, y0), Vector2(r.end.x, y1), Vector2(r.position.x, y1)])
			cols = PackedColorArray([c0, c0, c1, c1])
		else:
			var x0 := r.position.x + r.size.x * t0
			var x1 := r.position.x + r.size.x * t1
			pts = PackedVector2Array([Vector2(x0, r.position.y), Vector2(x1, r.position.y), Vector2(x1, r.end.y), Vector2(x0, r.end.y)])
			cols = PackedColorArray([c0, c1, c1, c0])
		ci.draw_polygon(pts, cols)

static func quad(p0: Vector2, p1: Vector2, p2: Vector2, n := 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		out.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	return out

static func cubic(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n := 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var u := 1.0 - t
		out.append(p0 * u * u * u + p1 * 3 * u * u * t + p2 * 3 * u * t * t + p3 * t * t * t)
	return out

## text centred on pos (both axes) with optional outline. scale draws the size-`size` text scaled (animated pops)
## 5-point star centred at c, outer radius r; soft: plump arms + rounded tips (3 corner-cutting passes); edge = outline
## colour (alpha 0 = none)
static func star(ci: CanvasItem, c: Vector2, r: float, fill: Color, edge := Color(0, 0, 0, 0), width := 1.5) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		pts.append(c + Vector2(cos(a), sin(a)) * (r * 1.12 if i % 2 == 0 else r * 0.56))
	for _pass in 3: # Chaikin: every corner cut -> round tips and inner bends, same overall size (outer pushed out above)
		var cut := PackedVector2Array()
		for i in pts.size():
			var p0 := pts[i]
			var p1 := pts[(i + 1) % pts.size()]
			cut.append(p0.lerp(p1, 0.25))
			cut.append(p0.lerp(p1, 0.75))
		pts = cut
	ci.draw_colored_polygon(pts, fill)
	if edge.a > 0.0:
		pts.append(pts[0])
		ci.draw_polyline(pts, edge, width, true)

static func text_c(
	ci: CanvasItem,
	font: Font,
	pos: Vector2,
	s: String,
	size: int,
	color: Color,
	outline := 0,
	outline_col := Color.BLACK,
	scale := 1.0,
) -> void:
	_text(ci, font, pos, s, size, color, 0.5, 0.5, outline, outline_col, scale)

## text with the given anchor: ax 0 left / 0.5 centre / 1 right; top = true puts pos at the text top, else baseline
static func text_a(
	ci: CanvasItem,
	font: Font,
	pos: Vector2,
	s: String,
	size: int,
	color: Color,
	ax := 0.0,
	top := false,
	outline := 0,
	outline_col := Color.BLACK,
	scale := 1.0,
) -> void:
	_text(ci, font, pos, s, size, color, ax, 1.0 if top else 0.0, outline, outline_col, scale)

## ay: 0.5 = vertically centred on pos, 1 = pos is the top, 0 = pos is the baseline
static func _text(
	ci: CanvasItem,
	font: Font,
	pos: Vector2,
	s: String,
	size: int,
	color: Color,
	ax: float,
	ay: float,
	outline: int,
	outline_col: Color,
	scale: float,
) -> void:
	if size <= 0 or size * scale < 1.0:
		return
	var q := font_size(size) # scale animates without picking another size
	var k := size * scale / q
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, q).x
	var dy := 0.0
	if ay == 0.5:
		dy = (font.get_ascent(q) - font.get_descent(q)) / 2.0
	elif ay == 1.0:
		dy = font.get_ascent(q)
	var ol := maxi(1, roundi(float(outline) * q / size)) if outline > 0 else 0
	if is_equal_approx(k, 1.0):
		var base := pos + Vector2(-w * ax, dy)
		if ol > 0:
			ci.draw_string_outline(font, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, q, ol, outline_col)
		ci.draw_string(font, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, q, color)
		return
	ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(k, k), 0.0, pos))
	var b := Vector2(-w * ax, dy)
	if ol > 0:
		ci.draw_string_outline(font, b, s, HORIZONTAL_ALIGNMENT_LEFT, -1, q, ol, outline_col)
	ci.draw_string(font, b, s, HORIZONTAL_ALIGNMENT_LEFT, -1, q, color)
	ci.draw_set_transform_matrix(xf)
