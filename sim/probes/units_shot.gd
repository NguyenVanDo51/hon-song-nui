extends SceneTree
## visual check of the AE2 roster: -- out tag <flags>. Retypes units on m02, puts a boat in the river, a temple,
## aura + poison markers, then a full-window shot.
var main: Node
var t := 0.0
var step := 0
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
func _process(dt: float) -> bool:
	t += dt
	if main.game == null or main.game.s.is_empty():
		return false
	var g: Node = main.game
	var s: Dictionary = g.s
	if step == 0 and t > 1.5:
		var types := ["bird", "wolf", "boat", "drum", "shaman", "elephant", "ghost", "catapult"]
		var i := 0
		for u: Dictionary in s.units:
			if u.type != "hero" and i < types.size():
				u.type = types[i]; i += 1
		for u: Dictionary in s.units:
			if u.type == "boat":
				for y in s.h:
					for x in s.w:
						if s.tiles[y][x] == "~" and Game.unit_at(s, x, y) == null and u.type == "boat" and u.x != x:
							u.x = x; u.y = y
							break
					if s.tiles[u.y][u.x] == "~": break
			if u.type == "wolf": u.poison = "e" if u.side == "p" else "p"; u.poisonAmt = Rules.UNITS.wolf.poison
			if u.side == "p" and u.type == "hero": u.aura = "p"; u.auraAtk = Rules.UNITS.drum.aura; u.rank = 4
		for y in s.h:
			for x in s.w:
				if s.tiles[y][x] == "." and Game.unit_at(s, x, y) == null and x == s.w / 2 - 2 and y == s.h / 2:
					s.tiles[y][x] = "t"
		g.board.refresh_terrain(); g.refresh()
		var h: Dictionary = s.units.filter(func(u: Dictionary) -> bool: return u.side == "p" and u.type == "hero")[0]
		g._on_tile(h.x, h.y)
		step = 1
	elif step == 1 and t > 3.0:
		step = 2
		_shot()
	return false
func _shot() -> void:
	await RenderingServer.frame_post_draw
	var a := OS.get_cmdline_user_args()
	root.get_texture().get_image().save_png("%s/%s.png" % [a[0], a[1]])
	print("[shot] ", a[1])
	quit()
