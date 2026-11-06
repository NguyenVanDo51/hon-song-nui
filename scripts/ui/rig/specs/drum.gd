extends RigSpec
## Trống đồng "Song hồi trống trận" (docs/anim_demo/drum.spec.js).
## L stick BOOM -> R stick BOOM; each boom rolls a bronze sound ring to the target (1st = small tick, 2nd = THE hit).

const BRONZE := "#e2c36e"
const PALE := "#fff6d6"

## JS soundRing(): upright concentric ellipses rolling forward, hit on reaching the target front.
## Own frame weight like RigFx.Wave (RigFx.travel_xf): 0 at the rim -> 1 at the target front (3 rings, one frame).
class SoundRing extends RefCounted:
	const FADE := 200.0
	var r: Rig
	var o: Dictionary
	var x: float
	var x0: float
	var y0: float
	var age := 0.0
	var hit := false
	var gone := 0.0
	var R0: float
	var R1: float
	var sp: float
	func _init(p_r: Rig, p_o: Dictionary) -> void:
		r = p_r; o = p_o
		var p0 := r.point("rim")
		x = p0.x; x0 = x; y0 = p0.y
		R0 = o.get("R0", 34.0); R1 = o.get("R1", 84.0); sp = o.get("speed", 1300.0)
	func upd(s: float, ms: float) -> bool:
		age += ms
		x += sp * s * (0.35 if hit else 1.0)
		if not hit and x >= float(r.target().front):
			hit = true
			r.hit(o.hit)
		if hit:
			gone += ms
		return gone < FADE
	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer != "front":
			return
		var T := r.target()
		var ry: float = (lerpf(R0, R1, RigFx.out(clampf(age / 120.0, 0.0, 1.0))) + gone * 0.12) * float(o.get("scale", 1.0))
		var y: float = lerpf(y0, T.y, RigFx.out(clampf(age / 110.0, 0.0, 1.0)))
		var a := 1.0 - gone / FADE
		ctx.set_xf(RigFx.travel_xf(r, cam, x0, x, y))
		# 3 concentric rings, outer = leading edge at x
		for k in 3:
			var f := 1.0 - k * 0.3
			var rr := ry * f
			var rx := rr * 0.32
			var cx := -rx - k * 10.0
			ctx.alpha = a * (1.0 - k * 0.22)
			ctx.begin_path(); ctx.ellipse(cx, 0.0, rx, rr, 0.0, 0.0, TAU); ctx.close_path()
			ctx.stroke(RigFx.INK, 9.0 if k > 0 else 12.0)
			ctx.stroke(BRONZE if k > 0 else PALE, 4.5 if k > 0 else 6.0)
			if k == 0:
				ctx.stroke(BRONZE, 2.5)
		ctx.alpha = 1.0

## JS boom(): shockwave around the drum face, sparks at the striking tip, small shake
static func boom(a: Rig, tip: String, big: bool) -> void:
	var f := a.point("face")
	a.shockwave(f.x, f.y, { "r": 110.0 if big else 80.0, "ms": 320.0 if big else 260.0, "color": BRONZE })
	a.sparks(a.point(tip).x, f.y - 4.0, 7 if big else 5, BRONZE)
	a.shake(6.0 if big else 4.0, 160.0 if big else 120.0)
	if big:
		a.dust(128, 244, 6, 0)
	a.sound("rock")

func events(_r: Rig) -> Array:
	return [
		[160.0, func(a: Rig) -> void:
			a.gleam("tipB")
			a.gleam("tipF")],
		[268.0, func(a: Rig) -> void:
			boom(a, "tipB", false)
			a.add(SoundRing.new(a, { "R0": 30.0, "R1": 70.0, "hit": Rig.with(Rig.HIT_SMALL, { "dmg": 12 }) }))],
		[396.0, func(a: Rig) -> void:
			boom(a, "tipF", true)
			a.add(SoundRing.new(a, { "R0": 38.0, "R1": 92.0, "scale": 1.0, "hit": Rig.with(Rig.HIT, { "dmg": 26 }) }))],
	]

func drive(name: String, p: Dictionary, vx: float, ctx: Dictionary) -> float:
	if name == "tails":
		var idle: float = ctx.idle
		return clampf(vx * 0.03, -14, 30) - p.lean * 0.8 - p.head * 0.6 + float(p.get("kick", 0.0)) + idle * 2.0 * sin(ctx.clock / 650.0)
	return 0.0

func idle(p: Dictionary, b: float, _clock: float) -> void:
	p.sy = 1.0 + 0.014 * b
	p.head = 1.5 * b
	p.armB = 2.0 * b
	p.armF = -2.0 * b
	p.wristB = -1.5 * b
	p.wristF = 1.5 * b

## sticks whipping across the head: draw the face under the arms
func order(p: Dictionary, list: Array) -> Array:
	if absf(p.wristB) > 60.0 or absf(p.wristF) > 60.0:
		return part_after(list, "face", "head")
	return list

## drum face flash: short bronze impact lines either side of the face while glow > 0 (hero-attached frame)
func draw(ctx: RigCtx, _cam: RigCam, r: Rig, layer: String, _t: float) -> void:
	var g: float = r.pose.get("glow", 0.0)
	if layer != "front" or g <= 0.02:
		return
	var f := r.point("face")
	var r0 := 64.0 + (1.0 - g) * 22.0
	var r1 := r0 + 26.0 * g
	ctx.set_world(0.0)
	ctx.alpha = minf(1.0, g * 1.4)
	for a: float in [-172.0, -150.0, -30.0, -8.0]:
		var c := cos(a / 57.3)
		var s2 := sin(a / 57.3) * 0.55
		ctx.begin_path(); ctx.move_to(f.x + c * r0, f.y - 6.0 + s2 * r0); ctx.line_to(f.x + c * r1, f.y - 6.0 + s2 * r1)
		ctx.stroke(RigFx.INK, 10); ctx.stroke(BRONZE, 5)
	ctx.alpha = 1.0
