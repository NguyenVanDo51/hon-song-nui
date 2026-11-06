extends "res://sim/probes/probe_base.gd"
## look check: enemy threat zone (archer / catapult / dragon picked), win card stars (late = 1 star), campaign map stars.
##   tools/run_guarded.sh /tmp/st.log -- --path . -s sim/probes/stars_threat_shot.gd -- mission=m02 fresh nointro profile=test shots=<dir>

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _pick_enemy(g: GameScreen, type: String, x: int, y: int, tag: String) -> void:
	var s: Dictionary = g.s
	var found := units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "e" and u.type == type,
	)
	var e: Variant = found.front() if found.size() else null
	if e == null:
		units_of(s).append({ "id": s.nextId, "side": "e", "type": type, "x": x, "y": y, "hp": 100, "xp": 0, "rank": 0, "acted": false })
		s.nextId += 1
		e = units_of(s).back()
	else:
		e.x = x
		e.y = y
	while g.ui.sel != null:
		g.cancel()
	g.refresh()
	g._on_tile(x, y)
	await _wait(6)
	var th: Variant = g.board.view.threat
	var n := -1
	if th != null:
		var thd: Dictionary = th
		n = thd.size()
	print("%s: threat %d tiles, danger %s" % [tag, n, g.board.view.danger])
	await main.shot(tag)

func _run(g: GameScreen) -> void:
	var s: Dictionary = g.s
	var w: int = s.w
	var h: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "p" and u.type == "hero",
	)[0]
	var hx: int = h.x
	var hy: int = h.y
	await _pick_enemy(g, "archer", mini(hx + 5, w - 1), hy, "threat_archer")
	await _pick_enemy(g, "catapult", mini(hx + 4, w - 1), maxi(hy - 1, 0), "threat_catapult")
	await _pick_enemy(g, "bird", mini(hx + 6, w - 1), hy, "threat_bird")
	while g.ui.sel != null:
		g.cancel()
	# win card: on par, commander alive, then campaign map with the stars kept
	s.winner = "p"
	s.reason = "castlesLost"
	var bar: Dictionary = g.def.stars
	s.turn = bar.get("turns", s.turn)
	if args.has("late"): # 1 star: a turn late + the commander fell once
		s.turn += 1
		s.heroDeaths.p = 1
	g.turns.finish()
	await create_timer(2.6).timeout
	await main.shot("end_win")
	main.show_campaign("c1")
	await _wait(8)
	var cm: Node = _find(root, "CampMap")
	if cm != null:
		cm.set("hover", str(g.ctx.id))
		await _wait(4)
	await main.shot("camp_map")
	quit()

func _find(n: Node, cls: String) -> Node:
	var sc: Script = n.get_script()
	if sc != null and sc.get_global_name() == cls:
		return n
	for c in n.get_children():
		var f := _find(c, cls)
		if f != null:
			return f
	return null
