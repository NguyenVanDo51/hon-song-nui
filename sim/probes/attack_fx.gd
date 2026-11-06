extends "res://sim/probes/probe_base.gd"
## per-troop strike FX check: -- out <flags>. On m02, each type in turn hits an enemy placed next to it; crops at contact.
var types := ["hero", "soldier", "boat", "shaman", "drum", "wolf", "elephant", "bird", "ghost"]

func _run(g: Node) -> void:
	var s: Dictionary = g.s
	var a: Dictionary = s.units.filter(func(u: Dictionary) -> bool: return u.side == "p" and u.type == "hero")[0]
	var d: Dictionary = s.units.filter(func(u: Dictionary) -> bool: return u.side == "e" and u.type != "hero")[0]
	d.x = 6; d.y = 4
	clear_around(s, Vector2i(6, 4), 2, [a.id, d.id])
	g.refresh()
	for type: String in types:
		a.type = type
		a.x = 5; a.y = 4
		g.refresh()
		g.fx.attack({ "x": a.x, "y": a.y, "id": a.id, "type": a.type, "side": "p" }, { "x": d.x, "y": d.y, "id": d.id, "type": d.type, "side": "e" }, 30)
		var t0 := Time.get_ticks_msec()
		await _at(t0, 300)
		await _shot(g, "%s_a" % type)
		await _at(t0, 480)
		await _shot(g, "%s_b" % type)
		await _at(t0, 1300)
	quit()

## until ms of wall time since t0
func _at(t0: int, ms: int) -> void:
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame

func _shot(g: Node, n: String) -> void:
	await RenderingServer.frame_post_draw
	var r: Rect2 = g.board.tile_rect(6, 4)
	var c: Vector2 = g._wrap.global_position + r.get_center()
	var box := Rect2i(Vector2i(c - Vector2(r.size.x * 2.2, r.size.y * 1.6)), Vector2i(r.size.x * 3.6, r.size.y * 2.8))
	box = box.intersection(Rect2i(Vector2i.ZERO, root.get_texture().get_size()))
	root.get_texture().get_image().get_region(box).save_png("%s/%s.png" % [OS.get_cmdline_user_args()[0], n])
