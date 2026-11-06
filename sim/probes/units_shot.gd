extends "res://sim/probes/probe_base.gd"
## visual check of the AE2 roster: -- out tag <flags>. Retypes units on m02, puts a boat in the river, a temple,
## aura + poison markers, then a full-window shot.

func _run(g: GameScreen) -> void:
	var s: Dictionary = g.s
	var types := ["bird", "wolf", "boat", "drum", "shaman", "elephant", "ghost", "catapult"]
	var i := 0
	for u: Dictionary in s.units:
		if u.type != "hero" and i < types.size():
			u.type = types[i]
			i += 1
	for u: Dictionary in s.units:
		if u.type == "boat":
			for y: int in s.h:
				for x: int in s.w:
					if s.tiles[y][x] == "~" and Game.unit_at(s, x, y) == null and u.type == "boat" and u.x != x:
						u.x = x
						u.y = y
						break
				if s.tiles[u.y][u.x] == "~":
					break
		if u.type == "wolf":
			u.poison = "e" if u.side == "p" else "p"
			u.poisonAmt = Rules.UNITS.wolf.poison
		if u.side == "p" and u.type == "hero":
			u.aura = "p"
			u.auraAtk = Rules.UNITS.drum.aura
			u.rank = 4
	for y: int in s.h:
		for x: int in s.w:
			if s.tiles[y][x] == "." and Game.unit_at(s, x, y) == null and x == s.w / 2 - 2 and y == s.h / 2:
				s.tiles[y][x] = "t"
	refresh_terrain(g)
	g.refresh()
	var h: Dictionary = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "p" and u.type == "hero",
	)[0]
	g._on_tile(pos(h).x, pos(h).y)
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var a := OS.get_cmdline_user_args()
	var path := "%s/%s.png" % [a[0], a[1]]
	var err := root.get_texture().get_image().save_png(path)
	if err != OK:
		push_error("units_shot: cannot write %s: %s" % [path, error_string(err)])
	print("[shot] ", a[1])
	quit()
