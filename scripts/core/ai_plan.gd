class_name AIPlan
extends RefCounted
## hard v2 (AI.PRESETS.hard "planner": 2): plans the whole turn, then hands it out one step at a time.
## Candidate turns (portfolio: v1 greedy under a few knob sets, focus-fire kill prefixes) are played out on copies of
## the state with mid rolls; the opponent answers with the v1 greedy; the position after that is scored -> best turn.
## A real roll that changes who is alive -> replan the rest. Deterministic: own RNG seeded from the state, work capped
## by counts (the wall-clock cap is an emergency stop only). Never mutates s.

## every planner knob; read through AI.params (s.aiParams[side]) so tune.gd specs can override them
const DEFAULT := {
	"pl_alpha": 0.3, # unit worth at 0 hp as a share of its value (still blocks, captures, heals back)
	"pl_gold": 1.0, # per gold in the bank
	"pl_inc": 4.0, # turns of income
	"pl_castle": 300.0, # per castle on top of its income (buy point; the last one decides the game)
	"pl_adv": 4.0, # per move-cost tile: units toward buildings not theirs
	"pl_adv_hero": 12.0, # commander toward castles not its own
	"pl_cands": 6.0, # knob-set candidates, first plan of the turn
	"pl_replan": 3.0, # knob-set candidates when a roll broke the plan
	"pl_kill": 3.0, # focus-fire kill prefixes (most valuable reachable enemies) + 1 chained double kill
	"pl_ms": 4000.0, # emergency wall-clock cap per plan
}
## knob sets for the greedy turn (merged over the side's own knobs); first = as is
const STYLES := [
	{},
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
static var last := {}

static func knob(P: Dictionary, k: String) -> float:
	var v: float = P.get(k, DEFAULT[k])
	return v

static func next_step(s: Dictionary, mem: Dictionary) -> Variant:
	for attempt in 2:
		if attempt == 1 or not mem.has("pl_steps"):
			_replan(s, mem)
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
			ok = Game.raisable_graves(s, u, tx, ty).any(func(g: Dictionary) -> bool: return g.x == gx and g.y == gy)
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
			mem[k] = {}
	var own: Dictionary = {}
	for k: String in P:
		if k != "planner" and not k.begins_with("pl_"):
			own[k] = P[k]
	var n := int(knob(P, "pl_replan" if mid else "pl_cands"))
	var cands := []
	for i in mini(n, STYLES.size()):
		var style: Dictionary = STYLES[i]
		cands.append({ "pre": [], "over": own.merged(style, true) })
	for pre: Array in kill_prefixes(s, side, int(knob(P, "pl_kill"))):
		cands.append({ "pre": pre, "over": own })
	var best: Dictionary = {}
	var runs := 0
	var capped := false
	var ms := knob(P, "pl_ms")
	for c: Dictionary in cands:
		if runs > 0 and Time.get_ticks_msec() - t0 > ms:
			capped = true
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
	AI.rng = prev_rng
	Game.fixed_roll = prev_roll
	mem.pl_steps = best.get("steps", [])
	mem.pl_alive = best.get("alive", [])
	mem.pl_i = 0
	last = { "runs": runs, "ms": Time.get_ticks_msec() - t0, "capped": capped, "score": best.get("score", 0.0) }

## focus fire: for the n most valuable enemies we can reach, the attack sequence that kills it (mid rolls), plus the
## best kill chained with a second one. Each = a forced prefix; the greedy AI finishes the turn
static func kill_prefixes(s: Dictionary, side: String, n: int) -> Array:
	if n <= 0:
		return []
	var foes := []
	for u: Dictionary in s.units:
		if u.side != side:
			foes.append(u)
	foes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var va := AI.value(s, a)
		var vb := AI.value(s, b)
		return va > vb or (va == vb and a.id < b.id))
	var out := []
	for f: Dictionary in foes:
		if out.size() >= n:
			break
		var c: Dictionary = s.duplicate(true)
		var fid: int = f.id
		var pre := focus(c, side, fid)
		if pre.is_empty():
			continue
		if out.is_empty(): # chain a second kill onto the best one (c is already past the first)
			var more := []
			for g: Dictionary in foes:
				var gid: int = g.id
				if gid != fid and Game.unit_by_id(c, gid) != null:
					more = focus(c.duplicate(true), side, gid)
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
static func focus(c: Dictionary, side: String, tid: int) -> Array:
	var steps := []
	for k in 6:
		var tv: Variant = Game.unit_by_id(c, tid)
		if tv == null:
			return steps
		var t: Dictionary = tv
		var thp: int = t.hp
		var tval := AI.value(c, t)
		var best: Dictionary = {}
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
			return {}
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
	if c.winner == null:
		Game.end_turn(c)
		var m2 := _sim_mem(shared)
		for k in MAX_STEPS:
			if c.winner != null:
				break
			var stv: Variant = AI.greedy_step(c, m2)
			if stv == null:
				break
			var st: Dictionary = stv
			AI.apply_step(c, st)
		if c.winner == null:
			Game.end_turn(c)
	return { "steps": steps, "alive": alive, "score": evaluate(c, side, shared, P) }

## side's view of a position: material (value x hp), bank, income, castles, advance; win / loss dominate
static func evaluate(c: Dictionary, side: String, shared: Dictionary, P: Dictionary) -> float:
	if c.winner != null:
		return WIN if c.winner == side else -WIN
	var alpha := knob(P, "pl_alpha")
	var adv := knob(P, "pl_adv")
	var adv_hero := knob(P, "pl_adv_hero")
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
			part += AI.value(c, u) * (alpha + (1.0 - alpha) * hp / 100.0)
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
		sc += sgn * part
	return sc

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
