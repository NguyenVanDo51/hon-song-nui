extends "res://sim/probes/probe_base.gd"
## safe-area check (phone notch / rounded corners): every floating UI piece measured against the inset band of the
## `safe=l,t,r,b` flag (red overlay in the shots) — HUD, ⚙ menu, unit / orders / buy popup in the 4 corners, corner card,
## codex, end card, hotseat handoff, tutorial bubble. Prints "SAFE <name> <rect> ok|IN BAND"; exits 1 if any sits in it.
##   tools/run_guarded.sh /tmp/s.log -- --path . --always-on-top -s sim/probes/safe_shot.gd -- mission=m02 fresh nointro
##     profile=test shots=<dir> shot_every=999 win=1500x675 safe=60,0,60,20

var bad := 0
var _band: Array[Rect2] = []

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
	var e := Style.safe_insets(g)
	var vs := g.get_viewport_rect().size
	_band = [Rect2(0, 0, e.x, vs.y), Rect2(vs.x - e.z, 0, e.z, vs.y), Rect2(0, 0, vs.x, e.y), Rect2(0, vs.y - e.w, vs.x, e.w)]
	_overlay()
	print("SAFE insets %s viewport %s" % [e, vs])
	var s: Dictionary = g.s
	await _wait(4)
	_check("turn/gold", g.hud.turn_label.get_parent() as Control)
	_check("gear", g.hud.hud_tr)
	_check("quests", g.hud.quests)
	_check("end turn", g.hud.btn_end)
	await main.shot("safe_idle")
	g.hud.show_menu(true)
	await _wait(4)
	_check("pause card", g.hud._pause)
	await main.shot("safe_menu")
	g.hud.show_menu(false)
	# unit card popup (ⓘ) for a unit parked in each corner
	var u: Dictionary = units_of(s).filter(
		func(o: Dictionary) -> bool:
			return o.side == "e" and o.type != "hero",
	)[0]
	var w: int = s.w
	var h: int = s.h
	for c: Vector2i in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
		var other: Variant = Game.unit_at(s, c.x, c.y)
		if other != null and other != u:
			continue
		u.x = c.x
		u.y = c.y
		g.refresh()
		var uid: int = u.id
		g._on_info_requested(uid)
		await _wait(6)
		_check("unit popup @%d,%d" % [c.x, c.y], g.panel.pop)
		await main.shot("safe_peek_%d_%d" % [c.x, c.y])
		g._on_tile_clicked(c.x, c.y)
		await _wait(2)
	# buy popup at our castle, terrain + unit corner card
	var cas: Vector2i = Game.castle_tiles(s, "p")[0]
	g._on_tile(cas.x, cas.y)
	await _wait(6)
	_check("buy popup", g.panel.pop)
	await main.shot("safe_buy")
	g.cancel()
	g._on_tile(w - 1, h - 1)
	await _wait(6)
	_check("corner card", g.hud.card)
	g.cancel()
	main.menus.open_codex("p")
	await create_timer(0.6).timeout
	_check("codex", main.menus._codex_card)
	await main.shot("safe_codex")
	main.menus.close_codex()
	s.winner = "p"
	s.reason = "castlesLost"
	g.turns.finish()
	await create_timer(1.5).timeout
	_check("end card", g.cards.end_layer.get_child(1).get_child(0) as Control)
	await main.shot("safe_end")
	# hotseat handoff
	var hp: String = Content.heroes_of("p")[0]
	var he: String = Content.heroes_of("e")[0]
	var dc := { "kind": "duel", "map": "dong_bang", "hero": hp, "heroE": he, "ctrlE": "human", "gold": 300, "cap": 15 }
	main.start_game(Game.new_game(Content.duel_def("dong_bang", hp, he, "human", 300, 15)), dc)
	await create_timer(0.8).timeout
	var ho := g.turns.handoff_layer
	if ho != null:
		_check("handoff card", ho.get_child(1).get_child(0) as Control)
		await main.shot("safe_handoff")
		g.turns.handoff_closed.emit()
	else:
		print("SAFE handoff MISSING")
		bad += 1
	# tutorial bubble (t01 step 1)
	var t01: Dictionary = Content.level("t01")
	main.start_game(Game.new_game(t01), { "kind": "campaign", "id": "t01" })
	await create_timer(1.8).timeout
	_check("tutorial bubble", g.tutorial._bubble)
	await main.shot("safe_tutorial")
	print("SAFE DONE bad=%d" % bad)
	quit(1 if bad else 0)

## screen rect of c (scale included) vs the inset band
func _check(what: String, c: Control) -> void:
	if c == null or not c.is_visible_in_tree():
		print("SAFE %s hidden" % what)
		return
	var r := c.get_global_transform() * Rect2(Vector2.ZERO, c.size)
	var hit := _band.any(
		func(b: Rect2) -> bool:
			return b.has_area() and b.intersects(r),
	)
	print("SAFE %s %s %s" % [what, r, "IN BAND" if hit else "ok"])
	bad += 1 if hit else 0

## red tint over the band so the shots show it
func _overlay() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 120
	root.add_child(cl)
	for b: Rect2 in _band:
		var cr := ColorRect.new()
		cr.color = Color(1, 0, 0, 0.28)
		cr.position = b.position
		cr.size = b.size
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.add_child(cr)
