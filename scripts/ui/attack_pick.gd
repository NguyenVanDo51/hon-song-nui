class_name AttackPick
extends RefCounted
## where a clicked / hovered attack is made from when the player picked no tile. UI only, no rule effect.
## 1. target in range from the unit's own tile -> stay (never auto-move; keeps castle / heal / guard).
## 2. else best reachable tile, worst case: counter at max roll unless a sure kill, no-counter tiles first.

const NO_COUNTER := 25.0

## [x, y] to attack `target` from, or null. `reach` = Game.reachable(s, u)
static func tile(s: Dictionary, u: Dictionary, target: Dictionary, reach: Dictionary) -> Variant:
	var ux: int = u.x
	var uy: int = u.y
	if reach.has(Vector2i(ux, uy)) and hits(s, u, ux, uy, target): # stacked unit: own tile not in reach, must step off
		return [ux, uy]
	var best: Variant = null
	for r: Dictionary in reach.values():
		var rx: int = r.x
		var ry: int = r.y
		if not hits(s, u, rx, ry, target):
			continue
		var cost: int = r.cost
		var sc := score(s, u, rx, ry, target) + Game.terrain_def(s, u, rx, ry) * 0.3 - cost * 0.1
		if best == null or sc > best.sc:
			best = { "sc": sc, "x": rx, "y": ry }
	if best == null:
		return null
	return [best.x, best.y]

## worst-case trade from (fx, fy): mid dmg vs max counter (0 only on a sure kill), kill / die bonuses, no-counter bonus
static func score(s: Dictionary, u: Dictionary, fx: int, fy: int, target: Dictionary) -> float:
	var p := Game.preview(s, u, fx, fy, target)
	var dmg: float = p.dmg
	var cmax: float = p.counterMax
	var sc := dmg - cmax * 1.1 + (50.0 if p.kill else (20.0 if p.mayKill else 0.0)) - (50.0 if p.die else (20.0 if p.mayDie else 0.0))
	if not Game.can_counter(s, target, fx, fy):
		sc += NO_COUNTER
	return sc

static func hits(s: Dictionary, u: Dictionary, fx: int, fy: int, target: Dictionary) -> bool:
	return Game.targets_from(s, u, fx, fy).any(
		func(o: Dictionary) -> bool:
			return o.id == target.id,
	)
