class_name BattleView
extends Control
## side-view duel played for each attack (setting "battle_scene", on by default): the screen splits, each squad stands on
## the terrain of its own tile, the attacker charges or looses a volley, casualties fall, the defender strikes back,
## then the board returns. Our side always on the left. Click / any key skips. Durations follow FX.speed.
## Sizes follow min(width, height) so portrait phones fit the squads. While fully open it sets `covering` and the
## board stops drawing underneath.

const FRONT := 1.25 # front rank distance from the seam, in figure sizes
const SLOTS := [Vector2(0, 0), Vector2(-1.1, -0.75), Vector2(-1.1, 0.75), Vector2(-2.2, 0.0), Vector2(-2.2, 1.5)]
const BIG_SLOTS := [Vector2(0, 0), Vector2(-1.2, -0.7), Vector2(-1.2, 0.7)]
const GOLD_NUM := Color("#ffd166")
const RED_NUM := Color("#ff6b57")
const SPARK := [Color("#ffd27a"), Color("#ff8a4c"), Color("#fff3c4")]
const MAGIC := [Color("#c9a2ff"), Color("#8f6bff"), Color("#f0e0ff")]
const ROCK := [Color("#7b6a55"), Color("#a08b6e"), Color("#e8c27a")]
const ARROW_HIT := [Color("#ffd27a"), Color("#fff3c4")]
const DUST := [Color("#6b625a"), Color("#8d837a"), Color("#3a3430")]
const SKY_DAY := [[0.0, Color("#5f7fa3")], [0.55, Color("#c9b48e")], [1.0, Color("#e8c9a0")]]
const SKY_NIGHT := [[0.0, Color("#0b1424")], [0.55, Color("#253354")], [1.0, Color("#3a3f58")]]
const MOON := Color("#e8ecf7")
const RIDGE_1 := Color("#5d6b7e")
const RIDGE_1N := Color("#1a2236")
const RIDGE_2 := Color("#4d5a4a")
const RIDGE_2N := Color("#141b2a")
const PLANK := Color("#8a6438")
const TRUNK := Color("#4a3420")
const DOOR := Color("#3a2a1c")
const GATE := Color("#2d2219")
const POLE := Color("#3b3026")
const FLAG_N := Color("#a89b84")
const SHAFT := Color("#e8d6b0")
const ARROW_TIP := Color("#f4e8cf")
const ORB := Color("#f0e0ff")
const STONE := Color("#7b6a55")
const STONE_HI := Color("#a08b6e")

## true while the duel fills the screen (Board draws nothing then)
static var covering := false

var main: Main
var _skip := false
var _run := 0 # bumped by every run() / close(): coroutines of an older run stop touching state
var _scenery_key := ""
var _open := 0.0
var _d := {}
var _sq := { "p": [], "e": [] }
var _hp := { "p": 100.0, "e": 100.0 }
var _parts: Array = []
var _projs: Array = []
var _slashes: Array = []
var _floats: Array = []
var _shake_until := 0.0
var _shake_mag := 0.0
var _halves := {}
var _top: Control

static func enabled() -> bool:
	return bool(Store.get_v("battle_scene", true))

static func set_enabled(on: bool) -> void:
	Store.set_v("battle_scene", on)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	for side: String in ["p", "e"]:
		var h := Layer.new()
		h.clip_contents = true
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.paint = _paint_half.bind(side)
		add_child(h)
		_halves[side] = h
	_top = Layer.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top.paint = _paint_top
	add_child(_top)

func is_open() -> bool:
	return visible

## fast-forward the running duel (no-op when none runs)
func skip() -> void:
	if visible:
		_skip = true

## abort at once (leaving the game screen): no close animation, any pending tween of this run is dropped
func close() -> void:
	_run += 1
	_skip = true
	_open = 0.0
	covering = false
	visible = false

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		skip()
		accept_event()

func _input(ev: InputEvent) -> void:
	if visible and ev is InputEventKey and ev.pressed and not ev.echo:
		skip()
		get_viewport().set_input_as_handled()

# ---------- timing (skippable, scaled by FX.speed) ----------
static func _now() -> float:
	return Time.get_ticks_usec() / 1000.0

func _tw(ms: float, fn: Callable) -> void:
	var my := _run
	var t0 := _now()
	var d := maxf(1.0, FX.sp(ms))
	while my == _run:
		var t := 1.0 if _skip else minf(1.0, (_now() - t0) / d)
		fn.call(t)
		if t >= 1.0:
			return
		await get_tree().process_frame

func _wait(ms: float) -> void:
	var my := _run
	var end := _now() + FX.sp(ms)
	while my == _run and not _skip and _now() < end and is_inside_tree():
		await get_tree().process_frame

# ---------- squads ----------
## figures shown for a unit at this hp: 5 for a full infantry squad, 3 for big units, 1 commander
static func squad_n(type: String, hp: float) -> int:
	if hp <= 0.0:
		return 0
	if type == "hero":
		return 1
	if type in ["elephant", "catapult"]:
		return clampi(ceili(hp / 34.0), 1, 3)
	return clampi(ceili(hp / 20.0), 1, 5)

## layout unit: the height on landscape screens, narrower on portrait so a 5-man squad fits half the width
func _u() -> float:
	return minf(size.y, size.x * 0.85)

func _fig_size(type: String) -> float:
	return _u() * (0.2 if type == "hero" else (0.17 if type in ["elephant", "catapult"] else 0.13))

func _ground_y() -> float:
	return size.y * 0.66

func _build_squads() -> void:
	for side: String in ["p", "e"]:
		var u: Dictionary = _d[side]
		var T := _fig_size(u.type)
		var dir := 1.0 if side == "p" else -1.0
		var slots: Array = BIG_SLOTS if u.type in ["elephant", "catapult"] else SLOTS
		var n := squad_n(u.type, u.hp0)
		var arr: Array = []
		for i in n:
			var sl: Vector2 = slots[i]
			var home := Vector2(size.x / 2.0 - dir * T * FRONT + dir * sl.x * T, _ground_y() + sl.y * T * 0.5)
			arr.append({ "home": home, "off": Vector2.ZERO, "T": T * (1.0 - sl.y * 0.06), "alive": true, "dead_t": -1.0,
				"flash": 0.0, "ph": randf() * TAU, "run": false, "knock": 0.0, "lean": 0.0 })
		_sq[side] = arr

func _alive(side: String) -> Array:
	return _sq[side].filter(func(f: Dictionary) -> bool: return f.alive)

func _pos(f: Dictionary) -> Vector2:
	return f.home + f.off

# ---------- the duel ----------
## d: { p: unit, e: unit, att: "p"|"e", first: hit, counter: hit|null, night }
## unit: { side, type, hero, hp0, tile, owner, rank, def }; hit: { amount, kill, shot }
func run(d: Dictionary) -> void:
	_run += 1
	var my := _run
	_d = d
	_skip = false
	_parts.clear(); _projs.clear(); _slashes.clear(); _floats.clear()
	_hp = { "p": float(d.p.hp0), "e": float(d.e.hp0) }
	_open = 0.0
	_scenery_key = ""
	visible = true
	_build_squads()
	_play("drum")
	await _tw(420.0, func(t: float) -> void: _open = 1.0 - pow(1.0 - t, 3.0))
	if my != _run:
		return
	await _wait(260.0)
	await _strike(d.att, d.first)
	if my != _run:
		return
	if d.counter != null and not _skip:
		await _wait(220.0)
		await _strike("e" if d.att == "p" else "p", d.counter)
	await _wait(650.0)
	if my != _run:
		return
	_skip = false # always play the short close so the cut back to the board is not abrupt
	await _tw(260.0, func(t: float) -> void: _open = 1.0 - t)
	if my != _run:
		return
	visible = false
	covering = false

func _strike(side: String, hit: Dictionary) -> void:
	var foe := "e" if side == "p" else "p"
	var dir := 1.0 if side == "p" else -1.0
	var my := _run
	var att := _alive(side)
	var tgt := _alive(foe)
	if att.is_empty() or tgt.is_empty():
		return
	var hp_after := maxf(0.0, _hp[foe] - hit.amount)
	var lose := tgt.size() - squad_n(_d[foe].type, hp_after)
	# front rank falls first
	tgt.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(a.home.x - size.x / 2.0) < absf(b.home.x - size.x / 2.0))
	var losers: Array = tgt.slice(0, lose)
	var shot: String = hit.get("shot", "")
	var heavy: bool = _d[side].type in ["hero", "elephant", "catapult"]
	var dx := 0.0
	if shot != "":
		_play("arrow" if shot == "arrow" else ("orb" if shot == "orb" else "rock"))
		var flights: Array = []
		for i in att.size():
			var f: Dictionary = att[i]
			var to: Dictionary = tgt[i % tgt.size()]
			f.lean = 1.0
			flights.append(_launch(shot, _pos(f) + Vector2(dir * f.T * 0.3, -f.T * 0.25), _pos(to) + Vector2(0, -to.T * 0.1), i * 90.0, to))
		for pr: Dictionary in flights:
			while not pr.done and not _skip and my == _run:
				await get_tree().process_frame
		if my != _run:
			return
		for f: Dictionary in att:
			f.lean = 0.0
	else:
		# charge: the attackers' front reaches just short of the defenders' front
		var my_front: float = att.map(func(f: Dictionary) -> float: return f.home.x).reduce(func(a: float, b: float) -> float: return maxf(a, b) if dir > 0 else minf(a, b))
		var their_front: float = tgt.map(func(f: Dictionary) -> float: return f.home.x).reduce(func(a: float, b: float) -> float: return minf(a, b) if dir > 0 else maxf(a, b))
		dx = their_front - my_front - dir * _fig_size(_d[foe].type) * 0.75
		for f: Dictionary in att:
			f.run = true
		_play("move")
		await _tw(380.0 if heavy else 330.0, func(t: float) -> void:
			for f: Dictionary in att:
				f.off.x = dx * t * t)
		if my != _run:
			return
		_play("slash")
		for i in tgt.size():
			var f: Dictionary = tgt[i]
			_slashes.append({ "p": _pos(f) + Vector2(0, -f.T * 0.15), "t0": _now() + FX.sp(i * 45.0), "dur": FX.sp(260.0), "dir": dir, "R": f.T * 0.62 })
		await _wait(120.0)
		if my != _run:
			return
	# impact
	_play("heavy" if heavy or shot == "rock" else "hit")
	_shake(0.022 if heavy or shot == "rock" or hit.amount >= 35 else 0.012, 320.0)
	var col := MAGIC if shot == "orb" else SPARK
	for f: Dictionary in tgt:
		f.flash = 1.0
		if shot == "":
			_burst(_pos(f) + Vector2(0, -f.T * 0.2), 9, col, f.T * 0.05, 3.0)
	for f: Dictionary in losers:
		f.alive = false
		f.dead_t = _now()
		f.knock = dir
		_burst(_pos(f) + Vector2(0, f.T * 0.2), 10, DUST, f.T * 0.09, 1.2, true)
	if not losers.is_empty():
		_play("die")
	var mid := Vector2(size.x * (0.75 if foe == "e" else 0.25), size.y * 0.36)
	var big: bool = hit.kill or hit.amount >= 35
	_floats.append({ "p": mid, "text": "−%d" % hit.amount, "t0": _now(), "dur": FX.sp(1100.0), "col": GOLD_NUM if hit.kill else RED_NUM, "big": big })
	var hp0: float = _hp[foe]
	var hp_d := _hp # this run's dict: a stale tween (dropped via _run anyway) never writes into the next duel
	_tw(420.0, func(t: float) -> void: hp_d[foe] = lerpf(hp0, hp_after, 1.0 - pow(1.0 - t, 2.0))) # runs alongside the pull-back
	if shot == "":
		await _wait(160.0)
		if my != _run:
			return
		await _tw(300.0, func(t: float) -> void:
			for f: Dictionary in att:
				f.off.x = dx * (1.0 - t))
		for f: Dictionary in att:
			f.run = false
			f.off = Vector2.ZERO
	await _wait(460.0 if shot != "" else 240.0)

func _launch(kind: String, from: Vector2, to: Vector2, delay: float, target: Dictionary) -> Dictionary:
	var pr := { "kind": kind, "from": from, "to": to, "t0": _now() + FX.sp(delay), "dur": FX.sp(560.0 if kind == "rock" else (420.0 if kind == "orb" else 300.0)),
		"arc": 0.55 if kind == "rock" else (0.16 if kind == "arrow" else 0.05), "done": false, "target": target, "trail": [] }
	_projs.append(pr)
	return pr

func _shake(mag: float, ms: float) -> void:
	_shake_mag = maxf(_shake_mag * 0.5, mag)
	_shake_until = _now() + FX.sp(ms)

func _burst(p: Vector2, n: int, cols: Array, sz: float, speed: float, smoke := false) -> void:
	var H := _u()
	for i in n:
		var a := randf() * TAU
		var v := randf_range(0.3, 1.0) * speed * H * 0.12
		_parts.append({ "p": p, "v": Vector2(cos(a) * v, sin(a) * v - (H * 0.08 if smoke else 0.0)), "life": 0.0,
			"max": randf_range(500.0, 1000.0) if smoke else randf_range(250.0, 600.0), "s": sz * randf_range(0.6, 1.2),
			"c": cols[randi() % cols.size()], "smoke": smoke })

func _play(name: String) -> void:
	if main and main.audio:
		main.audio.play(name)

# ---------- frame update ----------
var _last := 0.0
var _drawn_open := -1.0
func _process(_dt: float) -> void:
	if not visible:
		covering = false # hidden by anything else: never leave the board switched off
		return
	var now := _now()
	var dt := (clampf((now - _last) / 1000.0, 0.0, 0.05) if _last > 0.0 else 0.016) * FX.speed
	_last = now
	var H := _u()
	for pt: Dictionary in _parts:
		pt.life += dt * 1000.0
		pt.v *= pow(0.92 if pt.smoke else 0.9, FX.speed)
		pt.v.y += (-H * 0.02 if pt.smoke else H * 0.9) * dt
		pt.p += pt.v * dt
	_parts = _parts.filter(func(pt: Dictionary) -> bool: return pt.life < pt.max)
	for pr: Dictionary in _projs:
		if pr.done:
			continue
		var k := clampf((now - pr.t0) / pr.dur, 0.0, 1.0)
		if now < pr.t0:
			continue
		pr.trail.append(_proj_pos(pr, k))
		if pr.trail.size() > 8:
			pr.trail.remove_at(0)
		if k >= 1.0:
			pr.done = true
			var col: Array = MAGIC if pr.kind == "orb" else (ROCK if pr.kind == "rock" else ARROW_HIT)
			_burst(pr.to, 12 if pr.kind == "rock" else 7, col, H * 0.008, 2.6 if pr.kind == "rock" else 1.6)
			pr.target.flash = 1.0
	_projs = _projs.filter(func(pr: Dictionary) -> bool: return not pr.done)
	for side: String in ["p", "e"]:
		for f: Dictionary in _sq[side]:
			f.flash = maxf(0.0, f.flash - dt * 4.0)
	_slashes = _slashes.filter(func(sl: Dictionary) -> bool: return now < sl.t0 + sl.dur)
	_floats = _floats.filter(func(fl: Dictionary) -> bool: return now < fl.t0 + fl.dur)
	# halves slide in from the sides
	var w := size.x / 2.0
	_halves.p.position = Vector2(-(1.0 - _open) * w, 0)
	_halves.p.size = Vector2(w + 1, size.y)
	_halves.e.position = Vector2(w + (1.0 - _open) * w, 0)
	_halves.e.size = Vector2(w, size.y)
	_halves.p.modulate.a = _open
	_halves.e.modulate.a = _open
	covering = _open >= 1.0
	# scenery is static except water / bridge water and the castle flag: repaint those every frame, the rest once per duel
	var key := "%d|%s" % [_run, size]
	for side: String in ["p", "e"]:
		if key != _scenery_key or _d[side].tile in ["~", "=", "c"]:
			_halves[side].queue_redraw()
	_scenery_key = key
	_top.queue_redraw()
	if _open != _drawn_open:
		_drawn_open = _open
		queue_redraw()

static func _proj_pos(pr: Dictionary, k: float) -> Vector2:
	var p: Vector2 = pr.from.lerp(pr.to, k)
	p.y -= sin(k * PI) * pr.arc * absf(pr.to.x - pr.from.x)
	return p

func _shake_off() -> Vector2:
	var now := _now()
	if now > _shake_until:
		return Vector2.ZERO
	var m := _shake_mag * _u()
	return Vector2(randf_range(-m, m), randf_range(-m, m))

# ---------- drawing ----------
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.0, 0.62 * _open))

## background for one half (local coords of that half): sky, far hills, the unit's terrain, its building
func _paint_half(ci: Control, side: String) -> void:
	if _d.is_empty():
		return
	var u: Dictionary = _d[side]
	var w := ci.size.x
	var H := ci.size.y
	var U := _u() # object sizes (narrow on portrait); H stays for vertical extents
	var gy := _ground_y() - H * 0.1
	var night: bool = _d.get("night", false)
	var pal := Draw.pal()
	var th: Dictionary = pal.terrain.get(u.tile, pal.terrain["."])
	var sky := SKY_NIGHT if night else SKY_DAY
	Draw.gradient_rect(ci, Rect2(0, 0, w, gy), sky)
	if night:
		Draw.glow(ci, Vector2(w * (0.3 if side == "p" else 0.7), H * 0.2), H * 0.12, Color(0.85, 0.88, 1.0, 0.35))
		ci.draw_circle(Vector2(w * (0.3 if side == "p" else 0.7), H * 0.2), H * 0.035, MOON)
	else:
		Draw.glow(ci, Vector2(w * 0.5, gy), H * 0.35, Color(1.0, 0.85, 0.6, 0.35), Vector2(1.6, 0.6))
	# far ranges, phase depends on side so the halves differ
	var ph := 0.0 if side == "p" else 2.3
	_ridge(ci, w, gy, H * 0.16, RIDGE_1 if not night else RIDGE_1N, 0.011, ph)
	_ridge(ci, w, gy, H * 0.09, RIDGE_2 if not night else RIDGE_2N, 0.019, ph + 1.0)
	var t: String = u.tile
	var base := Color(th.get("base", "#5a7a3a"))
	match t:
		"~", "=":
			Draw.gradient_rect(ci, Rect2(0, gy, w, H - gy), [[0.0, Color(th.get("wave", "#4c8db0"))], [1.0, Color(th.get("deep", "#1c4766"))]])
			var ph2 := _now() / 700.0
			for i in 7:
				var yy := gy + (H - gy) * (0.12 + i * 0.13)
				var pts := PackedVector2Array()
				for j in 13:
					var xx := w * j / 12.0
					pts.append(Vector2(xx, yy + sin(ph2 + j * 0.9 + i * 1.7) * H * 0.006))
				ci.draw_polyline(pts, Color(0.75, 0.88, 0.95, 0.25), maxf(1.0, H * 0.003), true)
			if t == "=":
				var py := _ground_y() + H * 0.02
				ci.draw_rect(Rect2(0, py - H * 0.03, w, H * 0.09), Color(th.get("plank", "#8a6438")))
				for i in 16:
					var xx := w * i / 15.0
					ci.draw_line(Vector2(xx, py - H * 0.03), Vector2(xx, py + H * 0.06), Color(th.get("plank2", "#5e4124")), maxf(1.0, H * 0.004))
				for i in 5:
					ci.draw_rect(Rect2(w * (0.1 + i * 0.2), py + H * 0.06, H * 0.02, H * 0.12), Color(th.get("plank2", "#5e4124")))
			elif t == "~":
				var py := _ground_y() + H * 0.04 # raft for a commander who walks on water
				ci.draw_rect(Rect2(w * 0.5 - U * 0.2 + (U * 0.12 if side == "p" else -U * 0.12), py - U * 0.02, U * 0.4, U * 0.05), PLANK)
		_:
			Draw.gradient_rect(ci, Rect2(0, gy, w, H - gy), [[0.0, base.lightened(0.08)], [1.0, base.darkened(0.35)]])
	match t:
		".", "v", "r":
			var line := Color(th.get("line", "#6d8f44"))
			for i in 9: # rice rows running to the horizon
				var yy := gy + (H - gy) * pow(float(i + 1) / 10.0, 1.6)
				ci.draw_line(Vector2(0, yy), Vector2(w, yy), Color(line, 0.55), maxf(1.0, H * 0.003))
			if t == "r":
				var dirt := Color(th.get("dirt", "#a48a58"))
				ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.42, gy), Vector2(w * 0.58, gy), Vector2(w * 0.95, H), Vector2(w * 0.05, H)]), dirt)
			if t == "v":
				_house(ci, Vector2(w * (0.28 if side == "p" else 0.72), gy), U * 0.2, th, u.owner)
		"f":
			for i in 9: # tree line behind
				var x := w * (i + 0.5) / 9.0 + sin(i * 2.1 + ph) * w * 0.03
				_tree(ci, Vector2(x, gy + H * 0.01), U * (0.22 + 0.06 * sin(i * 1.3 + ph)), th)
			for i in 2: # and two in front, at the outer edge
				var x := w * (0.06 + i * 0.12) if side == "p" else w * (0.94 - i * 0.12)
				_tree(ci, Vector2(x, H * 0.98), U * 0.34, th)
		"h":
			var hill := Color(th.get("hill", "#959150"))
			var hill2 := Color(th.get("hill2", "#aaa65d"))
			Draw.ellipse(ci, Vector2(w * 0.3, gy + H * 0.03), w * 0.45, H * 0.12, hill2)
			Draw.ellipse(ci, Vector2(w * 0.8, gy + H * 0.05), w * 0.4, H * 0.1, hill)
		"m":
			var rock := Color(th.get("rock", "#8a7f6e"))
			var rock2 := Color(th.get("rock2", "#6f6556"))
			var snow := Color(th.get("snow", "#e4ddcd"))
			for i in 3:
				var px := w * (0.2 + i * 0.32)
				var ph3 := H * (0.32 + 0.08 * sin(i * 2.0 + ph))
				ci.draw_colored_polygon(PackedVector2Array([Vector2(px - w * 0.22, gy + 2), Vector2(px, gy - ph3), Vector2(px + w * 0.22, gy + 2)]), rock)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(px, gy - ph3), Vector2(px + w * 0.22, gy + 2), Vector2(px + w * 0.04, gy + 2)]), rock2)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(px - w * 0.06, gy - ph3 * 0.72), Vector2(px, gy - ph3), Vector2(px + w * 0.06, gy - ph3 * 0.72), Vector2(px, gy - ph3 * 0.64)]), snow)
		"c":
			_wall(ci, w, gy, U, th, u.owner, side)
	if night:
		ci.draw_rect(Rect2(0, 0, w, H), Color(0.04, 0.07, 0.18, 0.35))
	# seam shade toward the centre
	var seam := w if side == "p" else 0.0
	Draw.gradient_rect(ci, Rect2(seam - (w * 0.18 if side == "p" else 0.0), 0, w * 0.18, H),
		[[0.0, Color(0, 0, 0, 0.0 if side == "p" else 0.35)], [1.0, Color(0, 0, 0, 0.35 if side == "p" else 0.0)]], false)

func _ridge(ci: CanvasItem, w: float, gy: float, amp: float, col: Color, f: float, ph: float) -> void:
	var pts := PackedVector2Array([Vector2(0, gy + 2)])
	for i in 41:
		var x := w * i / 40.0
		pts.append(Vector2(x, gy - amp * (0.55 + 0.35 * sin(x * f + ph) + 0.15 * sin(x * f * 3.1 + ph * 2.0))))
	pts.append(Vector2(w, gy + 2))
	ci.draw_colored_polygon(pts, col)

func _tree(ci: CanvasItem, base: Vector2, h: float, th: Dictionary) -> void:
	ci.draw_rect(Rect2(base.x - h * 0.03, base.y - h * 0.18, h * 0.06, h * 0.18), TRUNK)
	var c1 := Color(th.get("tree", "#22401b"))
	var c2 := Color(th.get("tree2", "#2f5523"))
	for k in 3:
		var y := base.y - h * (0.15 + k * 0.22)
		var r := h * (0.32 - k * 0.07)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(base.x, y - h * 0.36), Vector2(base.x - r, y), Vector2(base.x + r, y)]), c1)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(base.x, y - h * 0.36), Vector2(base.x + r * 0.1, y), Vector2(base.x + r, y)]), c2)

func _roof_col(owner: Variant) -> Color:
	var facs: Dictionary = Draw.pal().factions
	return facs.get(owner if owner != null else "n", facs.n).roof

func _house(ci: CanvasItem, b: Vector2, h: float, th: Dictionary, owner: Variant) -> void:
	var wall := Color(th.get("wall", "#dcc6a0"))
	ci.draw_rect(Rect2(b.x - h * 0.6, b.y - h * 0.55, h * 1.2, h * 0.55), wall)
	ci.draw_rect(Rect2(b.x - h * 0.12, b.y - h * 0.38, h * 0.24, h * 0.38), DOOR)
	var roof := PackedVector2Array([Vector2(b.x - h * 0.95, b.y - h * 0.5), Vector2(b.x - h * 0.6, b.y - h * 0.95), Vector2(b.x + h * 0.6, b.y - h * 0.95), Vector2(b.x + h * 0.95, b.y - h * 0.5)])
	ci.draw_colored_polygon(roof, _roof_col(owner))
	if owner != null and owner != "n":
		Draw.glow(ci, Vector2(b.x, b.y - h * 0.2), h * 0.3, Color(1.0, 0.85, 0.54, 0.6))

func _wall(ci: CanvasItem, w: float, gy: float, H: float, th: Dictionary, owner: Variant, side: String) -> void:
	var wall := Color(th.get("wall", "#b0a48c"))
	var wall2 := Color(th.get("wall2", "#8c816c"))
	var top := gy - H * 0.2
	ci.draw_rect(Rect2(0, top, w, gy - top + 2), wall2)
	ci.draw_rect(Rect2(0, top, w, H * 0.02), wall)
	for i in 12:
		ci.draw_rect(Rect2(w * i / 12.0, top - H * 0.035, w / 24.0, H * 0.035), wall)
	var gx := w * (0.3 if side == "p" else 0.7)
	ci.draw_rect(Rect2(gx - H * 0.12, top - H * 0.16, H * 0.24, H * 0.16), wall2.darkened(0.1))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(gx - H * 0.18, top - H * 0.15), Vector2(gx - H * 0.1, top - H * 0.24), Vector2(gx + H * 0.1, top - H * 0.24), Vector2(gx + H * 0.18, top - H * 0.15)]), _roof_col(owner))
	Draw.ellipse_arc(ci, Vector2(gx, gy + 2), H * 0.07, H * 0.1, PI, TAU, GATE)
	var wave := sin(_now() / 260.0) * H * 0.01
	ci.draw_line(Vector2(gx, top - H * 0.24), Vector2(gx, top - H * 0.36), POLE, 2.0)
	var facs: Dictionary = Draw.pal().factions
	var fac: Dictionary = facs.get(owner if owner != null else "n", facs.n)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(gx, top - H * 0.36), Vector2(gx + H * 0.1, top - H * 0.34 + wave), Vector2(gx, top - H * 0.3)]), Color(fac.get("glow", FLAG_N)))

## squads, projectiles, effects, letterbox HUD
func _paint_top(ci: Control) -> void:
	if _d.is_empty():
		return
	var W := ci.size.x
	var HH := ci.size.y
	var H := _u() # sizes; HH for vertical extents
	var sh := _shake_off()
	var now := _now()
	# seam: a bronze blade stroke
	var a := _open
	var s0 := Vector2(W / 2.0 + H * 0.05, 0) + sh
	var s1 := Vector2(W / 2.0 - H * 0.05, HH) + sh
	ci.draw_line(s0, s1, Color(0.05, 0.03, 0.02, 0.9 * a), maxf(4.0, H * 0.012), true)
	ci.draw_line(s0, s1, Color(Style.GOLD, 0.8 * a), maxf(1.5, H * 0.003), true)
	# figures, back rows first
	var figs: Array = []
	for side: String in ["p", "e"]:
		for f: Dictionary in _sq[side]:
			figs.append([side, f])
	figs.sort_custom(func(x: Array, y: Array) -> bool: return x[1].home.y < y[1].home.y)
	var slide := (1.0 - _open) * W * 0.5
	for it: Array in figs:
		var side: String = it[0]
		var f: Dictionary = it[1]
		var u: Dictionary = _d[side]
		var p := _pos(f) + sh + Vector2(-slide if side == "p" else slide, 0)
		var al := _open
		var rot := 0.0
		if not f.alive:
			var k := clampf((now - f.dead_t) / FX.sp(750.0), 0.0, 1.0)
			if k >= 1.0:
				continue
			al *= 1.0 - k * k
			rot = f.knock * k * 1.3
			p += Vector2(f.knock * f.T * 0.5 * (1.0 - pow(1.0 - k, 2.0)), f.T * 0.25 * k)
		var bob := 0.0
		if f.alive:
			bob = absf(sin(now / 70.0 + f.ph)) * f.T * 0.1 if f.run else (sin(now / 420.0 + f.ph) + 1.0) * f.T * 0.02
		var lean: float = f.lean * (0.12 if side == "p" else -0.12)
		if rot != 0.0 or lean != 0.0:
			# Token.paint composes its own (mirror / text) transforms with this one
			Draw.set_xf(ci, Transform2D(rot - lean, p))
			Token.paint(ci, Vector2.ZERO, f.T, side, u.type, u.hero, { "alpha": al, "bob": bob, "flash": f.flash })
			Draw.set_xf(ci, Transform2D.IDENTITY)
		else:
			Token.paint(ci, p, f.T, side, u.type, u.hero, { "alpha": al, "bob": bob, "flash": f.flash })
	# projectiles
	for pr: Dictionary in _projs:
		if now < pr.t0 or pr.trail.is_empty():
			continue
		var k := clampf((now - pr.t0) / pr.dur, 0.0, 1.0)
		var p := _proj_pos(pr, k) + sh
		match pr.kind:
			"arrow":
				var p2 := _proj_pos(pr, maxf(0.0, k - 0.06)) + sh
				var d := (p - p2).normalized() * H * 0.05
				ci.draw_line(p - d, p, SHAFT, maxf(1.5, H * 0.004), true)
				ci.draw_circle(p, H * 0.005, ARROW_TIP)
			"orb":
				for i in pr.trail.size():
					Draw.glow(ci, pr.trail[i] + sh, H * 0.012 * (i + 1) / pr.trail.size() * 2.0, Color(0.6, 0.4, 1.0, 0.35))
				Draw.glow(ci, p, H * 0.04, Color(0.8, 0.65, 1.0, 0.9))
				ci.draw_circle(p, H * 0.012, ORB)
			_:
				ci.draw_circle(p, H * 0.022, STONE)
				ci.draw_circle(p + Vector2(-H * 0.006, -H * 0.006), H * 0.009, STONE_HI)
	# slashes
	for sl: Dictionary in _slashes:
		if now < sl.t0:
			continue
		var k := clampf((now - sl.t0) / sl.dur, 0.0, 1.0)
		var a0 := -2.3 if sl.dir > 0 else -0.85
		var pts := PackedVector2Array()
		for i in 13:
			var ang: float = a0 + (1.6 * sl.dir) * (float(i) / 12.0) * minf(1.0, k * 1.6)
			pts.append(sl.p + sh + Vector2(cos(ang), sin(ang)) * sl.R)
		ci.draw_polyline(pts, Color(1.0, 0.95, 0.8, 1.0 - k), maxf(2.0, H * 0.012 * (1.0 - k)), true)
	# particles
	for pt: Dictionary in _parts:
		var k: float = pt.life / pt.max
		var c: Color = pt.c
		c.a = 1.0 - k
		if pt.smoke:
			Draw.glow(ci, pt.p + sh, pt.s * (1.0 + k * 1.5), Color(c, 0.45 * (1.0 - k)))
		else:
			ci.draw_circle(pt.p + sh, pt.s, c)
	# damage numbers
	for fl: Dictionary in _floats:
		var k := clampf((now - fl.t0) / fl.dur, 0.0, 1.0)
		# one rasterised size (the pop's peak) scaled down: an animated font size made a new glyph cache every frame
		var fs := int(H * (0.11 if fl.big else 0.085) * 1.25)
		var pop := (1.0 + 0.25 * maxf(0.0, 1.0 - k * 6.0)) / 1.25
		Draw.text_c(ci, Style.display_x, fl.p - Vector2(0, H * 0.06 * k), fl.text, fs, Color(fl.col, 1.0 - k * k), maxi(4, fs / 7), Color(0.1, 0.03, 0.02, 1.0 - k * k), pop)
	_paint_hud(ci, W, HH, H)

## letterbox bars: names, side, hp bar + number on top; terrain under each squad at the bottom. U = layout unit (_u)
func _paint_hud(ci: CanvasItem, W: float, H: float, U: float) -> void:
	var ns := int(clampf(minf(W, H) * 0.028, 15.0, 64.0)) # 28 on a 1600x1000 canvas; grows on tall portrait canvases
	var bh := maxf(U * 0.13, ns * 3.6) * _open
	ci.draw_rect(Rect2(0, 0, W, bh), Color(0.03, 0.02, 0.01, 0.94))
	ci.draw_rect(Rect2(0, H - bh, W, bh), Color(0.03, 0.02, 0.01, 0.94))
	ci.draw_line(Vector2(0, bh), Vector2(W, bh), Color(Style.BRONZE, 0.6 * _open), 1.0)
	ci.draw_line(Vector2(0, H - bh), Vector2(W, H - bh), Color(Style.BRONZE, 0.6 * _open), 1.0)
	if _open < 0.6:
		return
	var al := (_open - 0.6) / 0.4
	var pad := maxf(12.0, W * 0.03)
	for side: String in ["p", "e"]:
		var u: Dictionary = _d[side]
		var look := Content.unit_type_look(side, u.type, u.hero)
		var left := side == "p"
		var ax := 0.0 if left else 1.0
		var x := pad if left else W - pad
		var tag := "  ⚔ đánh trước" if _d.att == side else ""
		var fac: Dictionary = Draw.pal().factions[side]
		Draw.text_a(ci, Style.display_x, Vector2(x, bh * 0.2), str(look.get("name", u.type)) + ("" if u.rank == 0 else "  " + "★".repeat(u.rank)), ns, Color(Style.P_NAME if left else fac.ring, al), ax, true)
		Draw.text_a(ci, Style.semi, Vector2(x, bh * 0.2 + ns * 1.25), str(fac.get("short", "")) + tag, int(ns * 0.62), Color(Style.MUTED, al), ax, true)
		# hp bar + number
		var bw := minf(W * 0.3, 360.0)
		var hp: float = _hp[side]
		var bx := x if left else x - bw
		var by := bh * 0.78
		ci.draw_rect(Rect2(bx, by, bw, maxf(6.0, U * 0.012)), Color(0, 0, 0, 0.6 * al))
		var fill := clampf(hp / 100.0, 0.0, 1.0)
		var hc := Style.GOOD if hp > 50 else (Style.GOLD if hp > 25 else Style.BAD)
		ci.draw_rect(Rect2(bx if left else bx + bw * (1.0 - fill), by, bw * fill, maxf(6.0, U * 0.012)), Color(hc, al))
		Draw.text_a(ci, Style.display_x, Vector2(bx + bw + 10 if left else bx - 10, by + maxf(6.0, U * 0.012)), str(int(ceil(hp))), int(ns * 1.1), Color(Style.INK, al), 0.0 if left else 1.0)
		# terrain under the squad (bottom bar)
		var tn: String = Draw.pal().terrain.get(u.tile, {}).get("name", "")
		var dv: int = u.get("def", 0)
		var tl := tn + ("  ·  thủ +%d" % dv if dv > 0 else "")
		Draw.text_a(ci, Style.semi, Vector2(x, H - bh * 0.5 - ns * 0.35), tl, int(ns * 0.7), Color(Style.MUTED, al), ax, true)
	Draw.text_c(ci, Style.display_x, Vector2(W / 2.0, bh * 0.5), "⚔", int(ns * 1.5), Color(Style.GOLD, al), 3, Color(0, 0, 0, al))
	Draw.text_c(ci, Style.semi, Vector2(W / 2.0, H - bh * 0.5), "Bấm để bỏ qua", int(ns * 0.55), Color(Style.MUTED, 0.7 * al))

class Layer:
	extends Control
	var paint: Callable
	func _draw() -> void:
		Draw.xf = Transform2D.IDENTITY
		if paint.is_valid():
			paint.call(self)
