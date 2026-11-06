extends RigSpec
## catapult "Nện đá tảng" (docs/anim_demo/catapult.spec.js). Winch ratchets the arm back -> trigger -> arm whips into
## the crossbar -> boulder flies a high arc (fixed FLY ms at any range 2..4) -> smash = THE hit + debris + dust ring.
## Ground fx at the target (landing shadow, crater, debris) stay upright around the target token for any direction.

## stone chunks (JS rockDebris): one-shot fx, own state. x = local offset from the target centre, upright frame
class Debris extends RefCounted:
	const LIFE := 820.0
	var r: Rig
	var bits: Array = []
	var age := 0.0
	var feet: float
	var stone: Color
	var stone_d: Color
	func _init(p_r: Rig, x: float, y: float, c: Dictionary) -> void:
		r = p_r
		feet = r.target().feet
		stone = Color(c.STONE)
		stone_d = Color(c.STONE_D)
		var x0 := x - r.cam.xt
		for i in 9:
			var a := -PI * (0.12 + 0.76 * i / 8.0) + randf_range(-0.12, 0.12)
			var v := randf_range(380, 720)
			bits.append({ "x": x0 + randf_range(-14, 14), "y": y - randf_range(0, 20), "vx": cos(a) * v, "vy": sin(a) * v,
				"r": randf_range(7, 14), "rot": randf_range(0, 6), "vr": randf_range(-12, 12), "bounced": false, "k": (i % 3) / 2.0 })
	func upd(s: float, ms: float) -> bool:
		age += ms
		for b: Dictionary in bits:
			b.vy += 1900.0 * s
			b.x += b.vx * s
			b.y += b.vy * s
			b.rot += b.vr * s
			if b.y > feet - b.r * 0.6 and b.vy > 0.0:
				b.y = feet - b.r * 0.6
				b.vy *= 0.0 if b.bounced else -0.32
				b.vx *= 0.45
				b.vr *= 0.5
				b.bounced = true
		return age < LIFE
	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer != "front":
			return
		var fade := (LIFE - age) / 220.0 if age > LIFE - 220.0 else 1.0
		for b: Dictionary in bits:
			var rr: float = b.r
			ctx.set_xf(cam.frame(cam.xt, b.y, 1.0).translated_local(Vector2(b.x, 0.0)).rotated_local(b.rot))
			ctx.alpha = fade
			ctx.begin_path(); ctx.move_to(-rr, -rr * 0.3); ctx.line_to(-rr * 0.2, -rr); ctx.line_to(rr, -rr * 0.4)
			ctx.line_to(rr * 0.6, rr * 0.8); ctx.line_to(-rr * 0.7, rr * 0.6); ctx.close_path()
			ctx.fill(stone_d if b.k > 0.6 else stone); ctx.stroke(Rig.INK, 4)
		ctx.alpha = 1.0

func events(_r: Rig) -> Array:
	var c := data.consts
	var rel: float = c.REL
	return [
		[630.0, func(a: Rig) -> void: a.sparks(68, 190, 4, "#e2c36e")],
		[672.0, func(a: Rig) -> void:
			a.shake(5, 160)
			a.dust(220, 244, 4, 1)],
		[rel, func(a: Rig) -> void:
			a.sound("rock")
			a.projectile({ "point": "rock", "kind": "rock", "size": 24.0, "color": c.STONE, "arc": 205.0, "ms": c.FLY, "trail": c.SAND,
				"hit": Rig.with(Rig.HIT, { "dmg": 60 }),
				"onArrive": func(to: Vector2) -> void:
					var f: float = a.target().feet
					a.shockwave(to.x, f, { "r": 210.0, "ms": 520.0, "color": c.SAND })
					a.shockwave(to.x, f, { "r": 120.0, "ms": 360.0, "color": "#d9c49a" })
					a.add(Debris.new(a, to.x, f - 20.0, c))
					a.dust(to.x, f, 10, 0) })],
		[800.0, func(a: Rig) -> void: a.dust(104, 244, 6, -1)],
	]

func drive(name: String, p: Dictionary, _vx: float, ctx: Dictionary) -> float:
	if name == "bucket":
		return p.arm * 0.4
	if name == "flag":
		return -p.tilt * 3.0 + float(p.get("flagX", 0.0)) + (7.0 * sin(ctx.clock / 420.0) if ctx.idle else 0.0)
	return 0.0

## machine never breathes (no sy); only the crew + flag move at idle
func idle(p: Dictionary, b: float, _clock: float) -> void:
	p.opHead = 2.0 * b
	p.opLean = 0.8 * b
	p.opArm = 1.5 * b

## stateless: creak marks while winding, landing shadow during flight, crater after impact
func draw(ctx: RigCtx, cam: RigCam, r: Rig, layer: String, t: float) -> void:
	var c := data.consts
	var rel: float = c.REL
	var fly: float = c.FLY
	var land: float = c.LAND
	if layer == "front" and t > 200.0 and t < 610.0:
		var k := int(floor(t / 55.0)) % 2
		for q: Array in [["hub", 26.0], ["mid", 30.0]]:
			ctx.set_xf(Transform2D(Vector2(cam.ca, 0), Vector2(0, cam.ca), r.point_px(q[0])))
			var r0: float = q[1]
			for s: float in [-1.0, 1.0]:
				ctx.begin_path()
				ctx.arc(0, 0, r0 + 7.0 * k, PI * 0.95 if s < 0.0 else -0.25, PI * 1.25 if s < 0.0 else 0.05)
				ctx.stroke(Rig.INK, 7); ctx.stroke("#fff6d6", 3)
	var f: float = r.target().feet
	if layer == "back" and t > rel and t < land:
		var u := (t - rel) / fly
		ctx.set_xf(cam.frame(cam.xt, f, 1.0))
		ctx.alpha = 0.12 + 0.3 * u
		ctx.begin_path(); ctx.ellipse(0, 2, 24 + 56 * u, 7 + 12 * u, 0, 0, TAU); ctx.close_path()
		ctx.fill(Rig.INK)
	if layer == "back" and t >= land:
		var u := clampf((t - land) / 700.0, 0.0, 1.0)
		ctx.set_xf(cam.frame(cam.xt, f, 1.0))
		ctx.alpha = 0.5 * (1.0 - u * u)
		ctx.begin_path(); ctx.ellipse(0, 4, 92, 20, 0, 0, TAU); ctx.close_path()
		ctx.fill("#6b4a2e"); ctx.stroke(Rig.INK, 4)
	ctx.alpha = 1.0
