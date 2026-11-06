class_name Stars
extends RefCounted
## campaign mission stars: 1 won · 2 our commander never fell · 3 the mission's bar, def.stars =
## { "turns": N } (won by round N) or { "lost": K } (at most K of our troops fell; commander + summons not counted).
## Wording: content/theme.gd text.star_*.

const MAX := 3

## the 3 goals of a mission: [{ key, text }]
static func goals(def: Dictionary) -> Array:
	var bar: Dictionary = def.get("stars", { })
	var third := { "key": "turns", "text": Content.text("star_turns").format({ "n": bar.get("turns", 0) }) }
	if not bar.has("turns"):
		var k: int = bar.get("lost", 0)
		third = { "key": "lost", "text": Content.text("star_lost0") if k == 0 else Content.text("star_lost").format({ "n": k }) }
	return [{ "key": "win", "text": Content.text("star_win") }, { "key": "hero", "text": Content.text("star_hero") }, third]

## goals(def) with "ok" for a finished game (all false unless p won) + "have": the number it was judged on
static func check(s: Dictionary, def: Dictionary) -> Array:
	var won: bool = s.winner == "p"
	var deaths: Dictionary = s.get("heroDeaths", { })
	var hd: int = deaths.get("p", 0)
	var lost: Dictionary = s.get("lost", { })
	var nl: int = lost.get("p", 0)
	var bar: Dictionary = def.get("stars", { })
	var out := goals(def)
	for g: Dictionary in out:
		var ok := won
		match g.key:
			"hero":
				ok = won and hd == 0
				g.have = hd
			"turns":
				var n: int = bar.get("turns", 0)
				var t: int = s.turn
				ok = won and t <= n
				g.have = t
			"lost":
				var k: int = bar.get("lost", 0)
				ok = won and nl <= k
				g.have = nl
		g.ok = ok
	return out

static func count(s: Dictionary, def: Dictionary) -> int:
	return check(s, def).filter(
		func(g: Dictionary) -> bool:
			return g.ok,
	).size()

## content error for a campaign mission ("" = ok), sim/tests.gd
static func check_def(def: Dictionary) -> String:
	var bar: Variant = def.get("stars")
	if not bar is Dictionary:
		return "stars: needs { turns: N } or { lost: K }"
	var b: Dictionary = bar
	if not b.has("turns") and not b.has("lost"):
		return "stars: needs { turns: N } or { lost: K }"
	var win: Dictionary = def.get("win", { })
	if b.has("turns"):
		if win.get("type") == "survive":
			return "stars: survive missions end on a fixed round, use { lost: K }"
		var n: int = b.turns
		var limit: int = win.get("turns", 999)
		if n < 1 or n > limit:
			return "stars: turns %d outside 1..%d" % [n, limit]
	return ""
