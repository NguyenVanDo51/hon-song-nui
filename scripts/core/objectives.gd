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
	"rout": { "bar_n": _rout_left },
	"hero": { "loss": _hero_loss, "check": _hero_check },
	"survive": { "on_round": _survive_round, "check": _survive_check },
	"reach": {
		"loss": _reach_loss,
		"on_round": _reach_round,
		"ai_goals": _reach_goals,
		"ai_tile": _reach_tile,
		"marks": _reach_marks,
		"check": _reach_check,
	},
}

static func has(type: Variant) -> bool:
	return TYPES.has(type)

static func types() -> Array:
	return TYPES.keys()

## the hook `key` of this game's win type, null if it has none
static func hook(s: Dictionary, key: String) -> Variant:
	var entry: Dictionary = TYPES.get(s.win.type, { })
	return entry.get(key)

static func loss(s: Dictionary, side: String) -> Variant:
	var f: Variant = hook(s, "loss")
	if f == null:
		return null
	var c: Callable = f
	return c.call(s, side)

static func on_round(s: Dictionary) -> Variant:
	var f: Variant = hook(s, "on_round")
	if f == null:
		return null
	var c: Callable = f
	return c.call(s)

static func ai_goals(s: Dictionary, u: Dictionary) -> Variant:
	var f: Variant = hook(s, "ai_goals")
	if f == null:
		return null
	var c: Callable = f
	return c.call(s, u)

static func marks(s: Dictionary) -> Array:
	var f: Variant = hook(s, "marks")
	if f == null:
		return []
	var c: Callable = f
	return c.call(s)

static func bar_n(s: Dictionary) -> int:
	var f: Variant = hook(s, "bar_n")
	if f == null:
		return Game.unit_count(s, "e")
	var c: Callable = f
	return c.call(s)

static func check(s: Dictionary) -> String:
	if not has(s.win.type):
		return "unknown win type " + str(s.win.type)
	var f: Variant = hook(s, "check")
	if f == null:
		return ""
	var c: Callable = f
	return c.call(s)

# ---------- castles ----------
static func _castles_left(s: Dictionary) -> int:
	return Game.castles(s, "e")

# ---------- rout ----------
## enemies on the board + those still to arrive by wave (t01 starts with none on the board)
static func _rout_left(s: Dictionary) -> int:
	var n := Game.unit_count(s, "e")
	for w: Dictionary in s.waves:
		if not w.done:
			var wu: Array = w.units
			n += wu.size()
	return n

# ---------- hero: bring down the enemy commander ----------
static func _hero_loss(s: Dictionary, side: String) -> Variant:
	if side == "e" and s.heroDead.e:
		return "heroKilled"
	return null

static func _hero_check(s: Dictionary) -> String:
	return "" if s.heroKey.e != null else "hero win needs an enemy commander"

# ---------- survive: hold until win.turns ----------
static func _survive_round(s: Dictionary) -> Variant:
	if s.turn > s.win.turns:
		return ["p", "survived"]
	return null

static func _survive_check(s: Dictionary) -> String:
	var win: Dictionary = s.win
	return "" if win.get("turns") is int and win.turns > 0 else "survive needs turns"

# ---------- reach: our commander to one of win.at (optional win.turns) ----------
static func _reach_loss(s: Dictionary, side: String) -> Variant:
	if side == "e" and Game.hero_on_goal(s):
		return "reached"
	if side == "p" and s.heroDead.p and Game.castles(s, "p") == 0:
		return "heroFell" # reach needs the commander and no castle is left to rebuy it
	return null

static func _reach_round(s: Dictionary) -> Variant:
	var win: Dictionary = s.win
	if win.has("turns") and s.turn > win.turns:
		return ["e", "timeUp"]
	return null

## escape missions: the hero only cares about the goal
static func _reach_goals(s: Dictionary, u: Dictionary) -> Variant:
	if u.side == "p" and u.type == "hero":
		var win: Dictionary = s.win
		var goals: Array = win.get("at", [])
		return goals.duplicate()
	return null

static func _reach_tile(s: Dictionary, u: Dictionary, x: int, y: int) -> float:
	var out := 0.0
	if u.side == "p" and u.type == "hero":
		var win: Dictionary = s.win
		for g: Array in win.get("at", []):
			if g[0] == x and g[1] == y:
				# stepping on the goal wins; rebought on it (offGoal) -> must step off first, back next turn
				out += -500.0 if u.get("offGoal", false) else 20000.0
	return out

static func _reach_marks(s: Dictionary) -> Array:
	var win: Dictionary = s.win
	return win.get("at", [])

static func _reach_check(s: Dictionary) -> String:
	var win: Dictionary = s.win
	var goals: Array = win.get("at", [])
	if goals.size() == 0:
		return "reach needs at"
	var hst := Game.stat(s, { "type": "hero", "side": "p" })
	var mc: String = hst.move
	for g: Array in s.win.at:
		var gx: int = g[0]
		var gy: int = g[1]
		if Game.move_cost(mc, Game.tile_at(s, gx, gy)) == INF:
			return "reach tile %s impassable" % [g]
	return ""
