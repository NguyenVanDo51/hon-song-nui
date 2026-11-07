extends RefCounted
## click driver checks kept out of click_driver.gd (1000-line cap). Each returns [[ok, message], ...] for the driver's ok().

const LayoutStorm := preload("res://sim/layout_storm.gd")

## place_hud re-queued by minimum_size_changed of controls it shows / hides: bursts and a self-feeding toggle pattern must
## cost at most 1 deferred layout per frame (was: unbounded per flush -> "Message queue out of memory"), then settle
static func layout_queue(tree: SceneTree, g: GameScreen) -> Array:
	var hud := g.hud
	var out := []
	var storm := LayoutStorm.new()
	storm.watch([hud.hud_tr, hud.quests, hud.card])
	# burst: 100 show / hide flips of ⏩ ⚙ + quest slip inside each of 10 frames
	var r0 := hud.queued_runs
	var worst := 0
	for f in 10:
		var rf := hud.queued_runs
		for i in 100:
			hud.hud_tr.visible = not hud.hud_tr.visible
			hud.quests.visible = not hud.quests.visible
		await tree.process_frame
		storm.tick()
		worst = maxi(worst, hud.queued_runs - rf)
	out.append(
		[
			worst <= 2 and hud.queued_runs - r0 <= 11,
			"layout queue: 2000 flips in 10 frames -> %d deferred place_hud (max %d between samples)" % [hud.queued_runs - r0, worst],
		]
	)
	# show-in-layout: something shows ⏩ ⚙ on each emit while the layout hides it (unit card up) -> layouts stay <= 1 / frame
	var show := func() -> void:
		hud.hud_tr.visible = true
	hud.card.visible = true
	hud.hud_tr.minimum_size_changed.connect(show)
	var r1 := hud.queued_runs
	var f1 := Engine.get_process_frames()
	hud.place_hud()
	hud.hud_tr.visible = true
	for f in 30:
		await tree.process_frame
		storm.tick()
	var runs := hud.queued_runs - r1
	var frames := Engine.get_process_frames() - f1
	out.append(
		[
			runs <= frames + 1 and not storm.cut,
			"layout queue: show-in-layout pattern -> %d layouts in %d frames, peak %d emits / frame" % [runs, frames, storm.peak],
		]
	)
	hud.hud_tr.minimum_size_changed.disconnect(show)
	storm.stop()
	g.cancel()
	hud.card.visible = false
	hud.place_hud()
	for f in 4:
		await tree.process_frame
	storm = LayoutStorm.new()
	storm.watch([hud.hud_tr, hud.quests, hud.card])
	var r2 := hud.queued_runs
	for f in 6:
		await tree.process_frame
		storm.tick()
	storm.stop()
	var idle := hud.queued_runs - r2
	out.append(
		[
			idle == 0 and hud.hud_tr.visible and storm.peak == 0,
			"layout queue: settles (%d layouts, peak %d emits in 6 idle frames)" % [idle, storm.peak],
		]
	)
	return out

## units / gold / turn / side as one string: any AI step changes it
static func _state_sig(s: Dictionary) -> String:
	var parts: Array[String] = ["%s %s %s %s" % [s.turn, s.side, s.gold.p, s.gold.e]]
	var units: Array = s.units
	for u: Dictionary in units:
		parts.append("%s:%s,%s,%s,%s" % [u.id, u.x, u.y, u.hp, u.acted])
	return " ".join(parts)

## ⚙ opened mid enemy turn (after its first step): state, FX clock, timers frozen while open; a real click on Tiếp tục
## (menu live under the pause) resumes and the turn plays on. Call right after the player's Hết lượt.
static func pause_menu(tree: SceneTree, g: GameScreen) -> Array:
	var out := []
	var s: Dictionary = g.s
	var sig0 := _state_sig(s)
	var mid := false
	for i in 2000:
		if s.side == "e" and g.ui.busy and _state_sig(s) != sig0:
			mid = true
			break
		await tree.process_frame
	out.append([mid, "pause: enemy turn under way (turn %s side %s)" % [s.turn, s.side]])
	g.hud.gear.pressed.emit()
	var sig := _state_sig(s)
	var clock := FX.now()
	var hold0: Dictionary = g.board.view.hold
	var hold := hold0.duplicate()
	for i in 20:
		await tree.process_frame
	await tree.create_timer(1.5).timeout # wall time: a bot step is ~0.1-0.5 s at x3
	var same := _state_sig(s) == sig
	out.append([tree.paused and g.hud.menu.visible, "pause: ⚙ menu open = tree paused"])
	out.append([same, "pause: no bot step in 1.5 s + 20 frames under the menu"])
	out.append([FX.now() == clock, "pause: FX clock frozen (%.1f ms moved)" % (FX.now() - clock)])
	out.append([g.board.view.hold == hold, "pause: board playback state unchanged"])
	var old_size := tree.root.size
	tree.root.size = Vector2i(1280, 720) # headless window is 64 px: real picking needs the button inside the viewport
	await tree.process_frame
	var go := _find_text(g.hud.menu, "Tiếp tục")
	out.append([go != null, "pause: Tiếp tục button"])
	if go != null:
		var at := go.get_global_rect().get_center()
		for down: bool in [true, false]:
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT
			mb.pressed = down
			mb.position = at
			mb.global_position = at
			tree.root.push_input(mb, true)
			await tree.process_frame
	tree.root.size = old_size
	out.append([not g.hud.menu.visible and not tree.paused, "pause: real click on Tiếp tục closes the menu, game runs"])
	if g.hud.menu.visible:
		g.hud.show_menu(false)
	var t1 := FX.now()
	for i in 600:
		if _state_sig(s) != sig:
			break
		await tree.process_frame
	out.append([_state_sig(s) != sig and FX.now() > t1, "pause: bot plays on after closing"])
	return out

static func _find_text(n: Node, part: String) -> Button:
	var b := n as Button
	if b != null and b.is_visible_in_tree() and b.text.contains(part):
		return b
	for c: Node in n.get_children():
		var f := _find_text(c, part)
		if f != null:
			return f
	return null
