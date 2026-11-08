class_name WorldMap
extends Control
## "Thử thách" as a kingdom map (geography: content/world_map.gd; premise "Ngọn Lửa Lâu Đài"). One castle per level
## on the march route: won = ours (red castle + flame, land glows red), not won = the Empire's (blue castle), not open
## yet = Empire haze, whole region not open = clouds. Scenery = the board's chibi terrain art without its grass square.
## Drag pans (never below K_MIN px per map unit; portrait fills the height). Nothing selected at first (the next level
## pulses); tap a castle = its card (title, setting line, short goal, best stars, "Xuất quân" = level_picked); tap
## empty land = card closes. Opens centred on the next level, or on `focus_id` (back from a level).

signal level_picked(id: String)

const Geo := preload("res://content/world_map.gd")
const ART := "res://assets/terrain/chibi/%s.svg"
const K_MIN := 7.5 # px per map unit at least: castles ~50 px wide on a phone, numbers readable
const HIT_R := 4.4
const CASTLE := 7.0 # castle art box, map units
const DRAG_PX := 8.0
const TOP_PAD := 64.0 # header (back button / counter) over the map
const LAND := Color("#ead6a4")
const STAIN := Color("#c9a66a")
const SEA := Color("#86b3bd")
const SEA_D := Color("#5f93a3")
const WATER := Color("#5f97a8")

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
var _rivers: Array[PackedVector2Array] = []
var _coast := PackedVector2Array()
var _decor := [] # [y, art name, centre, size] back to front

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
	_decor.clear()
	for spec: Array in [[Geo.PEAKS, "mountain"], [Geo.WOODS, "forest"], [Geo.HILLS, "hill"], [Geo.HAMLETS, "village_n"]]:
		var items: Array = spec[0]
		var kind: String = spec[1]
		for it: Array in items:
			var x: float = it[0]
			var y: float = it[1]
			var s: float = it[2]
			var nm := kind if kind == "village_n" else "%s_%s" % [kind, "a" if Board.hash01(int(x * 10), int(y * 10), 5) < 0.5 else "b"]
			_decor.append([y, nm, Vector2(x, y), s])
	_decor.sort_custom(
		func(a: Array, b: Array) -> bool:
			return a[0] < b[0],
	)
	_card = PanelContainer.new()
	var box := Style.paper(14.0)
	box.shadow = Vector2(4, 4)
	_card.add_theme_stylebox_override("panel", box)
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.visible = false
	add_child(_card)
	resized.connect(_fit)
	_card_width()
	_fit.call_deferred()

## level index i -> map position (Vector2.INF = not on the map)
func pos_of(i: int) -> Vector2:
	var def: Dictionary = levels[i]
	return Geo.POS.get(str(def.id), Vector2.INF)

func _p(v: Vector2) -> Vector2:
	return _off + v * _k

func _locked(i: int) -> bool:
	var def: Dictionary = levels[i]
	return i > open_index and not Store.is_done(str(def.id))

func _fit() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	_k = maxf(minf(size.x / Geo.VB.x, size.y / Geo.VB.y), K_MIN)
	if size.y > size.x: # portrait: fill the height (bigger castles for thumbs), pan sideways
		_k = maxf(_k, (size.y - TOP_PAD - 24.0) / Geo.VB.y)
	_card_width()
	_center_on(sel if sel >= 0 else focus)
	if sel >= 0:
		_reveal(sel)

## card: fixed width (autowrapped labels need it before layout), bottom centre above the safe inset
func _card_width() -> void:
	var vw := size.x if size.x >= 1.0 else get_viewport_rect().size.x
	var w := minf(440.0, vw - 32.0)
	_card.custom_minimum_size.x = w
	_card.offset_left = -w / 2.0
	_card.offset_right = w / 2.0
	_place_card()

## bottom edge above the safe inset, top = bottom - the card's real (minimum) height: never left taller / lower
func _place_card() -> void:
	_card.offset_bottom = -16.0 - Style.safe_insets(self).w
	_card.offset_top = _card.offset_bottom - _card.get_combined_minimum_size().y

## keep the map on screen with room for the header above (and the open card below); smaller than the screen = centred
func _clamp(o: Vector2) -> Vector2:
	var m := Geo.VB * _k
	var bottom := _card.size.y + 32.0 if _card.visible else 16.0
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

## tap a castle: its card. The map only moves if the card / header / an edge would hide that castle
func select(i: int) -> void:
	if i < 0 or i >= levels.size():
		return
	sel = i
	_card.visible = true # build while shown: autowrapped labels measured hidden report one word per line (card 1100+ px)
	_build_card()
	_reveal(i)
	queue_redraw()

## close the card (tap on empty land)
func deselect() -> void:
	sel = -1
	_card.visible = false
	queue_redraw()

## smallest pan that shows castle i above the card (the card's real height is known one frame after it was built)
func _reveal(i: int) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if sel != i or not is_inside_tree():
		return
	_place_card() # labels wrapped at the card width by now: real height
	var c := _p(pos_of(i))
	var d := Vector2.ZERO
	var low := size.y - _card.size.y - 28.0 - 3.0 * _k # castle badge + stars hang below the spot
	var high := TOP_PAD + 5.0 * _k # castle art rises above the spot
	if c.y > low:
		d.y = low - c.y
	elif c.y < high:
		d.y = high - c.y
	var margin := 4.0 * _k
	if c.x < margin:
		d.x = margin - c.x
	elif c.x > size.x - margin:
		d.x = size.x - margin - c.x
	if d != Vector2.ZERO:
		_off = _clamp(_off + d)
	queue_redraw()

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
		var d := at.distance_to(_p(p + Vector2(0, -1.0))) # castle body sits a little above its spot
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
	_draw_water(k, ink)
	_draw_route(k, ink)
	for d: Array in _decor:
		var at: Vector2 = d[2]
		var s: float = d[3] * k
		var tex := _art(str(d[1]), s * px)
		if tex != null:
			draw_texture_rect(tex, Rect2(_p(at) - Vector2(s, s) / 2.0, Vector2(s, s)), false)
	_draw_names(k, ink)
	_draw_castles(k, ink, px)
	_draw_fog(k)
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

## march route: dashed all the way, solid red up to the level after the furthest win
func _draw_route(k: float, ink: Color) -> void:
	var route := PackedVector2Array()
	var last_done := -1
	for i in levels.size():
		var p := pos_of(i)
		if p == Vector2.INF:
			continue
		route.append(_p(p))
		var def: Dictionary = levels[i]
		if Store.is_done(str(def.id)):
			last_done = route.size() - 1
	for j in route.size() - 1:
		var a := route[j]
		var b := route[j + 1]
		var n := maxi(1, int(a.distance_to(b) / (1.3 * k)))
		for q in n:
			if q % 2 == 0:
				draw_line(a.lerp(b, float(q) / n), a.lerp(b, float(q + 1) / n), Color(ink, 0.45), maxf(1.2, 0.32 * k), true)
	if last_done >= 0:
		draw_polyline(route.slice(0, mini(route.size(), last_done + 2)), Color(Style.CRIMSON, 0.9), maxf(2.0, 0.5 * k), true)

## clouds over every region not opened at all (still unknown land)
func _draw_fog(k: float) -> void:
	for rg: Dictionary in Geo.REGIONS:
		var unseen := true
		for id: String in rg.ids:
			var i := Content.level_index(id)
			unseen = unseen and i >= 0 and _locked(i)
		if not unseen:
			continue
		for id: String in rg.ids:
			var p: Vector2 = Geo.POS.get(id, Vector2.INF)
			if p == Vector2.INF:
				continue
			for j in 4:
				var h := Board.hash01(int(p.x), int(p.y), j)
				var dx := (h - 0.5) * 9.0 + sin(_t * 0.25 + j + p.x) * 0.8
				var dy := (Board.hash01(int(p.y), int(p.x), j) - 0.5) * 6.0
				var c := _p(p + Vector2(dx, dy))
				var r := (3.0 + h * 2.2) * k
				draw_circle(c + Vector2(0, 0.6 * k), r, Color(Style.ROYAL_D, 0.1))
				draw_circle(c, r, Color(0.96, 0.94, 0.9, 0.5))
				draw_circle(c + Vector2(-0.3, -0.4) * r, r * 0.55, Color(1, 1, 1, 0.25))

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

## one castle per level: ours (red, flame) when won, else the Empire's (blue); number badge + best stars under it
func _draw_castles(k: float, ink: Color, px: float) -> void:
	var s := CASTLE * k
	var order: Array = range(levels.size())
	order.sort_custom(
		func(a: int, b: int) -> bool:
			return pos_of(a).y < pos_of(b).y,
	)
	for i: int in order:
		var p := pos_of(i)
		if p == Vector2.INF:
			continue
		var def: Dictionary = levels[i]
		var done := Store.is_done(str(def.id))
		var locked := _locked(i)
		var base := _p(p) + Vector2(0, 1.2 * k) # where the castle stands
		if i == sel:
			Draw.ellipse(self, base, 3.6 * k, 1.3 * k, Color(Style.LEAF, 0.85))
			Draw.ellipse_line(self, base, 3.6 * k, 1.3 * k, Style.CRIMSON_D, maxf(2.0, 0.3 * k))
		if i == next:
			var ph := fmod(_t, 1.6) / 1.6
			Draw.ellipse_line(self, base, 3.4 * k * (1.0 + 0.6 * ph), 1.2 * k * (1.0 + 0.6 * ph), Color(Style.LEAF, 1.0 - ph), maxf(2.0, 0.4 * k))
		var tex := _art("castle_p" if done else "castle_e", s * px, false)
		var r := Rect2(base - Vector2(s / 2.0, s * 0.75), Vector2(s, s)) # art ground line ~0.75 of its box
		if tex != null:
			draw_texture_rect(tex, r, false, Color(1, 1, 1, 0.6) if locked else Color.WHITE)
		if done:
			Draw.flame(self, r.position + BoardPaint.FIRE_AT * s, s * 0.32, _t * 1000.0, float(i))
		var bc := base + Vector2(0, 1.2 * k)
		var br := 1.45 * k
		var fill := Style.CRIMSON if done else (Style.LEAF if i == next else (Style.PAPER_2 if locked else Style.PAPER_HI))
		draw_circle(bc + Vector2(0.2, 0.3) * k, br, Color(ink, 0.85))
		draw_circle(bc, br, fill)
		draw_arc(bc, br, 0, TAU, 24, ink, maxf(1.2, 0.25 * k), true)
		Draw.text_c(self, Style.display, bc + Vector2(0, 0.08 * k), str(i + 1), roundi(1.7 * k), Style.PAPER_HI if done else ink)
		if done:
			var got := Store.stars_of(str(def.id))
			for j in Stars.MAX:
				Draw.star(self, bc + Vector2((j - 1) * 1.3 * k, br + 0.75 * k), 0.62 * k, Style.LEAF if j < got else Style.PAPER_2, ink, 1.0)

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
