class_name CoinPop
extends Control
## "+N" popping out of each paying building at turn start: jumps up, lands on the tile, bounces, fades.
## Overlay above the board (draws over units); follows board.tile_rect so zoom / resize keep it on the tile.

const RISE := 0.55 # s: up and back down to the ground
const BOUNCE := 0.25 # s: small hop after landing
const HOLD := 2.2 # s: from start until fade begins
const FADE := 0.6
const STAGGER := 0.07 # s between buildings

var board: Control
var pops: Array[Dictionary] = []

func _init(p_board: Control) -> void:
	board = p_board
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## items: [{x, y, amount}]
func play(items: Array) -> void:
	var t0 := Time.get_ticks_msec() / 1000.0
	for i in items.size():
		var it: Dictionary = items[i]
		pops.append({ "x": it.x, "y": it.y, "text": "+%d" % it.amount, "t0": t0 + i * STAGGER })
	queue_redraw()

func clear() -> void:
	pops.clear()
	queue_redraw()

func _process(_dt: float) -> void:
	if pops.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	pops = pops.filter(func(p: Dictionary) -> bool: return now - p.t0 < HOLD + FADE)
	queue_redraw()

func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var font: Font = Style.bold
	for p: Dictionary in pops:
		var t: float = now - p.t0
		if t < 0.0:
			continue
		var r: Rect2 = board.tile_rect(p.x, p.y)
		var T := r.size.x
		var ground := r.position + Vector2(T * 0.5, T * 0.62)
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
		var fs := maxi(10, int(T * 0.3 * sc))
		var tw := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cr := fs * 0.42 # coin radius
		var w := cr * 2.0 + 3.0 + tw
		var base := ground - Vector2(w * 0.5, h * T)
		# landing shadow shrinks as the number rises
		var sh := clampf(1.0 - h, 0.3, 1.0)
		draw_set_transform(ground, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, w * 0.42 * sh, Color(0, 0, 0, 0.28 * a))
		draw_set_transform(Vector2.ZERO)
		var cc := base + Vector2(cr, -fs * 0.36)
		draw_circle(cc, cr + 2.0, Color(0.17, 0.13, 0.12, a))
		draw_circle(cc, cr, Color(0.98, 0.78, 0.26, a))
		draw_circle(cc, cr * 0.55, Color(0.86, 0.6, 0.14, a))
		var tp := base + Vector2(cr * 2.0 + 3.0, 0)
		draw_string_outline(font, tp, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, fs / 5), Color(0.17, 0.13, 0.12, a))
		draw_string(font, tp, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.86, 0.36, a))
