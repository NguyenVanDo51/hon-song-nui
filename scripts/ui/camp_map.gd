class_name CampMap
extends Control
## schematic chapter map (THEME.chapter, 100 x 70 viewbox): rivers from SVG path strings, lakes, labels,
## march route, one node per mission at m.pos; retaken regions glow in faction colour. Port of drawCampaignMap.

signal picked(id: String)

const VB := Vector2(100, 70)
var missions: Array = [] # campaign defs that have pos
var open_index := 0
var rivers: Array = [] # [{w, pts: PackedVector2Array (viewbox units)}]
var hover := ""
var t := 0.0

func setup(open: int) -> void:
	open_index = open
	missions = Content.missions_of(Content.active_chapter).filter(
		func(m: Dictionary) -> bool:
			return m.has("pos"),
	)
	rivers.clear()
	var ch: Dictionary = Content.theme().chapter
	for r: Dictionary in ch.get("rivers", []):
		var rw: float = r.w
		var rd: String = r.d
		rivers.append({ "w": rw, "pts": parse_path(rd) })
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	var vh := get_viewport_rect().size.y if is_inside_tree() else 900.0
	custom_minimum_size.y = minf(size.x * 0.7, vh * 0.66) if size.x > 0 else 400.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_fit.call_deferred()
	elif what == NOTIFICATION_MOUSE_EXIT:
		hover = ""

## SVG path with absolute M / C / S commands -> polyline
static func parse_path(d: String) -> PackedVector2Array:
	var toks := PackedStringArray()
	var rx := RegEx.new()
	rx.compile("[MCSmcs]|-?[0-9]*\\.?[0-9]+")
	for m: RegExMatch in rx.search_all(d):
		toks.append(m.get_string())
	var out := PackedVector2Array()
	var cur := Vector2.ZERO
	var last_c2 := Vector2.ZERO
	var cmd := ""
	var at := [0] # cursor in an array: _num advances it by reference
	var guard := 0
	while at[0] < toks.size() and guard < 10000:
		guard += 1
		if toks[at[0]] in ["M", "C", "S", "m", "c", "s"]:
			var tok: String = toks[at[0]]
			cmd = tok.to_upper()
			at[0] += 1
		if cmd == "M":
			cur = Vector2(_num(toks, at), _num(toks, at))
			last_c2 = cur
			out.append(cur)
		elif cmd == "C":
			var c1 := Vector2(_num(toks, at), _num(toks, at))
			var c2 := Vector2(_num(toks, at), _num(toks, at))
			var p := Vector2(_num(toks, at), _num(toks, at))
			var seg := Draw.cubic(cur, c1, c2, p, 16)
			seg.remove_at(0)
			out.append_array(seg)
			last_c2 = c2
			cur = p
		elif cmd == "S":
			var c1 := cur * 2 - last_c2
			var c2 := Vector2(_num(toks, at), _num(toks, at))
			var p := Vector2(_num(toks, at), _num(toks, at))
			var seg := Draw.cubic(cur, c1, c2, p, 16)
			seg.remove_at(0)
			out.append_array(seg)
			last_c2 = c2
			cur = p
		else:
			at[0] += 1
	return out

static func _num(toks: PackedStringArray, at: Array) -> float:
	at[0] += 1
	return toks[at[0] - 1].to_float()

func _scale() -> float:
	return minf(size.x / VB.x, size.y / VB.y)

static func _pos(m: Dictionary) -> Vector2:
	var p: Array = m.pos
	var x: float = p[0]
	var y: float = p[1]
	return Vector2(x, y)

func _origin() -> Vector2:
	return (size - VB * _scale()) / 2.0

func _p(v: Vector2) -> Vector2:
	return _origin() + v * _scale()

func _process(dt: float) -> void:
	t += dt
	if is_visible_in_tree():
		queue_redraw()

## mission node under pos; locked ones count only when any_state (hover shows their name, clicks ignore them)
func _node_at(pos: Vector2, any_state := false) -> String:
	for i in missions.size():
		var m: Dictionary = missions[i]
		if not any_state and _locked(m):
			continue
		if pos.distance_to(_p(_pos(m))) <= 3.6 * _scale():
			return m.id
	return ""

func _locked(m: Dictionary) -> bool:
	var mid: String = m.id
	return Content.mission_index(mid) > open_index and not Store.is_done(mid)

## info box for the hovered mission (or the next one to play): number, status, title, place, what's new.
## Sits in the top corner away from that node so it never covers it.
func _draw_info(_s: float) -> void:
	var id := hover
	if id == "":
		for m: Dictionary in missions:
			var mid: String = m.id
			if Content.mission_index(mid) == open_index:
				id = mid
	if id == "":
		return
	var k := -1
	for j in missions.size():
		if missions[j].id == id:
			k = j
	if k < 0:
		return
	var m: Dictionary = missions[k]
	var done := Store.is_done(id)
	var locked := _locked(m)
	var status := "ĐÃ THẮNG" if done else ("CHƯA MỞ" if locked else "TRẬN KẾ TIẾP")
	var status_col := Style.GOOD if done else (Style.MUTED if locked else Style.GOLD)
	var new_units: Array = m.get("newUnits", [])
	var nu: Array = new_units.filter(
		func(x: String) -> bool:
			return x != "hero",
	)
	var note := "Lính mới" if nu.size() else ("Tướng mới" if new_units.has("hero") else ("Trận cuối chương" if k == missions.size() - 1 else ""))
	var hint := "Thắng màn trước để mở" if locked else ("Bấm để chơi lại" if done else "Bấm để vào trận")
	if note != "":
		hint = note + " · " + hint
	var head := "MÀN %d / %d" % [k + 1, missions.size()]
	var title: String = m.title
	var place: String = m.get("place", "")
	var rows := [
		[Style.bold, head, 12, Style.MUTED],
		[Style.display, title, 24, Style.GOLD],
		[Style.body, place, 14, Style.INK],
		[Style.semi, hint, 13, Style.MUTED],
	]
	var w := Style.bold.get_string_size(head + "    " + status, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	for r: Array in rows:
		var rf: Font = r[0]
		var rtext: String = r[1]
		var rsize: int = r[2]
		w = maxf(w, rf.get_string_size(rtext, HORIZONTAL_ALIGNMENT_LEFT, -1, rsize).x)
	w = minf(w + 32, size.x * 0.45)
	var h := 16.0 + 18 + 32 + 22 + 20 + 12
	var node_x := _p(_pos(m)).x
	var x := size.x - w - 14 if node_x < size.x / 2 else 14.0
	var box := Rect2(x, 14, w, h)
	draw_style_box(Style.box(Color(0.09, 0.06, 0.035, 0.88), Color(status_col, 0.55), 10, 0), box)
	var y := box.position.y + 16
	Draw.text_a(self, Style.bold, Vector2(x + 16, y), head, 12, Style.MUTED, 0.0, true)
	Draw.text_a(self, Style.bold, Vector2(x + w - 16, y), status, 12, status_col, 1.0, true)
	y += 18
	Draw.text_a(self, Style.display, Vector2(x + 16, y), title, 24, Style.GOLD if not locked else Style.MUTED, 0.0, true)
	y += 32
	Draw.text_a(self, Style.body, Vector2(x + 16, y), place, 14, Style.INK, 0.0, true)
	y += 22
	Draw.text_a(self, Style.semi, Vector2(x + 16, y), hint, 13, Style.MUTED, 0.0, true)

func _gui_input(ev: InputEvent) -> void:
	var mm := ev as InputEventMouseMotion
	var mb := ev as InputEventMouseButton
	if mm != null:
		var h := _node_at(mm.position, true)
		if h != hover:
			hover = h
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _node_at(mm.position) != "" else Control.CURSOR_ARROW
	elif mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var id := _node_at(mb.position)
		if id != "":
			picked.emit(id)
			accept_event()

func _dashed(pts: PackedVector2Array, dash: float, gap: float, offset: float, col: Color, width: float) -> void:
	var period := dash + gap
	var ph := fposmod(offset, period)
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var L := a.distance_to(b)
		var s := 0.0
		var guard := 0
		while s < L - 1e-4 and guard < 2000: # bounded: a sub-ulp step must never spin (see Board._dashed)
			guard += 1
			var on := ph < dash
			var step := maxf(1e-3, minf((dash - ph) if on else (period - ph), L - s))
			if on:
				draw_line(a.lerp(b, s / L), a.lerp(b, (s + step) / L), col, width, true)
			s += step
			ph += step
			if ph >= period - 1e-6:
				ph -= period

func _xf(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in pts:
		out.append(_p(v))
	return out

func _draw() -> void:
	Draw.xf = Transform2D.IDENTITY
	var ch: Dictionary = Content.theme().chapter
	var s := _scale()
	var fp: Dictionary = Content.theme().factions.p
	var fe: Dictionary = Content.theme().factions.e
	# parchment-dark backdrop
	draw_rect(Rect2(Vector2.ZERO, size), Color("#1e140b"))
	var bg_stops := [[0.0, Color("#3b2a17")], [0.6, Color("#2a1d10")], [1.0, Color("#1e140b")]]
	Draw.radial(self, Vector2(size.x * 0.4, size.y * 0.3), size.x * 0.75, bg_stops, 40, Vector2(1.0, 0.75))
	# regions: still under the foe / retaken (breathing)
	var fe_body2: String = fe.body2
	var fp_glow: String = fp.glow
	for m: Dictionary in missions:
		var mid: String = m.id
		if not Store.is_done(mid):
			Draw.glow(self, _p(_pos(m)), 9 * s, Color(fe_body2, 0.5))
	var breath := 0.8 + 0.2 * cos(t * TAU / 3.0)
	for m: Dictionary in missions:
		var mid: String = m.id
		if Store.is_done(mid):
			Draw.glow(self, _p(_pos(m)), 10 * s, Color(fp_glow, 0.55 * breath))
	# rivers + flowing highlight
	for r: Dictionary in rivers:
		var rpts: PackedVector2Array = r.pts
		var pts := _xf(rpts)
		var w: float = r.w * s
		draw_polyline(pts, Color("#2d5f7e"), w, true)
		draw_circle(pts[0], w / 2, Color("#2d5f7e"), true, -1.0, true)
		draw_circle(pts[pts.size() - 1], w / 2, Color("#2d5f7e"), true, -1.0, true)
		_dashed(pts, 1.4 * s, 2.4 * s, -fmod(t / 6.0, 1.0) * 19 * s, Color("#6fa8c8", 0.45), w * 0.35)
	var lakes: Array = ch.get("lakes", [])
	for l: Dictionary in lakes:
		var cx: float = l.cx
		var cy: float = l.cy
		var rx: float = l.rx
		var ry: float = l.ry
		var c := _p(Vector2(cx, cy))
		Draw.ellipse(self, c, rx * s, ry * s, Color("#2d5f7e"))
		Draw.ellipse_line(self, c, rx * s, ry * s, Color("#6fa8c8", 0.5), 0.3 * s)
	var labels: Array = ch.get("labels", [])
	for l: Dictionary in labels:
		var lsize: float = l.size
		var lx: float = l.x
		var ly: float = l.y
		var ltext: String = l.text
		var fs := roundi(lsize * s)
		if l.get("river", false):
			Draw.text_a(self, Style.body, _p(Vector2(lx, ly)), ltext, fs, Color("#9cc7de", 0.55), 0.5)
		else:
			Draw.text_a(self, Style.display, _p(Vector2(lx, ly)), ltext, fs, Color("#e8d6b0", 0.28), 0.5)
	# march route: dashed all the way, solid up to the next mission after the last win
	var route := PackedVector2Array()
	for m: Dictionary in missions:
		route.append(_p(_pos(m)))
	_dashed(route, 1.0 * s, 1.2 * s, 0.0, Color("#e8d6b0", 0.25), 0.5 * s)
	var done_idx := 0
	for i in missions.size():
		var mid: String = missions[i].id
		if Store.is_done(mid):
			done_idx = i + 1
	if done_idx > 0:
		draw_polyline(route.slice(0, mini(missions.size(), done_idx + 1)), Color(Style.CINNABAR_HI, 0.9), 0.8 * s, true)
	# nodes
	for m: Dictionary in missions:
		var mid: String = m.id
		var i := Content.mission_index(mid)
		var done := Store.is_done(mid)
		var cur := i == open_index
		var locked := i > open_index and not done
		var c := _p(_pos(m))
		var al := 0.55 if locked else 1.0
		if cur:
			var k := fmod(t, 1.6) / 1.6
			draw_arc(c, 3.2 * s * (1 + 1.6 * k), 0, TAU, 40, Color(Style.GOLD, 0.9 * (1 - k)), 0.5 * s, true)
		var r := (3.3 if hover == m.id else 2.6) * s
		var fill := Color("#34406a")
		var stroke := Color("#d8c27a")
		if done:
			fill = Style.CINNABAR
			stroke = Style.GOLD
		if cur:
			fill = Style.GOLD
			stroke = Color("#fff6d8")
		draw_circle(c, r, Color(fill, al), true, -1.0, true)
		draw_arc(c, r, 0, TAU, 32, Color(stroke, al), 0.45 * s, true)
		Draw.text_c(self, Style.xbold, c, str(missions.find(m) + 1), roundi(2.6 * s), Color(Color("#3a1a10") if cur else Style.INK, al))
		var place: String = m.get("region", m.get("place", ""))
		Draw.text_a(
			self,
			Style.bold,
			c + Vector2(0, 5.6 * s),
			place,
			roundi(2.5 * s),
			Color(Style.INK, al),
			0.5,
			false,
			int(0.7 * s),
			Color("#1a0f08"),
		)
	_draw_info(s)
	# frame
	draw_style_box(Style.box(Color.TRANSPARENT, Style.BRONZE_2, 12, 0), Rect2(Vector2.ZERO, size))
