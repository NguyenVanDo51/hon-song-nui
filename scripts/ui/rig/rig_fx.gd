class_name RigFx
extends RefCounted
## engine.js VFX objects ported to GDScript: { upd(s, ms) -> alive, draw(ctx, cam, layer) } with layer back | mid | front.
## Positions stay in spec world units; RigCam maps them (see rig_cam.gd). Style = flat fill + INK outline, as the art.

const INK := Color("#2b2220")

static func out(u: float) -> float:
	return 1.0 - pow(1.0 - u, 3.0)

static func io(u: float) -> float:
	return RigData.ease_i(3, u)

## api.add({ upd = func(s, ms) -> bool, draw = func(ctx, cam, layer) }) from a spec port
class Custom extends RefCounted:
	var o: Dictionary
	func _init(p: Dictionary) -> void:
		o = p
	func upd(s: float, ms: float) -> bool:
		return o.upd.call(s, ms) if o.has("upd") else false
	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if o.has("draw"):
			o.draw.call(ctx, cam, layer)

## dust / leaf / spark; frame weight fixed where it was spawned (sparks at the target stay in the target frame)
class Particle extends RefCounted:
	var r: Rig
	var q: Dictionary
	var w := 0.0
	func _init(p_r: Rig, p_q: Dictionary) -> void:
		r = p_r
		q = p_q
		q.age = 0.0
		w = r.cam.w_of(q.x)
	func upd(s: float, ms: float) -> bool:
		q.age += ms
		if q.k == "leaf":
			q.vy += 520.0 * s
			q.vx *= 1.0 - 1.6 * s
			q.rot += q.vr * s
		elif q.k == "spark":
			q.vy += 400.0 * s
			q.vx *= 1.0 - 2.0 * s
		else:
			q.vx *= 1.0 - 3.0 * s
			q.vy *= 1.0 - 3.0 * s
		q.x += q.vx * s
		q.y += q.vy * s
		return q.age < q.life
	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer != "front":
			return
		var u: float = q.age / q.life
		if q.k == "leaf":
			ctx.set_xf(cam.frame(q.x, q.y, w).rotated_local(q.rot))
			ctx.alpha = 1.0 - u * u
			ctx.begin_path(); ctx.ellipse(0, 0, 11, 5, 0, 0, TAU); ctx.close_path()
			ctx.fill(q.color); ctx.stroke(INK, 3)
			ctx.begin_path(); ctx.move_to(-8, 0); ctx.line_to(8, 0); ctx.stroke(INK, 1.5)
		elif q.k == "spark":
			ctx.set_world(w)
			ctx.alpha = 1.0 - u
			ctx.begin_path(); ctx.move_to(q.x, q.y); ctx.line_to(q.x - q.vx * 0.04, q.y - q.vy * 0.04)
			ctx.stroke(INK, 8); ctx.stroke(q.color, 4)
		else:
			ctx.set_xf(cam.frame(q.x, q.y, w))
			ctx.alpha = (1.0 - u) * 0.9
			ctx.begin_path(); ctx.circle(0, 0, q.r * (1.0 + u * 1.2))
			ctx.fill("#efe3c8"); ctx.stroke(INK, 3)
		ctx.alpha = 1.0

## fixed-life fx base
class Timed extends RefCounted:
	var r: Rig
	var age := 0.0
	var life := 260.0
	func upd(_s: float, ms: float) -> bool:
		age += ms
		return age < life
	func draw(_ctx: RigCtx, _cam: RigCam, _layer: String) -> void:
		pass

## one-shot particle a spec spawns (wisp, droplet, ember, clod, debris): own position / velocity, front layer.
## w = frame weight fixed where it spawned (-1 = follow x along the default ramp every frame)
class Mote extends Timed:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var rr := 0.0
	var rot := 0.0
	var vr := 0.0
	var w := 0.0
	func upd(s: float, ms: float) -> bool:
		age += ms
		move(s)
		return alive()
	## one step of motion (age already advanced)
	func move(_s: float) -> void:
		pass
	func alive() -> bool:
		return age < life
	func xf(cam: RigCam) -> Transform2D:
		return cam.frame(x, y, w).rotated_local(rot)
	func fade() -> float:
		return 1.0
	## outline in the mote's own frame (fill + stroke)
	func shape(_ctx: RigCtx) -> void:
		pass
	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer != "front":
			return
		ctx.set_xf(xf(cam))
		ctx.alpha = fade()
		shape(ctx)
		ctx.alpha = 1.0

## frame weight of an fx travelling from x0: 0 at launch -> 1 at the target front
static func travel_w(r: Rig, x0: float, px: float) -> float:
	var front: float = r.target().front
	return clampf((px - x0) / maxf(1.0, front - x0), 0.0, 1.0)

## upright frame on a travelling fx (wave crescent, drum rings), local +x along its drawn path on the board
static func travel_xf(r: Rig, cam: RigCam, x0: float, x: float, y: float) -> Transform2D:
	var w := travel_w(r, x0, x)
	var at := cam.map(x, y, w)
	var dir := cam.map(x + 4.0, y, travel_w(r, x0, x + 4.0)) - at
	if dir.length_squared() < 0.0001:
		dir = cam.u
	return cam.aimed(at, dir, cam.k(w))

class Number extends Timed:
	var x: float
	var y: float
	var text: String
	var small: bool
	func _init(p_r: Rig, px: float, py: float, s: String, sm: bool) -> void:
		r = p_r; x = px; y = py; text = s; small = sm; life = 950.0
	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer != "front":
			return
		var a := age
		var u := a / 950.0
		var pop := 1.7 - 0.7 * RigFx.out(a / 120.0) if a < 120.0 else 1.0
		var s := (0.7 if small else 1.0) * pop
		var w := cam.w_of(x)
		ctx.set_world(w)
		ctx.alpha = 1.0 - (u - 0.75) / 0.25 if u > 0.75 else 1.0
		var col := Color("#ffd166") if r.kill and not small else (Color("#fff6d6") if small else Color.WHITE)
		# drawn at the pop's peak size and scaled down (no per-frame font size: glyph caches never free)
		ctx.text(x, y - 60.0 * RigFx.out(minf(1.0, a / 400.0)), text, 54.0 * 1.7, col, INK, 12.0 * 1.7, s / 1.7)
		ctx.alpha = 1.0

class Burst extends Timed:
	var x: float
	var y: float
	var sc: float
	func _init(p_r: Rig, px: float, py: float, s: float) -> void:
		r = p_r; x = px; y = py; sc = s; life = 260.0
	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer != "front":
			return
		var u := age / 260.0
		var R := (40.0 + 70.0 * RigFx.out(u)) * sc
		ctx.set_xf(cam.frame(x, y).rotated_local(deg_to_rad(22)))
		ctx.alpha = 1.0 - u * u
		ctx.begin_path()
		for i in 16:
			var rr := R * 0.42 if i % 2 else R
			var a := i * PI / 8.0
			ctx.line_to(cos(a) * rr, sin(a) * rr)
		ctx.close_path()
		ctx.fill("#fff6d6"); ctx.stroke(INK, 5)
		ctx.begin_path(); ctx.circle(0, 0, R * 0.3); ctx.fill("#e2c36e")
		ctx.alpha = 1.0

class Cut extends Timed:
	var x: float
	var y: float
	var ang: float
	func _init(p_r: Rig, px: float, py: float, a: float) -> void:
		r = p_r; x = px; y = py; ang = a; life = 260.0
	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer != "front":
			return
		var u := age / 260.0
		var len := 260.0 * minf(1.0, age / 50.0)
		var w := 12.0 * (1.0 - u)
		ctx.set_xf(cam.frame(x, y).rotated_local(deg_to_rad(ang)))
		ctx.begin_path(); ctx.move_to(-len / 2, 0); ctx.quad_to(0, -w, len / 2, 0); ctx.quad_to(0, w, -len / 2, 0); ctx.close_path()
		ctx.fill(Color.WHITE); ctx.stroke(INK, 4)

static func star4(ctx: RigCtx, s: float) -> void:
	ctx.begin_path()
	for i in 8:
		var rr := s * 0.22 if i % 2 else s
		var a := i * PI / 4.0
		ctx.line_to(cos(a) * rr, sin(a) * rr)
	ctx.close_path()

## sparkle on a character point (follows it: drawn in the character's own frame)
class Gleam extends Timed:
	var pt: String
	func _init(p_r: Rig, p_pt: String, ms: float) -> void:
		r = p_r; pt = p_pt; life = ms
	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer != "front":
			return
		var at := r.point_px(pt)
		var s := sin(age / life * PI) * 28.0
		ctx.set_xf(cam.at_px(at).rotated_local(deg_to_rad(r.clock * 0.3)))
		RigFx.star4(ctx, s); ctx.fill(Color.WHITE); ctx.stroke(INK, 3)

static func crescent(ctx: RigCtx, R: float, T: float, span: float) -> void:
	var n := 22
	ctx.begin_path()
	for i in n + 1:
		var u := -1.0 + 2.0 * i / n
		var a := u * span
		ctx.line_to(R * cos(a), R * sin(a))
	for i in range(n, -1, -1):
		var u := -1.0 + 2.0 * i / n
		var a := u * span
		var rr := R - T * (1.0 - u * u)
		ctx.line_to(rr * cos(a) - T * 0.5 * (1.0 - u * u), rr * sin(a))
	ctx.close_path()

## crescent blade flying toward the target; hits at the target front. Own frame weight: 0 at launch -> 1 at the front
class Wave extends RefCounted:
	var r: Rig
	var o: Dictionary
	var x: float
	var y: float
	var x0: float
	var vx: float
	var R: float
	var ang: float
	var fill: Color
	var inner: Color
	var age := 0.0
	var hit := false
	var gone := 0.0
	func _init(p_r: Rig, p_o: Dictionary) -> void:
		r = p_r; o = p_o
		x = o.x; x0 = x; y = o.get("y", r.data.target_cy); vx = o.get("vx", 1500.0); R = o.get("R", 120.0)
		ang = o.get("angle", -14.0); fill = Color(o.get("fill", "#f4fcff")); inner = Color(o.get("inner", "#a9e1f0"))
	func upd(s: float, ms: float) -> bool:
		age += ms
		x += vx * s
		if not hit and x >= r.target().front:
			hit = true
			if not (o.get("hit") is bool and o.hit == false):
				r.hit(o.get("hit", {}))
		if hit:
			gone += ms
		return gone < 220.0 and x < r.cam.xt + 700.0
	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer != "front":
			return
		var grow := minf(1.0, age / 70.0)
		var fade := 1.0 - gone / 220.0
		var sc := (0.6 + 0.4 * grow) * (1.0 + gone / 400.0)
		var m := RigFx.travel_xf(r, cam, x0, x, y).rotated_local(deg_to_rad(ang)).scaled_local(Vector2(sc, sc * (1.0 + 0.05 * sin(age / 25.0))))
		ctx.set_xf(m)
		ctx.alpha = fade
		var k := R / 120.0
		for dl: Array in [[-72, 130], [0, 190], [72, 120], [-36, 90], [38, 100]]:
			var xa := R - 50.0 * k
			var xb: float = xa - dl[1] * k * grow
			ctx.begin_path(); ctx.move_to(xa, dl[0] * k); ctx.line_to(xb, dl[0] * k)
			ctx.stroke(INK, 9); ctx.stroke(fill, 4)
		ctx.set_xf(m.translated_local(Vector2(-R + 30.0 * k, 0)))
		RigFx.crescent(ctx, R, 44.0 * k, 1.05); ctx.fill(fill); ctx.stroke(INK, 6)
		RigFx.crescent(ctx, R - 24.0 * k, 17.0 * k, 0.92); ctx.fill(inner)
		ctx.alpha = 1.0

## arrow | spear | rock | orb | custom (o.drawShape = func(ctx, size)). Starts exactly where the point is drawn,
## travels in board space to the target (arc = screen up), timing from world distance like the engine.
class Projectile extends RefCounted:
	var r: Rig
	var o: Dictionary
	var from: Vector2 # world
	var to: Vector2 # world
	var from_px: Vector2 # board px / T at launch
	var dur: float
	var kind: String
	var size: float
	var age := 0.0
	var done := false
	var trail: Array = [] # board px / T
	var at := Vector2.ZERO # board px / T
	var ang := 0.0
	func _init(p_r: Rig, p_o: Dictionary) -> void:
		r = p_r; o = p_o
		var T := r.cam.T
		if o.has("from"):
			var fv: Variant = o.from
			from = fv if fv is Vector2 else Vector2(fv.x, fv.y)
			from_px = r.cam.mapv(from) / T
		else:
			from = r.point(o.point)
			from_px = r.point_px(o.point) / T
		var tg := r.target()
		var tv: Variant = o.get("to", Vector2(tg.x, tg.y))
		to = tv if tv is Vector2 else Vector2(tv.x, tv.y)
		dur = o.get("ms", from.distance_to(to) / float(o.get("speed", 1400.0)) * 1000.0)
		kind = o.get("kind", "arrow")
		size = o.get("size", 24.0 if kind == "rock" else (20.0 if kind == "orb" else 1.0))
		at = from_px
	func pos_at(u: float) -> Vector2:
		var T := r.cam.T
		var a := from_px * T
		var b := r.cam.mapv(to, 1.0)
		var k := r.cam.k(u)
		return a.lerp(b, u) - Vector2(0.0, float(o.get("arc", 0.0)) * 4.0 * u * (1.0 - u) * k)
	func upd(_s: float, ms: float) -> bool:
		age += ms
		var u := minf(1.0, age / maxf(1.0, dur))
		var q := pos_at(u)
		var q2 := pos_at(minf(1.0, u + 0.02))
		if q2.distance_squared_to(q) > 0.0001:
			ang = (q2 - q).angle()
		at = q / r.cam.T
		trail.push_front(at)
		if trail.size() > 7:
			trail.resize(7)
		if u >= 1.0 and not done:
			done = true
			if not (o.get("hit") is bool and o.hit == false):
				r.hit(o.get("hit", {}))
			if o.has("onArrive"):
				o.onArrive.call(to)
			if kind == "rock":
				r.dust(to.x, r.data.feet, 8, 0.0)
				r.shake(14, 300)
		return not done
	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer != "front":
			return
		var T := cam.T
		var k := cam.k(minf(1.0, age / maxf(1.0, dur)))
		if trail.size() > 1:
			ctx.set_xf(Transform2D(0.0, Vector2(T, T), 0.0, Vector2.ZERO))
			ctx.begin_path()
			for i in trail.size():
				var p: Vector2 = trail[i]
				if i == 0:
					ctx.move_to(p.x, p.y)
				else:
					ctx.line_to(p.x, p.y)
			ctx.alpha = 0.7
			ctx.stroke(INK, 9.0 * k / T); ctx.stroke(o.get("trail", "#f4fcff"), 4.0 * k / T)
			ctx.alpha = 1.0
		var rot := age * 0.6 if kind == "rock" else 0.0
		var m := Transform2D(Vector2(k, 0), Vector2(0, k), at * T) * Transform2D(deg_to_rad(rot) if kind == "rock" else ang, Vector2.ZERO)
		ctx.set_xf(m)
		if o.has("drawShape"):
			o.drawShape.call(ctx, size)
		elif kind == "arrow" or kind == "spear":
			var L := 110.0 if kind == "spear" else 64.0
			var s := size
			ctx.begin_path(); ctx.move_to(-L * 0.7 * s, 0); ctx.line_to(L * 0.3 * s, 0); ctx.stroke(INK, 8); ctx.stroke("#9a6a3e", 3.5)
			ctx.begin_path(); ctx.move_to(L * 0.3 * s + 18 * s, 0); ctx.line_to(L * 0.3 * s - 2, -9 * s); ctx.line_to(L * 0.3 * s - 2, 9 * s); ctx.close_path()
			ctx.fill("#cdd4da"); ctx.stroke(INK, 3.5)
			if kind == "arrow":
				for sg: float in [-1.0, 1.0]:
					ctx.begin_path(); ctx.move_to(-L * 0.7 * s, 0); ctx.line_to(-L * 0.7 * s - 12 * s, sg * 10 * s); ctx.line_to(-L * 0.7 * s + 8 * s, sg * 2 * s); ctx.close_path()
					ctx.fill(o.get("color", "#c9503f")); ctx.stroke(INK, 3)
		elif kind == "rock":
			ctx.begin_path()
			for i in 9:
				var a := i / 9.0 * TAU
				var rr := size * (0.82 + 0.18 * sin(i * 2.7))
				ctx.line_to(cos(a) * rr, sin(a) * rr)
			ctx.close_path(); ctx.fill(o.get("color", "#9a8f84")); ctx.stroke(INK, 5)
			ctx.begin_path(); ctx.circle(-size * 0.3, -size * 0.3, size * 0.25); ctx.fill(Color(1, 1, 1, 0.35))
		else:
			var col := Color(o.get("color", "#8fe3ff"))
			ctx.begin_path(); ctx.circle(0, 0, size * 1.35); ctx.fill(Color(col, 0.33))
			ctx.begin_path(); ctx.circle(0, 0, size); ctx.fill(col); ctx.stroke(INK, 5)
			ctx.begin_path(); ctx.circle(-size * 0.3, -size * 0.3, size * 0.35); ctx.fill(Color.WHITE)

static func arc_run(ctx: RigCtx, cx: float, cy: float, rx: float, ry: float, a0: float, span: float, front: bool) -> void:
	var n := 18
	var open := false
	ctx.begin_path()
	for i in n + 1:
		var a := a0 + span * i / n
		var y := sin(a)
		var ok := y >= 0.0 if front else y < 0.0
		if ok:
			var X := cx + rx * cos(a)
			var Y := cy + ry * y
			if open:
				ctx.line_to(X, Y)
			else:
				ctx.move_to(X, Y)
			open = true
		else:
			open = false

## ink-edged stroke of the current path at this alpha (ctx.alpha left as it was)
static func band(ctx: RigCtx, lw: float, color: Color, alpha: float) -> void:
	var a0 := ctx.alpha
	ctx.alpha = alpha
	ctx.stroke(INK, lw + 5.0)
	ctx.stroke(color, lw)
	ctx.alpha = a0

## spin ring around the hero (hero frame)
class Ring extends Timed:
	var o: Dictionary
	func _init(p_r: Rig, p_o: Dictionary) -> void:
		r = p_r; o = p_o; life = o.get("ms", 540.0)
	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer == "back":
			return
		var a := age / 80.0 if age < 80.0 else ((life - age) / 120.0 if age > life - 120.0 else 1.0)
		var h := r.hero()
		var ph := age / life * TAU * float(o.get("turns", 2.0))
		var front := layer == "front"
		var col := Color(o.get("color", "#f4fcff"))
		var rx: float = o.get("rx", 150.0)
		var ry: float = o.get("ry", 38.0)
		ctx.set_world(0.0)
		for k in 3:
			RigFx.arc_run(ctx, h.x, float(o.get("y", 165.0)) + r.pose.y - k * 22, rx - k * 22, ry - k * 5, -ph * 1.2 + k * 2.1, 2.6, front)
			RigFx.band(ctx, 6 - k, col if front else Color("#cfeef6"), a * (1.0 if front else 0.6))
		ctx.alpha = 1.0

## tornado: grows at x0, travels to the target, lifts it + ticks, drops it (landing = final hit via target physics)
class Tornado extends RefCounted:
	var r: Rig
	var o: Dictionary
	var x0: float
	var travel: float
	var hold: float
	var lift: float
	var ticks: int
	var life: float
	var age := 0.0
	var fired := 0
	var lifted := false
	var released := false
	var x: float
	var s := 0.0
	func _init(p_r: Rig, p_o: Dictionary) -> void:
		r = p_r; o = p_o
		x0 = o.get("x0", 200.0); travel = o.get("travel", 320.0); hold = o.get("hold", 650.0); lift = o.get("lift", 95.0)
		ticks = o.get("ticks", 3); life = 180.0 + travel + hold + 270.0; x = x0
	func upd(_s: float, ms: float) -> bool:
		age += ms
		var t := age
		x = lerpf(x0, r.target().x - r.tgt.ox, RigFx.io(clampf(t / travel, 0.0, 1.0)))
		s = minf(1.0, t / 180.0) * (maxf(0.0, 1.0 - (t - travel - hold) / 270.0) if t > travel + hold else 1.0)
		if not lifted and t >= travel:
			lifted = true
			r.tgt.lift = { "h": lift, "t": 0.0, "ms": 520.0 }
		while fired < ticks and t >= travel + hold * (fired + 1) / (ticks + 1):
			fired += 1
			r.hit(Rig.with({ "dmg": 9, "small": true }, o.get("tick", {})))
		if not released and t >= travel + hold:
			released = true
			r.tgt.lift = null
			r.tgt.vy = -260.0
			r.tgt.land = Rig.with({ "dmg": 21, "kx": 0 }, o.get("final", {}))
		return t < life
	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer == "front" or s <= 0.0:
			return
		var front := layer == "mid"
		var ph := r.clock / 1000.0
		var by := r.data.feet - 4.0
		ctx.set_xf(cam.frame(x, by))
		var n := 9
		var bands := []
		for i in n:
			var h := float(i) / (n - 1)
			bands.append({ "cy": -i * 27.0 * s, "rx": (16 + 18 * h + 92 * h * h) * s, "ry": (6 + 22 * h * h) * s,
				"cx": sin(ph * 7 + i * 0.7) * 12 * h * s, "rot": -ph * 14 + i * 0.55 })
		if not front:
			ctx.begin_path()
			for i in n:
				var b: Dictionary = bands[i]
				ctx.line_to(b.cx - b.rx, b.cy)
			for i in range(n - 1, -1, -1):
				var b: Dictionary = bands[i]
				ctx.line_to(b.cx + b.rx, b.cy)
			ctx.close_path()
			ctx.fill(Color(0.886, 0.957, 0.976, 0.5)); ctx.stroke(Color(0.169, 0.133, 0.125, 0.35), 3)
		for b: Dictionary in bands:
			for kk in 2:
				RigFx.arc_run(ctx, b.cx, b.cy, b.rx, b.ry, b.rot + kk * PI, 2.2, front)
				RigFx.band(ctx, 6 * s + 1, Color("#f4fcff") if front else Color("#cfeef6"), 1.0 if front else 0.6)
		ctx.alpha = 1.0
		for j in 7:
			var b: Dictionary = bands[1 + (j % (n - 2))]
			var a := ph * 9 + j * 2.4
			var y := sin(a)
			if (y >= 0.0) != front:
				continue
			ctx.set_xf(cam.frame(x, by).translated_local(Vector2(b.cx + b.rx * cos(a), b.cy + b.ry * y)).rotated_local(deg_to_rad(a * 80)))
			ctx.begin_path(); ctx.ellipse(0, 0, 10 * s, 4.5 * s, 0, 0, TAU); ctx.close_path()
			ctx.fill("#7fb24e"); ctx.stroke(INK, 2.5)

## ground shockwave ring (stomps, slams, landings)
class Shock extends Timed:
	var x: float
	var y: float
	var R: float
	var col: Color
	func _init(p_r: Rig, px: float, py: float, o: Dictionary) -> void:
		r = p_r; x = px; y = py; life = o.get("ms", 380.0); R = o.get("r", 170.0); col = Color(o.get("color", "#f4ead0"))
	func draw(ctx: RigCtx, cam: RigCam, layer: String) -> void:
		if layer != "front":
			return
		var u := age / life
		var rr := 20.0 + R * RigFx.out(u)
		ctx.set_xf(cam.frame(x, y))
		ctx.alpha = 1.0 - u
		ctx.begin_path(); ctx.ellipse(0, 0, rr, rr * 0.28, 0, 0, TAU); ctx.close_path()
		ctx.stroke(INK, 11.0 * (1.0 - u) + 3.0); ctx.stroke(col, 6.0 * (1.0 - u) + 1.0)
		ctx.alpha = 1.0
