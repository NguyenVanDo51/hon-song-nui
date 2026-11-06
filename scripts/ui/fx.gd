class_name FX
extends Node
## visual effects in tile coordinates: particles, projectiles, rings, numbers, rays, shake, unit lunge / flash, fading corpses.
## Board draws them (draw_under / draw_over / draw_add / draw_top); event playback awaits the async helpers. Port of src/ui/fx.js.

const TURN_MS := 110.0

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
var shake_dur := 1.0
var flash_until := {}
var offsets := {}
var knock := {} # unit id -> { dir, t0, dur, mag }: hit reaction the board turns into a shove + lean
var facing := {} # unit id -> -1 / 1: which way an attacker turned to strike
var aim := {} # unit id -> Vector2 direction of its current strike (3D board turns the figure to it)
var rigs: Array = [] # live code-rigged attacks (Rig), drawn by the 2D board; kept until their sparks fade
var _gen := 0 # bumped by clear(): delayed effects of an older scene drop out
var _last := 0.0

static func now() -> float:
	return Time.get_ticks_usec() / 1000.0

static func sp(ms: float) -> float:
	return ms / speed

func sleep(ms: float) -> void:
	await get_tree().create_timer(sp(ms) / 1000.0).timeout

func clear() -> void:
	_gen += 1
	parts.clear(); projs.clear(); rings.clear(); floats.clear(); rays.clear(); ghosts.clear()
	flash_until.clear(); offsets.clear(); knock.clear(); facing.clear(); aim.clear(); shake_until = 0.0
	rigs.clear()

func _play(sfx: String) -> void:
	if audio:
		audio.play(sfx)

func burst(x: float, y: float, n: int, o: Dictionary) -> void:
	var vmin: float = o.get("vmin", 0.5)
	var vmax: float = o.get("vmax", 2.5)
	var up: float = o.get("up", 0.0)
	var lmin: float = o.get("lmin", 300.0)
	var lmax: float = o.get("lmax", 650.0)
	var smin: float = o.get("smin", 0.03)
	var smax: float = o.get("smax", 0.07)
	var col: Variant = o.color
	var pick := col is Array
	var cols: Array = [col]
	if pick:
		cols = col
	for i in n:
		var a := randf() * TAU
		var v := randf_range(vmin, vmax)
		var px := x + randf_range(-0.1, 0.1)
		var py := y + randf_range(-0.1, 0.1)
		var life_max := randf_range(lmin, lmax)
		var sz := randf_range(smin, smax)
		var hex: String = cols[randi() % cols.size()] if pick else cols[0]
		parts.append({
			"x": px, "y": py, "vx": cos(a) * v, "vy": sin(a) * v - up,
			"g": o.get("g", 3.0), "drag": o.get("drag", 0.9), "life": 0.0, "max": life_max,
			"size": sz,
			"color": Color(hex), "kind": o.get("kind", "spark"),
		})

func ring(x: float, y: float, color: String, dur := 600.0, max_r := 0.9, width := 0.08) -> void:
	rings.append({ "x": x, "y": y, "color": Color(color), "t0": now(), "dur": sp(dur), "maxR": max_r, "width": width })

func float_text(x: float, y: float, text: String, color: String, dur := 1000.0, big := false) -> void:
	floats.append({ "x": x, "y": y, "text": text, "color": Color(color), "t0": now(), "dur": sp(dur), "big": big })

## new envelope = max(running amp left, mag) decaying to the later end: a weaker shake never cuts a stronger one
func shake(mag: float, dur := 260.0) -> void:
	var t := now()
	var left := shake_mag * (shake_until - t) / shake_dur if t < shake_until else 0.0
	shake_mag = maxf(left, mag)
	shake_until = maxf(shake_until, t + maxf(1.0, sp(dur)))
	shake_dur = shake_until - t

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
	var ax: float = a.x
	var ay: float = a.y
	var dx: float = d.x
	var dy: float = d.y
	var dd := absi(int(ax - dx)) + absi(int(ay - dy))
	var shot: String = st.get("shot", "") if dd > 1 else ""
	var heavy: bool = st.get("heavy", false)
	var kill: bool = opts.get("kill", false)
	var dir := Vector2(dx - ax, dy - ay).normalized()
	if absf(dir.x) > 0.01:
		facing[a.id] = signf(dir.x)
	aim[a.id] = dir
	if shot != "":
		# draw: lean back, then loose the shot and spring forward
		await tween(130.0, func(t: float) -> void: offsets[a.id] = -dir * 0.08 * sin(t * PI * 0.5))
		_play("arrow" if shot == "arrow" else ("orb" if shot == "orb" else "rock"))
		tween(180.0, func(t: float) -> void:
			offsets[a.id] = -dir * 0.08 * (1.0 - t) + dir * 0.05 * sin(t * PI)
			if t >= 1.0:
				offsets.erase(a.id))
		await projectile(shot, ax, ay, dx, dy, 620.0 if shot == "rock" else (420.0 if shot == "orb" else 300.0))
	else:
		# wind-up (crouch back), then a fast lunge with a little leap
		await tween(120.0, func(t: float) -> void: offsets[a.id] = -dir * 0.12 * (1.0 - (1.0 - t) * (1.0 - t)))
		var reach := Vector2(dx - ax, dy - ay) * 0.42
		await tween(100.0, func(t: float) -> void: offsets[a.id] = (-dir * 0.12).lerp(reach, t * t) - Vector2(0, sin(t * PI) * 0.14))
		_play("slash")
		_signature(a, d, dir)
	knock[d.id] = { "dir": dir, "t0": now(), "dur": sp(380.0), "mag": 1.4 if (heavy or shot == "rock") else 1.0 }
	_impact(d, amount, heavy or shot == "rock", shot, kill)
	if shot == "":
		var ldx: float = (dx - ax) * 0.42
		var ldy: float = (dy - ay) * 0.42
		var back := func(t: float) -> void:
			offsets[a.id] = Vector2(ldx * (1 - t), ldy * (1 - t))
			if t >= 1.0:
				offsets.erase(a.id)
		tween(170.0, back)
	await sleep(260.0 if opts.get("counter", false) else 320.0)

## code-rigged attack on the 2D board (Rigs.make): the attacker's token is drawn by the rig until its timeline ends;
## the target token takes the rig's knock / lift / squash / flash. opts.on_hit fires once, at the rig's one big HIT
## (or at the end if it never got there). Returns at the end of the timeline; leftover sparks keep fading after.
func rig_attack(board: Control, r: Rig, a: Dictionary, d: Dictionary, amount: int, opts := {}) -> void:
	var f := rig_face(board, a, d)
	var g := _gen
	var a_id: int = a.id
	var a_side: String = a.side
	await turn_to(board, a_id, a_side, f)
	if g != _gen or not is_inside_tree(): # scene cleared mid-turn: no rig on a wiped board, damage still lands
		var cb: Callable = opts.get("on_hit", Callable())
		if cb.is_valid():
			cb.call()
		return
	r.fxh = self
	r.a_id = a.id
	r.d_id = d.id
	r.d_type = d.get("type", "soldier")
	r.amount = amount
	r.kill = opts.get("kill", false)
	r.on_hit = opts.get("on_hit", Callable())
	r.counter = opts.get("counter", false)
	if r.counter:
		r.time_scale = Rigs.COUNTER_SPEED
	var ax: int = a.x
	var ay: int = a.y
	var dx: int = d.x
	var dy: int = d.y
	r.place(board, Vector2i(ax, ay), Vector2i(dx, dy), f)
	aim[a.id] = Vector2(dx - ax, dy - ay).normalized()
	rigs.append(r)
	var t0 := now()
	var adur: float = r.A.dur
	var limit: float = adur * 1.5 + 2500.0 # wall-time bail: the board only ticks rigs while it is visible
	while r.playing and g == _gen and is_inside_tree() and now() - t0 < limit:
		await get_tree().process_frame
	r.playing = false
	r.shown = false
	if not r.hit_done:
		r.hit_done = true
		if r.on_hit.is_valid():
			r.on_hit.call()

## the way a rig attacker faces: toward the target; pure up / down keeps the token's facing
static func rig_face(board: Control, a: Dictionary, d: Dictionary) -> float:
	var dx: int = d.x - a.x
	if dx != 0:
		return signf(dx)
	var b: Board = board
	var a_id: int = a.id
	var a_side: String = a.side
	return b.face_of(a_id, a_side)

## token flips to face f (squash through edge-on) so the rig that replaces it starts with the same facing
func turn_to(board: Control, id: int, side: String, f: float) -> void:
	var b: Board = board
	var f0: float = b.face_of(id, side)
	b.set_face(id, f)
	if f0 == f:
		return
	b.turn(id, f0, f, sp(TURN_MS))
	await sleep(TURN_MS)

func rig_of_attacker(id: int) -> Rig:
	for r: Rig in rigs:
		if r.shown and r.a_id == id:
			return r
	return null

## the target pose a live rig imposes on unit `id` (null = none)
func rig_target_pose(id: int) -> Variant:
	var r := rig_of_target(id)
	if r == null:
		return null
	return r.target_pose()

## the rig acting on unit `id`: a playing one first (a finished one lingers while its number fades)
func rig_of_target(id: int) -> Rig:
	var any: Rig = null
	for r: Rig in rigs:
		if r.d_id == id:
			if r.playing:
				return r
			any = r
	return any

## each troop's own melee strike (drawn at the moment of contact). Ranged shots keep their projectile.
func _signature(a: Dictionary, d: Dictionary, dir: Vector2) -> void:
	var ax: float = a.x
	var ay: float = a.y
	var dx: float = d.x
	var dy: float = d.y
	var ang := atan2(dy - ay, dx - ax)
	var r := func(kind: String, dur: float, extra := {}) -> void:
		var e := { "kind": kind, "x": d.x, "y": d.y, "ax": a.x, "ay": a.y, "ang": ang, "t0": now(), "dur": sp(dur) }
		e.merge(extra, true)
		rays.append(e)
	match a.type:
		"hero": # chém ra gió xoáy: spinning vortex + wind streaks spiralling out
			r.call("whirl", 800.0)
			r.call("slash", 220.0)
			for i in 14:
				var k := float(i) / 14.0 * TAU
				parts.append({ "x": d.x + cos(k) * 0.15, "y": d.y + sin(k) * 0.1, "vx": cos(k + 1.4) * 2.4, "vy": sin(k + 1.4) * 1.4 - 0.8,
					"g": -0.6, "drag": 0.9, "life": -float(i) * 12.0, "max": 520.0, "size": 0.035, "color": Color("#e8f6ff"), "kind": "spark" })
			shake(0.07, 260.0)
		"soldier": # spear thrust: a straight lance of light through the target
			r.call("thrust", 240.0)
		"boat": # paddle-spear from the river: splash + spray
			r.call("thrust", 220.0, { "col": Color("#9fe3ff") })
			burst(dx, dy, 16, { "color": ["#7fd0ff", "#c8f0ff", "#3f9bd6"], "vmin": 1.0, "vmax": 3.0, "up": 1.6, "g": 6.0, "lmin": 300.0, "lmax": 650.0,
				"smin": 0.03, "smax": 0.06 })
			ring(dx, dy, "#9fe3ff", 420.0, 0.8, 0.06)
		"shaman": # gọi hồn: green spirit wisps swirl in and strike
			r.call("spirit", 520.0)
			burst(dx, dy, 12, { "color": ["#9dffb8", "#4fd38a", "#e6fff0"], "kind": "glow", "vmin": 0.4, "vmax": 1.4, "up": 0.8, "g": -0.8, "lmin": 400.0,
				"lmax": 800.0, "smin": 0.04, "smax": 0.08 })
		"drum": # bronze drum boom: sound rings rolling from the drummer to the target
			for i in 3:
				rays.append({ "kind": "boom", "x": d.x, "y": d.y, "ax": a.x, "ay": a.y, "ang": ang, "t0": now() + i * sp(70.0), "dur": sp(380.0) })
		"wolf": # claw rake + bite
			r.call("claw", 300.0)
			burst(dx, dy, 8, { "color": ["#ff6b57", "#ffb199"], "vmin": 0.8, "vmax": 2.2, "lmin": 200.0, "lmax": 420.0, "smin": 0.02, "smax": 0.045 })
		"elephant": # tusk charge + ground stomp: dust ring, cracks, heavy shake
			r.call("stomp", 520.0)
			burst(dx, dy + 0.3, 14, { "color": ["#8a7457", "#b39a76", "#6b5a44"], "kind": "smoke", "vmin": 0.6, "vmax": 1.6, "up": 0.2, "g": -0.2,
				"lmin": 500.0, "lmax": 900.0, "smin": 0.1, "smax": 0.2, "drag": 0.93 })
			ring(dx, dy, "#d8bb8a", 480.0, 1.3, 0.1)
			shake(0.12, 300.0)
		"bird": # dragon fire breath: a cone of flame from the jaws to the target
			r.call("fire", 520.0)
			for i in 26:
				var t := randf()
				var spread := randf_range(-0.35, 0.35)
				var v := dir.rotated(spread) * randf_range(3.0, 5.0)
				var hex: String = ["#ffe27a", "#ff9a3c", "#ff5a2a", "#fff3c4"][i % 4]
				parts.append({ "x": a.x + dir.x * 0.3, "y": a.y + dir.y * 0.3 - 0.15, "vx": v.x, "vy": v.y - 0.3, "g": -1.2, "drag": 0.88,
					"life": -t * 160.0, "max": randf_range(260.0, 420.0), "size": randf_range(0.05, 0.11),
					"color": Color(hex), "kind": "glow" })
			shake(0.08, 280.0)
		"ghost": # cold dark slash
			r.call("slash", 260.0, { "col": Color("#b7a6ff") })
		_:
			r.call("slash", 220.0)

func _impact(d: Dictionary, amount: int, heavy: bool, shot: String, kill: bool) -> void:
	var d_id: int = d.id
	var dx: float = d.x
	var dy: float = d.y
	flash(d_id)
	var big := amount >= 35 or heavy
	_play("heavy" if shot == "rock" or (big and heavy) else "hit")
	var col := ["#c9a2ff", "#8f6bff", "#f0e0ff"] if shot == "orb" else ["#ffd27a", "#ff8a4c", "#fff3c4"]
	@warning_ignore("integer_division")
	burst(dx, dy, mini(26, 8 + amount / 3), { "color": col, "vmin": 1.0, "vmax": 4.0 if big else 2.8, "lmin": 250.0, "lmax": 600.0, "smin": 0.025,
		"smax": 0.06, "g": 4.0 })
	if shot == "rock":
		burst(dx, dy + 0.2, 14, { "color": ["#7b6a55", "#a08b6e", "#5c4d3c"], "kind": "smoke", "vmin": 0.3, "vmax": 1.2, "up": 0.5, "g": -0.3,
			"lmin": 600.0, "lmax": 1100.0, "smin": 0.12, "smax": 0.25, "drag": 0.95 })
		ring(dx, dy, "#e8c27a", 450.0, 1.2, 0.1)
	if big:
		shake(0.16 if shot == "rock" else 0.09, 380.0 if shot == "rock" else 240.0)
	float_text(dx, dy - 0.2, "−" + str(amount), "#ffd166" if kill else "#ff6b57", 1000.0, big or kill)

## catapult wrecks a village: wind-up, rock in a high arc, then rubble smoke + dust ring + shake (no damage number)
func raze(a: Dictionary, x: int, y: int) -> void:
	var ax: float = a.x
	var ay: float = a.y
	var dir := Vector2(x - ax, y - ay).normalized()
	if absf(dir.x) > 0.01:
		facing[a.id] = signf(dir.x)
	aim[a.id] = dir
	await tween(130.0, func(t: float) -> void: offsets[a.id] = -dir * 0.08 * sin(t * PI * 0.5))
	_play("rock")
	tween(180.0, func(t: float) -> void:
		offsets[a.id] = -dir * 0.08 * (1.0 - t)
		if t >= 1.0:
			offsets.erase(a.id))
	await projectile("rock", ax, ay, x, y, 620.0)
	_play("heavy")
	burst(x, y + 0.1, 22, { "color": ["#7b6a55", "#a08b6e", "#5c4d3c", "#9a948a"], "kind": "smoke", "vmin": 0.3, "vmax": 1.4, "up": 0.6, "g": -0.3,
		"lmin": 700.0, "lmax": 1300.0, "smin": 0.14, "smax": 0.3, "drag": 0.95 })
	burst(x, y, 16, { "color": ["#c9b79a", "#8a7560", "#ddd5c4"], "vmin": 1.0, "vmax": 3.2, "lmin": 300.0, "lmax": 650.0, "smin": 0.03, "smax": 0.07,
		"g": 5.0 })
	ring(x, y, "#e8c27a", 500.0, 1.3, 0.1)
	shake(0.18, 400.0)

## a soldier puts a ruined village back up: hammer sparks + warm ring
func repair(x: int, y: int) -> void:
	_play("capture")
	ring(x, y, "#ffe39a", 600.0, 1.1, 0.08)
	burst(x, y, 14, { "color": ["#d2b07a", "#fff3c4", "#a87a4c"], "vmin": 0.6, "vmax": 2.0, "up": 1.0, "g": 2.0, "lmin": 400.0, "lmax": 800.0,
		"smin": 0.03, "smax": 0.06 })

## corpse fades + smoke; u = copy of the dying unit
func death(u: Dictionary) -> void:
	_play("die")
	ghosts.append({ "u": u, "t0": now(), "dur": sp(1000.0) })
	var ux: float = u.x
	var uy: float = u.y
	burst(ux, uy, 16, { "color": ["#3a3430", "#6b625a", "#8d837a"], "kind": "smoke", "vmin": 0.2, "vmax": 1.1, "up": 0.6, "g": -0.5, "lmin": 600.0,
		"lmax": 1200.0, "smin": 0.1, "smax": 0.22, "drag": 0.94 })
	burst(ux, uy, 6, { "color": "#ffb38a" if u.side == "p" else "#8ff0e8", "kind": "glow", "vmin": 0.1, "vmax": 0.4, "up": 1.2, "g": -0.6,
		"lmin": 900.0, "lmax": 1400.0, "smin": 0.04, "smax": 0.07 })

func capture(x: int, y: int, side: String) -> void:
	_play("capture")
	var c: String = Content.theme().factions[side].glow
	ring(x, y, c, 700.0, 1.4, 0.12)
	var g := _gen
	get_tree().create_timer(sp(150.0) / 1000.0).timeout.connect(func() -> void:
		if g == _gen:
			ring(x, y, "#ffe39a", 600.0, 1.0, 0.06))
	burst(x, y, 22, { "color": [c, "#ffe39a", "#fff7d6"], "kind": "glow", "vmin": 0.4, "vmax": 1.8, "up": 1.2, "g": -0.4, "lmin": 700.0, "lmax": 1300.0,
		"smin": 0.03, "smax": 0.06 })

## loud: rays + "★ Lên cấp N"; quiet: small stars + "LvN"
func rank(x: int, y: int, level: int, loud := true) -> void:
	_play("rank")
	if loud:
		rays.append({ "kind": "rays", "x": x, "y": y, "t0": now(), "dur": sp(1100.0) })
	burst(x, y, 14 if loud else 7, { "color": ["#ffe08a", "#fff6d0"], "kind": "star", "vmin": 0.4, "vmax": 1.6, "up": 1.5, "g": 0.8, "lmin": 700.0,
		"lmax": 1200.0, "smin": 0.06, "smax": 0.1 })
	float_text(x, y - 0.55, ("★ Lên cấp %d" % level) if loud else ("Lv%d" % level), "#ffe08a", 1300.0 if loud else 800.0)

func raise_fx(x: int, y: int) -> void:
	_play("raise")
	for i in 26:
		var a := float(i) / 26.0 * PI * 4
		parts.append({ "x": x + cos(a) * 0.5, "y": y + sin(a) * 0.5, "vx": -sin(a) * 1.2, "vy": cos(a) * 1.2 - 0.8, "g": -0.6, "drag": 0.92,
			"life": -i * 18.0, "max": 900.0, "size": 0.05, "color": Color("#b38cff") if i % 2 else Color("#e4d4ff"), "kind": "glow" })
	ring(x, y, "#a37cff", 800.0, 1.1, 0.1)

func heal(x: int, y: int, amount: int) -> void:
	heal_sparkle(x, y)
	float_text(x, y - 0.1, "+" + str(amount), "#9fe08a", 900.0)

## green "+" sparks rising off a healed unit
func heal_sparkle(x: float, y: float) -> void:
	burst(x, y + 0.2, 6, { "color": ["#9fe08a", "#d6ffc4"], "kind": "plus", "vmin": 0.05, "vmax": 0.3, "up": 0.9, "g": -0.2, "lmin": 700.0,
		"lmax": 1000.0, "smin": 0.06, "smax": 0.08 })

func spawn_fx(x: int, y: int) -> void:
	_play("spawn")
	ring(x, y, "#6fd6cf", 700.0, 1.0, 0.1)
	burst(x, y + 0.3, 18, { "color": ["#a8e6ff", "#5fb6d9", "#ffffff"], "vmin": 0.8, "vmax": 2.4, "up": 2.2, "g": 6.0, "lmin": 400.0, "lmax": 800.0,
		"smin": 0.03, "smax": 0.06 })

func buy_fx(x: int, y: int) -> void:
	_play("coin")
	ring(x, y, "#ffd166", 500.0, 0.9, 0.08)
	burst(x, y, 12, { "color": ["#ffd166", "#fff0b3", "#e0a43a"], "kind": "coin", "vmin": 0.8, "vmax": 2.0, "up": 2.0, "g": 6.0, "lmin": 500.0,
		"lmax": 800.0, "smin": 0.05, "smax": 0.07 })

## dust kicked up at a walker's feet: a low puff that spreads sideways and fades
func dust(x: float, y: float) -> void:
	for i in 7:
		var side := -1.0 if i % 2 else 1.0
		var hex: String = ["#cdb98f", "#b39f76", "#e0d2ae"][i % 3]
		parts.append({ "x": x + randf_range(-0.12, 0.12), "y": y + 0.3 + randf_range(-0.03, 0.03),
			"vx": side * randf_range(0.25, 0.7), "vy": -randf_range(0.05, 0.3), "g": -0.15, "drag": 0.9, "life": 0.0,
			"max": randf_range(380.0, 650.0), "size": randf_range(0.07, 0.12), "color": Color(hex), "kind": "smoke" })

# ---------- update + draw ----------
func update(t: float) -> void:
	var dt := minf(0.05, (t - _last) / 1000.0) * speed
	_last = t
	if not rigs.is_empty():
		for r: Rig in rigs:
			r.tick(dt * 1000.0)
		rigs = rigs.filter(func(r: Rig) -> bool: return not r.done())
	for p: Dictionary in parts:
		p.life += dt * 1000.0
		if p.life < 0:
			continue
		var drag: float = p.drag
		var dr := pow(drag, dt * 60.0)
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
		var k := _proj_k(pr, t)
		var trail: Array = pr.trail
		trail.append(_proj_pos(pr, k))
		if trail.size() > 8:
			trail.pop_front()
		if k >= 1.0:
			pr.hit = true
	projs = projs.filter(func(p: Dictionary) -> bool: return not p.hit)

static func _proj_k(pr: Dictionary, t: float) -> float:
	var t0: float = pr.t0
	var dur: float = pr.dur
	return minf(1.0, (t - t0) / dur)

static func _proj_pos(pr: Dictionary, k: float) -> Vector2:
	var fx: float = pr.fx
	var fy: float = pr.fy
	var tx: float = pr.tx
	var ty: float = pr.ty
	var arc: float = pr.arc
	return Vector2(fx + (tx - fx) * k, fy + (ty - fy) * k - sin(k * PI) * arc)

static func _px(e: Dictionary, T: float, ox := 0.5, oy := 0.5) -> Vector2:
	var x: float = e.x
	var y: float = e.y
	return Vector2((x + ox) * T, (y + oy) * T)

static func _from_px(e: Dictionary, T: float, oy: float) -> Vector2:
	var x: float = e.ax
	var y: float = e.ay
	return Vector2((x + 0.5) * T, (y + oy) * T)

## shake offset in tiles
func shake_offset(t: float) -> Vector2:
	if t > shake_until:
		shake_mag = 0.0
		return Vector2.ZERO
	var m := shake_mag * ((shake_until - t) / shake_dur)
	return Vector2(randf_range(-m, m), randf_range(-m, m))

func draw_under(ci: CanvasItem, T: float, t: float) -> void:
	for r: Dictionary in rings:
		var k: float = (t - r.t0) / r.dur
		var col: Color = r.color
		col.a = (1.0 - k) * 0.9
		var s: float = r.maxR * T * (0.2 + k * 0.8)
		var width: float = r.width
		Draw.ellipse_line(ci, _px(r, T, 0.5, 0.62), s, s * 0.5, col, maxf(1.0, width * T * (1.0 - k * 0.6)))

## normal-blend effects: arrows, rocks, smoke, stars, pluses, coins, hero whirlwind, drum sound rings
func draw_over(ci: CanvasItem, T: float, t: float) -> void:
	for r: Dictionary in rays:
		var k: float = (t - r.t0) / r.dur
		if k < 0.0:
			continue
		var c := _px(r, T)
		if r.kind == "whirl": # hero: tornado of wind arcs, spinning up and widening, rising off the target
			var spin := k * 10.0
			var al := sin(minf(1.0, k * 1.6) * PI * 0.5) * (1.0 - k * k)
			for i in 5:
				var lift := float(i) * 0.12
				var rr := T * (0.2 + 0.08 * i) * (0.75 + k * 0.6)
				var cc := c + Vector2(0, T * 0.2 - lift * T - k * T * 0.2)
				var a0 := spin + i * 1.3
				var w := maxf(1.5, T * (0.075 - 0.01 * i))
				ci.draw_arc(cc, rr, a0, a0 + 2.6, 18, Color(0.32, 0.55, 0.82, 0.55 * al), w + 2.0, true)
				ci.draw_arc(cc, rr, a0, a0 + 2.6, 18, Color(0.92, 0.98, 1.0, 0.95 * al), w, true)
				ci.draw_arc(cc, rr * 0.78, a0 + PI, a0 + PI + 1.7, 14, Color(0.75, 0.9, 1.0, 0.7 * al), maxf(1.0, T * 0.03), true)
		elif r.kind == "boom": # drum: a bronze sound ring rolling toward the target
			var from2 := _from_px(r, T, 0.5)
			var p2 := from2.lerp(c, k)
			var w2 := maxf(1.5, T * 0.07 * (1.0 - k * 0.6))
			var ang2: float = r.ang
			ci.draw_arc(p2, T * (0.2 + k * 0.32), ang2 - 1.1, ang2 + 1.1, 16, Color(0.35, 0.2, 0.05, 0.6 * (1.0 - k)), w2 + 2.0, true)
			ci.draw_arc(p2, T * (0.2 + k * 0.32), ang2 - 1.1, ang2 + 1.1, 16, Color(1.0, 0.82, 0.38, 0.95 * (1.0 - k)), w2, true)
	for pr: Dictionary in projs:
		var k := _proj_k(pr, t)
		var p := _proj_pos(pr, k)
		var q := _proj_pos(pr, maxf(0.0, k - 0.05))
		var X := (p + Vector2(0.5, 0.5)) * T
		if pr.kind == "arrow":
			var xf := Transform2D((p - q).angle(), X)
			ci.draw_line(xf * Vector2(-T * 0.3, 0), xf * Vector2(T * 0.12, 0), Draw.col("#3b2a1a"), maxf(1.5, T * 0.04), true)
			ci.draw_colored_polygon(PackedVector2Array([xf * Vector2(T * 0.2, 0), xf * Vector2(T * 0.1, -T * 0.05), xf * Vector2(T * 0.1, T * 0.05)]),
				Draw.col("#d8d0c0"))
			ci.draw_colored_polygon(PackedVector2Array([xf * Vector2(-T * 0.3, -T * 0.04), xf * Vector2(-T * 0.22, -T * 0.04),
				xf * Vector2(-T * 0.22, T * 0.04), xf * Vector2(-T * 0.3, T * 0.04)]), Draw.col("#c2412f"))
		elif pr.kind == "rock":
			var gfx: float = pr.fx
			var gfy: float = pr.fy
			var gtx: float = pr.tx
			var gty: float = pr.ty
			var g := Vector2((gfx + (gtx - gfx) * k + 0.5) * T, (gfy + (gty - gfy) * k + 0.75) * T)
			Draw.ellipse(ci, g, T * 0.14, T * 0.06, Color(0, 0, 0, 0.33))
			ci.draw_circle(X, T * 0.13, Draw.col("#8a7a64"))
			ci.draw_circle(X + Vector2(-T * 0.04, -T * 0.04).rotated(k * 8), T * 0.05, Draw.col("#b3a285"))
	for p: Dictionary in parts:
		if p.life < 0 or p.kind in ["glow", "spark"]:
			continue
		var k: float = p.life / p.max
		var X := _px(p, T)
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
			var life: float = p.life
			Draw.ellipse(ci, X, R, maxf(0.5, R * absf(cos(life / 80.0))), col, 0.0, 16)
	for r: Rig in rigs:
		r.draw_layer(ci, "front")

## additive effects (canvas 'lighter'): rank rays, slash arcs, orbs, glows, sparks
func draw_add(ci: CanvasItem, T: float, t: float) -> void:
	for r: Dictionary in rays:
		var k: float = (t - r.t0) / r.dur
		if k < 0.0:
			continue
		var c := _px(r, T)
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
			var c1: Color = r.get("col", Color(1, 0.957, 0.839))
			ci.draw_arc(c, T * 0.42, a0, a0 + 1.3, 12, Color(c1, 1.0 - k), T * 0.08 * (1.0 - k) + 1.0, true)
			var a1 := -2.1 + k * 1.2 + rot
			ci.draw_arc(c, T * 0.34, a1, a1 + 1.1, 10, Color(c1.lerp(Color(1, 0.69, 0.4), 0.6), 1.0 - k), T * 0.03, true)
		elif r.kind == "thrust": # spear: a narrow lance from the attacker through the target
			var from := _from_px(r, T, 0.5)
			var dirv := (c - from).normalized()
			var tip := c + dirv * T * (0.15 + k * 0.35)
			var tail := from.lerp(c, 0.35 + k * 0.5)
			var side := Vector2(-dirv.y, dirv.x) * T * 0.05 * (1.0 - k)
			var col: Color = r.get("col", Color(1, 0.96, 0.82))
			ci.draw_polygon(PackedVector2Array([tail + side, tip, tail - side]), PackedColorArray([Color(col, 0.0), Color(col, 1.0 - k), Color(col, 0.0)]))
		elif r.kind == "spirit": # shaman: three green wisps spiralling in onto the target
			for i in 3:
				var a := k * 7.0 + i * TAU / 3.0
				var rad := T * 0.55 * (1.0 - k)
				var p := c + Vector2(cos(a), sin(a) * 0.6) * rad + Vector2(0, -T * 0.1)
				Draw.radial(ci, p, T * 0.14, [[0.0, Color(0.9, 1.0, 0.92, 1.0 - k * 0.5)], [1.0, Color(0.3, 0.85, 0.55, 0.0)]], 14)
		elif r.kind == "claw": # wolf: three parallel scratches torn across the target
			var ang: float = r.ang
			var dirc := Vector2(cos(ang + 0.6), sin(ang + 0.6))
			var perp := Vector2(-dirc.y, dirc.x)
			var grow := minf(1.0, k * 3.0)
			for i in 3:
				var o := perp * T * (i - 1) * 0.13
				var p0 := c + o - dirc * T * 0.32
				ci.draw_line(p0, p0 + dirc * T * 0.64 * grow, Color(1.0, 0.35, 0.3, 1.0 - k), maxf(1.0, T * 0.05 * (1.0 - k * 0.7)), true)
		elif r.kind == "stomp": # elephant: ground cracks radiating from the target
			var al2 := 1.0 - k
			for i in 6:
				var a2 := float(i) / 6.0 * TAU + 0.3
				var crack_len := T * 0.5 * minf(1.0, k * 2.5)
				var mid := c + Vector2(cos(a2), sin(a2) * 0.5) * crack_len * 0.5 + Vector2(cos(a2 + 1.2), sin(a2 + 1.2)) * T * 0.04
				var end := c + Vector2(cos(a2), sin(a2) * 0.5) * crack_len
				ci.draw_polyline(PackedVector2Array([c + Vector2(0, T * 0.25), mid + Vector2(0, T * 0.25), end + Vector2(0, T * 0.25)]),
					Color(1.0, 0.85, 0.55, 0.7 * al2), maxf(1.0, T * 0.03), true)
		elif r.kind == "fire": # dragon: a hot glow along the breath line
			var from3 := _from_px(r, T, 0.35)
			var al3 := sin(k * PI)
			for i in 5:
				var q := from3.lerp(c, float(i + 1) / 5.0)
				Draw.radial(ci, q, T * (0.12 + 0.06 * i) * al3, [[0.0, Color(1, 0.95, 0.7, 0.8 * al3)], [1.0, Color(1, 0.35, 0.1, 0.0)]], 16)
	for pr: Dictionary in projs:
		if pr.kind != "orb":
			continue
		var k := _proj_k(pr, t)
		var X := (_proj_pos(pr, k) + Vector2(0.5, 0.5)) * T
		var trail: Array = pr.trail
		var n := trail.size()
		for i in n:
			var tp: Vector2 = trail[i]
			ci.draw_circle((tp + Vector2(0.5, 0.5)) * T, maxf(0.5, T * 0.08 * float(i) / n), Color(0.62, 0.48, 1.0, float(i) / n * 0.5))
		Draw.radial(ci, X, T * 0.22, [[0.0, Color.WHITE], [0.35, Draw.col("#c9a2ff")], [1.0, Color(0.42, 0.24, 1.0, 0.0)]], 20)
	for p: Dictionary in parts:
		if p.life < 0 or not (p.kind in ["glow", "spark"]):
			continue
		var k: float = p.life / p.max
		var col: Color = p.color
		col.a = 1.0 - k
		var psize: float = p.size
		ci.draw_circle(_px(p, T), maxf(0.5, psize * T * (1.4 if p.kind == "glow" else 1.0 - k * 0.5)), col)

## floating numbers / labels
func draw_top(ci: CanvasItem, T: float, t: float) -> void:
	for r: Rig in rigs:
		r.draw_flash(ci, Rect2(Vector2.ZERO, (ci as Control).size))
	for f: Dictionary in floats:
		var k: float = (t - f.t0) / f.dur
		var pop := 0.6 + (k / 0.15) * 0.7 if k < 0.15 else 1.3 - minf(0.3, (k - 0.15) * 1.5)
		var col: Color = f.color
		col.a = 1.0 - (k - 0.7) / 0.3 if k > 0.7 else 1.0
		# rasterised once at the pop's peak (1.3) and scaled: an animated font size leaked a glyph cache per size
		var size := maxi(6, roundi(T * (0.46 if f.big else 0.34) * 1.3))
		var fx: float = f.x
		var fy: float = f.y
		var text: String = f.text
		var pos := Vector2((fx + 0.5) * T, (fy + 0.3) * T - k * T * 0.55)
		Draw.text_c(ci, Style.xbold, pos, text, size, col, maxi(3, int(T * 0.08 * 1.3)), Color(0.1, 0.047, 0.024, col.a), pop / 1.3)
