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

func _run(g: GameScreen) -> void:
	for s: String in str(args.get("times", "0,160,290,420,900,1560")).split(","):
		times.append(float(s))
	_setup(g)
	await create_timer(0.6).timeout
	for at: float in times:
		await _frame(g, at)
	var out: String = args.get("out", "/tmp/rig_sheet.png")
	save_sheet(frames, mini(3, frames.size()), out, "rig_sheet")
	quit()

func _setup(g: GameScreen) -> void:
	var s: Dictionary = g.s
	var side: String = args.get("side", "p")
	var unit: String = args.get("unit", "hero")
	var foe := "e" if side == "p" else "p"
	var dist: String = args.get("dist", "1")
	var dv: Vector2i = DIRS.get(args.get("dir", "right"), Vector2i(1, 0)) * int(dist)
	var w: int = s.w
	var h: int = s.h
	@warning_ignore("integer_division")
	var ax := Vector2i(w / 2 - 1, h / 2)
	var dx := ax + dv
	var mine: Array = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == side,
	)
	var pick: Array = mine.filter(
		func(u: Dictionary) -> bool:
			return u.type == unit,
	)
	a = (pick[0]
		if not pick.is_empty()
		else mine.filter(
			func(u: Dictionary) -> bool:
				return u.type != "hero",
		)[0])
	d = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == foe and u.type != "hero",
	)[0]
	a.type = unit
	d.type = args.get("target", "soldier")
	clear_around(s, ax, 5, [a.id, d.id])
	stage(g, a, d, ax, dx)
	if args.get("zoom", "1") == "1":
		board(g).focus(ax, dx)
	label = ms_label(22)

## 2D board only (the stage crop below reads Board._stage)
static func board(g: GameScreen) -> Board:
	return g.board

func _frame(g: GameScreen, at: float) -> void:
	g.fx.rigs.clear()
	label.text = "token" if at < 0.0 else "%d ms" % int(at)
	if at < 0.0: # the plain token right before the swap (after FX.rig_attack's turn), to check it is seamless
		var a_id: int = a.id
		var a_side: String = a.side
		await g.fx.turn_to(g.board, a_id, a_side, FX.rig_face(g.board, a, d))
		await _grab(g)
		return
	var a_type: String = a.type
	var a_side: String = a.side
	var r := Rigs.make(a_type, a_side)
	if r == null:
		printerr("no rig for %s/%s" % [a.type, a.side])
		quit(1)
		return
	r.a_id = a.id
	r.d_id = d.id
	r.d_type = d.type
	r.amount = 42
	r.place(g.board, pos(a), pos(d), FX.rig_face(g.board, a, d))
	r.seek(at)
	r.time_scale = 0.0 # frozen at `at`
	g.fx.rigs.append(r)
	g.fx.shake_until = 0.0
	await _grab(g)

func _grab(g: GameScreen) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var b := board(g)
	var ra := b.tile_rect(pos(a).x, pos(a).y)
	var rd := b.tile_rect(pos(d).x, pos(d).y)
	if box.size == Vector2i.ZERO:
		# crop: both tiles on the zoomed stage, with margin (2D board: tile_rect is unzoomed, so map through the stage)
		var st: Control = b._stage
		var p0: Vector2 = b.get_global_transform() * (st.position + st.scale * (ra.position - b.position))
		var p1: Vector2 = b.get_global_transform() * (st.position + st.scale * (rd.position - b.position))
		var tl := Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y))
		var sz := (p0 - p1).abs() + ra.size * st.scale
		var c := tl + sz / 2.0
		var margin: String = args.get("margin", "0.9")
		var m := float(margin)
		var half := Vector2(maxf(sz.x, sz.y) * 0.5, sz.y * 0.5) + ra.size * st.scale * m + Vector2(0, ra.size.y * st.scale.y * 0.3)
		box = Rect2i(Vector2i(c - half - Vector2(0, ra.size.y * st.scale.y * 0.3)), Vector2i(half * 2.0))
		box = box.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		label.position = Vector2(box.position) + Vector2(8, 4)
		await process_frame
		await RenderingServer.frame_post_draw
		img = root.get_texture().get_image()
	frames.append(img.get_region(box))
