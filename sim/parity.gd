extends RefCounted
## chapter-1 parity player: same seeds, RNG and trace format as the JS original's trace (sim/trace_js.cjs).
## Used by sim/trace.gd (full run) and sim/tests.gd (a few golden games). apply() swaps in the frozen rules + seeded rng.

const LEGACY_RULES := preload("res://sim/legacy/rules.gd")
var _old_rng: Callable

func apply() -> void:
	_old_rng = AI.rng
	AI.rng = rng
	Game.use_tables(LEGACY_RULES.UNITS, LEGACY_RULES.HEROES, LEGACY_RULES.RULES, LEGACY_RULES.TERRAIN)

func restore() -> void:
	AI.rng = _old_rng
	Game.use_tables(Rules.UNITS, Rules.HEROES, Rules.RULES, Rules.TERRAIN)

## [name, games, def_for(game), naive]
func runs() -> Array:
	var out := []
	for i in range(1, 9):
		var m: Dictionary = load("res://sim/legacy/m%02d.gd" % i).DEF
		out.append([m.id, 20, func(_g: int) -> Dictionary: return m, false])
	var heroes := ["trungtrac", "trungnhi", "lechan"]
	out.append(["skirmish", 12, func(g: int) -> Dictionary: return _legacy_skirmish(heroes[g % 3], false), false])
	out.append(["skirmish-easy", 12, func(g: int) -> Dictionary: return _legacy_skirmish(heroes[g % 3], true), false])
	out.append(["naive", 10, func(_g: int) -> Dictionary: return _legacy_skirmish(heroes[0], false), true])
	return out

## one game, keyed like the golden file ("m01 0") -> its trace line
func replay(key: String) -> String:
	var p := key.split(" ")
	for r: Array in runs():
		if r[0] == p[0]:
			var g := int(p[1])
			seed_v = 1000.0 + g * 7919
			return play(r[2].call(g), r[3])
	return "?"

var seed_v := 1.0

func rng() -> float:
	seed_v = fmod(seed_v * 1103515245.0 + 12345.0, 2147483648.0)
	return seed_v / 2147483648.0

static func fnv(h: int, s: String) -> int:
	for c in s.to_ascii_buffer():
		h = ((h ^ c) * 16777619) & 0xFFFFFFFF
	return h

static func step_str(st: Variant) -> String:
	if st == null:
		return "E"
	if st.kind == "buy":
		return "b%d,%d:%s" % [st.x, st.y, st.type]
	var a: Dictionary = st.act
	var t := ""
	if a.get("target") != null:
		t = "%d,%d" % [a.target[0], a.target[1]] if a.target is Array else str(a.target)
	return "a%d>%d,%d:%s:%s" % [a.id, a.to[0], a.to[1], a.kind, t]

func play(def: Dictionary, naive: bool) -> String:
	var s := Game.new_game(def)
	var mem := {}
	var steps := 0
	var h := 2166136261
	while s.winner == null and s.turn <= 60:
		var step: Variant = AI.random_step(s, rng) if naive and s.side == "p" else AI.next_step(s, mem)
		h = fnv(h, step_str(step) + ";")
		if step == null:
			Game.end_turn(s)
			mem = {}
			continue
		AI.apply_step(s, step)
		steps += 1
	for u: Dictionary in s.units:
		h = fnv(h, "%d:%d,%d:%d:%d:%d;" % [u.id, u.x, u.y, u.hp, u.xp, u.rank])
	h = fnv(h, "g%d,%d" % [s.gold.p, s.gold.e])
	return "%s %s t%d n%d %x" % [s.winner if s.winner != null else "draw", s.reason if s.reason != null else "timeout", s.turn, steps, h]

## Content.skirmish_def as it was at the port, on the frozen dong_bang map
static func _legacy_skirmish(hero_key: String, easy: bool) -> Dictionary:
	var m: Dictionary = load("res://sim/legacy/skirmish_maps.gd").MAPS.dong_bang
	return {
		"id": "skirmish:dong_bang", "title": m.name, "hero": hero_key, "enemyHero": "todinh", "chapter": "c1",
		"map": { "rows": m.rows }, "owner": m.owner, "units": m.units,
		"gold": { "p": 300, "e": 150 if easy else 300 }, "incomeMul": { "e": 0.7 if easy else 1 },
		"win": { "type": "castles" }, "skirmish": { "mapId": "dong_bang", "easy": easy },
	}
