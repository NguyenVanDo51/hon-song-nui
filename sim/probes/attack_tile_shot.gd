extends "res://sim/probes/probe_base.gd"
## attack-tile check: our archer 2 tiles (diagonal) from an enemy soldier (50 hp), a mountain next to the enemy;
## hover the enemy -> highlighted attack tile (board view.dest) must be the archer's own tile. Prints it + screenshot.
##   tools/run_guarded.sh /tmp/at.log -- --path . -s sim/probes/attack_tile_shot.gd -- mission=m02 fresh nointro profile=test shots=<dir> [tag=x]

var _done := false

func _run(g: GameScreen) -> void:
	var s: Dictionary = g.s
	timeout_ms = Time.get_ticks_msec() + 60000
	var mine: Array = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "p",
	)
	var foes: Array = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "e",
	)
	var a: Dictionary = mine[0]
	var e: Dictionary = foes[0]
	# free 3x3 patch: archer (x, y), enemy (x+1, y+1), mountain (x+1, y) next to the enemy
	var spot := _find_patch(s)
	a.type = "archer"
	a.hp = 100
	a.acted = false
	a.x = spot.x
	a.y = spot.y
	e.type = "soldier"
	e.hp = 50
	e.x = spot.x + 1
	e.y = spot.y + 1
	var row: Array = s.tiles[spot.y]
	row[spot.x + 1] = "m"
	g.board.refresh_terrain()
	g.refresh()
	await process_frame
	g._on_tile(spot.x, spot.y) # select
	g.ui.hover = Vector2i(spot.x + 1, spot.y + 1)
	g.refresh()
	for i in 6:
		await process_frame
	var v: Dictionary = g.board.view
	print("ATTACK_TILE archer=(%d,%d) enemy=(%d,%d) mountain=(%d,%d) dest=%s path=%s" % [
		spot.x, spot.y, spot.x + 1, spot.y + 1, spot.x + 1, spot.y, v.dest, v.path,
	])
	RenderingServer.force_draw() # occluded macOS window: frame_post_draw may never fire, so no main.shot()
	var dir: String = args.get("shots", "res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png(dir.path_join(str(args.get("tag", "attack_tile")) + ".png"))
	_done = true

## top-left of a 2x2 patch of plain tiles with no unit on it, away from the map edge
func _find_patch(s: Dictionary) -> Vector2i:
	var h: int = s.h
	var w: int = s.w
	for y in range(2, h - 3):
		for x in range(2, w - 3):
			var ok := true
			for dy in 2:
				for dx in 2:
					var t: String = s.tiles[y + dy][x + dx]
					if t != "." or Game.unit_at(s, x + dx, y + dy) != null:
						ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(2, 2)

## quit() from the _run coroutine is not honoured here (window occluded?): end from _process instead
func _process(dt: float) -> bool:
	if _done:
		quit(0)
		return true
	return super(dt)
