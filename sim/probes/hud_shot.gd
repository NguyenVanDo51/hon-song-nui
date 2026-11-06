extends "res://sim/probes/probe_base.gd"
## HUD layout check: idle HUD, then a unit picked near the top-left (card must jump right), then one elsewhere.
##   tools/run_guarded.sh /tmp/hud.log -- --path . -s sim/probes/hud_shot.gd -- mission=m02 fresh nointro profile=test shots=<dir> [win=WxH]

func _boot() -> void:
	var win: String = main.flags.get("win", "")
	if win != "": # before the boot wait, so the game lays out at that size
		var p := win.split("x")
		DisplayServer.window_set_size(Vector2i(int(p[0]), int(p[1])))
	await super()

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _run(g: GameScreen) -> void:
	var s: Dictionary = g.s
	var tag: String = args.get("tag", "hud")
	await main.shot(tag + "_idle")
	# park our commander on the top-left tile, then pick it
	var h: Dictionary = units_of(s).filter(func(u: Dictionary) -> bool: return u.side == "p" and u.type == "hero")[0]
	for y in 2:
		for x in 2:
			if Game.unit_at(s, x, y) == null and h.x + h.y > 1:
				h.x = x; h.y = y
	g.refresh()
	g._on_tile(pos(h).x, pos(h).y)
	await _wait(4)
	print("TL pick: card at ", g._card.position, " end visible ", g._btn_end.visible)
	await main.shot(tag + "_pick_tl")
	g.cancel(); g.cancel()
	var far: Dictionary = units_of(s).filter(func(u: Dictionary) -> bool: return u.side == "p" and u.id != h.id)[0]
	far.x = s.w - 1; far.y = 0
	g.refresh()
	g._on_tile(pos(far).x, pos(far).y)
	await _wait(4)
	print("TR pick: card at ", g._card.position)
	await main.shot(tag + "_pick_tr")
	while g.ui.sel != null:
		g.cancel()
	await _wait(4)
	await main.shot(tag + "_back")
	quit()
