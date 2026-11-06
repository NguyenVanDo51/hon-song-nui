extends "res://sim/probes/probe_base.gd"
## plays every rigged unit's attack once per side and direction through the real path (FX.rig_attack on the 2D board),
## then checks: on_hit fired exactly once, the attack ended, its sparks drained. Any SCRIPT ERROR lands in the .err log.
##   MAX_SEC=300 tools/run_guarded.sh /tmp/rig_smoke.log -- --headless --path . -s sim/probes/rig_smoke.gd \
##       -- mission=m02 fresh nointro nobattle profile=test speed=3
##   grep -c "SCRIPT ERROR" /tmp/rig_smoke.log.err   # must be 0;  log ends with "RIG SMOKE DONE fails=0"
var fails := 0

func _initialize() -> void:
	boot_wait = 1.0
	super()

func _run(g: GameScreen) -> void:
	var s: Dictionary = g.s
	if not (g.board is Board):
		print("RIG SMOKE: board is not the 2D Board, nothing to test")
		quit(1)
		return
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-2, 1)]
	var w: int = s.w
	var h: int = s.h
	@warning_ignore("integer_division")
	var ax := Vector2i(w / 2 - 1, h / 2)
	var p_any: Dictionary = units_of(s).filter(func(u: Dictionary) -> bool: return u.side == "p")[0]
	var e_any: Dictionary = units_of(s).filter(func(u: Dictionary) -> bool: return u.side == "e")[0]
	clear_around(s, ax, 4, [p_any.id, e_any.id])
	var n := 0
	for type: String in Rigs.types():
		for side: String in ["p", "e"]:
			if not Rigs.has(type, side):
				print("  skip %s/%s: no data" % [type, side])
				continue
			var a: Dictionary = p_any if side == "p" else e_any
			var d: Dictionary = e_any if side == "p" else p_any
			for dv: Vector2i in dirs:
				var r := Rigs.make(type, side)
				a.type = type
				d.type = "soldier"
				a.x = ax.x; a.y = ax.y
				d.x = ax.x + dv.x; d.y = ax.y + dv.y
				g.refresh()
				var hits := [0]
				var t0 := Time.get_ticks_msec()
				await g.fx.rig_attack(g.board, r, { "x": a.x, "y": a.y, "id": a.id, "type": type, "side": side },
					{ "x": d.x, "y": d.y, "id": d.id, "type": d.type }, 37, { "kill": false, "counter": dv.x < 0,
					"on_hit": func() -> void: hits[0] += 1 })
				var ms := Time.get_ticks_msec() - t0
				var ok: bool = hits[0] == 1 and not r.playing and r.hit_t >= 0.0
				if not ok:
					fails += 1
				n += 1
				print("  %s %s/%s dir %s: %d ms, on_hit x%d, HIT at %d ms" % ["ok  " if ok else "FAIL", type, side, dv, ms, hits[0], int(r.hit_t)])
	# leftover fx must drain
	var w0 := Time.get_ticks_msec()
	while not g.fx.rigs.is_empty() and Time.get_ticks_msec() - w0 < 4000:
		await process_frame
	if not g.fx.rigs.is_empty():
		fails += 1
		print("  FAIL rigs not drained: %d" % g.fx.rigs.size())
	print("RIG SMOKE DONE attacks=%d fails=%d" % [n, fails])
	quit(1 if fails else 0)
