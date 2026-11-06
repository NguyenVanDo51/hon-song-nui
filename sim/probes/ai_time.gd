extends SceneTree
## AI cost per step (AI.next_step wall time), golden seeds: -- [m01,m08,m12] [games=4] -> avg / worst ms per mission
const SimLib := preload("res://sim/sim_lib.gd")
var lib := SimLib.new()

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var ids: Array = Array((args[0] if args.size() > 0 else "m01,m08,m12").split(","))
	var games := int(args[1]) if args.size() > 1 else 4
	AI.rng = lib.rng
	for id: String in ids:
		var ts: Array[int] = []
		for g in games:
			lib.seed_v = 1000.0 + g * 7919
			var def: Dictionary = Content.mission(id)
			var s := Game.new_game(def)
			s.rng = int(lib.seed_v)
			var mem := { }
			while s.winner == null and s.turn <= 60:
				var t0 := Time.get_ticks_usec()
				var step: Variant = AI.next_step(s, mem)
				ts.append(Time.get_ticks_usec() - t0)
				if step == null:
					Game.end_turn(s)
					mem = { }
				else:
					var stp: Dictionary = step
					AI.apply_step(s, stp)
		var sum := 0
		for t in ts:
			sum += t
		print("%s steps %d  avg %.2f ms  worst %.1f ms" % [id, ts.size(), sum / 1000.0 / ts.size(), ts.max() / 1000.0])
	quit()
