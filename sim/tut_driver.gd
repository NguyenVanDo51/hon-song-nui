extends "res://sim/click_driver.gd"
## tutorial levels t01–t03 through the real UI: every step by real mouse clicks (card -> Đã hiểu, tiles through the
## hole, orders popup / shop buttons, Hết lượt), lock checks, a shot per step, then the Hết lượt nudge (t01), Đánh tiếp
## resume (t03) and ⚙ Bỏ qua (t02). Windowed for shots:
##   tools/run_guarded.sh /tmp/t.log -- --path . -s sim/tut_driver.gd -- mission=t01 fresh shots=/tmp/tut [win=WxH]

## quest verbs done by picking a unit, a destination tile, then an orders popup button
const ACT_OF := {
	"move": "wait",
	"stand_on": "wait",
	"capture": "capture",
	"attack_with": "attack",
	"kill_with": "attack",
	"hit_type": "attack",
	"kill_type": "attack",
}

func _tutorial(g: GameScreen) -> void:
	var id := str(main.flags.get("mission", ""))
	await _tut_open(g, id)
	var tut := g.tutorial
	if id == "t01":
		await _lock_checks(g)
	var steps: Array = g.def.get("tutorial", [])
	var guard := 0
	while tut.step < steps.size() and guard < 40:
		guard += 1
		var i := tut.step
		var st: Dictionary = steps[i]
		var tag := "%s step %d" % [id, i + 1]
		if id == "t03" and i == 4:
			await _resume(g, tag)
		if st.has("card"):
			await _card(g, st, tag, i == 3)
		else:
			await _quest_step(g, st, tag)
		await _until(
			func() -> bool:
				return tut.step > i or g.s.winner != null,
		)
		ok(tut.step > i or g.s.winner != null, tag + " done -> step %d" % (tut.step + 1))
		if tut.step <= i:
			break
	ok(tut.step == steps.size() and not tut.active(), id + ": every step walked, guide off")
	if id == "t01":
		await _nudge(g)
	if id == "t02":
		await _skip(g)

## guide up, nothing else covering it, a frame to lay out
func _ready_step(g: GameScreen) -> bool:
	var tut := g.tutorial
	var up := await _live(tut)
	await wait(0.25)
	return up and tut.visible

func _shot(id: String) -> void:
	await main.shot("tut_" + id)

## card: bubble with title + Đã hiểu, ring on its point, board clicks swallowed; Space on one, a real click on the rest
func _card(g: GameScreen, st: Dictionary, tag: String, by_key: bool) -> void:
	var tut := g.tutorial
	ok(await _ready_step(g), tag + " card shows")
	ok(tut.is_card() and tut._ok.visible and tut._title.text == str(st.card), tag + " card: title + Đã hiểu")
	var p: Variant = st.get("point")
	if p is Array:
		var pa: Array = p
		var px: int = pa[0]
		var py: int = pa[1]
		ok(_near(tut.target_rect(), _tile_r(g, px, py)), tag + " card: ring on its tile")
	else:
		ok(not tut.target_rect().has_area(), tag + " card: no point -> centred")
	var br := Rect2(tut._bubble.position, tut._bubble.size)
	ok(Rect2(Vector2.ZERO, tut.size).encloses(br), tag + " card: bubble on screen %s" % br)
	ok(not tut.target_rect().has_area() or not br.intersects(tut.target_rect()), tag + " card: bubble off the ring")
	await _shot(tag.replace(" ", "_"))
	var step0 := tut.step
	var hero := _hero(g.s)
	await _tap(g, _tile_r(g, pos(hero).x, pos(hero).y).get_center())
	okv(tut.step == step0 and g.ui.sel == null, tag + " card: board click swallowed")
	if by_key:
		await _key(KEY_SPACE)
	else:
		await _tap(g, tut._ok.get_global_rect().get_center() - tut.global_position)

## quest step by real clicks: pick the unit through the hole, then the target, then the popup button
func _quest_step(g: GameScreen, st: Dictionary, tag: String) -> void:
	var tut := g.tutorial
	var s: Dictionary = g.s
	var qs: Array = s.quests
	var qi: int = st.q
	var q: Dictionary = qs[qi]
	var verb: String = q.do
	if verb == "heal_on": # passive: the turn start does it
		for i in 600:
			if tut.step > qi or q.done:
				break
			await process_frame
		okv(q.done, tag + " heal at turn start")
		await wait(0.3)
		return
	ok(await _ready_step(g), tag + " guide up")
	await _shot(tag.replace(" ", "_"))
	if verb == "end_turn":
		ok(_near(tut.target_rect(), _ctrl_r(g, g.hud.btn_end)), tag + " hole on Hết lượt")
		await _tap(g, tut.target_rect().get_center())
		ok(await turn_of(g, "p"), tag + " enemy turn played, back to us")
		return
	if verb == "buy":
		await _tap(g, tut.target_rect().get_center())
		await wait(0.3)
		var b := _buy_btn(g.panel.actions, str(q.what))
		ok(b != null and _near(tut.target_rect(), _ctrl_r(g, b)), tag + " shop open, hole on the buy button")
		await _shot(tag.replace(" ", "_") + "_shop")
		await _tap(g, tut.target_rect().get_center())
		await idle(g)
		return
	if verb == "select":
		await _tap(g, tut.target_rect().get_center())
		await idle(g)
		return
	# pick the unit (the hole is on it until it is picked)
	if g.ui.sel == null:
		await _tap(g, tut.target_rect().get_center())
		await process_frame
		await process_frame
		okv(g.ui.sel != null, tag + " unit picked through the hole")
	var p: Variant = st.get("point")
	await process_frame
	var aim := tut.target_rect()
	var act_kind: String = ACT_OF.get(verb, "wait")
	if p is Array and act_kind != "attack":
		var pa: Array = p
		var px: int = pa[0]
		var py: int = pa[1]
		ok(_near(aim, _tile_r(g, px, py)), tag + " hole moves to the destination")
	await _tap(g, aim.get_center())
	ok(await _live(tut), tag + " guide up with the orders popup")
	await wait(0.25)
	var kind: String = ACT_OF.get(verb, "wait")
	var btn := _act_btn(g, kind)
	var c := btn.get_global_rect().get_center() - tut.global_position if btn != null else Vector2(-1, -1)
	ok(btn != null and not tut._has_point(c), tag + " popup %s holed" % kind)
	await _shot(tag.replace(" ", "_") + "_popup")
	if btn != null:
		await _tap(g, c)
	await idle(g)
	for i in 120:
		if q.done:
			break
		await process_frame
	okv(q.done, tag + " quest %s done" % verb)

## t01 step 1: off-hole clicks / Tab E H do nothing, ⚙ passes, hover hits the dim / hole
func _lock_checks(g: GameScreen) -> void:
	var tut := g.tutorial
	var s: Dictionary = g.s
	ok(tut.is_card(), "t01 opens on the goal card")
	g._on_tile_clicked(6, 3)
	okv(g.ui.sel == null and g.ui.info == null and tut.step == 0, "t01 card: tile clicks do nothing")
	await _key(KEY_TAB)
	await _key(KEY_E)
	await _key(KEY_H)
	okv(g.ui.sel == null and g.ui.hint == null and s.side == "p" and s.turn == 1 and tut.step == 0, "t01 card: Tab / E / H off")
	var gc: Vector2 = g.hud.gear.get_global_rect().get_center() - tut.global_position
	ok(not tut._has_point(gc) and tut._has_point(Vector2(4, g.size.y / 2.0)), "t01: overlay lets ⚙ through, blocks elsewhere")
	g.hud.gear.pressed.emit()
	await process_frame
	ok(g.hud.menu.visible and find_btn(g.hud.menu, Content.text("tutSkip")) != null, "t01: ⚙ opens the menu with Bỏ qua")
	await process_frame
	ok(not tut.visible, "t01: guide steps aside while the menu is open")
	g.hud.show_menu(false)
	ok(await _live(tut), "t01: guide back after the menu")
	var on_dim: Control = await _hover_at(g, Vector2(4, g.size.y / 2.0))
	ok(on_dim == tut, "t01: pointer on the dim hits the guide overlay")

## after the last card every unit of ours has acted: the hand points at Hết lượt with no dim / lock
func _nudge(g: GameScreen) -> void:
	var tut := g.tutorial
	ok(not tut.visible or not tut._dim.visible, "t01 free play: no dim")
	var shown := await _until(
		func() -> bool:
			return tut._nudge and tut.visible,
	)
	await wait(0.3)
	ok(shown and tut._hand.visible and not tut._dim.visible, "t01: all units grey + idle -> hand on Hết lượt")
	ok(shown and _near(tut.target_rect(), _ctrl_r(g, g.hud.btn_end)), "t01 nudge: ring on Hết lượt")
	ok(tut.mouse_filter == Control.MOUSE_FILTER_IGNORE, "t01 nudge: clicks pass")
	await _shot("t01_nudge")
	await _tap(g, _ctrl_r(g, g.hud.btn_end).get_center())
	ok(await turn_of(g, "p"), "t01: Hết lượt through the nudge, enemy turn, back to us")
	await wait(0.4)
	ok(not tut._nudge, "t01: new turn, units fresh -> no nudge")

## save mid-way, title, Đánh tiếp -> same step
func _resume(g: GameScreen, tag: String) -> void:
	var at := g.tutorial.step
	g.save()
	main.show_title()
	await wait(0.6)
	press("Đánh tiếp")
	await wait(1.4)
	okv(g.visible and g.s.tut_step == at and g.tutorial.step == at and g.tutorial.active(), tag + ": Đánh tiếp resumes the same step")

## ⚙ -> Bỏ qua hướng dẫn: 1-star win, back to the grid, no save left
func _skip(g: GameScreen) -> void:
	var done: Array = Store.done_list().duplicate()
	done.erase("t02")
	Store.set_v("campaign_done", done)
	g.hud.gear.pressed.emit()
	await process_frame
	press(Content.text("tutSkip"))
	await wait(0.6)
	var skip_ok: bool = Store.is_done("t02") and Store.stars_of("t02") >= 1 and not g.visible and Store.load_game() == null
	ok(skip_ok, "t02: Bỏ qua = win (1 star), level grid, save cleared")
	ok(_find_cls(main, "LevelSelect") != null, "t02: level grid shows after skip")

static func _ctrl_r(g: GameScreen, c: Control) -> Rect2:
	return Rect2(c.global_position - g.tutorial.global_position, c.size)

# ---------- input + lookup helpers ----------
func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	await process_frame

## a real left click (press + release) at p in GameScreen coords, through the viewport's GUI picking
func _tap(g: GameScreen, p: Vector2) -> void:
	var at := g.get_global_transform_with_canvas() * p
	for down: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = at
		e.global_position = at
		main.get_viewport().push_input(e, true)
		await process_frame
	await process_frame

## wait (by the clock, max 10 s) until cond holds
func _until(cond: Callable) -> bool:
	var end := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await process_frame
	return false

## the guide is up (after banners, intro cards, ✓ stamps)
func _live(tut: Tutorial) -> bool:
	var end := Time.get_ticks_msec() + 12000 # by the clock: a window in the background runs at a few fps
	while Time.get_ticks_msec() < end:
		if tut.visible and tut._dim.visible:
			return true
		await process_frame
	return false

## orders popup button carrying meta act = kind (null when none)
static func _act_btn(g: GameScreen, kind: String) -> Button:
	for c: Node in g.panel.actions.get_children():
		var b := c as Button
		if b != null and str(b.get_meta("act", "")) == kind:
			return b
	return null

## control the GUI picks under p (GameScreen coords), via a real mouse motion
func _hover_at(g: GameScreen, p: Vector2) -> Control:
	var e := InputEventMouseMotion.new()
	e.position = g.get_global_transform_with_canvas() * p
	e.global_position = e.position
	main.get_viewport().push_input(e, true)
	await process_frame
	return main.get_viewport().gui_get_hovered_control()

## tile rect in GameScreen coords (the guide overlay's coords)
static func _tile_r(g: GameScreen, x: int, y: int) -> Rect2:
	var r: Rect2 = g.board.tile_rect(x, y)
	r.position += g.hud.map_wrap.position
	return r

static func _near(a: Rect2, b: Rect2) -> bool:
	return a.get_center().distance_to(b.get_center()) < 3.0

## intro cards up first (guide hidden under them), closed, then the guide comes up
func _tut_open(g: GameScreen, tag: String) -> void:
	var win: String = main.flags.get("win", "1280x720")
	var wh := win.split("x")
	var wsz := Vector2i(int(wh[0]), int(wh[1]))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(wsz)
	root.size = wsz # headless window is 64 px: real clicks need the board on screen
	await wait(0.3)
	var tut := g.tutorial
	ok(tut.active() and tut.step == 0, tag + ": guide on at step 1")
	var saw := false
	for i in 120:
		if g._intro_on:
			saw = true
			break
		await process_frame
	ok(saw, tag + ": new-unit intro shows first")
	await process_frame
	ok(not tut.visible, tag + ": guide hidden under the intro")
	for i in 20:
		if not g._intro_on:
			break
		g.cards.intro_closed.emit()
		await wait(0.3)
	for i in 300:
		if tut.visible:
			break
		await process_frame
	ok(tut.visible, tag + ": step 1 shows once the intro is closed")

func _hero(s: Dictionary) -> Dictionary:
	return units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "p" and u.type == "hero",
	)[0]

func _buy_btn(n: Node, type: String) -> Button:
	if n is Button and str(n.get_meta("buy", "")) == type:
		return n
	for c: Node in n.get_children():
		var f := _buy_btn(c, type)
		if f != null:
			return f
	return null
