extends "res://sim/tests/test_base.gd"
## rules tests (run by sim/tests.gd)

func rule_tests() -> void:
	run(
		"catapult razes an enemy / unowned village in range from where it stands; not own, not occupied, not after moving",
		func() -> void:
			var s := blank([["p", "catapult", 1, 1], ["e", "soldier", 4, 4]])
			var c: Dictionary = s.units[0]
			s.tiles[1][4] = "v"
			s.owner[Vector2i(4, 1)] = "e" # dist 3: in range
			s.tiles[3][1] = "v" # unowned, dist 2
			s.tiles[1][2] = "v"
			s.owner[Vector2i(2, 1)] = "p" # own: never
			s.tiles[4][4] = "v" # occupied by the enemy soldier: no
			s.tiles[1][1] = "."
			var opts := Game.razable_from(s, c, 1, 1)
			check(opts.has([4, 1]) and opts.has([3, 1]) == false and opts.has([1, 3]), "options %s" % [opts])
			check(not opts.has([2, 1]) and not opts.has([4, 4]), "own / occupied excluded %s" % [opts])
			eq(Game.razable_from(s, c, 1, 2).size(), 0, "siege: not from another tile")
			var ev := Game.do_action(s, { "id": c.id, "to": [1, 1], "kind": "raze", "target": [4, 1] })
			eq(s.tiles[1][4], "x", "village ruined")
			check(not owner_of(s).has(Vector2i(4, 1)), "owner cleared")
			check(
				ev.any(
					func(e: Dictionary) -> bool:
						return e.t == "raze" and e.prev == "e",
				),
				"raze event with prev owner",
			)
			check(acted(c), "catapult done for the turn")
			eq(Game.income(s, "e"), Rules.TERRAIN.c.income, "enemy lost the village income"),
	)
	run(
		"ruined village: no capture; capV unit repairs -> unowned village, capture on a later turn",
		func() -> void:
			var s := blank([["p", "soldier", 2, 2], ["p", "archer", 3, 3], ["e", "soldier", 5, 4]])
			var sol: Dictionary = s.units[0]
			s.tiles[2][2] = "x"
			check(not Game.can_capture(s, sol, 2, 2), "cannot capture a ruin")
			check(not Game.can_repair(s, unit(s, 1), 2, 2), "archer cannot repair")
			check(Game.can_repair(s, sol, 2, 2), "soldier can repair")
			Game.do_action(s, { "id": sol.id, "to": [2, 2], "kind": "repair" })
			eq(s.tiles[2][2], "v", "repaired")
			check(not owner_of(s).has(Vector2i(2, 2)), "still unowned")
			check(acted(sol), "repair takes the turn")
			Game.end_turn(s)
			Game.end_turn(s)
			check(Game.can_capture(s, sol, 2, 2), "capturable next turn")
			eq(Game.TERRAIN["x"].def, Game.TERRAIN["v"].def, "ruin keeps the village cover (as the original)"),
	)
	run(
		"AI catapult wrecks an enemy village when it has nothing to hit; AI soldier repairs a ruin",
		func() -> void:
			var s := blank([["e", "catapult", 4, 4], ["p", "soldier", 0, 1]])
			s.side = "e"
			s.tiles[1][4] = "v"
			s.owner[Vector2i(4, 1)] = "p"
			var step: Variant = AI.next_step(s, { })
			eq(step.act.kind, "raze", "catapult razes")
			eq(step.act.target, [4, 1])
			var s2 := blank([["e", "soldier", 3, 3], ["p", "soldier", 0, 1]])
			s2.side = "e"
			s2.tiles[3][4] = "x"
			var mem := { }
			var st2: Dictionary = AI.next_step(s2, mem)
			AI.apply_step(s2, st2)
			eq(s2.tiles[3][4], "v", "AI soldier repaired the adjacent ruin (got %s)" % [st2.act]),
	)
	run(
		"illegal capture / raise changes nothing (unit stays, can still act)",
		func() -> void:
			var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 4, 4]])
			var u: Dictionary = s.units[0]
			var n: int = units_of(s).size()
			Game.do_action(s, { "id": u.id, "to": [2, 2], "kind": "capture" }) # plain field: nothing to capture
			eq([u.x, u.y], [1, 1], "position")
			check(not acted(u), "still can act")
			Game.do_action(s, { "id": u.id, "to": [2, 1], "kind": "raise", "target": [3, 1] }) # soldier cannot raise, no grave
			eq([u.x, u.y], [1, 1], "position after bad raise")
			eq(units_of(s).size(), n, "no unit spawned"),
	)
	run(
		"AE2: raised ghosts ignore the unit cap and do not count toward it",
		func() -> void:
			var s := blank([["p", "shaman", 1, 1], ["e", "soldier", 4, 4]])
			s.graves = [{ "x": 2, "y": 1, "ttl": 2 }]
			s.unitCap = 1
			eq(Game.raisable_graves(s, unit(s, 0), 1, 1).size(), 1, "raise at cap")
			Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "raise", "target": [2, 1] })
			eq(Game.cap_count(s, "p"), 1, "ghost not counted"),
	)
	run(
		"AE2 graves: ttl 3, down 1 at every side's turn start; stepping on one clears it",
		func() -> void:
			var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 4, 4]])
			s.graves = [{ "x": 3, "y": 3, "ttl": Rules.RULES.graveRounds }]
			Game.end_turn(s)
			Game.end_turn(s)
			eq(graves_of(s).size(), 1, "alive after 2 half-turns")
			Game.end_turn(s)
			eq(graves_of(s).size(), 0, "gone after 3")
			s.graves = [{ "x": 2, "y": 1, "ttl": 3 }]
			s.side = "p"
			s.units[0].acted = false
			Game.do_action(s, { "id": 1, "to": [2, 1], "kind": "wait" })
			eq(graves_of(s).size(), 0, "stepped on"),
	)
	run(
		"buildings are descriptors: a new tile type works from TERRAIN alone (income, capture, heal, sells, raze / repair)",
		func() -> void:
			var ter: Dictionary = Rules.TERRAIN.duplicate(true)
			ter["p"] = { "def": 10, "cost": 1, "building": "port", "income": 40, "cap": "capV", "heals": "owner", "razeTo": "q" }
			ter["q"] = { "def": 5, "cost": 1, "repairTo": "p", "repairBy": "capV" }
			ter["o"] = { "def": 20, "cost": 1, "building": "fort", "income": 10, "cap": "capC", "heals": "owner", "sells": true }
			Game.use_tables(Rules.UNITS, Rules.HEROES, Rules.RULES, ter)
			eq(
				[Game.income_of("p"), Game.income_of("."), Game.sells("o"), Game.sells("p"), Game.cap_flag("o"), Game.cap_flag("t")],
				[40, 0, true, false, "capC", ""],
			)
			var s := blank([["p", "soldier", 2, 2, 50], ["p", "hero", 3, 3], ["e", "catapult", 5, 1]])
			s.tiles[2][2] = "p"
			s.tiles[3][3] = "o"
			check(Game.can_capture(s, unit(s, 0), 2, 2), "soldier takes a port (cap capV)")
			check(not Game.can_capture(s, unit(s, 0), 3, 3) and Game.can_capture(s, unit(s, 1), 3, 3), "fort needs capC")
			Game.do_action(s, { "id": 1, "to": [2, 2], "kind": "capture" })
			Game.do_action(s, { "id": 2, "to": [3, 3], "kind": "capture" })
			eq(Game.income(s, "p"), 50 + 40 + 10, "income = sum over owned tiles")
			eq(Game.castle_tiles(s, "p"), [Vector2i(0, 0), Vector2i(3, 3)], "fort sells")
			check(Game.buy_options(s, "p", 3, 3).size() > 0 and Game.buy_options(s, "p", 2, 2).is_empty(), "buy only where it sells")
			Game.end_turn(s)
			Game.end_turn(s)
			eq(s.units[0].hp, 70, "port heals its owner")
			s.units[0].x = 1
			s.units[1].x = 4
			s.units[1].y = 4
			s.side = "e"
			s.units[2].acted = false
			check(Game.razable_from(s, unit(s, 2), 5, 1).has([2, 2]), "port razable (razeTo)")
			Game.do_action(s, { "id": 3, "to": [5, 1], "kind": "raze", "target": [2, 2] })
			eq(s.tiles[2][2], "q", "razed into razeTo")
			Game.end_turn(s)
			s.units[0].acted = false
			check(Game.can_repair(s, unit(s, 0), 2, 2), "repairBy capV")
			Game.do_action(s, { "id": 1, "to": [2, 2], "kind": "repair" })
			eq(s.tiles[2][2], "p", "repaired into repairTo")
			Game.use_tables(Rules.UNITS, Rules.HEROES, Rules.RULES, Rules.TERRAIN),
	)
	run(
		"AE2 income: village 30, castle 50",
		func() -> void:
			var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 4, 4]])
			s.tiles[0][3] = "v"
			s.owner[Vector2i(3, 0)] = "e"
			eq(Game.income(s, "e"), 80)
			eq(Game.income(s, "p"), 50),
	)
	run(
		"AE2 damage: (roll atk..atkMax-1 + bonus - def - terrain) x hp / 100, floor, >= 0",
		func() -> void:
			var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 2, 1]])
			var a: Dictionary = s.units[0]
			var d: Dictionary = s.units[1]
			eq(Game.damage(s, a, 1, 1, 100, d, 0.0), 40) # 50 - 5 def - 5 field
			eq(Game.damage(s, a, 1, 1, 100, d, 0.999), 44, "never the table max 55") # 54 - 10
			eq(Game.damage(s, a, 1, 1, 100, d, Game.ROLL_TOP), 44)
			eq(Game.atk_range(s, a), [50, 54], "rollable range")
			# every roll in [0,1) lands in [min, max-1] and each value is reachable
			var seen := { }
			for i in 1000:
				seen[Game.damage(s, a, 1, 1, 100, d, i / 1000.0)] = true
			eq(
				seen.keys().map(
					func(k: int) -> int:
						return k + 10,
				).reduce(
					func(m: int, k: int) -> int:
						return maxi(m, k),
					0,
				),
				54,
				"max roll",
			)
			eq(seen.size(), 5, "rolls 50..54")
			check(
				Content.traits("soldier", null).any(
					func(t: String) -> bool:
						return "Công 50–54" in t,
				),
				"traits print the rollable range",
			)
			eq(Game.damage(s, a, 1, 1, 50, d, 0.0), 20)
			s.tiles[1][2] = "f"
			eq(Game.damage(s, a, 1, 1, 100, d, 0.0), 35)
			var e := blank([["p", "ghost", 1, 1], ["e", "elephant", 2, 1]])
			e.tiles[1][2] = "m"
			eq(Game.damage(e, unit(e, 0), 1, 1, 100, unit(e, 1), 0.0), 0, "armour soaks the hit"),
	)
	run(
		"attack applies rolled damage + adjacent counter; preview gives the range",
		func() -> void:
			var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 3, 1]])
			var a: Dictionary = s.units[0]
			var d: Dictionary = s.units[1]
			var p := Game.preview(s, a, 2, 1, d)
			eq([p.dmgMin, p.dmgMax, p.counterMin, p.counterMax], [40, 44, 22, 26])
			# forecast is exact: top roll -> hit = dmgMax (44); counter after it = (54 - 10) x 56 / 100 = 24
			var s2 := blank([["p", "soldier", 1, 1], ["e", "soldier", 3, 1]])
			Game.fixed_roll = Game.ROLL_TOP
			Game.do_action(s2, { "id": 1, "to": [2, 1], "kind": "attack", "target": 2 })
			Game.fixed_roll = -1.0
			eq([s2.units[1].hp, s2.units[0].hp], [100 - p.dmgMax, 76])
			Game.fixed_roll = 0.0
			Game.do_action(s, { "id": a.id, "to": [2, 1], "kind": "attack", "target": d.id })
			Game.fixed_roll = -1.0
			eq([d.hp, a.hp], [60, 76]),
	)
	run(
		"AE2 counter: only adjacent + rmin 1 (archer counters next to it, not at 2)",
		func() -> void:
			var s := blank([["p", "soldier", 1, 1], ["e", "archer", 2, 1], ["e", "catapult", 1, 2]])
			check(Game.can_counter(s, unit(s, 1), 1, 1), "archer adjacent counters")
			check(not Game.can_counter(s, unit(s, 1), 0, 1), "archer at 2 does not")
			check(not Game.can_counter(s, unit(s, 2), 1, 1), "catapult never"),
	)
	run(
		"AE2 drum: after acting, allies within 2 get +10 atk until the drum side's next turn",
		func() -> void:
			var s := blank([["p", "soldier", 1, 1], ["p", "drum", 1, 3], ["p", "archer", 4, 1], ["e", "soldier", 2, 1]])
			var a: Dictionary = s.units[0]
			var d: Dictionary = s.units[3]
			var before := Game.damage(s, a, 1, 1, 100, d, 0.0)
			Game.do_action(s, { "id": 2, "to": [1, 3], "kind": "wait" })
			var buffed: bool = a.get("aura") == "p" and unit(s, 2).get("aura") == null
			check(buffed, "soldier (2 away) buffed, archer (far) not")
			eq(Game.damage(s, a, 1, 1, 100, d, 0.0), before + 10)
			eq(Buffs.at(s, a, 1, 1).atk, 10, "buffs_at shows it")
			Game.end_turn(s)
			var lasts: bool = a.get("aura") == "p"
			check(lasts, "lasts through the enemy turn")
			Game.end_turn(s)
			check(a.get("aura") == null, "gone at our next turn")
			eq(
				Content.traits("drum", null).any(
					func(t: String) -> bool:
						return "+10 công" in t,
				),
				true,
			)
			# AE2: a drum killed by the counter still drums, from the tile it fell on (RM Unit.finishMove)
			var k := blank([["p", "drum", 1, 1, 1], ["p", "soldier", 1, 3], ["p", "archer", 4, 4], ["e", "soldier", 2, 2]])
			Game.fixed_roll = 0.0
			Game.do_action(k, { "id": 1, "to": [1, 2], "kind": "attack", "target": 4 })
			Game.fixed_roll = -1.0
			check(Game.unit_by_id(k, 1) == null, "drum died")
			var near_buffed: bool = unit(k, 0).get("aura") == "p"
			check(near_buffed, "ally 1 from the death tile buffed")
			var far_plain: bool = unit(k, 1).get("aura") == null
			check(far_plain, "far ally not")
			eq(Content.how_to_play("archer") != "", true),
	)
	run(
		"AE2 wolf: counter first at full strength, then the bite lands (RM finishAttack)",
		func() -> void:
			var s := blank([["p", "wolf", 1, 1], ["e", "soldier", 2, 1]])
			var w: Dictionary = s.units[0]
			var d: Dictionary = s.units[1]
			Game.fixed_roll = 0.0
			var ev := Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
			Game.fixed_roll = -1.0
			# soldier at 100 - 50 = 50 hp, unpoisoned: (50 - 15 - 5) x 50 / 100 = 15
			eq(d.hp, 50)
			eq(100 - w.hp, 15, "counter not weakened by the bite")
			eq(d.get("poison"), "p", "poisoned after")
			var hits: Array = ev.filter(
				func(e: Dictionary) -> bool:
					return e.t == "hit" or e.t == "poison",
			)
			var order: Array = hits.map(
				func(e: Dictionary) -> String:
					return "c" if e.get("counter", false) else e.t,
			)
			eq(order, ["hit", "c", "poison"], "event order"),
	)
	run(
		"AE2 wolf: a 0-damage bite still poisons, even if the counter kills the wolf",
		func() -> void:
			var s := blank([["p", "wolf", 1, 1, 1], ["e", "soldier", 2, 1]])
			var d: Dictionary = s.units[1]
			Game.fixed_roll = 0.0
			var ev := Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
			Game.fixed_roll = -1.0
			eq(d.hp, 100, "bite at 1 hp: 0 dmg")
			check(Game.unit_by_id(s, 1) == null, "wolf died to the counter")
			eq(d.get("poison"), "p", "still poisoned")
			check(
				ev.any(
					func(e: Dictionary) -> bool:
						return e.t == "poison",
				),
				"poison event",
			),
	)
	run(
		"AE2 wolf bite: target -10 atk / -10 def until the wolf side's next turn",
		func() -> void:
			var s := blank([["p", "wolf", 1, 1], ["e", "elephant", 2, 1], ["p", "soldier", 3, 2]])
			var e: Dictionary = s.units[1]
			var sol: Dictionary = s.units[2]
			var hit_before := Game.damage(s, sol, 3, 2, 100, e, 0.0)
			Game.fixed_roll = 0.0
			Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
			Game.fixed_roll = -1.0
			eq(e.get("poison"), "p", "poisoned")
			eq(Game.damage(s, sol, 3, 2, 100, e, 0.0), hit_before + 10, "softer")
			Game.end_turn(s)
			Game.end_turn(s)
			eq(e.get("poison"), null, "worn off"),
	)
	run(
		"AE2 water: everyone wades at cost 3 / def 0; water class 1 and +15 atk +25 def there (2026-11-09: AE2 +10 / +15)",
		func() -> void:
			eq(Game.move_cost("foot", "~"), 3.0)
			eq(Game.move_cost("water", "~"), 1.0)
			eq(Game.move_cost("fly", "m"), 1.0)
			eq(Game.move_cost("foot", "m"), 3.0)
			var s := blank([["p", "boat", 1, 1], ["e", "soldier", 2, 1]])
			s.tiles[1][1] = "~"
			var b: Dictionary = s.units[0]
			eq(Game.damage(s, b, 1, 1, 100, unit(s, 1), 0.0), 55, "50 + 15 water - 10")
			eq(Game.damage(s, unit(s, 1), 2, 1, 100, b, 0.0), 15, "50 - (10 + 25)"),
	)
	run(
		"temple heals any side, cannot be captured",
		func() -> void:
			var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 3, 3, 50]])
			s.tiles[3][3] = "t"
			check(not Game.can_capture(s, unit(s, 0), 3, 3), "no capture")
			Game.end_turn(s)
			eq(s.units[1].hp, 70, "enemy healed on the temple"),
	)
	run(
		"path_for walks through an ally (the drawn route used to lose its start there)",
		func() -> void:
			var s := blank([["p", "soldier", 1, 1], ["p", "archer", 2, 1], ["e", "soldier", 5, 4]])
			s.tiles[0][2] = "m"
			s.tiles[2][2] = "m" # only way east is through the archer
			var u: Dictionary = s.units[0]
			eq(Game.path_for(s, u, 3, 1), [[1, 1], [2, 1], [3, 1]])
			var ev := Game.do_action(s, { "id": u.id, "to": [3, 1], "kind": "wait" })
			eq(ev[0].path, [[1, 1], [2, 1], [3, 1]]),
	)
	run(
		"archer at range 2 takes no counter from melee",
		func() -> void:
			var s := blank([["p", "archer", 1, 1], ["e", "soldier", 3, 1]])
			Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
			eq(s.units[0].hp, 100),
	)
	run(
		"siege cannot move and attack same turn",
		func() -> void:
			var s := blank([["p", "catapult", 1, 1], ["e", "soldier", 4, 1]])
			eq(Game.targets_from(s, unit(s, 0), 2, 1).size(), 0)
			eq(Game.targets_from(s, unit(s, 0), 1, 1).size(), 1),
	)
	run(
		"threat zone (UI): tiles in range from any stop tile; siege only from where it stands",
		func() -> void:
			var s := blank([["e", "soldier", 5, 0], ["e", "catapult", 3, 3]])
			var sol := unit(s, 0)
			var reach := Game.reachable(s, sol)
			var th := Game.threat_tiles(s, sol, reach)
			check(th.has(Vector2i(0, 0)) and not reach.has(Vector2i(0, 0)), "5 away: hit, not walked to")
			check(not th.has(Vector2i(0, 1)), "6 away: out of reach")
			var cat := unit(s, 1)
			var tc := Game.threat_tiles(s, cat, Game.reachable(s, cat))
			check(tc.has(Vector2i(3, 1)) and tc.has(Vector2i(0, 2)), "catapult rings 2..4 round its tile")
			check(not tc.has(Vector2i(3, 2)) and not tc.has(Vector2i(0, 0)), "not 1 away, not 5+ away (no move then shoot)"),
	)
	run(
		"lost counter: troops that fall count; commanders + raised ghosts do not",
		func() -> void:
			var s := blank([["p", "elephant", 1, 1], ["e", "soldier", 2, 1, 10], ["e", "hero", 1, 2, 5], ["p", "soldier", 4, 4]])
			Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
			eq(s.lost, { "p": 0, "e": 1 }, "soldier counted")
			Game._kill(s, unit(s, 1), [])
			eq(s.lost.e, 1, "commander not counted")
			eq(s.heroDeaths.e, 1, "commander deaths kept apart")
			Game._kill(s, { "id": 99, "side": "e", "type": "ghost", "x": 3, "y": 3 }, [])
			eq(s.lost.e, 1, "ghost not counted"),
	)
	run(
		"mission stars: win · commander never fell · turns / lost bar",
		func() -> void:
			var m02: Dictionary = Content.level("m02")
			var n: int = m02.stars.turns
			var s := Game.new_game(m02)
			s.winner = "p"
			s.turn = n
			eq(Stars.count(s, m02), 3, "win on par, commander alive")
			s.turn = n + 1
			eq(Stars.count(s, m02), 2, "one turn late")
			s.heroDeaths.p = 1
			eq(Stars.count(s, m02), 1, "commander fell once")
			s.winner = "e"
			eq(Stars.count(s, m02), 0, "loss = no stars")
			var m03: Dictionary = Content.level("m03")
			var k: int = m03.stars.lost
			var s3 := Game.new_game(m03)
			s3.winner = "p"
			s3.lost.p = k
			eq(Stars.count(s3, m03), 3, "lost within the bar")
			s3.lost.p = k + 1
			eq(Stars.count(s3, m03), 2, "one too many lost")
			var old := s3.duplicate()
			old.erase("lost") # save from before the counter
			eq(Stars.count(old, m03), 3, "old save: no counter = nothing lost"),
	)
	run(
		"rules tables = docs/spec.md (cost, atk, atkMax, def, mv, rmin, rmax; terrain def / cost)",
		func() -> void:
			var spec := {
				"hero": [200, 55, 65, 20, 4, 1, 1],
				"soldier": [150, 50, 55, 5, 4, 1, 1],
				"archer": [250, 50, 55, 5, 4, 1, 2],
				"boat": [300, 50, 55, 10, 4, 1, 1],
				"shaman": [400, 40, 45, 5, 4, 1, 1],
				"drum": [500, 35, 40, 10, 4, 1, 1],
				"wolf": [500, 60, 65, 15, 5, 1, 1],
				"elephant": [600, 60, 70, 30, 4, 1, 1],
				"catapult": [700, 50, 70, 10, 3, 2, 4],
				"bird": [750, 70, 80, 25, 6, 1, 1],
				"ghost": [150, 40, 50, 2, 4, 1, 1],
			}
			for t: String in spec:
				var u: Dictionary = Rules.UNITS[t]
				eq([u.cost, u.atk, u.atkMax, u.def, u.mv, u.rmin, u.rmax], spec[t], t)
			eq(Rules.UNITS.keys().size(), spec.size(), "unit types")
			var ter := {
				".": [5, 1],
				"r": [0, 1],
				"f": [10, 2],
				"h": [10, 2],
				"m": [15, 3],
				"~": [0, 3],
				"=": [5, 1],
				"v": [15, 1],
				"c": [15, 1],
				"x": [15, 1],
				"t": [15, 1],
			}
			for k: String in ter:
				eq([Rules.TERRAIN[k].def, Rules.TERRAIN[k].cost], ter[k], "terrain " + k),
	)
	run(
		"AE2 damage modifiers: archer vs fly, drum vs ghost, poisoned attacker, defender rank, flyer terrain def",
		func() -> void:
			var s := blank(
				[
					["p", "archer", 1, 1],
					["p", "soldier", 1, 2],
					["e", "bird", 2, 1],
					["p", "drum", 3, 3],
					["e", "ghost", 4, 3],
					["e", "soldier", 2, 2],
				]
			)
			var ar: Dictionary = s.units[0]
			var so: Dictionary = s.units[1]
			var bird: Dictionary = s.units[2]
			var foe: Dictionary = s.units[5]
			eq(Game.damage(s, ar, 1, 1, 100, bird, 0.0) - Game.damage(s, so, 1, 1, 100, bird, 0.0), 15, "archer +15 vs flyer")
			eq(Game.damage(s, unit(s, 3), 3, 3, 100, unit(s, 4), 0.0), 43, "drum 35 +15 vs ghost - 2 def - 5 field")
			eq(Game.damage(s, so, 1, 2, 100, foe, 0.0), 40, "plain soldier hit")
			so.poison = "e"
			so.poisonAmt = 10
			eq(Game.damage(s, so, 1, 2, 100, foe, 0.0), 30, "poisoned attacker -10 atk")
			so.erase("poison")
			foe.rank = 2
			eq(Game.damage(s, so, 1, 2, 100, foe, 0.0), 36, "defender rank 2 -> +4 def")
			var field := Game.damage(s, so, 1, 1, 100, bird, 0.0)
			s.tiles[1][2] = "f"
			eq(field - Game.damage(s, so, 1, 1, 100, bird, 0.0), 5, "flyer still gets terrain def (forest 10 vs field 5)"),
	)
	run(
		"AE2 levels: capped at 9; an attacker killed by the counter does not level",
		func() -> void:
			var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 2, 1], ["p", "soldier", 3, 3, 1], ["e", "elephant", 4, 3]])
			s.units[0].rank = Rules.RULES.maxRank
			s.units[0].xp = 10000000
			Game.fixed_roll = 0.0
			var ev := Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
			eq(s.units[0].rank, Rules.RULES.maxRank, "stays at max")
			check(
				not ev.any(
					func(e: Dictionary) -> bool:
						return e.t == "rank",
				),
				"no rank event at max",
			)
			var weak: Dictionary = s.units[2]
			weak.xp = 10000000
			var ev2 := Game.do_action(s, { "id": weak.id, "to": [3, 3], "kind": "attack", "target": s.units[3].id })
			check(Game.unit_by_id(s, id_of(weak)) == null, "killed by the counter")
			check(
				not ev2.any(
					func(e: Dictionary) -> bool:
						return e.t == "rank" and e.id == weak.id,
				),
				"dead attacker never ranks up",
			),
	)
	run(
		"loss: a side that captures its first castle mid-game falls like a castled side (spec: never held a castle)",
		func() -> void:
			var s := blank([["p", "hero", 3, 3], ["e", "hero", 4, 4], ["e", "soldier", 1, 4]])
			owner_of(s).erase(Vector2i(5, 5))
			s.tiles[5][5] = "c"
			s.hadCastle.e = false
			s.side = "e"
			Game.do_action(s, { "id": 2, "to": [5, 5], "kind": "capture" })
			var had: bool = s.hadCastle.e
			check(had, "capturing a castle marks the side")
			s.owner[Vector2i(5, 5)] = "p" # we retake it
			s.units = units_of(s).filter(
				func(u: Dictionary) -> bool:
					return u.id != 2,
			)
			s.heroDead.e = true
			eq(Game.loss_reason(s, "e"), "castlesLost", "no castle + commander dead, army left"),
	)
	run(
		"reach mission: commander dead and no castle to rebuy it = lost (no soft-lock until timeUp)",
		func() -> void:
			var s := blank([["p", "soldier", 3, 3], ["e", "soldier", 5, 4]])
			s.win = { "type": "reach", "at": [[2, 5]] }
			owner_of(s).erase(Vector2i(0, 0))
			s.hadCastle.p = false
			s.heroDead.p = true
			eq(Game.loss_reason(s, "p"), "heroFell")
			s.owner[Vector2i(0, 0)] = "p"
			eq(Game.loss_reason(s, "p"), null, "a castle left: can rebuy, still playing"),
	)
	run(
		"AI: commander rebought on the reach goal steps off (offGoal) instead of waiting there",
		func() -> void:
			var s := blank([["e", "soldier", 5, 4]])
			s.win = { "type": "reach", "at": [[0, 0]] }
			s.heroDead.p = true
			s.heroKey.p = "anhhung"
			s.gold.p = 1000
			var h: Dictionary = Game.buy(s, 0, 0, "hero")
			AI.rng = func() -> float:
				return 0.5
			var step: Variant = AI.next_step(s, { })
			AI.rng = AI._gen.randf
			var acts: bool = step != null and step.kind == "act" and step.act.id == h.id
			check(acts, "acts with the commander")
			var leaves: bool = step != null and step.act.to != [0, 0]
			check(leaves, "leaves the goal tile (got %s)" % [step.act.to if step != null else null]),
	)
	run(
		"AE2 loss: castles gone AND commander dead; hero capture of the last castle wins only then",
		func() -> void:
			var s := blank([["p", "soldier", 4, 4], ["p", "hero", 4, 5], ["e", "hero", 1, 4]])
			s.tiles[3][4] = "v"
			check(not Game.can_capture(s, unit(s, 0), 5, 5), "soldier vs castle")
			check(Game.can_capture(s, unit(s, 0), 4, 3), "soldier vs village")
			Game.do_action(s, { "id": s.units[1].id, "to": [5, 5], "kind": "capture" })
			eq(s.winner, null, "enemy commander still alive")
			s.units[2].hp = 1
			Game.end_turn(s)
			Game.end_turn(s)
			s.units[0].x = 1
			s.units[0].y = 3
			Game.do_action(s, { "id": s.units[0].id, "to": [1, 3], "kind": "attack", "target": s.units[2].id })
			eq(s.winner, "p")
			eq(s.reason, "castlesLost"),
	)
