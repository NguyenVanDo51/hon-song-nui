extends SceneTree
## parity trace: one line per game = winner, reason, turns, steps, FNV-1a hash of every AI step + final units/gold.
## Same seeds and format as the JS-side trace, so `diff` proves the two engines play identical games.
## <godot> --headless --path . -s sim/trace.gd [-- only=m01,m02,skirmish,skirmish-easy,naive]

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

func _init() -> void:
	AI.rng = rng
	# rules parity with the JS original runs on a frozen copy of its content (sim/legacy: the 8 chapter-1 missions
	# and skirmish map as ported), so later map / hero redesigns in content/ do not touch the check. Rules = live code.
	var runs := []
	for i in range(1, 9):
		var m: Dictionary = load("res://sim/legacy/m%02d.gd" % i).DEF
		runs.append([m.id, 20, func(_g: int) -> Dictionary: return m, false])
	var heroes := ["trungtrac", "trungnhi", "lechan"]
	runs.append(["skirmish", 12, func(g: int) -> Dictionary: return _legacy_skirmish(heroes[g % 3], false), false])
	runs.append(["skirmish-easy", 12, func(g: int) -> Dictionary: return _legacy_skirmish(heroes[g % 3], true), false])
	runs.append(["naive", 10, func(_g: int) -> Dictionary: return _legacy_skirmish(heroes[0], false), true])
	var only := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = Array(a.substr(5).split(","))
	for r: Array in runs:
		if only.size() and not only.has(r[0]):
			continue
		for g in r[1]:
			seed_v = 1000.0 + g * 7919
			print("%s %d %s" % [r[0], g, play(r[2].call(g), r[3])])
	quit()

## Content.skirmish_def as it was at the port, on the frozen dong_bang map
static func _legacy_skirmish(hero_key: String, easy: bool) -> Dictionary:
	var m: Dictionary = load("res://sim/legacy/skirmish_maps.gd").MAPS.dong_bang
	return {
		"id": "skirmish:dong_bang", "title": m.name, "hero": hero_key, "enemyHero": "todinh", "chapter": "c1",
		"map": { "rows": m.rows }, "owner": m.owner, "units": m.units,
		"gold": { "p": 300, "e": 150 if easy else 300 }, "incomeMul": { "e": 0.7 if easy else 1 },
		"win": { "type": "castles" }, "skirmish": { "mapId": "dong_bang", "easy": easy },
	}
