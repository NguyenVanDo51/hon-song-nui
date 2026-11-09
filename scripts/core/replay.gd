class_name Replay
extends RefCounted
## match replay format (recorder: scripts/ui/match_rec.gd, reader / analyzer: sim/review.gd). One JSON object per line:
##   head   {t, format, date, kind, id, profile, bot, build, platform, ctx, ctrl, ai, turn, side, prev, state (var_to_str), h}
##   step   {t, turn, side, who: human|ai, step: {kind: act|buy|unbuy|end, ...}, h}   h = state_hash after the step
##   resume {t, date, turn, side, h}   continued from a save into the same file
##   finish {t, winner, reason, turns, h}
## Same start state + same steps = same game (rolls live in s.rng). README "Ghi trận / phân tích".

const FORMAT := 1
const EXT := ".replay"
## UI-only fields (quest progress, tutorial step): not replayed headless -> not hashed
const UNHASHED := ["quests", "tut_step"]
## unit fields the AI changes while only thinking (AI.greedy_step wakes guards before its step): not hashed
const UNIT_UNHASHED := ["guard", &"guard"]

## game-relevant state fingerprint (var_to_str sorts keys -> canonical)
static func state_hash(s: Dictionary) -> String:
	var sub := { }
	for k: Variant in s:
		if not UNHASHED.has(k):
			sub[k] = s[k]
	var units := []
	for u: Dictionary in s.get("units", []):
		var c := u.duplicate()
		for k: Variant in UNIT_UNHASHED:
			c.erase(k)
		units.append(c)
	sub.units = units
	return var_to_str(sub).md5_text().substr(0, 12)

static func encode(rec: Dictionary) -> String:
	return JSON.stringify(rec, "", false)

## one line -> record ({} = unparsable, e.g. a line cut by a crash); JSON numbers come back as floats -> whole ones to int
static func decode(line: String) -> Dictionary:
	var v: Variant = JSON.parse_string(line)
	if not (v is Dictionary):
		return { }
	var d: Dictionary = ints(v)
	return d

static func ints(v: Variant) -> Variant:
	if v is float:
		var f: float = v
		if f == floorf(f) and absf(f) < 9.0e15:
			return int(f)
		return f
	if v is Array:
		var out := []
		for x: Variant in v:
			out.append(ints(x))
		return out
	if v is Dictionary:
		var d: Dictionary = v
		var out := { }
		for k: Variant in d:
			out[k] = ints(d[k])
		return out
	return v

## {head, recs, bad} of a replay file; head {} = not a replay
static func load_file(path: String) -> Dictionary:
	var out := { "head": { }, "recs": [], "bad": 0, "path": path }
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var recs: Array = out.recs
	var head: Dictionary = { }
	var bad := 0
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var r := decode(line)
		if r.is_empty():
			bad += 1
		elif r.get("t") == "head" and head.is_empty():
			head = r
		else:
			recs.append(r)
	out.head = head
	out.bad = bad
	return out

## start state stored in the head (whole s: later content changes do not break it)
static func start_state(head: Dictionary) -> Dictionary:
	var v: Variant = str_to_var(str(head.get("state", "")))
	if v is Dictionary:
		var d: Dictionary = v
		return d
	return { }

## apply one recorded step to s; events, or null when the rules refused it
static func apply(s: Dictionary, step: Dictionary) -> Variant:
	var kind: String = step.get("kind", "")
	if kind == "end":
		return Game.end_turn(s)
	if kind == "surrender":
		var side: String = step.get("side", "")
		if side != "p" and side != "e":
			return null
		return Objectives.surrender(s, side)
	if kind == "unbuy":
		var id: int = step.id
		if Game.unbuy(s, id):
			return []
		return null
	if (kind == "buy" or kind == "act") and AIPlan.legal(s, step): # legal first: refused steps must not push_error
		return AI.apply_step(s, step)
	return null
