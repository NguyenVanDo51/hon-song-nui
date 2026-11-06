extends SceneTree
## why AI-vs-AI games time out: -- <mission> -> per-10-turn summary (units per side/type, castles, gold, hero alive)
const SimLib := preload("res://sim/sim_lib.gd")
var lib := SimLib.new()

func _init() -> void:
	var mid: String = OS.get_cmdline_user_args()[0]
	AI.rng = lib.rng
	for g in 4:
		lib.seed_v = 1000.0 + g * 7919
		print("--- game ", g)
		play(mid)
	quit()

func play(mid: String) -> void:
	var s := Game.new_game(Content.mission(mid))
	s.rng = int(lib.seed_v)
	var last := [0]
	lib.run_ai(s, false, 60, func(st: Dictionary) -> void:
		if st.turn % 10 == 0 and st.turn != last[0] and st.side == "p":
			last[0] = st.turn
			for side: String in ["p", "e"]:
				var types := {}
				for u: Dictionary in st.units:
					if u.side == side: types[u.type] = types.get(u.type, 0) + 1
				print("t%d %s castles=%d vil=%d gold=%d hero=%s %s" % [st.turn, side, Game.castles(st, side), Game.villages(st, side), st.gold[side], Game.hero_alive(st, side), types]))
	print("end ", s.winner, " ", s.reason, " t", s.turn)
	if s.winner == null:
		var ec: Array = Game.castle_tiles(s, "e")
		for c: Vector2i in ec:
			var on: Variant = Game.unit_at(s, c.x, c.y)
			print(" e castle ", c, " on=", on.type + "/" + on.side if on != null else "-")
		for u: Dictionary in s.units:
			if u.type == "hero":
				var df := AI.dist_field(s, "foot", ec.map(func(c: Vector2i) -> Array: return [c.x, c.y]))
				print(" hero ", u.side, " at ", u.x, ",", u.y, " acted=", u.acted, " dist->ecastle=", df.get(Vector2i(u.x, u.y)), " reach=", Game.reachable(s, u).size())
		for row in s.tiles: print(" ", "".join(row))
