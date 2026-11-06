extends SceneTree
## turn-start income look: "+N" pops per owned building (over units) + gold total counting up.
##   tools/run_guarded.sh /tmp/inc.log -- --path . -s sim/probes/income_shot.gd -- mission=m02 fresh nointro profile=test shots=<dir>
var main: Node
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func _run() -> void:
	await create_timer(1.5).timeout
	var g: Node = main.game
	var s: Dictionary = g.s
	# hand us every building on the left half so several pop (one under a unit)
	for y in s.h:
		for x in s.w / 2:
			if s.tiles[y][x] in ["v", "c"]:
				s.owner[Vector2i(x, y)] = "p"
	var inc: int = Game.income(s, "p")
	s.gold.p += inc
	g._gold_shown = s.gold.p - inc
	g.refresh()
	var t0 := Time.get_ticks_msec()
	g._income_fx()
	for at: int in [150, 330, 550, 800, 1200, 2000, 3000]:
		while Time.get_ticks_msec() - t0 < at:
			await process_frame
		print("t=%d gold=%s" % [at, g._gold_num.text])
		await main.shot("inc_%04d" % at)
	print("target=%d pops=%d" % [s.gold.p, g._coins.pops.size()])
	quit()
