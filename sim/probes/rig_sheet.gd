extends "res://sim/probes/probe_base.gd"
## contact sheet of a code-rigged attack on the real 2D board (windowed run; headless cannot screenshot):
##   godot --path . --resolution 1280x720 -s sim/probes/rig_sheet.gd -- mission=m02 fresh nointro nobattle \
##       out=/tmp/x/hero_board.png unit=hero side=p times=0,160,290,420,900,1560 [dir=right|left|up|down|ul|dr|...]
##       [dist=1] [zoom=1] [target=soldier]
## Each frame = Rig.seek(t) (8 ms steps, hit-stop skipped: same as snap.py sheet), board zoomed like an in-game
## exchange when zoom=1. Frames are laid out 3 per row in the order given; compare with
##   python3 ~/.claude/skills/svg-attack-anim/scripts/snap.py sheet docs/anim_demo/<spec>.html out.png "<id>:<times>"
var times: Array = []
var frames: Array[Image] = []
var a: Dictionary
var d: Dictionary
var label: Label
var box := Rect2i()

func _initialize() -> void:
	timeout_ms = 120000
	super()

func _run(g: Node) -> void:
	for s: String in str(args.get("times", "0,160,290,420,900,1560")).split(","):
		times.append(float(s))
	_setup(g)
	await create_timer(0.6).timeout
	for at: float in times:
		await _frame(g, at)
	save_sheet(frames, mini(3, frames.size()), args.get("out", "/tmp/rig_sheet.png"), "rig_sheet")
	quit()

func _setup(g: Node) -> void:
	var s: Dictionary = g.s
	var side: String = args.get("side", "p")
	var unit: String = args.get("unit", "hero")
	var foe := "e" if side == "p" else "p"
	var dv: Vector2i = DIRS.get(args.get("dir", "right"), Vector2i(1, 0)) * int(args.get("dist", "1"))
	var ax := Vector2i(s.w / 2 - 1, s.h / 2)
	var dx := ax + dv
	var mine: Array = s.units.filter(func(u: Dictionary) -> bool: return u.side == side)
	var pick: Array = mine.filter(func(u: Dictionary) -> bool: return u.type == unit)
	a = pick[0] if not pick.is_empty() else mine.filter(func(u: Dictionary) -> bool: return u.type != "hero")[0]
	d = s.units.filter(func(u: Dictionary) -> bool: return u.side == foe and u.type != "hero")[0]
	a.type = unit
	d.type = args.get("target", "soldier")
	clear_around(s, ax, 5, [a.id, d.id])
	stage(g, a, d, ax, dx)
	if args.get("zoom", "1") == "1":
		g.board.focus(ax, dx)
	label = ms_label(22)

func _frame(g: Node, at: float) -> void:
	g.fx.rigs.clear()
	label.text = "token" if at < 0.0 else "%d ms" % int(at)
	if at < 0.0: # the plain token right before the swap (after FX.rig_attack's turn), to check it is seamless
		await g.fx.turn_to(g.board, a.id, a.side, FX.rig_face(g.board, a, d))
		await _grab(g)
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
	r.place(g.board, Vector2i(a.x, a.y), Vector2i(d.x, d.y), FX.rig_face(g.board, a, d))
	r.seek(at)
	r.time_scale = 0.0 # frozen at `at`
	g.fx.rigs.append(r)
	g.fx.shake_until = 0.0
	await _grab(g)

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
