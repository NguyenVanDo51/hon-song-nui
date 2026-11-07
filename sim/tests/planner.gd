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
