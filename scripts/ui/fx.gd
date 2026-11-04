class_name FX
extends Node
## visual effects in tile coordinates: particles, projectiles, rings, numbers, rays, shake, unit lunge / flash, fading corpses.
## Board draws them (draw_under / draw_over / draw_add / draw_top); event playback awaits the async helpers. Port of src/ui/fx.js.

## playback speed x1 / x2 / x3: every duration is divided by it
static var speed := 1.0

var audio: Audio
var parts: Array = []
var projs: Array = []
var rings: Array = []
var floats: Array = []
var rays: Array = []
var ghosts: Array = []
var shake_until := 0.0
var shake_mag := 0.0
var flash_until := {}
var offsets := {}
var _last := 0.0

static func now() -> float:
	return Time.get_ticks_usec() / 1000.0

static func sp(ms: float) -> float:
	return ms / speed

func sleep(ms: float) -> void:
	await get_tree().create_timer(sp(ms) / 1000.0).timeout

func clear() -> void:
	parts.clear(); projs.clear(); rings.clear(); floats.clear(); rays.clear(); ghosts.clear()
	flash_until.clear(); offsets.clear(); shake_until = 0.0

func _play(name: String) -> void:
	if audio:
		audio.play(name)

func burst(x: float, y: float, n: int, o: Dictionary) -> void:
	for i in n:
		var a := randf() * TAU
		var v := randf_range(o.get("vmin", 0.5), o.get("vmax", 2.5))
		var col: Variant = o.color
		parts.append({
			"x": x + randf_range(-0.1, 0.1), "y": y + randf_range(-0.1, 0.1), "vx": cos(a) * v, "vy": sin(a) * v - o.get("up", 0.0),
			"g": o.get("g", 3.0), "drag": o.get("drag", 0.9), "life": 0.0, "max": randf_range(o.get("lmin", 300.0), o.get("lmax", 650.0)),
			"size": randf_range(o.get("smin", 0.03), o.get("smax", 0.07)),
			"color": Color(col[randi() % col.size()]) if col is Array else Color(col), "kind": o.get("kind", "spark"),
		})

func ring(x: float, y: float, color: String, dur := 600.0, max_r := 0.9, width := 0.08) -> void:
	rings.append({ "x": x, "y": y, "color": Color(color), "t0": now(), "dur": sp(dur), "maxR": max_r, "width": width })

func float_text(x: float, y: float, text: String, color: String, dur := 1000.0, big := false) -> void:
	floats.append({ "x": x, "y": y, "text": text, "color": Color(color), "t0": now(), "dur": sp(dur), "big": big })

func shake(mag: float, dur := 260.0) -> void:
	shake_mag = maxf(shake_mag * 0.5, mag)
	shake_until = now() + dur

func flash(id: int, dur := 180.0) -> void:
	flash_until[id] = now() + dur

## calls fn(t) every frame with t 0..1 over dur ms (scaled by speed)
func tween(dur: float, fn: Callable) -> void:
	var t0 := now()
	var d := maxf(0.001, sp(dur))
	while true:
		var t := minf(1.0, (now() - t0) / d)
		fn.call(t)
		if t >= 1.0:
			break
		await get_tree().process_frame

func projectile(kind: String, fx: float, fy: float, tx: float, ty: float, dur: float) -> void:
	var arc := 1.6 if kind == "rock" else (0.35 if kind == "arrow" else 0.15)
	var pr := { "kind": kind, "fx": fx, "fy": fy, "tx": tx, "ty": ty, "t0": now(), "dur": sp(dur), "arc": arc, "trail": [], "hit": false }
	projs.append(pr)
	# also bail on wall time: fx.update only runs while the board is visible
	while not pr.hit and is_inside_tree() and now() < pr.t0 + pr.dur + 100.0:
		await get_tree().process_frame

## attacker / target: {x, y, id, type, side} from the engine's hit event
func attack(a: Dictionary, d: Dictionary, amount: int, opts := {}) -> void:
	var st: Dictionary = Rules.UNITS.get(a.type, {})
	var dd := absi(a.x - d.x) + absi(a.y - d.y)
	var shot: String = st.get("shot", "") if dd > 1 else ""
	var heavy: bool = st.get("heavy", false) or st.get("siege", false) or a.type == "hero"
	if shot != "":
		_play("arrow" if shot == "arrow" else ("orb" if shot == "orb" else "rock"))
		await projectile(shot, a.x, a.y, d.x, d.y, 620.0 if shot == "rock" else (420.0 if shot == "orb" else 300.0))
	else:
		var ldx: float = (d.x - a.x) * 0.42
		var ldy: float = (d.y - a.y) * 0.42
		await tween(120.0, func(t: float) -> void: offsets[a.id] = Vector2(ldx * t * t, ldy * t * t - sin(t * PI) * 0.12))
		_play("slash")
		rays.append({ "kind": "slash", "x": d.x, "y": d.y, "ang": atan2(d.y - a.y, d.x - a.x), "t0": now(), "dur": sp(220.0) })
	_impact(d, amount, heavy or shot == "rock", shot, opts.get("kill", false))
	if shot == "":
		var ldx: float = (d.x - a.x) * 0.42
		var ldy: float = (d.y - a.y) * 0.42
		var back := func(t: float) -> void:
			offsets[a.id] = Vector2(ldx * (1 - t), ldy * (1 - t))
			if t >= 1.0:
				offsets.erase(a.id)
		tween(170.0, back)
	await sleep(260.0 if opts.get("counter", false) else 320.0)

func _impact(d: Dictionary, amount: int, heavy: bool, shot: String, kill: bool) -> void:
	flash(d.id)
	var big := amount >= 35 or heavy
	_play("heavy" if shot == "rock" or (big and heavy) else "hit")
	var col := ["#c9a2ff", "#8f6bff", "#f0e0ff"] if shot == "orb" else ["#ffd27a", "#ff8a4c", "#fff3c4"]
	burst(d.x, d.y, mini(26, 8 + amount / 3), { "color": col, "vmin": 1.0, "vmax": 4.0 if big else 2.8, "lmin": 250.0, "lmax": 600.0, "smin": 0.025, "smax": 0.06, "g": 4.0 })
	if shot == "rock":
		burst(d.x, d.y + 0.2, 14, { "color": ["#7b6a55", "#a08b6e", "#5c4d3c"], "kind": "smoke", "vmin": 0.3, "vmax": 1.2, "up": 0.5, "g": -0.3, "lmin": 600.0, "lmax": 1100.0, "smin": 0.12, "smax": 0.25, "drag": 0.95 })
		ring(d.x, d.y, "#e8c27a", 450.0, 1.2, 0.1)
	if big:
		shake(0.16 if shot == "rock" else 0.09, 380.0 if shot == "rock" else 240.0)
	float_text(d.x, d.y - 0.2, "−" + str(amount), "#ffd166" if kill else "#ff6b57", 1000.0, big or kill)

## corpse fades + smoke; u = copy of the dying unit
func death(u: Dictionary) -> void:
	_play("die")
	ghosts.append({ "u": u, "t0": now(), "dur": sp(650.0) })
	burst(u.x, u.y, 16, { "color": ["#3a3430", "#6b625a", "#8d837a"], "kind": "smoke", "vmin": 0.2, "vmax": 1.1, "up": 0.6, "g": -0.5, "lmin": 600.0, "lmax": 1200.0, "smin": 0.1, "smax": 0.22, "drag": 0.94 })
	burst(u.x, u.y, 6, { "color": "#ffb38a" if u.side == "p" else "#8ff0e8", "kind": "glow", "vmin": 0.1, "vmax": 0.4, "up": 1.2, "g": -0.6, "lmin": 900.0, "lmax": 1400.0, "smin": 0.04, "smax": 0.07 })

func capture(x: int, y: int, side: String) -> void:
	_play("capture")
	var c: String = Content.theme().factions[side].glow
	ring(x, y, c, 700.0, 1.4, 0.12)
	get_tree().create_timer(sp(150.0) / 1000.0).timeout.connect(func() -> void: ring(x, y, "#ffe39a", 600.0, 1.0, 0.06))
	burst(x, y, 22, { "color": [c, "#ffe39a", "#fff7d6"], "kind": "glow", "vmin": 0.4, "vmax": 1.8, "up": 1.2, "g": -0.4, "lmin": 700.0, "lmax": 1300.0, "smin": 0.03, "smax": 0.06 })

func rank(x: int, y: int) -> void:
	_play("rank")
	rays.append({ "kind": "rays", "x": x, "y": y, "t0": now(), "dur": sp(1100.0) })
	burst(x, y, 14, { "color": ["#ffe08a", "#fff6d0"], "kind": "star", "vmin": 0.4, "vmax": 1.6, "up": 1.5, "g": 0.8, "lmin": 700.0, "lmax": 1200.0, "smin": 0.06, "smax": 0.1 })
	float_text(x, y - 0.55, "★ Lên cấp", "#ffe08a", 1300.0)

func raise_fx(x: int, y: int) -> void:
	_play("raise")
	for i in 26:
		var a := float(i) / 26.0 * PI * 4
		parts.append({ "x": x + cos(a) * 0.5, "y": y + sin(a) * 0.5, "vx": -sin(a) * 1.2, "vy": cos(a) * 1.2 - 0.8, "g": -0.6, "drag": 0.92,
			"life": -i * 18.0, "max": 900.0, "size": 0.05, "color": Color("#b38cff") if i % 2 else Color("#e4d4ff"), "kind": "glow" })
	ring(x, y, "#a37cff", 800.0, 1.1, 0.1)

func heal(x: int, y: int, amount: int) -> void:
	burst(x, y + 0.2, 6, { "color": ["#9fe08a", "#d6ffc4"], "kind": "plus", "vmin": 0.05, "vmax": 0.3, "up": 0.9, "g": -0.2, "lmin": 700.0, "lmax": 1000.0, "smin": 0.06, "smax": 0.08 })
	float_text(x, y - 0.1, "+" + str(amount), "#9fe08a", 900.0)

func spawn_fx(x: int, y: int) -> void:
	_play("spawn")
	ring(x, y, "#6fd6cf", 700.0, 1.0, 0.1)
	burst(x, y + 0.3, 18, { "color": ["#a8e6ff", "#5fb6d9", "#ffffff"], "vmin": 0.8, "vmax": 2.4, "up": 2.2, "g": 6.0, "lmin": 400.0, "lmax": 800.0, "smin": 0.03, "smax": 0.06 })

func buy_fx(x: int, y: int) -> void:
	_play("coin")
	ring(x, y, "#ffd166", 500.0, 0.9, 0.08)
	burst(x, y, 12, { "color": ["#ffd166", "#fff0b3", "#e0a43a"], "kind": "coin", "vmin": 0.8, "vmax": 2.0, "up": 2.0, "g": 6.0, "lmin": 500.0, "lmax": 800.0, "smin": 0.05, "smax": 0.07 })

func dust(x: float, y: float) -> void:
	burst(x, y + 0.32, 3, { "color": ["#c9b48a", "#a8936b"], "kind": "smoke", "vmin": 0.1, "vmax": 0.5, "up": 0.2, "g": -0.1, "lmin": 300.0, "lmax": 500.0, "smin": 0.06, "smax": 0.1, "drag": 0.9 })

# ---------- update + draw ----------
func update(t: float) -> void:
	var dt := minf(0.05, (t - _last) / 1000.0) * speed
	_last = t
	for p: Dictionary in parts:
		p.life += dt * 1000.0
		if p.life < 0:
			continue
		var dr := pow(p.drag, dt * 60.0)
		p.vx *= dr
		p.vy *= dr
		p.vy += p.g * dt
		p.x += p.vx * dt
		p.y += p.vy * dt
	parts = parts.filter(func(p: Dictionary) -> bool: return p.life < p.max)
	if parts.size() > 600:
		parts = parts.slice(parts.size() - 600)
	rings = rings.filter(func(r: Dictionary) -> bool: return t - r.t0 < r.dur)
	floats = floats.filter(func(f: Dictionary) -> bool: return t - f.t0 < f.dur)
	rays = rays.filter(func(r: Dictionary) -> bool: return t - r.t0 < r.dur)
	ghosts = ghosts.filter(func(g: Dictionary) -> bool: return t - g.t0 < g.dur)
	for pr: Dictionary in projs:
		var k := minf(1.0, (t - pr.t0) / pr.dur)
		pr.trail.append(_proj_pos(pr, k))
		if pr.trail.size() > 8:
			pr.trail.pop_front()
		if k >= 1.0:
			pr.hit = true
	projs = projs.filter(func(p: Dictionary) -> bool: return not p.hit)

static func _proj_pos(pr: Dictionary, k: float) -> Vector2:
	return Vector2(pr.fx + (pr.tx - pr.fx) * k, pr.fy + (pr.ty - pr.fy) * k - sin(k * PI) * pr.arc)

## shake offset in tiles
func shake_offset(t: float) -> Vector2:
	if t > shake_until:
		shake_mag = 0.0
		return Vector2.ZERO
	var m := shake_mag * ((shake_until - t) / 300.0)
	return Vector2(randf_range(-m, m), randf_range(-m, m))

func draw_under(ci: CanvasItem, T: float, t: float) -> void:
	for r: Dictionary in rings:
		var k: float = (t - r.t0) / r.dur
		var col: Color = r.color
		col.a = (1.0 - k) * 0.9
		var s: float = r.maxR * T * (0.2 + k * 0.8)
		Draw.ellipse_line(ci, Vector2((r.x + 0.5) * T, (r.y + 0.62) * T), s, s * 0.5, col, maxf(1.0, r.width * T * (1.0 - k * 0.6)))

## normal-blend effects: arrows, rocks, smoke, stars, pluses, coins
func draw_over(ci: CanvasItem, T: float, t: float) -> void:
	for pr: Dictionary in projs:
		var k := minf(1.0, (t - pr.t0) / pr.dur)
		var p := _proj_pos(pr, k)
		var q := _proj_pos(pr, maxf(0.0, k - 0.05))
		var X := (p + Vector2(0.5, 0.5)) * T
		if pr.kind == "arrow":
			var tr := Transform2D((p - q).angle(), X)
			ci.draw_line(tr * Vector2(-T * 0.3, 0), tr * Vector2(T * 0.12, 0), Color("#3b2a1a"), maxf(1.5, T * 0.04), true)
			ci.draw_colored_polygon(PackedVector2Array([tr * Vector2(T * 0.2, 0), tr * Vector2(T * 0.1, -T * 0.05), tr * Vector2(T * 0.1, T * 0.05)]), Color("#d8d0c0"))
			ci.draw_colored_polygon(PackedVector2Array([tr * Vector2(-T * 0.3, -T * 0.04), tr * Vector2(-T * 0.22, -T * 0.04), tr * Vector2(-T * 0.22, T * 0.04), tr * Vector2(-T * 0.3, T * 0.04)]), Color("#c2412f"))
		elif pr.kind == "rock":
			var g := Vector2((pr.fx + (pr.tx - pr.fx) * k + 0.5) * T, (pr.fy + (pr.ty - pr.fy) * k + 0.75) * T)
			Draw.ellipse(ci, g, T * 0.14, T * 0.06, Color(0, 0, 0, 0.33))
			ci.draw_circle(X, T * 0.13, Color("#8a7a64"))
			ci.draw_circle(X + Vector2(-T * 0.04, -T * 0.04).rotated(k * 8), T * 0.05, Color("#b3a285"))
	for p: Dictionary in parts:
		if p.life < 0 or p.kind in ["glow", "spark"]:
			continue
		var k: float = p.life / p.max
		var X := Vector2((p.x + 0.5) * T, (p.y + 0.5) * T)
		var R: float = p.size * T
		var col: Color = p.color
		if p.kind == "smoke":
			col.a = (1.0 - k) * 0.55
			ci.draw_circle(X, R * (1.0 + k * 1.5), col)
		elif p.kind == "star":
			col.a = 1.0 - k
			var pts := PackedVector2Array()
			for i in 10:
				var rr := R * 0.4 if i % 2 else R
				var a := float(i) / 10.0 * TAU + k * 4
				pts.append(X + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts, col)
		elif p.kind == "plus":
			col.a = 1.0 - k
			ci.draw_rect(Rect2(X.x - R, X.y - R * 0.3, R * 2, R * 0.6), col)
			ci.draw_rect(Rect2(X.x - R * 0.3, X.y - R, R * 0.6, R * 2), col)
		elif p.kind == "coin":
			col.a = 1.0 - k * k
			Draw.ellipse(ci, X, R, maxf(0.5, R * absf(cos(p.life / 80.0))), col, 0.0, 16)

## additive effects (canvas 'lighter'): rank rays, slash arcs, orbs, glows, sparks
func draw_add(ci: CanvasItem, T: float, t: float) -> void:
	for r: Dictionary in rays:
		var k: float = (t - r.t0) / r.dur
		var c := Vector2((r.x + 0.5) * T, (r.y + 0.5) * T)
		if r.kind == "rays":
			var al := sin(k * PI) * 0.8
			for i in 10:
				var a := k * 1.2 + TAU / 10.0 * (i + 1)
				var dir := Vector2(sin(a), -cos(a))
				var side := Vector2(dir.y, -dir.x) * T * 0.06
				ci.draw_polygon(PackedVector2Array([c - side, c + dir * T * 1.4, c + side]),
					PackedColorArray([Color(1, 0.878, 0.541, 0.8 * al), Color(1, 0.878, 0.541, 0.0), Color(1, 0.878, 0.541, 0.8 * al)]))
		elif r.kind == "slash":
			var rot: float = r.ang + PI / 2
			var a0 := -2.2 + k * 1.2 + rot
			ci.draw_arc(c, T * 0.42, a0, a0 + 1.3, 12, Color(1, 0.957, 0.839, 1.0 - k), T * 0.08 * (1.0 - k) + 1.0, true)
			var a1 := -2.1 + k * 1.2 + rot
			ci.draw_arc(c, T * 0.34, a1, a1 + 1.1, 10, Color(1, 0.69, 0.4, 1.0 - k), T * 0.03, true)
	for pr: Dictionary in projs:
		if pr.kind != "orb":
			continue
		var k := minf(1.0, (t - pr.t0) / pr.dur)
		var X := (_proj_pos(pr, k) + Vector2(0.5, 0.5)) * T
		var n: int = pr.trail.size()
		for i in n:
			var tp: Vector2 = pr.trail[i]
			ci.draw_circle((tp + Vector2(0.5, 0.5)) * T, maxf(0.5, T * 0.08 * float(i) / n), Color(0.62, 0.48, 1.0, float(i) / n * 0.5))
		Draw.radial(ci, X, T * 0.22, [[0.0, Color.WHITE], [0.35, Color("#c9a2ff")], [1.0, Color(0.42, 0.24, 1.0, 0.0)]], 20)
	for p: Dictionary in parts:
		if p.life < 0 or not (p.kind in ["glow", "spark"]):
			continue
		var k: float = p.life / p.max
		var col: Color = p.color
		col.a = 1.0 - k
		ci.draw_circle(Vector2((p.x + 0.5) * T, (p.y + 0.5) * T), maxf(0.5, p.size * T * (1.4 if p.kind == "glow" else 1.0 - k * 0.5)), col)

## floating numbers / labels
func draw_top(ci: CanvasItem, T: float, t: float) -> void:
	for f: Dictionary in floats:
		var k: float = (t - f.t0) / f.dur
		var pop := 0.6 + (k / 0.15) * 0.7 if k < 0.15 else 1.3 - minf(0.3, (k - 0.15) * 1.5)
		var col: Color = f.color
		col.a = 1.0 - (k - 0.7) / 0.3 if k > 0.7 else 1.0
		var size := int(round(T * (0.46 if f.big else 0.34) * pop))
		var pos := Vector2((f.x + 0.5) * T, (f.y + 0.3) * T - k * T * 0.55)
		Draw.text_c(ci, Style.xbold, pos, f.text, maxi(6, size), col, maxi(3, int(T * 0.08)), Color(0.1, 0.047, 0.024, col.a))
