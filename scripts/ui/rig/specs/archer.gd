extends RigSpec
## Cung Thủ "Phát tên cung dài" (docs/anim_demo/archer.spec.js): brace -> draw longbow to the chin -> hold -> loose
## (one arrow = THE hit) -> recoil. Range 1-2.

## bowstring "twang": short white speed lines flaring off the bow grip (JS twang())
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
		# JS cam.translate(grip): forward = shot direction (aimed -> same as the demo for left/right, follows up/down)
		ctx.set_xf(cam.aimed(r.point_px("grip"), cam.u, cam.ca))
		ctx.alpha = 1.0 - u * u
		for a: float in [-0.75, 0.0, 0.75]:
			ctx.begin_path()
			ctx.move_to(cos(a) * r0, sin(a) * r0)
			ctx.line_to(cos(a) * r1, sin(a) * r1)
			ctx.stroke(RigFx.INK, 9.0)
			ctx.stroke("#fff6d6", 4.0)
		ctx.alpha = 1.0

static func loose(a: Rig) -> void:
	var tg := a.target()
	var tx: float = tg.x
	var ty: float = tg.y
	a.projectile(
		{
			"point": "atip",
			"to": Vector2(tx - 8.0, ty - 6.0),
			"kind": "arrow",
			"size": 1.0,
			"arc": 18.0,
			"speed": 2300.0,
			"color": "#4f74c9" if a.swap else "#c9503f",
			"trail": "#fff6d6",
			"hit": Rig.with(Rig.HIT, { "dmg": 40 }),
		}
	)
	a.sound("arrow")
	a.add(Twang.new(a))

func events(_r: Rig) -> Array:
	var t_loose: float = data.consts.LOOSE
	return [
		[
			120.0,
			func(a: Rig) -> void:
				a.dust(96, 244, 4, -1),
		],
		[
			470.0,
			func(a: Rig) -> void:
				a.gleam("atip", 150),
		],
		[
			t_loose,
			func(a: Rig) -> void:
				loose(a)
				a.dust(100, 244, 6, -1)
				a.shake(3, 120),
		],
	]

## JS sT / sB / sS composites (string halves follow the nock): exact instead of the 5 ms samples
func channels(p: Dictionary, _t: float, _attack: String) -> void:
	var l: float = data.consts.STR_L
	var s: float = p.get("str", 0.0)
	var ang := rad_to_deg(atan(-s / l))
	p.sT = ang
	p.sB = -ang
	p.sS = sqrt(s * s + l * l) / l - 1.0

func drive(name: String, p: Dictionary, vx: float, ctx: Dictionary) -> float:
	var idle_k: float = ctx.idle
	var ck: float = ctx.clock
	if name == "tails":
		return clampf(vx * 0.03, -14, 30) + p.lean * 0.6 + p.head * 0.5 + idle_k * 3.0 * sin(ck / 650.0)
	if name == "cape":
		return clampf(vx * 0.04, -10, 24) + p.lean * 0.5 + idle_k * 1.5 * sin(ck / 720.0)
	if name == "quiv":
		return clampf(vx * 0.02, -8, 12) + p.lean * 0.4 + idle_k * 0.8 * sin(ck / 800.0)
	return 0.0

func idle(p: Dictionary, b: float, _clock: float) -> void:
	p.sy = 1.0 + 0.014 * b
	p.head = 1.5 * b
	p.aim = -1.2 * b

## string hand at the chin: string, hand + arrow over the face
func order(p: Dictionary, list: Array) -> Array:
	var h: float = p.get("hand", 0.0)
	if h >= -18.0:
		return list
	return part_after(list, "face", "head")
