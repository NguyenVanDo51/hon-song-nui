extends RigSpec
## commander "Kiếm Giáng" (docs/anim_demo/hero_p.spec.js, hero_e.spec.js: same rig + attack, different art).
## Wrench the planted greatsword up -> backswing over the helm -> cleave down-forward = THE hit -> re-plant.

func events(_r: Rig) -> Array:
	var c := data.consts
	var dmg: float = c.DMG
	var t_slash: float = c.T_SLASH
	var t_hit: float = c.T_HIT
	var t_plant: float = c.T_PLANT
	return [
		[
			30.0,
			func(a: Rig) -> void:
				a.dust(128, 244, 4, 0),
		],
		[
			250.0,
			func(a: Rig) -> void:
				a.gleam("tip", 130),
		],
		[
			t_slash,
			func(a: Rig) -> void:
				a.sound("slash")
				a.dust(100, 244, 6, -1),
		],
		[
			t_hit,
			func(a: Rig) -> void:
				a.hit(Rig.with(Rig.HIT, { "dmg": dmg })),
		],
		[
			t_plant,
			func(a: Rig) -> void:
				a.dust(128, 244, 5, 0)
				a.shake(2, 70),
		],
	]

func drive(name: String, p: Dictionary, vx: float, ctx: Dictionary) -> float:
	var idle_k: float = ctx.idle
	var ck: float = ctx.clock
	if name == "cape":
		return clampf(vx * 0.03, -12, 30) + p.lean * 0.5 + idle_k * 2.0 * sin(ck / 700.0)
	if name == "crest": # hero_p feather wings only (hero_e horns have no spring)
		return clampf(vx * 0.02, -8, 14) + p.lean * 0.3 + p.head * 0.4 + idle_k * 1.2 * sin(ck / 700.0)
	return 0.0

func idle(p: Dictionary, b: float, _clock: float) -> void:
	p.sy = 1.0 + 0.014 * b
	p.head = 1.5 * b

## sword raised over the helm: draw it in front of head / wings
func order(p: Dictionary, list: Array) -> Array:
	var up: float = p.get("swordUp", 0.0)
	if up > 0.5:
		return part_after(list, "sword", "face")
	return list
