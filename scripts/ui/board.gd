class_name Board
extends BoardBase
## the battlefield: cached terrain + building layer, animated water, fallen soldiers, overlays, units, effects, night, ambience.
## Looks come from the theme; any unit / terrain "img" replaces the procedural drawing. Port of src/ui/render.js.
## Layers (bottom -> top): terrain + buildings (baked into a texture on fit / refresh / owner change) | water (shader) | dyn |
## fx normal | fx additive | numbers | night | ambient.
## Units are drawn from a pre-rendered Token.Atlas. Nothing is drawn while the duel view covers the board.
## Terrain / building painting lives in paint (BoardPaint, board_paint.gd).

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
const STAR := Color("#ffd166")
const STAR_INK := Color("#2a1606")
const BLADE_INK := Color("#2a1206")
const SHIELD_INK := Color("#0b2330")
const ZOOM := 1.9

var paint: BoardPaint # terrain / building painting (board_paint.gd)
## portrait screen (auto_rotate on): the board turns 90° counter-clockwise (map right -> screen up, like a xiangqi board
## seen from the red side); figures / buildings / text stay upright via up_xf / vis_xf. Map data never changes.
var auto_rotate := false
var rot := false

var _info_spots := [] # [[centre, unit id]] of the ⓘ dots drawn this frame
var _stage: Control
var _terrain: Baked # offscreen render of the static terrain
var _terrain_hi: Baked = null # the same at ZOOM x, only while focused: 19-77 MB, too big to keep
var _terrain_view: Layer # draws that texture
var _terrain_dirty := true
var _water: ColorRect # animated by shaders/water.gdshader over a per-tile mask: no per-frame GDScript
var _bld_key := 0 # owners / held tiles / tiles the baked buildings were drawn with
var _live_bld := [] # [t, x, y, own] buildings without art: animated flag, still drawn per frame
var _scale := 0.0 # screen px per canvas unit the terrain / tokens were baked at
var _atlas: Token.Atlas
var _night_key := -1
var _layers: Array[Layer] = []
var _night: ColorRect
var _clouds := []
var _motes := []
var _zoom := 0.0 # 0 = whole map, 1 = close-up on _zoom_at (px)
var _zoom_at := Vector2.ZERO
var _last_xy := { } # unit id -> Vector2 last drawn spot
var _face := { } # unit id -> -1 / 1 facing (enemies start facing left)
var _turn := { } # unit id -> { from, to, t0, dur }: drawn facing animating to _face

class Layer extends Control:
	var fn: Callable

	func _draw() -> void:
		Draw.xf = Transform2D.IDENTITY
		fn.call(self)

static func hash01(x: int, y: int, n: int) -> float:
	return float((((x * 73856093) ^ (y * 19349663) ^ (n * 83492791)) & 0xFFFFFFFF) % 1000) / 1000.0

func _init() -> void:
	super()
	paint = BoardPaint.new(self)
	clip_contents = false
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_terrain = Baked.new(paint.draw_terrain)
	add_child(_terrain)
	_terrain_view = _layer(
		func(ci: Control) -> void:
			if not s.is_empty():
				var src: Baked = _terrain_hi if _zoom > 0.0 and _terrain_hi != null else _terrain
				ci.draw_texture_rect(src.get_texture(), Rect2(Vector2.ZERO, ci.size), false),
	)
	_terrain_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # baked 1:1 with screen pixels
	_water = ColorRect.new()
	_water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water.gdshader")
	_water.material = wm
	_stage.add_child(_water)
	_atlas = Token.Atlas.new(self)
	_layers.append(_layer(_draw_dyn))
	_layers.append(
		_layer(
			func(ci: CanvasItem) -> void:
				fx.draw_over(ci, T, FX.now()),
		)
	)
	var add := _layer(
		func(ci: CanvasItem) -> void:
			fx.draw_add(ci, T, FX.now()),
	)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.material = mat
	_layers.append(add)
	_layers.append(
		_layer(
			func(ci: CanvasItem) -> void:
				fx.draw_top(ci, T, FX.now())
				_draw_preview(ci),
		)
	)
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
	paint.fires.clear() # a new game: no flare for castles that "changed hands" since the last one
	paint.flare_at.clear()
	_terrain_dirty = true
	_night_key = -1

## pick the tile size for the space available
func fit(avail: Vector2) -> void:
	if s.is_empty():
		return
	var sw: int = s.w
	var sh: int = s.h
	rot = auto_rotate and avail.y > avail.x
	var a := Vector2(avail.y, avail.x) if rot else avail
	T = clampf(floorf(minf(a.x / sw, a.y / sh)), 22.0, 96.0)
	var px := _px()
	custom_minimum_size = px
	size = px
	rotation = -PI / 2.0 if rot else 0.0
	_stage.size = px
	for l: Control in [_terrain_view, _water, _night] + _layers:
		l.size = px
	_terrain_dirty = true
	paint.art_tex.clear()
	_night_key = -1

## board size in canvas px
func _px() -> Vector2:
	var sw: int = s.w
	var sh: int = s.h
	return Vector2(T * sw, T * sh)

func refresh_terrain() -> void:
	_terrain_dirty = true

## close-up on an exchange: the map scales up around the two tiles (awaitable); unfocus() eases back
func focus(a: Vector2i, b: Vector2i) -> void:
	_zoom_at = (Vector2(a + b) / 2.0 + Vector2(0.5, 0.5)) * T
	if _terrain_hi == null and not s.is_empty():
		_terrain_hi = Baked.new(paint.draw_terrain)
		add_child(_terrain_hi)
		_bake_hi()
	await _ease_focus(
		300.0,
		_zoom,
		1.0,
		func(v: float) -> void:
			_zoom = v,
	)

func unfocus() -> void:
	await _ease_focus(
		260.0,
		_zoom,
		0.0,
		func(v: float) -> void:
			_zoom = v,
	)
	if _zoom == 0.0 and _terrain_hi != null:
		_terrain_hi.queue_free()
		_terrain_hi = null

## textures past 4096 px fail on some GPUs: the close-up gets a little softer on very large boards / screens
func _bake_hi() -> void:
	_terrain_hi.bake(_px(), _hi_scale())

func _hi_scale() -> float:
	var px := _px()
	return minf(_scale * ZOOM, 4095.0 / maxf(px.x, px.y))

## px per canvas unit for SVGs painted live during a close-up: the end scale, not the tweening one (one raster per figure)
func _zoom_rs() -> float:
	return clampf(_scale * ZOOM, 0.5, 4.0)

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

## a tile's rectangle in the parent's coordinates (popup placement)
func tile_rect(x: int, y: int) -> Rect2:
	return get_transform() * Rect2(Vector2(x * T, y * T), Vector2(T, T))

# ---------- portrait view ----------
## on-screen size (turned board: w / h swap)
func visual_size() -> Vector2:
	return Vector2(size.y, size.x) if rot else size

## on-screen rectangle in the parent's coordinates
func visual_rect() -> Rect2:
	return Rect2(position - (Vector2(0.0, size.x) if rot else Vector2.ZERO), visual_size())

## put the on-screen top-left at p (the turned board's origin sits at its bottom-left)
func place(p: Vector2) -> void:
	position = p + (Vector2(0.0, size.x) if rot else Vector2.ZERO)

## draw transform that keeps art centred at c (board px) upright on a turned board
func up_xf(c: Vector2) -> Transform2D:
	if not rot:
		return Transform2D.IDENTITY
	return Transform2D(PI / 2.0, c - c.rotated(PI / 2.0))

## draw transform from on-screen board px (origin = on-screen top-left) to board px
func vis_xf() -> Transform2D:
	if not rot:
		return Transform2D.IDENTITY
	return Transform2D(Vector2(0, 1), Vector2(-1, 0), Vector2(_px().x, 0))

## map direction -> screen direction
func scr(v: Vector2) -> Vector2:
	return Vector2(v.y, -v.x) if rot else v

## screen direction -> map direction
func unscr(v: Vector2) -> Vector2:
	return Vector2(-v.y, v.x) if rot else v

## map tile -> the tile it shows as on screen (column, row of the turned grid)
func vis_tile(t: Vector2i) -> Vector2i:
	var sw: int = s.w
	return Vector2i(t.y, sw - 1 - t.x) if rot else t

## art turn on a turned board (+90° undoes the board's -90°)
func up_rot() -> float:
	return PI / 2.0 if rot else 0.0

func _process(dt: float) -> void:
	if s.is_empty() or not is_visible_in_tree():
		return
	var t := FX.now()
	fx.update(t)
	var sc := Baked.screen_scale(self)
	var bk := hash([s.owner, view.hold, s.tiles])
	if _terrain_dirty or bk != _bld_key or not is_equal_approx(sc, _scale):
		_terrain_dirty = false
		_bld_key = bk
		if not is_equal_approx(sc, _scale):
			paint.art_tex.clear()
		_scale = sc
		paint.prep_buildings()
		_terrain.bake(_px(), sc)
		if _terrain_hi != null:
			_bake_hi()
		_terrain_view.queue_redraw()
		paint.update_water_mask()
		if paint.art_path("grass_a") != "":
			paint.warm_hi_art()
	if _water.visible:
		(_water.material as ShaderMaterial).set_shader_parameter("ph", fposmod(t / 1100.0, TAU))
	var hero_keys: Dictionary = s.heroKey
	_atlas.ensure(T, sc, hero_keys)
	_apply_zoom(fx.shake_offset(t) * T)
	for l: Layer in _layers:
		l.queue_redraw()
	_night.visible = s.night
	if s.night:
		_update_night()
		_drift_motes(dt)

# ---------- input ----------
func _pick(p: Vector2) -> Variant:
	var x := floori(p.x / T)
	var y := floori(p.y / T)
	if Game.tile_at(s, x, y) == null:
		return null
	return Vector2i(x, y)

## unit id whose ⓘ dot is under p (a little larger than drawn, so it is easy to hit), else -1
func _info_at(p: Vector2) -> int:
	var r := maxf(11.0, T * 0.17)
	for sp: Array in _info_spots:
		var at: Vector2 = sp[0]
		if p.distance_to(at) <= r:
			return sp[1]
	return -1

# ---------- per-frame ----------
func _draw_dyn(ci: CanvasItem) -> void:
	if s.is_empty():
		return
	var time := FX.now()
	for b: Array in _live_bld:
		var t: String = b[0]
		var x: int = b[1]
		var y: int = b[2]
		var own: String = b[3]
		Draw.set_xf(ci, up_xf(Vector2(x + 0.5, y + 0.5) * T))
		paint.draw_building(ci, t, x * T, y * T, own, time, x, y)
	paint.draw_fires(ci, time)
	for g: Dictionary in s.graves:
		var gx: float = g.x
		var gy: float = g.y
		Draw.set_xf(ci, up_xf(Vector2(gx + 0.5, gy + 0.5) * T))
		paint.draw_grave(ci, gx * T, gy * T, time)
	for at: Array in Objectives.marks(s):
		var ax: float = at[0]
		var ay: float = at[1]
		Draw.set_xf(ci, up_xf(Vector2(ax + 0.5, ay + 0.5) * T))
		paint.draw_goal(ci, ax * T, ay * T, time)
	Draw.set_xf(ci, Transform2D.IDENTITY)
	_draw_overlays(ci, time)
	fx.draw_under(ci, T, time)
	_draw_units(ci, time)

## border of a set of tiles ({ Vector2i: any }): only edges with no tile of the set on the other side
func _outline(ci: CanvasItem, zone: Dictionary, col: Color, lw: float) -> void:
	for key: Vector2i in zone:
		var x0 := key.x * T
		var y0 := key.y * T
		if not zone.has(key + Vector2i(1, 0)):
			ci.draw_line(Vector2(x0 + T, y0), Vector2(x0 + T, y0 + T), col, lw)
		if not zone.has(key + Vector2i(-1, 0)):
			ci.draw_line(Vector2(x0, y0), Vector2(x0, y0 + T), col, lw)
		if not zone.has(key + Vector2i(0, 1)):
			ci.draw_line(Vector2(x0, y0 + T), Vector2(x0 + T, y0 + T), col, lw)
		if not zone.has(key + Vector2i(0, -1)):
			ci.draw_line(Vector2(x0, y0), Vector2(x0 + T, y0), col, lw)

func _cell(ci: CanvasItem, x: int, y: int, fill: Variant, stroke: Variant, lw := 0.07) -> void:
	if fill != null:
		var fc: Color = fill
		ci.draw_rect(Rect2(x * T + 1, y * T + 1, T - 2, T - 2), fc)
	if stroke != null:
		var sc: Color = stroke
		ci.draw_rect(Rect2(x * T + 2, y * T + 2, T - 4, T - 4), sc, false, maxf(2.0, T * lw))

## dashed polyline with a moving phase
## dashed polyline with a moving phase. Bounded: one pass over a fixed number of dashes (an earlier
## while-loop could stall on float rounding and append draw commands forever -> 60 GB, machine froze).
static func _dashed(ci: CanvasItem, pts: Array, col: Color, w: float, on: float, off: float, phase: float) -> void:
	var period := on + off
	if pts.size() < 2 or period <= 0.0:
		return
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i - 1]
		cum.append(cum[i - 1] + a.distance_to(b))
	var total := cum[cum.size() - 1]
	var start := -fposmod(phase, period)
	var n := ceili((total - start) / period) + 1
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
		var reach: Dictionary = v.reach
		for r: Dictionary in reach.values():
			var rx: int = r.x
			var ry: int = r.y
			_cell(ci, rx, ry, Color(0.431, 0.745, 1.0, 0.22 + pulse * 0.08) if mine else Color(1, 1, 1, 0.11), null)
		if mine:
			var oc := RING_SEL
			var lw := maxf(1.5, T / 26.0)
			var edges := [
				PackedInt32Array([1, 0, 1, 0, 1, 1]),
				PackedInt32Array([-1, 0, 0, 0, 0, 1]),
				PackedInt32Array([0, 1, 0, 1, 1, 1]),
				PackedInt32Array([0, -1, 0, 0, 1, 0]),
			]
			for r: Dictionary in reach.values():
				var rx: int = r.x
				var ry: int = r.y
				for e: PackedInt32Array in edges:
					if reach.has(Vector2i(rx + e[0], ry + e[1])):
						continue
					ci.draw_line(Vector2((rx + e[2]) * T, (ry + e[3]) * T), Vector2((rx + e[4]) * T, (ry + e[5]) * T), oc, lw)
	if v.threat != null: # enemy picked: red tint (threatFill) + red line round every tile it can hit next turn
		var fill: Dictionary = v.threatFill if v.threatFill != null else { }
		for key: Vector2i in fill:
			_cell(ci, key.x, key.y, Color(ATTACK, 0.2 + pulse * 0.08), null)
		var th: Dictionary = v.threat
		_outline(ci, th, Color(ATTACK, 0.9), maxf(1.5, T / 24.0))
	for e: Dictionary in v.attackable:
		var ex: int = e.x
		var ey: int = e.y
		_cell(ci, ex, ey, Color(0.878, 0.38, 0.298, 0.18 + pulse * 0.14), ATTACK)
	for t: Array in v.razable:
		var aimed: bool = v.razeAt != null and v.razeAt[0] == t[0] and v.razeAt[1] == t[1]
		var tx: int = t[0]
		var ty: int = t[1]
		_cell(ci, tx, ty, Color(1, 0.6, 0.24, 0.16 + pulse * 0.14), TARGET if aimed else RAZE, 0.1 if aimed else 0.07)
	for e: Dictionary in v.targets:
		var is_t: bool = v.target != null and e.id == v.target
		var ex: int = e.x
		var ey: int = e.y
		_cell(ci, ex, ey, Color(0.878, 0.38, 0.298, 0.2 + pulse * 0.15), TARGET if is_t else ATTACK, 0.1 if is_t else 0.07)
	var path: Array = v.path if v.path != null else []
	if path.size() > 1:
		var pts := []
		for p: Array in path:
			var px: float = p[0]
			var py: float = p[1]
			pts.append(Vector2((px + 0.5) * T, (py + 0.5) * T))
		var w := maxf(3.0, T * 0.1)
		_dashed(ci, pts, PATH, w, T * 0.12, T * 0.14, -time / 30.0)
		for p: Vector2 in pts:
			ci.draw_circle(p, w * 0.5, PATH)
	if v.dest != null:
		var dx: int = v.dest[0]
		var dy: int = v.dest[1]
		_cell(ci, dx, dy, Color(1, 0.878, 0.541, 0.16), TARGET)
	if v.info != null:
		var ix: int = v.info.x
		var iy: int = v.info.y
		_cell(ci, ix, iy, null, Color(0.949, 0.898, 0.788, 0.8), 0.05)
	if v.buyAt != null:
		var bx: int = v.buyAt[0]
		var by: int = v.buyAt[1]
		_cell(ci, bx, by, Color(1, 0.839, 0.4, 0.15 + pulse * 0.15), BUY)
	if v.hover != null and v.dest == null:
		var hx: int = v.hover.x
		var hy: int = v.hover.y
		_cell(ci, hx, hy, null, Color(1, 1, 1, 0.33), 0.04)
	_draw_support_range(ci, pulse)

## hovering (or having selected) a unit that buffs its neighbours: tint the 4 tiles where allies get the bonus
func _draw_support_range(ci: CanvasItem, pulse: float) -> void:
	var src: Variant = null
	if hover != null:
		var hv: Vector2i = hover
		src = Game.unit_at(s, hv.x, hv.y)
	if src == null and view.sel != null:
		src = view.sel
	if src == null:
		return
	var su: Dictionary = src
	var st := Game.stat(s, su)
	if not st.get("aura", 0):
		return
	var col := BUFF_ATK
	var at: Array = view.dest if view.sel != null and su.id == view.sel.id and view.dest != null else [su.x, su.y]
	for dy in range(-2, 3): # AE2 drum: allies within 2 tiles after it acts
		for dx in range(-2, 3):
			var x: int = at[0] + dx
			var y: int = at[1] + dy
			if (dx == 0 and dy == 0) or absi(dx) + absi(dy) > 2 or Game.tile_at(s, x, y) == null:
				continue
			_cell(ci, x, y, Color(col, 0.10 + pulse * 0.08), Color(col, 0.55), 0.04)

## hover-attack forecast pinned above the target: [sword] 40  [back] 24 (gold = kill, red = our unit falls)
func _draw_preview(ci: CanvasItem) -> void:
	var p: Variant = view.get("preview")
	if p == null or s.is_empty():
		return
	var fs := int(clampf(T * 0.24, 12, 20))
	var dmg_min: int = p.dmgMin
	var dmg_max: int = p.dmgMax
	var ctr_min: int = p.counterMin
	var ctr_max: int = p.counterMax
	var give := "%s%s" % [Style.range_txt(dmg_min, dmg_max), " hạ gục" if p.kill else (" có thể hạ" if p.mayKill else "")]
	var take := "%s%s" % [Style.range_txt(ctr_min, ctr_max), " ngã" if p.die else (" có thể ngã" if p.mayDie else "")] \
			if ctr_max > 0 else ""
	var ic := float(fs) * 1.1 # drawn icons (sword = we hit, back arrow = counter)
	var gap := 4.0
	var w1 := ic + gap + Style.xbold.get_string_size(give, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w2 := (12.0 + ic + gap + Style.xbold.get_string_size(take, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) if take != "" else 0.0
	var pad := 7.0
	var w := w1 + w2 + pad * 2
	var h := fs * 1.5
	# laid out in on-screen px (turned board: vis_xf keeps the box upright)
	var tx: int = p.x
	var ty: int = p.y
	var vt := vis_tile(Vector2i(tx, ty))
	var vw := visual_size().x
	var x := clampf((vt.x + 0.5) * T - w / 2, 2, vw - w - 2)
	var y: float = vt.y * T - h - 4
	if y < 2:
		y = (vt.y + 1) * T + 4
	Draw.set_xf(ci, vis_xf())
	var box := Style.box(Style.PAPER_HI, Style.CRIMSON if p.kill or p.die else Style.INK_D, 7, 0, 2)
	ci.draw_style_box(box, Rect2(x, y, w, h))
	var base := y + h / 2 + (Style.xbold.get_ascent(fs) - Style.xbold.get_descent(fs)) / 2
	var iy := y + (h - ic) / 2
	ci.draw_texture_rect(Icons.tex("sword"), Rect2(x + pad, iy, ic, ic), false)
	ci.draw_string(Style.xbold, Vector2(x + pad + ic + gap, base), give, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.CRIMSON_D if p.kill else Style.GOOD)
	if take != "":
		var x2 := x + pad + w1 + 12.0
		ci.draw_texture_rect(Icons.tex("back"), Rect2(x2, iy, ic, ic), false)
		ci.draw_string(Style.xbold, Vector2(x2 + ic + gap, base), take, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.BAD)
	Draw.set_xf(ci, Transform2D.IDENTITY)

func _draw_units(ci: CanvasItem, time: float) -> void:
	_info_spots.clear()
	var v := view
	var list := _figures(time)
	for it: Dictionary in list:
		it.x += it.stack.x
		it.y += it.stack.y
		it.scale = 1.0
		if it.k >= 0.0:
			it.die = it.k
	var rig_t := { } # target id -> live attack rig: its back / mid fx wrap that token (tornado halves)
	var z := { } # unit id -> same-row rank: rig target 0, others 1, rig attacker 2 (demo: back, target, mid, attacker)
	for r: Rig in fx.rigs:
		rig_t[r.d_id] = fx.rig_of_target(r.d_id)
		z[r.d_id] = 0
	for r: Rig in fx.rigs:
		if r.shown:
			z[r.a_id] = 2
	# deterministic: sort_custom is not stable. Back to front by on-screen row (turned board: row = -map x)
	for it: Dictionary in list:
		var ix: float = it.x
		var iy: float = it.y
		it.sr = -ix if rot else iy
		it.sc = iy if rot else ix
	list.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a.sr != b.sr:
				return a.sr < b.sr
			var za: int = z.get(a.u.id, 1)
			var zb: int = z.get(b.u.id, 1)
			if za != zb:
				return za < zb
			if a.sc != b.sc:
				return a.sc < b.sc
			return a.u.id < b.u.id,
	)
	var sel_id: int = v.sel.id if v.sel != null else -1
	var st := ci.get_screen_transform()
	var back_at := { } # list index -> rigs whose back layer goes there: before the first drawn of attacker / target
	for r: Rig in rig_t.values():
		for i in list.size():
			var li: Dictionary = list[i]
			var lu: Dictionary = li.u
			if lu.id == r.d_id or (lu.id == r.a_id and r.shown and not li.has("die")):
				back_at[i] = back_at.get(i, []) + [r]
				break
	var back_done := { }
	var rig_done := { }
	for i in list.size():
		var it: Dictionary = list[i]
		var u: Dictionary = it.u
		var uid: int = u.id
		var side: String = u.side
		var type: String = u.type
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
		var ux := up_xf(c)
		Draw.set_xf(ci, ux)
		if is_sel:
			Draw.ellipse_line(ci, c + Vector2(0, T * 0.32), T * 0.36, T * 0.12, sel_color(time), maxf(2.0, T * 0.05))
		var alpha: float = it.alpha if it.alpha >= 0 else 1.0
		var acted: bool = u.get("acted", false) and s.side == u.side and not v.busy and not it.has("die")
		var tint := Color(0.42, 0.42, 0.45) if acted else Color.WHITE # done this turn: the figure greys out
		var pose := _pose(u, it, x, y, off, time, is_sel)
		var pose_flash: float = pose.flash
		flash = maxf(flash, pose_flash)
		# rigs are placed on on-screen tiles (fx.rig_attack) and drawn in on-screen px
		Draw.set_xf(ci, vis_xf())
		for rb: Rig in back_at.get(i, []):
			rb.draw_layer(ci, "back")
			back_done[rb] = true
		var rg: Rig = fx.rig_of_attacker(uid) if not it.has("die") else null
		var it_sc: float = it.scale
		if rg != null: # mid-attack: the rig stands in for the token (same size, same feet)
			rg.draw_char(ci)
		else:
			var shadow: float = pose.shadow
			var pose_xf: Transform2D = pose.xf
			var still: bool = pose.still
			Draw.set_xf(ci, ux)
			_atlas.draw_shadow(ci, c, it_sc, alpha, shadow)
			Draw.set_xf(ci, ux * pose_xf)
			if flash > 0 or _zoom > 0.0: # hit flash / close-up: paint live (white figure; crisp at any scale)
				var o := { "alpha": alpha, "flash": flash, "shadow": false, "tint": tint }
				if _zoom > 0.0:
					o.rs = _zoom_rs()
				Token.paint(ci, c, T * it_sc, side, type, s.heroKey[side], o)
			elif not _atlas.draw(ci, st * ux, c, side, type, 0.0, it_sc, alpha, tint, false, still):
				Token.paint(ci, c, T * it_sc, side, type, s.heroKey[side], { "alpha": alpha, "shadow": false })
		if rt != null:
			rig_done[u.id] = true
			Draw.set_xf(ci, vis_xf())
			rt.draw_layer(ci, "mid")
		Draw.set_xf(ci, ux)
		if it.alpha < 0 or it.alpha > 0.5:
			draw_unit_badges(ci, v, u, c, T)
			if it.alpha < 0 and off == null and not v.busy and not it.has("die"):
				_draw_buffs(ci, u, c, roundi(x), roundi(y), time)
	Draw.set_xf(ci, vis_xf())
	for r: Rig in fx.rigs:
		if not rig_done.has(r.d_id) or rig_t.get(r.d_id) != r: # target not drawn, or an older rig on the same target
			if not back_done.has(r):
				r.draw_layer(ci, "back")
			r.draw_layer(ci, "mid")
	Draw.set_xf(ci, Transform2D.IDENTITY)
	if not v.busy: # ours inside the picked enemy's threat zone: red "!" badge, top right
		for uid: int in v.danger:
			var du: Variant = Game.unit_by_id(s, uid)
			if du == null:
				continue
			var dx: float = du.x
			var dy: float = du.y
			var bc := Vector2((dx + 0.84) * T, (dy + 0.16) * T)
			var br := T * 0.13
			Draw.set_xf(ci, up_xf(Vector2(dx + 0.5, dy + 0.5) * T))
			ci.draw_circle(bc, br + maxf(1.0, T * 0.02), Color(0.1, 0.03, 0.02, 0.9))
			ci.draw_circle(bc, br, ATTACK.lightened(0.05 + sin(time / 200.0) * 0.08))
			Draw.text_c(ci, Style.xbold, bc, "!", roundi(T * 0.2), Color.WHITE)
		Draw.set_xf(ci, Transform2D.IDENTITY)

## hp bar + number (when hurt), rank stars, sleeping-sentry 💤 around a figure centred at c (tile size ts).
static func draw_unit_badges(ci: CanvasItem, v: Dictionary, u: Dictionary, c: Vector2, ts: float) -> void:
	var hp: int = u.hp
	if v.hp != null:
		var hps: Dictionary = v.hp
		hp = hps.get(u.id, u.hp)
	var counting: Dictionary = v.get("hpCount", { })
	hp = counting.get(u.id, hp) # turn-start heal counting up
	if hp < 100:
		var w := ts * 0.62
		var h := maxf(3.0, ts * 0.07)
		var bx := c.x - w / 2
		var byy := c.y + ts * 0.36
		ci.draw_rect(Rect2(bx - 1, byy - 1, w + 2, h + 2), Color(0, 0, 0, 0.73))
		ci.draw_rect(Rect2(bx, byy, w * maxi(0, hp) / 100.0, h), Style.hp_color(hp))
		Draw.text_a(
			ci,
			Style.xbold,
			Vector2(c.x + ts * 0.48, c.y + ts * 0.3),
			str(maxi(0, hp)),
			roundi(ts * 0.22),
			Color.WHITE,
			1.0,
			false,
			3,
			Color.BLACK,
		)
	if u.rank:
		Draw.text_a(ci, Style.xbold, Vector2(c.x - ts * 0.48, c.y - ts * 0.5), "Lv%d" % u.rank, roundi(ts * 0.2), STAR, 0.0, true, 3, STAR_INK)
	if u.get("guard", false) and u.side == "e": # sleeping sentry (not the guard *stat*)
		var zs := ts * 0.26
		ci.draw_texture_rect(Icons.tex("sleep"), Rect2(Vector2(c.x + ts * 0.2, c.y - ts * 0.62), Vector2(zs, zs)), false)

## how a figure stands this frame, as a transform around its feet: walking hops + sways + faces where it goes,
## striking leans into the blow (fx.offsets), getting hit shoves it back (fx.knock), dying topples it over (ghost),
## idle breathes, the selected one bounces. shadow = how big its ground shadow is (smaller in the air).
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
		if last != null:
			var lp: Vector2 = last
			var mv := scr(Vector2(bx, by) - lp)
			if absf(mv.x) > 0.001:
				face = signf(mv.x)
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
		var o0: Vector2 = off
		var o := scr(o0)
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
			var mag: float = kn.mag
			var kd0: Vector2 = kn.dir
			var kdir := scr(kd0)
			var a := (1.0 - k) * (1.0 - k) * mag
			shift += kdir * 0.13 * T * a
			lean += kdir.x * 0.32 * a - (0.0 if absf(kdir.x) > 0.3 else 0.12 * a)
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
			var f0: float = tn.from
			var f1: float = tn.to
			face = Rig.thin(lerpf(f0, f1, smoothstep(0.0, 1.0, k)))
	if face != home:
		still = false
	var foot := Vector2((x + 0.5) * T, (y + 0.5) * T + T * Token.FOOT)
	var xf := Transform2D(lean, Vector2(sx * face * home, sy), 0.0, foot + shift - Vector2(0, lift)) * Transform2D(0.0, Vector2.ONE, 0.0, -foot)
	return { "xf": xf, "still": still and is_equal_approx(sy, 1.0), "shadow": clampf(1.0 - lift / T * 1.6, 0.6, 1.0), "flash": rflash }

## which way a unit's figure looks on screen (+1 right / -1 left); a rig attack turns it toward its target
func face_of(id: int, side: String) -> float:
	return _face.get(id, 1.0 if side == "p" else -1.0)

## also drops the last drawn spot: a stale one (hidden while it moved) would re-face it by movement on the next frame
func set_face(id: int, f: float) -> void:
	_face[id] = f
	_last_xy.erase(id)

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
	var uid: int = u.id
	var pulse := 0.5 + 0.5 * sin(time / 300.0 + uid)
	var ring := BUFF_UP if arrows[0] else POISON
	Draw.ellipse_line(ci, c + Vector2(0, T * 0.36), T * 0.44, T * 0.16, Color(ring, 0.45 + pulse * 0.4), maxf(1.5, T * 0.035))
	var h := maxf(12.0, T * 0.3) # arrow height
	var w := h * 0.62
	for k in arrows.size():
		var up: bool = arrows[k]
		var bob := sin(time / 260.0 + uid + k * 1.3) * h * 0.12
		var p := c + Vector2(-T * 0.4 + k * w * 0.95, -T * 0.34 + bob) # arrow tip (up) / tail (down), beside the head
		var sy := 1.0 if up else -1.0
		var o := p if up else p + Vector2(0, h)
		var pts := PackedVector2Array(
			[
				o,
				o + Vector2(w / 2.0, h * 0.5 * sy),
				o + Vector2(w * 0.2, h * 0.5 * sy),
				o + Vector2(w * 0.2, h * sy),
				o + Vector2(-w * 0.2, h * sy),
				o + Vector2(-w * 0.2, h * 0.5 * sy),
				o + Vector2(-w / 2.0, h * 0.5 * sy),
			]
		)
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
			var ux: float = u.x
			var uy: float = u.y
			lights.append(Vector3(ux, uy, 2.4))
	for k: Vector2i in s.owner:
		if s.owner[k] == "p":
			lights.append(Vector3(k.x, k.y, 1.9))
			torches.append(Vector2(k))
	for g: Dictionary in s.graves:
		var gx: float = g.x
		var gy: float = g.y
		lights.append(Vector3(gx, gy, 0.9))
	lights.resize(mini(lights.size(), 128))
	torches.resize(mini(torches.size(), 64))
	var m: ShaderMaterial = _night.material
	m.set_shader_parameter("board_px", _px())
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
	var sw: int = s.w
	for c: Dictionary in _clouds:
		var cx: float = c.x
		var cy: float = c.y
		var cv: float = c.v
		var cr: float = c.r
		var x := fmod(cx + time * cv, sw + 8.0) - 4.0
		Draw.glow(ci, Vector2(x * T, cy * T), cr * T, Color(0.04, 0.08, 0.04, 0.13))

## fireflies by night (additive layer)
func _draw_fireflies(ci: CanvasItem) -> void:
	if s.is_empty() or not s.night:
		return
	var time := FX.now()
	for m: Dictionary in _motes:
		var mp: float = m.p
		var mx: float = m.x
		var my: float = m.y
		var a := (sin(time / 300.0 + mp * 3) + 1) / 2
		ci.draw_circle(Vector2(mx * T, my * T), T * 0.035, Color(0.82, 1.0, 0.55, a * 0.8))

## firefly drift, per second (was per drawn frame, so it sped up with the frame rate); tuned to the old 60 fps look
func _drift_motes(dt: float) -> void:
	if _motes.size() < 26:
		_motes.append({ "x": randf() * s.w, "y": randf() * s.h, "p": randf() * 6 })
	var time := FX.now()
	var k := minf(dt, 0.1) * 60.0
	for m: Dictionary in _motes:
		var mp: float = m.p
		m.x += sin(time / 900.0 + mp) * 0.004 * k
		m.y += cos(time / 1100.0 + mp) * 0.003 * k
