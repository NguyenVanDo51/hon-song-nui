extends SceneTree
## contact sheet of a code-rigged attack on the real 2D board (windowed run; headless cannot screenshot):
##   godot --path . --resolution 1280x720 -s sim/probes/rig_sheet.gd -- mission=m02 fresh nointro nobattle \
##       out=/tmp/x/hero_board.png unit=hero side=p times=0,160,290,420,900,1560 [dir=right|left|up|down|ul|dr|...]
##       [dist=1] [zoom=1] [target=soldier]
## Each frame = Rig.seek(t) (8 ms steps, hit-stop skipped: same as snap.py sheet), board zoomed like an in-game
## exchange when zoom=1. Frames are laid out 3 per row in the order given; compare with
##   python3 ~/.claude/skills/svg-attack-anim/scripts/snap.py sheet docs/anim_demo/<spec>.html out.png "<id>:<times>"
var main: Node
var t := 0.0
var step := 0
var args := {}
var times: Array = []
var i := 0
var frames: Array[Image] = []
var a: Dictionary
var d: Dictionary
var label: Label
var box := Rect2i()

func _initialize() -> void:
	for kv: String in OS.get_cmdline_user_args():
		var p := kv.split("=", true, 1)
		args[p[0]] = p[1] if p.size() > 1 else "1"
	for s: String in str(args.get("times", "0,160,290,420,900,1560")).split(","):
		times.append(float(s))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _process(dt: float) -> bool:
	t += dt
	if Time.get_ticks_msec() > 45000: # never hang a guarded run on a script error
		printerr("[rig_sheet] timeout")
		quit(1)
	if main.game == null or main.game.s.is_empty() or t < 1.5:
		return false
	var g: Node = main.game
	if step == 0:
		_setup(g)
		step = 1
		t = 0.0
	elif step == 1 and t > 0.6:
		step = 2
		_frame(g)
	return false

func _setup(g: Node) -> void:
	var s: Dictionary = g.s
	var side: String = args.get("side", "p")
	var unit: String = args.get("unit", "hero")
	var foe := "e" if side == "p" else "p"
	var dirs := { "right": Vector2i(1, 0), "left": Vector2i(-1, 0), "up": Vector2i(0, -1), "down": Vector2i(0, 1),
		"ur": Vector2i(1, -1), "dr": Vector2i(1, 1), "ul": Vector2i(-1, -1), "dl": Vector2i(-1, 1) }
	var dv: Vector2i = dirs.get(args.get("dir", "right"), Vector2i(1, 0)) * int(args.get("dist", "1"))
	var ax := Vector2i(s.w / 2 - 1, s.h / 2)
	var dx := ax + dv
	var mine: Array = s.units.filter(func(u: Dictionary) -> bool: return u.side == side)
	var pick: Array = mine.filter(func(u: Dictionary) -> bool: return u.type == unit)
	a = pick[0] if not pick.is_empty() else mine.filter(func(u: Dictionary) -> bool: return u.type != "hero")[0]
	d = s.units.filter(func(u: Dictionary) -> bool: return u.side == foe and u.type != "hero")[0]
	a.type = unit
	d.type = args.get("target", "soldier")
	for u: Dictionary in s.units:
		if u.id != a.id and u.id != d.id and absi(u.x - ax.x) + absi(u.y - ax.y) <= 5:
			u.x = 0
			u.y = 0
	a.x = ax.x; a.y = ax.y
	d.x = dx.x; d.y = dx.y
	for c: Vector2i in [ax, dx]: # plain ground under both
		s.tiles[c.y][c.x] = "."
	g.board.refresh_terrain()
	g.refresh()
	if args.get("zoom", "1") == "1":
		g.board.focus(ax, dx)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 6)
	var cl := CanvasLayer.new()
	cl.layer = 100
	cl.add_child(label)
	root.add_child(cl)

func _frame(g: Node) -> void:
	if i >= times.size():
		_save()
		return
	var at: float = times[i]
	g.fx.rigs.clear()
	label.text = "token" if at < 0.0 else "%d ms" % int(at)
	if at < 0.0: # the plain token, to check the token -> rig swap is seamless
		await _grab(g)
		_frame(g)
		return
	var r := Rigs.make(a.type, a.side)
	if r == null:
		printerr("no rig for %s/%s" % [a.type, a.side])
		quit(1)
		return
	r.a_id = a.id
	r.d_id = d.id
	r.d_type = d.type
	r.amount = 42
	var dxi: int = d.x - a.x
	r.place(g.board, Vector2i(a.x, a.y), Vector2i(d.x, d.y), signf(dxi) if dxi != 0 else g.board.face_of(a.id, a.side))
	r.seek(at)
	r.time_scale = 0.0 # frozen at `at`
	g.fx.rigs.append(r)
	g.fx.shake_until = 0.0
	await _grab(g)
	_frame(g)

func _grab(g: Node) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var ra: Rect2 = g.board.tile_rect(a.x, a.y)
	var rd: Rect2 = g.board.tile_rect(d.x, d.y)
	if box.size == Vector2i.ZERO:
		# crop: both tiles on the zoomed stage, with margin (2D board: tile_rect is unzoomed, so map through the stage)
		var st: Control = g.board._stage
		var p0: Vector2 = g.board.get_global_transform() * (st.position + st.scale * (ra.position - g.board.position))
		var p1: Vector2 = g.board.get_global_transform() * (st.position + st.scale * (rd.position - g.board.position))
		var tl := Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y))
		var sz := (p0 - p1).abs() + ra.size * st.scale
		var c := tl + sz / 2.0
		var m := float(args.get("margin", "0.9"))
		var half := Vector2(maxf(sz.x, sz.y) * 0.5, sz.y * 0.5) + ra.size * st.scale * m + Vector2(0, ra.size.y * st.scale.y * 0.3)
		box = Rect2i(Vector2i(c - half - Vector2(0, ra.size.y * st.scale.y * 0.3)), Vector2i(half * 2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		label.position = Vector2(box.position) + Vector2(8, 4)
		await process_frame
		await RenderingServer.frame_post_draw
		img = root.get_texture().get_image()
	frames.append(img.get_region(box))
	i += 1

func _save() -> void:
	var cols := mini(3, frames.size())
	var rows := ceili(frames.size() / 3.0)
	var w := frames[0].get_width()
	var h := frames[0].get_height()
	var sheet := Image.create(w * cols + (cols - 1) * 4, h * rows + (rows - 1) * 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.13, 0.13, 0.13))
	for k in frames.size():
		var f := frames[k]
		f.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i((k % 3) * (w + 4), (k / 3) * (h + 4)))
	var out: String = args.get("out", "/tmp/rig_sheet.png")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	print("[rig_sheet] ", out, " ", frames.size(), " frames")
	quit()
