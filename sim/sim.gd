extends SceneTree
## headless balance sim, same output lines as the JS scripts/sim.cjs (so the two can be diffed)
## <godot> --headless --path . -s sim/sim.gd -- mission <id|all> [games]   -> AI plays both sides of a campaign mission
## <godot> --headless --path . -s sim/sim.gd -- skirmish [games] [easy]    -> AI vs AI on the free-play map, heroes rotate
## <godot> --headless --path . -s sim/sim.gd -- naive [games]              -> random bot (p) vs AI (e) on skirmish map
## <godot> --headless --path . -s sim/sim.gd -- rng                        -> first 10 rng values (parity check)

var seed_v := 1.0

func rng() -> float:
	# JS: seed = (seed * 1103515245 + 12345) % 2147483648 in doubles (the product exceeds 2^53, so float math is the spec)
	seed_v = fmod(seed_v * 1103515245.0 + 12345.0, 2147483648.0)
	return seed_v / 2147483648.0

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "mission"
	var a1: String = args[1] if args.size() > 1 else ""
	var a2: String = args[2] if args.size() > 2 else ""
	AI.rng = rng
	var t0 := Time.get_ticks_msec()
	if mode == "rng":
		seed_v = 1000.0
		var out := []
		for i in 10:
			out.append("%.0f" % (rng() * 2147483648.0))
		print(" ".join(out))
	elif mode == "mission":
		var ids := []
		if a1 == "" or a1 == "all":
			for m: Dictionary in Content.campaign():
				ids.append(m.id)
		else:
			ids = [a1]
		for id: String in ids:
			var def: Dictionary = Content.mission(id)
			report("%s %s" % [id, def.title], int(a2) if a2 != "" else 20, func(_g: int) -> Dictionary: return play(def, {}, false))
	elif mode == "skirmish":
		var heroes := Content.heroes_of("p")
		report("skirmish" + (" easy" if a2 == "easy" else ""), int(a1) if a1 != "" else 12,
			func(g: int) -> Dictionary: return play(Content.skirmish_def("dong_bang", heroes[g % 3], a2 == "easy"), {}, false))
	elif mode == "naive":
		report("random vs AI", int(a1) if a1 != "" else 10,
			func(_g: int) -> Dictionary: return play(Content.skirmish_def("dong_bang", Content.heroes_of("p")[0], false), {}, true))
	printerr("wall %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()

func play(def: Dictionary, opts: Dictionary, naive: bool) -> Dictionary:
	var s := Game.new_game(def, opts)
	var mem := {}
	var steps := 0
	while s.winner == null and s.turn <= 60:
		var step: Variant = AI.random_step(s, rng) if naive and s.side == "p" else AI.next_step(s, mem)
		if step == null:
			Game.end_turn(s)
			mem = {}
			continue
		AI.apply_step(s, step)
		steps += 1
		if steps > 30000:
			push_error("stuck")
			break
	return s

func report(label: String, games: int, mk: Callable) -> void:
	var res := { "p": 0, "e": 0, "draw": 0 }
	var turns := []
	var reasons := {}
	for g in games:
		seed_v = 1000.0 + g * 7919
		var s: Dictionary = mk.call(g)
		var w: String = s.winner if s.winner != null else "draw"
		res[w] += 1
		turns.append(s.turn)
		var r: String = s.reason if s.reason != null else "timeout"
		reasons[r] = reasons.get(r, 0) + 1
	turns.sort()
	var rs := []
	for k: String in reasons:
		rs.append('"%s":%d' % [k, reasons[k]])
	print("%s p %d/%d  e %d  draw %d  turns med %d [%d-%d]  {%s}" % [label.rpad(22), res.p, games, res.e, res.draw,
		turns[turns.size() >> 1], turns[0], turns[turns.size() - 1], ",".join(rs)])
