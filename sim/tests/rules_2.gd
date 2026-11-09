extends "res://sim/tests/test_base.gd"
## rules tests, part 2 (run by sim/tests.gd)

## rule tests, part 2 (split from rule_tests for the file-length cap)
func rule_tests_2() -> void:
	run(
		"kill leaves grave; shaman raises ghost",
		func() -> void:
			var s := blank([["p", "elephant", 1, 1], ["e", "soldier", 2, 1, 10], ["p", "shaman", 1, 3], ["e", "soldier", 5, 4]])
			Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
			eq(graves_of(s).size(), 1)
			Game.do_action(s, { "id": 3, "to": [2, 2], "kind": "raise", "target": [2, 1] })
			check(
				units_of(s).any(
					func(u: Dictionary) -> bool:
						return u.type == "ghost" and u.side == "p",
				),
				"ghost raised",
			),
	)
	run(
		"income + heal at turn start; buy respects cap",
		func() -> void:
			var s := blank([["p", "soldier", 0, 0, 50], ["e", "soldier", 5, 4]])
			s.side = "e"
			s.gold.p = 0
			Game.end_turn(s)
			eq(s.gold.p, Rules.TERRAIN.c.income)
			eq(s.units[0].hp, 70)
			s.units[0].x = 1
			s.gold.p = 99999
			for i in 19:
				units_of(s).append({ "id": 100 + i, "side": "p", "type": "soldier", "x": 3, "y": i % 6, "hp": 100, "xp": 0, "rank": 0 })
			check(
				Game.buy_options(s, "p", 0, 0).all(
					func(o: Dictionary) -> bool:
						return not o.ok,
				),
				"cap blocks buy",
			),
	)
	run(
		"AE2 buy: new unit acts at once; buy on own-occupied castle -> must step off",
		func() -> void:
			var s := blank([["p", "soldier", 0, 0], ["e", "soldier", 5, 4]])
			s.gold.p = 5000
			var ok := func(t: String) -> bool:
				return Game.buy_options(s, "p", 0, 0).any(
					func(o: Dictionary) -> bool:
						return o.type == t and o.ok,
				)
			var can_archer: bool = ok.call("archer")
			check(can_archer, "buy allowed with our soldier on the castle")
			var a: Dictionary = Game.buy(s, 0, 0, "archer")
			check(not acted(a), "bought unit can act this turn")
			check(Game.stacked(s, a) and Game.stacked(s, unit(s, 0)), "both stacked")
			check(not Game.reachable(s, a).has(Vector2i(0, 0)), "new unit cannot stay on the shared tile")
			check(not Game.reachable(s, unit(s, 0)).has(Vector2i(0, 0)), "old unit cannot stay either")
			check(Game.buy_options(s, "p", 0, 0).is_empty(), "no 3rd unit on a stacked castle")
			eq(Game.do_action(s, { "id": a.id, "to": [0, 0], "kind": "wait" }), [], "wait in place rejected")
			Game.do_action(s, { "id": a.id, "to": [1, 1], "kind": "wait" })
			check(not Game.stacked(s, unit(s, 0)), "stack cleared after stepping off")
			var can_again: bool = ok.call("soldier")
			check(can_again, "can buy again on the same castle this turn")
			# boxed in: no free tile to step to -> cannot buy on top
			var b := blank(
				[
					["p", "soldier", 0, 0],
					["p", "soldier", 1, 0],
					["p", "soldier", 0, 1],
					["p", "soldier", 1, 1],
					["e", "soldier", 2, 0],
					["e", "soldier", 2, 1],
					["e", "soldier", 0, 2],
					["e", "soldier", 1, 2],
				]
			)
			b.gold.p = 5000
			for u: Dictionary in b.units:
				if u.id > 1:
					u.acted = true
			check(
				Game.buy_options(b, "p", 0, 0).all(
					func(o: Dictionary) -> bool:
						return not o.ok,
				),
				"boxed-in castle blocks buying on top",
			)
			# AE2 original: enemy standing on our castle does not block buying; the new unit steps off
			var c := blank([["e", "soldier", 0, 0]])
			c.gold.p = 500
			check(
				Game.buy_options(c, "p", 0, 0).any(
					func(o: Dictionary) -> bool:
						return o.ok,
				),
				"buy under an enemy on our castle",
			)
			var nb: Dictionary = Game.buy(c, 0, 0, "soldier")
			check(not Game.reachable(c, nb).has(Vector2i(0, 0)), "new unit must step off"),
	)
	run(
		"unbuy: take back a buy on top of another unit until it steps off",
		func() -> void:
			var s := blank([["p", "soldier", 0, 0], ["e", "soldier", 5, 4]])
			s.gold.p = 1000
			var a: Dictionary = Game.buy(s, 0, 0, "archer")
			check(Game.can_unbuy(s, a), "stacked fresh buy can be taken back")
			check(Game.unbuy(s, id_of(a)), "unbuy ok")
			eq(s.gold.p, 1000, "full refund")
			check(Game.unit_by_id(s, id_of(a)) == null and not Game.stacked(s, unit(s, 0)), "new unit gone, castle unit alone")
			var b: Dictionary = Game.buy(s, 0, 0, "archer")
			Game.do_action(s, { "id": b.id, "to": [1, 0], "kind": "wait" })
			check(not Game.can_unbuy(s, b), "no take-back once it stepped off")
			var c := blank([["e", "soldier", 4, 4]])
			c.gold.p = 1000
			var lone: Dictionary = Game.buy(c, 0, 0, "soldier")
			check(not Game.can_unbuy(c, lone), "buy on an empty castle cannot be taken back")
			var h := blank([["p", "soldier", 0, 0], ["e", "soldier", 5, 4]])
			h.gold.p = 1000
			h.heroDead.p = true
			var cost := Game.hero_cost(h, "p")
			var hero: Dictionary = Game.buy(h, 0, 0, "hero")
			var undone: bool = Game.unbuy(h, id_of(hero)) and h.heroDead.p and h.gold.p == 1000 and Game.hero_cost(h, "p") == cost
			check(undone, "commander rebuy taken back: dead again, same price"),
	)
	run(
		"AI moves a unit it bought the same turn",
		func() -> void:
			var s := blank([["p", "soldier", 0, 0], ["e", "hero", 4, 4]])
			s.side = "e"
			s.gold.e = 150
			s.units[1].acted = true
			var bought := false
			var mem := { }
			for i in 20:
				var st: Variant = AI.next_step(s, mem)
				if st == null:
					break
				if st.kind == "buy":
					bought = true
				var sd: Dictionary = st
				AI.apply_step(s, sd)
			var nu: Array = units_of(s).filter(
				func(u: Dictionary) -> bool:
					return u.side == "e" and u.type != "hero",
			)
			check(bought and nu.size() == 1, "AI bought")
			var nu_acted: bool = nu.size() == 1 and nu[0].acted
			check(nu_acted, "bought unit acted this turn"),
	)
	run(
		"AI buys under a unit on its castle (own acted / enemy), never a boat without water",
		func() -> void:
			var s := blank([["p", "soldier", 0, 0], ["e", "hero", 5, 5]])
			s.side = "e"
			s.gold.e = 300
			s.units[1].acted = true
			var st: Variant = AI.next_step(s, { })
			var under_own: bool = st != null and st.kind == "buy" and st.x == 5 and st.y == 5
			check(under_own, "buys under own acted hero (got %s)" % [st])
			var no_boat: bool = st == null or st.type != "boat"
			check(no_boat, "no boat on a dry map")
			var c := blank([["p", "soldier", 0, 0], ["p", "soldier", 5, 5], ["e", "hero", 3, 0]])
			c.side = "e"
			c.gold.e = 150
			c.units[2].acted = true
			var st2: Variant = AI.next_step(c, { })
			var under_foe: bool = st2 != null and st2.kind == "buy"
			check(under_foe, "buys under an enemy on its castle (got %s)" % [st2]),
	)
	run(
		"AI commander: healthy -> advances through one unit's threat (no retreat to a safe rear tile); " + "hurt -> never ends where it can die",
		func() -> void:
			var wide := func(units: Array) -> Dictionary:
				var s := blank(units)
				s.w = 12
				s.h = 7
				var tiles := []
				s.tiles = tiles
				for y in 7:
					var row := []
					row.resize(12)
					row.fill(".")
					tiles.append(row)
				s.tiles[0][0] = "c"
				s.tiles[6][11] = "c"
				s.owner = { Vector2i(0, 0): "p", Vector2i(11, 6): "e" }
				s.side = "e"
				return s
			AI.rng = func() -> float:
				return 0.5
			# user report (m07): commander backed off to a tile nobody threatens instead of heading for the fight
			var a: Dictionary = wide.call([["e", "hero", 8, 3], ["p", "soldier", 0, 3]])
			var st: Variant = AI.next_step(a, { })
			var to_a: Array = st.act.to
			var to := xy(to_a)
			var gd := mini(Game.dist(to.x, to.y, 0, 3), Game.dist(to.x, to.y, 0, 0))
			check(gd <= 4, "commander closes in (dist to nearest goal %d, start 8, got %s)" % [gd, st.act])
			var b: Dictionary = wide.call([["e", "hero", 8, 3, 35], ["p", "soldier", 1, 2], ["p", "soldier", 1, 4], ["p", "archer", 0, 3]])
			var st2: Variant = AI.next_step(b, { })
			var h: Dictionary = b.units[0]
			h.x = st2.act.to[0]
			h.y = st2.act.to[1]
			var worst := 0
			for e: Dictionary in AI.threat_map(b, "e").get(pos(h), []):
				var e_hp: int = e.hp
				worst += Game.damage(b, e, pos(e).x, pos(e).y, e_hp, h, Game.ROLL_TOP)
			var survives: bool = worst < h.hp
			check(survives, "hurt commander out of lethal reach (max incoming %d vs hp %d at %s)" % [worst, h.hp, st2.act.to])
			AI.rng = AI._gen.randf,
	)
	run(
		"AE2 levels: xp = dmg x (victim atk+atkMax+def); 1 level per fight max, leftover carries, +2 atk/+2 def",
		func() -> void:
			var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 2, 1]])
			var a: Dictionary = s.units[0]
			var need := Game.xp_need(s, a)
			eq(need, int((50 + 55 + 5) * 200.0 / 3.0))
			a.xp = need * 3
			Game.fixed_roll = 0.0
			Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
			Game.fixed_roll = -1.0
			eq(a.rank, 1, "only one level")
			eq(a.xp, need * 2 + 40 * 110, "leftover + this hit's xp")
			eq(Game.atk_range(s, a), [52, 56]),
	)
	run(
		"AE2 xp uses rank-boosted stats: victim quality for xp gained, own quality for the next level (RM Unit.java 250-263)",
		func() -> void:
			var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 2, 1]])
			var a: Dictionary = s.units[0]
			var d: Dictionary = s.units[1]
			d.rank = 2 # quality 110 + 3 x 2 x 2 = 122
			a.rank = 1 # quality 116
			eq(Game.quality(s, d), 122)
			@warning_ignore("integer_division")
			eq(Game.xp_need(s, a), 116 * 200 / 3, "own quality incl. rank")
			Game.fixed_roll = 0.0
			var ev := Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
			Game.fixed_roll = -1.0
			var hit: int = ev.filter(
				func(e: Dictionary) -> bool:
					return e.t == "hit" and not e.get("counter", false),
			)[0].amount
			var back: int = ev.filter(
				func(e: Dictionary) -> bool:
					return e.t == "hit" and e.get("counter", false),
			)[0].amount
			eq(a.xp, hit * 122, "xp = dmg x victim quality incl. its rank")
			eq(d.xp, back * 116, "counter xp = dmg x attacker quality incl. its rank")
			# float xpScale vs RM's integer q * 200 / 3: same for every quality a unit can have
			for type: String in Rules.UNITS:
				for r in Rules.RULES.maxRank + 1:
					var u := { "side": "p", "type": type, "rank": r }
					var q := Game.quality(s, u)
					@warning_ignore("integer_division")
					eq(Game.xp_need(s, u), q * 200 / 3, "%s rank %d" % [type, r]),
	)
	run(
		"reach goal: a commander bought on the goal tile must walk off and back",
		func() -> void:
			var s := blank([["p", "soldier", 3, 3], ["e", "soldier", 5, 4]])
			s.win = { "type": "reach", "at": [[0, 0]] }
			s.heroDead.p = true
			s.heroKey.p = "anhhung"
			s.gold.p = 1000
			var h: Dictionary = Game.buy(s, 0, 0, "hero")
			check(not Game.hero_on_goal(s), "buying there is not reaching")
			Game.do_action(s, { "id": h.id, "to": [1, 0], "kind": "wait" })
			Game.end_turn(s)
			Game.end_turn(s)
			Game.do_action(s, { "id": h.id, "to": [0, 0], "kind": "wait" })
			eq(s.reason, "reached"),
	)
	run(
		"AE2 commander: rebuy 200 + 200/death (max 1000), comes back with its level",
		func() -> void:
			var s := blank([["p", "hero", 1, 1, 1], ["e", "elephant", 2, 1]])
			s.units[0].rank = 3
			s.side = "e"
			Game.fixed_roll = 0.0
			Game.do_action(s, { "id": 2, "to": [2, 1], "kind": "attack", "target": 1 })
			Game.fixed_roll = -1.0
			var dead: bool = s.heroDead.p
			check(dead, "dead")
			eq(s.winner, null, "castle left: not out")
			eq(Game.hero_cost(s, "p"), 400)
			s.side = "p"
			s.gold.p = 400
			var h: Dictionary = Game.buy(s, 0, 0, "hero")
			eq(h.rank, 3, "level kept")
			s.heroDeaths.p = 9
			eq(Game.hero_cost(s, "p"), 1000),
	)
	run(
		"AE2 unit cap: campaign 100 unless the mission sets one; skirmish keeps its chosen cap",
		func() -> void:
			for m: Dictionary in Content.levels():
				eq(Game.new_game(m).unitCap, m.get("unitCap", 100), str(m.id))
			eq(Game.new_game(Content.skirmish_def("dong_bang", "anhhung", false)).unitCap, 10, "skirmish default")
			eq(Game.new_game(Content.skirmish_def("dong_bang", "anhhung", false, 500, 25)).unitCap, 25, "skirmish chosen")
			var d: Dictionary = mission("m02").duplicate()
			d.unitCap = 12
			eq(Game.new_game(d).unitCap, 12, "mission override"),
	)
	run(
		"AE2 titles: 4 tiers (0-1 none, 2-3, 4-5, 6-9); commanders only LvN; big level-up only on renames",
		func() -> void:
			eq(Content.unit_title("Vệ binh", 0), "Vệ binh")
			eq(Content.unit_title("Vệ binh", 1), "Vệ binh Lv1")
			eq(Content.unit_title("Vệ binh", 3), "Vệ binh lão luyện Lv3")
			eq(Content.unit_title("Vệ binh", 5), "Vệ binh tinh nhuệ Lv5")
			eq(Content.unit_title("Vệ binh", 6), "Vệ binh dũng mãnh Lv6")
			eq(Content.unit_title("Vệ binh", 9), "Vệ binh dũng mãnh Lv9")
			eq(Content.unit_title("Hiệp Sĩ Chỉ Huy", 4, true), "Hiệp Sĩ Chỉ Huy Lv4")
			var loud := []
			for r in range(1, 10):
				if Content.rank_announced("soldier", r):
					loud.append(r)
			eq(loud, [2, 4, 6])
			check(not Content.rank_announced("hero", 2), "commander: no rename announcement"),
	)
	run(
		"mission order values are unique",
		func() -> void:
			var seen := { }
			for m: Dictionary in Content.levels():
				check(not seen.has(m.order), "duplicate order %s (%s)" % [m.order, m.id])
				seen[m.order] = true,
	)
	run(
		"saves of an older state version / unknown unit type are refused",
		func() -> void:
			var s := Game.new_game(mission("m03"))
			var old: Dictionary = s.duplicate(true)
			old.v = 1
			check(not Content.save_fits({ "state": old, "ctx": { "kind": "campaign", "id": "m03" } }), "old version refused")
			var bad: Dictionary = s.duplicate(true)
			bad.units[0].type = "wizard"
			check(not Content.save_fits({ "state": bad, "ctx": { "kind": "campaign", "id": "m03" } }), "unknown unit refused")
			var nowin: Dictionary = s.duplicate(true)
			nowin.win = { "type": "teleport" }
			check(not Content.save_fits({ "state": nowin, "ctx": { "kind": "campaign", "id": "m03" } }), "unknown win type refused"),
	)
	run(
		"v3 save (stamps without amounts) migrates to v4: aura / poison keep their old 10",
		func() -> void:
			var s := Game.new_game(mission("m03"))
			var v3: Dictionary = { "state": s.duplicate(true), "ctx": { "kind": "campaign", "id": "m03" } }
			v3.state.v = 3
			v3.state.units[0].aura = "p"
			v3.state.units[1].poison = "e"
			check(not Content.save_fits(v3), "v3 does not fit before migrating")
			Content.migrate_save(v3)
			eq(v3.state.v, Content.STATE_V)
			check(Content.save_fits(v3), "migrated v3 fits")
			var st3: Dictionary = v3.state
			eq([Game.aura_atk(unit(st3, 0)), Game.poison_amt(unit(st3, 1))], [10, 10])
			eq(Game.aura_atk(unit(st3, 2)), 0, "no stamp -> 0"),
	)
	run(
		"unit flags are data: heavy set, aiWeight on buyables, raise / vsType name real types",
		func() -> void:
			var heavy := []
			for t: String in Rules.UNITS:
				var ut: Dictionary = Rules.UNITS[t]
				if ut.get("heavy", false):
					heavy.append(t)
				var r: Variant = ut.get("raise")
				check(r == null or Rules.UNITS.has(r), "%s raises a known type" % t)
				for v: String in ut.get("vsType", { }):
					check(Rules.UNITS.has(v), "%s vsType %s" % [t, v])
				if ut.get("buyable", true) and t != "hero":
					check(ut.has("aiWeight"), "aiWeight " + t)
			eq(heavy, ["hero", "elephant", "catapult", "bird"]),
	)
	run(
		"a new unit type defined only in UNITS: AI buys it (default weight), its flags work (vsType, aura, poison, raise)",
		func() -> void:
			var units: Dictionary = Rules.UNITS.duplicate(true)
			units["monk"] = {
				"cost": 100,
				"atk": 30,
				"atkMax": 31,
				"def": 5,
				"mv": 4,
				"rmin": 1,
				"rmax": 1,
				"move": "foot",
				"vsType": { "soldier": 7 },
				"aura": 4,
				"poison": 3,
				"raise": "soldier",
			}
			Game.use_tables(units, Rules.HEROES, Rules.RULES, Rules.TERRAIN)
			eq(AI.weight("monk"), AI.DEFAULT_WEIGHT)
			var s := blank([["p", "monk", 1, 1], ["p", "soldier", 1, 3], ["e", "soldier", 2, 1]])
			s.allowed.p = ["monk"]
			s.gold.p = 1000
			eq(AI.choose_buy(s, "p"), "monk", "no aiWeight: still bought, no crash")
			var mk: Dictionary = s.units[0]
			var foe: Dictionary = s.units[2]
			var plain := Game.damage(s, unit(s, 1), 1, 1, 100, foe, 0.0) # soldier 50 - 5 def - 5 field
			eq(Game.damage(s, mk, 1, 1, 100, foe, 0.0), 30 + 7 - 10, "vsType bonus")
			Game.fixed_roll = 0.0
			Game.do_action(s, { "id": mk.id, "to": [1, 1], "kind": "attack", "target": foe.id })
			eq(Game.poison_amt(foe), 3, "poison amount from data")
			eq(Game.aura_atk(unit(s, 1)), 4, "aura amount from data")
			eq(Game.damage(s, unit(s, 1), 1, 1, 100, foe, 0.0), plain + 4 + 3, "aura +4, target -3 def")
			s.graves = [{ "x": 0, "y": 1, "ttl": 3 }]
			mk.acted = false
			s.side = "p"
			Game.do_action(s, { "id": mk.id, "to": [1, 1], "kind": "raise", "target": [0, 1] })
			var raised: Variant = Game.unit_at(s, 0, 1)
			var raised_ok: bool = raised != null and raised.type == "soldier"
			check(raised_ok, "raise spawns the type named by `raise`")
			Game.use_tables(Rules.UNITS, Rules.HEROES, Rules.RULES, Rules.TERRAIN),
	)
	run(
		"objectives registry: a new win type is one entry (loss, round, AI goal, marks, bar)",
		func() -> void:
			eq(Objectives.types(), ["castles", "rout", "hero", "survive", "reach"])
			var s := blank([["p", "hero", 1, 1], ["e", "soldier", 4, 4]])
			s.win = { "type": "flag", "at": [[3, 1]] }
			check(Objectives.check(s).begins_with("unknown"), "unknown type flagged")
			var loss := func(st: Dictionary, side: String) -> Variant:
				if side == "e" and Game.unit_at(st, 3, 1) != null:
					return "flagTaken"
				return null
			var on_round := func(st: Dictionary) -> Variant:
				if st.turn > 3:
					return ["e", "late"]
				return null
			var ai_goals := func(st: Dictionary, _u: Dictionary) -> Variant:
				var at: Array = st.win.at
				return at.duplicate()
			Objectives.TYPES["flag"] = {
				"loss": loss,
				"on_round": on_round,
				"ai_goals": ai_goals,
				"marks": func(st: Dictionary) -> Array:
					return st.win.at,
				"bar_n": func(_st: Dictionary) -> int:
					return 7,
			}
			eq([Objectives.check(s), Objectives.marks(s), Objectives.bar_n(s)], ["", [[3, 1]], 7])
			eq(AI.goals_for(s, unit(s, 0), { }), [[3, 1]], "AI heads for the objective")
			Game.do_action(s, { "id": 1, "to": [3, 1], "kind": "wait" })
			eq([s.winner, s.reason], ["p", "flagTaken"], "loss hook")
			var s2 := blank([["p", "hero", 1, 1], ["e", "soldier", 4, 4]])
			s2.win = { "type": "flag", "at": [[3, 1]] }
			for i in 6:
				Game.end_turn(s2)
			eq([s2.winner, s2.reason, s2.turn], ["e", "late", 4], "round hook")
			Objectives.TYPES.erase("flag")
			eq(Objectives.marks(s), [], "no entry: no marks"),
	)
	run(
		"goal / end texts: every win type has copy, unknown types fall back",
		func() -> void:
			for t: String in Objectives.types():
				check(
					Content.goal_text({ "type": t, "turns": 5, "at": [[0, 0]] }, "brief", { "p": "anhhung", "e": "tuonggiac" }) != t,
					"brief copy " + t,
				)
				var bar := Content.goal_text(
					{ "type": t, "turns": 5, "at": [[0, 0]] },
					"bar",
					{ "p": "anhhung", "e": "tuonggiac" },
					{ "n": 1, "left": 2 },
				)
				check(bar != t, "bar copy " + t)
			eq(Content.goal_text({ "type": "teleport" }, "brief", { "p": "anhhung", "e": null }), "teleport")
			check(Content.tile_note("c").find("tướng") >= 0, "castle note names who captures"),
	)
	run(
		"save round-trip keeps types",
		func() -> void:
			var s := Game.new_game(mission("m02"))
			var back: Dictionary = str_to_var(var_to_str(s))
			eq(back, s)
			check(owner_of(back).keys()[0] is Vector2i, "Vector2i keys")
			check(back.units[0].hp is int, "int hp"),
	)
	run(
		"saves from older content are refused (removed commander / mission), current ones kept",
		func() -> void:
			var s := Game.new_game(mission("m03"))
			check(Content.save_fits({ "state": s, "ctx": { "kind": "campaign", "id": "m03" } }), "current save fits")
			var old: Dictionary = s.duplicate(true)
			old.heroKey.p = "trungnhi" # unknown commander key
			check(not Content.save_fits({ "state": old, "ctx": { "kind": "campaign", "id": "m03" } }), "unknown commander refused")
			# saves from before the two-commander change: named commanders map onto the fixed ones (same stats)
			var named: Dictionary = { "state": s.duplicate(true), "ctx": { "kind": "skirmish", "hero": "trungtrac", "easy": false } }
			named.state.heroKey = { "p": "trungtrac", "e": "mavien" }
			Content.migrate_save(named)
			eq([named.state.heroKey.p, named.state.heroKey.e, named.ctx.hero], ["anhhung", "tuonggiac", "anhhung"])
			check(Content.save_fits(named), "migrated save fits")
			check(not Content.save_fits({ "state": s, "ctx": { "kind": "campaign", "id": "m20" } }), "removed mission refused")
			check(not Content.save_fits({ "state": s, "ctx": { "kind": "skirmish", "hero": "lechan", "easy": false } }), "old skirmish hero refused")
			# stale key: placeholder, no crash
			eq(Content.hero_look("lechan").name, "lechan"),
	)
	run(
		"damaged saves are refused: no state, missing field, junk unit / buy list / controller / tile",
		func() -> void:
			var s := Game.new_game(mission("m03"))
			var ctx := { "kind": "campaign", "id": "m03" }
			check(Content.save_fits({ "state": s, "ctx": ctx }), "control: intact save fits")
			check(not Content.save_fits({ "ctx": ctx }), "no state")
			check(not Content.save_fits({ "state": "junk", "ctx": ctx }), "state not a dictionary")
			var cases := {
				"missing gold": func(d: Dictionary) -> void:
					d.erase("gold"),
				"unit not a dictionary": func(d: Dictionary) -> void:
					var us: Array = d.units
					us.append(7),
				"unknown type in buy list": func(d: Dictionary) -> void:
					var al: Array = d.allowed.p
					al.append("dragon_x"),
				"controller list not a dictionary": func(d: Dictionary) -> void:
					d.ctrl = "ai",
				"unknown tile": func(d: Dictionary) -> void:
					d.tiles[0][0] = "?",
			}
			for name: String in cases:
				var bad: Dictionary = s.duplicate(true)
				var f: Callable = cases[name]
				f.call(bad)
				check(not Content.save_fits({ "state": bad, "ctx": ctx }), name),
	)
