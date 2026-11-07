extends RefCounted
## match review (sim/review.gd, tools/review_match.sh): replay a recorded match (scripts/core/replay.gd), verify hashes, then
## per half-turn: eval timeline, hard v3 planner from the same start vs what was played (2-ply, mid rolls), rule labels
## (human mistakes), bot weaknesses (exploited / blunder / risky metrics) + scenario files. Report = Dictionary
## (review_out.gd writes md / json / lessons). Never touches the replay file.

const TacticsLib := preload("res://sim/tactics_lib.gd")

const MISTAKE_MIN := 100.0 # 2-ply eval below hard v3's line from the same start (~gold) -> a mistake
const EXPLOIT_MIN := 150.0 # human reply this far above the bot's opponent model -> bot exploited
const BLUNDER_MIN := 150.0 # bot's line this far below the hard planner's -> bot blunder
const CLAMP := 5000.0 # win / loss (AIPlan.WIN) clamped for deltas and ranking
const TOP := 5
const LOW_HP := 40
const SCEN_FORMAT := 1

var scen_dir := "res://sim/scenarios"
var write_scen := true
var planner_runs := 0
var planner_ms := 0

# ---------- replay ----------
## replay rep (Replay.load_file) from its start state -> {halves, final, finish, div, steps}. A half = one side's turn:
## {turn, side, who, start, steps, events, end (before end_turn), after (after it), ended}
static func walk(rep: Dictionary) -> Dictionary:
	var head: Dictionary = rep.head
	var s := Replay.start_state(head)
	var halves := []
	var div := { }
	var fin := { }
	var n_steps := 0
	if s.is_empty():
		return { "halves": halves, "final": s, "finish": fin, "div": { "why": "no start state" }, "steps": 0 }
	var prev_roll := Game.fixed_roll
	Game.fixed_roll = -1.0
	var cur: Dictionary = { }
	if Replay.state_hash(s) != head.get("h", ""):
		div = { "i": -1, "why": "start state hash differs from the head" }
	var recs: Array = rep.recs
	for i in recs.size():
		if not div.is_empty():
			break
		var r: Dictionary = recs[i]
		var t: String = r.get("t", "")
		if t == "finish":
			fin = r
			continue
		if t == "resume":
			if r.get("h") != Replay.state_hash(s):
				div = { "i": i, "turn": s.turn, "why": "resume: saved state differs from the replayed one" }
			continue
		if t != "step":
			continue
		var st: Dictionary = r.step
		if cur.is_empty():
			cur = _half(s, str(r.get("who", "human")))
		var end: bool = st.get("kind") == "end"
		if end:
			cur.end = s.duplicate(true)
		var ev: Variant = Replay.apply(s, st)
		if ev == null:
			div = { "i": i, "turn": r.get("turn"), "side": r.get("side"), "why": "step refused by the rules", "step": st }
			break
		n_steps += 1
		var evs: Array = ev
		if end:
			cur.after = s.duplicate(true)
			cur.ended = true
			halves.append(cur)
			cur = { }
		else:
			var steps: Array = cur.steps
			steps.append(st)
			var events: Array = cur.events
			events.append_array(evs)
		var got := Replay.state_hash(s)
		if got != r.get("h"):
			div = { "i": i, "turn": r.get("turn"), "side": r.get("side"), "why": "hash %s != recorded %s" % [got, r.get("h")], "step": st }
	if not cur.is_empty():
		var last: Dictionary = s.duplicate(true)
		cur.end = last
		cur.after = last
		halves.append(cur)
	Game.fixed_roll = prev_roll
	return { "halves": halves, "final": s, "finish": fin, "div": div, "steps": n_steps }

static func _half(s: Dictionary, who: String) -> Dictionary:
	var st: Dictionary = s.duplicate(true)
	return { "turn": s.turn, "side": s.side, "who": who, "start": st, "steps": [], "events": [], "end": st, "after": st, "ended": false }

# ---------- scoring (planner's own eval, mid rolls) ----------
static func hard_p() -> Dictionary:
	return AI.DEFAULT.merged(AI.PRESETS.hard, true)

static func _shared() -> Dictionary:
	return { "tm": { }, "rc": { }, "df": { } }

## side's static eval of s (AIPlan.evaluate, hard knobs), clamped
static func eval_of(s: Dictionary, side: String) -> float:
	return clampf(AIPlan.evaluate(s, side, _shared(), hard_p()), -CLAMP, CLAMP)

## 2-ply score of playing steps from start: steps (mid rolls; refused ones skipped), the foe answers with the planner's
## opponent model (v1 greedy, no noise), side's eval after. Mirrors AIPlan._rollout + _reply_score (pl_opp_kill / pl_ply3 off)
static func line_score(start: Dictionary, side: String, steps: Array) -> float:
	var c: Dictionary = start.duplicate(true)
	var foe := Game.other(side)
	c.aiParams = { side: AI.PRESETS.hard, foe: AIPlan.OPP }
	var shared := _shared()
	var prev_rng: Callable = AI.rng
	var prev_roll := Game.fixed_roll
	var gen := RandomNumberGenerator.new()
	gen.seed = hash([start.get("rng", 0), start.turn, side])
	AI.rng = gen.randf
	Game.fixed_roll = 0.5
	for st: Dictionary in steps:
		if c.winner != null:
			break
		if st.get("kind") != "end":
			Replay.apply(c, st) # refused under mid rolls (a real roll changed who lives): skipped
	if c.winner == null and c.side == side:
		Game.end_turn(c)
		AIPlan.play_greedy(c, shared)
		if c.winner == null:
			Game.end_turn(c)
	var sc := AIPlan.evaluate(c, side, shared, hard_p())
	AI.rng = prev_rng
	Game.fixed_roll = prev_roll
	return clampf(sc, -CLAMP, CLAMP)

## what hard v3 (AI.PRESETS.hard, planner 2) plays for side from start: the planned turn
func hard_line(start: Dictionary, side: String) -> Array:
	var c: Dictionary = start.duplicate(true)
	var old: Dictionary = c.get("aiParams", { })
	var aip := old.duplicate()
	aip[side] = AI.PRESETS.hard
	c.aiParams = aip
	var mem := { }
	var t0 := Time.get_ticks_msec()
	var first: Variant = AI.next_step(c, mem)
	planner_ms += Time.get_ticks_msec() - t0
	planner_runs += 1
	if first == null:
		return []
	var plan: Array = mem.get("pl_steps", [first])
	return plan

# ---------- review ----------
func review(rep: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	planner_runs = 0
	planner_ms = 0
	var head: Dictionary = rep.head
	var w := walk(rep)
	var halves: Array = w.halves
	var ai: Dictionary = head.get("ai", { })
	var humans := []
	for side: String in ["p", "e"]:
		if ai.get(side, "human") == "human":
			humans.append(side)
	var persp: String = humans[0] if humans.size() > 0 else "p"
	var path: String = rep.path
	var id := path.get_file().trim_suffix(Replay.EXT)
	var fin: Dictionary = w.finish
	var final: Dictionary = w.final
	var div: Dictionary = w.div
	var recs: Array = rep.recs
	var timeline := []
	var human_tags := { }
	var bot := { "weak": [], "tags": { }, "scen": [] }
	var prev_eval := 0.0
	if halves.size() > 0:
		var h0: Dictionary = halves[0]
		var s0: Dictionary = h0.start
		prev_eval = eval_of(s0, persp)
	var human_rows := { } # half index -> mistake row
	for i in halves.size():
		var h: Dictionary = halves[i]
		var nx: Dictionary = halves[i + 1] if i + 1 < halves.size() else { }
		var after: Dictionary = h.after
		var ev := eval_of(after, persp)
		timeline.append(_tl_row(h, ev, ev - prev_eval))
		prev_eval = ev
		if h.who == "human":
			var row := _human_half(h, nx)
			human_rows[i] = row
			var labels: Array = row.labels
			for tag: Dictionary in labels:
				_count(human_tags, str(tag.tag))
		else:
			_bot_half(h, nx, id, str(ai.get(h.side, "normal")), bot)
	var bot_weak: Array = bot.weak
	var out := {
		"id": id,
		"file": path,
		"date": head.get("date", ""),
		"kind": head.get("kind", ""),
		"map": _map_of(head),
		"ai": ai,
		"bot_flag": head.get("bot", false),
		"humans": humans,
		"persp": persp,
		"result": {
			"winner": fin.get("winner", final.get("winner")),
			"reason": fin.get("reason", final.get("reason")),
			"turns": final.get("turn", 0),
			"finished": not fin.is_empty(),
		},
		"replay": { "records": recs.size(), "steps": w.steps, "bad_lines": rep.bad, "verified": div.is_empty(), "divergence": div },
		"timeline": timeline,
		"human_mistakes": top_mistakes(human_rows),
		"turning_points": turning_points(timeline, human_rows, bot_weak),
		"human_tags": human_tags,
		"bot_weaknesses": bot.weak,
		"bot_tags": bot.tags,
		"scenarios": bot.scen,
	}
	out.timing = { "sec": (Time.get_ticks_msec() - t0) / 1000.0, "planner_runs": planner_runs, "planner_sec": planner_ms / 1000.0 }
	return out

static func _map_of(head: Dictionary) -> String:
	var ctx: Dictionary = head.get("ctx", { })
	return str(ctx.get("map", ctx.get("id", head.get("id", ""))))

static func _count(d: Dictionary, k: String) -> void:
	var n: int = d.get(k, 0)
	d[k] = n + 1

static func _tl_row(h: Dictionary, ev: float, delta: float) -> Dictionary:
	var a: Dictionary = h.after
	var gold: Dictionary = a.gold
	var row := { "turn": h.turn, "side": h.side, "who": h.who, "eval": snappedf(ev, 0.1), "delta": snappedf(delta, 0.1) }
	var g := { }
	var units := { }
	var castles := { }
	var income := { }
	for sd: String in ["p", "e"]:
		g[sd] = gold[sd]
		units[sd] = Game.unit_count(a, sd)
		castles[sd] = Game.castles(a, sd)
		income[sd] = Game.income(a, sd)
	row.gold = g
	row.units = units
	row.castles = castles
	row.income = income
	row.what = summary(h)
	return row

## a half's notable events: deaths, captures, razes, promotions, buys, win
static func summary(h: Dictionary) -> Array:
	var out := []
	var evs: Array = h.events
	var end: Dictionary = h.end
	for e: Dictionary in evs:
		var t: String = e.t
		if t == "die":
			out.append("%s %s#%d died @(%d,%d)" % [e.side, e.type, e.id, e.x, e.y])
		elif t == "capture":
			out.append("%s took %s @(%d,%d)" % [e.side, "castle" if Game.sells(e.tile) else "village", e.x, e.y])
		elif t == "raze":
			out.append("%s razed @(%d,%d)" % [e.side, e.x, e.y])
		elif t == "rank":
			var uid: int = e.id
			var uv: Variant = Game.unit_by_id(end, uid)
			if uv != null:
				var u: Dictionary = uv
				out.append("%s %s#%d -> rank %d" % [u.side, u.type, uid, e.rank])
		elif t == "buy":
			out.append("%s bought %s @(%d,%d)" % [e.side, e.type, e.x, e.y])
		elif t == "win":
			out.append("%s wins (%s)" % [e.side, e.reason])
	if out.is_empty():
		out.append("moves only")
	return out

# ---------- human turns ----------
func _human_half(h: Dictionary, nx: Dictionary) -> Dictionary:
	var side: String = h.side
	var start: Dictionary = h.start
	var steps: Array = h.steps
	var ref := hard_line(start, side)
	var my_sc := line_score(start, side, steps)
	var best_sc := line_score(start, side, ref)
	var labels := label_half(h, nx)
	if best_sc >= CLAMP and my_sc < CLAMP:
		labels.append({ "tag": "missed_win", "note": "hard v3 wins the game from here" })
	var played := TacticsLib.fmt_steps(start, steps)
	var better := TacticsLib.fmt_steps(start, ref)
	return {
		"turn": h.turn,
		"side": side,
		"loss": snappedf(best_sc - my_sc, 0.1),
		"score": snappedf(my_sc, 0.1),
		"bot_score": snappedf(best_sc, 0.1),
		"played": played,
		"better": "(same as played)" if better == played else better,
		"labels": labels,
		"what": summary(h),
	}

## rule-based labels of a human half (side = h.side): real states, h.end = its turn end, nx.after = after the foe's reply
static func label_half(h: Dictionary, nx: Dictionary) -> Array:
	var me: String = h.side
	var foe := Game.other(me)
	var S: Dictionary = h.start
	var E: Dictionary = h.end
	var N: Dictionary = nx.get("after", { })
	var out := []
	var expo := TacticsLib.exposure(E, me)
	var killable_ids := { }
	for x: Dictionary in expo:
		var u: Dictionary = x.u
		var uid: int = u.id
		var hero: bool = x.hero
		var killable: bool = x.killable
		var allies: int = x.allies
		var full: float = x.full
		killable_ids[uid] = killable
		var dead := not N.is_empty() and Game.unit_by_id(N, uid) == null
		if hero and killable and E.winner == null:
			var note := "commander %s left killable (enemy focus %d >= hp)%s" % [TacticsLib.unit_str(u), int(full), " -> died" if dead else ""]
			out.append({ "tag": "hero_killable", "at": [u.x, u.y], "note": note, "punished": dead })
		elif not hero and killable and allies == 0 and dead:
			out.append({ "tag": "lone_unit_killed", "at": [u.x, u.y], "note": "lone %s killed next turn" % TacticsLib.unit_str(u), "punished": true })
	var miss := _missed_kill(h)
	if not miss.is_empty():
		out.append(miss)
	if not N.is_empty():
		var own: Dictionary = E.owner
		var later: Dictionary = N.owner
		for key: Vector2i in own:
			if own[key] == me and later.get(key) != me:
				var castle := Game.sells(Game.tile_at(E, key.x, key.y))
				out.append({ "tag": "castle_lost" if castle else "village_lost", "at": [key.x, key.y], "note": "lost next turn", "punished": true })
	if E.winner == null and E.side == me:
		var gold: int = E.gold[me]
		for key: Vector2i in Game.castle_tiles(E, me):
			if Game.unit_at(E, key.x, key.y) != null:
				continue
			var ok := Game.buy_options(E, me, key.x, key.y).any(
				func(o: Dictionary) -> bool:
					return o.ok,
			)
			if ok:
				out.append({ "tag": "gold_unspent", "at": [key.x, key.y], "note": "%d gold left, free castle" % gold })
				break
	var evs: Array = h.events
	for e: Dictionary in evs:
		if e.t != "rank":
			continue
		var rid: int = e.id
		var rv: Variant = Game.unit_by_id(E, rid)
		if rv != null:
			var ru: Dictionary = rv
			if ru.side == foe:
				out.append({ "tag": "fed_promotion", "at": [ru.x, ru.y], "note": "enemy %s ranked up on our attack" % TacticsLib.unit_str(ru) })
	for u: Dictionary in S.units:
		var hp: int = u.hp
		if u.side != me or u.acted or hp > LOW_HP:
			continue
		var uid: int = u.id
		var ev: Variant = Game.unit_by_id(E, uid)
		if ev == null or not killable_ids.get(uid, false):
			continue
		var ue: Dictionary = ev
		var ex: int = ue.x
		var ey: int = ue.y
		if Game.heals_at(E, me, ex, ey):
			continue
		for r: Dictionary in Game.reachable(S, u).values():
			var rx: int = r.x
			var ry: int = r.y
			if Game.heals_at(S, me, rx, ry) and Game.unit_at(S, rx, ry) == null:
				var note := "%s stayed in reach, heal tile (%d,%d) was reachable" % [TacticsLib.unit_str(u), rx, ry]
				out.append({ "tag": "no_retreat", "at": [ex, ey], "note": note })
				break
	return out

## the most valuable enemy a min-roll focus fire could kill from h.start that is alive at h.end, unless we killed as much
static func _missed_kill(h: Dictionary) -> Dictionary:
	var me: String = h.side
	var S: Dictionary = h.start
	var E: Dictionary = h.end
	var evs: Array = h.events
	var killed := 0.0
	for e: Dictionary in evs:
		if e.t == "die" and e.side != me:
			var did: int = e.id
			var dv: Variant = Game.unit_by_id(S, did)
			if dv != null:
				var dd: Dictionary = dv
				killed += AI.value(S, dd)
	var foes := []
	for d: Dictionary in S.units:
		if d.side != me and _reachable_by(S, me, d):
			foes.append(d)
	foes.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return AI.value(S, a) > AI.value(S, b),
	)
	var prev_roll := Game.fixed_roll
	for d: Dictionary in foes.slice(0, 3):
		var tid: int = d.id
		if killed >= AI.value(S, d) or Game.unit_by_id(E, tid) == null:
			continue
		Game.fixed_roll = 0.0 # min rolls = sure (counters roll low too, but only hurt attackers that already hit)
		var pre := AIPlan.focus(S.duplicate(true), me, tid)
		Game.fixed_roll = prev_roll
		if not pre.is_empty():
			var note := "%s was a sure kill: %s" % [TacticsLib.unit_str(d), TacticsLib.fmt_steps(S, pre)]
			return { "tag": "missed_sure_kill", "at": [d.x, d.y], "note": note }
	return { }

static func _reachable_by(s: Dictionary, me: String, d: Dictionary) -> bool:
	var dx: int = d.x
	var dy: int = d.y
	for u: Dictionary in s.units:
		if u.side != me or u.acted:
			continue
		var st := Game.stat(s, u)
		var mv: int = st.mv
		var rmax: int = st.rmax
		var ux: int = u.x
		var uy: int = u.y
		if Game.dist(ux, uy, dx, dy) <= mv + rmax:
			return true
	return false

## human halves worth listing (loss >= MISTAKE_MIN or a label), worst first
static func top_mistakes(human_rows: Dictionary) -> Array:
	var rows := []
	for i: int in human_rows:
		var row: Dictionary = human_rows[i]
		var labels: Array = row.labels
		var loss: float = row.loss
		if loss >= MISTAKE_MIN or not labels.is_empty():
			rows.append(row)
	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var la: float = a.loss
			var lb: float = b.loss
			return la > lb or (la == lb and _punished(a) > _punished(b)),
	)
	return rows.slice(0, TOP)

static func _punished(row: Dictionary) -> int:
	var labels: Array = row.labels
	return labels.filter(
		func(l: Dictionary) -> bool:
			return l.get("punished", false),
	).size()

# ---------- bot turns ----------
func _bot_half(h: Dictionary, nx: Dictionary, id: String, lvl: String, bot: Dictionary) -> void:
	var side: String = h.side
	var start: Dictionary = h.start
	var steps: Array = h.steps
	var ref := hard_line(start, side)
	var exp_sc := line_score(start, side, ref)
	var act_sc := line_score(start, side, steps)
	var tags: Dictionary = bot.tags
	var weak: Array = bot.weak
	var base := { "turn": h.turn, "side": side, "level": lvl }
	if exp_sc - act_sc >= BLUNDER_MIN:
		var row := base.merged(
			{
				"tag": "bot_blunder",
				"gap": snappedf(exp_sc - act_sc, 0.1),
				"note": "played below %s planner: %s" % ["its own" if lvl == "hard" else "hard v3", TacticsLib.fmt_steps(start, steps)],
				"better": TacticsLib.fmt_steps(start, ref),
			}
		)
		weak.append(row)
		_count(tags, "bot_blunder")
	var N: Dictionary = { }
	if not nx.is_empty() and nx.who == "human":
		N = nx.after
		var end: Dictionary = h.end
		var model := line_score(end, side, []) # bot's opponent model answering the real position
		var real := eval_of(N, side)
		if model - real >= EXPLOIT_MIN:
			var nx_start: Dictionary = nx.start
			var nx_steps: Array = nx.steps
			var row := base.merged(
				{
					"tag": "bot_exploited",
					"gap": snappedf(model - real, 0.1),
					"note": "human reply beat the bot's opponent model: %s" % ", ".join(summary(nx)),
					"reply": TacticsLib.fmt_steps(nx_start, nx_steps),
				}
			)
			var note := "bot_exploited: expected %.0f, got %.0f after the human reply" % [model, real]
			var p := save_scenario_for(id, h, note, model, real)
			if p != "":
				row.scenario = p
				var scen: Array = bot.scen
				scen.append(p)
			weak.append(row)
			_count(tags, "bot_exploited")
	_risky(h, N, base, bot)

## bot turn end metrics (tactics_lib): lone killable units, commander killable, castles a foe capturer can step on
static func _risky(h: Dictionary, N: Dictionary, base: Dictionary, bot: Dictionary) -> void:
	var side: String = h.side
	var E: Dictionary = h.end
	if E.winner != null:
		return
	var tags: Dictionary = bot.tags
	var weak: Array = bot.weak
	for x: Dictionary in TacticsLib.exposure(E, side):
		var u: Dictionary = x.u
		var uid: int = u.id
		var hero: bool = x.hero
		var killable: bool = x.killable
		var allies: int = x.allies
		var dead := not N.is_empty() and Game.unit_by_id(N, uid) == null
		var tag := ""
		if hero and killable:
			tag = "bot_hero_exposed"
		elif not hero and killable and allies == 0:
			tag = "bot_lone_unit"
		if tag == "":
			continue
		_count(tags, tag + ("_punished" if dead else ""))
		if dead or hero:
			weak.append(base.merged({ "tag": tag, "at": [u.x, u.y], "punished": dead, "note": TacticsLib.unit_str(u) }))
	var later: Dictionary = N.get("owner", { })
	for key: Vector2i in AI.endangered_castles(E, side):
		var lost: bool = not N.is_empty() and later.get(key) != side
		_count(tags, "bot_castle_open" + ("_punished" if lost else ""))
		if lost:
			weak.append(
				base.merged(
					{ "tag": "bot_castle_open", "at": [key.x, key.y], "punished": true, "note": "empty castle in a foe capturer's reach, lost" }
				)
			)

## start-of-turn position + side + note -> sim/scenarios/<replay-id>_t<turn>.scenario (var_to_str). "" = not written
func save_scenario_for(id: String, h: Dictionary, note: String, expected: float, actual: float) -> String:
	if not write_scen:
		return ""
	var turn: int = h.turn
	var rec := {
		"format": SCEN_FORMAT,
		"replay": id,
		"turn": turn,
		"side": h.side,
		"kind": "bot_exploited",
		"note": note,
		"expected": expected,
		"actual": actual,
		"state": h.start,
	}
	return save_scenario(scen_dir.path_join("%s_t%d.scenario" % [id, turn]), rec)

static func save_scenario(path: String, rec: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null or not f.store_string(var_to_str(rec)):
		return ""
	return path

static func load_scenario(path: String) -> Dictionary:
	var v: Variant = str_to_var(FileAccess.get_file_as_string(path))
	if v is Dictionary:
		var d: Dictionary = v
		return d
	return { }

# ---------- turning points ----------
## biggest eval swings (persp side): turn, what happened, the better move from our turn (this one or the one before)
static func turning_points(tl: Array, human_rows: Dictionary, bot_weak: Array) -> Array:
	var idx := range(tl.size())
	idx.sort_custom(
		func(a: int, b: int) -> bool:
			var ra: Dictionary = tl[a]
			var rb: Dictionary = tl[b]
			var da: float = ra.delta
			var db: float = rb.delta
			return absf(da) > absf(db),
	)
	var out := []
	for i: int in idx.slice(0, TOP):
		var r: Dictionary = tl[i]
		var delta: float = r.delta
		if absf(delta) < 1.0:
			continue
		var tp := { "i": i, "turn": r.turn, "side": r.side, "who": r.who, "delta": delta, "eval": r.eval, "what": r.what, "better": "", "at": [] }
		if r.who != "human" and delta > 0.0: # bot turn that lost value: its own weakness notes
			var notes := []
			for b: Dictionary in bot_weak:
				if b.turn == r.turn and b.side == r.side:
					notes.append(str(b.tag))
			tp.better = "bot: " + (", ".join(notes) if notes.size() else "no tagged weakness")
			out.append(tp)
			continue
		var j := i if r.who == "human" else i - 1 # a bot turn's swing against us: our turn before it set it up
		if human_rows.has(j):
			var hr: Dictionary = human_rows[j]
			var loss: float = hr.loss
			if loss >= MISTAKE_MIN:
				tp.better = "t%d %s: hard v3 -> %s (%+.0f)" % [hr.turn, hr.side, hr.better, loss]
			elif i == j:
				tp.better = "hard v3 no better (loss %+.0f)" % loss
			tp.at = _first_at(hr)
		out.append(tp)
	out.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var ia: int = a.i
			var ib: int = b.i
			return ia < ib,
	)
	return out

static func _first_at(row: Dictionary) -> Array:
	var labels: Array = row.labels
	for l: Dictionary in labels:
		if l.has("at"):
			var a: Array = l.at
			return a
	return []
