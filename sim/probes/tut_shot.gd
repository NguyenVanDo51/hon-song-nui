extends "res://sim/probes/probe_base.gd"
## tutorial guide shots: t01 step 1 (hero), step 2 (village), step 3 (Hết lượt), ⚙ menu with Bỏ qua; t02 castle, buy button,
## hurt soldier. Prints the hole / hand / bubble rects so overlaps show in the log too.
##   tools/run_guarded.sh /tmp/tut.log -- --path . -s sim/probes/tut_shot.gd -- mission=t01 fresh nointro profile=test shots=<dir> [win=WxH]

func _boot() -> void:
	var win: String = main.flags.get("win", "")
	if win != "":
		var p := win.split("x")
		DisplayServer.window_set_size(Vector2i(int(p[0]), int(p[1])))
	timeout_ms = Time.get_ticks_msec() + 90000
	await super()

func _shot(g: GameScreen, name: String) -> void:
	for i in 300:
		if g.tutorial.visible and g.tutorial.modulate.a >= 1.0:
			break
		await process_frame
	await create_timer(0.3).timeout
	var t := g.tutorial
	var hand: Control = t.get_child(2)
	var bub: Control = t.get_child(3)
	var hr := Rect2(hand.position, hand.size)
	var br := Rect2(bub.position, bub.size)
	var tr0 := t.target_rect()
	print(
		"[tut] %s step %d target %s hand %s bubble %s | hand∩target %s bubble∩target %s bubble∩hand %s"
		% [name, t.step, tr0, hr, br, hr.intersects(tr0.grow(-4)), br.intersects(tr0), br.intersects(hr)]
	)
	await main.shot(str(args.get("tag", "tut")) + "_" + name)

func _run(g: GameScreen) -> void:
	var s: Dictionary = g.s
	var hero: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "p" and u.type == "hero",
	)[0]
	await _shot(g, "t01_s1")
	g._on_tile_clicked(pos(hero).x, pos(hero).y)
	await _shot(g, "t01_s2")
	g._on_tile_clicked(1, 1)
	await _shot(g, "t01_s2b")
	g._on_tile_clicked(1, 1)
	for i in 600:
		if not g.ui.busy:
			break
		await process_frame
	await _shot(g, "t01_s3")
	g.hud.gear.pressed.emit()
	await create_timer(0.3).timeout
	await main.shot(str(args.get("tag", "tut")) + "_menu")
	g.hud.show_menu(false)
	var t02: Dictionary = Content.level("t02")
	main.start_game(Game.new_game(t02), { "kind": "campaign", "id": "t02" })
	await create_timer(0.2).timeout
	await _shot(g, "t02_s1")
	g._on_tile_clicked(1, 4)
	await create_timer(0.3).timeout
	await _shot(g, "t02_buy")
	g.buy_unit("soldier")
	await _shot(g, "t02_s2")
	quit()
