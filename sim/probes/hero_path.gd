extends SceneTree
## reach missions: where the AI commander is each turn + its distance to the goal. -- <mission>
const SimLib := preload("res://sim/sim_lib.gd")
var lib := SimLib.new()

func _init() -> void:
	lib.seed_v = 1000.0
	AI.rng = lib.rng
	var def: Dictionary = Content.mission(OS.get_cmdline_user_args()[0])
	var s := Game.new_game(def)
	s.rng = 1000
	var last := [-1]
	var goal: Array = s.win.at
	lib.run_ai(
		s,
		false,
		30,
		func(st: Dictionary) -> void:
			if st.side == "p" and st.turn != last[0]:
				last[0] = st.turn
				var units: Array = st.units
				var h: Array = units.filter(
					func(u: Dictionary) -> bool:
						return u.side == "p" and u.type == "hero",
				)
				if h.size():
					var df := AI.dist_field(st, "foot", goal)
					var hx: int = h[0].x
					var hy: int = h[0].y
					print("t%d hero %d,%d hp%d dist=%s" % [st.turn, hx, hy, h[0].hp, df.get(Vector2i(hx, hy))])
				else:
					print("t%d hero dead" % st.turn),
	)
	print("end ", s.winner, " ", s.reason)
	for row: Array in s.tiles:
		print(" ", "".join(PackedStringArray(row)))
	quit()
