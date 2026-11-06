extends "res://sim/sim_lib.gd"
## regression player: seeded AI-vs-AI games on the current rules, one trace line each (sim/golden.txt).
## Used by sim/trace.gd (full run) and sim/tests.gd (a few games). apply() swaps in the seeded AI rng.

var _old_rng: Callable

func apply() -> void:
	_old_rng = AI.rng
	AI.rng = rng

func restore() -> void:
	AI.rng = _old_rng

## [name, games, def_for(game), naive]: every campaign mission + skirmish maps, current rules
func runs() -> Array:
	var out := []
	for m: Dictionary in Content.campaign():
		var md := m
		out.append([md.id, 4, func(_g: int) -> Dictionary: return md, false])
	for id: String in Content.SKIRMISH.MAPS:
		var mid := id
		out.append(["sk_" + id, 4, func(g: int) -> Dictionary: return Content.skirmish_def(mid, "anhhung", g % 2 == 1), false])
	out.append(["naive", 4, func(_g: int) -> Dictionary: return Content.skirmish_def("dong_bang", "anhhung", false), true])
	return out

## one game, keyed like the golden file ("m01 0") -> its trace line
func replay(key: String) -> String:
	var p := key.split(" ")
	for r: Array in runs():
		if r[0] == p[0]:
			var g := int(p[1])
			seed_v = 1000.0 + g * 7919
			var def_for: Callable = r[2]
			var naive: bool = r[3]
			var def: Dictionary = def_for.call(g)
			return play(def, naive)
	return "?"

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
	s.seed = int(seed_v)
	s.rng = int(seed_v) # combat rolls seeded like the AI
	var hh := [2166136261] # FNV-1a over every step (array: the lambda cannot rebind a captured local)
	var steps := run_ai(s, naive, 60, Callable(), func(step: Variant) -> void:
		var h0: int = hh[0]
		hh[0] = fnv(h0, step_str(step) + ";"))
	var h: int = hh[0]
	for u: Dictionary in s.units:
		h = fnv(h, "%d:%d,%d:%d:%d:%d;" % [u.id, u.x, u.y, u.hp, u.xp, u.rank])
	h = fnv(h, "g%d,%d" % [s.gold.p, s.gold.e])
	return "%s %s t%d n%d %x" % [s.winner if s.winner != null else "draw", s.reason if s.reason != null else "timeout", s.turn, steps, h]

