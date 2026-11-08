class_name WorldMap
extends Control
## "Thử thách" as a kingdom map (geography: content/world_map.gd; premise "Ngọn Lửa Lâu Đài"). One shield per level on
## the march route: won = ours (red shield, best stars under it, land glows red), not won = the Empire's (blue), not
## open yet = faded + Empire haze, whole region not open = clouds. Scenery = the board's chibi terrain art without its
## grass square. Drag / wheel pans (never below K_MIN px per map unit; portrait fills the height). Nothing selected
## at first (the next level pulses); tap a shield = its card in the middle of the screen over a dim layer (title,
## setting line, short goal, best stars, "Xuất quân" = level_picked); tap outside = closes. The map never jumps on a
## tap. Opens centred on the next level, or on `focus_id` (back from a level).

signal level_picked(id: String)

const Geo := preload("res://content/world_map.gd")
const ART := "res://assets/terrain/chibi/%s.svg"
const K_MIN := 10.5 # px per map unit at least: villages ~65 px, stars ~25 px across (reference look: few big markers, pan)
const HIT_R := 3.8
const CLOUD := Color("#f7f3ea")
const CLOUD_SHADE := Color("#ddd5c6")
const DRAG_PX := 8.0
const TOP_PAD := 64.0 # back button over the map
const LAND := Color("#ead6a4")
const STAIN := Color("#c9a66a")
const SEA := Color("#86b3bd")
const SEA_D := Color("#5f93a3")
const WATER := Color("#5f97a8")
const ROAD := Color("#f4e4bb")
const ROAD_EDGE := Color("#c9a467")
const ROAD_DASH := Color("#6e4f30")
const STAR_ON := Color("#f6a935")
const STAR_HI := Color("#ffe08a")
const STAR_OFF := Color("#3b2a20")
const SEG := 10 # road samples between two levels
const VILLAGE := 6.2 # building art box, map units: easy / mid levels
const FORT := 7.6 # hard levels

var levels: Array = []
var open_index := 0
var sel := -1 # level whose card is open (-1 = none)
var next := -1 # first level not won (pulsing)
var focus := 0 # level the map opened centred on
var _k := K_MIN
var _off := Vector2.ZERO
var _t := 0.0
var _down := false
var _dragging := false
var _press := Vector2.ZERO
var _press_off := Vector2.ZERO
var _card: PanelContainer
var _dim: ColorRect # under the card: dims the map, a tap on it closes the card
var _rivers: Array[PackedVector2Array] = []
var _coast := PackedVector2Array()
var _decor := [] # [y, art name, centre, size] back to front
var _road := PackedVector2Array() # one smooth road through every level in march order (map units)
var _road_at := { } # level index -> its sample index on _road
var _bridges := [] # [centre, direction] where the road crosses a river (map units)

func setup(lv: Array, open: int, focus_id := "") -> void:
	levels = lv
	open_index = open
	next = LevelSelect.first_unwon(lv, open)
	focus = mini(next, lv.size() - 1)
	for i in lv.size():
		var def: Dictionary = lv[i]
		if str(def.id) == focus_id:
			focus = i
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_rivers.clear()
	for r: Array in Geo.RIVERS:
		var rpts: Array = r[1]
		_rivers.append(smooth(rpts))
	_coast = smooth(Geo.COAST)
	_build_road()
	_decor.clear()
	for spec: Array in [[Geo.PEAKS, "mountain"], [Geo.WOODS, "forest"], [Geo.HILLS, "hill"]]:
		var items: Array = spec[0]
		var kind: String = spec[1]
		for it: Array in items:
			var x: float = it[0]
			var y: float = it[1]
			var s: float = it[2]
			var nm := "%s_%s" % [kind, "a" if Board.hash01(int(x * 10), int(y * 10), 5) < 0.5 else "b"]
			_decor.append([y, nm, Vector2(x, y), s])
	_decor.sort_custom(
		func(a: Array, b: Array) -> bool:
			return a[0] < b[0],
	)
	_dim = ColorRect.new()
	_dim.color = Color(Style.INK_D, 0.45)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	_dim.gui_input.connect(
		func(ev: InputEvent) -> void:
			var mb := ev as InputEventMouseButton
			if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				deselect(),
	)
	add_child(_dim)
	_card = PanelContainer.new()
	var box := Style.paper(16.0)
	box.shadow = Vector2(5, 6)
	_card.add_theme_stylebox_override("panel", box)
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 0.5
	_card.anchor_bottom = 0.5
	_card.visible = false
	add_child(_card)
	resized.connect(_fit)
	_card_width()
	_fit.call_deferred()

## level index i -> map position (Vector2.INF = not on the map)
func pos_of(i: int) -> Vector2:
	var def: Dictionary = levels[i]
	return Geo.POS.get(str(def.id), Vector2.INF)

## the march road: one Catmull-Rom curve through every placed level, in order (levels sit on it)
func _build_road() -> void:
	var pts := []
	_road_at.clear()
	for i in levels.size():
		var q := pos_of(i)
		if q != Vector2.INF:
			_road_at[i] = pts.size() * SEG
			pts.append(q)
	_road = smooth(pts, SEG) if pts.size() > 1 else PackedVector2Array()
	_bridges.clear()
	for river: PackedVector2Array in _rivers:
		for a in _road.size() - 1:
			for b in river.size() - 1:
				var hit: Variant = Geometry2D.segment_intersects_segment(_road[a], _road[a + 1], river[b], river[b + 1])
				if hit != null:
					var at: Vector2 = hit
					_bridges.append([at, (_road[a + 1] - _road[a]).normalized()])

func _p(v: Vector2) -> Vector2:
	return _off + v * _k

func _locked(i: int) -> bool:
	var def: Dictionary = levels[i]
	return i > open_index and not Store.is_done(str(def.id))

func _fit() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	_k = maxf(minf(size.x / Geo.VB.x, size.y / Geo.VB.y), K_MIN)
	if size.y > size.x: # portrait: fill the height (bigger shields for thumbs), pan sideways
		_k = maxf(_k, (size.y - TOP_PAD - 24.0) / Geo.VB.y)
	_card_width()
	_center_on(focus)

## card: fixed width (autowrapped labels need it before layout), centred on the screen
func _card_width() -> void:
	var vw := size.x if size.x >= 1.0 else get_viewport_rect().size.x
	var w := minf(440.0, vw - 32.0)
	_card.custom_minimum_size.x = w
	_card.offset_left = -w / 2.0
	_card.offset_right = w / 2.0
	_place_card()

## centred at its real (minimum) height: never left taller than its content
func _place_card() -> void:
	var h := _card.get_combined_minimum_size().y
	_card.offset_top = -h / 2.0
	_card.offset_bottom = h / 2.0

## keep the map on screen with room for the header above (and the open card below); smaller than the screen = centred
func _clamp(o: Vector2) -> Vector2:
	var m := Geo.VB * _k
	var bottom := 16.0
	var out := o
	out.x = (size.x - m.x) / 2.0 if m.x <= size.x else clampf(o.x, size.x - m.x, 0.0)
	var room := size.y - TOP_PAD - bottom
	out.y = TOP_PAD + (room - m.y) / 2.0 if m.y <= room else clampf(o.y, size.y - bottom - m.y, TOP_PAD)
	return out

func _center_on(i: int) -> void:
	var p := pos_of(i)
	if p == Vector2.INF:
		return
	_off = _clamp(Vector2(size.x * 0.5, TOP_PAD + (size.y - TOP_PAD) * 0.45) - p * _k)
	queue_redraw()

## tap a shield: its card in the middle of the screen (the map stays where it is)
func select(i: int) -> void:
	if i < 0 or i >= levels.size():
		return
	sel = i
	_dim.visible = true
	_card.visible = true # build while shown: autowrapped labels measured hidden report one word per line (card 1100+ px)
	_build_card()
	_settle(i)
	queue_redraw()

## close the card (tap outside it)
func deselect() -> void:
	sel = -1
	_dim.visible = false
	_card.visible = false
	queue_redraw()

## re-centre the card once its labels wrapped at the card width (real height known one frame after building)
func _settle(i: int) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if sel == i:
		_place_card()

## "Xuất quân": start the selected level (open ones only)
func go() -> void:
	if sel < 0 or _locked(sel):
		return
	var def: Dictionary = levels[sel]
	level_picked.emit(str(def.id))

func _build_card() -> void:
	for c in _card.get_children():
		_card.remove_child(c)
		c.queue_free()
	var def: Dictionary = levels[sel]
	var locked := _locked(sel)
	var v := Style.vbox(6)
	_card.add_child(v)
	var head := Style.hbox(10)
	v.add_child(head)
	var tier := LevelSelect.tier_of(def)
	var tc: Color = LevelSelect.TIER_COL[tier]
	var num := Style.lbl("%d" % (sel + 1), 20, tc, Style.display)
	num.tooltip_text = str(LevelSelect.TIER_NAME[tier])
	head.add_child(num)
	var title := Style.lbl(str(def.get("title", "")), 22, Style.GOLD if not locked else Style.MUTED, Style.display)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title)
	var got := Store.stars_of(str(def.id))
	for k in Stars.MAX:
		var ic := HudWidgets.StarIcon.new()
		ic.custom_minimum_size = Vector2(18, 18)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.on = k < got
		head.add_child(ic)
	if str(def.get("lore", "")) != "":
		v.add_child(Style.lbl(str(def.lore), 14, Style.MUTED, Style.semi, true))
	var win: Dictionary = def.get("win", { })
	var goal := Content.goal_text(win, "short", { "p": def.get("hero"), "e": def.get("enemyHero") })
	v.add_child(Style.lbl(goal, 15, Style.INK, Style.bold, true))
	if locked:
		v.add_child(Style.lbl(Content.text("mapLocked"), 13, Style.MUTED, null, true))
	else:
		var b := Style.menu_button(Content.text("mapGo"), "", true)
		b.pressed.connect(go)
		v.add_child(b)
	_place_card()

func _node_at(at: Vector2) -> int:
	var best := -1
	var bd := HIT_R * _k
	for i in levels.size():
		var p := pos_of(i)
		if p == Vector2.INF:
			continue
		var d := at.distance_to(_p(p))
		if d <= bd:
			best = i
			bd = d
	return best

func _gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	var mm := ev as InputEventMouseMotion
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_down = true
			_dragging = false
			_press = mb.position
			_press_off = _off
		elif _down:
			_down = false
			if not _dragging:
				var i := _node_at(mb.position)
				if i >= 0:
					select(i)
				else:
					deselect()
		accept_event()
	elif mb != null and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]: # desktop: wheel pans
		var step := 6.0 * _k * (1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
		_off = _clamp(_off + (Vector2(step, 0) if mb.shift_pressed else Vector2(0, step)))
		accept_event()
	elif mm != null:
		if _down and (_dragging or mm.position.distance_to(_press) > DRAG_PX):
			_dragging = true
			_off = _clamp(_press_off + mm.position - _press)
			queue_redraw()
		elif not _down:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _node_at(mm.position) >= 0 else Control.CURSOR_ARROW

func _process(dt: float) -> void:
	_t += dt
	if is_visible_in_tree():
		queue_redraw()

## Catmull-Rom through the points
static func smooth(pts: Array, seg := 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		for s in seg:
			var t := float(s) / seg
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	var last: Vector2 = pts[n - 1]
	out.append(last)
	return out

## board terrain art without its grass square / ground patches, so it sits on the parchment
static func strip_ground(svg: String) -> String:
	var out := PackedStringArray()
	for line in svg.split("\n"):
		if line.begins_with("<rect") and line.contains('width="256" height="256"'):
			continue
		if line.begins_with("<ellipse") and (line.contains("#86ab57") or line.contains("#b3d17c") or line.contains("#82a653")):
			continue
		out.append(line)
	return "\n".join(out)

func _art(art_name: String, px: float, strip := true) -> Texture2D:
	var path := ART % art_name
	if not FileAccess.file_exists(path):
		return null
	if not strip:
		return Token.raster(path, px)
	return Token.raster_svg(
		"map:" + path,
		func() -> String:
			return strip_ground(FileAccess.get_file_as_string(path)),
		px,
	)

func _xf(pts: PackedVector2Array, shift := Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(_p(q + shift))
	return out

func _draw() -> void:
	Draw.xf = Transform2D.IDENTITY
	var k := _k
	var ink := Style.INK_D
	var px := Baked.screen_scale(self)
	var land := Rect2(_p(Vector2.ZERO), Geo.VB * k)
	draw_rect(Rect2(land.position + Vector2(5, 6), land.size), Color(ink, 0.8)) # hard shadow
	draw_rect(land, LAND)
	for j in 7: # old-paper stains
		var sc := Vector2(Board.hash01(j, 3, 1) * Geo.VB.x, Board.hash01(j, 5, 2) * Geo.VB.y)
		Draw.glow(self, _p(sc), (14.0 + 10.0 * Board.hash01(j, 7, 3)) * k, Color(STAIN, 0.16))
	_draw_sea(k, ink)
	_draw_territory(k)
	_draw_route(k)
	_draw_water(k, ink)
	_draw_bridges(k, ink)
	for d: Array in _decor:
		var at: Vector2 = d[2]
		var s: float = d[3] * k
		var tex := _art(str(d[1]), s * px)
		if tex != null:
			draw_texture_rect(tex, Rect2(_p(at) - Vector2(s, s) / 2.0, Vector2(s, s)), false)
	_draw_marks(k, ink)
	_draw_fog(k)
	_draw_names(k, ink)
	_draw_frame(land, k, ink)

func _draw_sea(k: float, ink: Color) -> void:
	var sea := _xf(_coast)
	sea.append(_p(Geo.VB))
	sea.append(_p(Vector2(Geo.VB.x, 0)))
	draw_colored_polygon(sea, SEA)
	for j in 3: # ripples along the shore, fading out to sea
		var d := 1.3 + j * 1.5
		draw_polyline(_xf(_coast, Vector2(d, 0)), Color(1, 1, 1, 0.38 - j * 0.11), maxf(1.0, 0.22 * k), true)
	draw_polyline(_xf(_coast), ink, maxf(1.5, 0.35 * k), true)
	for j in 14:
		var wv := Vector2(136.0 + Board.hash01(j, 1, 9) * 12.0, 4.0 + j * 7.5)
		var sh := sin(_t * 1.1 + j) * 0.5 * k
		draw_arc(_p(wv) + Vector2(sh, 0), 1.1 * k, PI * 1.15, PI * 1.85, 8, Color(SEA_D, 0.9), maxf(1.0, 0.22 * k), true)
	for i in Geo.SHIPS.size():
		var sp: Vector2 = Geo.SHIPS[i]
		_draw_ship(_p(sp) + Vector2(0, sin(_t * 1.6 + i * 2.0) * 0.3 * k), k, ink, i)
	_draw_compass(_p(Geo.COMPASS), k, ink)

func _draw_ship(c: Vector2, k: float, ink: Color, i: int) -> void:
	var xf := Transform2D(sin(_t * 1.3 + i) * 0.06, c)
	var hull := PackedVector2Array([Vector2(-2.4, 0), Vector2(2.4, 0), Vector2(1.6, 1.2), Vector2(-1.7, 1.2)])
	var sail := PackedVector2Array([Vector2(0, -3.6), Vector2(1.9, -0.5), Vector2(0, -0.5)])
	var sail2 := PackedVector2Array([Vector2(-0.2, -3.0), Vector2(-0.2, -0.6), Vector2(-1.7, -0.6)])
	for poly: Array in [[hull, Color("#7a4b2a")], [sail, Style.PAPER_HI], [sail2, Color(Style.ROYAL, 0.85)]]:
		var pts := PackedVector2Array()
		var src: PackedVector2Array = poly[0]
		var col: Color = poly[1]
		for q in src:
			pts.append(xf * (q * k))
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, ink, maxf(1.0, 0.18 * k), true)
	draw_line(xf * Vector2(0, -3.8 * k), xf * Vector2.ZERO, ink, maxf(1.0, 0.2 * k), true)

## compass rose: 4 long + 4 short points, ring, "B" (bắc) on top
func _draw_compass(c: Vector2, k: float, ink: Color) -> void:
	var r := 4.2 * k
	draw_arc(c, r * 0.72, 0, TAU, 40, Color(ink, 0.7), maxf(1.0, 0.18 * k), true)
	for j in 8:
		var a := -PI / 2.0 + j * PI / 4.0
		var reach := r if j % 2 == 0 else r * 0.55
		var tip := c + Vector2(cos(a), sin(a)) * reach
		var side := Vector2(cos(a + PI / 2.0), sin(a + PI / 2.0)) * r * 0.16
		draw_colored_polygon(PackedVector2Array([c + side, tip, c]), ink if j % 2 == 0 else Color(ink, 0.6))
		draw_colored_polygon(PackedVector2Array([c - side, tip, c]), Style.PAPER_HI if j != 0 else Style.CRIMSON)
	Draw.text_c(self, Style.display, c + Vector2(0, -r - 1.4 * k), "B", roundi(2.2 * k), ink)

## won land glows red (breathing); not open yet = Empire haze
func _draw_territory(k: float) -> void:
	var breath := 0.85 + 0.15 * cos(_t * TAU / 3.0)
	for i in levels.size():
		var p := pos_of(i)
		if p != Vector2.INF and _locked(i):
			Draw.glow(self, _p(p), 10.0 * k, Color(Style.ROYAL, 0.26))
	for i in levels.size():
		var p := pos_of(i)
		var def: Dictionary = levels[i]
		if p != Vector2.INF and Store.is_done(str(def.id)):
			Draw.glow(self, _p(p), 10.5 * k, Color(Style.CRIMSON, 0.3 * breath))

## lakes, rivers (thin at the source, wide at the mouth, a highlight drifting downstream), reeds
func _draw_water(k: float, ink: Color) -> void:
	for l: Array in Geo.LAKES:
		var lc: Vector2 = l[0]
		var rx: float = l[1]
		var ry: float = l[2]
		Draw.ellipse(self, _p(lc), rx * k + 1.5, ry * k + 1.5, ink)
		Draw.ellipse(self, _p(lc), rx * k, ry * k, WATER)
		Draw.ellipse_line(self, _p(lc + Vector2(-0.6, -0.4)), rx * k * 0.6, ry * k * 0.45, Color(1, 1, 1, 0.35), maxf(1.0, 0.2 * k))
	for i in _rivers.size():
		var rw: float = Geo.RIVERS[i][0]
		var pts := _xf(_rivers[i])
		var n := pts.size()
		for pass_ink: bool in [true, false]:
			for j in n - 1:
				var w := rw * k * lerpf(0.45, 1.0, float(j) / maxf(1.0, n - 2))
				var ww := w + maxf(2.4, 0.5 * k) if pass_ink else w
				var col := ink if pass_ink else WATER
				draw_line(pts[j], pts[j + 1], col, ww, true)
				draw_circle(pts[j + 1], ww / 2.0, col)
		var flow := fposmod(_t * 0.35, 1.0)
		for j in range(0, n - 1, 6):
			draw_circle(pts[j].lerp(pts[mini(j + 3, n - 1)], flow), maxf(1.0, 0.18 * k), Color(1, 1, 1, 0.5))
	for r: Array in Geo.REEDS:
		var rx0: float = r[0]
		var ry0: float = r[1]
		var rc := _p(Vector2(rx0, ry0))
		for j in 4:
			var rx := rc + Vector2((j - 1.5) * 0.7 * k, 0)
			draw_line(rx, rx + Vector2((j - 1.5) * 0.15 * k, -1.5 * k), Color(ink, 0.6), maxf(1.0, 0.2 * k), true)

## the road: light dirt band with darker edges and a dashed middle; past the next level it fades
func _draw_route(k: float) -> void:
	if _road.size() < 2:
		return
	var cut: int = _road_at.get(next, _road.size() - 1) if next < levels.size() else _road.size() - 1
	for part: Array in [[0, cut + 1, 1.0], [cut, _road.size(), 0.5]]:
		var a: int = part[0]
		var b: int = part[1]
		if b - a < 2:
			continue
		var al: float = part[2]
		var pts := _xf(_road.slice(a, b))
		for layer: Array in [[ROAD_EDGE, 3.0], [ROAD, 2.3]]:
			var col: Color = layer[0]
			var w: float = layer[1] * k
			draw_polyline(pts, Color(col, al), w, true)
			for q in pts: # round joints on tight bends
				draw_circle(q, w / 2.0, Color(col, al))
		var run := 0.0 # dashed middle line
		for j in pts.size() - 1:
			var seg_len := pts[j].distance_to(pts[j + 1])
			if fposmod(run, 1.9 * k) < 1.0 * k:
				draw_line(pts[j], pts[j + 1], Color(ROAD_DASH, 0.85 * al), maxf(1.5, 0.3 * k), true)
			run += seg_len

## wooden bridge where the road crosses a river: planks across the road direction, rails, ink edge
func _draw_bridges(k: float, ink: Color) -> void:
	for br: Array in _bridges:
		var at: Vector2 = br[0]
		var c := _p(at)
		var d: Vector2 = br[1]
		var n := Vector2(-d.y, d.x)
		var hl := 2.2 * k # half length along the road
		var hw := 1.5 * k # half width
		var deck := PackedVector2Array([c - d * hl - n * hw, c + d * hl - n * hw, c + d * hl + n * hw, c - d * hl + n * hw])
		draw_colored_polygon(deck, Color("#a77a47"))
		for j in 7:
			var t := -hl + (j + 0.5) * (2.0 * hl / 7.0)
			draw_line(c + d * t - n * hw, c + d * t + n * hw, Color("#6e4a28"), maxf(1.0, 0.15 * k), true)
		for side: float in [-1.0, 1.0]:
			draw_line(c - d * hl + n * hw * side, c + d * hl + n * hw * side, Color("#5a3a1e"), maxf(2.0, 0.35 * k), true)
		deck.append(deck[0])
		draw_polyline(deck, ink, maxf(1.2, 0.2 * k), true)

## level ids of every region with no level open yet (still unknown land: clouds, no shields)
func _unseen_ids() -> Dictionary:
	var out := { }
	for rg: Dictionary in Geo.REGIONS:
		var unseen := true
		for id: String in rg.ids:
			var i := Content.level_index(id)
			unseen = unseen and i >= 0 and _locked(i)
		if unseen:
			for id: String in rg.ids:
				out[id] = true
	return out

## clouds over unknown regions: one drifting cumulus per level spot
func _draw_fog(k: float) -> void:
	for id: String in _unseen_ids():
		var p: Vector2 = Geo.POS.get(id, Vector2.INF)
		if p == Vector2.INF:
			continue
		var h := Board.hash01(int(p.x), int(p.y), 2)
		var at := p + Vector2((h - 0.5) * 3.0 + sin(_t * 0.22 + p.x) * 0.9, (Board.hash01(int(p.y), int(p.x), 4) - 0.5) * 2.0)
		_cloud(_p(at), (10.0 + h * 3.0) * k, k, h)

## cartoon cumulus: 4-5 round lobes on a flat rounded base; ink edge = the same shapes drawn a little larger first,
## grey underside, soft highlight on the top lobes. c = base centre, w = width px
func _cloud(c: Vector2, w: float, k: float, sd: float) -> void:
	var n := 4 + (1 if sd > 0.5 else 0)
	var lobes := []
	for j in n:
		var t := (j + 0.5) / n
		var hump := 1.0 - absf(t - 0.5) * 1.4 # middle lobes bigger and higher
		var r := w * (0.13 + 0.11 * hump + 0.03 * Board.hash01(j, int(sd * 97.0), 3))
		lobes.append([c + Vector2((t - 0.5) * w * 0.74, -r * 0.45 - w * 0.07 * hump), r])
	var bh := w * 0.17 # base: a capsule along the bottom
	var base := Rect2(c + Vector2(-w * 0.42, -bh * 0.5), Vector2(w * 0.84, bh))
	var e := maxf(1.5, 0.3 * k)
	draw_rect(Rect2(base.position + Vector2(0, bh * 0.5 + e), Vector2(base.size.x, e * 1.5)), Color(Style.ROYAL_D, 0.12)) # shadow
	for pass_i in 2: # 0: ink edge (lobes + base, a little larger), 1: grey base (= underside), lobes on top
		var grow := e if pass_i == 0 else 0.0
		var base_col := Style.INK_D if pass_i == 0 else CLOUD_SHADE
		draw_rect(base.grow(grow).grow_individual(-bh * 0.5, 0, -bh * 0.5, 0), base_col)
		draw_circle(Vector2(base.position.x, base.get_center().y), bh * 0.5 + grow, base_col)
		draw_circle(Vector2(base.end.x, base.get_center().y), bh * 0.5 + grow, base_col)
		for lb: Array in lobes:
			var lc: Vector2 = lb[0]
			var lr: float = lb[1]
			draw_circle(lc, lr + grow, Style.INK_D if pass_i == 0 else CLOUD)
	for lb: Array in lobes:
		var lc: Vector2 = lb[0]
		var lr: float = lb[1]
		draw_circle(lc + Vector2(-0.25, -0.3) * lr, lr * 0.45, Color(1, 1, 1, 0.55))

## region names (spaced capitals; red once every level in it is won), sea / river names
func _draw_names(k: float, ink: Color) -> void:
	for rg: Dictionary in Geo.REGIONS:
		var all_done := true
		for id: String in rg.ids:
			all_done = all_done and Store.is_done(id)
		var col := Color(Style.CRIMSON_D, 0.9) if all_done else Color(ink, 0.5)
		var at: Vector2 = rg.at
		var spaced := " ".join(str(rg.name).to_upper().split(""))
		Draw.text_c(self, Style.display, _p(at), spaced, roundi(2.6 * k), col, maxi(2, roundi(0.5 * k)), Color(LAND, 0.9))
	for nm: Array in Geo.NAMES:
		var at: Vector2 = nm[1]
		var fs: float = nm[2]
		var col := Color(Style.PAPER_HI, 0.9) if str(nm[3]) == "sea" else Color(SEA_D.darkened(0.35), 0.9)
		Draw.text_c(self, Style.semi, _p(at), str(nm[0]), roundi(fs * k), col)

## one building per level: village = easy / mid, castle = hard; red roofs = won (ours), blue = the Empire's, faded
## = not open. Round level medallion at its lower left, 3 floating stars above (gold = earned, dark = not yet; none
## while not open). Next level = pulsing gold ring, selected = gold glow + bigger
func _draw_marks(k: float, ink: Color) -> void:
	var px := Baked.screen_scale(self)
	var order: Array = range(levels.size())
	order.sort_custom(
		func(a: int, b: int) -> bool:
			return pos_of(a).y < pos_of(b).y,
	)
	var unseen := _unseen_ids()
	for i: int in order:
		var p := pos_of(i)
		var def: Dictionary = levels[i]
		if p == Vector2.INF or unseen.has(str(def.id)):
			continue
		var done := Store.is_done(str(def.id))
		var locked := _locked(i)
		var hard := LevelSelect.tier_of(def) == "hard"
		var c := _p(p)
		var u := k * (1.12 if i == sel else 1.0)
		if i == sel:
			Draw.glow(self, c + Vector2(0, -1.5 * k), 6.0 * k, Color(Style.LEAF, 0.75))
		if i == next:
			var ph := fmod(_t, 1.6) / 1.6
			Draw.ellipse_line(self, c, 3.8 * k * (1.0 + 0.5 * ph), 1.6 * k * (1.0 + 0.5 * ph), Color(Style.LEAF, 1.0 - ph), maxf(2.0, 0.4 * k))
		var s := (FORT if hard else VILLAGE) * u
		var art := "%s_%s" % ["castle" if hard else "village", "p" if done else "e"]
		var tex := _art(art, s * px)
		if tex != null: # art ground line ~0.72 of its box: the building stands on the spot
			draw_texture_rect(tex, Rect2(c + Vector2(-s / 2.0, -s * 0.72), Vector2(s, s)), false, Color(1, 1, 1, 0.55) if locked else Color.WHITE)
		_medal(c + Vector2(-0.3 * s, -0.02 * s), u, i, done, locked, ink)
		if not locked:
			var top := c.y - s * (0.69 if hard else 0.36) # roof line of the art
			_stars(Vector2(c.x, top - 1.7 * u), u, Store.stars_of(str(def.id)) if done else 0, ink)

## round level medallion: white sticker edge, ink ring, 10 alternating segments, plate with the 2-digit number
func _medal(c: Vector2, u: float, i: int, done: bool, locked: bool, ink: Color) -> void:
	var r := 1.8 * u
	var seg_a := Style.CRIMSON if done else (Style.FADED if locked else Style.ROYAL)
	var seg_b := Style.LEAF if not locked else Style.PAPER_2
	var plate := Color("#f39a2b") if done else (Style.PAPER_2 if locked else Color("#4f74c9"))
	draw_circle(c + Vector2(0.15, 0.25) * u, r + 0.35 * u, Color(ink, 0.5)) # soft drop
	draw_circle(c, r + 0.32 * u, Color.WHITE)
	draw_circle(c, r + 0.1 * u, ink)
	for j in 10:
		var a0 := j * TAU / 10.0 - PI / 2.0
		draw_arc(c, r * 0.86, a0, a0 + TAU / 10.0, 6, seg_a if j % 2 == 0 else seg_b, r * 0.28, true)
	draw_circle(c, r * 0.72, ink)
	draw_circle(c, r * 0.66, plate)
	var txt := Style.FADED.darkened(0.3) if locked else Style.PAPER_HI
	Draw.text_c(self, Style.display, c + Vector2(0, 0.05 * u), "%02d" % (i + 1), roundi(1.25 * u), txt, maxi(2, roundi(0.28 * u)), ink)

## 3 stars in a low arc (middle one higher, bigger): gold with a shine when earned, dark when not; white sticker edge
func _stars(c: Vector2, u: float, got: int, ink: Color) -> void:
	for j in 3:
		var at := c + Vector2((j - 1) * 2.3, 0.0 if j == 1 else 0.65) * u
		var r := (1.3 if j == 1 else 1.08) * u
		Draw.star(self, at + Vector2(0.12, 0.2) * u, r * 1.28, Color(ink, 0.45)) # drop
		Draw.star(self, at, r * 1.28, Color.WHITE)
		var on := j < got
		Draw.star(self, at, r, STAR_ON if on else STAR_OFF, ink, maxf(1.0, 0.12 * u))
		if on:
			Draw.star(self, at + Vector2(-0.12, -0.15) * r, r * 0.45, Color(STAR_HI, 0.85))

## map frame: ink edge, inner hairline, gold corner diamonds
func _draw_frame(land: Rect2, k: float, ink: Color) -> void:
	draw_rect(land, ink, false, maxf(2.0, 0.45 * k))
	var inner := land.grow(-1.1 * k)
	draw_rect(inner, Color(ink, 0.55), false, maxf(1.0, 0.15 * k))
	for cn: Vector2 in [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]:
		var d := 0.9 * k
		var dia := PackedVector2Array([cn + Vector2(0, -d), cn + Vector2(d, 0), cn + Vector2(0, d), cn + Vector2(-d, 0)])
		draw_colored_polygon(dia, Style.LEAF)
		dia.append(dia[0])
		draw_polyline(dia, ink, maxf(1.0, 0.15 * k), true)
