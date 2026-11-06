extends RigSpec
## Âm binh "Âm kiếm" (docs/anim_demo/ghost.spec.js): broken sword grows a spectral blade, drift-forward purple slash
## (wave = THE hit), afterimage echoes of the full token on the drift, fade-drift back.

const SPIRIT := "#b48cff"
const SPIRIT_CORE := "#f1eaff"
const GHOST := "#d9d4f0"

var _x_keys: Array = [] # consts.X: drift track shared by tr.x and the afterimage hook

func events(_r: Rig) -> Array:
	var dmg := 45.0 # spec value; the game shows the real amount
	return [
		[110.0, func(a: Rig) -> void:
			var q := a.point("tip")
			wisps(a, q.x, q.y, 2, { "size": 0.8 })],
		[200.0, func(a: Rig) -> void: a.gleam("tip")],
		[250.0, func(a: Rig) -> void: wisps(a, 120, 214, 3, { "vx": -120.0 })],
		[262.0, func(a: Rig) -> void: a.flash("#d9c6ff", 50)],
		[265.0, func(a: Rig) -> void:
			a.sound("slash")
			a.wave({ "x": 226.0, "y": 150.0, "vx": 1500.0, "R": 116.0, "fill": SPIRIT, "inner": SPIRIT_CORE, "hit": Rig.with(Rig.HIT, { "dmg": dmg }) })],
		[285.0, func(a: Rig) -> void:
			var q := a.point("tip")
			wisps(a, q.x, q.y, 3, { "vx": 160.0 })],
		[345.0, func(a: Rig) -> void:
			var c := a.target()
			wisps(a, c.x, c.y, 5, { "sx": 34.0, "sy": 34.0, "vx": 120.0 })],
		[650.0, func(a: Rig) -> void:
			var h := a.hero()
			wisps(a, h.x, h.y + 20.0, 5, { "sx": 40.0, "sy": 50.0, "vx": -90.0 })],
		[780.0, func(a: Rig) -> void:
			var h := a.hero()
			wisps(a, h.x - 40.0, h.y + 70.0, 2, { "sx": 24.0, "sy": 10.0, "vx": -80.0, "size": 0.8 })],
	]

func drive(name: String, p: Dictionary, vx: float, ctx: Dictionary) -> float:
	var idle: float = ctx.idle
	if name == "tail":
		return clampf(vx * 0.035, -18, 34) + p.lean * 0.5 + idle * 5.0 * sin(ctx.clock / 520.0)
	if name == "band":
		return clampf(vx * 0.04, -14, 30) + p.lean * 0.6 + p.head * 0.6 + idle * 3.0 * sin(ctx.clock / 600.0)
	return 0.0

## hover bob (b = 0 at load -> rest check stays aligned)
func idle(p: Dictionary, b: float, _clock: float) -> void:
	p.y = -5.0 * b
	p.sy = 1.0 + 0.012 * b
	p.head = 1.5 * b
	p.arm = 2.0 * b
	p.wrist = -1.5 * b

## afterimage echoes trailing the drift (stateless: from the X track). JS mid layer; drawn under the ghost itself so
## they stay behind its body when the target is drawn after it (dir=down)
func draw_char_under(ctx: RigCtx, cam: RigCam, r: Rig) -> void:
	var t := r.t
	if t < 250.0 or t > 420.0: # forward drift only (rest-pose echoes clash with the faded body on the way back)
		return
	if _x_keys.is_empty():
		_x_keys = RigData.keys_of(data.consts.X.track)
	var ci := ctx.ci
	var tex := Token.raster("res://assets/units/styles/chibi/ghost_%s.svg" % ("e" if r.swap else "p"), 256.0 * cam.ca * Baked.screen_scale(ci))
	if tex == null:
		return
	var fade := 1.0 - maxf(0.0, t - 330.0) / 90.0
	for la: Array in [[45.0, 0.32], [95.0, 0.16]]:
		var dx := RigData.sample(_x_keys, maxf(0.0, t - float(la[0])))
		if absf(dx - float(r.pose.x)) < 4.0:
			continue
		ci.draw_set_transform_matrix(cam.char_xf(dx, r.pose.y))
		ci.draw_texture_rect(tex, Rect2(0, 0, 256, 256), false, Color(1, 1, 1, float(la[1]) * fade * ctx.alpha))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

## rising ghost wisps: flame-like teardrop, flat fill + INK, sways up and fades (one-shot fx, owns its state)
static func wisps(a: Rig, x: float, y: float, n: int, o := {}) -> void:
	var sx: float = o.get("sx", 18.0)
	var sy: float = o.get("sy", 14.0)
	for i in n:
		var m := Wisp.new()
		m.x = x + randf_range(-sx, sx)
		m.y = y + randf_range(-sy, sy)
		m.vx = float(o.get("vx", 0.0)) + randf_range(-40, 40)
		m.vy = -randf_range(60, 130)
		m.rr = randf_range(9, 15) * float(o.get("size", 1.0))
		m.life = randf_range(520, 820)
		m.ph = randf_range(0, 6)
		m.w = a.cam.w_of(m.x)
		a.add(m)

class Wisp extends RigFx.Mote:
	var ph := 0.0
	func move(s: float) -> void:
		vx *= 1.0 - 2.0 * s
		x += (vx + 40.0 * sin(age / 120.0 + ph)) * s
		y += vy * s
	func xf(cam: RigCam) -> Transform2D:
		return cam.frame(x, y, w)
	func fade() -> float:
		var u := age / life
		return u / 0.1 if u < 0.1 else 1.0 - (u - 0.1) / 0.9
	func shape(ctx: RigCtx) -> void:
		var u := age / life
		var r := rr * (1.0 - 0.45 * u)
		var sway := 10.0 * sin(age / 90.0 + ph)
		ctx.begin_path(); ctx.arc(0, 0, r, PI, 0, true)
		ctx.quad_to(r, -1.7 * r, sway, -3.3 * r); ctx.quad_to(-r * 0.3, -1.4 * r, -r, 0); ctx.close_path()
		ctx.fill(GHOST); ctx.stroke(RigFx.INK, 3)
		ctx.begin_path(); ctx.arc(0, -r * 0.1, r * 0.42, 0, TAU); ctx.fill(SPIRIT)
