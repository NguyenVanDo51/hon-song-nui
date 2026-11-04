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
	missions = Content.campaign().filter(func(m: Dictionary) -> bool: return m.has("pos"))
	rivers.clear()
	for r: Dictionary in Content.theme().chapter.get("rivers", []):
		rivers.append({ "w": float(r.w), "pts": parse_path(r.d) })
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	var vh := get_viewport_rect().size.y if is_inside_tree() else 900.0
	custom_minimum_size.y = minf(size.x * 0.7, vh * 0.62) if size.x > 0 else 400.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_fit.call_deferred()

## SVG path with absolute M / C / S commands -> polyline
static func parse_path(d: String) -> PackedVector2Array:
	var toks := []
	var rx := RegEx.new()
	rx.compile("[MCSmcs]|-?[0-9]*\\.?[0-9]+")
	for m in rx.search_all(d):
		toks.append(m.get_string())
	var out := PackedVector2Array()
	var cur := Vector2.ZERO
	var last_c2 := Vector2.ZERO
	var cmd := ""
	var at := [0] # lambdas capture by value: keep the cursor in an array
	var num := func() -> float:
		at[0] += 1
		return float(toks[at[0] - 1])
	while at[0] < toks.size():
		if toks[at[0]] in ["M", "C", "S", "m", "c", "s"]:
			cmd = toks[at[0]].to_upper()
			at[0] += 1
		if cmd == "M":
			cur = Vector2(num.call(), num.call())
			last_c2 = cur
			out.append(cur)
		elif cmd == "C":
			var c1 := Vector2(num.call(), num.call())
			var c2 := Vector2(num.call(), num.call())
			var p := Vector2(num.call(), num.call())
			var seg := Draw.cubic(cur, c1, c2, p, 16)
			seg.remove_at(0)
			out.append_array(seg)
			last_c2 = c2
			cur = p
		elif cmd == "S":
			var c1 := cur * 2 - last_c2
			var c2 := Vector2(num.call(), num.call())
			var p := Vector2(num.call(), num.call())
			var seg := Draw.cubic(cur, c1, c2, p, 16)
			seg.remove_at(0)
			out.append_array(seg)
			last_c2 = c2
			cur = p
		else:
			at[0] += 1
	return out

func _scale() -> float:
	return minf(size.x / VB.x, size.y / VB.y)

func _origin() -> Vector2:
	return (size - VB * _scale()) / 2.0

func _p(v: Vector2) -> Vector2:
	return _origin() + v * _scale()

func _process(dt: float) -> void:
	t += dt
	if is_visible_in_tree():
		queue_redraw()

func _node_at(pos: Vector2) -> String:
	for i in missions.size():
		var m: Dictionary = missions[i]
		var ci := Content.mission_index(m.id)
		if ci > open_index and not Store.is_done(m.id):
			continue
		if pos.distance_to(_p(Vector2(m.pos[0], m.pos[1]))) <= 3.6 * _scale():
			return m.id
	return ""

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h := _node_at(ev.position)
		if h != hover:
			hover = h
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h != "" else Control.CURSOR_ARROW
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var id := _node_at(ev.position)
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
		while s < L - 1e-4:
			var on := ph < dash
			var step := minf((dash - ph) if on else (period - ph), L - s)
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
	var ch: Dictionary = Content.theme().chapter
	var s := _scale()
	var fp: Dictionary = Content.theme().factions.p
	var fe: Dictionary = Content.theme().factions.e
	# parchment-dark backdrop
	draw_rect(Rect2(Vector2.ZERO, size), Color("#1e140b"))
	Draw.radial(self, Vector2(size.x * 0.4, size.y * 0.3), size.x * 0.75, [[0.0, Color("#3b2a17")], [0.6, Color("#2a1d10")], [1.0, Color("#1e140b")]], 40, Vector2(1.0, 0.75))
	# regions: still under the foe / retaken (breathing)
	for m: Dictionary in missions:
		if not Store.is_done(m.id):
			Draw.glow(self, _p(Vector2(m.pos[0], m.pos[1])), 9 * s, Color(fe.body2, 0.5))
	var breath := 0.8 + 0.2 * cos(t * TAU / 3.0)
	for m: Dictionary in missions:
		if Store.is_done(m.id):
			Draw.glow(self, _p(Vector2(m.pos[0], m.pos[1])), 10 * s, Color(fp.glow, 0.55 * breath))
	# rivers + flowing highlight
	for r: Dictionary in rivers:
		var pts := _xf(r.pts)
		var w: float = r.w * s
		draw_polyline(pts, Color("#2d5f7e"), w, true)
		draw_circle(pts[0], w / 2, Color("#2d5f7e"), true, -1.0, true)
		draw_circle(pts[pts.size() - 1], w / 2, Color("#2d5f7e"), true, -1.0, true)
		_dashed(pts, 1.4 * s, 2.4 * s, -fmod(t / 6.0, 1.0) * 19 * s, Color("#6fa8c8", 0.45), w * 0.35)
	for l: Dictionary in ch.get("lakes", []):
		var c := _p(Vector2(l.cx, l.cy))
		Draw.ellipse(self, c, l.rx * s, l.ry * s, Color("#2d5f7e"))
		Draw.ellipse_line(self, c, l.rx * s, l.ry * s, Color("#6fa8c8", 0.5), 0.3 * s)
	for l: Dictionary in ch.get("labels", []):
		var fs := int(round(float(l.size) * s))
		if l.get("river", false):
			Draw.text_a(self, Style.body, _p(Vector2(l.x, l.y)), l.text, fs, Color("#9cc7de", 0.55), 0.5)
		else:
			Draw.text_a(self, Style.display, _p(Vector2(l.x, l.y)), l.text, fs, Color("#e8d6b0", 0.28), 0.5)
	# march route: dashed all the way, solid up to the next mission after the last win
	var route := PackedVector2Array()
	for m: Dictionary in missions:
		route.append(_p(Vector2(m.pos[0], m.pos[1])))
	_dashed(route, 1.0 * s, 1.2 * s, 0.0, Color("#e8d6b0", 0.25), 0.5 * s)
	var done_idx := 0
	for i in missions.size():
		if Store.is_done(missions[i].id):
			done_idx = i + 1
	if done_idx > 0:
		draw_polyline(route.slice(0, mini(missions.size(), done_idx + 1)), Color(Style.CINNABAR_HI, 0.9), 0.8 * s, true)
	# nodes
	for m: Dictionary in missions:
		var i := Content.mission_index(m.id)
		var done := Store.is_done(m.id)
		var cur := i == open_index
		var locked := i > open_index and not done
		var c := _p(Vector2(m.pos[0], m.pos[1]))
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
		Draw.text_c(self, Style.xbold, c, str(i + 1), int(round(2.6 * s)), Color(Color("#3a1a10") if cur else Style.INK, al))
		var name: String = m.get("region", m.get("place", ""))
		Draw.text_a(self, Style.bold, c + Vector2(0, 5.6 * s), name, int(round(2.5 * s)), Color(Style.INK, al), 0.5, false, int(0.7 * s), Color("#1a0f08"))
	# frame
	draw_style_box(Style.box(Color.TRANSPARENT, Style.BRONZE_2, 12, 0), Rect2(Vector2.ZERO, size))
