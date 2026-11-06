extends SceneTree
## reach missions: where the AI commander is each turn + its distance to the goal. -- <mission>
var seed_v := 1000.0
func rng() -> float:
	seed_v = fmod(seed_v * 1103515245.0 + 12345.0, 2147483648.0)
	return seed_v / 2147483648.0
func _init() -> void:
	AI.rng = rng
	var s := Game.new_game(Content.mission(OS.get_cmdline_user_args()[0]))
	s.rng = 1000
	var mem := {}
	var last := -1
	var goal: Array = s.win.at
	while s.winner == null and s.turn <= 30:
		if s.side == "p" and s.turn != last:
			last = s.turn
			var h: Variant = s.units.filter(func(u: Dictionary) -> bool: return u.side == "p" and u.type == "hero")
			if h.size():
				var df := AI.dist_field(s, "foot", goal)
				print("t%d hero %d,%d hp%d dist=%s" % [s.turn, h[0].x, h[0].y, h[0].hp, df.get(Vector2i(h[0].x, h[0].y))])
			else:
				print("t%d hero dead" % s.turn)
		var st: Variant = AI.next_step(s, mem)
		if st == null:
			Game.end_turn(s); mem = {}; continue
		AI.apply_step(s, st)
	print("end ", s.winner, " ", s.reason)
	for row in s.tiles: print(" ", "".join(row))
	quit()
