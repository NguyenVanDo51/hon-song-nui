class_name Draw
extends RefCounted
## canvas helpers the Canvas2D original had for free: ellipses, multi-stop radial / linear gradients (vertex colors), curves.

static func arc_points(c: Vector2, rx: float, ry: float, a0 := 0.0, a1 := TAU, rot := 0.0, seg := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var tr := Transform2D(rot, c)
	for i in seg + 1:
		var a := a0 + (a1 - a0) * i / seg
		pts.append(tr * Vector2(cos(a) * rx, sin(a) * ry))
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
		var col: Color = stops[si][1]
		var base := pts.size()
		for i in seg:
			var a := TAU * i / seg
			var p := Vector2(cos(a) * r * t * squash.x, sin(a) * r * t * squash.y)
			pts.append(c + p + focus * (1.0 - t))
			cols.append(col)
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

## text centred on pos (both axes) with optional outline
static func text_c(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, color: Color, outline := 0, outline_col := Color.BLACK) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := pos + Vector2(-w / 2.0, (font.get_ascent(size) - font.get_descent(size)) / 2.0)
	if outline > 0:
		ci.draw_string_outline(font, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_col)
	ci.draw_string(font, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

## text with the given anchor: ax 0 left / 0.5 centre / 1 right; top = true puts pos at the text top, else baseline
static func text_a(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, color: Color, ax := 0.0, top := false, outline := 0, outline_col := Color.BLACK) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := pos + Vector2(-w * ax, font.get_ascent(size) if top else 0.0)
	if outline > 0:
		ci.draw_string_outline(font, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_col)
	ci.draw_string(font, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
