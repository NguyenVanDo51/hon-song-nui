extends RigSpec
## stone golem "Đập đất" (docs/anim_demo/elephant.spec.js; unit key stays `elephant`): step-in -> both fists overhead ->
## double-fist slam -> ground cracks race to the target + shockwave + dust + stone shards -> THE hit at T_HIT.

var _main := PackedVector2Array()
var _br: Array = [] # [[at, PackedVector2Array], ...]

func _crack_data() -> void:
	if not _main.is_empty():
		return
	for q: Array in data.consts.CRACK_MAIN:
		_main.append(RigData.vec2(q))
	for b: Dictionary in data.consts.CRACK_BR:
		var pts := PackedVector2Array()
		for q: Array in b.pts:
			pts.append(RigData.vec2(q))
		var at: float = b.at
		_br.append([at, pts])

func events(_r: Rig) -> Array:
	var c := data.consts
	var ground: float = c.GROUND
	var t_step: float = c.T_STEP
	var t_slam: float = c.T_SLAM
	var t_hit: float = c.T_HIT
	var stone_hex: String = c.STONE
	var stone := Color(stone_hex)
	return [
		[
			t_step,
			func(a: Rig) -> void:
				a.dust(150, ground, 4, 1)
				a.dust(104, ground, 3, -1)
				a.shake(4, 160),
		],
		[
			500.0,
			func(a: Rig) -> void:
				a.gleam("core", 200),
		],
		[
			t_slam,
			func(a: Rig) -> void:
				var f := a.point("fistF")
				a.flash("#fff6dc", 40)
				a.shake(16, 440) # heavy unit: stronger shake than the shared HIT
				a.sound("heavy")
				a.shockwave(f.x, ground, { "r": 120.0, "ms": 340.0 })
				a.dust(f.x + 20, ground, 4, 1)
				a.dust(f.x - 40, ground, 3, -1)
				_shards(a, f.x, 7, ground, stone),
		],
		[
			t_hit,
			func(a: Rig) -> void:
				var tx: float = a.target().x
				a.hit(Rig.with(Rig.HIT, { "dmg": 60 }))
				a.shockwave(tx, ground, { "r": 110.0, "ms": 300.0 })
				a.dust(tx - 50, ground, 3, 1),
		],
	]

## stone shards thrown toward the target (one-shot fx with own state)
static func _shards(a: Rig, x: float, n: int, ground: float, stone: Color) -> void:
	for i in n:
		var m := Shard.new()
		m.x = x + randf_range(-14, 24)
		m.y = ground - 4
		m.vx = randf_range(120, 460)
		m.vy = randf_range(-560, -260)
		m.rr = randf_range(6, 11)
		m.rot = randf_range(0, 6)
		m.life = randf_range(520, 720)
		m.ground = ground
		m.col = stone
		m.w = -1.0
		a.add(m)

class Shard extends RigFx.Mote:
	var ground: float
	var col: Color

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
		for k in 4:
			var an := k / 4.0 * TAU + 0.4
			var rad := rr * (0.7 if k % 2 else 1.0)
			if k:
				ctx.line_to(cos(an) * rad, sin(an) * rad)
			else:
				ctx.move_to(cos(an) * rad, sin(an) * rad)
		ctx.close_path()
		ctx.fill(col)
		ctx.stroke(RigFx.INK, 3)

func idle(p: Dictionary, b: float, _clock: float) -> void:
	p.sy = 1.0 + 0.01 * b
	p.head = 1.0 * b
	p.armF = 1.5 * b
	p.armB = -1.5 * b

static func _plen(pts: PackedVector2Array) -> float:
	var s := 0.0
	for i in range(1, pts.size()):
		s += pts[i].distance_to(pts[i - 1])
	return s

## draw the first u (0..1) of a polyline, tapering width w0 -> w1
static func _crack_line(ctx: RigCtx, pts: PackedVector2Array, u: float, w0: float, w1: float, edge: Color) -> void:
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
		ctx.stroke(edge, w + 9.0)
		ctx.stroke(RigFx.INK, w)
		acc += d
		i += 1

func draw(ctx: RigCtx, _cam: RigCam, _r: Rig, layer: String, t: float) -> void:
	var c := data.consts
	var t_slam: float = c.T_SLAM
	# ground cracks: race from the fists to under the target, then fade
	if layer == "back" and t >= t_slam:
		_crack_data()
		var edge_hex: String = c.STONE2
		var edge := Color(edge_hex)
		var u := RigData.ease_by_name("outExpo", clampf((t - t_slam) / 90.0, 0.0, 1.0))
		var al := 1.0 if t < 1000.0 else clampf(1.0 - (t - 1000.0) / 250.0, 0.0, 1.0)
		ctx.set_world()
		ctx.alpha = al
		ctx.begin_path()
		ctx.ellipse(_main[0].x, _main[0].y, 34, 9, 0, 0, TAU)
		ctx.close_path()
		ctx.fill(Color(RigFx.INK, 0.35))
		_crack_line(ctx, _main, u, 13, 5, edge)
		for b: Array in _br:
			var at: float = b[0]
			var pts: PackedVector2Array = b[1]
			_crack_line(ctx, pts, clampf((u - at) / 0.25, 0.0, 1.0), 9, 3, edge)
		ctx.alpha = 1.0
