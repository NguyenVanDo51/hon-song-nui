extends "res://sim/tests/test_base.gd"
## quest suite: Quests (data, progress from Game events), Stars.final

func _def(quests: Array) -> Dictionary:
	return { "quests": quests }

func _q(verb: String, what: Variant = null) -> Dictionary:
	return { "do": verb, "what": what }

func quest_tests() -> void:
	run("quests: for_level adds the DEBUT of newUnits", func() -> void:
		var qs := Quests.for_level(mission("m02"))
		check(qs.any(func(q: Dictionary) -> bool: return q.do == "attack_with" and q.what == "archer"), "m02 attack_with archer")
		check(not qs.any(func(q: Dictionary) -> bool: return q.do == "win"), "no win line")
		# enemy-only new unit -> kill_type
		var def := { "newUnits": ["elephant"], "units": [["p", "hero", 0, 0], ["e", "elephant", 3, 3]], "allowed": { "p": ["soldier"], "e": ["elephant"] } }
		var q2 := Quests.for_level(def)
		eq(q2.size(), 1, "one quest")
		eq(q2[0].do, "kill_type", "enemy-only -> kill_type")
		eq(q2[0].what, "elephant", "what")
		def.tutorial = []
		eq(Quests.for_level(def).size(), 0, "tutorial level: no DEBUT")
		# dup of a manual quest skipped
		var def3 := { "quests": [_q("attack_with", "archer")], "newUnits": ["archer"], "allowed": { "p": ["archer"] } }
		eq(Quests.for_level(def3).size(), 1, "duplicate skipped")
		eq(Quests.for_level(def3)[0].have, 0, "have 0")
	)
	run("quests: observe credits only side p", func() -> void:
		var s := blank([["p", "archer", 1, 1], ["e", "soldier", 1, 3], ["e", "archer", 4, 4]])
		Quests.init_state(s, _def([_q("attack_with", "archer")]))
		var ev := Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
		eq(Quests.observe(s, ev), [0], "p archer hit")
		eq(Quests.done_count(s), 1, "done")
		var s2 := blank([["e", "archer", 1, 1], ["p", "soldier", 1, 3]])
		Quests.init_state(s2, _def([_q("attack_with", "archer")]))
		s2.side = "e"
		var ev2 := Game.do_action(s2, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
		eq(Quests.observe(s2, ev2), [], "e archer hit")
		eq(Quests.done_count(s2), 0, "not done")
	)
	run("quests: kill by counter-attack credits p", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 2, 1, 1]])
		Quests.init_state(s, _def([_q("kill_with"), _q("kill_type", "soldier")]))
		Game.fixed_roll = Game.ROLL_TOP
		s.side = "e"
		var ev := Game.do_action(s, { "id": 2, "to": [2, 1], "kind": "attack", "target": 1 })
		check(ev.any(func(e: Dictionary) -> bool: return e.t == "die"), "e soldier died to the counter")
		eq(Quests.observe(s, ev), [0, 1], "both kill quests")
	)
	run("quests: heal in enemy end_turn credits p", func() -> void:
		var s := blank([["p", "soldier", 2, 2, 50]])
		s.tiles[2][2] = "v"
		s.owner[Vector2i(2, 2)] = "p"
		Quests.init_state(s, _def([_q("heal_on", "v"), _q("heal_on", "c")]))
		var ev := Game.end_turn(s)
		ev.append_array(Game.end_turn(s))
		check(ev.any(func(e: Dictionary) -> bool: return e.t == "heal"), "heal event")
		eq(Quests.observe(s, ev), [0], "heal_on v only")
	)
	run("quests: move / stand_on / capture / hit_type", func() -> void:
		var s := blank([["p", "hero", 1, 1]])
		s.tiles[3][1] = "v"
		Quests.init_state(s, _def([_q("move", "hero"), _q("stand_on", "v"), _q("capture", "v"), _q("capture", "c"), _q("move", "archer")]))
		var ev := Game.do_action(s, { "id": 1, "to": [1, 3], "kind": "capture" })
		eq(Quests.observe(s, ev), [0, 1, 2], "move + stand_on + capture")
		var s2 := blank([["p", "soldier", 1, 1], ["e", "soldier", 1, 2, 1], ["e", "archer", 4, 4]])
		Quests.init_state(s2, _def([_q("hit_type", "archer"), _q("hit_type", "soldier"), _q("kill_type", "soldier")]))
		var ev2 := Game.do_action(s2, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
		eq(Quests.observe(s2, ev2), [1, 2], "hit_type of a victim that died + kill_type")
	)
	run("quests: note completes UI verbs", func() -> void:
		var s := blank([])
		Quests.init_state(s, _def([_q("buy", "archer"), _q("select", "hero"), _q("end_turn")]))
		eq(Quests.note(s, "buy", "soldier"), [], "wrong type")
		eq(Quests.note(s, "buy", "archer"), [0], "right type")
		eq(Quests.note(s, "select", "hero"), [1], "select")
		eq(Quests.note(s, "end_turn", null), [2], "end_turn")
		eq(Quests.done_count(s), 3, "done")
		eq(Quests.total(s), 3, "total")
	)
	run("quests: text", func() -> void:
		eq(Quests.text(_q("attack_with", "archer")), "Đánh bằng Cung thủ", "attack_with")
		eq(Quests.text(_q("buy")), "Mua 1 quân", "buy any")
		eq(Quests.text(_q("capture", "v")), "Chiếm 1 Làng", "capture")
		eq(Quests.text({ "do": "move", "what": null, "text": "X" }), "X", "override")
	)
	run("quests: feasible", func() -> void:
		var m := mission("m02")
		eq(Quests.feasible(m, _q("attack_with", "archer")), "", "archer ok")
		check(Quests.feasible(m, _q("attack_with", "elephant")) != "", "no elephant")
		check(Quests.feasible(m, _q("repair")) != "", "no ruin")
		eq(Quests.feasible(m, _q("capture", "c")), "", "capture c")
		check(Quests.feasible(m, _q("zzz")) != "", "unknown verb")
	)
	run("quests: every campaign level's quests are doable", func() -> void:
		for def: Dictionary in Content.levels():
			for q: Dictionary in Quests.for_level(def):
				eq(Quests.feasible(def, q), "", "%s %s" % [def.id, q.do])
	)
	run("quests: Stars.final", func() -> void:
		var s := blank([])
		s.winner = "p"
		s.turn = 3
		s.heroDeaths = { "p": 0 }
		s.lost = { "p": 0 }
		var def := { "stars": { "turns": 5 } }
		eq(Stars.count(s, def), 3, "base 3")
		eq(Stars.final(s, def), 3, "no quests key")
		s.quests = [{ "do": "move", "what": null, "n": 1, "have": 0, "done": false }]
		eq(Stars.final(s, def), 2, "3 -> 2")
		eq(Stars.count(s, def), 3, "count ignores penalty goal")
		s.turn = 99
		s.heroDeaths = { "p": 1 }
		eq(Stars.count(s, def), 1, "base 1")
		eq(Stars.final(s, def), 1, "floor 1")
		var goals := Stars.check(s, def)
		eq(goals.size(), 4, "4th goal")
		eq(goals[3].key, "quests", "key")
		eq(goals[3].text, "Nhiệm vụ 0/1", "text")
		var qs: Array = s.quests
		var q0: Dictionary = qs[0]
		q0.done = true
		eq(Stars.final(s, def), 1, "all done, base 1")
		s.winner = "e"
		eq(Stars.final(s, def), 0, "not won")
	)
	run("quests: old save without quests key", func() -> void:
		var s := blank([])
		check(not s.has("quests"), "no key")
		eq(Quests.done_count(s), 0, "done 0")
		eq(Quests.total(s), 0, "total 0")
		eq(Quests.observe(s, [{ "t": "hit" }]), [], "observe no-op")
		eq(Quests.note(s, "buy", "archer"), [], "note no-op")
	)
