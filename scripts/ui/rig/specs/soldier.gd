extends RigSpec
## soldier "Đâm thương xuyên giáp" (docs/anim_demo/soldier.spec.js): step-in -> coil -> lunging thrust; the HIT fires
## the frame the spear tip crosses the target front, then a lance streak shoots through the target.

func events(_r: Rig) -> Array:
	var dmg: float = data.consts.DMG
	return [
		[130.0, func(a: Rig) -> void: a.dust(160, 244, 3, 1)],
		[230.0, func(a: Rig) -> void: a.gleam("tip", 115)],
		[345.0, func(a: Rig) -> void:
			a.dust(98, 244, 6, -1)
			a.sound("slash")
			a.add(Pierce.new(a, dmg))],
	]

func drive(name: String, p: Dictionary, vx: float, ctx: Dictionary) -> float:
	var idle: float = 1.0 if ctx.idle else 0.0
	if name == "crest":
		return clampf(vx * 0.035, -14, 30) + p.lean * 0.7 + p.head * 0.6 + idle * 1.8 * sin(ctx.clock / 700.0)
	if name == "tassel": # hangs with gravity (cancels spear angle) + trails the thrust
		return -(p.lean + p.arm + p.wrist) * 0.9 + clampf(vx * 0.03, -12, 40) + idle * 3.0 * sin(ctx.clock / 600.0)
	return 0.0

func idle(p: Dictionary, b: float, _clock: float) -> void:
	p.sy = 1.0 + 0.014 * b
	p.head = 1.5 * b
	p.arm = 1.5 * b
	p.wrist = -1.5 * b
	p.shield = -1.5 * b

## JS pierceFx: armed at thrust start; THE hit when the tip crosses the target front, then the lance through it.
## Speed lines: character frame (stay on the drawn spear). Lance + exit ring: target frame aimed along the real
## attack line (horizontal = the JS world drawing; up/down stay a lance, not a collapsed sliver).
class Pierce extends RefCounted:
	const INK := Color("#2b2220")
	var r: Rig
	var dmg: float
	var age := 0.0
	var hit := -1.0
	var x0 := 0.0
	var y0 := 0.0

	func _init(p_r: Rig, p_dmg: float) -> void:
		r = p_r
		dmg = p_dmg

	func upd(_s: float, ms: float) -> bool:
		age += ms
		if hit < 0.0:
			var tp := r.point("tip")
			# spear reach caps at the demo's range-1 front (rmax = 1; only off-range probes, e.g. diagonal, differ)
			if tp.x >= minf(float(r.target().front), 256.0 + r.data.target_front):
				hit = 0.0
				x0 = tp.x
				y0 = tp.y
				r.hit(Rig.with(Rig.HIT, { "dmg": dmg }))
		else:
			hit += ms
		return age < 900.0 and hit < 300.0

	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		var pre: float = minf(1.0, age / 30.0) if hit < 0.0 else maxf(0.0, 1.0 - hit / 140.0)
		if layer == "mid" and pre > 0.0:
			var root := Vector2(r.pose.x, r.pose.y)
			var tp := r.point("tip") - root
			var hd := r.point("hand") - root
			ctx.set_xf(cam.char_xf(r.pose.x, r.pose.y))
			ctx.alpha = pre
			for q: Array in [[-26.0, 0.05, 0.7], [24.0, 0.15, 0.8], [-48.0, 0.3, 0.62]]:
				var a := hd.lerp(tp, q[1])
				var b := hd.lerp(tp, q[2])
				ctx.begin_path()
				ctx.move_to(a.x - 40.0, a.y + q[0])
				ctx.line_to(b.x - 40.0, b.y + q[0])
				ctx.stroke(INK, 9)
				ctx.stroke("#fffdf4", 4)
			ctx.alpha = 1.0
		if layer != "front" or hit < 0.0:
			return
		# lance: shoots through the target and out the back (local x = world x - x0 along the attack line)
		var u := hit
		var grow := RigData.ease_by_name("outExpo", minf(1.0, u / 60.0))
		var k: float = 1.0 if u < 110.0 else maxf(0.0, 1.0 - (u - 110.0) / 190.0)
		var xs := -90.0
		var xm := 10.0
		var xe := 30.0 + 230.0 * grow
		var w := 24.0 * k + 2.0
		ctx.set_xf(cam.aimed(cam.map(x0, y0, 1.0), cam.u, cam.cd))
		ctx.alpha = minf(1.0, 0.35 + k)
		ctx.begin_path()
		ctx.move_to(xs, 0); ctx.line_to(xm, -w / 2.0); ctx.line_to(xe, 0); ctx.line_to(xm, w / 2.0); ctx.close_path()
		ctx.fill("#fffdf4"); ctx.stroke(INK, 5)
		ctx.begin_path()
		ctx.move_to(xs + 40.0, 0); ctx.line_to(xm, -w * 0.2); ctx.line_to(xe - 40.0, 0); ctx.line_to(xm, w * 0.2); ctx.close_path()
		ctx.fill("#ffe08a")
		# exit ring on the far side of the target
		var g := RigFx.out(minf(1.0, u / 160.0))
		var xr: float = float(r.target().x) + 46.0 + 30.0 * g - x0
		ctx.alpha = maxf(0.0, 1.0 - u / 260.0)
		ctx.begin_path()
		ctx.ellipse(xr, 0, 8.0 + 12.0 * g, 22.0 + 38.0 * g, 0, 0, TAU)
		ctx.stroke(INK, 11.0 * (1.0 - g) + 4.0)
		ctx.stroke("#fffdf4", 6.0 * (1.0 - g) + 1.5)
		ctx.alpha = 1.0
