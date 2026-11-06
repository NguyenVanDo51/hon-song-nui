extends SceneTree
## drives the human click path through the real UI (no bot). run with -- mission=m02 fresh nointro

var main: Node
var fails := 0

func _init() -> void:
	Store.use_profile("driver") # never touch the player's save / progress / settings
	Store.board3d_flag = 0 # this driver walks the 2D board
	main = load("res://main.tscn").instantiate()
	main.flags["nozoom"] = "1"
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
	press("✖ Hủy")
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
	var dest_r := Rect2(g.board.position + Vector2(dest.x * T, dest.y * T), Vector2(T, T))
	ok(not Rect2(g._pop.position, g._pop.size).intersects(dest_r.grow(-2)), "popup does not cover the destination tile")
	g._on_tile(dest.x, dest.y) # same tile again = default action (wait here)
	await idle(g)
	ok(hero.acted and hero.x == dest.x, "hero moved + waited (click dest twice)")
	g.select_next()
	ok(g.ui.sel != null and g.ui.sel != hero.id, "Tab selects next unacted unit")
	g.cancel()
	# empty terrain tile: 1st click = its card (HUD hidden), same tile again = close card, HUD back
	var plain: Vector2i = Vector2i(-1, -1)
	for ty in s.h:
		for tx in s.w:
			if plain.x < 0 and Game.unit_at(s, tx, ty) == null and Game.buy_options(s, "p", tx, ty).is_empty():
				plain = Vector2i(tx, ty)
	g._on_tile(plain.x, plain.y)
	await process_frame
	ok(g.ui.info != null and g._card.visible and g._btn_end.is_visible_in_tree(), "terrain click shows its card, end-turn stays")
	g._on_tile(plain.x, plain.y)
	await process_frame
	ok(g.ui.info == null and not g._card.visible and g._btn_end.is_visible_in_tree(), "same terrain tile again closes card")
	g._on_tile(hero.x, hero.y)
	await process_frame
	ok(g._card.visible and not g._btn_end.is_visible_in_tree(), "unit picked: only its card, end-turn hidden")
	g.cancel()
	# buy at our castle (1,2)
	g._on_tile(1, 2)
	await process_frame
	ok(g.ui.buyAt != null, "castle click opens buy panel")
	var gold0: int = s.gold.p
	press("", g._actions) # first enabled buy button
	await process_frame
	ok(s.gold.p < gold0, "bought a unit (%d -> %d)" % [gold0, s.gold.p])
	# AE2: our castle with an ACTED unit of ours on it still opens the shop
	var newu: Variant = Game.unit_at(s, 1, 2)
	if newu != null:
		newu.acted = true
		g.cancel()
		g._on_tile(1, 2)
		await process_frame
		ok(g.ui.buyAt == [1, 2] and g.ui.sel == null, "acted unit on our castle: click opens buy panel")
		ok(find_btn(g._actions, "") != null, "buy panel shows buttons")
		newu.acted = false
		g.cancel()
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
	press("⚔ Đánh")
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
	g._gear.pressed.emit()
	await process_frame
	ok(g._menu.visible, "⚙ opens the menu")
	g._on_tile_clicked(0, 0)
	ok(not g._menu.visible, "a map click closes the menu")
	g._on_tile(foe2.x, foe2.y)
	await idle(g)
	ok(arch.acted and (foe2.hp < hp1 or Game.unit_by_id(s, foe2.id) == null), "one click attack after hover")
	g.ui.hover = null
	# terrain info, hint, codex, speed
	g._on_tile(6, 0)
	await process_frame
	ok(g._card.visible and g._card_box.get_child_count() > 0, "terrain info in the corner card")
	g.cancel()
	# ⓘ on a token: unit card with traits + how to play; next click on the board just closes it
	var any_u: Dictionary = s.units.filter(func(u): return u.side == "e")[0]
	g._on_info_requested(any_u.id)
	await process_frame
	ok(g.ui.peek == any_u.id and g._pop.visible and g._info.get_child_count() >= 4, "ⓘ opens the unit card (%d rows)" % g._info.get_child_count())
	g._on_tile_clicked(0, 0)
	ok(g.ui.peek == null, "board click closes the unit card")
	await process_frame
	ok(g.board._info_spots.is_empty(), "no ⓘ dots on the figures (details live in the corner card)")
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
	for i in 5: # a picked unit swaps the HUD for its card: deselect to reach "Hết lượt"
		if g.ui.sel == null:
			break
		g.cancel()
	ok(g._btn_end.visible and not g._card.visible, "nothing picked -> HUD back, card gone")
	press("Hết lượt")
	var low := 1 << 30
	for i in 1200:
		if s.side == "p" and not g.ui.busy:
			break
		if s.side == "p":
			low = mini(low, int(g._gold_num.text))
		await process_frame
	ok(s.side == "p" and s.turn == 2, "enemy turn played, turn 2 (turn %d)" % s.turn)
	# turn-start income: the total counts up (shown below the real total for a while), then lands on it
	for i in 200:
		low = mini(low, int(g._gold_num.text))
		if g._gold_shown < 0 and i > 5:
			break
		await process_frame
	ok(Game.income(s, "p") == 0 or low < s.gold.p, "gold counts up at turn start (lowest shown %d, total %d)" % [low, s.gold.p])
	ok(int(g._gold_num.text) == s.gold.p, "gold count-up ends on the real total")
	# buy on top of a unit standing on our castle; click its own tile = keep, click outside its reach = take back (refund)
	var cas: Vector2i = Game.castle_tiles(s, "p")[0]
	var moved := {}
	for u: Dictionary in s.units: # clear the castle, then park exactly one of ours on it
		if u.x == cas.x and u.y == cas.y:
			moved[u.id] = Vector2i(u.x, u.y)
			u.x = -10 - u.id
	var on: Dictionary = s.units.filter(func(u): return u.side == "p" and u.type != "hero" and u.x >= 0)[0]
	moved[on.id] = Vector2i(on.x, on.y)
	on.x = cas.x; on.y = cas.y
	s.gold.p += 500
	var g0: int = s.gold.p
	var n0: int = s.units.size()
	g._clear_sel(); g.ui.buyAt = [cas.x, cas.y]; g.refresh()
	g.buy_unit("soldier")
	var nb: Dictionary = s.units[-1]
	ok(s.units.size() == n0 + 1 and g.ui.sel == nb.id and Game.can_unbuy(s, nb), "stacked buy selects the new unit")
	g._on_tile_clicked(cas.x, cas.y)
	ok(Game.unit_by_id(s, nb.id) != null, "clicking the castle tile itself keeps the buy")
	for i in 5:
		if g.ui.sel == nb.id:
			break
		g.cancel()
	g._on_tile_clicked(s.w - 1, s.h - 1)
	ok(Game.unit_by_id(s, nb.id) == null and s.gold.p == g0 and s.units.size() == n0, "click outside reach takes the buy back, full refund")
	for u: Dictionary in s.units:
		if moved.has(u.id):
			u.x = moved[u.id].x; u.y = moved[u.id].y
	s.gold.p -= 500
	g._clear_sel(); g.refresh()
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
