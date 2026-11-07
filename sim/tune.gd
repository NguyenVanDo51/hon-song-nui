extends SceneTree
## AI self-play tuning: side p plays params A, side e params B (s.aiParams) on every skirmish map, both seatings.
## <godot> --headless --path . -s sim/tune.gd -- <mode> [k=v ...]
##   match a=<spec> b=<spec> [games=8] [salt=1]     -> A score vs B (win 1, draw 0.5) per map / seat + total
##   evolve out=<file> [games=8] [minutes=20] [island=0] [thr=0.55]
##                                                   -> mutate best, play child vs best, keep child if > thr twice
##                                                      (2 x games x maps x 2 seats); resumes from out (var_to_str)
##   presets [games=8] [salt=9000000] [tuned=<file>] [names=a,b,..] -> round robin of the presets (row score vs column)
##   any mode: log=1 -> one line per game (winner, reason, turn, commander deaths)
##   time a=<spec> b=<spec> [games=2] [salt=9100000] -> A's AI wall time per step / per turn (avg, worst)
##   evaldata a= b= [games=2] [salt=500] out=<csv>   -> per turn start: eval features (side to move) + final result
##                                                      (Texel-style fit: tools/texel_fit.py)
## spec: default | normal | easy | easy_gold (easy + half start gold) | hard (tuned file) | hard_n2 (tuned, noise 2)
##       | hard_v1 (AI.PRESETS.hard before the planner, frozen) | hard_v2 (AI.PRESETS.hard)
##       | hard_v2_0 (hard v2 as first shipped, frozen) | hard_v3 (hard_v2_0 + V3_TACTICS, frozen)
##       | hard_v5 (hard_v3 + V5_ARMY, frozen) | file:<path> (tuned file)
##       (hard_v4 = v3 + internet tactics: code removed, results in docs/ai.md; rerun at 5aac2ee)
##       + optional overrides: <spec>+key:value+key:value (e.g. hard_v2+pl_cands:4); +_spam:1 = that side buys only
##       soldier / archer (spam test)
## seeds: game k of salt -> 1000 + (salt * 64 + k) * 7919 (evolve salts < 9e6; held-out / presets >= 9e6)
const FROZEN := ["noise", "cap_last"] # not tuned: noise = difficulty knob, last-castle capture = instant win
const HELD_OUT := 9000000
## evaldata columns (features())
const FEATS := ["val", "dmg_cap", "dmg_unit", "dmg_hero", "hero", "gold", "inc", "castles", "adv", "adv_hero", "units", "risk_me", "risk_foe"]
## AI.PRESETS.hard as it was before hard v2 (planner): the fixed yardstick
const HARD_V1 := { "hp_cap": 81.2937, "kill_hero": 552.335 }
## AI.PRESETS.hard + AIPlan.DEFAULT at hard v2's first ship (20fae2e), frozen: the yardstick for later planner changes
const HARD_V2_0 := {
	"hp_cap": 81.2937,
	"kill_hero": 552.335,
	"planner": 2.0,
	"pl_alpha": 0.3,
	"pl_hp_cap": 200.0,
	"pl_gold": 1.0,
	"pl_inc": 4.0,
	"pl_castle": 300.0,
	"pl_adv": 4.0,
	"pl_adv_hero": 12.0,
	"pl_cands": 3.0,
	"pl_replan": 3.0,
	"pl_kill": 3.0,
	"pl_kcombo": 0.0,
	"pl_opp_roll": 0.5,
	"pl_opp_kill": 0.0,
	"pl_hero": 0.0,
	"pl_guard": 1.0,
	"pl_herosafe": 0.0,
	"pl_hero_risk": 0.0,
	"pl_ply3": 0.0,
	"pl_buy": 0.0,
	"pl_ms": 4000.0,
}
## hard v3 = hard_v2_0 + human-tactics knobs (docs/ai.md "Kinh nghiệm người chơi"), frozen like HARD_V2_0
const V3_TACTICS := {
	"lone_w": 0.3,
	"lone_n": 1.0,
	"tgt_sup": 0.5,
	"tgt_thr": 2.0,
	"home_val": 0.0, # tips 2 / 7 (retreat, buildings): measured neutral, left off
	"home_rank": 0.0,
	"home_cap": 80.0,
	"bld_w": 0.0,
	"trade_w": 1.0,
	"order_w": 1.0,
	"feed_w": 1.0,
	"escort_w": 0.0, # tip 1: lost vs hard_v1 (docs/ai.md), off
	"hero_cgoal": 0.0,
}
## hard v5 = hard_v3 + flexible army (docs/ai.md "Đội hình linh hoạt = Khó v5"), frozen; the most varied dev candidate
const V5_ARMY := {
	"role_w": 1.0, # unit jobs: shaman last + by graves, drum first, wolf bite first, boats on water
	"mix_w": 1.0, # situational buys, affordable now
	"pl_chain": 1.0, # drum / wolf first in kill chains (added in v4, kept)
	"mix_save": 0.1, # lead >= 10%: save one income for a called-for unit >= 500
	"sham_save": 1.0, # ... or a shaman with graves in reach
}

var seed_v := 1.0
var args := { }
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
	elif mode == "evaldata":
		eval_data()
	if AIPlan.capped_n > 0:
		print("WARNING planner capped %d times (pl_ms): not deterministic" % AIPlan.capped_n)
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

## frozen specs + normal (probes share them); {} for anything else
static func frozen(sp: String) -> Dictionary:
	if sp == "hard_v1":
		return HARD_V1
	if sp == "hard_v2":
		return AI.PRESETS.hard
	if sp == "hard_v2_0":
		return HARD_V2_0
	if sp == "hard_v3":
		return HARD_V2_0.merged(V3_TACTICS)
	if sp == "hard_v5":
		return HARD_V2_0.merged(V3_TACTICS).merged(V5_ARMY)
	return { }

## frozen spec name + overrides (static twin of spec(); no tuned files)
static func spec_of(full: String) -> Dictionary:
	var parts := full.split("+")
	var out := frozen(parts[0]).duplicate()
	for kv: String in parts.slice(1):
		var p := kv.split(":", true, 1)
		out[p[0]] = float(p[1])
	return out

func base_spec(sp: String) -> Dictionary:
	if sp.begins_with("hard_v"):
		return frozen(sp)
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
	return { } # default / normal

func load_tuned(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("no tuned file %s" % path)
		return { }
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
func play_one(map_id: String, pp: Dictionary, pe: Dictionary, salt: int, k: int, timing := { }) -> String:
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
		if sp.get("_spam", 0.0) > 0.0: # spam test: this side may buy only the cheap pair
			s.allowed[side] = ["soldier", "archer"]
	s.aiParams = { "p": pp, "e": pe }
	var mem := { }
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
			mem = { }
			if timing.has("rec") and s.winner == null:
				var rec: Array = timing.rec
				var me: String = s.side
				rec.append([map_id, me, s.turn] + features(s, me))
			continue
		var st: Dictionary = step
		AI.apply_step(s, st)
		steps += 1
	games_played += 1
	if args.has("log"): # one line per game: who won, why, when, commander deaths
		print(
			"    game %s k%d winner %s reason %s turn %d heroDeaths p%d e%d" % [map_id, k, s.winner, s.reason, s.turn, s.heroDeaths.p, s.heroDeaths.e]
		)
	return s.winner if s.winner != null else "draw"

## child = best with ~3 knobs scaled by exp(N(0, 0.3)) (small steps: hill climb); hp thresholds stay in 0..100
func mutate(best: Dictionary, r: RandomNumberGenerator) -> Dictionary:
	var child := AI.DEFAULT.merged(best, true)
	var keys := child.keys().filter(
		func(k: String) -> bool:
			return not FROZEN.has(k),
	)
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
	print(
		"%-9s %s"
		% [
			"",
			"  ".join(
				names.map(
					func(n: String) -> String:
						return n.rpad(7),
				)
			),
		]
	)
	var m := { }
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
		print(
			"%s %s: n %d  avg %.1f ms  p95 %.1f ms  worst %.1f ms"
			% [arg("a", "hard_v2"), key, xs.size(), sum / 1000.0 / maxi(1, xs.size()), p95 / 1000.0, worst / 1000.0]
		)

## Texel-style data: every turn start (the position the planner scores), side to move = "me": features me - foe
## (+ both commanders' exposure) and the final result for me -> csv rows for an offline logistic fit
func eval_data() -> void:
	var a := spec(arg("a", "hard_v2_0"))
	var b := spec(arg("b", "hard_v2_0"))
	var games := int(arg("games", "2"))
	var salt := int(arg("salt", "500"))
	var f := FileAccess.open(arg("out", "user://evaldata.csv"), FileAccess.WRITE)
	f.store_line("game,map,me,turn,seat_p,%s,result" % ",".join(FEATS))
	var gi := 0
	for map_id: String in Content.SKIRMISH.MAPS:
		for a_side: String in ["p", "e"]:
			for k in games:
				var timing := { "rec": [] }
				var w := play_one(map_id, a if a_side == "p" else b, b if a_side == "p" else a, salt, k, timing)
				var rec: Array = timing.rec
				for row: Array in rec:
					var me: String = row[1]
					var res := 0.5 if w == "draw" else (1.0 if w == me else 0.0)
					var cells := ["%d_%d" % [salt, gi], row[0], me, str(row[2]), "1" if me == "p" else "0"]
					for x: float in row.slice(3):
						cells.append("%.4f" % x)
					cells.append(str(res))
					f.store_line(",".join(cells))
				gi += 1
	f.close()

## FEATS for side me (me - foe; risk_*: each commander's expected damage taken next turn / its hp, 0 if dead)
func features(s: Dictionary, me: String) -> Array:
	var shared := { "tm": { }, "rc": { }, "df": { } }
	var out := []
	out.resize(FEATS.size())
	out.fill(0.0)
	var owner: Dictionary = s.owner
	for sd: String in ["p", "e"]:
		var sgn := 1.0 if sd == me else -1.0
		var tgt := []
		var cas := []
		for y: int in s.h:
			for x: int in s.w:
				if Game.cap_flag(s.tiles[y][x]) != "" and owner.get(Vector2i(x, y)) != sd:
					tgt.append([x, y])
					if Game.sells(Game.tile_at(s, x, y)):
						cas.append([x, y])
		var v := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		for u: Dictionary in s.units:
			if u.side != sd:
				continue
			var hp: float = u.hp
			var val := AI.value(s, u)
			var hero: bool = u.type == "hero"
			v[0] += val
			v[1] += minf(val * 0.7, 200.0) * (1.0 - hp / 100.0)
			if hero:
				v[3] += 1.0 - hp / 100.0
				v[4] += 1.0
			else:
				v[2] += val * (1.0 - hp / 100.0)
				v[10] += 1.0
			var goals: Array = cas if hero else tgt
			var d := 30.0
			if not goals.is_empty():
				var st := Game.stat(s, u)
				var mc: String = st.move if st.move in ["fly", "water"] else "foot"
				var df := AI._dist_cached(s, mc, goals, shared)
				var ux: int = u.x
				var uy: int = u.y
				var d0: float = df.get(Vector2i(ux, uy), 30.0)
				d = minf(d0, 30.0)
			if hero:
				v[9] += d
			else:
				v[8] += d
		var gold: int = s.gold[sd]
		v[5] = gold
		v[6] = Game.income(s, sd)
		v[7] = Game.castles(s, sd)
		for i in v.size():
			var vi: float = v[i]
			var oi: float = out[i]
			out[i] = oi + sgn * vi
		var risk := 0.0
		for h: Dictionary in s.units:
			if h.side == sd and h.type == "hero":
				var threat := AI.threat_map(s, sd)
				var hx: int = h.x
				var hy: int = h.y
				var hhp: float = h.hp
				risk = minf(AI.expected_hit(s, h, hx, hy, threat.get(Vector2i(hx, hy)), 1.0) / hhp, 1.0)
		out[11 if sd == me else 12] = risk
	return out
