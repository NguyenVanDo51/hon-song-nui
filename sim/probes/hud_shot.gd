extends "res://sim/probes/probe_base.gd"
## HUD layout check: idle HUD, then a unit picked near the top-left (card must jump right), then one elsewhere; then the quest
## slip: collapsed, open, covered by a unit (faded), hidden on pick, ✓ stamp, end card quest row.
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
	g.hud.show_menu(true)
	await _wait(4)
	await main.shot(tag + "_menu")
	g.hud.show_menu(false)
	# park our commander on the top-left tile, then pick it
	var h: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "p" and u.type == "hero",
	)[0]
	for y in 2:
		for x in 2:
			if Game.unit_at(s, x, y) == null and h.x + h.y > 1:
				h.x = x
				h.y = y
	g.refresh()
	g._on_tile(pos(h).x, pos(h).y)
	await _wait(4)
	print("TL pick: card at ", g.hud.card.position, " end visible ", g.hud.btn_end.visible)
	await main.shot(tag + "_pick_tl")
	g.cancel()
	g.cancel()
	var far: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "p" and u.id != h.id,
	)[0]
	far.x = s.w - 1
	far.y = 0
	g.refresh()
	g._on_tile(pos(far).x, pos(far).y)
	await _wait(4)
	print("TR pick: card at ", g.hud.card.position)
	await main.shot(tag + "_pick_tr")
	while g.ui.sel != null:
		g.cancel()
	await _wait(4)
	await main.shot(tag + "_back")
	await _quest_shots(g, tag)
	quit()

## quest slip (synthetic list, m02 ships none): collapsed, open, covered by a unit, hidden on pick, stamp, end card row
func _quest_shots(g: GameScreen, tag: String) -> void:
	var s: Dictionary = g.s
	var def := { "quests": [{ "do": "move", "what": "hero" }, { "do": "capture", "what": "v" }, { "do": "buy", "what": "archer" }] }
	Quests.init_state(s, def)
	var qs: Array = s.quests
	qs[0].done = true
	g.hud.quests.bind(s, "")
	var qp := g.hud.quests
	g.refresh()
	await _wait(4) # slip laid out at its collapsed size before finding the tiles under it
	var under: Array[Vector2i] = []
	var h: int = s.h
	var w: int = s.w
	for y in h:
		for x in w:
			var r: Rect2 = g.board.tile_rect(x, y)
			r.position += g.hud.map_wrap.position
			if r.grow(-r.size.x * 0.15).intersects(qp.get_rect()):
				under.append(Vector2i(x, y))
	for u: Dictionary in units_of(s): # nothing under the slip yet
		if under.has(pos(u)):
			u.x = 0
			u.y = h - 1
	g.refresh()
	await create_timer(0.3).timeout # fade back in after the earlier shots
	var tc: Control = g.hud.turn_label.get_parent()
	var top_r: Control = g.hud.hud_tr
	print("QUEST slip ", qp.get_rect(), " tc ", Rect2(tc.position, tc.size), " tr ", Rect2(top_r.position, top_r.size))
	print("QUEST overlap_tc=", qp.get_rect().intersects(Rect2(tc.position, tc.size)), " below_tr=", qp.position.y >= top_r.get_rect().end.y)
	print("QUEST tiles under slip ", under.size(), " covered=", qp.covered, " a=", qp.modulate.a)
	await main.shot(tag + "_q_idle")
	qp._on_input(_press())
	await _wait(6)
	print("QUEST open ", qp.open, " rect ", qp.get_rect())
	await main.shot(tag + "_q_open")
	qp._on_input(_press())
	await _wait(4)
	var foe: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "e",
	)[0]
	if not under.is_empty():
		foe.x = under[0].x
		foe.y = under[0].y
	g.refresh()
	await create_timer(0.3).timeout
	print("QUEST cover: unit at ", pos(foe), " covered=", qp.covered, " a=", qp.modulate.a, " filter=", qp._slip.mouse_filter)
	await main.shot(tag + "_q_cover")
	var mine: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "p" and not u.acted,
	)[0]
	g._on_tile(pos(mine).x, pos(mine).y)
	await _wait(4)
	print("QUEST pick: slip visible=", qp.visible, " end visible=", g.hud.btn_end.visible)
	await main.shot(tag + "_q_pick")
	while g.ui.sel != null:
		g.cancel()
	foe.x = 0
	foe.y = h - 1
	g.refresh()
	qs[1].done = true
	qp.celebrate([1])
	await create_timer(0.45).timeout
	await main.shot(tag + "_q_stamp")
	await create_timer(0.75).timeout
	await main.shot(tag + "_q_land")
	await create_timer(1.0).timeout
	print("QUEST after stamp: busy=", qp._busy, " done=", Quests.done_count(s), "/", Quests.total(s))
	await main.shot(tag + "_q_after")
	s.winner = "p"
	s.reason = "castles"
	g.turns.finish()
	await create_timer(2.5).timeout
	print("QUEST end: final stars=", Stars.final(s, g.def), " count=", Stars.count(s, g.def))
	await main.shot(tag + "_q_end")
	# skirmish: no quests, the slip holds the win line only
	var c := { "kind": "skirmish", "hero": Content.heroes_of("p")[0], "easy": true, "map": "dong_bang", "gold": 300, "cap": 15 }
	main.start_game(Game.new_game(g._def_for(c)), c)
	await create_timer(1.5).timeout
	print("QUEST skirmish: has quests=", g.s.has("quests"), " pill=", qp._pill.visible)
	await main.shot(tag + "_q_skirmish")

static func _press() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e
