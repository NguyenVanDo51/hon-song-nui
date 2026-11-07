extends SceneTree
## headless balance sim (line starts as the old JS scripts/sim.cjs; + win turns / lost / stars columns for mission stars)
## <godot> --headless --path . -s sim/sim.gd -- mission <id|all> [games]   -> AI plays both sides of a level (Content.levels)
## <godot> --headless --path . -s sim/sim.gd -- skirmish [games] [easy|normal] [map]  -> AI vs AI on a free-play map, heroes rotate
## <godot> --headless --path . -s sim/sim.gd -- naive [games]              -> random bot (p) vs AI (e) on skirmish map
## <godot> --headless --path . -s sim/sim.gd -- rng                        -> first 10 rng values (parity check)

const SimLib := preload("res://sim/sim_lib.gd")
var lib := SimLib.new()

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "mission"
	var a1: String = args[1] if args.size() > 1 else ""
	var a2: String = args[2] if args.size() > 2 else ""
	var a3: String = args[3] if args.size() > 3 else "dong_bang"
	AI.rng = lib.rng
	var t0 := Time.get_ticks_msec()
	if mode == "rng":
		lib.seed_v = 1000.0
		var out := []
		for i in 10:
			out.append("%.0f" % (lib.rng() * 2147483648.0))
		print(" ".join(out))
	elif mode == "mission":
		var ids := []
		if a1 == "" or a1 == "all":
			for m: Dictionary in Content.levels():
				ids.append(m.id)
		else:
			ids = [a1]
		for id: String in ids:
			var def: Dictionary = Content.level(id)
			report(
				"%s %s" % [id, def.title],
				int(a2) if a2 != "" else 20,
				func(_g: int) -> Dictionary:
					return play(def, { }, false),
			)
	elif mode == "skirmish":
		var heroes := Content.heroes_of("p")
		report(
			"skirmish " + a3 + (" easy" if a2 == "easy" else ""),
			int(a1) if a1 != "" else 12,
			func(g: int) -> Dictionary:
				var hero: String = heroes[g % heroes.size()]
				return play(Content.skirmish_def(a3, hero, a2 == "easy"), { }, false),
		)
	elif mode == "naive":
		report(
			"random vs AI",
			int(a1) if a1 != "" else 10,
			func(_g: int) -> Dictionary:
				var hero: String = Content.heroes_of("p")[0]
				return play(Content.skirmish_def("dong_bang", hero, false), { }, true),
		)
	printerr("wall %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()

func play(def: Dictionary, opts: Dictionary, naive: bool) -> Dictionary:
	var s := Game.new_game(def, opts)
	lib.run_ai(s, naive, 60, Callable(), Callable(), 30000)
	return s

func report(label: String, games: int, mk: Callable) -> void:
	var res := { "p": 0, "e": 0, "draw": 0 }
	var turns := []
	var reasons := { }
	var win_lost := [] # p troops lost in p wins (mission stars calibration)
	var hero_ok := 0
	var win_turns := []
	var stars := [0, 0, 0, 0]
	for g in games:
		lib.seed_v = 1000.0 + g * 7919
		var s: Dictionary = mk.call(g)
		var w: String = s.winner if s.winner != null else "draw"
		res[w] += 1
		turns.append(s.turn)
		if w == "p":
			var lost: Dictionary = s.get("lost", { })
			win_lost.append(lost.get("p", 0))
			win_turns.append(s.turn)
			var deaths: Dictionary = s.heroDeaths
			hero_ok += 1 if deaths.p == 0 else 0
		var mdef: Variant = Content.level(str(s.get("scenario", "")))
		if mdef != null:
			var md: Dictionary = mdef
			if md.has("stars"):
				stars[Stars.count(s, md)] += 1
		var r: String = s.reason if s.reason != null else "timeout"
		reasons[r] = reasons.get(r, 0) + 1
	turns.sort()
	var rs := []
	for k: String in reasons:
		rs.append('"%s":%d' % [k, reasons[k]])
	win_lost.sort()
	win_turns.sort()
	var wt_txt := "-" if win_turns.is_empty() else "%d [%d-%d]" % [win_turns[win_turns.size() >> 1], win_turns[0], win_turns.back()]
	var lost_txt := "-" if win_lost.is_empty() else "%d [%d-%d]" % [win_lost[win_lost.size() >> 1], win_lost[0], win_lost.back()]
	print(
		"%s p %d/%d  e %d  draw %d  turns med %d [%d-%d]  {%s}  win: turns med %s, lost med %s, hero ok %d  stars 0-3 %s"
		% [
			label.rpad(22),
			res.p,
			games,
			res.e,
			res.draw,
			turns[turns.size() >> 1],
			turns[0],
			turns[turns.size() - 1],
			",".join(rs),
			wt_txt,
			lost_txt,
			hero_ok,
			stars,
		]
	)
