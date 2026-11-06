extends SceneTree
## why AI-vs-AI games time out: -- <mission> -> per-10-turn summary (units per side/type, castles, gold, hero alive)
var seed_v := 1.0
func rng() -> float:
	seed_v = fmod(seed_v * 1103515245.0 + 12345.0, 2147483648.0)
	return seed_v / 2147483648.0

func _init() -> void:
	var mid: String = OS.get_cmdline_user_args()[0]
	AI.rng = rng
	for g in 4:
		seed_v = 1000.0 + g * 7919
		print("--- game ", g)
		play(mid)
	quit()

func play(mid: String) -> void:
	var s := Game.new_game(Content.mission(mid))
	s.rng = int(seed_v)
	var mem := {}
	var last := 0
	while s.winner == null and s.turn <= 60:
		if s.turn % 10 == 0 and s.turn != last and s.side == "p":
			last = s.turn
			for side: String in ["p", "e"]:
				var types := {}
				for u: Dictionary in s.units:
					if u.side == side: types[u.type] = types.get(u.type, 0) + 1
				print("t%d %s castles=%d vil=%d gold=%d hero=%s %s" % [s.turn, side, Game.castles(s, side), Game.villages(s, side), s.gold[side], Game.hero_alive(s, side), types])
		var st: Variant = AI.next_step(s, mem)
		if st == null:
			Game.end_turn(s); mem = {}; continue
		AI.apply_step(s, st)
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
