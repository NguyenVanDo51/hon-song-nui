extends RigSpec
## dragon "Phun lửa" (docs/anim_demo/bird.spec.js): inhale (neck rears, mouth glow) -> fire cone mouth -> target,
## 3 burn ticks (small) + THE hit, embers. Cone aimed in board px: mouth as drawn -> real target token, any direction.

# ---------- fire cone (JS fireShape / drawFire / fireFx) ----------
## flat fire tongue along +x from s0..s1 (local), half-width min(70, 9 + .4 s) * wk * k, scalloped edge scrolling out
static func fire_shape(ctx: RigCtx, s0: float, s1: float, wk: float, t: float, k: float) -> void:
	var n := 22
	var top: Array[Vector2] = []
	var bot: Array[Vector2] = []
	for i in n + 1:
		var s := lerpf(s0, s1, float(i) / n)
		var ww := minf(70.0, 9.0 + 0.4 * s) * wk * k
		var ramp := minf(1.0, (s - s0) / 30.0)
		var sc := absf(sin((s - t * 0.32) / 15.0)) * 7.0 * k * ramp
		top.append(Vector2(s, -ww - sc))
		bot.append(Vector2(s, ww + absf(sin((s - t * 0.27) / 13.0 + 1.0)) * 6.0 * k * ramp))
	ctx.begin_path()
	ctx.move_to(s0, 0)
	for q in top:
		ctx.line_to(q.x, q.y)
	var R := minf(70.0, 9.0 + 0.4 * s1) * wk * k # rounded, lobed front
	for j in range(1, 9):
		var a := -PI / 2.0 + PI * j / 9.0
		var r := R * (1.25 if j % 2 else 0.85) + 4.0 * sin(t * 0.05 + j)
		ctx.line_to(s1 + cos(a) * r * 0.9, sin(a) * r)
	for i in range(n, -1, -1):
		ctx.line_to(bot[i].x, bot[i].y)
	ctx.close_path()

## cone from the mouth gap (as drawn) to just past the target token; pure function of attack time t
func draw_fire(ctx: RigCtx, cam: RigCam, r: Rig, t: float) -> void:
	var c := data.consts
	var t_fire: float = c.T_FIRE
	var t_full: float = c.T_FULL
	var t_end: float = c.T_END
	var t_gone: float = c.T_GONE
	if t < t_fire or t > t_gone:
		return
	var fire: Dictionary = c.FIRE
	var m := (r.point_px("lipU") + r.point_px("lipD")) * 0.5
	var tg := r.target()
	var d := cam.map(tg.x + 40.0, tg.y + 6.0, 1.0) - m
	var L := d.length() / cam.ca # local units (1 = attacker art unit) -> tip lands on the target token
	var grow := RigData.ease_i(4, clampf((t - t_fire) / (t_full - t_fire), 0.0, 1.0))
	var gone := RigData.ease_i(2, clampf((t - t_end) / (t_gone - t_end), 0.0, 1.0))
	var s1 := L * grow + 30.0 * gone
	var s0 := 8.0 + (L - 20.0) * gone
	if s1 - s0 < 6.0:
		return
	var pulse := 1.0 + 0.22 * maxf(0.0, 1.0 - absf(t - 700.0) / 40.0) + 0.05 * sin(t * 0.07)
	var wk := pulse * (1.0 - 0.5 * gone)
	ctx.set_xf(cam.aimed(m, d, cam.ca))
	ctx.alpha = 0.3
	fire_shape(ctx, s0, s1, wk, t, 1.35); ctx.fill(fire.mid) # faint halo
	ctx.alpha = 1.0
	fire_shape(ctx, s0, s1, wk, t, 1.0); ctx.fill(fire.out); ctx.stroke(RigFx.INK, 6)
	fire_shape(ctx, s0 + 4.0, s0 + (s1 - s0) * 0.92, wk, t + 90.0, 0.64); ctx.fill(fire.mid)
	fire_shape(ctx, s0 + 8.0, s0 + (s1 - s0) * 0.74, wk, t + 200.0, 0.3); ctx.fill(fire.core)

## fire cone as an fx added at T_FIRE: drawn before later hit fx (burst / number stay over the flame)
func fire_fx(a: Rig) -> void:
	var t_gone: float = data.consts.T_GONE
	a.add({
		"upd": func(_s: float, _ms: float) -> bool: return a.t <= t_gone and a.t > 0.0,
		"draw": func(ctx: RigCtx, cam: RigCam, layer: String) -> void:
			if layer == "front" and a.t <= t_gone and a.t > 0.0:
				draw_fire(ctx, cam, a, a.t),
	})

## flat flame ball with ink outline (mouth glow); frame = upright at the mouth, highlight stays top-left
func orb(ctx: RigCtx, cam: RigCam, at: Vector2, r: float) -> void:
	var fire: Dictionary = data.consts.FIRE
	ctx.set_xf(cam.at_px(at))
	ctx.alpha = 0.35
	ctx.begin_path(); ctx.circle(0, 0, r * 1.7); ctx.fill(fire.mid)
	ctx.alpha = 1.0
	ctx.begin_path(); ctx.circle(0, 0, r); ctx.fill(fire.out); ctx.stroke(RigFx.INK, 4)
	ctx.begin_path(); ctx.circle(0, 0, r * 0.62); ctx.fill(fire.mid)
	ctx.begin_path(); ctx.circle(-r * 0.15, -r * 0.15, r * 0.3); ctx.fill(fire.core)

## rising embers at the target after the final hit (own state -> add); pinned to the target frame (w = 1)
func embers(a: Rig, n: int) -> void:
	var fire: Dictionary = data.consts.FIRE
	var c := a.target()
	for i in n:
		var m := Ember.new()
		m.x = c.x + randf_range(-55, 55)
		m.y = c.y + randf_range(-50, 20)
		m.vx = randf_range(-60, 60)
		m.vy = randf_range(-360, -160)
		m.rr = randf_range(6, 10)
		m.rot = randf_range(0, 6)
		m.vr = randf_range(-6, 6)
		m.life = randf_range(650, 1050)
		m.col = Color(fire.out if i % 2 else fire.mid)
		m.w = 1.0
		a.add(m)

class Ember extends RigFx.Mote:
	var col: Color
	func move(s: float) -> void:
		x += (vx + 30.0 * sin(age / 120.0)) * s
		y += vy * s
		vy *= 1.0 - 0.8 * s
		rot += vr * s
	func fade() -> float:
		var u := age / life
		return 1.0 - u * u
	func shape(ctx: RigCtx) -> void:
		var rad := rr * (1.0 - age / life * 0.6)
		ctx.begin_path(); ctx.move_to(0, -rad * 1.5); ctx.line_to(rad, 0); ctx.line_to(0, rad); ctx.line_to(-rad, 0); ctx.close_path()
		ctx.fill(col); ctx.stroke(RigFx.INK, 3)

# ---------- RigSpec ----------
func events(_r: Rig) -> Array:
	var c := data.consts
	var t_fire: float = c.T_FIRE
	var fire: Dictionary = c.FIRE
	return [
		[120.0, func(a: Rig) -> void: a.gleam("lipU", 200)],
		[300.0, func(a: Rig) -> void: a.shake(3, 120)],
		[t_fire - 20.0, func(a: Rig) -> void: a.flash(fire.mid, 50)],
		[t_fire, func(a: Rig) -> void:
			a.sound("orb")
			fire_fx(a)],
		[450.0, func(a: Rig) -> void: a.hit(Rig.with(Rig.HIT_SMALL, { "dmg": 8 }))],
		[540.0, func(a: Rig) -> void: a.hit(Rig.with(Rig.HIT_SMALL, { "dmg": 8 }))],
		[630.0, func(a: Rig) -> void: a.hit(Rig.with(Rig.HIT_SMALL, { "dmg": 8 }))],
		[705.0, func(a: Rig) -> void: a.hit(Rig.with(Rig.HIT, { "dmg": 50 }))],
		[720.0, func(a: Rig) -> void:
			embers(a, 12)
			a.sparks(a.target().x, a.target().y, 6, fire.out)],
	]

## body wave: hump / tail / fin springs lag the neck snap and swing through
func drive(name: String, p: Dictionary, vx: float, ctx: Dictionary) -> float:
	var idle_k: float = ctx.idle
	var ck: float = ctx.clock
	var neck: float = p.neck
	match name:
		"hump":
			return -neck * 0.35 + float(p.get("humpT", 0.0)) + idle_k * 1.5 * sin(ck / 520.0)
		"tail":
			return neck * 0.5 - clampf(vx * 0.02, -10, 10) + idle_k * 3.0 * sin(ck / 520.0 - 1.2)
		"flame":
			return -neck * 0.4 + idle_k * 5.0 * sin(ck / 300.0)
		"fin":
			return -neck * 0.45 - clampf(vx * 0.03, -14, 14) + idle_k * 3.0 * sin(ck / 420.0)
		"mane":
			return -(neck + float(p.head)) * 0.3 - clampf(vx * 0.03, -14, 14) + idle_k * 2.0 * sin(ck / 600.0)
	return 0.0

func idle(p: Dictionary, b: float, _clock: float) -> void:
	p.hover = -2.5 * b
	p.neck = 2.0 * b
	p.head = -1.5 * b
	p.arm = 2.0 * b

## inhale glow in the mouth: stateless (pure of t). Streaks point ahead of the facing (x basis carries f)
func draw(ctx: RigCtx, cam: RigCam, r: Rig, layer: String, t: float) -> void:
	var c := data.consts
	var t_fire: float = c.T_FIRE
	var t_end: float = c.T_END
	if layer != "front" or t < 90.0 or t > t_end + 60.0:
		return
	var fire: Dictionary = c.FIRE
	var m := (r.point_px("throatU") + r.point_px("throatD")) * 0.5
	if t < t_fire: # air streaks sucked into the mouth
		ctx.set_xf(cam.at_px(m, cam.ca, true))
		for i in 5:
			var ph := fposmod((t - 90.0) / 240.0 + i / 5.0, 1.0)
			var dd := 110.0 * (1.0 - ph) + 16.0
			var a := -0.9 + i * 0.42
			ctx.alpha = sin(ph * PI)
			ctx.begin_path()
			ctx.move_to(cos(a) * dd, sin(a) * dd)
			ctx.line_to(cos(a) * (dd + 26.0), sin(a) * (dd + 26.0))
			ctx.stroke(RigFx.INK, 8); ctx.stroke(fire.core, 4)
		ctx.alpha = 1.0
	var rr: float
	if t < t_fire:
		rr = 3.0 + 8.0 * RigData.ease_i(1, clampf((t - 120.0) / 200.0, 0.0, 1.0))
	else:
		rr = 11.0 * (1.0 - clampf((t - t_end) / 60.0, 0.0, 1.0))
	if rr > 1.0:
		orb(ctx, cam, m, rr * (1.0 + 0.08 * sin(t * 0.09)))
