extends "res://sim/probes/probe_base.gd"
## portrait check: board turned (rot), every tile's on-screen centre picks back that tile, idle / reach / preview shots,
## then 2 attacks (enemy above = map right, enemy to the right = map down) as contact sheets.
##   tools/run_guarded.sh /tmp/pt.log -- --path . --resolution 540x1170 -s sim/probes/portrait_shot.gd -- mission=m02 fresh nointro
##     profile=test shots=<dir> [tag=x]

func _run(g: GameScreen) -> void:
	timeout_ms = Time.get_ticks_msec() + 90000
	var s: Dictionary = g.s
	var tag: String = args.get("tag", "pt")
	var h: int = s.h
	var w: int = s.w
	_check(g)
	await _snap(tag + "_idle")
	var mine: Array = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "p" and u.type != "hero",
	)
	var foes: Array = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "e",
	)
	var a: Dictionary = mine[0]
	g._on_tile(pos(a).x, pos(a).y)
	await _frames(6)
	await _snap(tag + "_reach")
	g.cancel()
	g.cancel()
	var e: Dictionary = foes[0]
	for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var spot := Vector2i(clampi(w >> 1, 1, w - 3), clampi(h >> 1, 1, h - 3))
		clear_around(s, spot, 3, [a.id, e.id])
		a.acted = false
		a.hp = 100
		e.hp = 100
		stage(g, a, e, spot, spot + d)
		await _frames(4)
		g._on_tile(spot.x, spot.y)
		g.ui.hover = spot + d
		g.refresh()
		await _frames(6)
		await _snap("%s_preview_%d%d" % [tag, d.x, d.y])
		g._on_tile(spot.x + d.x, spot.y + d.y)
		await _frames(2)
		if g.ui.sel != null: # touch: 1st tap aims, 2nd strikes
			g._on_tile(spot.x + d.x, spot.y + d.y)
		var frames: Array[Image] = []
		for i in 12:
			await create_timer(0.12).timeout
			frames.append(_grab())
		save_sheet(frames, 4, _dir().path_join("%s_attack_%d%d.png" % [tag, d.x, d.y]), "portrait")
		while g.ui.busy:
			await process_frame
		await _frames(4)
	# device turned mid-game: landscape -> portrait again, board / picking follow
	for sz: Vector2i in [Vector2i(1170, 540), Vector2i(540, 1170)]:
		DisplayServer.window_set_size(sz)
		await create_timer(0.6).timeout
		_check(g)
		await _snap("%s_flip_%dx%d" % [tag, sz.x, sz.y])
	quit()

## board turned or not, on-screen rect inside the screen, every tile's on-screen centre picks back that tile
func _check(g: GameScreen) -> void:
	var s: Dictionary = g.s
	var b := g.board
	var bad := 0
	var h: int = s.h
	var w: int = s.w
	for y in h:
		for x in w:
			var r: Rect2 = b.tile_rect(x, y)
			var gp: Vector2 = b.get_parent_control().get_global_transform_with_canvas() * r.get_center()
			var lp: Vector2 = b.get_global_transform_with_canvas().affine_inverse() * gp
			var got: Variant = b._pick(lp)
			if got != Vector2i(x, y):
				bad += 1
	var inside := Rect2(Vector2.ZERO, g.size).grow(1.0).encloses(b.visual_rect())
	print(
		"PORTRAIT rot=%s T=%s screen=%s board_on_screen=%s inside=%s pick_mismatches=%d/%d"
		% [b.rot, b.T, g.size, b.visual_rect(), inside, bad, w * h]
	)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _dir() -> String:
	return str(args.get("shots", "res://shots"))

## occluded macOS window: frame_post_draw may never fire -> force a draw, read the root texture
func _grab() -> Image:
	RenderingServer.force_draw()
	return root.get_texture().get_image()

func _snap(shot_name: String) -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(_dir())
	_grab().save_png(_dir().path_join(shot_name + ".png"))
