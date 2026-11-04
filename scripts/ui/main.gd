class_name Main
extends Control
## app shell: theme, audio, menus (title / campaign / briefing / skirmish / codex), the game screen, debug flags.
## debug args (after `--`): mission=m01 (start it) bot (AI plays our side) speed=3 fresh (ignore save)
##   screen=title|campaign|briefing:m03|skirmish|codex shots=DIR (png every shot_every s) shot_every=2 quit_at=60

var audio: Audio
var menus: Menus
var game: GameScreen
var flags := {}
var _shot_t := 0.0
var _shot_n := 0
var _t := 0.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		flags[kv[0]] = kv[1] if kv.size() > 1 else "1"
	EmojiFont.attach([Style.body, Style.semi, Style.bold, Style.xbold, Style.display, Style.display_x])
	theme = Style.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RenderingServer.set_default_clear_color(Style.LACQUER)
	audio = Audio.new()
	add_child(audio)
	menus = Menus.new()
	menus.main = self
	add_child(menus)
	game = GameScreen.new()
	game.main = self
	add_child(game)
	menus.add_overlays() # codex sits above the game screen
	if flags.has("speed"):
		FX.speed = float(flags.speed)
	if flags.has("fresh"):
		Store.clear_game()
	_boot()

func _boot() -> void:
	if flags.has("mission"):
		start_game(Game.new_game(Content.mission(flags.mission)), { "kind": "campaign", "id": flags.mission })
		return
	var sc: String = flags.get("screen", "title")
	if sc.begins_with("briefing"):
		menus.show_briefing(Content.mission(sc.split(":")[1] if ":" in sc else "m01"))
	elif sc == "campaign":
		menus.show_campaign()
	elif sc == "skirmish":
		menus.show_skirmish()
	elif sc == "codex":
		menus.show_title()
		menus.open_codex("p")
	else:
		menus.show_title()

# ---------- navigation (menus and the game screen call these) ----------
func show_title() -> void:
	game.leave()
	menus.show_title()

func show_campaign() -> void:
	game.leave()
	menus.show_campaign()

func show_briefing(m: Dictionary) -> void:
	game.leave()
	menus.show_briefing(m)

func show_skirmish() -> void:
	game.leave()
	menus.show_skirmish()

## ctx = {kind:'campaign', id} | {kind:'skirmish', hero, easy}
func start_game(state: Dictionary, ctx: Dictionary) -> void:
	menus.hide_all()
	game.start(state, ctx)

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		if menus.is_codex_open():
			menus.close_codex()
		elif game.visible:
			game.cancel()
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	_t += dt
	if flags.has("shots"):
		_shot_t -= dt
		if _shot_t <= 0.0:
			_shot_t = float(flags.get("shot_every", "2"))
			shot(flags.get("tag", "s") + "_%03d" % _shot_n)
			_shot_n += 1
	if flags.has("quit_at") and _t >= float(flags.quit_at):
		get_tree().quit()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir: String = flags.get("shots", "res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
