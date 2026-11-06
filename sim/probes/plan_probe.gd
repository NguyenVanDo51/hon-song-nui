extends SceneTree
## hard v2 planner at work: which candidate wins each plan, replans per turn, and examples where v2's turn differs
## from what hard v1 would do from the same state.
## <godot> --headless --path . -s sim/probes/plan_probe.gd -- [games=1] [salt=9200000] [examples=4]
const HARD_V1 := { "hp_cap": 81.2937, "kill_hero": 552.335 }

var seed_v := 1.0

func _init() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var a_games: String = args.get("games", "1")
	var a_salt: String = args.get("salt", "9200000")
	var a_want: String = args.get("examples", "4")
	var games := int(a_games)
	var salt := int(a_salt)
	var want := int(a_want)
	AI.rng = rng
	var tags := {}
	var plans := 0
	var replans := 0
	var turns := 0
	var shown := 0
	for map_id: String in Content.SKIRMISH.MAPS:
		for v2_side: String in ["p", "e"]:
			for k in games:
				seed_v = 1000.0 + (salt * 64.0 + k) * 7919.0
				var s := Game.new_game(Content.skirmish_def(map_id, "anhhung", false))
				s.rng = int(seed_v)
				s.aiParams = { v2_side: AI.PRESETS.hard, Game.other(v2_side): HARD_V1 }
				var mem := {}
				var turn_start: Dictionary = s.duplicate(true)
				var turn_steps := []
				while s.winner == null and s.turn <= 60:
					var n0: int = mem.get("pl_n", 0)
					var stv: Variant = AI.next_step(s, mem)
					if s.side == v2_side and mem.get("pl_n", 0) != n0:
						plans += 1
						var tag: String = AIPlan.last.tag
						if AIPlan.last.mid:
							replans += 1
						else:
							tag = "first " + tag
						tags[tag] = tags.get(tag, 0) + 1
					if stv == null:
						if s.side == v2_side:
							turns += 1
							if shown < want and _differs(turn_start, turn_steps, v2_side):
								shown += 1
						Game.end_turn(s)
						mem = {}
						turn_start = s.duplicate(true)
						turn_steps = []
						continue
					var st: Dictionary = stv
					turn_steps.append(st)
					AI.apply_step(s, st)
	print("v2 turns %d, plans %d (replans %d)" % [turns, plans, replans])
	var keys := tags.keys()
	keys.sort()
	for t: String in keys:
		print("  %-14s %d" % [t, tags[t]])
	quit()

func rng() -> float:
	seed_v = fmod(seed_v * 1103515245.0 + 12345.0, 2147483648.0)
	return seed_v / 2147483648.0

## v2's turn killed a unit v1 (same start, mid rolls) would not: print both turns
func _differs(start: Dictionary, v2_steps: Array, side: String) -> bool:
	var v1: Dictionary = start.duplicate(true)
	v1.aiParams = { side: HARD_V1 }
	var prev: Callable = AI.rng
	AI.rng = func() -> float: return 0.5
	Game.fixed_roll = 0.5
	var v1_steps := []
	var mem := {}
	for i in 80:
		var stv: Variant = AI.next_step(v1, mem)
		if stv == null:
			break
		var st: Dictionary = stv
		v1_steps.append(st)
		AI.apply_step(v1, st)
	var v2: Dictionary = start.duplicate(true)
	for st: Dictionary in v2_steps:
		if AIPlan.legal(v2, st): # real rolls differ from mid: a later step can be off
			AI.apply_step(v2, st)
	Game.fixed_roll = -1.0
	AI.rng = prev
	var foe := Game.other(side)
	var k1 := _value_left(v1, foe)
	var k2 := _value_left(v2, foe)
	var hero_kill := _hero_dies(v2, foe) and not _hero_dies(v1, foe)
	var held := _held(start, v1, v2, side)
	if not hero_kill and k2 >= k1 - 200.0 and held == "":
		return false
	print("\n== %s turn %d side %s: enemy value left v1 %.0f vs v2 %.0f (mid rolls)%s" % [start.scenario, start.turn, side, k1, k2, held])
	print(" board units: %s" % [_units(start)])
	print(" v1: %s" % [_fmt(start, v1_steps)])
	print(" v2: %s" % [_fmt(start, v2_steps)])
	return true

## an own castle an enemy commander can step on next turn: v2 ends the turn with a unit on it, v1 leaves it empty
func _held(start: Dictionary, v1: Dictionary, v2: Dictionary, side: String) -> String:
	for key: Vector2i in Game.castle_tiles(start, side):
		var near := false
		for e: Dictionary in start.units:
			var ex: int = e.x
			var ey: int = e.y
			if e.side != side and e.type == "hero" and Game.dist(ex, ey, key.x, key.y) <= Game.stat(start, e).mv:
				near = true
		if near and Game.unit_at(v2, key.x, key.y) != null and Game.unit_at(v1, key.x, key.y) == null:
			return "; castle (%d,%d) under enemy commander threat: v2 holds it, v1 leaves it empty" % [key.x, key.y]
	return ""

func _hero_dies(s: Dictionary, foe: String) -> bool:
	return not Game.hero_alive(s, foe)

func _value_left(s: Dictionary, side: String) -> float:
	var v := 0.0
	for u: Dictionary in s.units:
		if u.side == side:
			var hp: float = u.hp
			v += AI.value(s, u) * hp / 100.0
	return v

func _units(s: Dictionary) -> String:
	var out := []
	for u: Dictionary in s.units:
		out.append("%s#%d %s(%d,%d) %dhp" % [u.side, u.id, u.type, u.x, u.y, u.hp])
	return ", ".join(out)

func _fmt(start: Dictionary, steps: Array) -> String:
	var out := []
	for st: Dictionary in steps:
		if st.kind == "buy":
			out.append("buy %s@(%d,%d)" % [st.type, st.x, st.y])
			continue
		var a: Dictionary = st.act
		var aid: int = a.id
		var u: Variant = Game.unit_by_id(start, aid)
		var who: String = u.type if u != null else "new"
		var tail := ""
		if a.kind == "attack":
			var tid: int = a.target
			var t: Variant = Game.unit_by_id(start, tid)
			tail = " #%d %s" % [tid, t.type if t != null else "?"]
		out.append("#%d %s->(%d,%d) %s%s" % [aid, who, a.to[0], a.to[1], a.kind, tail])
	return "; ".join(out)
