class_name WaxBox
extends StyleBox
## F1 wax seal (Hết lượt): irregular crimson blob with a pressed rim, a highlight and a crown stamped on top.
## Drawn as vectors; pressed = shifted onto its hard shadow.

@export var wax := Color("#c22f36")
@export var rim := Color("#8f1b22")
@export var ink := Color("#231a15")
@export var shadow := Vector2(5, 5)
@export var shift := Vector2.ZERO
@export var crown := true
## 0..1 extra glow ring (ready to end the turn)
@export var glow := 0.0

func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(12.0)

func _draw(ci: RID, rect: Rect2) -> void:
	var c := rect.get_center() + shift
	var r := minf(rect.size.x, rect.size.y) * 0.5
	if glow > 0.0:
		RenderingServer.canvas_item_add_polygon(ci, blob(c, r + 6.0 + 4.0 * glow, 0.0), [Color(0.89, 0.70, 0.27, 0.45 * glow)])
	if shadow != Vector2.ZERO:
		RenderingServer.canvas_item_add_polygon(ci, blob(c + shadow, r, 0.0), [ink])
	RenderingServer.canvas_item_add_polygon(ci, blob(c, r, 0.0), [ink])
	RenderingServer.canvas_item_add_polygon(ci, blob(c, r - 3.0, 0.0), [wax])
	RenderingServer.canvas_item_add_polygon(ci, blob(c, r * 0.74, 1.3), [rim])
	RenderingServer.canvas_item_add_polygon(ci, blob(c, r * 0.68, 1.3), [wax])
	# highlight
	RenderingServer.canvas_item_add_circle(ci, c + Vector2(-r * 0.36, -r * 0.42), r * 0.12, Color(1, 0.75, 0.68, 0.55))
	if crown:
		var s := r * 0.2
		var y := c.y - r * 0.44
		var pts := PackedVector2Array(
			[
				Vector2(c.x - s * 1.3, y + s * 0.6),
				Vector2(c.x - s * 1.45, y - s * 0.55),
				Vector2(c.x - s * 0.6, y + s * 0.05),
				Vector2(c.x, y - s * 0.95),
				Vector2(c.x + s * 0.6, y + s * 0.05),
				Vector2(c.x + s * 1.45, y - s * 0.55),
				Vector2(c.x + s * 1.3, y + s * 0.6),
			]
		)
		RenderingServer.canvas_item_add_polygon(ci, pts, [rim])
		var loop := pts.duplicate()
		loop.append(pts[0])
		RenderingServer.canvas_item_add_polyline(ci, loop, [Color(1, 0.6, 0.55, 0.6)], 1.2, true)

## wobbly circle: the seal is pressed by hand, never perfectly round
static func blob(c: Vector2, r: float, phase: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var k := 1.0 + 0.035 * sin(a * 5.0 + phase) + 0.02 * sin(a * 9.0 + 1.7 + phase)
		pts.append(c + Vector2(cos(a), sin(a)) * r * k)
	return pts

func pressed() -> WaxBox:
	var b: WaxBox = duplicate()
	b.shift = shadow
	b.shadow = Vector2.ZERO
	b.content_margin_top += 4
	b.content_margin_bottom -= 4
	return b
