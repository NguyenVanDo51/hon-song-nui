class_name Kit
extends RefCounted
## tiny low-poly mesh builder for the 3D board: flat-shaded, vertex-coloured triangles in one surface
## (a whole terrain or a whole figurine = one mesh = one draw call). Parts are placed through `xf`.

var st := SurfaceTool.new()
var xf := Transform3D.IDENTITY # applied to every vertex added
var uv := false

func _init(with_uv := false) -> void:
	uv = with_uv
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

func commit() -> ArrayMesh:
	return st.commit()

## one triangle; `out` = a direction pointing out of the solid (the winding is fixed from it)
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, out := Vector3.ZERO) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	if out != Vector3.ZERO and n.dot(out) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	var wa := xf * a
	var wb := xf * b
	var wc := xf * c
	var wn := (xf.basis * n).normalized()
	# Godot front faces wind clockwise seen from outside: emit a, c, b
	for p: Vector3 in [wa, wc, wb]:
		st.set_color(col)
		st.set_normal(wn)
		st.add_vertex(p)

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, out: Vector3) -> void:
	tri(a, b, c, col, out)
	tri(a, c, d, col, out)

## axis-aligned box centred on c; `top` colours the upward face; `skip` = side directions to leave out (hidden by a neighbour)
func box(c: Vector3, s: Vector3, col: Color, top: Variant = null, bottom := true, skip: Array = []) -> void:
	var h := s / 2.0
	var p := func(x: float, y: float, z: float) -> Vector3: return c + Vector3(h.x * x, h.y * y, h.z * z)
	var tc: Color = top if top != null else col
	quad(p.call(-1, 1, -1), p.call(1, 1, -1), p.call(1, 1, 1), p.call(-1, 1, 1), tc, Vector3.UP)
	if bottom:
		quad(p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1), p.call(-1, -1, 1), col.darkened(0.3), Vector3.DOWN)
	if not skip.has(Vector3.BACK):
		quad(p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1), col, Vector3.BACK)
	if not skip.has(Vector3.FORWARD):
		quad(p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(-1, 1, -1), col, Vector3.FORWARD)
	if not skip.has(Vector3.RIGHT):
		quad(p.call(1, -1, -1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(1, 1, -1), col, Vector3.RIGHT)
	if not skip.has(Vector3.LEFT):
		quad(p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1), col, Vector3.LEFT)

## frustum along +y from the base centre b (r1 = 0: cone); caps optional
func cyl(b: Vector3, r0: float, r1: float, h: float, col: Color, seg := 10, top: Variant = null, cap_bottom := false) -> void:
	var tc: Color = top if top != null else col
	var t := b + Vector3(0, h, 0)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var out := (d0 + d1).normalized()
		if r1 <= 0.0:
			tri(b + d0 * r0, b + d1 * r0, t, col, out + Vector3(0, r0 / maxf(h, 0.001), 0))
		else:
			quad(b + d0 * r0, b + d1 * r0, t + d1 * r1, t + d0 * r1, col, out)
			tri(t, t + d0 * r1, t + d1 * r1, tc, Vector3.UP)
		if cap_bottom:
			tri(b, b + d0 * r0, b + d1 * r0, col.darkened(0.3), Vector3.DOWN)

func cone(b: Vector3, r: float, h: float, col: Color, seg := 8) -> void:
	cyl(b, r, 0.0, h, col, seg)

## low-poly sphere (squash it with xf for an ellipsoid)
func ball(c: Vector3, r: float, col: Color, seg := 8, rings := 5) -> void:
	for j in rings:
		var p0 := PI * j / rings - PI / 2
		var p1 := PI * (j + 1) / rings - PI / 2
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var v := func(p: float, a: float) -> Vector3: return c + Vector3(cos(p) * cos(a), sin(p), cos(p) * sin(a)) * r
			var q0: Vector3 = v.call(p0, a0)
			var q1: Vector3 = v.call(p0, a1)
			var q2: Vector3 = v.call(p1, a1)
			var q3: Vector3 = v.call(p1, a0)
			var out := ((q0 + q1 + q2 + q3) / 4.0 - c)
			if j == 0:
				tri(q0, q2, q3, col, out)
			elif j == rings - 1:
				tri(q0, q1, q2, col, out)
			else:
				quad(q0, q1, q2, q3, col, out)

## gable roof over a w (x) x d (z) footprint, ridge along x at height h; eaves overhang + a ridge a bit longer
## than the eaves (the upswept look of a village đình)
func roof(c: Vector3, w: float, d: float, h: float, col: Color, ridge_ext := 0.06) -> void:
	var e0 := c + Vector3(-w / 2, 0, -d / 2)
	var e1 := c + Vector3(w / 2, 0, -d / 2)
	var e2 := c + Vector3(w / 2, 0, d / 2)
	var e3 := c + Vector3(-w / 2, 0, d / 2)
	var r0 := c + Vector3(-w / 2 - ridge_ext, h, 0)
	var r1 := c + Vector3(w / 2 + ridge_ext, h, 0)
	quad(e0, e1, r1, r0, col.darkened(0.12), Vector3(0, 1, -1))
	quad(e3, e2, r1, r0, col, Vector3(0, 1, 1))
	tri(e0, e3, r0, col.darkened(0.2), Vector3.LEFT)
	tri(e1, e2, r1, col.darkened(0.2), Vector3.RIGHT)
	quad(e0, e1, e2, e3, col.darkened(0.45), Vector3.DOWN)
	box((r0 + r1) / 2.0 + Vector3(0, 0.012, 0), Vector3(w + ridge_ext * 2 + 0.04, 0.03, 0.04), col.darkened(0.3))

## flat textured quad (overlay meshes): corners a..d CCW from above, uv0..uv3
func uv_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, uvs: Array) -> void:
	for idx: Array in [[0, 2, 1], [0, 3, 2]]: # clockwise seen from above = front
		for k: int in idx:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[k])
			st.add_vertex([a, b, c, d][k])
