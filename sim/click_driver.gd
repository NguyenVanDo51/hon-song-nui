extends SceneTree
## drives the human click path through the real UI (no bot). run with -- mission=m02 fresh nointro

var main: Node
var fails := 0

func _init() -> void:
	Store.use_profile("driver") # never touch the player's save / progress / settings
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func ok(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1

func wait(sec: float) -> void:
	await create_timer(sec).timeout

func find_btn(n: Node, text: String) -> Button:
	if n is Button and n.is_visible_in_tree():
		var t: String = n.text
		if n.has_meta("title"):
			t = (n.get_meta("title") as Label).text
		if t.begins_with(text):
			return n
	for c in n.get_children():
		var b := find_btn(c, text)
		if b:
			return b
	return null

func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e

func press(text: String, where: Node = null) -> bool:
	var b := find_btn(where if where else main, text)
	ok(b != null and not b.disabled, "button '%s'" % text)
	if b and not b.disabled:
		b.pressed.emit()
		return true
	return false

func idle(g: Node) -> void:
	for i in 400:
		if not g.ui.busy:
			return
		await process_frame

func _run() -> void:
	FX.speed = 3.0
	await wait(1.0)
	var g = main.game
	var s: Dictionary = g.s
	var hero: Dictionary = s.units.filter(func(u): return u.side == "p" and u.type == "hero")[0]
	# select hero -> reach, hover path
	g._on_tile(hero.x, hero.y)
	ok(g.board.view.reach != null and not g._pop.visible, "select hero shows reach, board stays clear (no popup yet)")
	var dest: Dictionary
	for r in g.board.view.reach.values():
		if (r.x != hero.x or r.y != hero.y) and Game.unit_at(s, r.x, r.y) == null:
			dest = r
	g.ui.hover = Vector2i(dest.x, dest.y)
	g._build_view()
	ok(g.board.view.path != null, "hover draws path")
	g._on_tile(dest.x, dest.y)
	await process_frame
	press("Hủy")
	await process_frame
	g._on_tile(hero.x, hero.y)
	g._on_tile(dest.x, dest.y)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await main.shot("ux_float")
	ok(g._pop.visible and g._actions.get_child_count() >= 2, "popup with orders next to the tile (%d buttons)" % g._actions.get_child_count())
	var T: float = g.board.T
	var tr := Rect2(g.board.position + Vector2(dest.x * T, dest.y * T), Vector2(T, T))
	ok(not Rect2(g._pop.position, g._pop.size).intersects(tr.grow(-2)), "popup does not cover the destination tile")
	g._on_tile(dest.x, dest.y) # same tile again = default action (wait here)
	await idle(g)
	ok(hero.acted and hero.x == dest.x, "hero moved + waited (click dest twice)")
	g.select_next()
	ok(g.ui.sel != null and g.ui.sel != hero.id, "Tab selects next unacted unit")
	g.cancel()
	# buy at our castle (1,2)
	g._on_tile(1, 2)
	await process_frame
	ok(g.ui.buyAt != null, "castle click opens buy panel")
	var gold0: int = s.gold.p
	press("", g._actions) # first enabled buy button
	await process_frame
	ok(s.gold.p < gold0, "bought a unit (%d -> %d)" % [gold0, s.gold.p])
	# attack: bring an enemy soldier next to our soldier, then click it
	var sol: Dictionary = s.units.filter(func(u): return u.side == "p" and u.type == "soldier")[0]
	var foe: Dictionary = s.units.filter(func(u): return u.side == "e" and u.type == "soldier")[0]
	foe.x = sol.x + 1
	foe.y = sol.y
	if Game.unit_at(s, foe.x, foe.y) != foe:
		foe.y = sol.y + 1
		foe.x = sol.x
	g._on_tile(sol.x, sol.y)
	g._on_tile(foe.x, foe.y)
	await process_frame
	ok(g.ui.mode == "target", "click enemy -> target mode with preview")
	var hp0: int = foe.hp
	Store.set_battle_mode("all")
	press("⚔ Đánh")
	var seen := false
	for i in 60:
		await process_frame
		if g.battle.visible:
			seen = true
			break
	ok(seen, "battle scene opens on attack")
	await wait(0.6)
	await main.shot("ux_battle")
	g.battle._gui_input(_click())
	var t0 := Time.get_ticks_msec()
	while g.battle.visible and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	ok(not g.battle.visible and Time.get_ticks_msec() - t0 < 1500, "click skips the battle scene (%d ms)" % (Time.get_ticks_msec() - t0))
	await idle(g)
	ok(foe.hp < hp0 or Game.unit_by_id(s, foe.id) == null, "attack resolved")
	# mouse path: rest the pointer on an enemy -> board shows the forecast -> one click attacks
	var arch: Dictionary = s.units.filter(func(u): return u.side == "p" and u.type == "archer")[0]
	var foe2: Dictionary = s.units.filter(func(u): return u.side == "e" and u.id != foe.id)[0]
	foe2.x = arch.x + 2
	foe2.y = arch.y
	if Game.tile_at(s, foe2.x, foe2.y) == null or Game.unit_at(s, foe2.x, foe2.y) != foe2:
		foe2.x = arch.x
		foe2.y = arch.y - 2
	g._on_tile(arch.x, arch.y)
	g.ui.hover = Vector2i(foe2.x, foe2.y)
	g._hover_at = Time.get_ticks_msec() - 500
	g._build_view()
	ok(g.board.view.preview != null, "hover forecast on board")
	await main.shot("ux_forecast")
	await process_frame
	var hp1: int = foe2.hp
	press("⚔ Luôn") # top-bar toggle cycles Luôn -> Khi ta đánh -> Tắt
	ok(Store.battle_mode() == "mine", "battle toggle: Luôn -> Khi ta đánh")
	press("⚔ Khi ta đánh")
	ok(Store.battle_mode() == "off", "battle toggle: -> Tắt")
	g._on_tile(foe2.x, foe2.y)
	var opened := false
	for i in 20:
		await process_frame
		opened = opened or g.battle.visible
	ok(not opened, "no battle scene when off")
	await idle(g)
	Store.set_battle_mode("all")
	ok(arch.acted and (foe2.hp < hp1 or Game.unit_by_id(s, foe2.id) == null), "one click attack after hover")
	g.ui.hover = null
	# terrain info, hint, codex, speed
	g._on_tile(6, 0)
	await process_frame
	ok(g._info.get_child_count() > 0, "terrain info")
	g.cancel()
	# ⓘ on a token: unit card with traits + how to play; next click on the board just closes it
	var any_u: Dictionary = s.units.filter(func(u): return u.side == "e")[0]
	g._on_info_requested(any_u.id)
	await process_frame
	ok(g.ui.peek == any_u.id and g._pop.visible and g._info.get_child_count() >= 4, "ⓘ opens the unit card (%d rows)" % g._info.get_child_count())
	g._on_tile_clicked(0, 0)
	ok(g.ui.peek == null, "board click closes the unit card")
	await process_frame
	ok(g.board._info_spots.size() == s.units.size(), "every unit has an ⓘ dot (%d/%d)" % [g.board._info_spots.size(), s.units.size()])
	# new-unit intro card (Store untouched: called directly)
	g._intro_card(any_u, 0, 1)
	await process_frame
	ok(g._intro_layer != null and g._intro_layer.is_inside_tree(), "intro card shows")
	await main.shot("ux_intro")
	g._intro_closed.emit()
	for i in 30:
		await process_frame
	ok(g._intro_layer == null, "intro card closes")
	g._on_hint()
	await process_frame
	ok(g.ui.hint != null, "hint shows")
	main.menus.open_codex("e")
	await process_frame
	ok(main.menus.is_codex_open(), "codex opens over game")
	main.menus.close_codex()
	g._on_speed()
	# end turn -> enemy turn -> back to us
	g.cancel()
	press("Hết lượt")
	for i in 1200:
		if s.side == "p" and not g.ui.busy:
			break
		await process_frame
	ok(s.side == "p" and s.turn == 2, "enemy turn played, turn 2 (turn %d)" % s.turn)
	# save -> title -> continue
	g.save()
	main.show_title()
	await wait(0.6)
	press("Đánh tiếp")
	await wait(0.6)
	ok(g.visible and g.s.turn == 2 and g.s.units.size() == s.units.size(), "continue restores the save")
	# win -> next mission -> briefing -> start
	g.s.winner = "p"
	g.s.reason = "castlesLost"
	g.finish()
	await wait(1.5)
	press("Màn tiếp")
	await wait(0.6)
	ok(not g.visible, "end -> next mission briefing")
	press("Xuất quân")
	await wait(0.8)
	ok(g.visible and g.s.scenario == "m03", "briefing starts m03")
	# win, then straight back to the menu inside the end-card pause: the win must still count
	await wait(0.5)
	g.s.winner = "p"
	g.s.reason = "castlesLost"
	g.finish()
	await wait(0.1)
	main.show_title()
	await wait(0.8)
	ok(Store.is_done("m03") and not g._end.visible, "win kept when leaving during the end pause")
	print("DRIVER DONE fails=%d" % fails)
	quit(1 if fails else 0)
