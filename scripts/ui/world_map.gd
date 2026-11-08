class_name WorldMap
extends Control
## "Thử thách" as a kingdom map (geography: content/world_map.gd; premise "Ngọn Lửa Lâu Đài"). One node per level on
## the march route; won = our land (crimson, flame on the node), not open yet = still the Empire's (blue haze).
## Drag pans (never below K_MIN px per map unit: phones get a bigger map to scroll), tap a node = its card (title,
## setting line, short goal, best stars), "Xuất quân" = level_picked. Starts on the next level (first_unwon) or `focus`.

signal level_picked(id: String)

const Geo := preload("res://content/world_map.gd")
const K_MIN := 6.0 # px per map unit at least: nodes ~34 px across, labels readable
const NODE_R := 2.8
const HIT_R := 4.4
const DRAG_PX := 8.0
const TOP_PAD := 64.0 # header (back button / counter) over the map
const LAND := Color("#ead7a6")
const SEA := Color("#8fb8bf")
const WATER := Color("#5f97a8")

var levels: Array = []
var open_index := 0
var sel := -1 # selected level index (card)
var next := -1 # first level not won (gold, pulsing)
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

func setup(lv: Array, open: int, focus_id := "") -> void:
	levels = lv
	open_index = open
	next = LevelSelect.first_unwon(lv, open)
	var focus := mini(next, lv.size() - 1)
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
	_card = PanelContainer.new()
	var box := Style.paper(14.0)
	box.shadow = Vector2(4, 4)
	_card.add_theme_stylebox_override("panel", box)
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_card)
	resized.connect(_fit)
	_card_width()
	select(focus)
	_fit.call_deferred()

## node index i -> map position (Vector2.INF = not on the map)
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
	if size.y > size.x: # portrait: fill the height (bigger nodes for thumbs), pan sideways
		_k = maxf(_k, (size.y - TOP_PAD - 24.0) / Geo.VB.y)
	_card_width()
	if sel >= 0:
		_center_on.call_deferred(sel) # after the card's height settled at its width

## card: fixed width (autowrapped labels need it before layout), bottom centre above the safe inset
func _card_width() -> void:
	var vw := size.x if size.x >= 1.0 else get_viewport_rect().size.x
	var w := minf(440.0, vw - 32.0)
	_card.custom_minimum_size.x = w
	_card.offset_left = -w / 2.0
	_card.offset_right = w / 2.0
	_card.offset_bottom = -16.0 - Style.safe_insets(self).w
	_card.offset_top = _card.offset_bottom
	_card.reset_size()

## keep the map on screen: room for the header above and the card below; smaller than the screen = centred
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
	_off = _clamp(Vector2(size.x * 0.5, TOP_PAD + (size.y - TOP_PAD - _card.size.y) * 0.45) - p * _k)
	queue_redraw()

## tap a node: its card. Off-screen (under the card / header) -> pan to it
func select(i: int) -> void:
	if i < 0 or i >= levels.size():
		return
	sel = i
	_build_card()
	_reveal.call_deferred(i)
	queue_redraw()

## node under the card / header / off screen -> pan to it (deferred: the new card's height is known by then)
func _reveal(i: int) -> void:
	var c := _p(pos_of(i))
	if c.y > size.y - _card.size.y - 40.0 or c.y < TOP_PAD + 20.0 or c.x < 20.0 or c.x > size.x - 20.0:
		_center_on(i)

## "Xuất quân": start the selected level (open ones only)
func go() -> void:
	if sel < 0 or _locked(sel):
		return
	var def: Dictionary = levels[sel]
	level_picked.emit(str(def.id))

func _build_card() -> void:
	for c in _card.get_children():
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
	_card.reset_size()

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

func _xf(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(_p(q))
	return out

func _draw() -> void:
	Draw.xf = Transform2D.IDENTITY
	var k := _k
	var ink := Style.INK_D
	var ms := _t * 1000.0
	# parchment land + hard shadow + ink frame
	var land := Rect2(_p(Vector2.ZERO), Geo.VB * k)
	draw_rect(Rect2(land.position + Vector2(5, 6), land.size), Color(ink, 0.8))
	draw_rect(land, LAND)
	# sea east of the coast, wave ticks
	var sea := _xf(_coast)
	sea.append(_p(Geo.VB))
	sea.append(_p(Vector2(Geo.VB.x, 0)))
	draw_colored_polygon(sea, SEA)
	draw_polyline(_xf(_coast), ink, maxf(1.5, 0.35 * k), true)
	for j in 9:
		var wv := _p(Vector2(128.0 + float(j % 3) * 4.0, 8.0 + j * 11.0))
		var sh := sin(_t * 1.2 + j) * 0.6 * k
		draw_arc(wv + Vector2(sh, 0), 1.2 * k, PI * 1.15, PI * 1.85, 8, Color(1, 1, 1, 0.5), maxf(1.0, 0.25 * k), true)
	# territory: still the Empire's (blue haze) / retaken (crimson, breathing)
	var breath := 0.85 + 0.15 * cos(_t * TAU / 3.0)
	for i in levels.size():
		var p := pos_of(i)
		if p != Vector2.INF and _locked(i):
			Draw.glow(self, _p(p), 10.0 * k, Color(Style.ROYAL, 0.3))
	for i in levels.size():
		var p := pos_of(i)
		var def: Dictionary = levels[i]
		if p != Vector2.INF and Store.is_done(str(def.id)):
			Draw.glow(self, _p(p), 9.5 * k, Color(Style.CRIMSON, 0.3 * breath))
	# water
	for l: Array in Geo.LAKES:
		var lc: Vector2 = l[0]
		var rx: float = l[1]
		var ry: float = l[2]
		Draw.ellipse(self, _p(lc), rx * k, ry * k, WATER)
		Draw.ellipse_line(self, _p(lc), rx * k, ry * k, ink, maxf(1.2, 0.3 * k))
	for i in _rivers.size():
		var rw: float = Geo.RIVERS[i][0]
		var pts := _xf(_rivers[i])
		draw_polyline(pts, ink, rw * k + maxf(2.0, 0.5 * k), true)
		draw_polyline(pts, WATER, rw * k, true)
	for r: Array in Geo.REEDS:
		var rx0: float = r[0]
		var ry0: float = r[1]
		var rc := _p(Vector2(rx0, ry0))
		for j in 3:
			var rx := rc + Vector2((j - 1) * 0.9 * k, 0)
			draw_line(rx, rx + Vector2(0.2 * k, -1.6 * k), Color(ink, 0.6), maxf(1.0, 0.2 * k), true)
	# relief: mountains (ink triangle, snow cap), forest clumps
	for pk: Array in Geo.PEAKS:
		var px: float = pk[0]
		var py: float = pk[1]
		var psz: float = pk[2]
		var b := _p(Vector2(px, py))
		var s := psz * k * 0.5
		var tri := PackedVector2Array([b + Vector2(-s, 0), b + Vector2(0, -s * 1.3), b + Vector2(s, 0)])
		draw_colored_polygon(tri, Color("#b39a74"))
		draw_colored_polygon(
			PackedVector2Array([b + Vector2(-s * 0.32, -s * 0.88), b + Vector2(0, -s * 1.3), b + Vector2(s * 0.32, -s * 0.88)]),
			Color("#f6eedb"),
		)
		tri.append(tri[0])
		draw_polyline(tri, ink, maxf(1.2, 0.3 * k), true)
	for w: Array in Geo.WOODS:
		var wx: float = w[0]
		var wy: float = w[1]
		var c := _p(Vector2(wx, wy))
		for j in 3:
			var tc := c + Vector2((j - 1) * 1.5 * k, (j % 2) * 0.8 * k)
			draw_circle(tc, 1.1 * k, Color("#6f8f4a"))
			draw_arc(tc, 1.1 * k, 0, TAU, 16, ink, maxf(1.0, 0.25 * k), true)
	# region names: faded ink, crimson once every level in it is won
	for rg: Dictionary in Geo.REGIONS:
		var all_done := true
		for id: String in rg.ids:
			all_done = all_done and Store.is_done(id)
		var col := Color(Style.CRIMSON_D, 0.85) if all_done else Color(ink, 0.4)
		var at: Vector2 = rg.at
		Draw.text_c(self, Style.display, _p(at), str(rg.name).to_upper(), roundi(3.0 * k), col)
	_draw_route(k, ink)
	_draw_nodes(k, ink, ms)
	draw_rect(land, ink, false, maxf(2.0, 0.4 * k))

## march route: dashed all the way, solid crimson up to the next level after the furthest win
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
		var n := maxi(1, int(a.distance_to(b) / (1.6 * k)))
		for q in n:
			if q % 2 == 0:
				draw_line(a.lerp(b, float(q) / n), a.lerp(b, float(q + 1) / n), Color(ink, 0.35), maxf(1.0, 0.35 * k), true)
	if last_done >= 0:
		draw_polyline(route.slice(0, mini(route.size(), last_done + 2)), Color(Style.CRIMSON, 0.9), maxf(2.0, 0.55 * k), true)

func _draw_nodes(k: float, ink: Color, ms: float) -> void:
	for i in levels.size():
		var p := pos_of(i)
		if p == Vector2.INF:
			continue
		var def: Dictionary = levels[i]
		var done := Store.is_done(str(def.id))
		var locked := _locked(i)
		var c := _p(p)
		var r := NODE_R * k * (1.15 if i == sel else 1.0)
		if i == next:
			var ph := fmod(_t, 1.6) / 1.6
			draw_arc(c, r * (1.0 + 0.9 * ph), 0, TAU, 40, Color(Style.LEAF, 0.9 * (1.0 - ph)), maxf(2.0, 0.45 * k), true)
		var fill := Style.PAPER_HI
		if done:
			fill = Style.CRIMSON
		elif i == next:
			fill = Style.LEAF
		elif locked:
			fill = Style.PAPER_2
		draw_circle(c + Vector2(0.35, 0.45) * k, r, Color(ink, 0.85)) # hard shadow
		draw_circle(c, r, fill)
		draw_arc(c, r, 0, TAU, 32, ink if not locked else Style.FADED, maxf(1.5, 0.4 * k), true)
		if i == sel:
			draw_arc(c, r + 0.7 * k, 0, TAU, 40, Style.CRIMSON_D, maxf(2.0, 0.4 * k), true)
		var txt := Style.PAPER_HI if done else (Style.FADED if locked else ink)
		Draw.text_c(self, Style.display, c + Vector2(0, 0.1 * k), str(i + 1), roundi(2.4 * k), txt)
		if done: # relit flame + best stars under the node
			Draw.flame(self, c + Vector2(0, -r * 0.85), r * 1.25, ms, float(i))
			var got := Store.stars_of(str(def.id))
			for j in Stars.MAX:
				Draw.star(self, c + Vector2((j - 1) * 1.6 * k, r + 0.9 * k), 0.75 * k, Style.LEAF if j < got else Style.PAPER_2, ink, 1.0)
