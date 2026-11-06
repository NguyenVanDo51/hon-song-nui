extends RigSpec
## catapult "Nện đá tảng" (docs/anim_demo/catapult.spec.js). Winch ratchets the arm back -> trigger -> arm whips into
## the crossbar -> boulder flies a high arc (fixed FLY ms at any range 2..4) -> smash = THE hit + debris + dust ring.
## Ground fx at the target (landing shadow, crater, debris) stay upright around the target token for any direction.

## stone chunk (JS rockDebris). x = local offset from the target centre: upright frame there, any attack direction
class Debris extends RigFx.Mote:
	const LIFE := 820.0
	var feet: float
	var col: Color
	var bounced := false
	static func spawn(rig: Rig, tx: float, ty: float, c: Dictionary) -> void:
		var feet_y: float = rig.target().feet
		var x0 := tx - rig.cam.xt
		for i in 9:
			var d := Debris.new()
			var a := -PI * (0.12 + 0.76 * i / 8.0) + randf_range(-0.12, 0.12)
			var v := randf_range(380, 720)
			d.x = x0 + randf_range(-14, 14)
			d.y = ty - randf_range(0, 20)
			d.vx = cos(a) * v
			d.vy = sin(a) * v
			d.rr = randf_range(7, 14)
			d.rot = randf_range(0, 6)
			d.vr = randf_range(-12, 12)
			d.col = RigFx.col(c.STONE_D if (i % 3) / 2.0 > 0.6 else c.STONE)
			d.feet = feet_y
			d.life = LIFE
			rig.add(d)
	func move(s: float) -> void:
		vy += 1900.0 * s
		x += vx * s
		y += vy * s
		rot += vr * s
		if y > feet - rr * 0.6 and vy > 0.0:
			y = feet - rr * 0.6
			vy *= 0.0 if bounced else -0.32
			vx *= 0.45
			vr *= 0.5
			bounced = true
	func xf(cam: RigCam) -> Transform2D:
		return cam.frame(cam.xt, y, 1.0).translated_local(Vector2(x, 0.0)).rotated_local(rot)
	func fade() -> float:
		return (LIFE - age) / 220.0 if age > LIFE - 220.0 else 1.0
	func shape(ctx: RigCtx) -> void:
		ctx.begin_path(); ctx.move_to(-rr, -rr * 0.3); ctx.line_to(-rr * 0.2, -rr); ctx.line_to(rr, -rr * 0.4)
		ctx.line_to(rr * 0.6, rr * 0.8); ctx.line_to(-rr * 0.7, rr * 0.6); ctx.close_path()
		ctx.fill(col); ctx.stroke(RigFx.INK, 4)

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
					Debris.spawn(a, to.x, f - 20.0, c)
					a.dust(to.x, f, 10, 0) })],
		[800.0, func(a: Rig) -> void: a.dust(104, 244, 6, -1)],
	]

func drive(name: String, p: Dictionary, _vx: float, ctx: Dictionary) -> float:
	if name == "bucket":
		return p.arm * 0.4
	if name == "flag":
		var flag_x: float = p.get("flagX", 0.0)
		var ck: float = ctx.clock
		return -p.tilt * 3.0 + flag_x + (7.0 * sin(ck / 420.0) if ctx.idle else 0.0)
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
		var k := floori(t / 55.0) % 2
		for q: Array in [["hub", 26.0], ["mid", 30.0]]:
			var pt: String = q[0]
			ctx.set_xf(cam.at_px(r.point_px(pt)))
			var r0: float = q[1]
			for s: float in [-1.0, 1.0]:
				ctx.begin_path()
				ctx.arc(0, 0, r0 + 7.0 * k, PI * 0.95 if s < 0.0 else -0.25, PI * 1.25 if s < 0.0 else 0.05)
				ctx.stroke(RigFx.INK, 7); ctx.stroke("#fff6d6", 3)
	var f: float = r.target().feet
	if layer == "back" and t > rel and t < land:
		var u := (t - rel) / fly
		ctx.set_xf(cam.frame(cam.xt, f, 1.0))
		ctx.alpha = 0.12 + 0.3 * u
		ctx.begin_path(); ctx.ellipse(0, 2, 24 + 56 * u, 7 + 12 * u, 0, 0, TAU); ctx.close_path()
		ctx.fill(RigFx.INK)
	if layer == "back" and t >= land:
		var u := clampf((t - land) / 700.0, 0.0, 1.0)
		ctx.set_xf(cam.frame(cam.xt, f, 1.0))
		ctx.alpha = 0.5 * (1.0 - u * u)
		ctx.begin_path(); ctx.ellipse(0, 4, 92, 20, 0, 0, TAU); ctx.close_path()
		ctx.fill("#6b4a2e"); ctx.stroke(RigFx.INK, 4)
	ctx.alpha = 1.0
