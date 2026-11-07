extends "res://sim/tests/test_base.gd"
## planner tests (run by sim/tests.gd)

## human-tactics knobs (AI.DEFAULT lone_w .. hero_cgoal, docs/ai.md "Kinh nghiệm người chơi")
const TACTICS := {
	"lone_w": 0.3,
	"tgt_sup": 0.5,
	"tgt_thr": 2.0,
	"home_val": 10.0,
	"bld_w": 20.0,
	"trade_w": 1.0,
	"order_w": 1.0,
	"feed_w": 1.0,
	"escort_w": 30.0,
	"hero_cgoal": 1.0,
}
## internet-tactics knobs (docs/ai.md "Mẹo người chơi trên mạng = Khó v4")
const V4 := { "buy_threat": 0.5, "promo_w": 1.0, "pl_dp": 1.0, "pl_chain": 1.0, "ret_terr": 1.0, "buy_sup": 4.0 }
## flexible army knobs (docs/ai.md "Đội hình linh hoạt = Khó v5")
const V5 := { "role_w": 1.0, "mix_w": 1.0, "pl_chain": 1.0 }

func planner_tests() -> void:
	run(
		"hard v2: only legal steps, state untouched, rng / roll globals restored",
		func() -> void:
			var prev: Callable = AI.rng
			var draw := [0]
			AI.rng = func() -> float:
				draw[0] += 1
				return 0.5
			for mid: String in Content.SKIRMISH.MAPS:
				var s := hard_duel(mid)
				var steps := planner_game(mid, 6, s)
				check(steps.size() > 20, "%s: game went on (%d steps)" % [mid, steps.size()])
				eq(Game.fixed_roll, -1.0, mid + " fixed_roll restored")
			eq(draw[0], 0, "planner never draws from AI.rng (own seeded stream)")
			AI.rng = prev,
	)
	run(
		"hard v2 extra candidates (buy first, opponent kill replies): legal, state untouched",
		func() -> void:
			for mid: String in Content.SKIRMISH.MAPS:
				var s := hard_duel(mid)
				for sd: String in ["p", "e"]:
					s.aiParams[sd] = AI.PRESETS.hard.merged({ "pl_buy": 2.0, "pl_opp_kill": 1.0 }, true)
				var steps := planner_game(mid, 4, s)
				check(steps.size() > 10, "%s: game went on (%d steps)" % [mid, steps.size()])
			var c := hard_duel("dong_bang")
			var g0: int = c.gold.p
			var buys := AIPlan.buy_prefix(c)
			var g1: int = c.gold.p
			check(buys.size() > 0 and g1 < g0, "turn 1: buy prefix spends gold (%d buys)" % buys.size())
			for st: Dictionary in buys:
				eq(st.kind, "buy", "buy prefix holds only buys"),
	)
	run(
		"hard v2: deterministic (same state -> same game)",
		func() -> void:
			var a := planner_game("cua_bien", 5, hard_duel("cua_bien"))
			var b := planner_game("cua_bien", 5, hard_duel("cua_bien"))
			eq(var_to_str(a), var_to_str(b), "same steps"),
	)
	run(
		"hard v2: time cap stops the search but still plays a legal step",
		func() -> void:
			var s := hard_duel("dong_bang")
			planner_game("dong_bang", 4, s)
			var st: Variant = AI.next_step(s, { })
			var capped: bool = AIPlan.last.capped
			check(not capped, "default counts stay under the wall-clock cap")
			var ms: int = AIPlan.last.ms
			check(ms < 1500, "plan took %d ms" % ms)
			s.aiParams[s.side].pl_ms = 0.0
			var st0: Variant = AI.next_step(s, { })
			capped = AIPlan.last.capped
			var runs: int = AIPlan.last.runs
			check(capped and runs == 1, "capped after 1 rollout %s" % [AIPlan.last])
			var st0d: Dictionary = st0 if st0 != null else { }
			check(st0 != null and AIPlan.legal(s, st0d), "capped plan is still legal")
			check(st != null, "a step"),
	)
	run(
		"hard v2: focus fire kills a wounded commander the greedy AI only hits",
		func() -> void:
			# e commander (60 hp) in the open; p archer + 2 soldiers can reach it; no single hit kills
			var s := blank(
				[
					["e", "hero", 3, 3, 60],
					["p", "archer", 1, 3],
					["p", "soldier", 3, 0],
					["p", "soldier", 0, 4],
					["p", "hero", 0, 0],
					["e", "soldier", 5, 4],
				]
			)
			s.aiParams = { "p": AI.PRESETS.hard }
			var pre := AIPlan.kill_prefixes(s, "p", 3)
			check(pre.size() > 0, "a kill plan exists")
			if pre.size():
				var first: Array = pre[0]
				var last_step: Dictionary = first.back()
				eq(last_step.act.target, 1, "first plan kills the commander")
				var c: Dictionary = s.duplicate(true)
				Game.fixed_roll = 0.5
				for st: Dictionary in first:
					AI.apply_step(c, st)
				check(not Game.hero_alive(c, "e"), "commander dead at mid rolls")
				Game.fixed_roll = -1.0,
	)

func tactics_tests() -> void:
	run(
		"hard v2 + tactics knobs: legal steps, state untouched, no AI.rng draws",
		func() -> void:
			var prev: Callable = AI.rng
			var draw := [0]
			AI.rng = func() -> float:
				draw[0] += 1
				return 0.5
			for mid: String in Content.SKIRMISH.MAPS:
				var s := hard_duel(mid)
				for sd: String in ["p", "e"]:
					s.aiParams[sd] = AI.PRESETS.hard.merged(TACTICS, true)
				var steps := planner_game(mid, 5, s)
				check(steps.size() > 10, "%s: game went on (%d steps)" % [mid, steps.size()])
			eq(draw[0], 0, "planner never draws from AI.rng")
			AI.rng = prev,
	)
	run(
		"lone_w: a lone soldier stops outside the reach of 2 enemies that could kill it",
		func() -> void:
			var s := blank([["p", "soldier", 0, 2, 60], ["e", "soldier", 5, 2], ["e", "soldier", 5, 3], ["p", "hero", 0, 5], ["e", "hero", 5, 0]])
			var u: Dictionary = unit(s, 0)
			var threat := AI.threat_map(s, "p")
			s.aiParams = { "p": { "noise": 0.0 } }
			var off: Dictionary = AI.best_for_unit(s, u, threat, { }, { }, { })
			s.aiParams = { "p": { "noise": 0.0, "lone_w": 1.0 } }
			var on: Dictionary = AI.best_for_unit(s, u, threat, { }, { }, { "sup": AI.support_map(s, "p") })
			var to_off: Array = off.act.to
			var to_on: Array = on.act.to
			var t_off := xy(to_off)
			var t_on := xy(to_on)
			var f_off := AI.expected_hit(s, u, t_off.x, t_off.y, threat.get(t_off), 1.0)
			var f_on := AI.expected_hit(s, u, t_on.x, t_on.y, threat.get(t_on), 1.0)
			check(f_off >= 60, "knob off: walks into focus range (%s, focus %d)" % [t_off, f_off])
			check(f_on < 60, "knob on: ends where 2 enemies cannot kill it (%s, focus %d)" % [t_on, f_on]),
	)
	run(
		"tgt_sup / tgt_thr: support unit first, a healthy hitter over a wounded one",
		func() -> void:
			var s := blank([["e", "elephant", 2, 2], ["e", "wolf", 3, 3], ["e", "soldier", 4, 4, 100], ["e", "soldier", 4, 1, 20]])
			var ele: Dictionary = unit(s, 0)
			var wolf: Dictionary = unit(s, 1)
			eq(AI.tvalue(s, ele, 0.0, 0.0), AI.tvalue(s, wolf, 0.0, 0.0), "same cost, knobs off")
			check(AI.tvalue(s, wolf, 0.5, 0.0) > AI.tvalue(s, ele, 0.5, 0.0), "wolf over elephant with tgt_sup")
			check(AI.tvalue(s, unit(s, 2), 0.0, 2.0) > AI.tvalue(s, unit(s, 3), 0.0, 2.0), "full-hp soldier over 20-hp one with tgt_thr"),
	)
	run(
		"order_w: the archer shoots before the soldier hits",
		func() -> void:
			var s := blank([["p", "soldier", 1, 2], ["p", "archer", 0, 4], ["e", "soldier", 3, 3], ["p", "hero", 0, 0], ["e", "hero", 5, 5]])
			s.aiParams = { "p": { "noise": 0.0, "order_w": 3.0 } }
			var st: Dictionary = AI.greedy_step(s, { })
			var act: Dictionary = st.act
			eq(act.kind, "attack", "first step attacks")
			eq(act.id, 2, "archer first (soldier would eat a counter it can wait out)"),
	)

func v4_tests() -> void:
	run(
		"buy_sup: an army of 4 without drum saves for one, then buys it; off = a cheap unit now",
		func() -> void:
			var s := blank([["p", "soldier", 1, 1], ["p", "soldier", 1, 2], ["p", "soldier", 2, 1], ["p", "archer", 2, 2], ["p", "hero", 0, 1]])
			s.gold.p = 400
			check(AI.choose_buy(s, "p") != null, "off: buys something now")
			s.aiParams = { "p": { "buy_sup": 4.0 } }
			eq(AI.buy_step(s, { }), null, "on: 400 + 2 x 50 income reaches a drum -> save")
			s.gold.p = 500
			var st: Dictionary = AI.buy_step(s, { })
			eq(st.get("type"), "drum", "on: 500 gold -> drum")
			s.gold.p = 100
			check(AI.choose_buy(s, "p") == null, "100 gold: nothing affordable either way"),
	)
	run(
		"hard v3 + v4 knobs: legal steps, state untouched, no AI.rng draws, deterministic",
		func() -> void:
			var prev: Callable = AI.rng
			var draw := [0]
			AI.rng = func() -> float:
				draw[0] += 1
				return 0.5
			for mid: String in Content.SKIRMISH.MAPS:
				var s := hard_duel(mid)
				for sd: String in ["p", "e"]:
					s.aiParams[sd] = AI.PRESETS.hard.merged(V4, true)
				var steps := planner_game(mid, 5, s)
				check(steps.size() > 10, "%s: game went on (%d steps)" % [mid, steps.size()])
			eq(draw[0], 0, "planner never draws from AI.rng")
			AI.rng = prev
			var runs := []
			for i in 2:
				var c := hard_duel("nui_rung")
				c.aiParams.p = AI.PRESETS.hard.merged(V4, true)
				runs.append(var_to_str(planner_game("nui_rung", 4, c)))
			eq(runs[0], runs[1], "same state -> same game"),
	)
	run(
		"buy_threat: foe castle threatens like its best affordable non-siege buy, budget shared, at buy_hp",
		func() -> void:
			var s := blank([["p", "soldier", 2, 2], ["p", "hero", 0, 0]])
			s.gold.e = 0
			eq(AI.buy_threats(s, "p", 1.0).size(), 0, "50 income only: nothing to buy")
			s.gold.e = 1000
			var v: Array = AI.buy_threats(s, "p", 0.5)
			eq(v.size(), 1, "one castle, one buy")
			var b: Dictionary = v[0]
			eq(b.type, "bird", "best attacker within 1050 gold")
			eq(b.hp, 50, "hp = buy_hp x 100")
			eq(pos(b), Vector2i(5, 5), "on the castle")
			s.gold.e = 700
			var w: Dictionary = AI.buy_threats(s, "p", 1.0)[0]
			eq(w.type, "elephant", "no catapult (siege cannot move + attack), elephant within 750")
			var off := AI.threat_map(s, "p")
			var on := AI.threat_map(s, "p", { }, { }, 1.0)
			check(off.is_empty() and on.has(Vector2i(4, 2)), "no foe unit: only the buy threatens (4, 2)")
			eq(units_of(s).size(), 2, "virtual units never enter s.units"),
	)
	run(
		"promo_gain: a hit that levels our unit up is worth 0.2 x its base value",
		func() -> void:
			var s := blank([["p", "soldier", 2, 2], ["e", "soldier", 3, 2]])
			var u := unit(s, 0)
			var d := unit(s, 1)
			eq(AI.promo_gain(s, u, 40, d), 0.0, "fresh soldier: no level")
			u.xp = Game.xp_need(s, u) - 1
			eq(AI.promo_gain(s, u, 40, d), 30.0, "about to level: 0.2 x 150"),
	)
	run(
		"pl_chain: the wolf bites first so the follow-up hits land on a weakened target",
		func() -> void:
			var s := blank(
				[["e", "soldier", 3, 3], ["p", "soldier", 1, 3], ["p", "archer", 3, 0], ["p", "wolf", 5, 3], ["p", "hero", 0, 0], ["e", "hero", 5, 0]]
			)
			Game.fixed_roll = 0.5
			var off := AIPlan.focus(s.duplicate(true), "p", 1)
			var on := AIPlan.focus(s.duplicate(true), "p", 1, 0.0, 0.0, 0.0, 3.0)
			Game.fixed_roll = -1.0
			check(on.size() > 0, "a kill chain exists")
			if on.size() and off.size():
				var first_on: Dictionary = on[0]
				var first_off: Dictionary = off[0]
				eq(first_on.act.id, 4, "wolf first (off: #%d first)" % first_off.act.id)
			var t: Dictionary = Game.unit_by_id(s, 1)
			eq(t.hp, 100, "s untouched"),
	)
	run(
		"pl_dp: commander 2 moves from an empty foe castle -> snipe step closer; weak foe commander, no rebuy -> kill point",
		func() -> void:
			var s := blank([["p", "hero", 0, 0], ["e", "hero", 5, 0, 30], ["p", "soldier", 4, 2], ["p", "soldier", 3, 0]])
			s.gold.e = 0
			var dp := AIPlan.decision_point(s, "p", { })
			var why: String = dp.get("why", "")
			eq(why, "snipe+kill", "both points")
			var snipe: Array = dp.get("snipe", [])
			eq(snipe.size(), 1, "one snipe step")
			if snipe.size():
				var st: Dictionary = snipe[0]
				check(AIPlan.legal(s, st), "legal snipe step")
				var act: Dictionary = st.act
				var to_a: Array = act.to
				var to := xy(to_a)
				eq(Game.dist(to.x, to.y, 5, 5), 5, "ends one move (5 tiles) from the castle")
			s.gold.e = 500
			eq(AIPlan.decision_point(s, "p", { }).get("why", ""), "snipe", "foe can rebuy: no kill point"),
	)

func v5_tests() -> void:
	run(
		"role_w: shaman raises an adjacent grave; never acts before other units unless raising",
		func() -> void:
			var s := blank([["p", "soldier", 1, 2], ["e", "soldier", 4, 4, 40], ["p", "shaman", 2, 4], ["p", "soldier", 1, 3]])
			s.aiParams = { "p": { "noise": 0.0, "role_w": 1.0 } }
			var mem := { }
			var raised := false
			for i in 6:
				var stv: Variant = AI.greedy_step(s, mem)
				if stv == null:
					break
				var st: Dictionary = stv
				if st.kind == "act" and st.act.id == 3:
					raised = st.act.kind == "raise"
				AI.apply_step(s, st)
			check(raised, "kill at (4, 4) -> shaman raises its grave")
			for mid: String in Content.SKIRMISH.MAPS:
				var c := hard_duel(mid)
				c.aiParams.p = { "role_w": 1.0 }
				c.aiParams.e = { }
				var sy := 8 if mid == "dong_bang" else 9
				Game.spawn(c, "p", "shaman", 2, sy)
				var bad := 0
				var seen := 0
				while c.winner == null and c.turn <= 6:
					var m := { }
					for i in 80:
						var stv: Variant = AI.greedy_step(c, m)
						if stv == null:
							break
						var st: Dictionary = stv
						if c.side == "p" and st.kind == "act":
							var uid: int = st.act.id
							var u: Dictionary = Game.unit_by_id(c, uid)
							if u.type == "shaman":
								seen += 1
								for o: Dictionary in c.units:
									if st.act.kind != "raise" and o.side == "p" and not o.acted and o.type != "shaman":
										bad += 1
						AI.apply_step(c, st)
					if c.winner == null:
						Game.end_turn(c)
				check(seen > 0, mid + ": shaman acted")
				eq(bad, 0, mid + ": shaman acted last unless raising"),
	)
	run(
		"role_w: drum covering 2 attackers acts first; boat counts waterDef as cover on water",
		func() -> void:
			var s := blank([["p", "soldier", 2, 3], ["e", "soldier", 4, 3], ["p", "drum", 0, 2], ["p", "soldier", 2, 2]])
			s.aiParams = { "p": { "noise": 0.0 } }
			var off: Dictionary = AI.greedy_step(s.duplicate(true), { })
			s.aiParams = { "p": { "noise": 0.0, "role_w": 1.0 } }
			var on: Dictionary = AI.greedy_step(s.duplicate(true), { })
			var off_id: int = off.act.id
			check(off_id != 3, "off: an attack first")
			eq(on.act.id, 3, "on: drum first")
			var to_a: Array = on.act.to
			var to := xy(to_a)
			check(Game.dist(to.x, to.y, 2, 3) <= 2 and Game.dist(to.x, to.y, 2, 2) <= 2, "aura reaches both soldiers")
			var b := blank([["p", "boat", 0, 2], ["e", "soldier", 5, 5]])
			for x in 6:
				b.tiles[2][x] = "~"
				b.tiles[3][x] = "f"
			var u := unit(b, 0)
			b.aiParams = { "p": { "noise": 0.0 } }
			var w0: Dictionary = AI.best_for_unit(b, u, AI.threat_map(b, "p"), { }, { })
			b.aiParams = { "p": { "noise": 0.0, "role_w": 1.0 } }
			var w1: Dictionary = AI.best_for_unit(b, u, AI.threat_map(b, "p"), { }, { })
			eq(w1.act.to, w0.act.to, "same water tile")
			var sc0: float = w0.score
			var sc1: float = w1.score
			check(absf(sc1 - sc0 - 0.8 * 15.0) < 0.01, "+ def_w x waterDef (%.2f -> %.2f)" % [sc0, sc1]),
	)
	run(
		"mix_w: a grave the shaman reaches from the castle -> shaman; off -> a cheap unit; only affordable types",
		func() -> void:
			var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 4, 4]])
			s.graves = [{ "x": 2, "y": 3, "ttl": 2 }]
			s.gold.p = 400
			var at := Vector2i(0, 0)
			var off: Variant = AI.choose_buy(s, "p", null, { }, at)
			s.aiParams = { "p": { "mix_w": 1.0 } }
			eq(AI.choose_buy(s, "p", null, { }, at), "shaman", "on: shaman (raises this turn)")
			check(str(off) != "shaman", "off: %s" % off)
			s.gold.p = 300
			check(str(AI.choose_buy(s, "p", null, { }, at)) != "shaman", "300 gold: no shaman, no saving up")
			check(AI.buy_step(s, { }) != null, "still buys now"),
	)
	run(
		"hard v5 knobs: legal steps, state untouched, no AI.rng draws, deterministic",
		func() -> void:
			var prev: Callable = AI.rng
			var draw := [0]
			AI.rng = func() -> float:
				draw[0] += 1
				return 0.5
			for mid: String in Content.SKIRMISH.MAPS:
				var s := hard_duel(mid)
				for sd: String in ["p", "e"]:
					s.aiParams[sd] = AI.PRESETS.hard.merged(V5, true)
				var steps := planner_game(mid, 5, s)
				check(steps.size() > 10, "%s: game went on (%d steps)" % [mid, steps.size()])
			eq(draw[0], 0, "planner never draws from AI.rng")
			AI.rng = prev
			var runs := []
			for i in 2:
				var c := hard_duel("cua_bien")
				c.aiParams.p = AI.PRESETS.hard.merged(V5, true)
				runs.append(var_to_str(planner_game("cua_bien", 4, c)))
			eq(runs[0], runs[1], "same state -> same game"),
	)
