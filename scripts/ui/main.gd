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
	var args := Array(OS.get_cmdline_user_args())
	if OS.has_feature("web"):
		# web: same debug flags from the page URL, e.g. index.html?screen=campaign&speed=3
		var q: Variant = JavaScriptBridge.eval("window.location.search", true)
		if q is String and q.length() > 1:
			args += Array(q.substr(1).split("&"))
	for a: String in args:
		var kv := a.uri_decode().split("=")
		flags[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if flags.has("profile"): # profile=test: settings / progress / save kept apart from the player's
		Store.use_profile(str(flags.profile))
	if flags.has("3d"): # 3d=1 / 3d=0: board renderer for this run
		Store.board3d_flag = 0 if str(flags["3d"]) == "0" else 1
	if flags.has("figstyle"): # figstyle=<dir>: full-colour figures from assets/units/styles/<dir> (art preview)
		Token.fig_style = str(flags.figstyle)
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
	_build_rotate_hint()
	get_window().size_changed.connect(_fit_scale)
	_fit_scale()
	_boot()

# ---------- screen scale ----------
## canvas_items stretch scales the 1280x720 base by min(w/1280, h/720); on small windows that makes 13 px text ~6 px.
## Never let the UI shrink below MIN_SCALE: the layout gets a smaller logical area instead (menus scroll, board fits).
const BASE := Vector2(1280, 720)
const MIN_SCALE := 0.8
var _rotate: Control

func _fit_scale() -> void:
	var w := get_window()
	var px := Vector2(w.size)
	var auto := minf(px.x / BASE.x, px.y / BASE.y)
	w.content_scale_factor = maxf(1.0, MIN_SCALE / maxf(auto, 0.01))
	if _rotate:
		_rotate.visible = px.y > px.x * 1.1 # portrait phone: ask to turn the screen

func _build_rotate_hint() -> void:
	_rotate = ColorRect.new()
	(_rotate as ColorRect).color = Style.LACQUER
	_rotate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotate.mouse_filter = Control.MOUSE_FILTER_STOP
	_rotate.z_index = 200
	_rotate.visible = false
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := Style.vbox(14)
	var icon := Style.lbl("⟳", 64, Style.GOLD, Style.display_x)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(icon)
	var t := Style.lbl("Xoay ngang màn hình để chơi", 22, Style.INK, Style.display)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := Style.lbl("Bàn cờ cần khổ ngang.", 15, Style.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	c.add_child(v)
	_rotate.add_child(c)
	add_child(_rotate)

func _boot() -> void:
	if flags.has("mission"):
		start_game(Game.new_game(Content.mission(flags.mission)), { "kind": "campaign", "id": flags.mission })
		return
	var sc: String = flags.get("screen", "title")
	if sc.begins_with("briefing"):
		menus.show_briefing(Content.mission(sc.split(":")[1] if ":" in sc else "m01"))
	elif sc.begins_with("campaign"):
		menus.show_campaign(sc.split(":")[1] if ":" in sc else "")
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

func show_campaign(chapter_id := "") -> void:
	game.leave()
	menus.show_campaign(chapter_id)

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
	if DisplayServer.get_name() == "headless":
		return # nothing is rendered (and frame_post_draw never fires)
	await RenderingServer.frame_post_draw
	var dir: String = flags.get("shots", "res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
