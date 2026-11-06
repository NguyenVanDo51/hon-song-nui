class_name Board
extends Control
## the battlefield: cached terrain layer + animated water, buildings, fallen soldiers, overlays, units, effects, night, ambience.
## Looks come from the theme; any unit / terrain "img" replaces the procedural drawing. Port of src/ui/render.js.
## Layers (bottom -> top): terrain (baked once into a texture on fit / refresh) | dyn | fx normal | fx additive | numbers | night | ambient.
## Units are drawn from a pre-rendered Token.Atlas. Nothing is drawn while the duel view covers the board.

signal tile_clicked(x: int, y: int)
signal hover_changed(tile: Variant)
signal cancel_requested
signal info_requested(id: int)

const BUFF_ATK := Color("#ff9a3c") # aura: +10 attack
const POISON := Color("#e0503f") # bitten: -atk / -def
const POISON_INK := Color("#4a1712")
const BUFF_UP := Color("#5fd35a") # buff arrow (map)
const BUFF_INK := Color("#1d3a17")
const GRASS_A := Color("#7da350")
const GRASS_B := Color("#4c6b30")
const TRUNK := Color("#4a3420")
const DOOR := Color("#3a2a1c")
const GATE := Color("#2d2219")
const POLE := Color("#3b3026")
const FLAG_N := Color("#a89b84")
const GOAL := Color("#ffd166")
const SPEAR := Color("#5e4124")
const BLADE := Color("#c9c2b0")
const CLOTH := Color("#b8322a")
const SHIELD := Color("#7a5a34")
const SHIELD_RIM := Color("#c9a35e")
const RING_SEL := Color("#bfe4ff")
const ATTACK := Color("#ff7a5f")
const RAZE := Color("#ff9a3c") # villages a catapult can wreck
const TARGET := Color("#ffe08a")
const PATH := Color("#ffe9a8")
const BUY := Color("#ffd166")
const HP_HI := Color("#8fd16a")
const HP_MID := Color("#ffd166")
const HP_LO := Color("#ff6b57")
const STAR := Color("#ffd166")
const STAR_INK := Color("#2a1606")
const BLADE_INK := Color("#2a1206")
const SHIELD_INK := Color("#0b2330")

var s: Dictionary = {}
var fx: FX
var T := 48.0
## what the game screen wants shown (see GameScreen.build_view)
var view := { "hide": {}, "hold": {}, "razable": [], "razeAt": null, "sprites": [], "hp": null, "busy": false, "sel": null, "selMine": false, "reach": null, "attackable": [],
	"dest": null, "targets": [], "target": null, "path": null, "info": null, "buyAt": null, "hover": null, "preview": null }
var hover: Variant = null
var _info_spots := [] # [[centre, unit id]] of the ⓘ dots drawn this frame
var _info_hit_id := -1
var _stage: Control
var _terrain: Baked # offscreen render of the static terrain
var _terrain_hi: Baked # the same at ZOOM x, shown during an attack close-up (the 1x one would blur)
var _terrain_view: Layer # draws that texture
var _terrain_dirty := true
var _scale := 0.0 # screen px per canvas unit the terrain / tokens were baked at
var _atlas: Token.Atlas
var _night_key := -1
var _layers: Array[Layer] = []
var _night: ColorRect
var _clouds := []
var _motes := []
var _zoom := 0.0 # 0 = whole map, 1 = close-up on _zoom_at (px)
var _zoom_at := Vector2.ZERO
const ZOOM := 1.9

class Layer extends Control:
	var fn: Callable
	func _draw() -> void:
		Draw.xf = Transform2D.IDENTITY
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
	_terrain = Baked.new(_draw_terrain)
	add_child(_terrain)
	_terrain_hi = Baked.new(_draw_terrain)
	add_child(_terrain_hi)
	_terrain_view = _layer(func(ci: CanvasItem) -> void:
		if not s.is_empty():
			ci.draw_texture_rect((_terrain_hi if _zoom > 0.0 else _terrain).get_texture(), Rect2(Vector2.ZERO, ci.size), false))
	_terrain_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # baked 1:1 with screen pixels
	_atlas = Token.Atlas.new(self)
	_layers.append(_layer(_draw_dyn))
	_layers.append(_layer(func(ci: CanvasItem) -> void: fx.draw_over(ci, T, FX.now())))
	var add := _layer(func(ci: CanvasItem) -> void: fx.draw_add(ci, T, FX.now()))
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.material = mat
	_layers.append(add)
	_layers.append(_layer(func(ci: CanvasItem) -> void:
		fx.draw_top(ci, T, FX.now())
		_draw_preview(ci)))
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
	_terrain_dirty = true
	_night_key = -1

## pick the tile size for the space available
func fit(avail: Vector2) -> void:
	if s.is_empty():
		return
	T = clampf(floor(minf(avail.x / s.w, avail.y / s.h)), 22.0, 96.0)
	var px := Vector2(T * s.w, T * s.h)
	custom_minimum_size = px
	size = px
	_stage.size = px
	for l: Control in [_terrain_view, _night] + _layers:
		l.size = px
	_terrain_dirty = true
	_night_key = -1

func refresh_terrain() -> void:
	_terrain_dirty = true

## close-up on an exchange: the map scales up around the two tiles (awaitable); unfocus() eases back
func focus(a: Vector2i, b: Vector2i) -> void:
	_zoom_at = (Vector2(a + b) / 2.0 + Vector2(0.5, 0.5)) * T
	var z0 := _zoom
	await fx.tween(300.0, func(k: float) -> void: _zoom = lerpf(z0, 1.0, 1.0 - pow(1.0 - k, 3.0)))

func unfocus() -> void:
	var z0 := _zoom
	await fx.tween(260.0, func(k: float) -> void: _zoom = lerpf(z0, 0.0, k * k * (3.0 - 2.0 * k)))

func _apply_zoom(shake: Vector2) -> void:
	var sc := lerpf(1.0, ZOOM, _zoom)
	var p := (size / 2.0 - _zoom_at * sc) * _zoom
	p = p.clamp(size - size * sc, Vector2.ZERO) # never show past the map edge
	_stage.scale = Vector2(sc, sc)
	_stage.position = p + shake
	clip_contents = _zoom > 0.0
	var zoomed := _zoom > 0.0
	if zoomed != (_terrain_view.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR):
		_terrain_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if zoomed else CanvasItem.TEXTURE_FILTER_NEAREST
		_terrain_view.queue_redraw()

## a tile's rectangle in the parent's coordinates (popup placement; Board3D returns its projected footprint)
func tile_rect(x: int, y: int) -> Rect2:
	return Rect2(position + Vector2(x * T, y * T), Vector2(T, T))

func _process(dt: float) -> void:
	if s.is_empty() or not is_visible_in_tree():
		return
	var t := FX.now()
	fx.update(t)
	var sc := Baked.screen_scale(self)
	if _terrain_dirty or not is_equal_approx(sc, _scale):
		_terrain_dirty = false
		_scale = sc
		_terrain.bake(Vector2(T * s.w, T * s.h), sc)
		_terrain_hi.bake(Vector2(T * s.w, T * s.h), sc * ZOOM)
		_terrain_view.queue_redraw()
	_atlas.ensure(T, sc, s.heroKey)
	_apply_zoom(fx.shake_offset(t) * T)
	for l: Layer in _layers:
		l.queue_redraw()
	_night.visible = s.night
	if s.night:
		_update_night()
		_drift_motes(dt)

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
			var info_id := _info_at(ev.position)
			if info_id >= 0:
				info_requested.emit(info_id)
			else:
				var tl: Variant = _tile_at_mouse(ev.position)
				if tl != null:
					tile_clicked.emit(tl.x, tl.y)
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			cancel_requested.emit()
		accept_event()
	elif ev is InputEventMouseMotion:
		var ih := _info_at(ev.position)
		if ih != _info_hit_id:
			_info_hit_id = ih
			tooltip_text = "Xem thông tin quân" if ih >= 0 else ""
		var tl: Variant = _tile_at_mouse(ev.position)
		if tl != hover:
			hover = tl
			hover_changed.emit(tl)

## unit id whose ⓘ dot is under p (a little larger than drawn, so it is easy to hit), else -1
func _info_at(p: Vector2) -> int:
	var r := maxf(11.0, T * 0.17)
	for sp: Array in _info_spots:
		if p.distance_to(sp[0]) <= r:
			return sp[1]
	return -1

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hover != null:
		hover = null
		hover_changed.emit(null)

# ---------- terrain (cached) ----------
## art set (Token.fig_style, e.g. chibi): SVG tiles in assets/terrain/<style>/ replace the procedural terrain
func _art(name: String) -> String:
	if Token.fig_style == "":
		return ""
	var p := "res://assets/terrain/%s/%s.svg" % [Token.fig_style, name]
	return p if Token.exists(p) else ""

## tile x, y -> its art file (two looks per kind, picked by position); "" = no art for it
func _tile_art(t: String, x: int, y: int) -> String:
	var ab := "_a" if hash01(x, y, 11) < 0.5 else "_b"
	var base: String = { ".": "grass", "r": "grass", "v": "grass", "c": "grass", "x": "grass", "t": "grass", "f": "forest", "h": "hill", "m": "mountain" }.get(t, "")
	if base != "":
		var p := _art(base + ab)
		return p if p != "" else _art(base + "_a")
	return _art({ "~": "water", "=": "bridge" }.get(t, "-"))

## an SVG drawn over tile x, y (rasterised at the on-screen size), turned by rot around the tile centre
func _art_draw(ci: CanvasItem, path: String, x: int, y: int, rot := 0.0) -> bool:
	var tex := Token.raster(path, T * Baked.screen_scale(ci))
	if tex == null:
		return false
	if rot == 0.0:
		ci.draw_texture_rect(tex, Rect2(x * T, y * T, T, T), false)
	else:
		ci.draw_set_transform(Vector2((x + 0.5) * T, (y + 0.5) * T), rot)
		ci.draw_texture_rect(tex, Rect2(-T / 2.0, -T / 2.0, T, T), false)
		ci.draw_set_transform_matrix(Draw.xf)
	return true

func _bridge_horiz(x: int, y: int) -> bool:
	return (Game.tile_at(s, x - 1, y) != "~" or Game.tile_at(s, x + 1, y) != "~") and Game.tile_at(s, x, y - 1) == "~"

func _draw_terrain(ci: CanvasItem) -> void:
	if s.is_empty():
		return
	var art := _art("grass_a") != ""
	for y in s.h:
		for x in s.w:
			var t: String = s.tiles[y][x]
			var p: Dictionary = Content.terrain(t)
			var ap := _tile_art(t, x, y) if art else ""
			if ap != "" and _art_draw(ci, ap, x, y, PI / 2.0 if t == "=" and _bridge_horiz(x, y) else 0.0):
				continue
			var tex := Token.image(p.get("img"))
			if tex:
				ci.draw_texture_rect(tex, Rect2(x * T, y * T, T, T), false)
			else:
				_paint(ci, p.paint, x * T, y * T, p, x, y)
	_draw_roads(ci)
	# shorelines: sand on land edges touching water
	for y in s.h:
		for x in s.w:
			var t: String = s.tiles[y][x]
			if Rules.TERRAIN[t].get("water", false) or t == "=":
				continue
			var X: float = x * T
			var Y: float = y * T
			var w := T * 0.12
			var sand := Color("#e3cf9a", 0.85) if art else Color(0.788, 0.718, 0.541, 0.53)
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

## dirt tracks: every path tile joins its path / village / castle / bridge neighbours with a worn band (two tones +
## pebbles), so the roads read as one network leading to the buildings and over the bridges
func _draw_roads(ci: CanvasItem) -> void:
	var p: Dictionary = Content.terrain("r")
	if _art("grass_a") != "":
		p = p.merged({ "dirt": Color("#d2b07a"), "dirt2": Color("#b48e58"), "pebble": Color("#e9d9ad") }, true)
	# how far from this tile's centre the band runs toward each kind of neighbour (tile units):
	# path -> the shared edge (the neighbour draws its own half), village / castle -> up to the building, bridge -> onto the planks
	var links := { "r": 0.5, "v": 1.0, "c": 1.0, "x": 1.0, "t": 1.0, "=": 0.62 }
	var w := T * 0.30
	for pass_i in 2:
		var col := Color(p.dirt2) if pass_i == 0 else Color(p.dirt)
		var ww := w + (T * 0.07 if pass_i == 0 else 0.0)
		for y in s.h:
			for x in s.w:
				if s.tiles[y][x] != "r":
					continue
				var c := Vector2((x + 0.5) * T, (y + 0.5) * T)
				ci.draw_circle(c, ww / 2, col)
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nt: Variant = Game.tile_at(s, x + d.x, y + d.y)
					if nt == null or not links.has(nt):
						continue
					var e := c + Vector2(d) * T * float(links[nt])
					ci.draw_line(c, e, col, ww)
					if nt != "r":
						ci.draw_circle(e, ww / 2, col)
	for y in s.h:
		for x in s.w:
			if s.tiles[y][x] != "r":
				continue
			for i in 4:
				var q := Vector2((x + 0.3 + hash01(x, y, i + 40) * 0.4) * T, (y + 0.3 + hash01(x, y, i + 50) * 0.4) * T)
				ci.draw_circle(q, maxf(1.0, T * 0.018), Color(p.pebble, 0.8))

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
		"road":
			ci.draw_rect(Rect2(X, Y, T, T), Color(p.base)) # grass under the track (_draw_roads paints the dirt)
			for i in 4:
				ci.draw_rect(Rect2(X + hash01(x, y, i) * T, Y + hash01(x, y, i + 20) * T, maxf(1.0, T / 30.0), maxf(2.0, T / 14.0)),
					GRASS_A if hash01(x, y, i + 9) > 0.5 else GRASS_B)
		"field", "village":
			ci.draw_rect(Rect2(X, Y, T, T), Color(p.base))
			for i in range(1, 5):
				var yy := Y + T * i / 5.0
				ci.draw_polyline(Draw.quad(Vector2(X + 2, yy), Vector2(X + T / 2, yy + (hash01(x, y, i) - 0.5) * T * 0.12), Vector2(X + T - 2, yy), 8),
					Color(p.line), maxf(1.0, T / 40.0), true)
			for i in 6:
				ci.draw_rect(Rect2(X + hash01(x, y, i) * T, Y + hash01(x, y, i + 20) * T, maxf(1.0, T / 30.0), maxf(2.0, T / 14.0)),
					GRASS_A if hash01(x, y, i + 9) > 0.5 else GRASS_B)
		"forest":
			ci.draw_rect(Rect2(X, Y, T, T), Color(p.base))
			var trees := [[0.25, 0.42], [0.72, 0.38], [0.5, 0.68], [0.2, 0.86], [0.8, 0.84]]
			for i in trees.size():
				var cx: float = X + T * (trees[i][0] + (hash01(x, y, i) - 0.5) * 0.08)
				var by: float = Y + T * trees[i][1]
				var h := T * (0.36 + hash01(x, y, i + 5) * 0.1)
				Draw.ellipse(ci, Vector2(cx + T * 0.04, by + T * 0.02), h * 0.38, h * 0.12, Color(0, 0, 0, 0.2), 0.0, 14)
				ci.draw_rect(Rect2(cx - T * 0.015, by - h * 0.15, T * 0.03, h * 0.18), TRUNK)
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
			var own: String = s.owner.get(Vector2i(x, y), "n")
			var held: Variant = view.hold.get(Vector2i(x, y)) # [tile, owner] shown until its event plays (raze / repair)
			if held != null:
				t = held[0]
				own = held[1] if held[1] != null else "n"
			if t == "v" or t == "c" or t == "x" or t == "t":
				_draw_building(ci, t, x * T, y * T, own, time, x, y)
	for g: Dictionary in s.graves:
		_draw_grave(ci, g.x * T, g.y * T, time)
	for at: Array in Objectives.marks(s):
		_draw_goal(ci, at[0] * T, at[1] * T, time)
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
	var ap := _art("temple" if t == "t" else ("village_x" if t == "x" else "%s_%s" % ["village" if t == "v" else "castle", own]))
	if ap != "" and _art_draw(ci, ap, x, y):
		return
	if t == "t": # shrine without the art set: drawn as a neutral village
		t = "v"
		own = "n"
	var pal := Draw.pal()
	var fac: Dictionary = pal.factions.get(own, pal.factions.n)
	var p: Dictionary = pal.terrain[t]
	var P := func(a: float, b: float) -> Vector2: return Vector2(X + T * a, Y + T * b)
	if t == "x": # ruined village (no art set): broken wall stubs + rubble
		Draw.ellipse(ci, P.call(0.52, 0.84), T * 0.34, T * 0.08, Color(0, 0, 0, 0.22))
		ci.draw_rect(Rect2(P.call(0.26, 0.62), Vector2(T * 0.14, T * 0.2)), p.wall)
		ci.draw_rect(Rect2(P.call(0.6, 0.68), Vector2(T * 0.16, T * 0.14)), p.wall)
		for i in 5:
			ci.draw_circle(P.call(0.3 + hash01(x, y, i) * 0.45, 0.78 + hash01(x, y, i + 9) * 0.1), T * 0.035, Color("#8a8073"))
		return
	if t == "v":
		Draw.ellipse(ci, P.call(0.52, 0.84), T * 0.34, T * 0.08, Color(0, 0, 0, 0.27))
		ci.draw_rect(Rect2(P.call(0.26, 0.5), Vector2(T * 0.5, T * 0.32)), p.wall)
		ci.draw_rect(Rect2(P.call(0.46, 0.62), Vector2(T * 0.1, T * 0.2)), DOOR)
		# curved roof (đình style)
		var roof := _join([Draw.quad(P.call(0.12, 0.5), P.call(0.2, 0.46), P.call(0.3, 0.3), 6),
			Draw.quad(P.call(0.72, 0.3), P.call(0.82, 0.46), P.call(0.92, 0.42), 6),
			PackedVector2Array([P.call(0.84, 0.54), P.call(0.2, 0.54)])])
		ci.draw_colored_polygon(roof, fac.roof)
		ci.draw_rect(Rect2(P.call(0.2, 0.5), Vector2(T * 0.64, T * 0.04)), Color(0, 0, 0, 0.2))
		if own != "n":
			Draw.glow(ci, P.call(0.51, 0.72), T * 0.12, Color(1, 0.85, 0.54, 0.8))
	elif t == "c":
		ci.draw_rect(Rect2(P.call(0.12, 0.42), Vector2(T * 0.76, T * 0.46)), p.wall2)
		ci.draw_rect(Rect2(P.call(0.12, 0.42), Vector2(T * 0.76, T * 0.06)), p.wall)
		for i in 4:
			ci.draw_rect(Rect2(P.call(0.12 + 0.21 * i, 0.32), Vector2(T * 0.13, T * 0.12)), p.wall)
		# gate tower roof
		var roof := _join([PackedVector2Array([P.call(0.26, 0.34)]), Draw.quad(P.call(0.26, 0.34), P.call(0.34, 0.3), P.call(0.38, 0.18), 6),
			Draw.quad(P.call(0.62, 0.18), P.call(0.66, 0.3), P.call(0.74, 0.34), 6)])
		ci.draw_colored_polygon(roof, fac.roof)
		ci.draw_colored_polygon(Draw.arc_points(P.call(0.5, 0.88), T * 0.14, T * 0.14, PI, TAU, 0.0, 12), GATE)
		# flag
		var wave := sin(time / 260.0 + x + y) * T * 0.03
		ci.draw_line(P.call(0.5, 0.18), P.call(0.5, -0.06), POLE, maxf(1.0, T / 30.0))
		var flag_col: Color = FLAG_N if own == "n" else fac.glow
		var top: Vector2 = P.call(0.5, -0.06)
		var tip := Vector2(X + T * 0.8, Y + wave * 1.5)
		var flag := _join([Draw.quad(top, Vector2(X + T * 0.64, Y - T * 0.06 + wave), tip, 6),
			Draw.quad(tip, Vector2(X + T * 0.64, Y + T * 0.06 + wave), P.call(0.5, 0.08), 6)])
		ci.draw_colored_polygon(flag, flag_col)

## objective goal tile (Objectives.marks): pulsing gold frame + a tall gold banner
func _draw_goal(ci: CanvasItem, X: float, Y: float, time: float) -> void:
	var pulse := 0.5 + 0.5 * sin(time / 300.0)
	ci.draw_rect(Rect2(X + 2, Y + 2, T - 4, T - 4), Color(1, 0.84, 0.4, 0.12 + 0.12 * pulse))
	ci.draw_rect(Rect2(X + 2, Y + 2, T - 4, T - 4), Color(1, 0.84, 0.4, 0.6 + 0.4 * pulse), false, maxf(2.0, T * 0.06))
	var wave := sin(time / 240.0) * T * 0.03
	ci.draw_line(Vector2(X + T * 0.22, Y + T * 0.92), Vector2(X + T * 0.22, Y + T * 0.08), POLE, maxf(1.5, T / 26.0))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(X + T * 0.22, Y + T * 0.08), Vector2(X + T * 0.5, Y + T * 0.14 + wave),
		Vector2(X + T * 0.22, Y + T * 0.28)]), GOAL)

## fallen soldier: spear planted in the ground, dropped round shield, slow breathing red cloth
func _draw_grave(ci: CanvasItem, X: float, Y: float, time: float) -> void:
	var P := func(a: float, b: float) -> Vector2: return Vector2(X + T * a, Y + T * b)
	Draw.ellipse(ci, P.call(0.5, 0.8), T * 0.32, T * 0.1, Color(0, 0, 0, 0.33))
	ci.draw_line(P.call(0.62, 0.8), P.call(0.7, 0.18), SPEAR, maxf(1.5, T / 22.0), true)
	ci.draw_colored_polygon(PackedVector2Array([P.call(0.705, 0.06), P.call(0.745, 0.2), P.call(0.67, 0.19)]), BLADE)
	var sway := sin(time / 520.0) * T * 0.03
	var cloth := _join([PackedVector2Array([P.call(0.69, 0.24)]), Draw.quad(P.call(0.69, 0.24), Vector2(X + T * 0.82 + sway, Y + T * 0.28), Vector2(X + T * 0.86 + sway, Y + T * 0.38), 6),
		PackedVector2Array([P.call(0.68, 0.34)])])
	ci.draw_colored_polygon(cloth, CLOTH)
	Draw.ellipse(ci, P.call(0.4, 0.7), T * 0.2, T * 0.11, SHIELD, -0.2)
	Draw.ellipse_line(ci, P.call(0.4, 0.7), T * 0.13, T * 0.07, SHIELD_RIM, maxf(1.0, T / 36.0), -0.2, 20)
	ci.draw_circle(P.call(0.4, 0.7), T * 0.03, SHIELD_RIM)
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
			var oc := RING_SEL
			var lw := maxf(1.5, T / 26.0)
			for r: Dictionary in v.reach.values():
				var rx: int = r.x
				var ry: int = r.y
				for e: Array in [[1, 0, 1, 0, 1, 1], [-1, 0, 0, 0, 0, 1], [0, 1, 0, 1, 1, 1], [0, -1, 0, 0, 1, 0]]:
					if v.reach.has(Vector2i(rx + e[0], ry + e[1])):
						continue
					ci.draw_line(Vector2((rx + e[2]) * T, (ry + e[3]) * T), Vector2((rx + e[4]) * T, (ry + e[5]) * T), oc, lw)
	for e: Dictionary in v.attackable:
		_cell(ci, e.x, e.y, Color(0.878, 0.38, 0.298, 0.18 + pulse * 0.14), ATTACK)
	for t: Array in v.razable:
		var aimed: bool = v.razeAt != null and v.razeAt[0] == t[0] and v.razeAt[1] == t[1]
		_cell(ci, t[0], t[1], Color(1, 0.6, 0.24, 0.16 + pulse * 0.14), TARGET if aimed else RAZE, 0.1 if aimed else 0.07)
	for e: Dictionary in v.targets:
		var is_t: bool = v.target != null and e.id == v.target
		_cell(ci, e.x, e.y, Color(0.878, 0.38, 0.298, 0.2 + pulse * 0.15), TARGET if is_t else ATTACK, 0.1 if is_t else 0.07)
	if v.path != null and v.path.size() > 1:
		var pts := []
		for p: Array in v.path:
			pts.append(Vector2((p[0] + 0.5) * T, (p[1] + 0.5) * T))
		var w := maxf(3.0, T * 0.1)
		_dashed(ci, pts, PATH, w, T * 0.12, T * 0.14, -time / 30.0)
		for p: Vector2 in pts:
			ci.draw_circle(p, w * 0.5, PATH)
	if v.dest != null:
		_cell(ci, v.dest[0], v.dest[1], Color(1, 0.878, 0.541, 0.16), TARGET)
	if v.info != null:
		_cell(ci, v.info.x, v.info.y, null, Color(0.949, 0.898, 0.788, 0.8), 0.05)
	if v.buyAt != null:
		_cell(ci, v.buyAt[0], v.buyAt[1], Color(1, 0.839, 0.4, 0.15 + pulse * 0.15), BUY)
	if v.hover != null and v.dest == null:
		_cell(ci, v.hover.x, v.hover.y, null, Color(1, 1, 1, 0.33), 0.04)
	_draw_support_range(ci, pulse)

## hovering (or having selected) a unit that buffs its neighbours: tint the 4 tiles where allies get the bonus
func _draw_support_range(ci: CanvasItem, pulse: float) -> void:
	var src: Variant = null
	if hover != null:
		src = Game.unit_at(s, hover.x, hover.y)
	if src == null and view.sel != null:
		src = view.sel
	if src == null:
		return
	var st := Game.stat(s, src)
	if not st.get("aura", 0):
		return
	var col := BUFF_ATK
	var at: Array = view.dest if view.sel != null and src.id == view.sel.id and view.dest != null else [src.x, src.y]
	for dy in range(-2, 3): # AE2 drum: allies within 2 tiles after it acts
		for dx in range(-2, 3):
			var x: int = at[0] + dx
			var y: int = at[1] + dy
			if (dx == 0 and dy == 0) or absi(dx) + absi(dy) > 2 or Game.tile_at(s, x, y) == null:
				continue
			_cell(ci, x, y, Color(col, 0.10 + pulse * 0.08), Color(col, 0.55), 0.04)

## hover-attack forecast pinned above the target: "⚔ 40  ⤺ 24" (gold = kill, red = our unit falls)
func _draw_preview(ci: CanvasItem) -> void:
	var p: Variant = view.get("preview")
	if p == null or s.is_empty():
		return
	var fs := int(clampf(T * 0.24, 12, 20))
	var rng := func(lo: int, hi: int) -> String: return str(lo) if lo == hi else "%d–%d" % [lo, hi]
	var give := "⚔ %s%s" % [rng.call(p.dmgMin, p.dmgMax), " hạ gục" if p.kill else (" có thể hạ" if p.mayKill else "")]
	var take := "  ↩ %s%s" % [rng.call(p.counterMin, p.counterMax), " ngã" if p.die else (" có thể ngã" if p.mayDie else "")] \
		if p.counterMax > 0 else ""
	var w1 := Style.xbold.get_string_size(give, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w2 := Style.xbold.get_string_size(take, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pad := 7.0
	var w := w1 + w2 + pad * 2
	var h := fs * 1.5
	var x := clampf((p.x + 0.5) * T - w / 2, 2, s.w * T - w - 2)
	var y: float = p.y * T - h - 4
	if y < 2:
		y = (p.y + 1) * T + 4
	var box := Style.box(Color(0.08, 0.04, 0.03, 0.92), Style.GOLD if p.kill else (Style.BAD if p.die else Style.BRONZE_2), 7, 0, 2)
	ci.draw_style_box(box, Rect2(x, y, w, h))
	var base := y + h / 2 + (Style.xbold.get_ascent(fs) - Style.xbold.get_descent(fs)) / 2
	ci.draw_string(Style.xbold, Vector2(x + pad, base), give, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.GOLD if p.kill else Style.GOOD)
	if take != "":
		ci.draw_string(Style.xbold, Vector2(x + pad + w1, base), take, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.BAD)

func _draw_units(ci: CanvasItem, time: float) -> void:
	_info_spots.clear()
	var v := view
	var list := []
	var seen := {} # tile -> a unit already there: a 2nd one (just bought on an occupied castle) is drawn shifted
	for u: Dictionary in s.units:
		if not v.hide.has(u.id):
			var k := Vector2i(u.x, u.y)
			var off := Vector2(0.24, 0.06) if seen.has(k) else Vector2.ZERO
			if seen.has(k):
				seen[k].x -= 0.2
			var it := { "u": u, "x": float(u.x) + off.x, "y": float(u.y) + off.y, "alpha": -1.0, "scale": 1.0 }
			seen[k] = it
			list.append(it)
	for sp: Dictionary in v.sprites:
		if not sp.get("hidden", false):
			list.append({ "u": sp.u, "x": float(sp.u.x), "y": float(sp.u.y), "alpha": sp.get("alpha", -1.0), "scale": 1.0 })
	for g: Dictionary in fx.ghosts:
		var kk: float = clampf((time - g.t0) / g.dur, 0.0, 1.0)
		list.append({ "u": g.u, "x": float(g.u.x), "y": float(g.u.y), "alpha": 1.0 - kk * kk, "scale": 1.0, "die": kk })
	var rig_t := {} # target id -> live attack rig: its back / mid fx wrap that token (tornado halves)
	var z := {} # unit id -> same-row rank: rig target 0, others 1, rig attacker 2 (demo: back, target, mid, attacker)
	for r: Rig in fx.rigs:
		rig_t[r.d_id] = fx.rig_of_target(r.d_id)
		z[r.d_id] = 0
	for r: Rig in fx.rigs:
		if r.shown:
			z[r.a_id] = 2
	# deterministic: sort_custom is not stable
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.y != b.y:
			return a.y < b.y
		var za: int = z.get(a.u.id, 1)
		var zb: int = z.get(b.u.id, 1)
		if za != zb:
			return za < zb
		if a.x != b.x:
			return a.x < b.x
		return a.u.id < b.u.id)
	var sel_id: int = v.sel.id if v.sel != null else -1
	var st := ci.get_screen_transform()
	var back_at := {} # list index -> rigs whose back layer goes there: before the first drawn of attacker / target
	for r: Rig in rig_t.values():
		for i in list.size():
			var lu: Dictionary = list[i].u
			if lu.id == r.d_id or (lu.id == r.a_id and r.shown and not list[i].has("die")):
				back_at[i] = back_at.get(i, []) + [r]
				break
	var back_done := {}
	var rig_done := {}
	for i in list.size():
		var it: Dictionary = list[i]
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
		var rt: Rig = rig_t.get(u.id) if not rig_done.has(u.id) else null
		var is_sel: bool = u.id == sel_id
		if is_sel:
			Draw.ellipse_line(ci, c + Vector2(0, T * 0.32), T * 0.36, T * 0.12, Color(1, 0.878, 0.541, 0.6 + sin(time / 160.0) * 0.4), maxf(2.0, T * 0.05))
		var alpha: float = it.alpha if it.alpha >= 0 else 1.0
		var acted: bool = u.get("acted", false) and s.side == u.side and not v.busy and not it.has("die")
		var tint := Color(0.42, 0.42, 0.45) if acted else Color.WHITE # done this turn: the figure greys out
		var pose := _pose(u, it, x, y, off, time, is_sel)
		flash = maxf(flash, pose.flash)
		for rb: Rig in back_at.get(i, []):
			rb.draw_layer(ci, "back")
			back_done[rb] = true
		var rg: Rig = fx.rig_of_attacker(u.id) if not it.has("die") else null
		if rg != null: # mid-attack: the rig stands in for the token (same size, same feet)
			rg.draw_char(ci)
		else:
			_atlas.draw_shadow(ci, c, it.scale, alpha, pose.shadow)
			Draw.set_xf(ci, pose.xf)
			if flash > 0 or _zoom > 0.0: # hit flash / close-up: paint live (white figure; crisp at any scale)
				Token.paint(ci, c, T * it.scale, u.side, u.type, s.heroKey[u.side], { "alpha": alpha, "flash": flash, "shadow": false, "tint": tint })
			elif not _atlas.draw(ci, st, c, u.side, u.type, 0.0, it.scale, alpha, tint, false, pose.still):
				Token.paint(ci, c, T * it.scale, u.side, u.type, s.heroKey[u.side], { "alpha": alpha, "shadow": false })
			Draw.set_xf(ci, Transform2D.IDENTITY)
		if rt != null:
			rig_done[u.id] = true
			rt.draw_layer(ci, "mid")
		var hp: int = v.hp.get(u.id, u.hp) if v.hp != null else u.hp
		hp = v.get("hpCount", {}).get(u.id, hp) # turn-start heal counting up
		if it.alpha < 0 or it.alpha > 0.5:
			var w := T * 0.62
			var h := maxf(3.0, T * 0.07)
			var bx := c.x - w / 2
			var byy := c.y + T * 0.36
			if hp < 100:
				ci.draw_rect(Rect2(bx - 1, byy - 1, w + 2, h + 2), Color(0, 0, 0, 0.73))
				ci.draw_rect(Rect2(bx, byy, w * maxi(0, hp) / 100.0, h), HP_HI if hp > 60 else (HP_MID if hp > 30 else HP_LO))
				Draw.text_a(ci, Style.xbold, Vector2(c.x + T * 0.48, c.y + T * 0.3), str(maxi(0, hp)), int(round(T * 0.22)), Color.WHITE, 1.0, false, 3, Color.BLACK)
			if u.rank:
				Draw.text_a(ci, Style.xbold, Vector2(c.x - T * 0.48, c.y - T * 0.5), "★".repeat(u.rank), int(round(T * 0.2)), STAR, 0.0, true, 3, STAR_INK)
			if u.get("guard", false) and u.side == "e": # sleeping sentry (not the guard *stat* below)
				Draw.text_a(ci, Style.body, Vector2(c.x + T * 0.24, c.y - T * 0.52), "💤", int(round(T * 0.22)), Color.WHITE, 1.0, true)
			if it.alpha < 0 and off == null and not v.busy and not it.has("die"):
				_draw_buffs(ci, u, c, int(round(x)), int(round(y)), time)
	for r: Rig in fx.rigs:
		if not rig_done.has(r.d_id) or rig_t.get(r.d_id) != r: # target not drawn, or an older rig on the same target
			if not back_done.has(r):
				r.draw_layer(ci, "back")
			r.draw_layer(ci, "mid")

## how a figure stands this frame, as a transform around its feet: walking hops + sways + faces where it goes,
## striking leans into the blow (fx.offsets), getting hit shoves it back (fx.knock), dying topples it over (ghost),
## idle breathes, the selected one bounces. shadow = how big its ground shadow is (smaller in the air).
var _last_xy := {} # unit id -> Vector2 last drawn spot
var _face := {} # unit id -> -1 / 1 facing (enemies start facing left)
func _pose(u: Dictionary, it: Dictionary, x: float, y: float, off: Variant, time: float, is_sel: bool) -> Dictionary:
	var id: int = u.id
	var home := 1.0 if u.side == "p" else -1.0 # the way the figure is drawn
	var face: float = _face.get(id, home)
	var lean := 0.0
	var sx := 1.0
	var sy := 1.0 + sin(time / 620.0 + id * 1.3) * 0.018 # breathing
	var lift := 0.0
	var shift := Vector2.ZERO
	var still := true
	var rflash := 0.0
	var bx: float = it.x
	var by: float = it.y
	var last: Variant = _last_xy.get(id)
	if not it.has("die"):
		if last != null and absf(bx - last.x) > 0.001:
			face = signf(bx - last.x)
		_last_xy[id] = Vector2(bx, by)
	# walking: one hop per tile, a little sway and stretch while in the air
	var p := fposmod(bx, 1.0) + fposmod(by, 1.0)
	if p > 0.001 and p < 0.999:
		still = false
		var air := sin(p * PI)
		lift += air * 0.14 * T
		sy *= 1.0 + air * 0.07
		sx *= 1.0 - air * 0.05
		lean += sin(p * TAU) * 0.09
	# striking: lean into the blow, stretch along it
	if off != null:
		still = false
		var o: Vector2 = off
		if fx.facing.has(id):
			face = fx.facing[id]
		lean += clampf(o.x * 1.5, -0.55, 0.55)
		sx *= 1.0 + absf(o.x) * 0.45
		sy *= 1.0 - absf(o.x) * 0.2 + maxf(0.0, -o.y) * 0.5
	# hit: shoved back along the blow, leaning away, squashed
	var kn: Variant = fx.knock.get(id)
	if kn != null:
		var k: float = (time - kn.t0) / kn.dur
		if k >= 1.0:
			fx.knock.erase(id)
		else:
			still = false
			var a := (1.0 - k) * (1.0 - k) * float(kn.mag)
			shift += kn.dir * 0.13 * T * a
			lean += kn.dir.x * 0.32 * a - (0.0 if absf(kn.dir.x) > 0.3 else 0.12 * a)
			sy *= 1.0 - 0.12 * a
			sx *= 1.0 + 0.08 * a
	# struck by a code-rigged attack: the rig's target physics (knock along the blow, lift, squash, spin, flash)
	var rp: Variant = fx.rig_target_pose(id) if not it.has("die") else null
	if rp != null:
		still = false
		shift += rp.shift
		lift += rp.lift
		sy *= rp.sy
		sx *= rp.sx * rp.face
		rflash = rp.flash
	# dying: topple backwards and sink a little
	if it.has("die"):
		still = false
		var kk: float = it.die
		var fall := kk * kk * (3.0 - 2.0 * kk)
		lean += -face * fall * 1.45
		shift.y += fall * 0.06 * T
		sy *= 1.0 - fall * 0.1
	if is_sel and off == null:
		still = false
		lift += absf(sin(time / 230.0)) * 0.07 * T
	_face[id] = face
	var tn: Variant = _turn.get(id)
	if tn != null: # turning to face a rig target: the drawn facing sweeps through edge-on
		var k: float = (time - tn.t0) / tn.dur
		if k >= 1.0:
			_turn.erase(id)
		else:
			face = Rig.thin(lerpf(tn.from, tn.to, smoothstep(0.0, 1.0, k)))
	if face != home:
		still = false
	var foot := Vector2((x + 0.5) * T, (y + 0.5) * T + T * 0.30)
	var xf := Transform2D(lean, Vector2(sx * face * home, sy), 0.0, foot + shift - Vector2(0, lift)) * Transform2D(0.0, Vector2.ONE, 0.0, -foot)
	return { "xf": xf, "still": still and is_equal_approx(sy, 1.0), "shadow": clampf(1.0 - lift / T * 1.6, 0.6, 1.0), "flash": rflash }

## which way a unit's figure looks on screen (+1 right / -1 left); a rig attack turns it toward its target
func face_of(id: int, side: String) -> float:
	return _face.get(id, 1.0 if side == "p" else -1.0)

## also drops the last drawn spot: a stale one (hidden while it moved) would re-face it by movement on the next frame
func set_face(id: int, f: float) -> void:
	_face[id] = f
	_last_xy.erase(id)

var _turn := {} # unit id -> { from, to, t0, dur }: drawn facing animating to _face
func turn(id: int, from: float, to: float, dur: float) -> void:
	set_face(id, to)
	_turn[id] = { "from": from, "to": to, "t0": FX.now(), "dur": maxf(1.0, dur) }

## live buffs from Game.buffs_at (what the forecast counts): green up arrow per bonus (drum aura, water),
## red down arrow when bitten (-atk / -def), plus a soft ground ring in the dominant colour
func _draw_buffs(ci: CanvasItem, u: Dictionary, c: Vector2, x: int, y: int, time: float) -> void:
	var b := Game.buffs_at(s, u, x, y)
	var arrows := []
	if b.atk_from == "aura":
		arrows.append(true)
	if b.def_from == "water":
		arrows.append(true)
	if b.poison:
		arrows.append(false)
	if arrows.is_empty():
		return
	var pulse := 0.5 + 0.5 * sin(time / 300.0 + u.id)
	var ring := BUFF_UP if arrows[0] else POISON
	Draw.ellipse_line(ci, c + Vector2(0, T * 0.36), T * 0.44, T * 0.16, Color(ring, 0.45 + pulse * 0.4), maxf(1.5, T * 0.035))
	var h := maxf(12.0, T * 0.3) # arrow height
	var w := h * 0.62
	for k in arrows.size():
		var up: bool = arrows[k]
		var bob := sin(time / 260.0 + u.id + k * 1.3) * h * 0.12
		var p := c + Vector2(-T * 0.4 + k * w * 0.95, -T * 0.34 + bob) # arrow tip (up) / tail (down), beside the head
		var sy := 1.0 if up else -1.0
		var o := p if up else p + Vector2(0, h)
		var pts := PackedVector2Array([o, o + Vector2(w / 2.0, h * 0.5 * sy), o + Vector2(w * 0.2, h * 0.5 * sy), o + Vector2(w * 0.2, h * sy),
			o + Vector2(-w * 0.2, h * sy), o + Vector2(-w * 0.2, h * 0.5 * sy), o + Vector2(-w / 2.0, h * 0.5 * sy)])
		var outline := pts.duplicate()
		outline.append(pts[0])
		ci.draw_colored_polygon(pts, BUFF_UP if up else POISON)
		ci.draw_polyline(outline, BUFF_INK if up else POISON_INK, maxf(1.5, T * 0.025), true)

## light holes + torches follow units / owned buildings / graves: rebuilt only when those change (flicker runs on shader TIME)
func _update_night() -> void:
	var key: int = int(T * 16.0) * 7919 + s.w * 131 + s.h
	for u: Dictionary in s.units:
		if u.side == "p":
			key = key * 1000003 ^ (u.x * 73856093 + u.y * 19349663 + 1)
	for k: Vector2i in s.owner:
		if s.owner[k] == "p":
			key = key * 1000003 ^ (k.x * 83492791 + k.y * 2654435761 + 2)
	for g: Dictionary in s.graves:
		key = key * 1000003 ^ (g.x * 40503 + g.y * 9973 + 3)
	if key == _night_key:
		return
	_night_key = key
	var lights := PackedVector3Array()
	var torches := PackedVector2Array()
	for u: Dictionary in s.units:
		if u.side == "p":
			lights.append(Vector3(u.x, u.y, 2.4))
	for k: Vector2i in s.owner:
		if s.owner[k] == "p":
			lights.append(Vector3(k.x, k.y, 1.9))
			torches.append(Vector2(k))
	for g: Dictionary in s.graves:
		lights.append(Vector3(g.x, g.y, 0.9))
	lights.resize(mini(lights.size(), 128))
	torches.resize(mini(torches.size(), 64))
	var m: ShaderMaterial = _night.material
	m.set_shader_parameter("board_px", Vector2(T * s.w, T * s.h))
	m.set_shader_parameter("tile", T)
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
	for m: Dictionary in _motes:
		var a := (sin(time / 300.0 + m.p * 3) + 1) / 2
		ci.draw_circle(Vector2(m.x * T, m.y * T), T * 0.035, Color(0.82, 1.0, 0.55, a * 0.8))

## firefly drift, per second (was per drawn frame, so it sped up with the frame rate); tuned to the old 60 fps look
func _drift_motes(dt: float) -> void:
	if _motes.size() < 26:
		_motes.append({ "x": randf() * s.w, "y": randf() * s.h, "p": randf() * 6 })
	var time := FX.now()
	var k := minf(dt, 0.1) * 60.0
	for m: Dictionary in _motes:
		m.x += sin(time / 900.0 + m.p) * 0.004 * k
		m.y += cos(time / 1100.0 + m.p) * 0.003 * k
