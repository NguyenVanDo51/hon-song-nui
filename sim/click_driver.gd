extends SceneTree
## drives the human click path through the real UI (no bot). run with -- mission=m02 fresh nointro

var main: Main
var fails := 0

func _init() -> void:
	Store.use_profile("driver") # never touch the player's save / progress / settings
	var scn: PackedScene = load("res://main.tscn")
	main = scn.instantiate()
	main.flags["nozoom"] = "1"
	root.add_child(main)
	_run.call_deferred()

func ok(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1

## ok() for conditions read off Dictionaries (Variant)
func okv(cond: Variant, msg: String) -> void:
	ok(true if cond else false, msg)

func wait(sec: float) -> void:
	await create_timer(sec).timeout

func find_btn(n: Node, text: String) -> Button:
	var btn := n as Button
	if btn and btn.is_visible_in_tree():
		var t := btn.text
		if btn.has_meta("title"):
			var title: Label = btn.get_meta("title")
			t = title.text
		if t.begins_with(text):
			return btn
	for c: Node in n.get_children():
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

## s.units read fresh (Game swaps the array when a unit dies)
static func units_of(s: Dictionary) -> Array:
	return s.units

## unit tile (read at call time)
static func pos(u: Dictionary) -> Vector2i:
	var x: int = u.x
	var y: int = u.y
	return Vector2i(x, y)

## board, read fresh like g.board
static func board(g: GameScreen) -> Board:
	return g.board

static func id_of(u: Dictionary) -> int:
	return u.id

func idle(g: GameScreen) -> void:
	for i in 400:
		if not g.ui.busy:
			return
		await process_frame

## node carrying meta key = val (menu cards are PanelContainers, not buttons)
func find_meta(n: Node, key: String, val: String) -> Control:
	if n.has_meta(key) and str(n.get_meta(key)) == val:
		return n as Control
	for c: Node in n.get_children():
		var f := find_meta(c, key, val)
		if f:
			return f
	return null

func click_card(key: String, val: String) -> void:
	var card := find_meta(main.menus, key, val)
	ok(card != null, "card %s" % val)
	if card:
		card.gui_input.emit(_click())

## wait until the side to move is `side` and input is open (or frames run out)
func turn_of(g: GameScreen, side: String, frames := 3000) -> bool:
	for i in frames:
		if g.s.side == side and not g.ui.busy and g.turns.handoff_layer == null:
			return true
		await process_frame
	return false

func wait_handoff(g: GameScreen) -> bool:
	for i in 120:
		if g.turns.handoff_layer != null:
			return true
		await process_frame
	return false

## 1 vs 1: two humans on one device (handoff between turns), then a short start against the AI
func _duel(g: GameScreen) -> void:
	var done0: Array = Store.done_list().duplicate()
	press("1 đấu 1")
	await wait(0.6)
	click_card("duel_pick", "p:" + str(Content.heroes_of("p")[0]))
	await process_frame
	click_card("duel_pick", "e:" + str(Content.heroes_of("e")[0]))
	await process_frame
	press("Người")
	await process_frame
	press("Xuất quân")
	await wait(0.8)
	var s: Dictionary = g.s
	var started: bool = g.visible and s.get("ctrl", { }) == { "p": "human", "e": "human" } and s.side == "p"
	ok(started, "1 vs 1 hotseat starts, ctrl %s" % [s.get("ctrl")])
	ok(await wait_handoff(g), "handoff card before Red's first turn")
	press("Bắt đầu lượt")
	ok(await turn_of(g, "p"), "Red to move")
	ok(g.hud.turn_label.text.contains(g._side_name("p")), "HUD names Red's turn (%s)" % g.hud.turn_label.text)
	# P1: hero moves + waits, then ends the turn
	var hero: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "p" and u.type == "hero",
	)[0]
	g._on_tile(pos(hero).x, pos(hero).y)
	var dest := Vector2i(-1, -1)
	var reach: Dictionary = board(g).view.reach
	for r: Dictionary in reach.values():
		if pos(r) != pos(hero) and Game.unit_at(s, pos(r).x, pos(r).y) == null:
			dest = pos(r)
	g._on_tile(dest.x, dest.y)
	g._on_tile(dest.x, dest.y)
	await idle(g)
	var p1_ok: bool = hero.acted and pos(hero) == dest
	ok(p1_ok, "P1 hero moved")
	for i in 5:
		if g.ui.sel == null:
			break
		g.cancel()
	press("Hết lượt")
	ok(await wait_handoff(g), "handoff card after P1 ends the turn")
	var hb := find_btn(g.turns.handoff_layer, "Bắt đầu")
	okv(hb != null and s.side == "e" and not Content.is_ai(s, "e"), "handoff waits for Blue (no AI turn)")
	await main.shot("duel_handoff")
	press("Bắt đầu lượt")
	ok(await turn_of(g, "e"), "Blue to move")
	var gold_ok: bool = int(g.hud.gold_num.text) == s.gold.e or g.hud.gold_shown >= 0
	ok(gold_ok, "HUD shows Blue's gold (%s vs %d)" % [g.hud.gold_num.text, s.gold.e])
	# P2: buy at Blue's castle
	var cas: Vector2i = Game.castle_tiles(s, "e")[0]
	ok(Game.unit_at(s, cas.x, cas.y) == null, "Blue castle free")
	g._on_tile(cas.x, cas.y)
	await process_frame
	okv(g.ui.buyAt == [cas.x, cas.y], "Blue castle opens Blue's shop")
	var ge0: int = s.gold.e
	press("", g.panel.actions)
	await process_frame
	var ge1: int = s.gold.e
	ok(ge1 < ge0, "P2 bought (%d -> %d)" % [ge0, ge1])
	g._clear_sel()
	g.refresh()
	# P2: a Blue soldier attacks a Red unit next to it
	var sol: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "e" and u.type == "soldier" and not u.acted,
	)[0]
	var foe: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "p" and u.type != "hero",
	)[0]
	foe.x = sol.x + 1
	foe.y = sol.y
	if Game.tile_at(s, pos(foe).x, pos(foe).y) == null or Game.unit_at(s, pos(foe).x, pos(foe).y) != foe:
		foe.x = sol.x
		foe.y = sol.y + 1
	g.refresh()
	g._on_tile(pos(sol).x, pos(sol).y)
	g._on_tile(pos(foe).x, pos(foe).y)
	await process_frame
	okv(g.ui.mode == "target", "P2 aims at a Red unit")
	await main.shot("duel_p2_aim")
	var hp0: int = foe.hp
	press("⚔ Đánh")
	await idle(g)
	var hit_ok: bool = foe.hp < hp0 or Game.unit_by_id(s, id_of(foe)) == null
	ok(hit_ok, "P2 attack resolved")
	for i in 5:
		if g.ui.sel == null:
			break
		g.cancel()
	press("Hết lượt")
	ok(await wait_handoff(g), "handoff card after P2")
	press("Bắt đầu lượt")
	var back: bool = await turn_of(g, "p")
	okv(back and s.turn == 2, "turn back to P1, turn %d" % s.turn)
	# save / continue keeps ctrl
	g.save()
	main.show_title()
	await wait(0.6)
	press("Đánh tiếp")
	await wait(0.6)
	var cont_ctrl: Dictionary = g.s.get("ctrl", { })
	okv(g.visible and cont_ctrl == { "p": "human", "e": "human" } and g.s.turn == 2, "continue keeps ctrl")
	ok(await wait_handoff(g), "continued hotseat game opens on the handoff card")
	press("Bắt đầu lượt")
	await process_frame
	# end card: faction wins, no campaign progress
	g.s.winner = "e"
	g.s.reason = "castlesLost"
	g.turns.finish()
	await wait(1.5)
	ok(
		g.cards.end_layer.visible and find_btn(g.cards.end_layer, "Chơi lại") != null and find_btn(g.cards.end_layer, "Về menu") != null,
		"duel end card: Chơi lại / Về menu",
	)
	await main.shot("duel_end")
	ok(Store.done_list() == done0, "duel result leaves campaign progress alone")
	press("Chơi lại")
	await wait(0.8)
	var again_ctrl: Dictionary = g.s.get("ctrl", { })
	okv(g.visible and g.s.turn == 1 and again_ctrl.e == "human", "Chơi lại restarts the duel")
	# vs AI (hard): Red ends the turn -> the AI plays Blue -> back to Red
	main.show_title()
	await wait(0.6)
	press("1 đấu 1")
	await wait(0.6)
	press("Máy Khó")
	await process_frame
	press("Xuất quân")
	await wait(0.8)
	var ai_ctrl: Dictionary = g.s.get("ctrl", { })
	okv(ai_ctrl.e == "ai:hard" and g.turns.handoff_layer == null, "vs AI: Blue = ai:hard, no handoff")
	ok(await turn_of(g, "p"), "vs AI: Red to move")
	press("Hết lượt")
	var ai_back: bool = await turn_of(g, "p")
	okv(ai_back and g.s.turn == 2, "vs AI: AI turn played, back to Red (turn %d)" % g.s.turn)
	main.show_title()
	await wait(0.4)

func _run() -> void:
	FX.speed = 3.0
	await wait(1.0)
	var g: GameScreen = main.game
	var s: Dictionary = g.s
	var hero: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "p" and u.type == "hero",
	)[0]
	# select hero -> reach, hover path
	g._on_tile(pos(hero).x, pos(hero).y)
	ok(board(g).view.reach != null and not g.panel.pop.visible, "select hero shows reach, board stays clear (no popup yet)")
	var dest: Dictionary
	var reach: Dictionary = board(g).view.reach
	for r: Dictionary in reach.values():
		if pos(r) != pos(hero) and Game.unit_at(s, pos(r).x, pos(r).y) == null:
			dest = r
	g.ui.hover = pos(dest)
	g._build_view()
	ok(board(g).view.path != null, "hover draws path")
	g._on_tile(pos(dest).x, pos(dest).y)
	await process_frame
	press("✖ Hủy")
	await process_frame
	g._on_tile(pos(hero).x, pos(hero).y)
	g._on_tile(pos(dest).x, pos(dest).y)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await main.shot("ux_float")
	ok(
		g.panel.pop.visible and g.panel.actions.get_child_count() >= 2,
		"popup with orders next to the tile (%d buttons)" % g.panel.actions.get_child_count(),
	)
	var T: float = board(g).T
	var dest_r := Rect2(board(g).position + Vector2(pos(dest)) * T, Vector2(T, T))
	ok(not Rect2(g.panel.pop.position, g.panel.pop.size).intersects(dest_r.grow(-2)), "popup does not cover the destination tile")
	g._on_tile(pos(dest).x, pos(dest).y) # same tile again = default action (wait here)
	await idle(g)
	var moved_ok: bool = hero.acted and hero.x == dest.x
	ok(moved_ok, "hero moved + waited (click dest twice)")
	g.select_next()
	var next_ok: bool = g.ui.sel != null and g.ui.sel != hero.id
	ok(next_ok, "Tab selects next unacted unit")
	g.cancel()
	# empty terrain tile: 1st click = its card (HUD stays), same tile again = close card
	var plain: Vector2i = Vector2i(-1, -1)
	for ty: int in s.h:
		for tx: int in s.w:
			if plain.x < 0 and Game.unit_at(s, tx, ty) == null and Game.buy_options(s, "p", tx, ty).is_empty():
				plain = Vector2i(tx, ty)
	g._on_tile(plain.x, plain.y)
	await process_frame
	var card_ok: bool = g.ui.info != null and g.hud.card.visible and g.hud.btn_end.is_visible_in_tree()
	ok(card_ok, "terrain click shows its card, end-turn stays")
	g._on_tile(plain.x, plain.y)
	await process_frame
	var closed_ok: bool = g.ui.info == null and not g.hud.card.visible and g.hud.btn_end.is_visible_in_tree()
	ok(closed_ok, "same terrain tile again closes card")
	g._on_tile(pos(hero).x, pos(hero).y)
	await process_frame
	var unit_ok: bool = g.hud.card.visible and not g.hud.btn_end.is_visible_in_tree()
	ok(unit_ok, "unit picked: only its card, end-turn hidden")
	g.cancel()
	# buy at our castle (1,2)
	g._on_tile(1, 2)
	await process_frame
	ok(g.ui.buyAt != null, "castle click opens buy panel")
	var gold0: int = s.gold.p
	press("", g.panel.actions) # first enabled buy button
	await process_frame
	var gold1: int = s.gold.p
	ok(gold1 < gold0, "bought a unit (%d -> %d)" % [gold0, s.gold.p])
	# AE2: our castle with an ACTED unit of ours on it still opens the shop
	var newu: Variant = Game.unit_at(s, 1, 2)
	if newu != null:
		newu.acted = true
		g.cancel()
		g._on_tile(1, 2)
		await process_frame
		var shop_ok: bool = g.ui.buyAt == [1, 2] and g.ui.sel == null
		ok(shop_ok, "acted unit on our castle: click opens buy panel")
		ok(find_btn(g.panel.actions, "") != null, "buy panel shows buttons")
		newu.acted = false
		g.cancel()
	# attack: bring an enemy soldier next to our soldier, then click it
	var sol: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "p" and u.type == "soldier",
	)[0]
	var foe: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "e" and u.type == "soldier",
	)[0]
	foe.x = sol.x + 1
	foe.y = sol.y
	if Game.unit_at(s, pos(foe).x, pos(foe).y) != foe:
		foe.y = sol.y + 1
		foe.x = sol.x
	g._on_tile(pos(sol).x, pos(sol).y)
	g._on_tile(pos(foe).x, pos(foe).y)
	await process_frame
	var target_ok: bool = g.ui.mode == "target"
	ok(target_ok, "click enemy -> target mode with preview")
	var hp0: int = foe.hp
	press("⚔ Đánh")
	await idle(g)
	var hit_ok: bool = foe.hp < hp0 or Game.unit_by_id(s, id_of(foe)) == null
	ok(hit_ok, "attack resolved")
	# mouse path: rest the pointer on an enemy -> board shows the forecast -> one click attacks
	var arch: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "p" and u.type == "archer",
	)[0]
	var foe2: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "e" and u.id != foe.id,
	)[0]
	foe2.x = arch.x + 2
	foe2.y = arch.y
	if Game.tile_at(s, pos(foe2).x, pos(foe2).y) == null or Game.unit_at(s, pos(foe2).x, pos(foe2).y) != foe2:
		foe2.x = arch.x
		foe2.y = arch.y - 2
	g._on_tile(pos(arch).x, pos(arch).y)
	g.ui.hover = pos(foe2)
	g._hover_at = Time.get_ticks_msec() - 500
	g._build_view()
	ok(board(g).view.preview != null, "hover forecast on board")
	await main.shot("ux_forecast")
	await process_frame
	var hp1: int = foe2.hp
	g.hud.gear.pressed.emit()
	await process_frame
	ok(g.hud.menu.visible, "⚙ opens the menu")
	g._on_tile_clicked(0, 0)
	ok(not g.hud.menu.visible, "a map click closes the menu")
	g._on_tile(pos(foe2).x, pos(foe2).y)
	await idle(g)
	var click_ok: bool = arch.acted and (foe2.hp < hp1 or Game.unit_by_id(s, id_of(foe2)) == null)
	ok(click_ok, "one click attack after hover")
	g.ui.hover = null
	# terrain info, hint, codex, speed
	g._on_tile(6, 0)
	await process_frame
	ok(g.hud.card.visible and g.hud.card_box.get_child_count() > 0, "terrain info in the corner card")
	g.cancel()
	# ⓘ on a token: unit card with traits + how to play; next click on the board just closes it
	var any_u: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "e",
	)[0]
	g._on_info_requested(id_of(any_u))
	await process_frame
	var peek_ok: bool = g.ui.peek == any_u.id and g.panel.pop.visible and g.panel.info.get_child_count() >= 4
	ok(peek_ok, "ⓘ opens the unit card (%d rows)" % g.panel.info.get_child_count())
	g._on_tile_clicked(0, 0)
	ok(g.ui.peek == null, "board click closes the unit card")
	await process_frame
	ok(board(g)._info_spots.is_empty(), "no ⓘ dots on the figures (details live in the corner card)")
	# new-unit intro card (Store untouched: called directly)
	g.cards.intro_card(any_u, 0, 1)
	await process_frame
	ok(g.cards.intro_layer != null and g.cards.intro_layer.is_inside_tree(), "intro card shows")
	await main.shot("ux_intro")
	g.cards.intro_closed.emit()
	for i in 30:
		await process_frame
	ok(g.cards.intro_layer == null, "intro card closes")
	g._on_hint()
	await process_frame
	ok(g.ui.hint != null, "hint shows")
	main.menus.open_codex("e")
	await process_frame
	ok(main.menus.is_codex_open(), "codex opens over game")
	main.menus.close_codex()
	g.hud.on_speed()
	# end turn -> enemy turn -> back to us
	for i in 5: # a picked unit swaps the HUD for its card: deselect to reach "Hết lượt"
		if g.ui.sel == null:
			break
		g.cancel()
	ok(g.hud.btn_end.visible and not g.hud.card.visible, "nothing picked -> HUD back, card gone")
	press("Hết lượt")
	var low := 1 << 30
	for i in 1200:
		if s.side == "p" and not g.ui.busy:
			break
		if s.side == "p":
			low = mini(low, int(g.hud.gold_num.text))
		await process_frame
	var turn2_ok: bool = s.side == "p" and s.turn == 2
	ok(turn2_ok, "enemy turn played, turn 2 (turn %d)" % s.turn)
	# turn-start income: the total counts up (shown below the real total for a while), then lands on it
	for i in 200:
		low = mini(low, int(g.hud.gold_num.text))
		if g.hud.gold_shown < 0 and i > 5:
			break
		await process_frame
	var count_ok: bool = Game.income(s, "p") == 0 or low < s.gold.p
	ok(count_ok, "gold counts up at turn start (lowest shown %d, total %d)" % [low, s.gold.p])
	var total_ok: bool = int(g.hud.gold_num.text) == s.gold.p
	ok(total_ok, "gold count-up ends on the real total")
	# buy on top of a unit standing on our castle; click its own tile = keep, click outside its reach = take back (refund)
	var cas: Vector2i = Game.castle_tiles(s, "p")[0]
	var moved := { }
	for u: Dictionary in s.units: # clear the castle, then park exactly one of ours on it
		if u.x == cas.x and u.y == cas.y:
			moved[u.id] = pos(u)
			u.x = -10 - u.id
	var on: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "p" and u.type != "hero" and u.x >= 0,
	)[0]
	moved[on.id] = pos(on)
	on.x = cas.x
	on.y = cas.y
	s.gold.p += 500
	var g0: int = s.gold.p
	var n0: int = units_of(s).size()
	g._clear_sel()
	g.ui.buyAt = [cas.x, cas.y]
	g.refresh()
	g.buy_unit("soldier")
	var nb: Dictionary = s.units[-1]
	var stack_ok: bool = units_of(s).size() == n0 + 1 and g.ui.sel == nb.id and Game.can_unbuy(s, nb)
	ok(stack_ok, "stacked buy selects the new unit")
	g._on_tile_clicked(cas.x, cas.y)
	ok(Game.unit_by_id(s, id_of(nb)) != null, "clicking the castle tile itself keeps the buy")
	for i in 5:
		if g.ui.sel == nb.id:
			break
		g.cancel()
	var w: int = s.w
	var h: int = s.h
	g._on_tile_clicked(w - 1, h - 1)
	var refund_ok: bool = Game.unit_by_id(s, id_of(nb)) == null and s.gold.p == g0 and units_of(s).size() == n0
	ok(refund_ok, "click outside reach takes the buy back, full refund")
	for u: Dictionary in s.units:
		if moved.has(u.id):
			u.x = moved[u.id].x
			u.y = moved[u.id].y
	s.gold.p -= 500
	g._clear_sel()
	g.refresh()
	# save -> title -> continue
	g.save()
	main.show_title()
	await wait(0.6)
	press("Đánh tiếp")
	await wait(0.6)
	var restore_ok: bool = g.visible and g.s.turn == 2 and units_of(g.s).size() == units_of(s).size()
	ok(restore_ok, "continue restores the save")
	# map node of the mission in progress: ask, never wipe it silently
	var m02: Dictionary = Content.mission("m02")
	main.menus.confirm_start(Game.new_game(m02), { "kind": "campaign", "id": "m02" })
	await process_frame
	var asked_ok: bool = find_btn(main, "Đánh lại từ đầu") != null and g.s.turn == 2
	ok(asked_ok, "same mission in progress: modal asks (game kept)")
	press("Đánh tiếp")
	await wait(0.6)
	var kept_ok: bool = g.visible and g.s.turn == 2
	ok(kept_ok, "modal 'Đánh tiếp' keeps the saved game")
	# win -> next mission: straight onto the board -> new-unit intro -> play (no story)
	main.flags.erase("nointro")
	Store.set_v("seen_units", []) # driver profile: m03's unit cards show on every run
	g.s.winner = "p"
	g.s.reason = "castlesLost"
	g.turns.finish()
	await wait(1.5)
	press("Màn tiếp")
	await wait(0.6)
	var m03_ok: bool = g.visible and g.s.scenario == "m03"
	ok(m03_ok, "next mission starts m03")
	ok(g.cards.intro_layer != null, "new-unit intro shows first")
	for i in 20:
		if not g._intro_on:
			break
		g.cards.intro_closed.emit()
		await wait(0.3)
	var play_ok: bool = not g._intro_on and g.s.side == "p" and g.s.turn == 1
	ok(play_ok, "then the game is playable")
	# an old ctx still carrying "story": no overlay, plays, key dropped from the save
	var m03: Dictionary = Content.mission("m03")
	main.start_game(Game.new_game(m03), { "kind": "campaign", "id": "m03", "story": true })
	await wait(0.6)
	for i in 20:
		if not g._intro_on:
			break
		g.cards.intro_closed.emit()
		await wait(0.3)
	var sv: Dictionary = Store.load_game()
	var sctx: Dictionary = sv.ctx
	var old_ok: bool = not g._intro_on and g.s.side == "p" and not sctx.has("story")
	ok(old_ok, "old ctx with story key: plays, key dropped")
	main.flags["nointro"] = "1"
	# win, then straight back to the menu inside the end-card pause: the win must still count
	await wait(0.5)
	g.s.winner = "p"
	g.s.reason = "castlesLost"
	g.turns.finish()
	await wait(0.1)
	main.show_title()
	await wait(0.8)
	ok(Store.is_done("m03") and not g.cards.end_layer.visible, "win kept when leaving during the end pause")
	await _duel(g)
	print("DRIVER DONE fails=%d" % fails)
	quit(1 if fails else 0)
