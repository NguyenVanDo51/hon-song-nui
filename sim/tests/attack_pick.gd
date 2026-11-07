extends "res://sim/tests/test_base.gd"
## AttackPick: tile a click / hover attack is made from when the player picked none (run by sim/tests.gd)

## pre-fix pick (mid-roll counter, terrain bonus): to show the bug each case guards against
static func old_tile(s: Dictionary, u: Dictionary, target: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_sc := -INF
	for r: Dictionary in Game.reachable(s, u).values():
		var rx: int = r.x
		var ry: int = r.y
		if not AttackPick.hits(s, u, rx, ry, target):
			continue
		var p := Game.preview(s, u, rx, ry, target)
		var cost: int = r.cost
		var sc: float = p.dmg - p.counter * 1.1 + (50.0 if p.kill else (20.0 if p.mayKill else 0.0)) \
				- (50.0 if p.die else (20.0 if p.mayDie else 0.0)) + Game.terrain_def(s, u, rx, ry) * 0.3 - cost * 0.1
		if sc > best_sc:
			best_sc = sc
			best = Vector2i(rx, ry)
	return best

## picked tile, (-1, -1) = none
static func pick(s: Dictionary, u: Dictionary, target: Dictionary) -> Vector2i:
	var t: Variant = AttackPick.tile(s, u, target, Game.reachable(s, u))
	if t is Array:
		var a: Array = t
		return xy(a)
	return Vector2i(-1, -1)

func attack_pick_tests() -> void:
	run(
		"archer in range (dist 2) stays; adjacent mountain not chosen",
		func() -> void:
			# hp 50: counter mid 2 / max 3 -> pre-fix terrain +3.0 beat it; hp 44: counter mid 0 (2 hp left), max 1
			for ehp: int in [50, 44]:
				var s := blank([["p", "archer", 1, 1], ["e", "soldier", 2, 2, ehp]])
				s.tiles[1][2] = "m" # (2,1): adjacent to the enemy
				var a: Dictionary = unit(s, 0)
				var e: Dictionary = unit(s, 1)
				var p := Game.preview(s, a, 2, 1, e)
				var kill: bool = p.kill
				var cmax: int = p.counterMax
				check(not kill and cmax > 0, "setup hp %d: enemy may survive and counter" % ehp)
				eq(old_tile(s, a, e), Vector2i(2, 1), "pre-fix hopped next to the enemy, hp %d" % ehp)
				eq(pick(s, a, e), Vector2i(1, 1), "stays on its own tile, hp %d" % ehp),
	)
	run(
		"soldier on own castle next to enemy stays (no hop to mountain)",
		func() -> void:
			var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 2, 1]])
			s.tiles[1][1] = "c"
			s.owner[Vector2i(1, 1)] = "p"
			s.tiles[2][2] = "m" # (2,2): below the enemy
			var u: Dictionary = unit(s, 0)
			eq(old_tile(s, u, unit(s, 1)), Vector2i(1, 1), "pre-fix also stayed (castle def = mountain def; guard only)")
			eq(pick(s, u, unit(s, 1)), Vector2i(1, 1), "stays on the castle"),
	)
	run(
		"archer on own village next to enemy stays (pre-fix stepped back to dodge the counter, left the village)",
		func() -> void:
			var s := blank([["p", "archer", 1, 1], ["e", "soldier", 2, 1]])
			s.tiles[1][1] = "v"
			s.owner[Vector2i(1, 1)] = "p"
			var a: Dictionary = unit(s, 0)
			var e: Dictionary = unit(s, 1)
			var o := old_tile(s, a, e)
			check(o != Vector2i(1, 1) and Game.dist(o.x, o.y, 2, 1) == 2, "pre-fix left the village for a dist-2 tile")
			eq(pick(s, a, e), Vector2i(1, 1), "stays on the village"),
	)
	run(
		"soldier on bridge next to enemy stays (pre-fix hopped to forest)",
		func() -> void:
			var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 2, 1]])
			s.tiles[1][1] = "="
			s.tiles[2][2] = "f"
			var u: Dictionary = unit(s, 0)
			var e: Dictionary = unit(s, 1)
			eq(old_tile(s, u, e), Vector2i(2, 2), "pre-fix hopped to the forest")
			eq(pick(s, u, e), Vector2i(1, 1), "stays on the bridge"),
	)
	run(
		"out of range: picks a reachable tile; archer prefers no-counter (dist 2) over adjacent mountain",
		func() -> void:
			var s := blank([["p", "archer", 0, 3], ["e", "soldier", 4, 3]])
			s.tiles[3][3] = "m" # (3,3): adjacent to the enemy, best terrain
			var a: Dictionary = unit(s, 0)
			var e: Dictionary = unit(s, 1)
			var t := pick(s, a, e)
			check(t != Vector2i(-1, -1) and t != Vector2i(0, 3), "moves (target out of range)")
			eq(Game.dist(t.x, t.y, 4, 3), 2, "attacks from distance 2")
			check(not Game.can_counter(s, e, t.x, t.y), "no counter from there")
			var s2 := blank([["p", "soldier", 0, 3], ["e", "soldier", 3, 3]])
			var t2 := pick(s2, unit(s2, 0), unit(s2, 1))
			eq(Game.dist(t2.x, t2.y, 3, 3), 1, "melee: adjacent tile picked"),
	)
	run(
		"catapult: only from its own tile",
		func() -> void:
			var s := blank([["p", "catapult", 1, 1], ["e", "soldier", 1, 4], ["e", "soldier", 5, 4]])
			var c: Dictionary = unit(s, 0)
			eq(pick(s, c, unit(s, 1)), Vector2i(1, 1), "in range: own tile")
			eq(pick(s, c, unit(s, 2)), Vector2i(-1, -1), "out of range: no tile (no move + attack)"),
	)
	run(
		"stacked unit (bought on occupied castle) never attacks from the shared tile",
		func() -> void:
			var s := blank([["p", "soldier", 0, 0], ["p", "archer", 0, 0], ["e", "soldier", 1, 1]])
			var a: Dictionary = unit(s, 1)
			var t := pick(s, a, unit(s, 2))
			check(t != Vector2i(-1, -1) and t != Vector2i(0, 0), "steps off the shared tile"),
	)
