extends RigSpec
## commander "Kiếm gió lốc" (docs/anim_demo/hero_p.spec.js, hero_e.spec.js: same rig + attack, different art).
## Slash -> wind blade (small tick) -> tornado lifts the target, 3 ticks, drops it = THE hit (via target landing).

func events(r: Rig) -> Array:
	var c := data.consts
	var t_wave: float = c.T_WAVE
	var wave_x: float = c.WAVE_X
	var wave_vx: float = c.WAVE_VX
	var t_drop: float = c.T_DROP
	# JS: T_TWISTER = T_WAVE + (256 + 84 - WAVE_X) / WAVE_VX * 1000 (range 1); here from the real target front
	var front: float = r.target().front
	var t_twister := t_wave + roundf((front - wave_x) / wave_vx * 1000.0)
	var dmg: Dictionary = c.DMG
	return [
		[
			160.0,
			func(a: Rig) -> void:
				a.gleam("tip"),
		],
		[
			225.0,
			func(a: Rig) -> void:
				a.dust(100, 244, 6, -1),
		],
		[
			t_wave,
			func(a: Rig) -> void:
				a.flash("#f4fcff", 50)
				a.sound("slash")
				a.wave({ "x": wave_x, "y": 150.0, "vx": wave_vx, "R": 118.0, "angle": -16.0, "hit": Rig.with(Rig.HIT_SMALL, { "dmg": dmg.blade }) }),
		],
		[
			t_twister,
			func(a: Rig) -> void:
				var tx: float = a.target().x
				a.shockwave(tx, 244, { "r": 130.0, "ms": 360.0, "color": "#f4fcff" })
				a.dust(tx, 244, 8, 0)
				a.tornado(
					{
						"x0": tx,
						"travel": c.TW_TRAVEL,
						"hold": c.TW_HOLD,
						"lift": 100.0,
						"ticks": 3,
						"tick": Rig.with(Rig.HIT_SMALL, { "dmg": dmg.tick }),
						"final": Rig.with(Rig.HIT, { "dmg": dmg.drop }),
					}
				),
		],
		[
			t_drop - 70.0,
			func(a: Rig) -> void:
				a.gleam("tip", 150),
		],
	]

func drive(name: String, p: Dictionary, vx: float, ctx: Dictionary) -> float:
	var idle_k: float = ctx.idle
	var ck: float = ctx.clock
	if name == "cape":
		return clampf(vx * 0.03, -12, 34) + p.lean * 0.5 + idle_k * 3.0 * sin(ck / 700.0)
	if name == "plume":
		return clampf(vx * 0.035, -14, 30) + p.lean * 0.7 + p.head * 0.6 + idle_k * 1.8 * sin(ck / 700.0)
	return 0.0

func idle(p: Dictionary, b: float, _clock: float) -> void:
	p.sy = 1.0 + 0.014 * b
	p.head = 1.5 * b
	p.arm = 2.0 * b
	p.wrist = -1.5 * b
