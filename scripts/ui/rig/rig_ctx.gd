class_name RigCtx
extends RefCounted
## a small Canvas2D look-alike over a CanvasItem, so the spec's custom draw code ports line by line:
##   ctx.setTransform(cam.translate(x, y).rotate(a)) -> ctx.set_xf(cam.frame(x, y).rotated_local(deg_to_rad(a)))
##   ctx.setTransform(cam) + world coords       -> ctx.set_world()  (each point mapped by cam.map; w fixed or per point)
##   beginPath / moveTo / lineTo / quadraticCurveTo / bezierCurveTo / arc / ellipse / closePath / rect
##   fill(color) / stroke(color, width)  (width in local units, like ctx.lineWidth); alpha = ctx.globalAlpha
## Paths are flattened to board px as they are built. Fills: ear-clip triangulation, falling back to a fan when the
## polygon self-intersects (Godot's draw_colored_polygon would drop it). Strokes: antialiased polylines + round joins.

var ci: CanvasItem
var cam: RigCam
var alpha := 1.0
var _xf := Transform2D.IDENTITY
var _world := false
var _w := -1.0 # world mode weight (-1 = per point)
var _scale := 1.0 # px per local unit (line widths)
var _subs: Array[PackedVector2Array] = []
var _closed: Array[bool] = []
var _cur := PackedVector2Array()
var _pen := Vector2.ZERO # last point, local coords
var _start := Vector2.ZERO

func _init(p_ci: CanvasItem, p_cam: RigCam) -> void:
	ci = p_ci
	cam = p_cam

func set_xf(m: Transform2D) -> void:
	_world = false
	_xf = m
	_scale = maxf(0.0001, m.x.length())

## world coordinates; w >= 0 keeps every point in one frame (hero-attached 0, target-attached 1)
func set_world(w := -1.0) -> void:
	_world = true
	_w = w
	_scale = cam.k(maxf(0.0, w)) if w >= 0.0 else cam.k(0.5)

func px_per_unit() -> float:
	return _scale

func tp(x: float, y: float) -> Vector2:
	return cam.map(x, y, _w) if _world else _xf * Vector2(x, y)

# ---------- path ----------
func begin_path() -> void:
	_subs.clear()
	_closed.clear()
	_cur = PackedVector2Array()

func _flush(closed: bool) -> void:
	if _cur.size() > 0:
		_subs.append(_cur)
		_closed.append(closed)
	_cur = PackedVector2Array()

func move_to(x: float, y: float) -> void:
	_flush(false)
	_pen = Vector2(x, y)
	_start = _pen
	_cur.append(tp(x, y))

func line_to(x: float, y: float) -> void:
	if _cur.is_empty():
		_start = Vector2(x, y)
	_pen = Vector2(x, y)
	_cur.append(tp(x, y))

func _seg_n(len_local: float) -> int:
	return clampi(int(len_local * _scale / 4.0), 3, 48)

func quad_to(cx: float, cy: float, x: float, y: float) -> void:
	var p0 := _pen
	var c := Vector2(cx, cy)
	var p1 := Vector2(x, y)
	var n := _seg_n(p0.distance_to(c) + c.distance_to(p1))
	for i in range(1, n + 1):
		var t := float(i) / n
		var q := p0 * (1.0 - t) * (1.0 - t) + c * 2.0 * t * (1.0 - t) + p1 * t * t
		line_to(q.x, q.y)

func bezier_to(c1x: float, c1y: float, c2x: float, c2y: float, x: float, y: float) -> void:
	var p0 := _pen
	var c1 := Vector2(c1x, c1y)
	var c2 := Vector2(c2x, c2y)
	var p1 := Vector2(x, y)
	var n := _seg_n(p0.distance_to(c1) + c1.distance_to(c2) + c2.distance_to(p1))
	for i in range(1, n + 1):
		var t := float(i) / n
		var m := 1.0 - t
		var q := p0 * m * m * m + c1 * 3.0 * m * m * t + c2 * 3.0 * m * t * t + p1 * t * t * t
		line_to(q.x, q.y)

## canvas arc(): angles in radians, clockwise unless ccw (y down); joins the current point with a line like canvas
func arc(cx: float, cy: float, r: float, a0: float, a1: float, ccw := false) -> void:
	ellipse(cx, cy, r, r, 0.0, a0, a1, ccw)

func ellipse(cx: float, cy: float, rx: float, ry: float, rot: float, a0: float, a1: float, ccw := false) -> void:
	var span := a1 - a0
	if not ccw:
		if span < 0.0 or span > TAU:
			span = fposmod(span, TAU) if span < 0.0 else TAU
		if is_zero_approx(span) and a1 != a0:
			span = TAU
	else:
		if span > 0.0 or span < -TAU:
			span = -fposmod(-span, TAU) if span > 0.0 else -TAU
	var n := clampi(int(absf(span) * maxf(rx, ry) * _scale / 3.0), 6, 64)
	var cr := cos(rot)
	var sr := sin(rot)
	for i in n + 1:
		var a := a0 + span * i / n
		var ex := cos(a) * rx
		var ey := sin(a) * ry
		line_to(cx + ex * cr - ey * sr, cy + ex * sr + ey * cr)

func close_path() -> void:
	if _cur.size() > 0:
		_flush(true)
		_pen = _start

func rect(x: float, y: float, w: float, h: float) -> void:
	move_to(x, y)
	line_to(x + w, y)
	line_to(x + w, y + h)
	line_to(x, y + h)
	close_path()

func circle(cx: float, cy: float, r: float) -> void:
	_flush(false)
	ellipse(cx, cy, r, r, 0.0, 0.0, TAU)
	close_path()

# ---------- paint ----------
func _subs_now() -> Array:
	var out: Array = _subs.duplicate()
	var cl: Array = _closed.duplicate()
	if _cur.size() > 0:
		out.append(_cur)
		cl.append(false)
	return [out, cl]

func fill(col: Variant) -> void:
	var c := _col(col)
	if c.a <= 0.002:
		return
	ci.draw_set_transform_matrix(Draw.xf)
	var both := _subs_now()
	for pts: PackedVector2Array in both[0]:
		fill_poly(ci, pts, c)

func stroke(col: Variant, width: float) -> void:
	var c := _col(col)
	if c.a <= 0.002:
		return
	ci.draw_set_transform_matrix(Draw.xf)
	var w := maxf(0.6, width * _scale)
	var both := _subs_now()
	var subs: Array = both[0]
	var closed: Array = both[1]
	for i in subs.size():
		var pts: PackedVector2Array = subs[i]
		if pts.size() < 2:
			continue
		if closed[i]:
			pts = pts.duplicate()
			pts.append(pts[0])
		stroke_line(ci, pts, c, w)

func _col(col: Variant) -> Color:
	var c := RigFx.col(col)
	c.a *= alpha
	return c

## filled polygon in board px (no transform): triangulated, fan fallback for self-intersecting outlines
static func fill_poly(item: CanvasItem, pts: PackedVector2Array, c: Color) -> void:
	if pts.size() < 3:
		return
	if pts.size() > 3 and pts[0].distance_squared_to(pts[pts.size() - 1]) < 0.0001:
		pts = pts.slice(0, pts.size() - 1)
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		idx = PackedInt32Array()
		for i in range(1, pts.size() - 1):
			idx.append_array([0, i, i + 1])
	RenderingServer.canvas_item_add_triangle_array(item.get_canvas_item(), idx, pts, PackedColorArray([c]))

## antialiased polyline with round joins / caps (canvas lineJoin / lineCap 'round'): discs where it bends
static func stroke_line(item: CanvasItem, pts: PackedVector2Array, c: Color, w: float) -> void:
	item.draw_polyline(pts, c, w, true)
	if w < 2.5:
		return
	var n := pts.size()
	var closed := pts[0].distance_squared_to(pts[n - 1]) < 0.01
	for i in n:
		var cap := not closed and (i == 0 or i == n - 1)
		if not cap:
			if i == 0 or i == n - 1:
				continue
			var d0 := pts[i] - pts[i - 1]
			var d1 := pts[i + 1] - pts[i]
			if d0.length_squared() < 0.0001 or d1.length_squared() < 0.0001 or absf(d0.angle_to(d1)) < 0.5:
				continue
		item.draw_circle(pts[i], w * 0.5, c, true, -1.0, true)

## text centred on a world/local point, never mirrored; size and outline in local units, scale animates
func text(x: float, y: float, s: String, size: float, col: Color, ink: Color, outline: float, scale := 1.0) -> void:
	var p := tp(x, y)
	var c := col
	c.a *= alpha
	var o := ink
	o.a *= alpha
	ci.draw_set_transform_matrix(Draw.xf)
	Draw.text_c(ci, Style.xbold, p, s, maxi(6, roundi(size * _scale)), c, maxi(1, roundi(outline * _scale)), o, scale)
