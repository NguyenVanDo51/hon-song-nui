extends "res://sim/tests/test_base.gd"
## commander fixes from a human match (docs/ai.md "Sửa lỗi tướng từ trận người chơi"): positions from the recorded
## match (sim/scenarios/<replay>_t<turn>.scenario, bot = e), replayed with each hard preset + / - the fix knobs

const ReviewLib := preload("res://sim/review_lib.gd")
const Tune := preload("res://sim/tune.gd")
const SCEN := "res://sim/scenarios/2026-11-07_22-19-09_duel_dong_bang_t%d.scenario"
const CASTLE := Vector2i(11, 8) # unowned castle next to the bot's side of dong_bang

func hero_tests() -> void:
	run(
		"t5: commander (49 hp) no longer ends where fresh buys + units kill it (roll 0.75); old presets do",
		func() -> void:
			for name: String in ["hard_v3", "hard_v5"]:
				var old := _play(5, Tune.frozen(name))
				check(not _hero_kill(old, 0.75).is_empty(), "%s: the recorded blunder (killable)" % name)
				var fixed := _play(5, Tune.frozen(name + "b"))
				var h := _hero(fixed)
				var kill := _hero_kill(fixed, 0.75)
				check(kill.is_empty(), "%s: commander at %s killable: %s" % [name + "b", pos(h), kill]),
	)
	run(
		"t2 / t9: healthy commander heads for the free castle (11,8) instead of idling / villages",
		func() -> void:
			for turn: int in [2, 9]:
				for name: String in ["hard_v3b", "hard_v5b"]:
					var s := _play(turn, Tune.frozen(name))
					var h := _hero(s)
					var df := AI.dist_field(s, "foot", [[CASTLE.x, CASTLE.y]])
					var d: float = df.get(pos(h), INF)
					var mv: int = Game.stat(s, h).mv
					var owner: Dictionary = s.owner
					var took: bool = owner.get(CASTLE) == "e"
					check(took or d <= mv, "t%d %s: commander at %s, %.0f moves from (11,8)" % [turn, name, pos(h), d]),
	)
	run(
		"t21: 64-hp commander ends where fresh buys + units cannot kill it (roll 0.75)",
		func() -> void:
			for name: String in ["hard_v3b", "hard_v5b"]:
				var s := _play(21, Tune.frozen(name))
				var h := _hero(s)
				check(not h.is_empty(), name + ": commander alive")
				check(_hero_kill(s, 0.75).is_empty(), "%s: commander at %s killable" % [name, pos(h)]),
	)
	run(
		"fix knobs: commander-only threat, reply legal, state untouched, deterministic",
		func() -> void:
			var sc := ReviewLib.load_scenario(SCEN % 5)
			var s: Dictionary = sc.state
			var before := var_to_str(s)
			var a := _play(5, Tune.frozen("hard_v3b"))
			var b := _play(5, Tune.frozen("hard_v3b"))
			eq(var_to_str(a), var_to_str(b), "same turn twice")
			eq(var_to_str(s), before, "scenario state untouched")
			var c: Dictionary = s.duplicate(true)
			c.aiParams = { "e": Tune.frozen("hard_v3b") }
			var mem := { }
			AI.greedy_step(c, mem)
			var hbt: Dictionary = mem.get("hbt", { })
			check(hbt.size() > 0, "hero_bt: fresh-buy reach map built")
			var hit: Array = hbt.get(Vector2i(1, 6), [])
			check(hit.size() > 0, "a soldier bought at (1,9) reaches (1,6) -> hits (2,6)")
			c.aiParams = { "e": Tune.frozen("hard_v3") }
			mem = { }
			AI.greedy_step(c, mem)
			check(not mem.has("hbt"), "knob off: no buy map"),
	)

## the bot's (e) planned turn from the recorded start at turn, with knobs P; returns the state after it (mid rolls)
func _play(turn: int, P: Dictionary) -> Dictionary:
	var sc := ReviewLib.load_scenario(SCEN % turn)
	var st: Dictionary = sc.state
	var s: Dictionary = st.duplicate(true)
	s.aiParams = { "e": P }
	var prev: Callable = AI.rng
	var gen := RandomNumberGenerator.new()
	gen.seed = 7
	AI.rng = gen.randf
	Game.fixed_roll = 0.5
	var mem := { }
	for k in 40:
		var stv: Variant = AI.next_step(s, mem)
		if stv == null:
			break
		var step: Dictionary = stv
		AI.apply_step(s, step)
	AI.rng = prev
	return s

## e's commander, {} if dead
func _hero(s: Dictionary) -> Dictionary:
	for u: Dictionary in s.units:
		if u.side == "e" and u.type == "hero":
			return u
	return { }

## after e's turn: p's buys + focus fire that kill e's commander at roll r ([] = it survives)
func _hero_kill(s: Dictionary, r: float) -> Array:
	var c: Dictionary = s.duplicate(true)
	Game.end_turn(c)
	Game.fixed_roll = r
	var out := AIPlan.hero_kill_prefix(c, "p")
	Game.fixed_roll = 0.5
	return out
