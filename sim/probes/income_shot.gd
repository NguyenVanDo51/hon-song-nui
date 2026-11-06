extends "res://sim/probes/probe_base.gd"
## turn-start income look: "+N" pops per owned building (over units) + gold total counting up.
##   tools/run_guarded.sh /tmp/inc.log -- --path . -s sim/probes/income_shot.gd -- mission=m02 fresh nointro profile=test shots=<dir>

func _run(g: Node) -> void:
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
	# a hurt unit on one of our buildings: its +hp pops over it, after the coin
	var on_b: Array = s.units.filter(func(u: Dictionary) -> bool: return u.side == "p" and s.owner.get(Vector2i(u.x, u.y)) == "p")
	var hu: Dictionary = on_b[0] if on_b.size() else s.units[0]
	hu.hp = 80
	var t0 := Time.get_ticks_msec()
	g._income_fx()
	g._heal_fx({ "id": hu.id, "amount": 20, "x": hu.x, "y": hu.y })
	for at: int in [150, 330, 550, 800, 1200, 2000, 3000]:
		while Time.get_ticks_msec() - t0 < at:
			await process_frame
		print("t=%d gold=%s hp=%s" % [at, g._gold_num.text, g._hp_count.get(hu.id, hu.hp)])
		await main.shot("inc_%04d" % at)
	print("target=%d pops=%d" % [s.gold.p, g._coins.pops.size()])
	quit()
