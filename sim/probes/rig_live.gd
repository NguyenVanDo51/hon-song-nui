extends "res://sim/probes/probe_base.gd"
## a real exchange through GameScreen.play() (zoom, hp bars, counter, die), screenshots every `every` ms of wall time:
##   godot --path . --resolution 1280x720 -s sim/probes/rig_live.gd -- mission=m02 fresh nointro nobattle profile=test \
##       out=/tmp/x/live.png [att=hero] [def=hero] [dir=right] [every=250] [n=12] [def_hp=100] [speed=1]
## Our unit `att` (retyped) attacks an enemy `def` placed at `dir`; the enemy commander counters with its own rig.
var frames: Array[Image] = []
var box := Rect2i()
var label: Label

func _initialize() -> void:
	timeout_ms = 60000
	super()

func _run(g: GameScreen) -> void:
	var s: Dictionary = g.s
	var w: int = s.w
	var h: int = s.h
	@warning_ignore("integer_division")
	var ax := Vector2i(w / 2 - 1, h / 2)
	var dx: Vector2i = ax + DIRS.get(args.get("dir", "right"), Vector2i(1, 0))
	var att: String = args.get("att", "hero")
	var dft: String = args.get("def", "hero")
	var mine: Array = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "p",
	)
	var theirs: Array = units_of(s).filter(
		func(u: Dictionary) -> bool:
			return u.side == "e",
	)
	var pa: Array = mine.filter(
		func(u: Dictionary) -> bool:
			return u.type == att,
	)
	var pd: Array = theirs.filter(
		func(u: Dictionary) -> bool:
			return u.type == dft,
	)
	var a: Dictionary = pa[0] if not pa.is_empty() else mine[0]
	var d: Dictionary = pd[0] if not pd.is_empty() else theirs[0]
	a.type = att
	d.type = dft
	var def_hp: String = args.get("def_hp", "100")
	d.hp = int(def_hp)
	clear_around(s, ax, 4, [a.id, d.id])
	a.acted = false
	stage(g, a, d, ax, dx)
	label = ms_label(20)
	await process_frame
	var before: Dictionary = g._snapshot()
	var ev := Game.do_action(s, { "id": a.id, "to": [a.x, a.y], "kind": "attack", "target": d.id })
	print(
		"[rig_live] events: ",
		ev.map(
			func(e: Dictionary) -> String:
				return "%s %s" % [e.t, e.get("amount", "")],
		),
	)
	g.ui.busy = true
	g.refresh() # as GameScreen.commit: busy view (no 'acted' grey while it plays)
	var t0 := Time.get_ticks_msec()
	_shoot(g, t0)
	await g.play(ev, before)
	print("[rig_live] play() took %d ms" % (Time.get_ticks_msec() - t0))
	await create_timer(0.5).timeout
	if frames.is_empty():
		quit(1)
		return
	var out: String = args.get("out", "/tmp/rig_live.png")
	save_sheet(frames, 4, out, "rig_live")
	quit()

func _shoot(g: GameScreen, t0: int) -> void:
	var every_ms: String = args.get("every", "250")
	var n_s: String = args.get("n", "12")
	var every := float(every_ms) / 1000.0
	var n := int(n_s)
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
