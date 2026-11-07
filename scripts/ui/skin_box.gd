class_name SkinBox
extends StyleBox
## F1 "woodblock print" box drawn as vectors (crisp at any UI scale): ink edge, uneven hand-cut corners,
## hard offset shadow, optional thin inner line, and for panels a double frame with gold diamonds at the corners.
## Pressed buttons = `shift` the face onto the shadow (content moves with it via content margins).

const SEG := 5

@export var face := Color("#f2e3c0")
@export var edge := Color("#231a15")
@export var edge_w := 3.0
## corner radii tl, tr, br, bl (uneven = "carved by hand")
@export var radii := Vector4(13, 9, 15, 8)
@export var shadow := Vector2(4, 4)
@export var shadow_col := Color("#231a15")
@export var shift := Vector2.ZERO
## thin line just inside the edge (C mockup: inset light line on buttons); alpha 0 = none
@export var inner := Color(1, 1, 1, 0)
@export var inner_inset := 2.5
## panel double frame + diamonds
@export var frame := false
@export var frame_inset := 8.0
@export var diamond := Color("#e3b345")
## flat top highlight band (0 = none)
@export var shine := 0.0
## optional extra soft drop under the hard shadow (panels floating on the board)
@export var drop := 0.0

func _get_draw_rect(rect: Rect2) -> Rect2:
	var r := rect
	r = r.merge(Rect2(rect.position + shadow + shift, rect.size))
	return r.grow(drop + 2.0)

func _draw(ci: RID, rect: Rect2) -> void:
	var body := Rect2(rect.position + shift, rect.size)
	if drop > 0.0:
		for i in 3:
			var g := drop * (i + 1) / 3.0
			RenderingServer.canvas_item_add_polygon(
				ci,
				rounded(body.grow(g).grow_individual(0, 0, 0, g * 0.6), radii + Vector4.ONE * g),
				[Color(0, 0, 0, 0.10)],
			)
	if shadow != Vector2.ZERO:
		RenderingServer.canvas_item_add_polygon(ci, rounded(Rect2(body.position + shadow, body.size), radii), [shadow_col])
	RenderingServer.canvas_item_add_polygon(ci, rounded(body, radii), [edge])
	var inside := body.grow(-edge_w)
	var r_in := (radii - Vector4.ONE * edge_w).max(Vector4.ONE)
	RenderingServer.canvas_item_add_polygon(ci, rounded(inside, r_in), [face])
	if shine > 0.0:
		var band := Rect2(inside.position, Vector2(inside.size.x, inside.size.y * 0.42))
		var r_b := Vector4(r_in.x, r_in.y, 0, 0)
		RenderingServer.canvas_item_add_polygon(ci, rounded(band, r_b), [Color(1, 1, 1, shine)])
	if inner.a > 0.0:
		var ln := inside.grow(-inner_inset)
		_outline(ci, rounded(ln, (r_in - Vector4.ONE * inner_inset).max(Vector4.ONE)), inner, 1.5)
	if frame:
		var fr := body.grow(-frame_inset)
		_outline(ci, rounded(fr, Vector4(6, 4, 7, 4)), Color(edge, 0.85), 1.6)
		for c: Vector2 in [fr.position, Vector2(fr.end.x, fr.position.y), fr.end, Vector2(fr.position.x, fr.end.y)]:
			_diamond(ci, c, 6.0)

func _diamond(ci: RID, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	var big := PackedVector2Array([c + Vector2(0, -r - 2), c + Vector2(r + 2, 0), c + Vector2(0, r + 2), c + Vector2(-r - 2, 0)])
	RenderingServer.canvas_item_add_polygon(ci, big, [edge])
	RenderingServer.canvas_item_add_polygon(ci, pts, [diamond])

func _outline(ci: RID, pts: PackedVector2Array, col: Color, w: float) -> void:
	var loop := pts.duplicate()
	loop.append(pts[0])
	RenderingServer.canvas_item_add_polyline(ci, loop, [col], w, true)

## rounded rect polygon, radii = tl, tr, br, bl (clamped to half the short side)
static func rounded(r: Rect2, rad: Vector4) -> PackedVector2Array:
	var m := minf(r.size.x, r.size.y) * 0.5
	var r0 := minf(rad.x, m)
	var r1 := minf(rad.y, m)
	var r2 := minf(rad.z, m)
	var r3 := minf(rad.w, m)
	var rr: Array[float] = [r0, r1, r2, r3]
	var centers: Array[Vector2] = [
		r.position + Vector2(r0, r0),
		Vector2(r.end.x - r1, r.position.y + r1),
		r.end - Vector2(r2, r2),
		Vector2(r.position.x + r3, r.end.y - r3),
	]
	var start := [PI, PI * 1.5, 0.0, PI * 0.5]
	var pts := PackedVector2Array()
	for i in 4:
		var cr: float = rr[i]
		var cc: Vector2 = centers[i]
		var a0: float = start[i]
		if cr < 0.5:
			pts.append(cc)
			continue
		for s in SEG + 1:
			var a := a0 + PI * 0.5 * s / SEG
			pts.append(cc + Vector2(cos(a), sin(a)) * cr)
	return pts

## builder: content margins + look in one call
static func make(face_c: Color, pad := Vector4(18, 10, 18, 12), opts := { }) -> SkinBox:
	var b := SkinBox.new()
	b.face = face_c
	b.content_margin_left = pad.x
	b.content_margin_top = pad.y
	b.content_margin_right = pad.z
	b.content_margin_bottom = pad.w
	for k: String in opts:
		b.set(k, opts[k])
	return b

## pressed copy: face lands on the shadow, content follows
func pressed() -> SkinBox:
	var b: SkinBox = duplicate()
	b.shift = shadow
	b.shadow = Vector2.ZERO
	b.content_margin_left += shift_x()
	b.content_margin_top += shift_y()
	b.content_margin_right -= shift_x()
	b.content_margin_bottom -= shift_y()
	return b

func shift_x() -> float:
	return shadow.x

func shift_y() -> float:
	return shadow.y
