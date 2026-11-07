extends "res://sim/probes/probe_base.gd"
## new-unit intro popup (IntroStage) for every unit type, 3 frames each (move zone, hit, end) -> <out>/intro_<type>.png.
## Windowed run (headless cannot screenshot), under the guard:
##   MAX_SEC=180 tools/run_guarded.sh /tmp/i.log -- --path . --resolution 1280x720 -s sim/probes/intro_shot.gd -- \
##       mission=m02 fresh nointro nobattle profile=test [out=shots] [types=wolf,archer] [side=p|e]
## Prints "[intro] <type> <ms>" = how long one play() took.
const GRABS := ["reach", "hit", "end"]

var scene: IntroStage
var frames: Array[Image] = []

func _initialize() -> void:
	timeout_ms = 170000
	super()

func _run(g: GameScreen) -> void:
	var out: String = args.get("out", "shots")
	var side: String = args.get("side", "p")
	var types: Array = Rules.UNITS.keys()
	if args.has("types"):
		types = str(args.types).split(",")
	for type: String in types:
		frames.clear()
		g.cards.intro_card({ "side": side, "type": type }, 0, 1) # runs up to its first await: the stage exists now
		scene = g.cards.intro_stage
		if scene == null:
			printerr("[intro] no IntroStage for %s" % type)
			quit(1)
			return
		scene.phase_changed.connect(_on_phase)
		var t0 := Time.get_ticks_msec()
		await scene.finished
		print("[intro] %s %d ms" % [type, Time.get_ticks_msec() - t0])
		await _grab("end")
		var path := "%s/intro_%s.png" % [out, type]
		if frames.size() == GRABS.size():
			save_sheet(frames, GRABS.size(), path, "intro")
		else:
			printerr("[intro] %s: %d frames" % [type, frames.size()])
		g.cards.intro_closed.emit()
		for i in 30:
			await process_frame
		if g.cards.intro_layer != null:
			printerr("[intro] %s: card did not close" % type)
	quit()

func _on_phase(phase: String) -> void:
	if phase == "reach":
		await create_timer(0.3).timeout
		await _grab("reach")
	elif phase == "hit":
		await create_timer(0.12).timeout
		await _grab("hit")

## the card only, on its own frame
func _grab(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var card: Control = scene.get_meta("card")
	var k := Vector2(img.get_size()) / root.get_visible_rect().size
	var r := card.get_global_rect()
	var box := Rect2i(Vector2i(r.position * k), Vector2i(r.size * k)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var f := img.get_region(box)
	if not frames.is_empty() and f.get_size() != frames[0].get_size():
		f.resize(frames[0].get_width(), frames[0].get_height())
	frames.append(f)
	print("[intro] grab ", tag)
