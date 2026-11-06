extends SceneTree
## shared boilerplate of the probes that drive the real game (rig_live, rig_sheet, rig_smoke, attack_fx, hud_shot,
## units_shot, income_shot): boot main.tscn, wait for the game + boot_wait s, args = main.flags (every k=v after --),
## then await _run(game). Subclass: `extends "res://sim/probes/probe_base.gd"` and override _run.

const DIRS := { "right": Vector2i(1, 0), "left": Vector2i(-1, 0), "up": Vector2i(0, -1), "down": Vector2i(0, 1),
	"ur": Vector2i(1, -1), "dr": Vector2i(1, 1), "ul": Vector2i(-1, -1), "dl": Vector2i(-1, 1) }

var main: Main
var args := {}
var boot_wait := 1.5 # s after the game is up (fonts, atlas, first bake)
var timeout_ms := 0 # > 0: quit(1) past this wall time (a script error must not hang a guarded run)

func _initialize() -> void:
	var scn: PackedScene = load("res://main.tscn")
	main = scn.instantiate()
	root.add_child(main)
	_boot.call_deferred()

func _process(_dt: float) -> bool:
	if timeout_ms > 0 and Time.get_ticks_msec() > timeout_ms:
		printerr("[probe] timeout")
		quit(1)
	return false

func _boot() -> void:
	args = main.flags
	while main.game == null or main.game.s.is_empty():
		await process_frame
	await create_timer(boot_wait).timeout
	await _run(main.game)

func _run(_g: GameScreen) -> void:
	await process_frame # coroutine like the overrides, so `await _run()` is never redundant
	quit()

## s.units read fresh (Game swaps the array when a unit dies)
static func units_of(s: Dictionary) -> Array:
	return s.units

## unit tile
static func pos(u: Dictionary) -> Vector2i:
	var x: int = u.x
	var y: int = u.y
	return Vector2i(x, y)

## park every unit within r tiles (manhattan) of at in the corner, except the ids in keep
static func clear_around(s: Dictionary, at: Vector2i, r: int, keep: Array) -> void:
	for u: Dictionary in s.units:
		var p := pos(u)
		if not keep.has(u.id) and absi(p.x - at.x) + absi(p.y - at.y) <= r:
			u.x = 0
			u.y = 0

## attacker a on tile ax, defender d on dx, plain ground under both, board redrawn
static func stage(g: GameScreen, a: Dictionary, d: Dictionary, ax: Vector2i, dx: Vector2i) -> void:
	var s: Dictionary = g.s
	a.x = ax.x; a.y = ax.y
	d.x = dx.x; d.y = dx.y
	for c: Vector2i in [ax, dx]:
		s.tiles[c.y][c.x] = "."
	refresh_terrain(g)
	g.refresh()

## g.board is Board (2D) or Board3D; no shared base method for these
static func refresh_terrain(g: GameScreen) -> void:
	if g.board is Board3D:
		(g.board as Board3D).refresh_terrain()
	else:
		(g.board as Board).refresh_terrain()

static func tile_rect(g: GameScreen, x: int, y: int) -> Rect2:
	if g.board is Board3D:
		return (g.board as Board3D).tile_rect(x, y)
	return (g.board as Board).tile_rect(x, y)

## black-on-white caption over everything (frame time on a contact sheet)
func ms_label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 6)
	var cl := CanvasLayer.new()
	cl.layer = 100
	cl.add_child(label)
	root.add_child(cl)
	return label

## frames laid out cols per row on a dark sheet -> out (png); prints "[tag] out n frames"
static func save_sheet(frames: Array[Image], cols: int, out: String, tag: String) -> void:
	var w := frames[0].get_width()
	var h := frames[0].get_height()
	var rows := ceili(frames.size() / float(cols))
	var sheet := Image.create(w * cols + (cols - 1) * 4, h * rows + (rows - 1) * 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.13, 0.13, 0.13))
	for k in frames.size():
		var f := frames[k]
		f.convert(Image.FORMAT_RGBA8)
		@warning_ignore("integer_division")
		sheet.blit_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i((k % cols) * (w + 4), (k / cols) * (h + 4)))
	DirAccess.make_dir_recursive_absolute(out.get_base_dir()) # a failure shows as the save_png error
	var err := sheet.save_png(out)
	if err != OK:
		push_error("[%s] cannot write %s: %s" % [tag, out, error_string(err)])
	print("[%s] %s %d frames" % [tag, out, frames.size()])
