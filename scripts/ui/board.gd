class_name Board
extends Control
## the battlefield: cached terrain layer + animated water, buildings, fallen soldiers, overlays, units, effects, night, ambience.
## Looks come from the theme; any unit / terrain "img" replaces the procedural drawing. Port of src/ui/render.js.
## Layers (bottom -> top): terrain (redrawn only on fit = cached) | dyn | fx normal | fx additive | numbers | night | ambient.

signal tile_clicked(x: int, y: int)
signal hover_changed(tile: Variant)
signal cancel_requested

var s: Dictionary = {}
var fx: FX
var T := 48.0
## what the game screen wants shown (see GameScreen.build_view)
var view := { "hide": {}, "sprites": [], "hp": null, "busy": false, "sel": null, "selMine": false, "reach": null, "attackable": [],
	"dest": null, "targets": [], "target": null, "path": null, "info": null, "buyAt": null, "hover": null }
var hover: Variant = null
var _stage: Control
var _terrain: Layer
var _layers: Array[Layer] = []
var _night: ColorRect
var _clouds := []
var _motes := []

class Layer extends Control:
	var fn: Callable
	func _draw() -> void:
		fn.call(self)

static func hash01(x: int, y: int, n: int) -> float:
	return float((((x * 73856093) ^ (y * 19349663) ^ (n * 83492791)) & 0xFFFFFFFF) % 1000) / 1000.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = false
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_terrain = _layer(_draw_terrain)
	_layers.append(_layer(_draw_dyn))
	_layers.append(_layer(func(ci: CanvasItem) -> void: fx.draw_over(ci, T, FX.now())))
	var add := _layer(func(ci: CanvasItem) -> void: fx.draw_add(ci, T, FX.now()))
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.material = mat
	_layers.append(add)
	_layers.append(_layer(func(ci: CanvasItem) -> void: fx.draw_top(ci, T, FX.now())))
	_night = ColorRect.new()
	_night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/night.gdshader")
	_night.material = sm
	_stage.add_child(_night)
	_layers.append(_layer(_draw_ambient))
	var amb_add := _layer(_draw_fireflies)
	amb_add.material = mat
	_layers.append(amb_add)
	for i in 3:
		_clouds.append({ "x": i * 5 - 3, "y": 1 + i * 3, "r": 3 + i, "v": 0.0004 + i * 0.0001 })

func _layer(fn: Callable) -> Layer:
	var l := Layer.new()
	l.fn = fn
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(l)
	return l

func set_state(state: Dictionary) -> void:
	s = state
	_motes.clear()

## pick the tile size for the space available
func fit(avail: Vector2) -> void:
	if s.is_empty():
		return
	T = clampf(floor(minf(avail.x / s.w, avail.y / s.h)), 22.0, 96.0)
	var px := Vector2(T * s.w, T * s.h)
	custom_minimum_size = px
	size = px
	_stage.size = px
	for l: Control in [_terrain, _night] + _layers:
		l.size = px
	_terrain.queue_redraw()

func refresh_terrain() -> void:
	_terrain.queue_redraw()

func _process(_dt: float) -> void:
	if s.is_empty() or not is_visible_in_tree():
		return
	var t := FX.now()
	fx.update(t)
	_stage.position = fx.shake_offset(t) * T
	for l: Layer in _layers:
		l.queue_redraw()
	_night.visible = s.night
	if s.night:
		_update_night(t)

# ---------- input ----------
func _tile_at_mouse(p: Vector2) -> Variant:
	var x := int(floor(p.x / T))
	var y := int(floor(p.y / T))
	return Vector2i(x, y) if Game.tile_at(s, x, y) != null else null

func _gui_input(ev: InputEvent) -> void:
	if s.is_empty():
		return
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			var tl: Variant = _tile_at_mouse(ev.position)
			if tl != null:
				tile_clicked.emit(tl.x, tl.y)
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			cancel_requested.emit()
		accept_event()
	elif ev is InputEventMouseMotion:
		var tl: Variant = _tile_at_mouse(ev.position)
		if tl != hover:
			hover = tl
			hover_changed.emit(tl)

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hover != null:
		hover = null
		hover_changed.emit(null)

# ---------- terrain (cached) ----------
func _draw_terrain(ci: CanvasItem) -> void:
	if s.is_empty():
		return
	for y in s.h:
		for x in s.w:
			var t: String = s.tiles[y][x]
			var p: Dictionary = Content.terrain(t)
			var tex := Token.image(p.get("img"))
			if tex:
				ci.draw_texture_rect(tex, Rect2(x * T, y * T, T, T), false)
			else:
				_paint(ci, p.paint, x * T, y * T, p, x, y)
	# shorelines: sand on land edges touching water
	for y in s.h:
		for x in s.w:
			var t: String = s.tiles[y][x]
			if Rules.TERRAIN[t].get("water", false) or t == "=":
				continue
			var X: float = x * T
			var Y: float = y * T
			var w := T * 0.12
			var sand := Color(0.788, 0.718, 0.541, 0.53)
			if Game.tile_at(s, x + 1, y) == "~": ci.draw_rect(Rect2(X + T - w, Y, w, T), sand)
			if Game.tile_at(s, x - 1, y) == "~": ci.draw_rect(Rect2(X, Y, w, T), sand)
			if Game.tile_at(s, x, y + 1) == "~": ci.draw_rect(Rect2(X, Y + T - w, T, w), sand)
			if Game.tile_at(s, x, y - 1) == "~": ci.draw_rect(Rect2(X, Y, T, w), sand)
	# soft grid
	var gc := Color(0, 0, 0, 0.13)
	for x in range(1, s.w):
		ci.draw_line(Vector2(x * T + 0.5, 0), Vector2(x * T + 0.5, s.h * T), gc, 1.0)
	for y in range(1, s.h):
		ci.draw_line(Vector2(0, y * T + 0.5), Vector2(s.w * T, y * T + 0.5), gc, 1.0)

## polygon filled with a linear gradient from p0 (c0) to p1 (c1)
static func _grad_poly(ci: CanvasItem, pts: PackedVector2Array, p0: Vector2, p1: Vector2, c0: Color, c1: Color) -> void:
	var axis := p1 - p0
	var len2 := axis.length_squared()
	var cols := PackedColorArray()
	for p in pts:
		cols.append(c0.lerp(c1, clampf((p - p0).dot(axis) / len2, 0.0, 1.0)))
	ci.draw_polygon(pts, cols)

func _paint(ci: CanvasItem, kind: String, X: float, Y: float, p: Dictionary, x: int, y: int) -> void:
	match kind:
		"field", "village":
			ci.draw_rect(Rect2(X, Y, T, T), Color(p.base))
			for i in range(1, 5):
				var yy := Y + T * i / 5.0
				ci.draw_polyline(Draw.quad(Vector2(X + 2, yy), Vector2(X + T / 2, yy + (hash01(x, y, i) - 0.5) * T * 0.12), Vector2(X + T - 2, yy), 8),
					Color(p.line), maxf(1.0, T / 40.0), true)
			for i in 6:
				ci.draw_rect(Rect2(X + hash01(x, y, i) * T, Y + hash01(x, y, i + 20) * T, maxf(1.0, T / 30.0), maxf(2.0, T / 14.0)),
					Color("#7da350") if hash01(x, y, i + 9) > 0.5 else Color("#4c6b30"))
		"forest":
			ci.draw_rect(Rect2(X, Y, T, T), Color(p.base))
			var trees := [[0.25, 0.42], [0.72, 0.38], [0.5, 0.68], [0.2, 0.86], [0.8, 0.84]]
			for i in trees.size():
				var cx: float = X + T * (trees[i][0] + (hash01(x, y, i) - 0.5) * 0.08)
				var by: float = Y + T * trees[i][1]
				var h := T * (0.36 + hash01(x, y, i + 5) * 0.1)
				Draw.ellipse(ci, Vector2(cx + T * 0.04, by + T * 0.02), h * 0.38, h * 0.12, Color(0, 0, 0, 0.2), 0.0, 14)
				ci.draw_rect(Rect2(cx - T * 0.015, by - h * 0.15, T * 0.03, h * 0.18), Color("#4a3420"))
				ci.draw_colored_polygon(PackedVector2Array([Vector2(cx, by - h), Vector2(cx - h * 0.36, by - h * 0.12), Vector2(cx + h * 0.36, by - h * 0.12)]), Color(p.tree))
				ci.draw_colored_polygon(PackedVector2Array([Vector2(cx, by - h), Vector2(cx - h * 0.05, by - h * 0.12), Vector2(cx + h * 0.36, by - h * 0.12)]), Color(p.tree2))
		"hill":
			ci.draw_rect(Rect2(X, Y, T, T), Color(p.base))
			for m: Array in [[0.36, 0.8, 0.34, 0.36], [0.7, 0.86, 0.26, 0.26]]:
				var c := Vector2(X + T * m[0], Y + T * m[1])
				var rx: float = T * m[2]
				var ry: float = T * m[3]
				_grad_poly(ci, Draw.arc_points(c, rx, ry, PI, TAU, 0.0, 18), c - Vector2(rx, ry), c + Vector2(rx, 0), Color(p.hill2), Color(p.hill))
		"mountain":
			ci.draw_rect(Rect2(X, Y, T, T), Color(p.base))
			for pk: Array in [[0.32, 0.3, 0.55], [0.62, 0.36, 0.82]]:
				var px: float = pk[0]
				var w: float = pk[1]
				var h: float = pk[2]
				var P := func(a: float, b: float) -> Vector2: return Vector2(X + T * a, Y + T * b)
				ci.draw_colored_polygon(PackedVector2Array([P.call(px - w, 0.92), P.call(px, 0.92 - h), P.call(px + w, 0.92)]), Color(p.rock))
				ci.draw_colored_polygon(PackedVector2Array([P.call(px, 0.92 - h), P.call(px + w, 0.92), P.call(px + w * 0.2, 0.92)]), Color(p.rock2))
				ci.draw_colored_polygon(PackedVector2Array([P.call(px - w * 0.28, 0.92 - h * 0.72), P.call(px, 0.92 - h), P.call(px + w * 0.28, 0.92 - h * 0.72), P.call(px, 0.92 - h * 0.62)]), Color(p.snow))
		"water":
			Draw.gradient_rect(ci, Rect2(X, Y, T, T), [[0.0, Color(p.base)], [1.0, Color(p.get("deep", p.base))]])
		"bridge":
			Draw.gradient_rect(ci, Rect2(X, Y, T, T), [[0.0, Color(p.base)], [1.0, Color(p.get("deep", p.base))]])
			var horiz: bool = (Game.tile_at(s, x - 1, y) != "~" or Game.tile_at(s, x + 1, y) != "~") and Game.tile_at(s, x, y - 1) == "~"
			if horiz:
				ci.draw_rect(Rect2(X, Y + T * 0.22, T, T * 0.62), Color(0, 0, 0, 0.27))
				ci.draw_rect(Rect2(X, Y + T * 0.18, T, T * 0.6), Color(p.plank))
			else:
				ci.draw_rect(Rect2(X + T * 0.18, Y, T * 0.68, T), Color(0, 0, 0, 0.27))
				ci.draw_rect(Rect2(X + T * 0.14, Y, T * 0.68, T), Color(p.plank))
			for i in range(1, 7):
				if horiz:
					ci.draw_line(Vector2(X + T * i / 7.0, Y + T * 0.18), Vector2(X + T * i / 7.0, Y + T * 0.78), Color(p.plank2), maxf(1.0, T / 40.0))
				else:
					ci.draw_line(Vector2(X + T * 0.14, Y + T * i / 7.0), Vector2(X + T * 0.82, Y + T * i / 7.0), Color(p.plank2), maxf(1.0, T / 40.0))
		"castle":
			ci.draw_rect(Rect2(X, Y, T, T), Color(p.base))
			ci.draw_rect(Rect2(X + T * 0.06, Y + T * 0.08, T * 0.88, T * 0.86), Color(0, 0, 0, 0.13))

# ---------- per-frame ----------
func _draw_dyn(ci: CanvasItem) -> void:
	if s.is_empty():
		return
	var time := FX.now()
	_draw_water(ci, time)
	for y in s.h:
		for x in s.w:
			var t: String = s.tiles[y][x]
			if t == "v" or t == "c":
				_draw_building(ci, t, x * T, y * T, s.owner.get(Vector2i(x, y), "n"), time, x, y)
	for g: Dictionary in s.graves:
		_draw_grave(ci, g.x * T, g.y * T, time)
	_draw_overlays(ci, time)
	fx.draw_under(ci, T, time)
	_draw_units(ci, time)

func _draw_water(ci: CanvasItem, time: float) -> void:
	var ph := time / 1100.0
	var wave := Color(0.498, 0.722, 0.831, 0.33)
	for y in s.h:
		for x in s.w:
			if s.tiles[y][x] != "~":
				continue
			var X: float = x * T
			var Y: float = y * T
			for i in 3:
				var yy: float = Y + T * (0.22 + 0.28 * i)
				var pts := PackedVector2Array()
				for j in 7:
					pts.append(Vector2(X + T * j / 6.0, yy + sin(ph * 2 + j * 1.1 + x * 0.9 + i * 2 + y) * T * 0.035))
				ci.draw_polyline(pts, wave, maxf(1.0, T / 28.0), true)
			var spk := (sin(ph * 3 + x * 7.1 + y * 3.3) + 1) / 2
			if spk > 0.85:
				ci.draw_circle(Vector2(X + hash01(x, y, 3) * T, Y + hash01(x, y, 4) * T), T * 0.03, Color(1, 1, 1, (spk - 0.85) * 4))

static func _join(parts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: PackedVector2Array in parts:
		for i in p.size():
			if out.size() and out[out.size() - 1].is_equal_approx(p[i]):
				continue
			out.append(p[i])
	return out

func _draw_building(ci: CanvasItem, t: String, X: float, Y: float, own: String, time: float, x: int, y: int) -> void:
	var facs: Dictionary = Content.theme().factions
	var fac: Dictionary = facs.get(own, facs.n)
	var p: Dictionary = Content.terrain(t)
	var P := func(a: float, b: float) -> Vector2: return Vector2(X + T * a, Y + T * b)
	if t == "v":
		Draw.ellipse(ci, P.call(0.52, 0.84), T * 0.34, T * 0.08, Color(0, 0, 0, 0.27))
		ci.draw_rect(Rect2(P.call(0.26, 0.5), Vector2(T * 0.5, T * 0.32)), Color(p.wall))
		ci.draw_rect(Rect2(P.call(0.46, 0.62), Vector2(T * 0.1, T * 0.2)), Color("#3a2a1c"))
		# curved roof (đình style)
		var roof := _join([Draw.quad(P.call(0.12, 0.5), P.call(0.2, 0.46), P.call(0.3, 0.3), 6),
			Draw.quad(P.call(0.72, 0.3), P.call(0.82, 0.46), P.call(0.92, 0.42), 6),
			PackedVector2Array([P.call(0.84, 0.54), P.call(0.2, 0.54)])])
		ci.draw_colored_polygon(roof, Color(fac.roof))
		ci.draw_rect(Rect2(P.call(0.2, 0.5), Vector2(T * 0.64, T * 0.04)), Color(0, 0, 0, 0.2))
		if own != "n":
			Draw.glow(ci, P.call(0.51, 0.72), T * 0.12, Color(1, 0.85, 0.54, 0.8))
	elif t == "c":
		ci.draw_rect(Rect2(P.call(0.12, 0.42), Vector2(T * 0.76, T * 0.46)), Color(p.wall2))
		ci.draw_rect(Rect2(P.call(0.12, 0.42), Vector2(T * 0.76, T * 0.06)), Color(p.wall))
		for i in 4:
			ci.draw_rect(Rect2(P.call(0.12 + 0.21 * i, 0.32), Vector2(T * 0.13, T * 0.12)), Color(p.wall))
		# gate tower roof
		var roof := _join([PackedVector2Array([P.call(0.26, 0.34)]), Draw.quad(P.call(0.26, 0.34), P.call(0.34, 0.3), P.call(0.38, 0.18), 6),
			Draw.quad(P.call(0.62, 0.18), P.call(0.66, 0.3), P.call(0.74, 0.34), 6)])
		ci.draw_colored_polygon(roof, Color(fac.roof))
		ci.draw_colored_polygon(Draw.arc_points(P.call(0.5, 0.88), T * 0.14, T * 0.14, PI, TAU, 0.0, 12), Color("#2d2219"))
		# flag
		var wave := sin(time / 260.0 + x + y) * T * 0.03
		ci.draw_line(P.call(0.5, 0.18), P.call(0.5, -0.06), Color("#3b3026"), maxf(1.0, T / 30.0))
		var flag_col := Color("#a89b84") if own == "n" else Color(fac.glow)
		var top: Vector2 = P.call(0.5, -0.06)
		var tip := Vector2(X + T * 0.8, Y + wave * 1.5)
		var flag := _join([Draw.quad(top, Vector2(X + T * 0.64, Y - T * 0.06 + wave), tip, 6),
			Draw.quad(tip, Vector2(X + T * 0.64, Y + T * 0.06 + wave), P.call(0.5, 0.08), 6)])
		ci.draw_colored_polygon(flag, flag_col)

## fallen soldier: spear planted in the ground, dropped round shield, slow breathing red cloth
func _draw_grave(ci: CanvasItem, X: float, Y: float, time: float) -> void:
	var P := func(a: float, b: float) -> Vector2: return Vector2(X + T * a, Y + T * b)
	Draw.ellipse(ci, P.call(0.5, 0.8), T * 0.32, T * 0.1, Color(0, 0, 0, 0.33))
	ci.draw_line(P.call(0.62, 0.8), P.call(0.7, 0.18), Color("#5e4124"), maxf(1.5, T / 22.0), true)
	ci.draw_colored_polygon(PackedVector2Array([P.call(0.705, 0.06), P.call(0.745, 0.2), P.call(0.67, 0.19)]), Color("#c9c2b0"))
	var sway := sin(time / 520.0) * T * 0.03
	var cloth := _join([PackedVector2Array([P.call(0.69, 0.24)]), Draw.quad(P.call(0.69, 0.24), Vector2(X + T * 0.82 + sway, Y + T * 0.28), Vector2(X + T * 0.86 + sway, Y + T * 0.38), 6),
		PackedVector2Array([P.call(0.68, 0.34)])])
	ci.draw_colored_polygon(cloth, Color("#b8322a"))
	Draw.ellipse(ci, P.call(0.4, 0.7), T * 0.2, T * 0.11, Color("#7a5a34"), -0.2)
	Draw.ellipse_line(ci, P.call(0.4, 0.7), T * 0.13, T * 0.07, Color("#c9a35e"), maxf(1.0, T / 36.0), -0.2, 20)
	ci.draw_circle(P.call(0.4, 0.7), T * 0.03, Color("#c9a35e"))
	ci.draw_circle(P.call(0.5, 0.62), T * 0.05, Color(1, 0.86, 0.63, 0.25 + 0.2 * sin(time / 700.0)))

func _cell(ci: CanvasItem, x: int, y: int, fill: Variant, stroke: Variant, lw := 0.07) -> void:
	if fill != null:
		ci.draw_rect(Rect2(x * T + 1, y * T + 1, T - 2, T - 2), fill)
	if stroke != null:
		ci.draw_rect(Rect2(x * T + 2, y * T + 2, T - 4, T - 4), stroke, false, maxf(2.0, T * lw))

## dashed polyline with a moving phase
## dashed polyline with a moving phase. Bounded: one pass over a fixed number of dashes (an earlier
## while-loop could stall on float rounding and append draw commands forever -> 60 GB, machine froze).
static func _dashed(ci: CanvasItem, pts: Array, col: Color, w: float, on: float, off: float, phase: float) -> void:
	var period := on + off
	if pts.size() < 2 or period <= 0.0:
		return
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + (pts[i] as Vector2).distance_to(pts[i - 1]))
	var total := cum[cum.size() - 1]
	var start := -fposmod(phase, period)
	var n := int(ceil((total - start) / period)) + 1
	for k in mini(n, 400):
		var s0 := maxf(0.0, start + k * period)
		var s1 := minf(total, start + k * period + on)
		if s1 > s0:
			ci.draw_polyline(_sub_path(pts, cum, s0, s1), col, w, true)

## points of the polyline between arc lengths s0..s1
static func _sub_path(pts: Array, cum: PackedFloat32Array, s0: float, s1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(1, pts.size()):
		var l0 := cum[i - 1]
		var l1 := cum[i]
		if l1 < s0 or l0 > s1 or l1 <= l0:
			continue
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var p0 := a.lerp(b, clampf((s0 - l0) / (l1 - l0), 0.0, 1.0))
		var p1 := a.lerp(b, clampf((s1 - l0) / (l1 - l0), 0.0, 1.0))
		if out.is_empty():
			out.append(p0)
		out.append(p1)
	if out.size() == 1:
		out.append(out[0])
	return out

func _draw_overlays(ci: CanvasItem, time: float) -> void:
	var v := view
	var pulse := 0.5 + sin(time / 250.0) * 0.5
	if v.reach != null:
		var mine: bool = v.selMine
		for r: Dictionary in v.reach.values():
			_cell(ci, r.x, r.y, Color(0.431, 0.745, 1.0, 0.22 + pulse * 0.08) if mine else Color(1, 1, 1, 0.11), null)
		if mine:
			var oc := Color("#bfe4ff")
			var lw := maxf(1.5, T / 26.0)
			for r: Dictionary in v.reach.values():
				var rx: int = r.x
				var ry: int = r.y
				for e: Array in [[1, 0, 1, 0, 1, 1], [-1, 0, 0, 0, 0, 1], [0, 1, 0, 1, 1, 1], [0, -1, 0, 0, 1, 0]]:
					if v.reach.has(Vector2i(rx + e[0], ry + e[1])):
						continue
					ci.draw_line(Vector2((rx + e[2]) * T, (ry + e[3]) * T), Vector2((rx + e[4]) * T, (ry + e[5]) * T), oc, lw)
	for e: Dictionary in v.attackable:
		_cell(ci, e.x, e.y, Color(0.878, 0.38, 0.298, 0.18 + pulse * 0.14), Color("#ff7a5f"))
	for e: Dictionary in v.targets:
		var is_t: bool = v.target != null and e.id == v.target
		_cell(ci, e.x, e.y, Color(0.878, 0.38, 0.298, 0.2 + pulse * 0.15), Color("#ffe08a") if is_t else Color("#ff7a5f"), 0.1 if is_t else 0.07)
	if v.path != null and v.path.size() > 1:
		var pts := []
		for p: Array in v.path:
			pts.append(Vector2((p[0] + 0.5) * T, (p[1] + 0.5) * T))
		var w := maxf(3.0, T * 0.1)
		_dashed(ci, pts, Color("#ffe9a8"), w, T * 0.12, T * 0.14, -time / 30.0)
		for p: Vector2 in pts:
			ci.draw_circle(p, w * 0.5, Color("#ffe9a8"))
	if v.dest != null:
		_cell(ci, v.dest[0], v.dest[1], Color(1, 0.878, 0.541, 0.16), Color("#ffe08a"))
	if v.info != null:
		_cell(ci, v.info.x, v.info.y, null, Color(0.949, 0.898, 0.788, 0.8), 0.05)
	if v.buyAt != null:
		_cell(ci, v.buyAt[0], v.buyAt[1], Color(1, 0.839, 0.4, 0.15 + pulse * 0.15), Color("#ffd166"))
	if v.hover != null and v.dest == null:
		_cell(ci, v.hover.x, v.hover.y, null, Color(1, 1, 1, 0.33), 0.04)

func _draw_units(ci: CanvasItem, time: float) -> void:
	var v := view
	var list := []
	for u: Dictionary in s.units:
		if not v.hide.has(u.id):
			list.append({ "u": u, "x": float(u.x), "y": float(u.y), "alpha": -1.0, "scale": 1.0 })
	for sp: Dictionary in v.sprites:
		if not sp.get("hidden", false):
			list.append({ "u": sp.u, "x": float(sp.u.x), "y": float(sp.u.y), "alpha": sp.get("alpha", -1.0), "scale": 1.0 })
	for g: Dictionary in fx.ghosts:
		var kk: float = (time - g.t0) / g.dur
		list.append({ "u": g.u, "x": float(g.u.x), "y": g.u.y - kk * 0.3, "alpha": 1.0 - kk, "scale": 1.0 - kk * 0.3 })
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.y < b.y)
	var sel_id: int = v.sel.id if v.sel != null else -1
	for it: Dictionary in list:
		var u: Dictionary = it.u
		var x: float = it.x
		var y: float = it.y
		if u.id == sel_id and v.dest != null:
			x = v.dest[0]
			y = v.dest[1]
		var off: Variant = fx.offsets.get(u.id)
		if off != null:
			x += off.x
			y += off.y
		var c := Vector2((x + 0.5) * T, (y + 0.5) * T)
		var fl: float = fx.flash_until.get(u.id, 0.0)
		var flash := (fl - time) / 180.0 if fl > time else 0.0
		var bob := sin(time / 420.0 + u.id * 1.7) * T * 0.025
		var is_sel: bool = u.id == sel_id
		if is_sel:
			Draw.ellipse_line(ci, c + Vector2(0, T * 0.36), T * 0.42, T * 0.15, Color(1, 0.878, 0.541, 0.6 + sin(time / 160.0) * 0.4), maxf(2.0, T * 0.06))
		var alpha: float = it.alpha if it.alpha >= 0 else 1.0
		Token.paint(ci, c, T * it.scale, u.side, u.type, s.heroKey[u.side], { "bob": bob * 3 if is_sel else bob, "flash": flash, "alpha": alpha })
		var hp: int = v.hp.get(u.id, u.hp) if v.hp != null else u.hp
		if u.get("acted", false) and s.side == u.side and not v.busy:
			ci.draw_circle(c - Vector2(0, bob), T * 0.41, Color(0.04, 0.024, 0.024, 0.63))
		if it.alpha < 0 or it.alpha > 0.5:
			var w := T * 0.62
			var h := maxf(3.0, T * 0.07)
			var bx := c.x - w / 2
			var byy := c.y + T * 0.36
			if hp < 100:
				ci.draw_rect(Rect2(bx - 1, byy - 1, w + 2, h + 2), Color(0, 0, 0, 0.73))
				ci.draw_rect(Rect2(bx, byy, w * maxi(0, hp) / 100.0, h), Color("#8fd16a") if hp > 60 else (Color("#ffd166") if hp > 30 else Color("#ff6b57")))
				Draw.text_a(ci, Style.xbold, Vector2(c.x + T * 0.48, c.y + T * 0.3), str(maxi(0, hp)), int(round(T * 0.22)), Color.WHITE, 1.0, false, 3, Color.BLACK)
			if u.rank:
				Draw.text_a(ci, Style.xbold, Vector2(c.x - T * 0.48, c.y - T * 0.5), "★".repeat(u.rank), int(round(T * 0.2)), Color("#ffd166"), 0.0, true, 3, Color("#2a1606"))
			if u.get("guard", false) and u.side == "e":
				Draw.text_a(ci, Style.body, Vector2(c.x + T * 0.5, c.y - T * 0.52), "💤", int(round(T * 0.22)), Color.WHITE, 1.0, true)

func _update_night(time: float) -> void:
	var lights := PackedVector3Array()
	var torches := PackedVector2Array()
	for u: Dictionary in s.units:
		if u.side == "p":
			lights.append(Vector3(u.x, u.y, 2.4))
	for key: Vector2i in s.owner:
		if s.owner[key] == "p":
			lights.append(Vector3(key.x, key.y, 1.9))
			torches.append(Vector2(key))
	for g: Dictionary in s.graves:
		lights.append(Vector3(g.x, g.y, 0.9))
	lights.resize(mini(lights.size(), 128))
	torches.resize(mini(torches.size(), 64))
	var m: ShaderMaterial = _night.material
	m.set_shader_parameter("board_px", Vector2(T * s.w, T * s.h))
	m.set_shader_parameter("tile", T)
	m.set_shader_parameter("time_ms", fmod(time, 1.0e6))
	m.set_shader_parameter("n_lights", lights.size())
	m.set_shader_parameter("lights", lights)
	m.set_shader_parameter("n_torches", torches.size())
	m.set_shader_parameter("torches", torches)

## drifting cloud shadows by day
func _draw_ambient(ci: CanvasItem) -> void:
	if s.is_empty() or s.night:
		return
	var time := FX.now()
	for c: Dictionary in _clouds:
		var x := fmod(c.x + time * c.v, s.w + 8.0) - 4.0
		Draw.glow(ci, Vector2(x * T, c.y * T), c.r * T, Color(0.04, 0.08, 0.04, 0.13))

## fireflies by night (additive layer)
func _draw_fireflies(ci: CanvasItem) -> void:
	if s.is_empty() or not s.night:
		return
	var time := FX.now()
	if _motes.size() < 26:
		_motes.append({ "x": randf() * s.w, "y": randf() * s.h, "p": randf() * 6 })
	for m: Dictionary in _motes:
		m.x += sin(time / 900.0 + m.p) * 0.004
		m.y += cos(time / 1100.0 + m.p) * 0.003
		var a := (sin(time / 300.0 + m.p * 3) + 1) / 2
		ci.draw_circle(Vector2(m.x * T, m.y * T), T * 0.035, Color(0.82, 1.0, 0.55, a * 0.8))
