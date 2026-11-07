extends RigSpec
## Tu Sĩ Ánh Sáng "Đèn thánh, chùy phán xét" (docs/anim_demo/drum.spec.js).
## Raise the lantern high -> holy light ring bursts out (no damage) -> step in + mace bonk (THE hit).

const GOLD := "#e2c36e"
const PALE := "#fff6d6"

## JS holyBurst(): one warm ring + short rays expanding from the lantern (hero-attached, world coords)
class HolyBurst extends RigFx.Timed:
	var c: Vector2

	func _init(p_r: Rig) -> void:
		r = p_r
		life = 440.0
		c = r.point("lamp")

	func draw(ctx: RigCtx, _cam: RigCam, layer: String) -> void:
		if layer != "front":
			return
		var u := age / life
		var rr := 24.0 + 150.0 * RigFx.out(u)
		var r0 := rr + 8.0
		var r1 := r0 + 8.0 + 26.0 * (1.0 - u)
		ctx.set_world(0.0)
		ctx.alpha = 1.0 - u * u
		ctx.begin_path()
		ctx.arc(c.x, c.y, rr, 0.0, TAU)
		ctx.stroke(RigFx.INK, 11.0)
		ctx.stroke(PALE, 6.0)
		ctx.stroke(GOLD, 2.5)
		for k in 10:
			var a := k * PI / 5.0 + 0.3
			var cs := cos(a)
			var sn := sin(a)
			ctx.begin_path()
			ctx.move_to(c.x + cs * r0, c.y + sn * r0)
			ctx.line_to(c.x + cs * r1, c.y + sn * r1)
			ctx.stroke(RigFx.INK, 8.0)
			ctx.stroke(PALE, 4.0)
		ctx.alpha = 1.0

func events(_r: Rig) -> Array:
	var t_burst: float = data.consts.BURST
	var t_bonk: float = data.consts.BONK
	return [
		[
			120.0,
			func(a: Rig) -> void:
				a.dust(110, 244, 4, -1),
		],
		[
			t_burst,
			func(a: Rig) -> void:
				a.add(HolyBurst.new(a))
				var l := a.point("lamp")
				a.sparks(l.x, l.y, 8, GOLD)
				a.flash(PALE, 60)
				a.shake(3, 120)
				a.sound("orb"),
		],
		[
			t_bonk,
			func(a: Rig) -> void:
				a.hit(Rig.with(Rig.HIT, { "dmg": 30 }))
				var m := a.point("maceHead")
				a.sparks(m.x, m.y, 6, GOLD)
				a.dust(150, 244, 6, 1),
		],
	]

func drive(name: String, p: Dictionary, vx: float, ctx: Dictionary) -> float:
	var idle_k: float = ctx.idle
	var ck: float = ctx.clock
	if name == "tails":
		return clampf(vx * 0.03, -14, 30) - p.lean * 0.8 + idle_k * 2.0 * sin(ck / 650.0)
	if name == "lamp": # hangs plumb (cancels arm + body tilt) and trails the motion
		return -(p.armB + p.lean) + clampf(vx * 0.04, -20, 20) + idle_k * 2.5 * sin(ck / 700.0)
	return 0.0

func idle(p: Dictionary, b: float, _clock: float) -> void:
	p.sy = 1.0 + 0.014 * b
	p.head = 1.5 * b
	p.armB = 2.0 * b
	p.armF = -2.0 * b
	p.wristF = 1.5 * b

## mace cocked over the head: draw the face under the arm
func order(p: Dictionary, list: Array) -> Array:
	var af: float = p.armF
	if af < -40.0:
		return part_after(list, "face", "head")
	return list

## lantern halo: soft warm discs + 4 short glints around the lantern while glow > 0 (hero-attached frame)
func draw(ctx: RigCtx, _cam: RigCam, r: Rig, layer: String, _t: float) -> void:
	var g: float = r.pose.get("glow", 0.0)
	if layer != "front" or g <= 0.02:
		return
	var l := r.point("lamp")
	ctx.set_world(0.0)
	ctx.alpha = 0.28 * g
	ctx.begin_path()
	ctx.arc(l.x, l.y, 22.0 + 14.0 * g, 0.0, TAU)
	ctx.fill(PALE)
	ctx.alpha = 0.5 * g
	ctx.begin_path()
	ctx.arc(l.x, l.y, 12.0 + 8.0 * g, 0.0, TAU)
	ctx.fill(PALE)
	ctx.alpha = minf(1.0, g * 1.4)
	var r0 := 28.0 + 6.0 * g
	var r1 := r0 + 14.0 * g
	for a: float in [-90.0, 0.0, 90.0, 180.0]:
		var c := cos(a / 57.3)
		var s2 := sin(a / 57.3)
		ctx.begin_path()
		ctx.move_to(l.x + c * r0, l.y + s2 * r0)
		ctx.line_to(l.x + c * r1, l.y + s2 * r1)
		ctx.stroke(RigFx.INK, 9.0)
		ctx.stroke(GOLD, 4.5)
	ctx.alpha = 1.0
