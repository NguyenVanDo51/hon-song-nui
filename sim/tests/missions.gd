extends "res://sim/tests/test_base.gd"
## missions tests (run by sim/tests.gd)

# ---------- missions ----------
func mission_tests() -> void:
	run(
		"rout mission: enemy without castle does not lose at start; loses when wiped",
		func() -> void:
			var s := Game.new_game(mission("m01"))
			Game.end_turn(s)
			Game.end_turn(s)
			eq(s.winner, null)
			var first_e: Dictionary = units_of(s).filter(
				func(u: Dictionary) -> bool:
					return u.side == "e",
			)[0]
			s.units = units_of(s).filter(
				func(u: Dictionary) -> bool:
					return u.side == "p" or u.id == first_e.id,
			)
			var last: Dictionary = first_e
			last.hp = 1
			var hero: Dictionary = units_of(s).filter(
				func(u: Dictionary) -> bool:
					return u.type == "hero",
			)[0]
			hero.x = last.x - 1
			hero.y = last.y
			for u: Dictionary in s.units:
				if u.id != hero.id and u.x == hero.x and u.y == hero.y:
					u.x = 0
			Game.do_action(s, { "id": hero.id, "to": [hero.x, hero.y], "kind": "attack", "target": last.id })
			eq(s.winner, "p")
			eq(s.reason, "routed"),
	)
	run(
		"survive: win when turn passes limit; waves spawn, occupied tile shifts",
		func() -> void:
			var def: Dictionary = Content.mission("m03")
			var s := Game.new_game(def)
			var w: Array = def.waves[0].units[0]
			Game.spawn(s, "p", "soldier", xy(w, 1).x, xy(w, 1).y)
			Game.end_turn(s)
			Game.end_turn(s)
			Game.end_turn(s)
			var spawned: Array = units_of(s).filter(
				func(u: Dictionary) -> bool:
					return u.side == "e",
			)
			eq(spawned.size(), 3)
			check(
				not spawned.any(
					func(u: Dictionary) -> bool:
						return u.x == w[1] and u.y == w[2],
				),
				"occupied tile skipped",
			)
			for i in 40:
				if s.winner != null:
					break
				Game.end_turn(s)
			eq(s.winner, "p")
			eq(s.reason, "survived")
			eq(s.turn, 11),
	)
	run(
		"hero mission: killing enemy hero wins even with castles left",
		func() -> void:
			var s := Game.new_game(mission("m04"))
			var eh: Dictionary = units_of(s).filter(
				func(u: Dictionary) -> bool:
					return u.side == "e" and u.type == "hero",
			)[0]
			var el: Dictionary = units_of(s).filter(
				func(u: Dictionary) -> bool:
					return u.side == "p" and u.type == "soldier",
			)[0]
			eh.hp = 1
			el.x = eh.x
			el.y = eh.y + 1
			for u: Dictionary in s.units:
				if u.id != el.id and u.x == el.x and u.y == el.y:
					u.x = 13
					u.y = 9
			Game.do_action(s, { "id": el.id, "to": [el.x, el.y], "kind": "attack", "target": eh.id })
			eq(s.winner, "p")
			eq(s.reason, "heroKilled"),
	)
	run(
		"guard unit holds until player near",
		func() -> void:
			var s := Game.new_game(mission("m04"))
			Game.end_turn(s)
			var eh: Dictionary = units_of(s).filter(
				func(u: Dictionary) -> bool:
					return u.side == "e" and u.type == "hero",
			)[0]
			var at := [eh.x, eh.y]
			var n := 0
			while n < 50:
				n += 1
				var step: Variant = AI.next_step(s, { })
				if step == null:
					break
				var sd: Dictionary = step
				AI.apply_step(s, sd)
			eq([eh.x, eh.y], at)
			var guarding: bool = eh.guard
			check(guarding, "still guarding"),
	)
	run(
		"allowed list limits buys",
		func() -> void:
			var s := Game.new_game(mission("m02"))
			s.units = units_of(s).filter(
				func(u: Dictionary) -> bool:
					return not (u.x == 1 and u.y == 2),
			)
			eq(
				Game.buy_options(s, "p", 1, 2).map(
					func(o: Dictionary) -> String:
						return o.type,
				),
				["soldier", "archer"],
			),
	)
