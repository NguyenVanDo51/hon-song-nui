extends "res://sim/probes/probe_base.gd"
## "Thử thách" page at several window sizes -> <shots>/levels_<WxH>.png (viewport grab, windowed):
##   MAX_SEC=200 tools/run_guarded.sh /tmp/l.log -- --path . -s sim/probes/levels_shot.gd --
##     screen=levels fresh profile=test shots=<dir> [sizes=844x390,1280x720] [tag=x] [focus=m05] [done=N]
## done=N: the first N levels count as won (shows retaken land; profile only). sel=<id>: that level's card open.

func _boot() -> void:
	args = main.flags
	if args.has("done"):
		var ids: Array = Content.levels().slice(0, str(args.done).to_int()).map(
			func(m: Dictionary) -> String:
				return m.id,
		)
		Store.set_v("campaign_done", ids)
	if args.has("done") or args.has("focus"):
		main.menus.show_levels(str(args.get("focus", "")))
	await create_timer(1.0).timeout
	if args.has("sel"): # sel=<level id>: tap it (card open)
		var wm: WorldMap = main.menus.page.get_child(0)
		wm.select(Content.level_index(str(args.sel)))
	var tag: String = args.get("tag", "")
	for sz: String in str(args.get("sizes", "844x390,1500x675,1280x720,960x720")).split(","):
		var p := sz.split("x")
		root.size = Vector2i(int(p[0]), int(p[1]))
		DisplayServer.window_set_size(Vector2i(int(p[0]), int(p[1])))
		for i in 30:
			await process_frame
		await create_timer(0.8).timeout
		await main.shot("levels_%s%s" % [sz, tag])
	quit()
