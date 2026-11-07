class_name AIPlan
extends RefCounted
## hard v2 (AI.PRESETS.hard "planner": 2): plans the whole turn, then hands it out one step at a time.
## Candidate turns (portfolio: v1 greedy under a few knob sets, focus-fire kill prefixes, castle guard) are played on copies of
## the state with mid rolls; the opponent answers with the v1 greedy; the position after that is scored -> best turn.
## A real roll that changes who is alive -> replan the rest. Deterministic: own RNG seeded from the state, work capped
## by counts (the wall-clock cap is an emergency stop only). Never mutates s.

## every planner knob; read through AI.params (s.aiParams[side]) so tune.gd specs can override them
const DEFAULT := {
	"pl_alpha": 0.3, # unit worth at 0 hp as a share of its value (still blocks, captures, heals back)
	"pl_hp_cap": 200.0, # hp-dependent part of a unit's worth capped here; the rest counts while it lives
	"pl_gold": 1.0, # per gold in the bank
	"pl_inc": 4.0, # turns of income
	"pl_castle": 300.0, # per castle on top of its income (buy point; the last one decides the game)
	"pl_adv": 4.0, # per move-cost tile: units toward buildings not theirs
	"pl_adv_hero": 12.0, # commander toward castles not its own
	"pl_cands": 3.0, # knob-set candidates, first plan of the turn
	"pl_replan": 3.0, # knob-set candidates when a roll broke the plan
	"pl_kill": 3.0, # focus-fire kill prefixes (most valuable reachable enemies) + 1 chained double kill
	"pl_kcombo": 0.0, # k > 0: each kill prefix also finished with STYLES[k]
	"pl_opp_roll": 0.5, # roll the opponent's reply uses (> 0.5 = pessimistic)
	"pl_opp_kill": 0.0, # opponent replies also tried: its focus-fire kills on our n most valuable units
	"pl_hero": 0.0, # commander alive, on top of its unit value (only castle taker)
	"pl_guard": 1.0, # 1 = also try: hold every own castle an enemy commander could take next turn
	"pl_herosafe": 0.0, # 1 = also try: our commander to the least-threatened tile first
	"pl_hero_risk": 0.0, # x smooth death risk of each commander where it ends (enemy threat map)
	"pl_ply3": 0.0, # 1 = also play our next turn (greedy) before scoring
	"pl_buy": 0.0, # >= 1: also try v1's buys first (AE2: bought units act this turn); >= 2: + buys then n-1 kill prefixes
	"pl_ms": 4000.0, # emergency wall-clock cap per plan
}
## knob sets for the greedy turn (merged over the side's own knobs); first = as is
const STYLES := [
	{ },
	{ "noise": 0.0 },
	{ "caution": 0.0, "caution_hero": 0.6, "atk_bias": 80.0 },
	{ "caution": 1.2, "caution_hero": 3.0, "reach_w": 0.9 },
	{ "noise": 16.0 },
	{ "goal_w": 20.0 },
]
## opponent model: the v1 normal AI without noise
const OPP := { "noise": 0.0 }
const MAX_STEPS := 80 # per simulated turn
const WIN := 1000000.0

## planner stats of the last plan (probes / tests): rollouts, ms, capped
static var last := { }
## plans cut by pl_ms since start (sims: non-zero = wall clock leaked into results)
static var capped_n := 0

static func knob(P: Dictionary, k: String) -> float:
	var v: float = P.get(k, DEFAULT[k])
	return v

static func next_step(s: Dictionary, mem: Dictionary) -> Variant:
	for attempt in 2:
		if attempt == 1 or not mem.has("pl_steps"):
			var prev_rng: Callable = AI.rng
			var prev_roll: float = Game.fixed_roll
			_replan(s, mem)
			AI.rng = prev_rng # again here: a runtime error inside the search must not leave the globals swapped
			Game.fixed_roll = prev_roll
		var steps: Array = mem.pl_steps
		var alive: Array = mem.pl_alive
		var i: int = mem.pl_i
		if i > 0 and alive[i - 1] != alive_ids(s):
			continue # a roll changed who lives: the rest of the plan is stale
		if i >= steps.size():
			return null
		var st: Dictionary = steps[i]
		if legal(s, st):
			mem.pl_i = i + 1
			return st
	return AI.greedy_step(s, mem) # should not happen: a fresh plan starts from this exact state

## unit ids in s.units order (deaths filter, spawns append -> comparable as is)
static func alive_ids(s: Dictionary) -> Array:
	var out := []
	for u: Dictionary in s.units:
		out.append(u.id)
	return out

## would AI.apply_step accept this step (same checks as Game.do_action / Game.buy)
static func legal(s: Dictionary, st: Dictionary) -> bool:
	if s.winner != null:
		return false
	var side: String = s.side
	if st.kind == "buy":
		var bx: int = st.x
		var by: int = st.y
		for o: Dictionary in Game.buy_options(s, side, bx, by):
			if o.type == st.type:
				var ok: bool = o.ok
				return ok
		return false
	var act: Dictionary = st.act
	var aid: int = act.id
	var uv: Variant = Game.unit_by_id(s, aid)
	if uv == null:
		return false
	var u: Dictionary = uv
	if u.side != side or u.acted:
		return false
	var tx: int = act.to[0]
	var ty: int = act.to[1]
	if not Game.reachable(s, u).has(Vector2i(tx, ty)):
		return false
	var kind: String = act.kind
	if kind == "attack":
		var tid: int = act.target
		var dv: Variant = Game.unit_by_id(s, tid)
		return dv != null and Game.targets_from(s, u, tx, ty).has(dv)
	if kind == "raze":
		return Game.razable_from(s, u, tx, ty).has(act.get("target"))
	if kind == "capture" or kind == "repair" or kind == "raise":
		var ox: int = u.x
		var oy: int = u.y
		u.x = tx
		u.y = ty
		var ok := false
		if kind == "capture":
			ok = Game.can_capture(s, u, tx, ty)
		elif kind == "repair":
			ok = Game.can_repair(s, u, tx, ty)
		else:
			var gx: int = act.target[0]
			var gy: int = act.target[1]
			ok = Game.raisable_graves(s, u, tx, ty).any(
				func(g: Dictionary) -> bool:
					return g.x == gx and g.y == gy,
			)
		u.x = ox
		u.y = oy
		return ok
	return true

## search: every candidate turn played out + answered; best -> mem.pl_steps / pl_alive / pl_i
static func _replan(s: Dictionary, mem: Dictionary) -> void:
	var t0 := Time.get_ticks_msec()
	var side: String = s.side
	var P := AI.params(s, side, mem)
	var mid: bool = mem.has("pl_steps")
	var prev_rng: Callable = AI.rng
	var prev_roll: float = Game.fixed_roll
	var gen := RandomNumberGenerator.new()
	var n_plans: int = mem.get("pl_n", 0)
	mem.pl_n = n_plans + 1
	gen.seed = hash([s.rng, s.turn, side, n_plans, alive_ids(s)])
	AI.rng = gen.randf
	Game.fixed_roll = 0.5
	for k: String in ["tm", "rc", "df"]:
		if not mem.has(k):
			mem[k] = { }
	var own: Dictionary = { }
	for k: String in P:
		if k != "planner" and not k.begins_with("pl_"):
			own[k] = P[k]
	var n := int(knob(P, "pl_replan" if mid else "pl_cands"))
	var cands := []
	for i in mini(n, STYLES.size()):
		var style: Dictionary = STYLES[i]
		cands.append({ "pre": [], "over": own.merged(style, true), "tag": "style%d" % i })
	var combo := int(knob(P, "pl_kcombo"))
	for pre: Array in kill_prefixes(s, side, int(knob(P, "pl_kill"))):
		cands.append({ "pre": pre, "over": own, "tag": "kill%d" % pre.size() })
		if combo > 0 and combo < STYLES.size():
			var cs: Dictionary = STYLES[combo]
			cands.append({ "pre": pre, "over": own.merged(cs, true), "tag": "kill%d+s%d" % [pre.size(), combo] })
	var guard := guard_prefix(s, side) if knob(P, "pl_guard") > 0.0 else []
	if not guard.is_empty():
		cands.append({ "pre": guard, "over": own, "tag": "guard" })
	var nbuy := int(knob(P, "pl_buy"))
	if nbuy > 0 and not mid:
		var bc: Dictionary = s.duplicate(true)
		var buys := buy_prefix(bc)
		if not buys.is_empty():
			cands.append({ "pre": buys, "over": own, "tag": "buy" })
			for pre: Array in kill_prefixes(bc, side, nbuy - 1):
				cands.append({ "pre": buys + pre, "over": own, "tag": "buy+kill%d" % pre.size() })
	var safe := hero_safe_prefix(s, side) if knob(P, "pl_herosafe") > 0.0 else []
	if not safe.is_empty():
		cands.append({ "pre": safe, "over": own, "tag": "herosafe" })
	var best: Dictionary = { }
	var runs := 0
	var capped := false
	var ms := knob(P, "pl_ms")
	for c: Dictionary in cands:
		if runs > 0 and Time.get_ticks_msec() - t0 > ms:
			capped = true
			capped_n += 1
			break
		var pre: Array = c.pre
		var over: Dictionary = c.over
		var r := _rollout(s, side, over, pre, mem, P)
		runs += 1
		if r.is_empty():
			continue
		var sc: float = r.score
		if best.is_empty() or sc > best.score:
			best = r
			best.tag = c.tag
	AI.rng = prev_rng
	Game.fixed_roll = prev_roll
	mem.pl_steps = best.get("steps", [])
	mem.pl_alive = best.get("alive", [])
	mem.pl_i = 0
	last = {
		"runs": runs,
		"ms": Time.get_ticks_msec() - t0,
		"capped": capped,
		"score": best.get("score", 0.0),
		"tag": best.get("tag", ""),
		"mid": mid,
	}

## focus fire: for the n most valuable enemies we can reach, the attack sequence that kills it (mid rolls), plus the
## best kill chained with a second one. Each = a forced prefix; the greedy AI finishes the turn
static func kill_prefixes(s: Dictionary, side: String, n: int) -> Array:
	if n <= 0:
		return []
	var P := AI.params(s, side)
	var sup: float = P.tgt_sup
	var thr: float = P.tgt_thr
	var foes := []
	for u: Dictionary in s.units:
		if u.side != side:
			foes.append(u)
	foes.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var va := AI.tvalue(s, a, sup, thr)
			var vb := AI.tvalue(s, b, sup, thr)
			return va > vb or (va == vb and a.id < b.id),
	)
	var out := []
	for f: Dictionary in foes:
		if out.size() >= n:
			break
		var c: Dictionary = s.duplicate(true)
		var fid: int = f.id
		var pre := focus(c, side, fid, sup, thr)
		if pre.is_empty():
			continue
		if out.is_empty() and c.winner == null: # chain a second kill onto the best one (c is past the first)
			var more := []
			for g: Dictionary in foes:
				var gid: int = g.id
				if gid != fid and Game.unit_by_id(c, gid) != null:
					more = focus(c.duplicate(true), side, gid, sup, thr)
					if not more.is_empty():
						break
			out.append(pre)
			if not more.is_empty():
				out.append(pre + more)
		else:
			out.append(pre)
	return out

## attacks on c (mutated, mid rolls) by our unacted units until target tid dies; [] if it survives them all.
## Order: a kill now by the cheapest unit that can; else the hit with the best damage-for-counter (ranged first)
static func focus(c: Dictionary, side: String, tid: int, sup := 0.0, thr := 0.0) -> Array:
	var steps := []
	for k in 6:
		var tv: Variant = Game.unit_by_id(c, tid)
		if tv == null or c.winner != null:
			return steps
		var t: Dictionary = tv
		var thp: int = t.hp
		var tval := AI.tvalue(c, t, sup, thr)
		var best: Dictionary = { }
		for u: Dictionary in c.units:
			if u.side != side or u.acted:
				continue
			var st := Game.stat(c, u)
			var rmax: int = st.rmax
			var mv: int = st.mv
			var ux: int = u.x
			var uy: int = u.y
			var tx: int = t.x
			var ty: int = t.y
			if Game.dist(ux, uy, tx, ty) > mv + rmax:
				continue
			var uval := AI.value(c, u)
			for r: Dictionary in Game.reachable(c, u).values():
				var rx: int = r.x
				var ry: int = r.y
				if not Game.targets_from(c, u, rx, ry).has(t):
					continue
				var p := Game.preview(c, u, rx, ry, t)
				var dmg: int = p.dmg
				if dmg <= 0:
					continue
				var tdef: int = Game.TERRAIN[c.tiles[ry][rx]].def
				var sc: float
				if dmg >= thp:
					sc = 100000.0 - uval + tdef + (500.0 if p.kill else 0.0) # sure kill (min roll) first
				else:
					var counter: int = p.counter
					sc = dmg * tval / 100.0 - counter * uval / 100.0 + tdef * 0.5
					if p.mayDie:
						sc -= uval
				if best.is_empty() or sc > best.sc:
					best = { "sc": sc, "step": { "kind": "act", "act": { "id": u.id, "to": [rx, ry], "kind": "attack", "target": tid } } }
		if best.is_empty():
			return []
		var step: Dictionary = best.step
		AI.apply_step(c, step)
		steps.append(step)
	return steps if Game.unit_by_id(c, tid) == null else []

## hold every own castle an enemy castle-taker could step on next turn: a unit already on it stays, else the cheapest
## unit that can reach it moves on (AE2: the castle is lost the moment their commander stands on it)
static func guard_prefix(s: Dictionary, side: String) -> Array:
	var steps := []
	var used := { }
	var c: Dictionary = s.duplicate(true)
	var threatened := { }
	for e: Dictionary in c.units:
		if e.side == side or not Game.stat(c, e).get("capC", false):
			continue
		var reach := Game.reachable(c, e)
		var mv: int = Game.stat(c, e).mv
		var ex: int = e.x
		var ey: int = e.y
		for key: Vector2i in Game.castle_tiles(c, side):
			# reachable() leaves out tiles our units stand on: an occupied castle counts by plain distance
			if reach.has(key) or Game.dist(ex, ey, key.x, key.y) <= mv:
				threatened[key] = true
	for key: Vector2i in threatened:
		var on: Variant = Game.unit_at(c, key.x, key.y)
		if on != null:
			if on.side == side and not on.acted:
				var st := { "kind": "act", "act": { "id": on.id, "to": [key.x, key.y], "kind": "wait" } }
				AI.apply_step(c, st)
				steps.append(st)
			continue
		var best: Variant = null
		var best_v := INF
		for u: Dictionary in c.units:
			if u.side != side or u.acted or used.has(u.id):
				continue
			var v := AI.value(c, u)
			if v < best_v and Game.reachable(c, u).has(key):
				best = u
				best_v = v
		if best != null:
			used[best.id] = true
			var st := { "kind": "act", "act": { "id": best.id, "to": [key.x, key.y], "kind": "wait" } }
			AI.apply_step(c, st)
			steps.append(st)
	return steps

## AE2: a bought unit acts this turn, v1 buys only after every unit acted. The buys v1 would make, made now on c
## (mutated), so the new units can join the turn
static func buy_prefix(c: Dictionary) -> Array:
	var steps := []
	var m := { }
	for k in 8:
		var stv: Variant = AI.buy_step(c, m)
		if stv == null:
			break
		var st: Dictionary = stv
		AI.apply_step(c, st)
		steps.append(st)
	return steps

## our commander to the reachable tile with the least expected enemy damage next turn (heal tile, cover break ties)
static func hero_safe_prefix(s: Dictionary, side: String) -> Array:
	var hero: Variant = null
	for u: Dictionary in s.units:
		if u.side == side and u.type == "hero" and not u.acted:
			hero = u
	if hero == null:
		return []
	var h: Dictionary = hero
	var threat := AI.threat_map(s, side)
	var best: Variant = null
	var best_sc := INF
	var hhp: int = h.hp
	for r: Dictionary in Game.reachable(s, h).values():
		var rx: int = r.x
		var ry: int = r.y
		var key := Vector2i(rx, ry)
		var hurt := AI.expected_hit(s, h, rx, ry, threat.get(key), 1.0)
		var tdef: int = Game.TERRAIN[s.tiles[ry][rx]].def
		var sc := hurt - tdef * 0.1
		if Game.heals_at(s, side, rx, ry) and hhp < 100:
			sc -= 10.0
		if sc < best_sc:
			best_sc = sc
			best = [rx, ry]
	if best == null:
		return []
	return [{ "kind": "act", "act": { "id": h.id, "to": best, "kind": "wait" } }]

## fresh per simulated turn (claims, knob cache), sharing the turn's reach / threat / distance caches
static func _sim_mem(shared: Dictionary) -> Dictionary:
	return { "tm": shared.tm, "rc": shared.rc, "df": shared.df }

## copy of s: forced prefix, then the greedy AI with `over` knobs to the end of the turn, then the opponent's turn.
## {} when the prefix is illegal
static func _rollout(s: Dictionary, side: String, over: Dictionary, pre: Array, shared: Dictionary, P: Dictionary) -> Dictionary:
	var c: Dictionary = s.duplicate(true)
	var foe := Game.other(side)
	c.aiParams = { side: over, foe: OPP }
	var steps := []
	var alive := []
	for st: Dictionary in pre:
		if not legal(c, st):
			return { }
		AI.apply_step(c, st)
		steps.append(st)
		alive.append(alive_ids(c))
	var m := _sim_mem(shared)
	for k in MAX_STEPS:
		if c.winner != null:
			break
		var stv: Variant = AI.greedy_step(c, m)
		if stv == null:
			break
		var st: Dictionary = stv
		AI.apply_step(c, st)
		steps.append(st)
		alive.append(alive_ids(c))
	var score := evaluate(c, side, shared, P) if c.winner != null else _reply_score(c, side, shared, P)
	return { "steps": steps, "alive": alive, "score": score }

## the opponent's turn on c (mutated) -> our score after it. Replies tried: its greedy turn, and its focus-fire kills
## (our most valuable units first) finished greedily; the worst one for us counts (2-ply minimax over a portfolio)
static func _reply_score(c: Dictionary, side: String, shared: Dictionary, P: Dictionary) -> float:
	Game.end_turn(c)
	var foe := Game.other(side)
	Game.fixed_roll = knob(P, "pl_opp_roll") # > 0.5: plan against a lucky reply
	var replies := [[]]
	if c.winner == null:
		replies.append_array(kill_prefixes(c, foe, int(knob(P, "pl_opp_kill"))))
	var worst := INF
	for pre: Array in replies:
		var r: Dictionary = c if replies.size() == 1 else c.duplicate(true)
		for st: Dictionary in pre:
			AI.apply_step(r, st)
		play_greedy(r, shared)
		Game.fixed_roll = 0.5
		if r.winner == null:
			Game.end_turn(r)
		if r.winner == null and knob(P, "pl_ply3") > 0.0: # our follow-up turn: rewards set-ups
			play_greedy(r, shared)
		worst = minf(worst, evaluate(r, side, shared, P))
		Game.fixed_roll = knob(P, "pl_opp_roll")
	Game.fixed_roll = 0.5
	return worst

## the side to move plays the rest of its turn with the greedy AI (its s.aiParams knobs)
static func play_greedy(c: Dictionary, shared: Dictionary) -> void:
	var m := _sim_mem(shared)
	for k in MAX_STEPS:
		if c.winner != null:
			return
		var stv: Variant = AI.greedy_step(c, m)
		if stv == null:
			return
		var st: Dictionary = stv
		AI.apply_step(c, st)

## side's view of a position: material (value x hp), bank, income, castles, advance; win / loss dominate
static func evaluate(c: Dictionary, side: String, shared: Dictionary, P: Dictionary) -> float:
	if c.winner != null:
		return WIN if c.winner == side else -WIN
	var alpha := knob(P, "pl_alpha")
	var hp_cap := knob(P, "pl_hp_cap")
	var adv := knob(P, "pl_adv")
	var adv_hero := knob(P, "pl_adv_hero")
	var hero_risk := knob(P, "pl_hero_risk")
	var sc := 0.0
	for sd: String in ["p", "e"]:
		var sgn := 1.0 if sd == side else -1.0
		var part := 0.0
		var tgt := []
		var cas := []
		var owner: Dictionary = c.owner
		for key: Vector2i in _buildings(c, shared):
			if owner.get(key) != sd:
				tgt.append([key.x, key.y])
				if Game.sells(Game.tile_at(c, key.x, key.y)):
					cas.append([key.x, key.y])
		for u: Dictionary in c.units:
			if u.side != sd:
				continue
			var hp: float = u.hp
			var val := AI.value(c, u)
			var hpv := minf(val * (1.0 - alpha), hp_cap) # hp heals: a commander's hp is not worth its whole value
			part += val - hpv + hpv * hp / 100.0
			var st := Game.stat(c, u)
			var mc: String = st.move if st.move in ["fly", "water"] else "foot"
			var hero: bool = u.type == "hero"
			var goals: Array = cas if hero else tgt
			if goals.is_empty():
				continue
			var df := AI._dist_cached(c, mc, goals, shared)
			var ux: int = u.x
			var uy: int = u.y
			var d0: float = df.get(Vector2i(ux, uy), 30.0)
			var d := minf(d0, 30.0)
			part -= d * (adv_hero if hero else adv)
		var gold: int = c.gold[sd]
		part += gold * knob(P, "pl_gold")
		part += Game.income(c, sd) * knob(P, "pl_inc")
		part += Game.castles(c, sd) * knob(P, "pl_castle")
		if Game.hero_alive(c, sd):
			part += knob(P, "pl_hero")
		if hero_risk > 0.0:
			part -= _hero_risk(c, sd, shared, hero_risk)
		sc += sgn * part
	return sc

## sd's commander where it stands: smooth death risk from every enemy that can reach it (v1's _risk on the threat map)
static func _hero_risk(c: Dictionary, sd: String, shared: Dictionary, die_val: float) -> float:
	for h: Dictionary in c.units:
		if h.side != sd or h.type != "hero":
			continue
		var tm := { "tiles_h": hash(c.tiles), "tm": shared.tm, "rc": shared.rc }
		var threat := AI.threat_map(c, sd, { }, tm)
		var hx: int = h.x
		var hy: int = h.y
		var hurt := AI.expected_hit(c, h, hx, hy, threat.get(Vector2i(hx, hy)), 0.6)
		var hhp: float = h.hp
		return AI._risk(hurt, hhp, 0.0, die_val)
	return 0.0

## owned-or-ownable building tiles (villages, castles), scanned once per turn
static func _buildings(c: Dictionary, shared: Dictionary) -> Array:
	if not shared.has("pl_bld"):
		var out := []
		for y: int in c.h:
			for x: int in c.w:
				if Game.cap_flag(c.tiles[y][x]) != "":
					out.append(Vector2i(x, y))
		shared.pl_bld = out
	return shared.pl_bld
