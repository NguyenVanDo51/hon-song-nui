extends RigSpec
## shaman "Gọi hồn" (docs/anim_demo/shaman.spec.js): chant (staff raised, glyph ring at the feet, wisps) -> staff thrust
## -> 3 soul flames spiral into the target: 2 small ticks + THE hit. Impact = shared HIT only (no extra dissolve).

const SPIRIT := Color("#8fe39a")
const SPIRIT_PALE := Color("#e6ffe9")
const GLOW := Color(0.561, 0.89, 0.604, 0.22) # rgba(143,227,154,.22)
const RING_BACK := Color("#b9efc0")

static func wob(t: float, a: float, b: float, amp: float, per: float) -> float:
	return amp * sin((t - a) / per) if t > a and t < b else 0.0

func events(_r: Rig) -> Array:
	var c := data.consts
	var t_thrust: float = c.T_THRUST
	var ring: Dictionary = c.RING
	var ring_x: float = ring.x
	var ring_y: float = ring.y
	var ev := [
		[250.0, func(a: Rig) -> void: a.gleam("top")],
		[t_thrust - 20.0, func(a: Rig) -> void: a.flash(SPIRIT_PALE, 45)],
		[t_thrust, func(a: Rig) -> void:
			var q := a.point("tip")
			a.sound("orb")
			a.sparks(q.x, q.y, 7, "#8fe39a")
			a.shockwave(ring_x, ring_y, { "r": 150.0, "ms": 360.0, "color": "#8fe39a" })],
	]
	var flames: Array = c.FLAMES
	for i in flames.size():
		var f: Dictionary = flames[i]
		# only the last flame is THE hit (shared look); the others are ticks
		var hit := Rig.with(Rig.HIT if i == flames.size() - 1 else Rig.HIT_SMALL, {})
		var ft: float = f.t
		ev.append([ft, func(a: Rig) -> void: a.add(SoulFlame.new(a, f, hit))])
	return ev

func drive(name: String, p: Dictionary, vx: float, ctx: Dictionary) -> float:
	if name == "plume":
		var idle_k: float = ctx.idle
		var ck: float = ctx.clock
		return clampf(-vx * 0.035, -26, 14) - p.lean * 0.5 - p.head * 0.4 + idle_k * 2.0 * sin(ck / 700.0)
	return 0.0

func idle(p: Dictionary, b: float, _clock: float) -> void:
	p.sy = 1.0 + 0.014 * b
	p.head = 1.5 * b
	p.arm = 1.5 * b
	p.wrist = -1.5 * b
	p.armB = 2.0 * b

# ---------- shapes ----------
## flame drawing, shared by the attack draw and SoulFlame (an inner class cannot call the outer static funcs)
class Fl extends RefCounted:
	## soul flame: teardrop pointing along +x, wavy tail
	static func flame_shape(ctx: RigCtx, s: float, w: float) -> void:
		ctx.begin_path()
		ctx.arc(0, 0, s, -PI / 2, PI / 2)
		ctx.quad_to(-1.5 * s, 1.1 * s, -3.1 * s, w * s)
		ctx.quad_to(-2.2 * s, 0.1 * s, -1.9 * s, -0.35 * s)
		ctx.quad_to(-2.4 * s, -0.9 * s, -2.7 * s, -1.15 * s)
		ctx.quad_to(-1.2 * s, -1.25 * s, 0, -s)
		ctx.close_path()

	## JS drawFlame with the frame given: m = translate(x, y).rotate(ang); up = translate(x, y) (eyes stay upright)
	static func draw_flame(ctx: RigCtx, m: Transform2D, up: Transform2D, s: float, w: float, alpha: float, eyes: bool) -> void:
		ctx.set_xf(m)
		ctx.alpha = alpha
		ctx.begin_path(); ctx.circle(0, 0, s * 1.7); ctx.fill(GLOW)
		Fl.flame_shape(ctx, s, w); ctx.fill(SPIRIT); ctx.stroke(RigFx.INK, 5)
		ctx.set_xf(m.translated_local(Vector2(s * 0.2, 0)))
		Fl.flame_shape(ctx, s * 0.55, w); ctx.fill(SPIRIT_PALE)
		if eyes:
			ctx.set_xf(up)
			for ex: float in [-s * 0.28, s * 0.3]:
				ctx.begin_path(); ctx.ellipse(ex, -s * 0.05, s * 0.13, s * 0.2, 0, 0, TAU); ctx.fill(RigFx.INK)
		ctx.alpha = 1.0

## elliptic arc on the near (front) or far half
static func arc_half(ctx: RigCtx, cx: float, cy: float, rx: float, ry: float, front: bool) -> void:
	ctx.begin_path()
	if front:
		ctx.ellipse(cx, cy, rx, ry, 0, 0, PI)
	else:
		ctx.ellipse(cx, cy, rx, ry, 0, PI, TAU)

## Đông Sơn-ish marks: concentric circle, S-spiral, chevron (stroke INK w3 set by the caller in JS)
static func glyph(ctx: RigCtx, k: int, s: float) -> void:
	ctx.begin_path()
	if k == 0:
		ctx.arc(0, 0, s, 0, TAU); ctx.fill(SPIRIT_PALE); ctx.stroke(RigFx.INK, 3)
		ctx.begin_path(); ctx.arc(0, 0, s * 0.4, 0, TAU); ctx.fill(RigFx.INK)
		return
	if k == 1:
		ctx.arc(-s * 0.5, 0, s * 0.5, PI, 0)
		ctx.arc(s * 0.5, 0, s * 0.5, PI, 0, true)
	else:
		ctx.move_to(-s, s * 0.6); ctx.line_to(0, -s * 0.6); ctx.line_to(s, s * 0.6)
	ctx.stroke(RigFx.INK, 7); ctx.stroke(SPIRIT_PALE, 3.5)

# ---------- attack draw: glyph ring at the feet + rising wisps + spirit gathering on the bronze bird ----------
## stateless (pure function of t). Hero-attached: every point in the hero frame (w = 0).
## near half = front layer; far half (JS mid) under the shaman itself, so it never covers its feet (dir=down)
func draw(ctx: RigCtx, cam: RigCam, r: Rig, layer: String, t: float) -> void:
	if layer == "front":
		_ring(ctx, cam, r, t, true)

func draw_char_under(ctx: RigCtx, cam: RigCam, r: Rig) -> void:
	_ring(ctx, cam, r, r.t, false)

func _ring(ctx: RigCtx, cam: RigCam, r: Rig, t: float, front: bool) -> void:
	var c := data.consts
	var ring: Dictionary = c.RING
	var t0: float = ring.t0
	var t1: float = ring.t1
	var t_thrust: float = c.T_THRUST
	if t < t0 or t > t1:
		return
	var RX: float = ring.x
	var RY: float = ring.y
	var g := RigData.ease_i(5, clampf((t - t0) / 200.0, 0.0, 1.0))
	var fade := (t1 - t) / 260.0 if t > t1 - 260.0 else 1.0
	var pulse := maxf(0.0, 1.0 - (t - t_thrust + 20.0) / 260.0) if t > t_thrust - 20.0 else 0.0
	var rx := 100.0 * g * (1.0 + 0.18 * pulse)
	var ry := 26.0 * g * (1.0 + 0.18 * pulse)
	var rot := t / 1000.0 * 2.4
	ctx.set_world(0.0)
	if not front:
		ctx.alpha = 0.28 * fade * (1.0 + pulse)
		ctx.begin_path(); ctx.ellipse(RX, RY, rx, ry, 0, 0, TAU); ctx.close_path()
		ctx.fill(SPIRIT)
	for kw: Array in [[1.0, 6.0], [0.7, 4.0]]:
		var k: float = kw[0]
		var w: float = kw[1]
		arc_half(ctx, RX, RY, rx * k, ry * k, front)
		ctx.alpha = fade * (1.0 if front else 0.75)
		ctx.stroke(RigFx.INK, w + 5.0)
		ctx.stroke(SPIRIT if front else RING_BACK, w)
	for k in 8:
		var a := rot + k * PI / 4.0
		var sy := sin(a)
		if (sy >= 0.0) != front:
			continue
		ctx.set_xf(cam.frame(RX + cos(a) * rx * 0.85, RY + sy * ry * 0.85, 0.0).scaled_local(Vector2(1.0, 0.55)))
		ctx.alpha = fade
		glyph(ctx, k % 3, 9.0 * g)
	# wisps rising from the ring while the spell gathers
	for k in 6:
		var st := 140.0 + k * 55.0
		var per := 380.0
		var n := floorf((t - st) / per)
		if t < st or st + n * per > 470.0:
			continue
		var u := (t - st - n * per) / per
		var a := k * 1.9 + 0.4
		var z := sin(a)
		if (z >= 0.0) != front:
			continue
		var m := cam.frame(RX + cos(a) * 82.0, RY + z * 20.0 - u * 150.0, 0.0)
		Fl.draw_flame(ctx, m.rotated_local(deg_to_rad(-90.0)), m, 9.0 * (1.0 - u * 0.6), 0.3 * sin(t / 40.0 + k), (1.0 - u) * fade, false)
	# spirit gathering on the bronze bird while chanting (becomes the burst)
	if front and t > 240.0 and t < t_thrust:
		var u := clampf((t - 240.0) / 260.0, 0.0, 1.0)
		var m := cam.at_px(r.point_px("top"), cam.ca, true).translated_local(Vector2(2.0, -20.0 - 6.0 * u))
		Fl.draw_flame(ctx, m.rotated_local(deg_to_rad(-90.0)), m, 5.0 + 8.0 * RigFx.out(u) + 1.2 * sin(t / 35.0), 0.3 * sin(t / 40.0), fade, false)
	ctx.alpha = 1.0

## one soul flame: bursts up/forward from the staff tip along a bezier, spiralling, then dives into the target.
## World path as the JS; own frame weight w = path progress (0 at the drawn tip -> 1 on the target token).
class SoulFlame extends RigFx.Fx:
	const MS := 330.0
	const R := 30.0
	var r: Rig
	var f: Dictionary
	var hit: Dictionary
	var P0: Vector2
	var P1: Vector2
	var P2: Vector2
	var off0: Vector2 # (drawn tip px - mapped tip px) / T at launch, faded out along the path
	var age := 0.0
	var done := false
	var x: float
	var y: float
	var w := 0.0
	var z := 1.0
	var trail: Array = [] # [x, y, w] world
	var head := Vector3.ZERO # previous [x, y, w] for the heading (JS st.ang from the last step)
	var has_head := false

	func _init(p_r: Rig, p_f: Dictionary, p_hit: Dictionary) -> void:
		r = p_r; f = p_f; hit = p_hit
		P0 = r.point("tip")
		var tg := r.target()
		var tx: float = tg.x
		var ty: float = tg.y
		P2 = Vector2(tx - 8.0, ty - 6.0)
		var fcx: float = f.cx
		var fcy: float = f.cy
		P1 = P0 + Vector2(fcx, fcy)
		x = P0.x; y = P0.y
		off0 = (r.point_px("tip") - r.cam.mapv(P0, 0.0)) / r.cam.T

	func bez(u: float) -> Vector2:
		return P0 * (1.0 - u) * (1.0 - u) + P1 * 2.0 * u * (1.0 - u) + P2 * u * u

	func px(q: Vector3) -> Vector2:
		var cam := r.cam
		return cam.map(q.x, q.y, q.z) + off0 * cam.T * (1.0 - q.z)

	func upd(_s: float, dt: float) -> bool:
		age += dt
		if done:
			return false # impact = shared HIT only (same for every unit)
		var u := minf(1.0, age / MS)
		var uu := RigFx.io(u) * 0.35 + u * 0.65
		var b := bez(uu)
		var b2 := bez(minf(1.0, uu + 0.02))
		var tv := b2 - b
		var L := tv.length()
		if L == 0.0:
			L = 1.0
		var fph: float = f.ph
		var ph: float = fph + uu * PI * 3.2
		var o := R * pow(sin(PI * uu), 0.7) * sin(ph)
		var nx := b.x - tv.y / L * o
		var ny := b.y + tv.x / L * o
		if age > 8.0:
			head = Vector3(x, y, w)
			has_head = true
		x = nx; y = ny; w = uu; z = cos(ph)
		trail.push_front(Vector3(nx, ny, uu))
		if trail.size() > 9:
			trail.resize(9)
		if u >= 1.0:
			done = true
			r.hit(hit)
		return true

	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer != "front" or done:
			return
		var k := cam.k(w)
		ctx.set_xf(Transform2D.IDENTITY)
		if trail.size() > 1:
			ctx.begin_path()
			for i in trail.size():
				var q: Vector3 = trail[i]
				var p := px(q)
				if i == 0:
					ctx.move_to(p.x, p.y)
				else:
					ctx.line_to(p.x, p.y)
			ctx.alpha = 0.75
			ctx.stroke(RigFx.INK, 13.0 * k); ctx.stroke(SPIRIT, 7.0 * k)
			ctx.alpha = 1.0
		var grow := minf(1.0, age / 60.0)
		var s := 20.0 * (0.88 + 0.16 * z) * (0.5 + 0.5 * grow)
		var at := px(Vector3(x, y, w))
		var dir := Vector2(cam.f, 0.0) # JS ang 0 until the first step: forward
		if has_head:
			var d := at - px(head)
			if d.length_squared() > 0.0001:
				dir = d
		var up := cam.at_px(at, k, true)
		Fl.draw_flame(ctx, cam.aimed(at, dir, k), up, s, 0.25 * sin(age / 30.0), 1.0, true)
