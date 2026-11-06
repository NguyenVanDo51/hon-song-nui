extends RefCounted
## shared by sim.gd, parity.gd, probes/stall.gd, probes/hero_path.gd: the seeded LCG (JS parity) + the AI-vs-AI loop.
## Use: `const SimLib := preload("res://sim/sim_lib.gd")`, `var lib := SimLib.new()`, `AI.rng = lib.rng`.

var seed_v := 1.0

func rng() -> float:
	# JS: seed = (seed * 1103515245 + 12345) % 2147483648 in doubles (the product exceeds 2^53, so float math is the spec)
	seed_v = fmod(seed_v * 1103515245.0 + 12345.0, 2147483648.0)
	return seed_v / 2147483648.0

## AI plays both sides (naive: random bot for "p", from this rng) until a winner or past max_turn.
## before(s) runs at the top of every loop pass; on_step(step) sees each step (null = end of turn) before it applies.
## max_steps > 0: stop with a "stuck" error past that many. Returns the steps applied.
func run_ai(s: Dictionary, naive := false, max_turn := 60, before := Callable(), on_step := Callable(), max_steps := 0) -> int:
	var mem := { }
	var steps := 0
	while s.winner == null and s.turn <= max_turn:
		if before.is_valid():
			before.call(s)
		var step: Variant = AI.random_step(s, rng) if naive and s.side == "p" else AI.next_step(s, mem)
		if on_step.is_valid():
			on_step.call(step)
		if step == null:
			Game.end_turn(s)
			mem = { }
			continue
		var st: Dictionary = step
		AI.apply_step(s, st)
		steps += 1
		if max_steps > 0 and steps > max_steps:
			push_error("stuck")
			break
	return steps
