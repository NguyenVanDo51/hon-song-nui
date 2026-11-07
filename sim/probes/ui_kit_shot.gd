extends "res://sim/probes/probe_base.gd"
## UI skin check (fantasy reskin): orders popup, Mộ quân popup, win + lose end cards, new-unit intro card.
##   tools/run_guarded.sh <log> -- --path . -s sim/probes/ui_kit_shot.gd -- mission=m02 fresh nointro profile=test shots=<dir> [win=WxH]

func _boot() -> void:
	var win: String = main.flags.get("win", "")
	if win != "":
		var p := win.split("x")
		DisplayServer.window_set_size(Vector2i(int(p[0]), int(p[1])))
	await super()

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _run(g: GameScreen) -> void:
	timeout_ms = Time.get_ticks_msec() + 40000
	var s: Dictionary = g.s
	var tag: String = args.get("tag", "ui")
	# orders popup: pick our commander, then its own tile (stay = wait / capture choices)
	var h: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "p" and u.type == "hero",
	)[0]
	g._on_tile(pos(h).x, pos(h).y)
	await _wait(3)
	g._on_tile(pos(h).x, pos(h).y)
	await _wait(6)
	await main.shot(tag + "_orders")
	while g.ui.sel != null:
		g.cancel()
	await _wait(3)
	# Mộ quân: an empty castle of ours
	var hh: int = s.h
	var ww: int = s.w
	var own: Dictionary = s.owner
	for y: int in hh:
		for x: int in ww:
			if Game.sells(s.tiles[y][x]) and own.get(Vector2i(x, y)) == "p" and Game.unit_at(s, x, y) == null:
				g._on_tile(x, y)
				await _wait(6)
				await main.shot(tag + "_shop")
				while g.ui.sel != null:
					g.cancel()
				await _wait(3)
				break
	# new-unit intro card
	g.cancel()
	g.cancel()
	g.cards.intro_card(h, 0, 1)
	await _wait(40)
	await main.shot(tag + "_intro")
	# end cards
	if g.cards.intro_layer != null:
		g.cards.intro_layer.queue_free()
		g.cards.intro_layer = null
	var noop := func() -> void:
		pass
	g.cards.show_end(true, "Đã chiếm hết lâu đài và hạ tướng địch.", [["Màn tiếp", noop, true], ["Chơi lại", noop, false]])
	await _wait(30)
	await main.shot(tag + "_win")
	g.cards.show_end(false, "Hiệp Sĩ Chỉ Huy đã ngã.", [["Chơi lại", noop, true], ["Về menu", noop, false]])
	await _wait(30)
	await main.shot(tag + "_lose")
	quit()
