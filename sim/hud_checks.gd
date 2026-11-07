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
