extends RigSpec
## Thủy binh "Sóng cuộn" (docs/anim_demo/boat.spec.js). Paddle-spear sweep -> blade slaps the water -> curling wave
## rolls forward and crashes on the target = THE hit (WaveFx).

const GROUND := 244.0
const WATER := "#6fb6e0"
const WSHADE := "#3f8cc4"
const FOAM := "#f4fcff"
const DEMO_FRONT := 340.0 # T_FRONT at the demo range (256 + targetFront)

func events(_r: Rig) -> Array:
	return [
		[170.0, func(a: Rig) -> void: a.gleam("blade")],
		[240.0, func(a: Rig) -> void:
			a.sound("slash")
			a.dust(100, GROUND, 5, -1)],
		[300.0, func(a: Rig) -> void:
			var b := a.point("blade")
			var x := clampf(b.x, 200.0, 300.0)
			Drop.spawn(a, x, GROUND - 14.0, 9, { "sx": 26.0, "vx0": 60.0, "vx1": 380.0, "vy0": -560.0, "vy1": -220.0, "r0": 4.0, "r1": 8.0 })
			a.shockwave(x, GROUND, { "color": WATER, "r": 80.0, "ms": 320.0 })
			# demo x0 = 250 at range 1; keep the same gap to the real front (diagonal)
			a.add(WaveFx.new(a, 250.0 + float(a.target().front) - DEMO_FRONT))],
	]

func drive(name: String, p: Dictionary, vx: float, ctx: Dictionary) -> float:
	if name == "plume":
		var idle: float = ctx.idle
		return clampf(vx * 0.035, -14, 30) + p.lean * 0.8 + p.head * 0.6 + idle * 2.0 * sin(ctx.clock / 700.0)
	return 0.0

func idle(p: Dictionary, b: float, _clock: float) -> void:
	p.sy = 1.0 + 0.014 * b
	p.head = 1.5 * b
	p.arm = 2.0 * b
	p.wrist = -1.5 * b
	p.shld = b

## water droplet: outlined teardrop along its velocity, gravity, dies on the ground. Frame weight fixed at spawn.
class Drop extends RigFx.Mote:
	static func spawn(r: Rig, px: float, py: float, n: int, o := {}) -> void:
		var sx: float = o.get("sx", 20.0)
		for i in n:
			var d := Drop.new()
			d.x = px + randf_range(-sx, sx)
			d.y = py + randf_range(-10, 10)
			d.vx = randf_range(o.get("vx0", -150.0), o.get("vx1", 350.0))
			d.vy = randf_range(o.get("vy0", -620.0), o.get("vy1", -260.0))
			d.rr = randf_range(o.get("r0", 5.0), o.get("r1", 10.0))
			d.life = randf_range(650, 1000)
			d.w = r.cam.w_of(d.x)
			r.add(d)

	func move(s: float) -> void:
		vy += 1500.0 * s
		x += vx * s
		y += vy * s

	func alive() -> bool:
		return age < life and y < GROUND + 6.0

	func xf(cam: RigCam) -> Transform2D:
		return cam.frame(x, y, w).rotated_local(atan2(vy, vx))

	func fade() -> float:
		return 1.0 - (age - life * 0.7) / (life * 0.3) if age > life * 0.7 else 1.0

	func shape(ctx: RigCtx) -> void:
		var r := rr
		ctx.begin_path(); ctx.move_to(-r * 2.3, 0); ctx.quad_to(-r * 0.6, -r, 0, -r); ctx.arc(0, 0, r, -PI / 2, PI / 2)
		ctx.quad_to(-r * 0.6, r, -r * 2.3, 0)
		ctx.fill(WATER); ctx.stroke(RigFx.INK, 3)
		ctx.begin_path(); ctx.circle(r * 0.2, -r * 0.35, r * 0.3); ctx.fill(FOAM)

## wave: rises + curls toward the target, crashes (THE shared HIT), then collapses into foam
class WaveFx extends RefCounted:
	const RISE := 150.0
	const FALL := 340.0
	const HMAX := 200.0
	var r: Rig
	var x0: float
	var age := 0.0
	var hit := false

	func _init(p_r: Rig, p_x0: float) -> void:
		r = p_r
		x0 = p_x0

	func upd(_s: float, ms: float) -> bool:
		age += ms
		if not hit and age >= RISE:
			hit = true
			var c := r.target()
			r.hit(Rig.with(Rig.HIT, { "dmg": 52 }))
			Drop.spawn(r, c.x, c.y - 30.0, 16, { "sx": 34.0, "vx0": -180.0, "vx1": 420.0, "vy0": -700.0, "vy1": -280.0, "r0": 6.0, "r1": 11.0 })
			r.shockwave(c.x, GROUND, { "color": WATER, "r": 150.0, "ms": 460.0 })
		return age < RISE + FALL

	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer != "mid":
			return
		if age < RISE:
			var u := age / RISE
			var e := RigFx.out(u)
			draw_wave(ctx, cam, lerpf(x0, x0 + 44.0, e), lerpf(40.0, HMAX, e), RigFx.out(clampf((u - 0.15) / 0.85, 0.0, 1.0)), lerpf(0.05, 0.25, u), 1.0)
		else:
			var v := (age - RISE) / FALL
			var e := RigFx.out(v)
			draw_wave(ctx, cam, x0 + 44.0 + 30.0 * e, HMAX * (1.0 - 0.7 * e), 1.0 + 0.9 * e, 0.25 + 0.25 * e, 1.0 if v < 0.45 else 1.0 - (v - 0.45) / 0.55)

	## curling wave, base on the ground at X, height H; c = curl 0..2 (1 = full barrel, 2 = lip slammed down), k = forward
	## lean. JS draws in world coords; here an upright frame at (X, ground) with P() as local offsets, so the wave stays
	## upright on vertical attacks too (same convention as the shared shockwave).
	static func draw_wave(ctx: RigCtx, cam: RigCam, X: float, H: float, c: float, k: float, alpha: float) -> void:
		var P := func(x: float, y: float) -> Vector2: return Vector2((x * 0.85 - k * y) * H, y * H)
		var tip := Vector2(0.18 + 0.42 * c, -1.0 + 0.5 * c)
		var I := Vector2(0.16 + 0.1 * c, -0.6 + 0.1 * c)
		ctx.set_xf(cam.frame(X, GROUND))
		ctx.alpha = alpha
		# body
		ctx.begin_path(); _mv(ctx, P.call(-0.85, 0.0))
		_bz(ctx, P.call(-0.45, 0.0), P.call(-0.45, -1.0), P.call(-0.05, -1.0))
		_lip(ctx, P, tip, c)
		_bz(ctx, P.call(tip.x - 0.04, tip.y - 0.22 * minf(c, 1.0)), P.call(I.x + 0.14, I.y - 0.14), P.call(I.x, I.y))
		_bz(ctx, P.call(I.x - 0.1, I.y + 0.25), P.call(0.16, -0.06), P.call(0.42, 0.0))
		ctx.close_path(); ctx.fill(WATER); ctx.stroke(RigFx.INK, 6)
		# shade on the inner face (no outline)
		ctx.begin_path(); _mv(ctx, P.call(I.x, I.y))
		_bz(ctx, P.call(I.x - 0.1, I.y + 0.25), P.call(0.16, -0.06), P.call(0.36, -0.01))
		_ln(ctx, P.call(0.02, -0.01)); _bz(ctx, P.call(-0.06, -0.3), P.call(-0.04, -0.62), P.call(I.x, I.y))
		ctx.fill(WSHADE)
		# motion streaks on the back slope
		ctx.alpha = alpha * 0.9
		for s: Array in [[-0.55, -0.3, -0.45], [-0.42, -0.2, -0.72], [-0.66, -0.5, -0.2]]:
			ctx.begin_path(); _mv(ctx, P.call(s[0], s[2])); _ln(ctx, P.call(s[1], s[2] - 0.04)); ctx.stroke(FOAM, 5)
		ctx.alpha = alpha
		# foam cap along the crest -> lip
		var w := maxf(9.0, H * 0.1)
		ctx.begin_path(); _mv(ctx, P.call(-0.32, -0.94))
		var q1: Vector2 = P.call(-0.2, -1.01)
		var q2: Vector2 = P.call(-0.05, -1.0)
		ctx.quad_to(q1.x, q1.y, q2.x, q2.y)
		_lip(ctx, P, tip, c)
		ctx.stroke(RigFx.INK, w + 7.0); ctx.stroke(FOAM, w)
		# foam bubbles off the lip
		for b: Array in [[0.08, -0.1, 0.05], [-0.02, 0.02, 0.035], [0.12, 0.06, 0.03]]:
			var at: Vector2 = P.call(tip.x + b[0], tip.y + b[1])
			ctx.begin_path(); ctx.circle(at.x, at.y, maxf(4.0, b[2] * H)); ctx.fill(FOAM); ctx.stroke(RigFx.INK, 3)
		ctx.alpha = 1.0

	static func _lip(ctx: RigCtx, P: Callable, tip: Vector2, c: float) -> void:
		_bz(ctx, P.call(0.25, -1.02), P.call(tip.x + 0.06, -1.0 + 0.2 * c), P.call(tip.x, tip.y))

	static func _mv(ctx: RigCtx, v: Vector2) -> void:
		ctx.move_to(v.x, v.y)

	static func _ln(ctx: RigCtx, v: Vector2) -> void:
		ctx.line_to(v.x, v.y)

	static func _bz(ctx: RigCtx, a: Vector2, b: Vector2, e: Vector2) -> void:
		ctx.bezier_to(a.x, a.y, b.x, b.y, e.x, e.y)
