extends "res://sim/probes/probe_base.gd"
## layout storm hunt (MQ OOM crash): 1 vs 1 vs Máy Siêu khó (ai:hard), empty tiles picked (terrain card), then window sizes + ⚙ menu
## cycled while the game plays on; counts ⏩ ⚙ / quest slip minimum_size_changed per frame (LayoutStorm).
##   tools/run_guarded.sh /tmp/ll.log -- --path . -s sim/probes/layout_loop.gd -- fresh profile=test speed=3 [bot] [secs=60]
## headless works too (layout forced to 1280x720; window sizes then do nothing). shots=DIR shot_every=999: terrain card png

const LayoutStorm := preload("res://sim/layout_storm.gd")

var storm := LayoutStorm.new()

func _boot() -> void:
	main.menus.duel_opts.map = str(main.flags.get("map", "dong_bang"))
	main.menus.duel_opts.ctrlE = "ai:hard"
	main.menus.show_duel() # fills the commander picks
	main.menus._start_duel()
	await super()

func _process(dt: float) -> bool:
	storm.tick()
	return super(dt)

func _run(g: GameScreen) -> void:
	if DisplayServer.get_name() == "headless": # 64 px window: give the layout a desktop size
		main.size = Vector2(1280, 720)
		await process_frame
	storm.watch([g.hud.hud_tr, g.hud.quests])
	var s: Dictionary = g.s
	var picks := 0
	for y: int in s.h:
		for x: int in s.w:
			if picks >= 6 or storm.cut or Game.unit_at(s, x, y) != null:
				continue
			g._on_tile(x, y)
			picks += 1
			for k in 6:
				await process_frame
			print("terrain %d,%d card at %s, ⏩ ⚙ shown %s, peak %d" % [x, y, g.hud.card.position, g.hud.hud_tr.visible, storm.peak])
			print("  card size %s, min %s" % [g.hud.card.size, g.hud.card.get_combined_minimum_size()])
			if picks == 1 and args.has("shots"):
				await main.shot("ll_terrain")
			g.cancel()
			await process_frame
	var sizes: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(844, 390), Vector2i(1000, 700), Vector2i(1600, 900), Vector2i(700, 400)]
	var t0 := Time.get_ticks_msec()
	var i := 0
	while not storm.cut and Time.get_ticks_msec() - t0 < str(args.get("secs", "0")).to_int() * 1000:
		DisplayServer.window_set_size(sizes[i % sizes.size()])
		i += 1
		for k in 30:
			await process_frame
		g.hud.show_menu(true)
		await process_frame
		g.hud.show_menu(false)
		for k in 30:
			await process_frame
	print("LAYOUT LOOP DONE storm=%s peak/frame=%d turn=%s" % [storm.cut, storm.peak, s.turn])
	quit(1 if storm.cut else 0)
