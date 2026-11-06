extends SceneTree
## per-troop strike FX check: -- out <flags>. On m02, each type in turn hits an enemy placed next to it; crops at contact.
var main: Node
var t := 0.0
var i := -1
var types := ["hero", "soldier", "boat", "shaman", "drum", "wolf", "elephant", "bird", "ghost"]
var a: Dictionary
var d: Dictionary
var fired := 0.0
var shots := 0
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
func _process(dt: float) -> bool:
	t += dt
	if main.game == null or main.game.s.is_empty() or t < 1.5:
		return false
	var g: Node = main.game
	var s: Dictionary = g.s
	if i == -1:
		a = s.units.filter(func(u: Dictionary) -> bool: return u.side == "p" and u.type == "hero")[0]
		d = s.units.filter(func(u: Dictionary) -> bool: return u.side == "e" and u.type != "hero")[0]
		d.x = 6; d.y = 4
		for u: Dictionary in s.units:
			if u.id != a.id and u.id != d.id and abs(u.x - 6) + abs(u.y - 4) <= 2:
				u.x = 0; u.y = 0
		g.refresh()
		i = 0
		fired = -1.0
	if fired < 0.0:
		a.type = types[i]
		a.x = 5; a.y = 4
		g.refresh()
		g.fx.attack({ "x": a.x, "y": a.y, "id": a.id, "type": a.type, "side": "p" }, { "x": d.x, "y": d.y, "id": d.id, "type": d.type, "side": "e" }, 30)
		fired = t
		shots = 0
	elif shots == 0 and t - fired > 0.30:
		shots = 1; _shot("%s_a" % types[i])
	elif shots == 1 and t - fired > 0.48:
		shots = 2; _shot("%s_b" % types[i])
	elif shots == 2 and t - fired > 1.3:
		i += 1
		fired = -1.0
		if i >= types.size():
			quit()
	return false
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var g: Node = main.game
	var r: Rect2 = g.board.tile_rect(6, 4)
	var c: Vector2 = g._wrap.global_position + r.get_center()
	var box := Rect2i(Vector2i(c - Vector2(r.size.x * 2.2, r.size.y * 1.6)), Vector2i(r.size.x * 3.6, r.size.y * 2.8))
	box = box.intersection(Rect2i(Vector2i.ZERO, root.get_texture().get_size()))
	root.get_texture().get_image().get_region(box).save_png("%s/%s.png" % [OS.get_cmdline_user_args()[0], n])
