extends SceneTree
## a real exchange through GameScreen.play() (zoom, hp bars, counter, die), screenshots every `every` ms of wall time:
##   godot --path . --resolution 1280x720 -s sim/probes/rig_live.gd -- mission=m02 fresh nointro nobattle profile=test \
##       out=/tmp/x/live.png [att=hero] [def=hero] [dir=right] [every=250] [n=12] [def_hp=100] [speed=1]
## Our unit `att` (retyped) attacks an enemy `def` placed at `dir`; the enemy commander counters with its own rig.
var main: Node
var t := 0.0
var step := 0
var args := {}
var frames: Array[Image] = []
var box := Rect2i()
var label: Label

func _initialize() -> void:
	for kv: String in OS.get_cmdline_user_args():
		var p := kv.split("=", true, 1)
		args[p[0]] = p[1] if p.size() > 1 else "1"
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _process(dt: float) -> bool:
	t += dt
	if Time.get_ticks_msec() > 60000:
		printerr("[rig_live] timeout")
		quit(1)
	if step == 0 and main.game != null and not main.game.s.is_empty() and t > 1.5:
		step = 1
		_run()
	return false

func _run() -> void:
	var g: Node = main.game
	var s: Dictionary = g.s
	var dirs := { "right": Vector2i(1, 0), "left": Vector2i(-1, 0), "up": Vector2i(0, -1), "down": Vector2i(0, 1) }
	var ax := Vector2i(s.w / 2 - 1, s.h / 2)
	var dx: Vector2i = ax + dirs.get(args.get("dir", "right"), Vector2i(1, 0))
	var att: String = args.get("att", "hero")
	var dft: String = args.get("def", "hero")
	var mine: Array = s.units.filter(func(u: Dictionary) -> bool: return u.side == "p")
	var theirs: Array = s.units.filter(func(u: Dictionary) -> bool: return u.side == "e")
	var pa: Array = mine.filter(func(u: Dictionary) -> bool: return u.type == att)
	var pd: Array = theirs.filter(func(u: Dictionary) -> bool: return u.type == dft)
	var a: Dictionary = pa[0] if not pa.is_empty() else mine[0]
	var d: Dictionary = pd[0] if not pd.is_empty() else theirs[0]
	a.type = att
	d.type = dft
	d.hp = int(args.get("def_hp", "100"))
	for u: Dictionary in s.units:
		if u.id != a.id and u.id != d.id and absi(u.x - ax.x) + absi(u.y - ax.y) <= 4:
			u.x = 0
			u.y = 0
	a.x = ax.x; a.y = ax.y; a.acted = false
	d.x = dx.x; d.y = dx.y
	for c: Vector2i in [ax, dx]:
		s.tiles[c.y][c.x] = "."
	g.board.refresh_terrain()
	g.refresh()
	label = Label.new()
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 6)
	var cl := CanvasLayer.new()
	cl.layer = 100
	cl.add_child(label)
	root.add_child(cl)
	await process_frame
	var before: Dictionary = g._snapshot()
	var ev := Game.do_action(s, { "id": a.id, "to": [a.x, a.y], "kind": "attack", "target": d.id })
	print("[rig_live] events: ", ev.map(func(e: Dictionary) -> String: return "%s %s" % [e.t, e.get("amount", "")]))
	g.ui.busy = true
	g.refresh() # as GameScreen.commit: busy view (no 'acted' grey while it plays)
	var t0 := Time.get_ticks_msec()
	_shoot(g, t0)
	await g.play(ev, before)
	print("[rig_live] play() took %d ms" % (Time.get_ticks_msec() - t0))
	await create_timer(0.5).timeout
	_save()

func _shoot(g: Node, t0: int) -> void:
	var every := float(args.get("every", "250")) / 1000.0
	var n := int(args.get("n", "12"))
	for k in n:
		await create_timer(every if k > 0 else 0.35).timeout
		label.text = "%d ms" % (Time.get_ticks_msec() - t0)
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if box.size == Vector2i.ZERO:
			var b: Control = g.board
			var c: Vector2 = b.get_global_rect().get_center()
			var sz := Vector2(560, 420)
			box = Rect2i(Vector2i(c - sz / 2.0), Vector2i(sz)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			label.position = Vector2(box.position) + Vector2(8, 4)
		frames.append(img.get_region(box))

func _save() -> void:
	if frames.is_empty():
		quit(1)
		return
	var cols := 4
	var w := frames[0].get_width()
	var h := frames[0].get_height()
	var rows := ceili(frames.size() / float(cols))
	var sheet := Image.create(w * cols + (cols - 1) * 4, h * rows + (rows - 1) * 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.13, 0.13, 0.13))
	for k in frames.size():
		var f := frames[k]
		f.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i((k % cols) * (w + 4), (k / cols) * (h + 4)))
	var out: String = args.get("out", "/tmp/rig_live.png")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	print("[rig_live] ", out, " ", frames.size(), " frames")
	quit()
