class_name CoinPop
extends Control
## "+N" popping out of a tile at turn start (gold per building, hp per healed unit): jumps up, lands, bounces, fades.
## Overlay above the board (draws over units); follows board.tile_rect so zoom / resize keep it on the tile.

const RISE := 0.55 # s: up and back down to the ground
const BOUNCE := 0.25 # s: small hop after landing
const HOLD := 2.2 # s: from start until fade begins
const FADE := 0.6
const STAGGER := 0.07 # s between buildings

var board: BoardBase
var pops: Array[Dictionary] = []

func _init(p_board: Control) -> void:
	board = p_board
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## items: [{x, y, amount}]; kind "coin" lands low on the tile, "heal" higher (over the unit) so both fit one tile
func play(items: Array, kind := "coin", delay := 0.0) -> void:
	var t0 := FX.now() / 1000.0 + delay
	for i in items.size():
		var it: Dictionary = items[i]
		var txt := ("+%d" if kind == "heal" else "%d") % it.amount # coin icon already says "gain"
		pops.append({ "x": it.x, "y": it.y, "text": txt, "t0": t0 + i * STAGGER, "kind": kind })
	queue_redraw()

func clear() -> void:
	pops.clear()
	queue_redraw()

func _process(_dt: float) -> void:
	if pops.is_empty():
		return
	var now := FX.now() / 1000.0
	pops = pops.filter(
		func(p: Dictionary) -> bool:
			return now - p.t0 < HOLD + FADE,
	)
	queue_redraw()

func _draw() -> void:
	var now := FX.now() / 1000.0
	var font: Font = Style.bold
	for p: Dictionary in pops:
		var t0: float = p.t0
		var t: float = now - t0
		var px: int = p.x
		var py: int = p.y
		var text: String = p.text
		if t < 0.0:
			continue
		var r: Rect2 = board.tile_rect(px, py)
		var T := r.size.x
		var heal: bool = p.kind == "heal"
		var ground := r.position + Vector2(T * 0.5, T * (0.3 if heal else 0.62))
		var h := 0.0 # height above ground, in tiles
		var sc := 1.0
		if t < RISE:
			var k := t / RISE
			h = 0.85 * 4.0 * k * (1.0 - k)
			sc = lerpf(0.4, 1.15, minf(1.0, k * 2.5))
		elif t < RISE + BOUNCE:
			var k := (t - RISE) / BOUNCE
			h = 0.14 * 4.0 * k * (1.0 - k)
			sc = lerpf(1.15, 1.0, k)
		var a := 1.0 if t < HOLD else clampf(1.0 - (t - HOLD) / FADE, 0.0, 1.0)
		# fixed font size (per tile size) + scale transform: animating fs would bake a glyph cache per size
		var fs := maxi(10, int(T * 0.3))
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cr := fs * 0.42 # coin radius
		var w := cr * 2.0 + 3.0 + tw
		# landing shadow shrinks as the number rises
		var sh := clampf(1.0 - h, 0.3, 1.0)
		draw_set_transform(ground, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, w * sc * 0.42 * sh, Color(0, 0, 0, 0.28 * a))
		draw_set_transform(ground - Vector2(0, h * T), 0.0, Vector2(sc, sc))
		var base := Vector2(-w * 0.5, 0)
		var ink := Color(0.17, 0.13, 0.12, a)
		var cc := base + Vector2(cr, -fs * 0.36)
		draw_circle(cc, cr + 2.0, ink)
		if heal:
			draw_circle(cc, cr, Color(0.37, 0.66, 0.24, a))
			var arm := cr * 0.58
			var th := maxf(2.0, cr * 0.36)
			draw_rect(Rect2(cc - Vector2(arm, th / 2), Vector2(arm * 2, th)), Color(1, 1, 1, a))
			draw_rect(Rect2(cc - Vector2(th / 2, arm), Vector2(th, arm * 2)), Color(1, 1, 1, a))
		else:
			draw_circle(cc, cr, Color(0.98, 0.78, 0.26, a))
			draw_circle(cc, cr * 0.55, Color(0.86, 0.6, 0.14, a))
		var tp := base + Vector2(cr * 2.0 + 3.0, 0)
		@warning_ignore("integer_division")
		draw_string_outline(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, fs / 5), ink)
		draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.69, 0.93, 0.55, a) if heal else Color(1.0, 0.86, 0.36, a))
	draw_set_transform(Vector2.ZERO)
