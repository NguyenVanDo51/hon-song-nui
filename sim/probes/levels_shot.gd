extends "res://sim/probes/probe_base.gd"
## "Thử thách" page at several window sizes -> <shots>/levels_<WxH>.png (viewport grab, windowed):
##   MAX_SEC=200 tools/run_guarded.sh /tmp/l.log -- --path . -s sim/probes/levels_shot.gd -- screen=levels fresh profile=test shots=<dir> [sizes=844x390,1280x720] [tag=x] [pg=0]
## Prints the page's scroll range per size: max 0 = fits without scrolling.

func _boot() -> void:
	args = main.flags
	if args.has("pg"):
		main.menus.show_levels(str(args.pg).to_int())
	await create_timer(1.0).timeout
	var tag: String = args.get("tag", "")
	for sz: String in str(args.get("sizes", "844x390,1500x675,1280x720,960x720")).split(","):
		var p := sz.split("x")
		root.size = Vector2i(int(p[0]), int(p[1]))
		DisplayServer.window_set_size(Vector2i(int(p[0]), int(p[1])))
		for i in 30:
			await process_frame
		await create_timer(0.8).timeout
		var sc: ScrollContainer = main.menus.page
		var bar := sc.get_v_scroll_bar()
		print("[levels] %s scroll max=%d page=%d" % [sz, int(bar.max_value - bar.page), int(bar.page)])
		await main.shot("levels_%s%s" % [sz, tag])
	quit()
