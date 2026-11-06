class_name Objectives
extends RefCounted
## mission win types (def.win.type): one entry each. The AE2 loss rule (Game.loss_reason) always applies on top.
## Entry keys, all optional static funcs:
##   loss(s, side) -> reason | null       checked before the base rule
##   on_round(s) -> [winner, reason] | null   each new round (side "p" to move, s.turn already counted)
##   ai_goals(s, u) -> Array | null        tiles this unit heads for instead of the usual goals
##   ai_tile(s, u, x, y) -> float          extra AI score for ending on (x, y)
##   marks(s) -> Array of [x, y]            goal tiles the board flags
##   bar_n(s) -> int                        {n} in the top-bar goal line (default: enemy units left)
##   check(s) -> String                     content error for a new game ("" = ok), sim/tests.gd
## Wording: content/theme.gd goals[type] (brief / bar), ends[side][reason], text.loseTip_<reason>.

static var TYPES := {
	"castles": { "bar_n": _castles_left },
	"rout": {},
	"hero": { "loss": _hero_loss, "check": _hero_check },
	"survive": { "on_round": _survive_round, "check": _survive_check },
	"reach": { "loss": _reach_loss, "on_round": _reach_round, "ai_goals": _reach_goals, "ai_tile": _reach_tile,
		"marks": _reach_marks, "check": _reach_check },
}

static func has(type: Variant) -> bool:
	return TYPES.has(type)

static func types() -> Array:
	return TYPES.keys()

## the hook `key` of this game's win type, null if it has none
static func hook(s: Dictionary, key: String) -> Variant:
	return TYPES.get(s.win.type, {}).get(key)

static func loss(s: Dictionary, side: String) -> Variant:
	var f: Variant = hook(s, "loss")
	return f.call(s, side) if f != null else null

static func on_round(s: Dictionary) -> Variant:
	var f: Variant = hook(s, "on_round")
	return f.call(s) if f != null else null

static func ai_goals(s: Dictionary, u: Dictionary) -> Variant:
	var f: Variant = hook(s, "ai_goals")
	return f.call(s, u) if f != null else null

static func marks(s: Dictionary) -> Array:
	var f: Variant = hook(s, "marks")
	return f.call(s) if f != null else []

static func bar_n(s: Dictionary) -> int:
	var f: Variant = hook(s, "bar_n")
	return f.call(s) if f != null else Game.unit_count(s, "e")

static func check(s: Dictionary) -> String:
	if not has(s.win.type):
		return "unknown win type " + str(s.win.type)
	var f: Variant = hook(s, "check")
	return f.call(s) if f != null else ""

# ---------- castles ----------
static func _castles_left(s: Dictionary) -> int:
	return Game.castles(s, "e")

# ---------- hero: bring down the enemy commander ----------
static func _hero_loss(s: Dictionary, side: String) -> Variant:
	return "heroKilled" if side == "e" and s.heroDead.e else null

static func _hero_check(s: Dictionary) -> String:
	return "" if s.heroKey.e != null else "hero win needs an enemy commander"

# ---------- survive: hold until win.turns ----------
static func _survive_round(s: Dictionary) -> Variant:
	return ["p", "survived"] if s.turn > s.win.turns else null

static func _survive_check(s: Dictionary) -> String:
	return "" if s.win.get("turns") is int and s.win.turns > 0 else "survive needs turns"

# ---------- reach: our commander to one of win.at (optional win.turns) ----------
static func _reach_loss(s: Dictionary, side: String) -> Variant:
	if side == "e" and Game.hero_on_goal(s):
		return "reached"
	if side == "p" and s.heroDead.p and Game.castles(s, "p") == 0:
		return "heroFell" # reach needs the commander and no castle is left to rebuy it
	return null

static func _reach_round(s: Dictionary) -> Variant:
	return ["e", "timeUp"] if s.win.has("turns") and s.turn > s.win.turns else null

## escape missions: the hero only cares about the goal
static func _reach_goals(s: Dictionary, u: Dictionary) -> Variant:
	return s.win.get("at", []).duplicate() if u.side == "p" and u.type == "hero" else null

static func _reach_tile(s: Dictionary, u: Dictionary, x: int, y: int) -> float:
	var out := 0.0
	if u.side == "p" and u.type == "hero":
		for g: Array in s.win.get("at", []):
			if g[0] == x and g[1] == y:
				# stepping on the goal wins; rebought on it (offGoal) -> must step off first, back next turn
				out += -500.0 if u.get("offGoal", false) else 20000.0
	return out

static func _reach_marks(s: Dictionary) -> Array:
	return s.win.get("at", [])

static func _reach_check(s: Dictionary) -> String:
	if s.win.get("at", []).size() == 0:
		return "reach needs at"
	var hst := Game.stat(s, { "type": "hero", "side": "p" })
	for g: Array in s.win.at:
		if Game.move_cost(hst.move, Game.tile_at(s, g[0], g[1])) == INF:
			return "reach tile %s impassable" % [g]
	return ""
