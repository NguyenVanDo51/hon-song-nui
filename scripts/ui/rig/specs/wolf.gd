extends RigSpec
## wolf "Vồ cắn" (docs/anim_demo/wolf.spec.js): crouch -> pounce leap -> jaw-snap bite = THE hit (+3 red claw slashes)
## -> "weakened" puff on the target (poison cue) -> hop back.
## Target-attached fx draw in a frame at the target centre (local x = the art's forward): same as the JS world offsets
## for left / right, and the offsets stay screen-horizontal for up / down.

func events(_r: Rig) -> Array:
	return [
		[120.0, func(a: Rig) -> void: a.gleam("eye", 200)],
		[236.0, func(a: Rig) -> void: a.dust(70, 244, 7, -1)],
		[442.0, func(a: Rig) -> void:
			a.hit(Rig.HIT)
			a.add(Claw.new(a))],
		[620.0, func(a: Rig) -> void:
			# game poisons only on the wolf's own attack + survivor (game.gd); counters run at COUNTER_SPEED
			if not a.kill and a.time_scale != Rigs.COUNTER_SPEED:
				a.add(Weak.new(a))],
		[652.0, func(a: Rig) -> void: a.dust(200, 244, 4, 1)],
		[890.0, func(a: Rig) -> void: a.dust(128, 244, 6, 0)],
	]

func drive(name: String, p: Dictionary, vx: float, ctx: Dictionary) -> float:
	var idle_k: float = ctx.idle
	var ck: float = ctx.clock
	var ears: float = p.get("earsX", 0.0)
	if name == "tail":
		var tail_x: float = p.get("tailX", 0.0)
		return clampf(-vx * 0.035, -34, 16) + tail_x - p.pitch * 0.6 + idle_k * 9.0 * sin(ck / 170.0)
	if name == "earB":
		return clampf(-vx * 0.03, -30, 10) + ears - p.head * 0.4 + idle_k * 2.0 * sin(ck / 600.0)
	if name == "earF":
		return clampf(-vx * 0.035, -34, 10) + ears * 1.1 - p.head * 0.5 + idle_k * 2.5 * sin(ck / 600.0 + 1.0)
	return 0.0

func idle(p: Dictionary, b: float, _clock: float) -> void:
	p.sy = 1.0 + 0.016 * b
	p.head = 2.0 * b
	p.jaw = 3.0 * maxf(0.0, b)
	p.pitch = 0.6 * b

## speed streaks behind the leaping body (JS: world lines at hero().x - 70; here trailing along the real leap line)
func draw(ctx: RigCtx, cam: RigCam, r: Rig, layer: String, t: float) -> void:
	if layer != "mid" or t < 250.0 or t > 470.0:
		return
	var u := (t - 250.0) / 220.0
	var a := u / 0.2 if u < 0.2 else 1.0 - (u - 0.2) / 0.8
	var px: float = r.pose.x
	var py: float = r.pose.y
	var at := cam.root(px, py) + Vector2(0.0, (data.target_cy - data.feet) * cam.ca)
	ctx.set_xf(cam.aimed(at, cam.u, cam.ca))
	ctx.alpha = a
	for q: Array in [[-40.0, 110.0], [0.0, 150.0], [36.0, 90.0]]:
		var qy: float = q[0]
		var ql: float = q[1]
		ctx.begin_path()
		ctx.move_to(-70.0, qy)
		ctx.line_to(-70.0 - ql, qy)
		ctx.stroke(RigFx.INK, 10)
		ctx.stroke("#f4fcff", 5)
	ctx.alpha = 1.0

## 3 red bite/claw slashes on the target, staggered
class Claw extends RigFx.Timed:
	const LIFE := 360.0
	var col: Color
	func _init(p_r: Rig) -> void:
		r = p_r
		life = LIFE
		col = RigFx.col(r.data.consts.CLAW)
	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer != "front":
			return
		var c := r.target()
		var cx: float = c.x
		var cy: float = c.y
		var base := cam.frame(cx, cy, 1.0) # upright frame at the target centre (follows knockback / lift)
		for i in 3:
			var a := age - i * 28.0
			if a <= 0.0:
				continue
			var u := minf(1.0, a / (LIFE - 60.0))
			var slash_len := 170.0 * minf(1.0, a / 45.0)
			var w := 15.0 * (1.0 - u * u)
			if w <= 0.5:
				continue
			ctx.set_xf(base.translated_local(Vector2(-6.0 + (i - 1) * 30.0, -10.0 + (i - 1) * 6.0)).rotated_local(deg_to_rad(62.0)))
			ctx.begin_path()
			ctx.move_to(-slash_len / 2.0, 0.0)
			ctx.quad_to(0.0, -w, slash_len / 2.0, 0.0)
			ctx.quad_to(0.0, w, -slash_len / 2.0, 0.0)
			ctx.close_path()
			ctx.fill(col)
			ctx.stroke(RigFx.INK, 4)

## debuff (-10 atk / -10 def): dark-red puff + swirl on the bitten torso + 2 sinking down-arrows (below the dmg number)
class Weak extends RigFx.Timed:
	const LIFE := 950.0
	const PUFF := [[-30.0, 6.0, 20.0], [-8.0, -8.0, 26.0], [20.0, -2.0, 22.0], [34.0, 10.0, 15.0], [0.0, 12.0, 20.0]]
	var dark: Color
	var mid: Color
	var light: Color
	func _init(p_r: Rig) -> void:
		r = p_r
		life = LIFE
		var wk: Dictionary = r.data.consts.WEAK
		dark = RigFx.col(wk.dark)
		mid = RigFx.col(wk.mid)
		light = RigFx.col(wk.light)
	func _arrow(ctx: RigCtx, x: float, y: float, s: float) -> void:
		ctx.begin_path()
		ctx.move_to(x - 7 * s, y - 22 * s); ctx.line_to(x + 7 * s, y - 22 * s); ctx.line_to(x + 7 * s, y - 4 * s); ctx.line_to(x + 16 * s, y - 4 * s)
		ctx.line_to(x, y + 16 * s); ctx.line_to(x - 16 * s, y - 4 * s); ctx.line_to(x - 7 * s, y - 4 * s); ctx.close_path()
		ctx.fill(mid)
		ctx.stroke(RigFx.INK, 4)
	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer != "front":
			return
		var t := age
		var pop := RigData.ease_by_name("outBack", minf(1.0, t / 170.0))
		var fade := (LIFE - t) / 260.0 if t > LIFE - 260.0 else 1.0
		var c := r.target()
		var cx: float = c.x
		var cy: float = c.y
		var base := cam.frame(cx, cy, 1.0) # upright frame at the target centre (follows knockback / lift)
		# JS: x = c.x + 2, y = c.y + 4 + 10 * E.out(t / life), relative to the target centre here
		var x := 2.0
		var y := 4.0 + 10.0 * RigFx.out(t / LIFE)
		ctx.alpha = maxf(0.0, fade)
		ctx.set_xf(base.translated_local(Vector2(x, y)).scaled_local(Vector2(pop, pop)))
		ctx.begin_path()
		for q: Array in PUFF:
			var qx: float = q[0]
			var qy: float = q[1]
			var qr: float = q[2]
			ctx.move_to(qx + qr, qy)
			ctx.arc(qx, qy, qr, 0.0, TAU)
		ctx.stroke(RigFx.INK, 9)
		ctx.fill(dark)
		ctx.begin_path()
		for k in 41:
			var a := k / 40.0 * PI * 3.2 + t / 120.0
			var rr := 3.0 + k * 0.45
			ctx.line_to(cos(a) * rr * 1.3, 2.0 + sin(a) * rr)
		ctx.stroke(light, 4)
		var sink := 34.0 * RigFx.out(minf(1.0, t / 600.0))
		ctx.set_xf(base)
		_arrow(ctx, x - 74.0, -44.0 + sink, 1.2)
		_arrow(ctx, x + 76.0, -34.0 + sink * 0.8, 1.05)
		ctx.alpha = 1.0
