class_name Rig
extends RefCounted
## one live attack of a code-rigged unit: pose from the exported tracks, springs, the target's reaction (knock, squash,
## lift, spin, flash), hit-stop, flash and the VFX api the spec events call. GDScript port of engine.js boot()
## (svg-attack-anim skill) minus the review page. Spec functions come from a RigSpec (scripts/ui/rig/specs/<unit>.gd).
## Board draws it: draw_char() in the unit y-order instead of the token, draw_layer("back"/"mid") around the target
## token, draw_layer("front") over the units, draw_flash() on top. FX.update() ticks it. See docs/rig_port.md.

## shared impact for every unit (docs/anim_demo/SHARED.md)
const HIT := { "stop": 90, "amp": 9, "kx": 420, "debris": "spark", "n": 8, "sparkColor": "#ffe08a", "cut": true, "cutAng": -24 }
const HIT_SMALL := { "small": true, "stop": 45, "amp": 4, "kx": 0, "debris": "spark", "n": 3, "sparkColor": "#ffe08a", "cut": false }

var data: RigData
var spec: RigSpec
var A: Dictionary # the attack
var swap := false # enemy colours on shared art
var part_id := "" # texture cache id prefix

# ---------- clock / attack ----------
var t := 0.0 # attack time, ms (engine act.t)
var clock := 0.0
var playing := true # engine act != null
var shown := true # character drawn (false once the token is back)
var time_scale := 1.0 # extra speed on top of FX.speed (counters)
var counter := false # this rig is the defender's counter-attack
var hitstop := 0.0
var flash_t := 0.0
var flash_dur := 1.0
var flash_col := Color.WHITE
var pose := { }
var fxs: Array = [] # RigFx.Fx objects
var tgt := { "ox": 0.0, "vx": 0.0, "oy": 0.0, "vy": 0.0, "sy": 1.0, "svy": 0.0, "flash": 0.0, "face": 1.0, "spin": 0.0, "lift": null, "land": null }

# ---------- game wiring ----------
var cam := RigCam.new()
var board: BoardBase # T, screen scale
var fxh: FX # board shake + sounds
var a_tile := Vector2i.ZERO
var d_tile := Vector2i.ZERO
var a_id := -1
var d_id := -1
var a_type := ""
var d_type := ""
var heavy := false
var amount := 0 # real damage from the game event (shown on the one non-small HIT)
var kill := false
var on_hit := Callable() # called once at that HIT (game drops the hp bar)
var hit_done := false
var hit_t := -1.0 # attack time of THE hit (-1 = never reached; FX.rig_attack then applies the damage at the end)

var _ev: Array = [] # [[t, Callable(rig)]]
var _fired := 0
var _prev_x := 0.0
var _sprs := { } # name -> [angle, velocity]
var _cam_T := -1.0
var _parts := { } # part -> [raster cache id, svg source]: built once, not per part per frame
var _parts_for := ""
var _smear_at := { } # smear sample index on the step grid -> [tip, base (character space), root x, root y]

static func thin(v: float) -> float:
	return 0.08 * (signf(v) if v != 0.0 else 1.0) if absf(v) < 0.08 else v

## spec: data name (assets/units/rig/<spec>.json), script: RigSpec subclass, attack "" = first
func _init(p_data: RigData, p_spec: RigSpec, attack := "") -> void:
	data = p_data
	spec = p_spec
	spec.data = data
	A = data.attacks[attack if attack != "" else data.attack_ids[0]]
	for k: String in data.springs:
		_sprs[k] = [0.0, 0.0]
	pose = pose_at(0.0)

## attacker / defender tiles + who they are; f = the art's facing (+1 right, -1 left)
func place(p_board: Control, a_xy: Vector2i, d_xy: Vector2i, f: float) -> void:
	board = p_board
	a_tile = a_xy
	d_tile = d_xy
	cam.f = f
	_ev = spec.events(self)
	_ev.sort_custom(
		func(p: Array, q: Array) -> bool:
			return p[0] < q[0],
	)
	_cam_T = -1.0
	_update_cam()

## px per art unit of a standing token (Token._standee: the 256 SVG fills Token.fig_h)
static func token_k(type: String, T: float) -> float:
	return Token.fig_h(type, T) / 256.0

func _update_cam() -> void:
	var T: float = board.T if board else 64.0
	if is_equal_approx(T, _cam_T):
		return
	_cam_T = T
	var c := cam
	c.T = T
	c.CX = data.cx
	c.FEET = data.feet
	c.ca = token_k(a_type, T)
	c.cd = token_k(d_type, T)
	var dv := Vector2(d_tile - a_tile)
	var dist := maxf(1.0, dv.length())
	c.u = dv.normalized() if dv.length() > 0.0 else Vector2(c.f, 0.0)
	c.TX = 256.0 * dist
	c.xt = c.TX + 128.0
	c.xhf = c.CX + 64.0
	c.xt = c.TX + 128.0
	c.xtf = c.xt - 64.0
	# feet: the token's SVG square has its bottom edge at tile centre + Token.FOOT tiles (Token._standee)
	var ac := (Vector2(a_tile) + Vector2(0.5, 0.5)) * T
	var dc := (Vector2(d_tile) + Vector2(0.5, 0.5)) * T
	c.Fa = ac + Vector2(c.f * (c.CX - 128.0) * c.ca, T * Token.FOOT + (c.FEET - 256.0) * c.ca)
	c.Fd = dc + Vector2(0.0, T * Token.FOOT + (c.FEET - 256.0) * c.cd)

# ---------- pose ----------
func base_pose() -> Dictionary:
	return data.base.duplicate()

func pose_at(at: float) -> Dictionary:
	var p := base_pose()
	var tracks: Dictionary = A.tr
	for k: String in tracks:
		var keys: Array = tracks[k]
		p[k] = RigData.sample(keys, at)
	var aid: String = A.id
	spec.channels(p, at, aid)
	var spin: float = p.spin
	p.face *= cos(spin)
	return p

func rest_pose(breath := 0.0) -> Dictionary:
	var p := base_pose()
	spec.idle(p, breath, clock)
	return p

## bone matrices in character space (root translation excluded: RigCam.root places it)
func bones_of(p: Dictionary) -> Dictionary:
	var R := { }
	var sy: float = p.sy
	var face: float = p.face
	var sx: float = (1.0 + (1.0 - sy) * 0.8) * thin(face)
	R.root = _about(Transform2D.IDENTITY, Vector2(data.cx, data.feet), Transform2D(Vector2(sx, 0.0), Vector2(0.0, sy), Vector2.ZERO))
	for b: Dictionary in data.bones:
		var m: Transform2D = R[b.parent]
		var pv: Vector2 = b.pivot
		if b.has("tx") or b.has("ty"):
			var tx: float = p.get(b.get("tx", ""), 0.0)
			var ty: float = p.get(b.get("ty", ""), 0.0)
			m = m * Transform2D(0.0, Vector2(tx, ty))
		if b.has("ch"):
			var deg: float = p[b.ch]
			m = _about(m, pv, Transform2D(deg_to_rad(deg), Vector2.ZERO))
		if b.has("sc"):
			var s: float = 1.0 + p[b.sc]
			m = _about(m, pv, Transform2D(Vector2(s, 0.0), Vector2(0.0, s), Vector2.ZERO))
		if b.get("stretch", false):
			var st: float = p[b.ch]
			m = _about(m, pv, Transform2D(Vector2(1.0 + absf(st) / 160.0, 0.0), Vector2(0.0, 1.0), Vector2.ZERO))
		R[b.name] = m
	return R

static func _about(m: Transform2D, pv: Vector2, op: Transform2D) -> Transform2D:
	return m * Transform2D(0.0, pv) * op * Transform2D(0.0, -pv)

## engine point(): world coords of a named point for the current pose (root translation = pose x / y)
func point(name: String) -> Vector2:
	var q: Array = data.points[name]
	var m: Transform2D = bones_of(pose)[q[0]]
	var v: Vector2 = q[1]
	var px: float = pose.x
	var py: float = pose.y
	return m * v + Vector2(px, py)

## the same point in board px, exactly where it is drawn
func point_px(name: String, p: Variant = null) -> Vector2:
	var pp: Dictionary = pose if p == null else p
	var q: Array = data.points[name]
	_update_cam()
	var m: Transform2D = bones_of(pp)[q[0]]
	var v: Vector2 = q[1]
	var px: float = pp.x
	var py: float = pp.y
	return cam.char_xf(px, py) * (m * v)

func hero() -> Dictionary:
	return { "x": data.cx + pose.x, "y": data.target_cy + pose.y, "feet": data.feet }

func target() -> Dictionary:
	return { "x": cam.xt + tgt.ox, "y": data.target_cy + tgt.oy, "front": cam.TX + data.target_front, "feet": data.feet, "tileX": cam.TX }

# ---------- update (engine update + frame hit-stop) ----------
## rdt: ms of game time this frame (already x FX.speed)
func tick(rdt: float) -> void:
	rdt *= time_scale
	var dt := rdt
	if hitstop > 0.0:
		hitstop -= rdt
		dt = 0.0
	update(dt, rdt)

func update(dt: float, rdt: float) -> void:
	_update_cam()
	clock += dt
	if flash_t > 0.0:
		flash_t = maxf(0.0, flash_t - rdt)
	if playing:
		t += dt
		while _fired < _ev.size() and _ev[_fired][0] <= t:
			var cb: Callable = _ev[_fired][1]
			_fired += 1
			cb.call(self)
		if t >= A.dur:
			playing = false
	var dur: float = A.dur
	var p := pose_at(minf(t, dur))
	if dt > 0.0:
		var s := dt / 1000.0
		var vx: float = (p.x - _prev_x) / s
		_prev_x = p.x
		for k: String in _sprs:
			var sp: Dictionary = data.springs[k]
			var sk: float = sp.k
			var sc: float = sp.c
			var o: Array = _sprs[k]
			var aim := spec.drive(k, p, vx, { "idle": 0.0 if playing else 1.0, "clock": clock })
			var h := s / 4.0
			for i in 4:
				o[1] += (sk * (aim - o[0]) - sc * o[1]) * h
				o[0] += o[1] * h
		_upd_target(s)
		var cur := fxs
		fxs = []
		var keep := []
		for f: RigFx.Fx in cur:
			if f.upd(s, dt):
				keep.append(f)
		fxs = keep + fxs
	for k: String in _sprs:
		p[k] = _sprs[k][0]
	pose = p

## engine seek(): replay from 0 in 8 ms steps (hit-stop skipped), for contact sheets
func seek(at: float) -> void:
	t = 0.0
	clock = 0.0
	_fired = 0
	playing = true
	fxs.clear()
	hitstop = 0.0
	flash_t = 0.0
	hit_done = false
	_prev_x = 0.0
	for k: String in _sprs:
		_sprs[k] = [0.0, 0.0]
	tgt = { "ox": 0.0, "vx": 0.0, "oy": 0.0, "vy": 0.0, "sy": 1.0, "svy": 0.0, "flash": 0.0, "face": 1.0, "spin": 0.0, "lift": null, "land": null }
	while playing and t < at:
		update(minf(8.0, at - t), 8.0)
	if not playing:
		pose = pose_at(at)

func _upd_target(s: float) -> void:
	var e := tgt
	var fl: float = e.flash
	e.flash = maxf(0.0, fl - s * 1000.0 / 150.0)
	e.vx += (-120.0 * e.ox - 13.0 * e.vx) * s
	e.ox += e.vx * s
	e.svy += (-260.0 * (e.sy - 1.0) - 14.0 * e.svy) * s
	e.sy += e.svy * s
	if e.lift != null:
		var l: Dictionary = e.lift
		l.t += s * 1000.0
		var lt: float = l.t
		var lms: float = l.ms
		e.oy = -l.h * RigData.ease_i(1, clampf(lt / lms, 0.0, 1.0)) + sin(clock / 90.0) * 4.0
		e.spin += s * 15.0
		var spin: float = e.spin
		e.face = cos(spin)
		e.vy = 0.0
	elif e.oy < 0.0 or e.vy != 0.0:
		e.vy += 2600.0 * s
		e.oy += e.vy * s
		var oy: float = e.oy
		e.spin += s * 15.0 * clampf(-oy / 95.0, 0.0, 1.0)
		var spin: float = e.spin
		e.face = cos(spin)
		if e.oy >= 0.0:
			var hard: bool = e.vy > 500.0
			e.oy = 0.0
			e.vy = 0.0
			e.face = 1.0
			e.spin = 0.0
			if hard and e.land != null:
				var land: Dictionary = e.land
				e.land = null
				hit(land)
				dust(cam.xt, data.feet, 10, 0.0)
	else:
		e.face += (1.0 - e.face) * minf(1.0, s * 12.0)

## the target token's pose for Board._pose: shift (board px), lift (px up), squash, facing multiplier, flash 0..1
func target_pose() -> Dictionary:
	_update_cam()
	var e := tgt
	var face: float = e.face
	return {
		"shift": cam.u * (e.ox * cam.cd),
		"lift": -e.oy * cam.cd,
		"sy": e.sy,
		"sx": (1.0 + (1.0 - e.sy) * 0.8),
		"face": thin(face),
		"flash": e.flash,
	}

# ---------- api (engine `api`) ----------
func add(o: Variant) -> Variant:
	if o is Dictionary:
		var d: Dictionary = o
		o = RigFx.Custom.new(d)
	fxs.append(o)
	return o

func sound(name: String) -> void:
	if fxh:
		fxh._play(name)

func shake(amp: float, ms := 260.0) -> void:
	if fxh and board:
		_update_cam()
		fxh.shake(amp * cam.ca / cam.T, ms / time_scale)

func stop(ms: float) -> void:
	hitstop = maxf(hitstop, ms)

func flash(color: Variant = "#ffffff", ms := 120.0) -> void:
	flash_col = RigFx.col(color)
	flash_t = ms
	flash_dur = ms

## the one place damage lands. small = a tick (no number in game). The first non-small hit is THE hit: it shows the
## real amount from the game event and calls on_hit (hp bar drops); later non-small hits show no number.
func hit(o := { }) -> void:
	var small: bool = o.get("small", false)
	var c := target()
	var cx: float = c.x
	var cy: float = c.y
	var stop_ms: float = o.get("stop", 40.0 if small else 90.0)
	stop(stop_ms)
	var amp: float = o.get("amp", 5.0 if small else 11.0)
	shake(amp, 140.0 if small else 280.0)
	tgt.flash = 1.0
	var kx: float = o.get("kx", 0.0 if small else 520.0)
	tgt.vx += kx
	tgt.sy = 0.92 if small else 0.82
	if not small and not hit_done:
		hit_done = true
		hit_t = t
		number(cx + randf_range(-16.0, 16.0), cy - 70.0, "−%d" % amount, false)
		sound("heavy" if heavy or amount >= 35 else "hit")
		if on_hit.is_valid():
			on_hit.call()
	elif small:
		sound("hit")
	burst(cx + randf_range(-10.0, 10.0), cy + randf_range(-10.0, 10.0), 0.55 if small else 1.0)
	if o.get("cut", not small):
		var ang: float = o.get("cutAng", -24.0)
		cut(cx, cy, ang)
	var deb: String = o.get("debris", "leaf")
	var n: int = o.get("n", 3 if small else 9)
	if deb == "leaf":
		leaves(cx, cy, n, randf_range(-300.0, 300.0) if small else 650.0)
	elif deb == "spark":
		var sc: String = o.get("sparkColor", "#ffe08a")
		sparks(cx, cy, n, sc)
	elif deb == "dust":
		dust(cx, data.feet, n, 1.0)

func dust(x: float, y: float, n := 6, dir := 0.0) -> void:
	for i in n:
		_particle(
			{
				"k": "dust",
				"x": x + randf_range(-30, 30),
				"y": y - randf_range(0, 8),
				"vx": (dir if dir != 0.0 else randf_range(-1, 1)) * randf_range(60, 220),
				"vy": randf_range(-90, -20),
				"life": randf_range(380, 560),
				"r": randf_range(9, 15),
			}
		)

func leaves(x: float, y: float, n := 8, sp := 600.0, color := "#7fb24e") -> void:
	for i in n:
		_particle(
			{
				"k": "leaf",
				"x": x + randf_range(-20, 20),
				"y": y + randf_range(-40, 40),
				"vx": randf_range(0.3, 1.0) * sp,
				"vy": randf_range(-380, 60),
				"rot": randf_range(0, 6),
				"vr": randf_range(-14, 14),
				"life": randf_range(600, 1000),
				"color": Color(color),
			}
		)

func sparks(x: float, y: float, n := 8, color := "#ffe08a") -> void:
	for i in n:
		var a := randf_range(0, TAU)
		var v := randf_range(250, 600)
		_particle({ "k": "spark", "x": x, "y": y, "vx": cos(a) * v, "vy": sin(a) * v, "life": randf_range(180, 320), "color": Color(color) })

func _particle(q: Dictionary) -> void:
	fxs.append(RigFx.Particle.new(self, q))

func number(x: float, y: float, text: String, small := false) -> void:
	fxs.append(RigFx.Number.new(self, x, y, text, small))

func burst(x: float, y: float, s := 1.0) -> void:
	fxs.append(RigFx.Burst.new(self, x, y, s))

func cut(x: float, y: float, ang := -24.0) -> void:
	fxs.append(RigFx.Cut.new(self, x, y, ang))

func gleam(pt: String, ms := 170.0) -> void:
	fxs.append(RigFx.Gleam.new(self, pt, ms))

func wave(o: Dictionary) -> Object:
	return add(RigFx.Wave.new(self, o))

func projectile(o: Dictionary) -> Object:
	return add(RigFx.Projectile.new(self, o))

func tornado(o := { }) -> Object:
	return add(RigFx.Tornado.new(self, o))

func ring(o := { }) -> Object:
	return add(RigFx.Ring.new(self, o))

func shockwave(x: float, y: float, o := { }) -> Object:
	return add(RigFx.Shock.new(self, x, y, o))

## shared HIT / HIT_SMALL merged with overrides (engine Object.assign({}, HIT, {...}))
static func with(base: Dictionary, o := { }) -> Dictionary:
	var d := base.duplicate()
	d.merge(o, true)
	return d

# ---------- draw ----------
func _ctx(ci: CanvasItem) -> RigCtx:
	_update_cam()
	return RigCtx.new(ci, cam)

## the character (shadow, parts in draw order with alpha channels, smear) where the token would stand
func draw_char(ci: CanvasItem) -> void:
	if not shown:
		return
	_update_cam()
	var p := pose
	var T := cam.T
	# ground shadow like Token._standee, under the root, smaller when the figure is in the air
	var px: float = p.x
	var py: float = p.y
	var g := cam.root(px, 0.0)
	var base := g - Vector2(0.0, (data.feet - 256.0) * cam.ca)
	var ls := clampf(1.0 + py / 220.0, 0.45, 1.0)
	ci.draw_set_transform_matrix(Draw.xf)
	Token.draw_shadow(ci, base, T, 1.0, ls)
	if a_type == "hero":
		Token.halo(ci, base - Vector2(0.0, T * Token.FOOT), T, Token.FOE_GLOW if swap or data.name.ends_with("_e") else Token.HERO_GLOW)
	if playing:
		spec.draw_char_under(_ctx(ci), cam, self)
		ci.draw_set_transform_matrix(Draw.xf)
	var R := bones_of(p)
	var X := cam.char_xf(px, py)
	var tex_px := 256.0 * cam.ca * Baked.screen_scale(ci)
	var list: Array = data.draw
	if data.hooks.get("order", false):
		list = spec.order(p, list.duplicate())
	for e: Array in list:
		var al := 1.0
		if e[2] != "":
			var av: float = p.get(e[2], 1.0)
			al = clampf(av, 0.0, 1.0)
		if al <= 0.0:
			continue
		var part: String = e[0]
		var pc: Array = _part_src(part)
		var rid: String = pc[0]
		var src: Callable = pc[1]
		var tex := Token.raster_svg(rid, src, tex_px)
		if tex == null:
			continue
		var bm: Transform2D = R[e[1]]
		ci.draw_set_transform_matrix(Draw.xf * X * bm)
		ci.draw_texture_rect(tex, Rect2(0, 0, 256, 256), false, Color(1, 1, 1, al))
	ci.draw_set_transform_matrix(Draw.xf)
	if A.get("smear") != null and playing:
		_draw_smear(ci)
	spec.draw_char_extra(_ctx(ci), cam, self)

func _part_src(part: String) -> Array:
	var f := part_id + str(swap)
	if f != _parts_for:
		_parts.clear()
		_parts_for = f
	if not _parts.has(part):
		_parts[part] = ["%s|%s|%s" % [part_id, part, swap], data.part_svg.bind(part, swap)]
	return _parts[part]

## blade tip / base in character space + root offset at attack time `at` (pose_at is a pure function of the time)
func _smear_pt(at: float, qt: Array, qb: Array) -> Array:
	var pp := pose_at(at)
	var R := bones_of(pp)
	var px: float = pp.x
	var py: float = pp.y
	return [R[qt[0]] * qt[1], R[qb[0]] * qb[1], px, py]

func _draw_smear(ci: CanvasItem) -> void:
	var sm: Dictionary = A.smear
	var to: float = sm.to
	var from: float = sm.from
	var fade: float = sm.get("fade", to - 45.0)
	if t < from or t > to:
		return
	var a := 1.0 if t < fade else 1.0 - (t - fade) / (to - fade)
	var n: int = sm.get("samples", 12)
	var step: float = sm.get("window", 48.0) / n
	var tips := PackedVector2Array()
	var mids := PackedVector2Array()
	var inner := PackedVector2Array()
	var qt: Array = data.points[sm.tip]
	var qb: Array = data.points[sm.base]
	_update_cam()
	# past samples in the CURRENT frame, root travel turned onto the art's forward axis (demo look): on a vertical attack
	# line the lunge would otherwise shift each sample across the blade and fill the band into a blob
	var px: float = pose.x
	var py: float = pose.y
	var X := cam.char_xf(px, py)
	var r0 := cam.root(px, py)
	# exact ends (now, now - window) + the step grid between them: grid samples are memoised, ~4 new poses a frame instead of 13
	var w := n * step
	var lo := maxf(from, t - w)
	var samples := [_smear_pt(t, qt, qb)]
	for m in range(ceili(t / step) - 1, floori(lo / step), -1):
		if m * step < t and m * step > lo:
			if not _smear_at.has(m):
				_smear_at[m] = _smear_pt(m * step, qt, qb)
			samples.append(_smear_at[m])
	if lo < t:
		samples.append(_smear_pt(lo, qt, qb))
	for sp: Array in samples:
		var sx: float = sp[2]
		var sy: float = sp[3]
		var dy: float = (sy - py) * cam.ca
		var along := (cam.root(sx, sy) - r0 - Vector2(0.0, dy)).dot(cam.u)
		var d := Vector2(cam.f * along, dy) # board px; = the old mapping on horizontal attacks
		var tip: Vector2 = sp[0]
		var mid: Vector2 = sp[1]
		var tp: Vector2 = X * tip + d
		var md: Vector2 = X * mid + d
		tips.append(tp)
		mids.append(md)
		inner.append(tp.lerp(md, 0.35))
	ci.draw_set_transform_matrix(Draw.xf)
	var fill := RigFx.col(sm.get("fill", "#f4fbff"))
	var inn := RigFx.col(sm.get("inner", "#b9e7f3"))
	fill.a *= a
	inn.a *= a
	_strip(ci, tips, mids, fill)
	var outline := tips.duplicate()
	for i in range(mids.size() - 1, -1, -1):
		outline.append(mids[i])
	outline.append(tips[0])
	var ink := RigFx.INK
	ink.a *= a
	RigCtx.stroke_line(ci, outline, ink, maxf(0.8, 4.0 * cam.ca))
	_strip(ci, inner, mids, inn)

## band between two polylines as quads (the swept area can self-intersect mid-swing)
static func _strip(ci: CanvasItem, a: PackedVector2Array, b: PackedVector2Array, c: Color) -> void:
	var pts := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in a.size():
		pts.append(a[i])
		pts.append(b[i])
	for i in a.size() - 1:
		var j := i * 2
		idx.append_array([j, j + 1, j + 2, j + 1, j + 3, j + 2])
	if idx.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, PackedColorArray([c]))

## VFX layer: back = behind the target token, mid = just over it, front = over every unit
func draw_layer(ci: CanvasItem, layer: String) -> void:
	var ctx := _ctx(ci)
	for f: RigFx.Fx in fxs:
		ctx.alpha = 1.0
		f.draw(ctx, cam, layer)
	if playing:
		ctx.alpha = 1.0
		spec.draw(ctx, cam, self, layer, t)
	ci.draw_set_transform_matrix(Draw.xf)

## full-board flash (engine flash(): 45% at start, fading)
func draw_flash(ci: CanvasItem, area: Rect2) -> void:
	if flash_t <= 0.0:
		return
	var c := flash_col
	c.a = 0.45 * flash_t / flash_dur
	ci.draw_set_transform_matrix(Draw.xf)
	ci.draw_rect(area, c)

## nothing left to draw (character back to token, every fx gone)
func done() -> bool:
	return not playing and not shown and fxs.is_empty() and flash_t <= 0.0
