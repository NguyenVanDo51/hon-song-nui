class_name TitleArt
extends Control
## title screen diorama: our castle (with its flame) on a grassy mound, a few of our units in front (idle bob), a dragon circling above.
## Pure decoration (mouse ignored); art = the same chibi SVGs as the board, rasterised at screen size.

const UNIT := "res://assets/units/styles/chibi/%s_p.svg"
const CASTLE := "res://assets/terrain/chibi/castle_p.svg"
## [art path, centre x / w, foot y / h, size / h, bob phase]; back to front
const CAST := [
	[CASTLE, 0.50, 0.71, 0.56, -1.0],
	[UNIT % "bird", 0.80, 0.20, 0.28, 0.3],
	[UNIT % "archer", 0.17, 0.83, 0.28, 2.4],
	[UNIT % "elephant", 0.82, 0.84, 0.34, 1.7],
	[UNIT % "soldier", 0.33, 0.88, 0.29, 0.9],
	[UNIT % "hero", 0.56, 0.90, 0.36, 0.0],
]

var _t := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var ink := Style.INK_D
	# mound: ink rim + hard shadow, two grass tones
	var c := Vector2(w * 0.50, h * 0.80)
	var rx := w * 0.49
	var ry := h * 0.17
	_ellipse(c + Vector2(6, 7), rx, ry, Color(ink, 0.85))
	_ellipse(c, rx + 3, ry + 3, ink)
	_ellipse(c, rx, ry, Color("#7fa64e"))
	_ellipse(c + Vector2(0, -ry * 0.18), rx * 0.92, ry * 0.72, Color("#95bd5d"))
	var px := Baked.screen_scale(self)
	for row: Array in CAST:
		var path: String = row[0]
		var phase: float = row[4]
		var fx: float = row[1]
		var fy: float = row[2]
		var fs: float = row[3]
		var s := h * fs
		var foot := Vector2(w * fx, h * fy)
		var bob := 0.0 if phase < 0 else sin(_t * 2.2 + phase) * s * 0.018
		if path.contains("bird"): # glides on a slow figure-eight
			foot += Vector2(sin(_t * 0.6) * w * 0.05, sin(_t * 1.2) * h * 0.03)
			bob = sin(_t * 3.0 + phase) * s * 0.05
		elif phase >= 0:
			_ellipse(foot + Vector2(0, -s * 0.03), s * 0.30, s * 0.06, Color(ink, 0.28))
		var tex := Token.raster(path, s * px)
		if tex == null:
			continue
		# chibi art stands on y ~ 0.78 of its 256 box (castle ground ~ 0.75)
		var r := Rect2(foot.x - s / 2.0, foot.y - s * 0.80 + bob, s, s)
		draw_texture_rect(tex, r, false)

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
