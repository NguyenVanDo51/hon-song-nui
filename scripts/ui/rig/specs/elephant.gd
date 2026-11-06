extends RigSpec
## war elephant "Giẫm đất" (docs/anim_demo/elephant.spec.js): rear up, trunk raised + trumpet -> slam front feet ->
## ground cracks race to the target + shockwave + dust + clods -> THE hit at T_HIT.

const CRACK := Color("#a87a4c")
var _main := PackedVector2Array()
var _br: Array = [] # [[at, PackedVector2Array], ...]

func _crack_data() -> void:
	if not _main.is_empty():
		return
	for q: Array in data.consts.CRACK_MAIN:
		_main.append(Vector2(q[0], q[1]))
	for b: Dictionary in data.consts.CRACK_BR:
		var pts := PackedVector2Array()
		for q: Array in b.pts:
			pts.append(Vector2(q[0], q[1]))
		_br.append([float(b.at), pts])

func events(_r: Rig) -> Array:
	var c := data.consts
	var ground: float = c.GROUND
	var t_slam: float = c.T_SLAM
	var t_hit: float = c.T_HIT
	return [
		[400.0, func(a: Rig) -> void:
			a.dust(70, ground, 5, -1)
			a.sound("rock")],
		[430.0, func(a: Rig) -> void: a.shake(3, 260)], # trumpet rumble
		[t_slam, func(a: Rig) -> void:
			var f := a.point("foot")
			a.flash("#fff6dc", 40)
			a.shake(16, 440) # heavy unit: stronger shake than the shared HIT
			a.shockwave(f.x + 6, ground, { "r": 120.0, "ms": 340.0 })
			a.dust(f.x + 20, ground, 4, 1)
			a.dust(f.x - 30, ground, 3, -1)
			_clods(a, f.x + 10, 6, ground)],
		[t_hit, func(a: Rig) -> void:
			var tg := a.target()
			a.hit(Rig.with(Rig.HIT, { "dmg": 65 }))
			a.shockwave(tg.x, ground, { "r": 110.0, "ms": 300.0 })
			a.dust(tg.x - 50, ground, 3, 1)],
	]

## dirt clods kicked toward the target (one-shot fx with own state)
static func _clods(a: Rig, x: float, n: int, ground: float) -> void:
	for i in n:
		var m := Clod.new()
		m.x = x + randf_range(-14, 24)
		m.y = ground - 4
		m.vx = randf_range(120, 460)
		m.vy = randf_range(-560, -260)
		m.rr = randf_range(6, 10)
		m.rot = randf_range(0, 6)
		m.life = randf_range(520, 720)
		m.ground = ground
		m.w = -1.0
		a.add(m)

class Clod extends RigFx.Mote:
	var ground: float
	func move(s: float) -> void:
		vy += 1700.0 * s
		x += vx * s
		y += vy * s
		rot += 9.0 * s
		if y > ground:
			y = ground
			vy *= -0.3
			vx *= 0.5
	func fade() -> float:
		var u := age / life
		return (1.0 - u) / 0.3 if u > 0.7 else 1.0
	func shape(ctx: RigCtx) -> void:
		ctx.begin_path()
		for k in 5:
			var an := k / 5.0 * TAU
			var rad := rr * (0.75 if k % 2 else 1.0)
			if k:
				ctx.line_to(cos(an) * rad, sin(an) * rad)
			else:
				ctx.move_to(rad, 0)
		ctx.close_path()
		ctx.fill(CRACK)
		ctx.stroke(RigFx.INK, 3)

func drive(name: String, p: Dictionary, vx: float, ctx: Dictionary) -> float:
	var idle_k: float = ctx.idle
	if name == "ear":
		return float(p.get("earX", 0.0)) + clampf(vx * 0.02, -10, 14) + idle_k * 3.0 * sin(ctx.clock / 520.0)
	if name == "tail":
		return -float(p.lean) * 0.7 + clampf(-vx * 0.03, -20, 20) + idle_k * 5.0 * sin(ctx.clock / 800.0)
	return 0.0

func idle(p: Dictionary, b: float, clock: float) -> void:
	p.sy = 1.0 + 0.012 * b
	p.head = 1.2 * b
	p.rider = 1.5 * b
	p.rarm = 2.0 * b
	p.tr1 = 3.0 * b
	p.tr2 = 6.0 * sin(clock / 1300.0 * TAU)

static func _plen(pts: PackedVector2Array) -> float:
	var s := 0.0
	for i in range(1, pts.size()):
		s += pts[i].distance_to(pts[i - 1])
	return s

## draw the first u (0..1) of a polyline, tapering width w0 -> w1
static func _crack_line(ctx: RigCtx, pts: PackedVector2Array, u: float, w0: float, w1: float) -> void:
	var total := _plen(pts)
	var L := total * u
	var acc := 0.0
	var i := 1
	while i < pts.size() and acc < L:
		var p0 := pts[i - 1]
		var p1 := pts[i]
		var d := p0.distance_to(p1)
		var k := minf(1.0, (L - acc) / d)
		var w := lerpf(w0, w1, (acc + d * k / 2.0) / total)
		var e := p0 + (p1 - p0) * k
		ctx.begin_path()
		ctx.move_to(p0.x, p0.y)
		ctx.line_to(e.x, e.y)
		ctx.stroke(CRACK, w + 9.0)
		ctx.stroke(RigFx.INK, w)
		acc += d
		i += 1

func draw(ctx: RigCtx, cam: RigCam, r: Rig, layer: String, t: float) -> void:
	var c := data.consts
	var t_slam: float = c.T_SLAM
	# ground cracks: race from the front feet to under the target, then fade
	if layer == "back" and t >= t_slam:
		_crack_data()
		var u := RigData.ease_by_name("outExpo", clampf((t - t_slam) / 90.0, 0.0, 1.0))
		var al := 1.0 if t < 1200.0 else clampf(1.0 - (t - 1200.0) / 330.0, 0.0, 1.0)
		ctx.set_world()
		ctx.alpha = al
		ctx.begin_path()
		ctx.ellipse(_main[0].x, _main[0].y, 30, 8, 0, 0, TAU)
		ctx.close_path()
		ctx.fill(Color(RigFx.INK, 0.35))
		_crack_line(ctx, _main, u, 13, 5)
		for b: Array in _br:
			_crack_line(ctx, b[1], clampf((u - b[0]) / 0.25, 0.0, 1.0), 9, 3)
		ctx.alpha = 1.0
	# trumpet: sound dashes pulsing out of the raised trunk tip (anchored to the drawn trunk, board px)
	var tr0: float = c.T_TRUMP[0]
	var tr1: float = c.T_TRUMP[1]
	if layer == "front" and t > tr0 and t < tr1:
		var tip := r.point_px("tip")
		var bk := r.point_px("troot")
		var a0 := atan2(tip.y - bk.y, tip.x - bk.x)
		var env := clampf((t - tr0) / 40.0, 0.0, 1.0) * clampf((tr1 - t) / 60.0, 0.0, 1.0)
		ctx.set_xf(cam.at_px(tip))
		for k in 3:
			var ph := fposmod((t - tr0) / 200.0 + k / 3.0, 1.0)
			var d := 16.0 + 56.0 * ph
			var streak := 22.0 - 8.0 * ph
			ctx.alpha = env * (1.0 - ph * ph)
			for da: float in [-0.6, 0.0, 0.6]:
				var an := a0 + da
				var cx := cos(an)
				var cy := sin(an)
				ctx.begin_path()
				ctx.move_to(cx * d, cy * d)
				ctx.line_to(cx * (d + streak), cy * (d + streak))
				ctx.stroke(RigFx.INK, 10)
				ctx.stroke("#fffaf0", 4.5)
		ctx.alpha = 1.0
