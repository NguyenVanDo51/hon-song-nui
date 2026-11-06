class_name Draw
extends RefCounted
## canvas helpers the Canvas2D original had for free: ellipses, multi-stop radial / linear gradients (vertex colors), curves.

## transform the current item is drawn with. draw_set_transform* is absolute, so nested helpers compose with this
## (painters that set a transform go through set_xf; every Layer resets it at the start of its _draw)
static var xf := Transform2D.IDENTITY
## font sizes text is rasterised at: each distinct (size, outline) is a glyph cache that is never freed, so other
## sizes are drawn at the next step up and scaled down
const SIZES := [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
	36, 40, 44, 48, 56, 64, 72, 80, 96, 112, 128, 160, 192, 256]
static var _pal_key := ""
static var _pal := {}
static var _cols := {}

static func set_xf(ci: CanvasItem, m: Transform2D) -> void:
	xf = m
	ci.draw_set_transform_matrix(m)

## smallest step >= size
static func font_size(size: float) -> int:
	var n := int(ceil(size - 0.01))
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

## the active chapter's theme with every "#..." string pre-parsed into a Color (factions, terrain, units).
## Rebuilt when Content.use_chapter switches chapter.
static func pal() -> Dictionary:
	if _pal_key != Content.active_chapter or _pal.is_empty():
		_pal_key = Content.active_chapter
		_pal = _parse(Content.theme())
	return _pal

static func _parse(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			out[k] = _parse(v[k])
		return out
	if v is String and v.begins_with("#") and Color.html_is_valid(v):
		return Color(v)
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
	cols.append(stops[0][1])
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
static func text_c(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, color: Color, outline := 0, outline_col := Color.BLACK, scale := 1.0) -> void:
	_text(ci, font, pos, s, size, color, 0.5, 0.5, outline, outline_col, scale)

## text with the given anchor: ax 0 left / 0.5 centre / 1 right; top = true puts pos at the text top, else baseline
static func text_a(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, color: Color, ax := 0.0, top := false, outline := 0, outline_col := Color.BLACK,
	scale := 1.0) -> void:
	_text(ci, font, pos, s, size, color, ax, 1.0 if top else 0.0, outline, outline_col, scale)

## ay: 0.5 = vertically centred on pos, 1 = pos is the top, 0 = pos is the baseline
static func _text(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, color: Color, ax: float, ay: float, outline: int, outline_col: Color, scale: float) -> void:
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
	var ol := maxi(1, int(round(float(outline) * q / size))) if outline > 0 else 0
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
