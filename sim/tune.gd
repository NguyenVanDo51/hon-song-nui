extends SceneTree
## AI self-play tuning: side p plays params A, side e params B (s.aiParams) on every skirmish map, both seatings.
## <godot> --headless --path . -s sim/tune.gd -- <mode> [k=v ...]
##   match a=<spec> b=<spec> [games=8] [salt=1]     -> A score vs B (win 1, draw 0.5) per map / seat + total
##   evolve out=<file> [games=8] [minutes=20] [island=0] [thr=0.55]
##                                                   -> mutate best, play child vs best, keep child if > thr twice
##                                                      (2 x games x maps x 2 seats); resumes from out (var_to_str)
##   presets [games=8] [salt=9000000] [tuned=<file>] [names=a,b,..] -> round robin of the presets (row score vs column)
##   time a=<spec> b=<spec> [games=2] [salt=9100000] -> A's AI wall time per step / per turn (avg, worst)
## spec: default | normal | easy | easy_gold (easy + half start gold) | hard (tuned file) | hard_n2 (tuned, noise 2)
##       | hard_v1 (AI.PRESETS.hard before the planner, frozen) | hard_v2 (AI.PRESETS.hard) | file:<path> (tuned file)
##       + optional overrides: <spec>+key:value+key:value (e.g. hard_v2+pl_cands:4)
## seeds: game k of salt -> 1000 + (salt * 64 + k) * 7919 (evolve salts < 9e6; held-out / presets >= 9e6)
const FROZEN := ["noise", "cap_last"] # not tuned: noise = difficulty knob, last-castle capture = instant win
const HELD_OUT := 9000000
## AI.PRESETS.hard as it was before hard v2 (planner): the fixed yardstick
const HARD_V1 := { "hp_cap": 81.2937, "kill_hero": 552.335 }

var seed_v := 1.0
var args := {}
var games_played := 0

func _init() -> void:
	var argv := OS.get_cmdline_user_args()
	var mode: String = argv[0] if argv.size() > 0 else "match"
	for a: String in argv.slice(1):
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	AI.rng = rng
	var t0 := Time.get_ticks_msec()
	if mode == "match":
		var a := spec(arg("a", "default"))
		var b := spec(arg("b", "default"))
		var r := play_match(a, b, int(arg("games", "8")), int(arg("salt", "1")), true)
		print("A %s vs B %s: A score %.3f over %d games" % [arg("a", "default"), arg("b", "default"), r[0], r[1]])
	elif mode == "evolve":
		evolve()
	elif mode == "presets":
		presets()
	elif mode == "time":
		time_ai()
	var sec := (Time.get_ticks_msec() - t0) / 1000.0
	printerr("wall %.1fs, %d games, %.2f games/s" % [sec, games_played, games_played / maxf(sec, 0.001)])
	quit()

## sim_lib's LCG (own copy: sim_lib is not strict-typed, this file is)
func rng() -> float:
	seed_v = fmod(seed_v * 1103515245.0 + 12345.0, 2147483648.0)
	return seed_v / 2147483648.0

func arg(k: String, def: String) -> String:
	var v: String = args.get(k, def)
	return v

## params for a spec; partial dicts are fine (AI.params merges over DEFAULT)
func spec(full: String) -> Dictionary:
	var parts := full.split("+")
	var out := base_spec(parts[0]).duplicate()
	for kv: String in parts.slice(1):
		var p := kv.split(":", true, 1)
		out[p[0]] = float(p[1])
	return out

func base_spec(sp: String) -> Dictionary:
	if sp == "hard_v1":
		return HARD_V1
	if sp == "hard_v2":
		return AI.PRESETS.hard
	if sp == "easy" or sp == "easy_gold":
		# reckless: no death fear, no walk home, no heal stop, coarse picks; _gold = start gold factor (not an AI knob)
		var e := { "noise": 60.0, "caution": 0.0, "caution_hero": 0.3, "home_hp": 0.0, "heal_hp": 0.0, "maydie_w": 0.1 }
		if sp == "easy_gold":
			e._gold = 0.5
		return e
	if sp == "hard" or sp == "hard_n2":
		var t: Dictionary = load_tuned(arg("tuned", "res://sim/tuned_params.txt")).duplicate()
		if sp == "hard_n2":
			t.noise = 2.0 # measured: low noise loses to normal (too predictable / no tie spread)
		return t
	if sp.begins_with("file:"):
		return load_tuned(sp.substr(5))
	return {} # default / normal

func load_tuned(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("no tuned file %s" % path)
		return {}
	var d: Dictionary = str_to_var(FileAccess.get_file_as_string(path))
	return d.best

## A vs B: every skirmish map x {A as p, A as e} x games. Returns [A score in 0..1, games]
func play_match(a: Dictionary, b: Dictionary, games: int, salt: int, verbose := false) -> Array:
	var score := 0.0
	var n := 0
	for map_id: String in Content.SKIRMISH.MAPS:
		for a_side: String in ["p", "e"]:
			var part := 0.0
			for k in games:
				var w := play_one(map_id, a if a_side == "p" else b, b if a_side == "p" else a, salt, k)
				part += 0.5 if w == "draw" else (1.0 if w == a_side else 0.0)
			score += part
			n += games
			if verbose:
				print("  %-10s A as %s: %.1f / %d" % [map_id, a_side, part, games])
	return [score / n, n]

## winner side or "draw". timing.side set -> that side's AI wall time (usec) appended to timing.steps / timing.turns
func play_one(map_id: String, pp: Dictionary, pe: Dictionary, salt: int, k: int, timing := {}) -> String:
	seed_v = 1000.0 + (salt * 64.0 + k) * 7919.0
	var s := Game.new_game(Content.skirmish_def(map_id, "anhhung", false))
	s.seed = int(seed_v)
	s.rng = int(seed_v)
	for side: String in ["p", "e"]:
		var sp: Dictionary = pp if side == "p" else pe
		if sp.has("_gold"):
			var gf: float = sp._gold
			var g0: int = s.gold[side]
			s.gold[side] = int(g0 * gf)
	s.aiParams = { "p": pp, "e": pe }
	var mem := {}
	var steps := 0
	var t_side: String = timing.get("side", "")
	var turn_us := 0
	while s.winner == null and s.turn <= 60 and steps < 30000:
		var t0 := Time.get_ticks_usec()
		var step: Variant = AI.next_step(s, mem)
		if s.side == t_side:
			var dt := Time.get_ticks_usec() - t0
			var ts: Array = timing.steps
			ts.append(dt)
			turn_us += dt
		if step == null:
			if s.side == t_side:
				var tt: Array = timing.turns
				tt.append(turn_us)
			turn_us = 0
			Game.end_turn(s)
			mem = {}
			continue
		var st: Dictionary = step
		AI.apply_step(s, st)
		steps += 1
	games_played += 1
	return s.winner if s.winner != null else "draw"

## child = best with ~3 knobs scaled by exp(N(0, 0.3)) (small steps: hill climb); hp thresholds stay in 0..100
func mutate(best: Dictionary, r: RandomNumberGenerator) -> Dictionary:
	var child := AI.DEFAULT.merged(best, true)
	var keys := child.keys().filter(func(k: String) -> bool: return not FROZEN.has(k))
	var changed := 0
	while changed == 0:
		for k: String in keys:
			if r.randf() < 3.0 / keys.size():
				var v: float = child[k]
				v *= exp(r.randfn(0.0, 0.3))
				if k.ends_with("_hp"):
					v = clampf(v, 0.0, 100.0)
				child[k] = snappedf(v, 0.0001)
				changed += 1
	return child

func evolve() -> void:
	var out: String = arg("out", "res://sim/tuned_params.txt")
	var games := int(arg("games", "8"))
	var minutes := float(arg("minutes", "20"))
	var island := int(arg("island", "0"))
	var thr := float(arg("thr", "0.55"))
	var st := { "gen": 0, "best": AI.DEFAULT.duplicate(), "history": [] }
	if FileAccess.file_exists(out):
		st = str_to_var(FileAccess.get_file_as_string(out))
		print("resume %s at gen %d" % [out, st.gen])
	var t_end := Time.get_ticks_msec() + int(minutes * 60000.0)
	var r := RandomNumberGenerator.new()
	while Time.get_ticks_msec() < t_end:
		var gen: int = st.gen
		r.seed = island * 1000003 + gen
		var best: Dictionary = st.best
		var child := mutate(best, r)
		var salt := (island * 10000 + gen) * 2 + 1
		var r1 := play_match(child, best, games, salt)
		var sc: float = r1[0]
		var verdict := "reject"
		if sc > thr: # confirm on fresh seeds before keeping (one lucky match is common at this size)
			var r2 := play_match(child, best, games, salt + 1)
			var r2s: float = r2[0]
			sc = (sc + r2s) / 2.0
			if sc > thr:
				verdict = "ACCEPT"
				st.best = child
		var diff := []
		for k: String in child:
			if child[k] != best.get(k):
				diff.append("%s %s->%s" % [k, best.get(k), child[k]])
		var line := "gen %d island %d child %.3f %s  [%s]" % [gen, island, sc, verdict, ", ".join(diff)]
		print(line)
		var hist: Array = st.history
		hist.append(line)
		st.gen = gen + 1
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(var_to_str(st))
		f.close()

## round robin: row preset score vs column preset (held-out seeds)
func presets() -> void:
	var names := Array(arg("names", "easy,normal,hard_v1,hard_v2").split(","))
	var games := int(arg("games", "8"))
	var salt := int(arg("salt", str(HELD_OUT)))
	print("row score vs column (win 1, draw 0.5), %d games per pair" % (games * 2 * Content.SKIRMISH.MAPS.size()))
	print("%-9s %s" % ["", "  ".join(names.map(func(n: String) -> String: return n.rpad(7)))])
	var m := {}
	for i in names.size():
		for j in range(i + 1, names.size()):
			var ni: String = names[i]
			var nj: String = names[j]
			var r := play_match(spec(ni), spec(nj), games, salt)
			var sc: float = r[0]
			m[[i, j]] = sc
			m[[j, i]] = 1.0 - sc # same seeds, same seats: the mirror pairing is the complement
	for i in names.size():
		var cells := []
		for j in names.size():
			cells.append("  -    " if i == j else ("%.3f" % m[[i, j]]).rpad(7))
		print("%-9s %s" % [names[i], "  ".join(cells)])

## A's AI cost on every map, both seats: per step and per whole turn (ms)
func time_ai() -> void:
	var a := spec(arg("a", "hard_v2"))
	var b := spec(arg("b", "hard_v1"))
	var games := int(arg("games", "2"))
	var salt := int(arg("salt", "9100000"))
	var timing := { "steps": [], "turns": [] }
	for map_id: String in Content.SKIRMISH.MAPS:
		for a_side: String in ["p", "e"]:
			timing.side = a_side
			for k in games:
				play_one(map_id, a if a_side == "p" else b, b if a_side == "p" else a, salt, k, timing)
	for key: String in ["steps", "turns"]:
		var xs: Array = timing[key]
		var sum := 0
		for x: int in xs:
			sum += x
		xs.sort()
		var p95: int = xs[int(xs.size() * 0.95)] if xs.size() else 0
		var worst: int = xs.back() if xs.size() else 0
		print("%s %s: n %d  avg %.1f ms  p95 %.1f ms  worst %.1f ms" % [arg("a", "hard_v2"), key, xs.size(),
			sum / 1000.0 / maxi(1, xs.size()), p95 / 1000.0, worst / 1000.0])
