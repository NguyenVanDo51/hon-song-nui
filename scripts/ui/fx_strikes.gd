class_name FxStrikes
extends RefCounted
## FX part (split from fx.gd): per-troop melee strike of the non-rig attack path (FX.attack).

## each troop's own melee strike (drawn at the moment of contact). Ranged shots keep their projectile.
static func signature(fx: FX, a: Dictionary, d: Dictionary, dir: Vector2) -> void:
	var ax: float = a.x
	var ay: float = a.y
	var dx: float = d.x
	var dy: float = d.y
	var ang := atan2(dy - ay, dx - ax)
	var r := func(kind: String, dur: float, extra := { }) -> void:
		var e := { "kind": kind, "x": d.x, "y": d.y, "ax": a.x, "ay": a.y, "ang": ang, "t0": FX.now(), "dur": fx.sp(dur) }
		e.merge(extra, true)
		fx.rays.append(e)
	match a.type:
		"hero": # chém ra gió xoáy: spinning vortex + wind streaks spiralling out
			r.call("whirl", 800.0)
			r.call("slash", 220.0)
			for i in 14:
				var k := float(i) / 14.0 * TAU
				fx.parts.append(
					{
						"x": d.x + cos(k) * 0.15,
						"y": d.y + sin(k) * 0.1,
						"vx": cos(k + 1.4) * 2.4,
						"vy": sin(k + 1.4) * 1.4 - 0.8,
						"g": -0.6,
						"drag": 0.9,
						"life": -float(i) * 12.0,
						"max": 520.0,
						"size": 0.035,
						"color": Color("#e8f6ff"),
						"kind": "spark",
					}
				)
			fx.shake(0.07, 260.0)
		"soldier": # spear thrust: a straight lance of light through the target
			r.call("thrust", 240.0)
		"boat": # paddle-spear from the river: splash + spray
			r.call("thrust", 220.0, { "col": Color("#9fe3ff") })
			fx.burst(
				dx,
				dy,
				16,
				{
					"color": ["#7fd0ff", "#c8f0ff", "#3f9bd6"],
					"vmin": 1.0,
					"vmax": 3.0,
					"up": 1.6,
					"g": 6.0,
					"lmin": 300.0,
					"lmax": 650.0,
					"smin": 0.03,
					"smax": 0.06,
				},
			)
			fx.ring(dx, dy, "#9fe3ff", 420.0, 0.8, 0.06)
		"shaman": # gọi hồn: green spirit wisps swirl in and strike
			r.call("spirit", 520.0)
			fx.burst(
				dx,
				dy,
				12,
				{
					"color": ["#9dffb8", "#4fd38a", "#e6fff0"],
					"kind": "glow",
					"vmin": 0.4,
					"vmax": 1.4,
					"up": 0.8,
					"g": -0.8,
					"lmin": 400.0,
					"lmax": 800.0,
					"smin": 0.04,
					"smax": 0.08,
				},
			)
		"drum": # bronze drum boom: sound rings rolling from the drummer to the target
			for i in 3:
				fx.rays.append(
					{ "kind": "boom", "x": d.x, "y": d.y, "ax": a.x, "ay": a.y, "ang": ang, "t0": FX.now() + i * fx.sp(70.0), "dur": fx.sp(380.0) }
				)
		"wolf": # claw rake + bite
			r.call("claw", 300.0)
			fx.burst(
				dx,
				dy,
				8,
				{ "color": ["#ff6b57", "#ffb199"], "vmin": 0.8, "vmax": 2.2, "lmin": 200.0, "lmax": 420.0, "smin": 0.02, "smax": 0.045 },
			)
		"elephant": # tusk charge + ground stomp: dust ring, cracks, heavy shake
			r.call("stomp", 520.0)
			fx.burst(
				dx,
				dy + 0.3,
				14,
				{
					"color": ["#8a7457", "#b39a76", "#6b5a44"],
					"kind": "smoke",
					"vmin": 0.6,
					"vmax": 1.6,
					"up": 0.2,
					"g": -0.2,
					"lmin": 500.0,
					"lmax": 900.0,
					"smin": 0.1,
					"smax": 0.2,
					"drag": 0.93,
				},
			)
			fx.ring(dx, dy, "#d8bb8a", 480.0, 1.3, 0.1)
			fx.shake(0.12, 300.0)
		"bird": # dragon fire breath: a cone of flame from the jaws to the target
			r.call("fire", 520.0)
			for i in 26:
				var t := randf()
				var spread := randf_range(-0.35, 0.35)
				var v := dir.rotated(spread) * randf_range(3.0, 5.0)
				var hex: String = ["#ffe27a", "#ff9a3c", "#ff5a2a", "#fff3c4"][i % 4]
				fx.parts.append(
					{
						"x": a.x + dir.x * 0.3,
						"y": a.y + dir.y * 0.3 - 0.15,
						"vx": v.x,
						"vy": v.y - 0.3,
						"g": -1.2,
						"drag": 0.88,
						"life": -t * 160.0,
						"max": randf_range(260.0, 420.0),
						"size": randf_range(0.05, 0.11),
						"color": Color(hex),
						"kind": "glow",
					}
				)
			fx.shake(0.08, 280.0)
		"ghost": # cold dark slash
			r.call("slash", 260.0, { "col": Color("#b7a6ff") })
		_:
			r.call("slash", 220.0)
