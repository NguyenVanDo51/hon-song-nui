class_name Quests
extends RefCounted
## first-time quests of a campaign level (def.quests + Guide.DEBUT of def.newUnits): progress comes from Game events of side "p".
## A quest = { do, what (unit type | tile char | null), n, text? }; state s.quests adds { have, done }. No quests key = none.
## VERBS entry keys: "ev" = func(s, e, ctx) -> bool (one Game event counts once), absent = UI-only (Quests.note);
## "ok" = func(def, q) -> String ("" = can be done). Wording: content/theme.gd text.quest_<verb>[_any] + star_quests.

## verbs whose `what` is an enemy type (wording names the enemy commander, not ours)
const FOE_VERBS := ["hit_type", "kill_type"]

## kill credit needs the earlier hit of the same ev array; target types need the dying unit
static var VERBS := {
	"select": { "ok": _ok_any },
	"move": { "ev": _ev_move, "ok": _ok_any },
	"end_turn": { "ok": _ok_any },
	"capture": { "ev": _ev_capture, "ok": _ok_capture },
	"stand_on": { "ev": _ev_stand_on, "ok": _ok_tile },
	"attack_with": { "ev": _ev_attack_with, "ok": _ok_ours },
	"kill_with": { "ev": _ev_kill_with, "ok": _ok_ours },
	"hit_type": { "ev": _ev_hit_type, "ok": _ok_enemy },
	"kill_type": { "ev": _ev_kill_type, "ok": _ok_enemy },
	"buy": { "ev": null, "ok": _ok_buy },
	"heal_on": { "ev": _ev_heal_on, "ok": _ok_tile },
	"repair": { "ev": _ev_repair, "ok": _ok_repair },
	"raze": { "ev": _ev_raze, "ok": _ok_raze },
	"raise": { "ev": _ev_raise, "ok": _ok_raise },
}

## quests of a level, win line not included
static func for_level(def: Dictionary) -> Array:
	var out := []
	var manual: Array = def.get("quests", [])
	for q: Dictionary in manual:
		out.append(_norm(q))
	if def.has("tutorial"):
		return out
	var debut: Dictionary = Content.GUIDE.DEBUT
	var new_units: Array = def.get("newUnits", [])
	for type: String in new_units:
		if not debut.has(type):
			continue
		var src: Dictionary = debut[type]
		var q := _norm(src)
		if q.do == "attack_with" and not _ours(def, str(q.what)):
			q.do = "kill_type"
		if not out.any(
			func(o: Dictionary) -> bool:
				return o.do == q.do and o.what == q.what,
		):
			out.append(q)
	return out

static func init_state(s: Dictionary, def: Dictionary) -> void:
	s.quests = for_level(def)

## campaign game opened on the screen: a save from before quests gets none (mid-level they may be undoable now)
static func on_open(s: Dictionary, def: Dictionary) -> void:
	if not s.has("quests"):
		s.quests = for_level(def) if fresh(s, def) else []

## nothing played yet: round 1, our side, no unit acted, bought or raised
static func fresh(s: Dictionary, def: Dictionary) -> bool:
	var turn: int = s.turn
	var next_id: int = s.nextId
	var start: Array = def.get("units", [])
	var units: Array = s.units
	var acted := units.any(
		func(u: Dictionary) -> bool:
			return u.acted,
	)
	return turn == 1 and s.side == "p" and next_id == start.size() + 1 and not acted

## indexes of quests newly done by the events of side "p"
static func observe(s: Dictionary, ev: Array) -> Array:
	var newly := []
	var quests: Array = s.get("quests", [])
	for i in quests.size():
		var q: Dictionary = quests[i]
		var entry: Dictionary = VERBS.get(q.do, { })
		var f: Variant = entry.get("ev")
		if q.done or f == null:
			continue
		var fn: Callable = f
		for k in ev.size():
			var e: Dictionary = ev[k]
			if fn.call(s, e, { "q": q, "ev": ev, "k": k }):
				if _bump(q):
					newly.append(i)
					break
	return newly

## UI-only verbs (select, buy, end_turn): the screen reports what happened
static func note(s: Dictionary, verb: String, what: Variant) -> Array:
	var newly := []
	var quests: Array = s.get("quests", [])
	for i in quests.size():
		var q: Dictionary = quests[i]
		if q.done or q.do != verb or (q.what != null and q.what != what):
			continue
		if _bump(q):
			newly.append(i)
	return newly

static func text(q: Dictionary) -> String:
	if q.has("text"):
		return str(q.text)
	var key := "quest_" + str(q.do)
	if q.what == null and Content.text(key + "_any") != key + "_any":
		key += "_any"
	var vars := { "unit": "", "tile": "" }
	if q.what != null:
		var w: String = q.what
		vars.unit = _unit_name(w, FOE_VERBS.has(q.do))
		var terr: Dictionary = Content.theme().terrain
		var tl: Dictionary = terr.get(w, { "name": w })
		vars.tile = str(tl.name)
	return Content.text(key).format(vars)

static func done_count(s: Dictionary) -> int:
	var quests: Array = s.get("quests", [])
	return quests.filter(
		func(q: Dictionary) -> bool:
			return q.done,
	).size()

static func total(s: Dictionary) -> int:
	var quests: Array = s.get("quests", [])
	return quests.size()

## "" = def can complete q, else why not (sim/tests.gd)
static func feasible(def: Dictionary, q: Dictionary) -> String:
	if not VERBS.has(q.do):
		return "unknown verb %s" % q.do
	var entry: Dictionary = VERBS[q.do]
	var f: Callable = entry.ok
	return f.call(def, q)

# ---------- helpers ----------
static func _norm(src: Dictionary) -> Dictionary:
	var q := { "do": src.do, "what": src.get("what"), "n": src.get("n", 1), "have": 0, "done": false }
	if src.has("text"):
		q.text = src.text
	return q

static func _bump(q: Dictionary) -> bool:
	q.have += 1
	var n: int = q.n
	var have: int = q.have
	q.done = have >= n
	return q.done

static func _unit_name(type: String, foe: bool) -> String:
	if type == "hero":
		return Content.text("questHeroE" if foe else "questHero")
	var units: Dictionary = Content.theme().units.p
	var look: Dictionary = units.get(type, { "name": type })
	return str(look.name)

static func _is(what: Variant, v: Variant) -> bool:
	return what == null or what == v

static func _ours_side(s: Dictionary, e: Dictionary) -> bool:
	var id: int = e.id
	var u: Variant = Game.unit_by_id(s, id)
	return u != null and u.side == "p"

## the "hit" before ev[k] (a die) that dealt the killing blow
static func _killer(ctx: Dictionary) -> Dictionary:
	var ev: Array = ctx.ev
	var k: int = ctx.k
	var die: Dictionary = ev[k]
	for j in range(k - 1, -1, -1):
		var h: Dictionary = ev[j]
		if h.t == "hit" and h.id == die.id:
			return h
	return { }

# ---------- event matchers ----------
static func _ev_move(s: Dictionary, e: Dictionary, ctx: Dictionary) -> bool:
	if e.t != "move":
		return false
	var id: int = e.id
	var u: Variant = Game.unit_by_id(s, id)
	return u != null and u.side == "p" and _is(ctx.q.what, u.type)

static func _ev_stand_on(s: Dictionary, e: Dictionary, ctx: Dictionary) -> bool:
	if e.t != "move" or not _ours_side(s, e):
		return false
	var path: Array = e.path
	var last: Array = path[path.size() - 1]
	var lx: int = last[0]
	var ly: int = last[1]
	return _is(ctx.q.what, Game.tile_at(s, lx, ly))

static func _ev_capture(_s: Dictionary, e: Dictionary, ctx: Dictionary) -> bool:
	return e.t == "capture" and e.side == "p" and _is(ctx.q.what, e.tile)

static func _ev_attack_with(_s: Dictionary, e: Dictionary, ctx: Dictionary) -> bool:
	return e.t == "hit" and e.side == "p" and not e.get("counter", false) and _is(ctx.q.what, e.type)

static func _ev_kill_with(_s: Dictionary, e: Dictionary, ctx: Dictionary) -> bool:
	if e.t != "die" or e.side != "e":
		return false
	var h := _killer(ctx)
	return not h.is_empty() and h.side == "p" and _is(ctx.q.what, h.type)

static func _ev_kill_type(_s: Dictionary, e: Dictionary, ctx: Dictionary) -> bool:
	if e.t != "die" or e.side != "e" or not _is(ctx.q.what, e.type):
		return false
	var h := _killer(ctx)
	return not h.is_empty() and h.side == "p"

static func _ev_hit_type(s: Dictionary, e: Dictionary, ctx: Dictionary) -> bool:
	if e.t != "hit" or e.side != "p" or e.get("counter", false):
		return false
	var q: Dictionary = ctx.q
	if q.what == null:
		return true
	var type := ""
	var ev: Array = ctx.ev
	for o: Dictionary in ev: # a victim that died in this batch is already gone from s.units
		if o.t == "die" and o.id == e.id:
			type = str(o.type)
	var vid: int = e.id
	var u: Variant = Game.unit_by_id(s, vid)
	if u != null:
		type = str(u.type)
	return type == q.what

static func _ev_heal_on(s: Dictionary, e: Dictionary, ctx: Dictionary) -> bool:
	if e.t != "heal" or not _ours_side(s, e):
		return false
	var hx: int = e.x
	var hy: int = e.y
	return _is(ctx.q.what, Game.tile_at(s, hx, hy))

static func _ev_repair(_s: Dictionary, e: Dictionary, _ctx: Dictionary) -> bool:
	return e.t == "repair" and e.side == "p"

static func _ev_raze(_s: Dictionary, e: Dictionary, _ctx: Dictionary) -> bool:
	return e.t == "raze" and e.side == "p"

static func _ev_raise(s: Dictionary, e: Dictionary, _ctx: Dictionary) -> bool:
	return e.t == "raise" and _ours_side(s, e)

# ---------- feasibility ----------
static func _ours(def: Dictionary, type: String) -> bool:
	for u: Array in def.get("units", []):
		if u[0] == "p" and u[1] == type:
			return true
	return _allowed(def, "p", type)

## no allowed list = everything is allowed
static func _allowed(def: Dictionary, side: String, type: String) -> bool:
	var al: Dictionary = def.get("allowed", { })
	var list: Array = al.get(side, [type])
	return list.has(type)

static func _enemy_has(def: Dictionary, type: String) -> bool:
	for u: Array in def.get("units", []):
		if u[0] == "e" and u[1] == type:
			return true
	var waves: Array = def.get("waves", [])
	for w: Dictionary in waves:
		for wu: Array in w.get("units", []):
			if wu[0] == type:
				return true
	var al: Dictionary = def.get("allowed", { })
	var list: Array = al.get("e", [])
	return type != "hero" and list.has(type)

static func _tiles(def: Dictionary, ch: Variant) -> Array:
	var out := []
	var map: Dictionary = def.get("map", { })
	var rows: Array = map.get("rows", [])
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if ch == null or row[x] == ch:
				out.append(Vector2i(x, y))
	return out

static func _char(def: Dictionary, t: Vector2i) -> String:
	var map: Dictionary = def.get("map", { })
	var rows: Array = map.get("rows", [])
	var row: String = rows[t.y]
	return row[t.x]

static func _ok_any(_def: Dictionary, _q: Dictionary) -> String:
	return ""

static func _ok_ours(def: Dictionary, q: Dictionary) -> String:
	if q.what == null or _ours(def, str(q.what)):
		return ""
	return "%s: no %s on our side" % [q.do, q.what]

static func _ok_enemy(def: Dictionary, q: Dictionary) -> String:
	if q.what == null or _enemy_has(def, str(q.what)):
		return ""
	return "%s: no enemy %s" % [q.do, q.what]

static func _ok_buy(def: Dictionary, q: Dictionary) -> String:
	if q.what == null:
		return ""
	return "" if _allowed(def, "p", str(q.what)) else "buy: %s not allowed for us" % q.what

static func _ok_tile(def: Dictionary, q: Dictionary) -> String:
	return "" if not _tiles(def, q.what).is_empty() else "%s: no tile %s on the map" % [q.do, q.what]

static func _ok_capture(def: Dictionary, q: Dictionary) -> String:
	var mine := { }
	for o: Array in def.get("owner", []):
		if o[2] == "p":
			var ox: int = o[0]
			var oy: int = o[1]
			mine[Vector2i(ox, oy)] = true
	for t: Vector2i in _tiles(def, q.what):
		if not mine.has(t) and (q.what != null or Game.ter(_char(def, t)).has("cap")):
			return ""
	return "capture: no %s that is not ours" % q.what

static func _ok_repair(def: Dictionary, _q: Dictionary) -> String:
	return "" if not _tiles(def, "x").is_empty() else "repair: no ruined village (x)"

static func _ok_raze(def: Dictionary, _q: Dictionary) -> String:
	return "" if not _tiles(def, "v").is_empty() else "raze: no village"

static func _ok_raise(def: Dictionary, _q: Dictionary) -> String:
	return "" if _ours(def, "shaman") else "raise: no shaman on our side"
