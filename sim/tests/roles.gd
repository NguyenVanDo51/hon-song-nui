extends "res://sim/tests/test_base.gd"
## unit roles (2026-11-09, docs/spec.md "Khác AE2 gốc có chủ ý"): drum heals, wolf crosses rough ground, boat river bonus,
## catapult pierces terrain cover (run by sim/tests.gd)

func role_tests() -> void:
	run(
		"drum heals allies within 2 at our turn start (not itself, no stacking with a castle)",
		func() -> void:
			var s := blank([["p", "drum", 2, 2, 50], ["p", "soldier", 3, 3, 50], ["p", "soldier", 2, 5, 50], ["e", "soldier", 5, 4]])
			units_of(s).append({ "id": 9, "side": "p", "type": "soldier", "x": 0, "y": 0, "hp": 50, "xp": 0, "rank": 0, "acted": false })
			units_of(s).append({ "id": 10, "side": "p", "type": "drum", "x": 1, "y": 1, "hp": 100, "xp": 0, "rank": 0, "acted": false })
			s.side = "e"
			Game.end_turn(s)
			eq(unit(s, 0).hp, 60, "drum at (2,2) healed by the other drum at (1,1)")
			eq(unit(s, 1).hp, 60, "soldier 2 away healed 10")
			eq(unit(s, 2).hp, 50, "soldier 3 away not healed")
			eq(unit(s, 4).hp, 70, "on our castle: castle 20, not 20 + 10")
			eq(Buffs.heal_aura(s, unit(s, 5)), 10, "drum (1,1) gets the other drum's heal")
			eq(Buffs.heal_aura(s, unit(s, 3)), 0, "foe gets nothing"),
	)
	run(
		"wolf (beast) pays 1 on forest / hill / mountain; a soldier pays the table",
		func() -> void:
			eq([Game.move_cost("beast", "f"), Game.move_cost("beast", "h"), Game.move_cost("beast", "m")], [1.0, 1.0, 1.0])
			eq(Game.move_cost("beast", "~"), 3.0, "beast wades like a walker")
			eq(Game.move_cost("foot", "m"), 3.0)
			var s := blank([["p", "wolf", 0, 2], ["p", "soldier", 0, 3], ["e", "soldier", 5, 4]])
			for x in range(1, 6):
				s.tiles[2][x] = "m"
				s.tiles[3][x] = "m"
			check(Game.reachable(s, unit(s, 0)).has(Vector2i(5, 2)), "wolf runs 5 mountains")
			check(not Game.reachable(s, unit(s, 1)).has(Vector2i(2, 3)), "soldier stops after 1 mountain"),
	)
	run(
		"boat in the river: +15 atk, +25 def",
		func() -> void:
			var s := blank([["p", "boat", 1, 1], ["e", "soldier", 2, 1], ["e", "boat", 3, 3], ["p", "soldier", 3, 4]])
			s.tiles[1][1] = "~"
			s.tiles[3][3] = "~"
			# boat atk mid 52 + 15 - (soldier def 5 + plain 5) = 57
			eq(Game.damage(s, unit(s, 0), 1, 1, 100, unit(s, 1)), 57)
			# soldier 52 - (boat def 10 + water 0 + 25) = 17
			eq(Game.damage(s, unit(s, 3), 3, 4, 100, unit(s, 2)), 17),
	)
	run(
		"catapult pierces terrain cover; others do not",
		func() -> void:
			var s := blank([["p", "catapult", 1, 1], ["p", "soldier", 3, 2], ["e", "elephant", 3, 1]])
			s.tiles[1][3] = "m"
			# catapult mid 60 - golem def 30 (mountain 15 ignored) = 30
			eq(Game.damage(s, unit(s, 0), 1, 1, 100, unit(s, 2)), 30)
			# soldier mid 52 - (30 + mountain 15) = 7
			eq(Game.damage(s, unit(s, 1), 3, 2, 100, unit(s, 2)), 7),
	)
