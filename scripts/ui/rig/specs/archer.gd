extends RigSpec
## archer "Nỏ thần liên châu" (docs/anim_demo/archer.spec.js): aim -> 3-bolt volley -> recoil -> reload. Range 1-2.
## Bolts 1-2 = HIT_SMALL ticks, bolt 3 = THE hit.

const OFFS := [-16.0, 6.0, -4.0] # bolt y offsets at the target

## bowstring "twang": short white speed lines flaring off the muzzle (JS twang())
class Twang extends RigFx.Timed:
	func _init(p_r: Rig) -> void:
		r = p_r
		life = 110.0
	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer != "front":
			return
		var u := age / life
		var r0 := 10.0 + 26.0 * RigFx.out(u)
		var r1 := r0 + 22.0 * (1.0 - u)
		# JS cam.translate(muzzle): forward = shot direction (aimed -> same as the demo for left/right, follows up/down)
		ctx.set_xf(cam.aimed(r.point_px("muzzle"), cam.u, cam.ca))
		ctx.alpha = 1.0 - u * u
		for a: float in [-0.75, 0.0, 0.75]:
			ctx.begin_path(); ctx.move_to(cos(a) * r0, sin(a) * r0); ctx.line_to(cos(a) * r1, sin(a) * r1)
			ctx.stroke(RigFx.INK, 9.0); ctx.stroke("#fff6d6", 4.0)
		ctx.alpha = 1.0

static func bolt(a: Rig, i: int) -> void:
	var tg := a.target()
	var tx: float = tg.x
	var ty: float = tg.y
	var off: float = OFFS[i]
	var shots: Array = a.data.consts.SHOTS
	var last := i == shots.size() - 1
	a.projectile({ "point": "muzzle", "to": Vector2(tx - 8.0, ty + off), "kind": "arrow", "size": 0.95, "arc": 14.0,
		"speed": 2500.0, "color": "#4f74c9" if a.swap else "#c9503f", "trail": "#fff6d6",
		"hit": Rig.with(Rig.HIT, { "dmg": 36 }) if last else Rig.with(Rig.HIT_SMALL, { "dmg": 8 }) })
	a.sound("arrow")
	a.add(Twang.new(a))

func events(_r: Rig) -> Array:
	var shots: Array = data.consts.SHOTS
	var s0: float = shots[0]
	var s1: float = shots[1]
	var s2: float = shots[2]
	return [
		[150.0, func(a: Rig) -> void: a.dust(96, 244, 4, -1)],
		[210.0, func(a: Rig) -> void: a.gleam("muzzle", 160)],
		[s0, func(a: Rig) -> void: bolt(a, 0)],
		[s1, func(a: Rig) -> void: bolt(a, 1)],
		[s2, func(a: Rig) -> void:
			bolt(a, 2)
			a.dust(100, 244, 6, -1)
			a.shake(3, 120)],
		[1042.0, func(a: Rig) -> void: a.gleam("nut", 120)],
	]

func drive(name: String, p: Dictionary, vx: float, ctx: Dictionary) -> float:
	var idle_k: float = ctx.idle
	var ck: float = ctx.clock
	var kick: float = p.get("kick", 0.0)
	if name == "tails":
		return clampf(vx * 0.03, -14, 30) + p.lean * 0.6 + p.head * 0.5 + kick * -1.2 + idle_k * 3.0 * sin(ck / 650.0)
	if name == "quiv":
		return clampf(vx * 0.02, -8, 12) + p.lean * 0.4 + kick * -0.5 + idle_k * 0.8 * sin(ck / 800.0)
	return 0.0

func idle(p: Dictionary, b: float, _clock: float) -> void:
	p.sy = 1.0 + 0.014 * b
	p.head = 1.5 * b
	p.aim = -1.2 * b
	p.raise = -0.8 * b

## stock raised to the cheek -> crossbow + arm in front of the face
func order(p: Dictionary, list: Array) -> Array:
	var rs: float = p.get("raise", 0.0)
	if rs >= -1.0:
		return list
	return part_after(list, "face", "head")
