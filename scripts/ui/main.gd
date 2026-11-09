class_name Main
extends Control
## app shell: theme, audio, menus (title / levels / skirmish / 1 vs 1 / codex), the game screen, debug flags.
## debug args (after `--`): mission=m01 (start it) bot (AI plays our side) speed=3
##   fresh (ignore save) screen=title|levels|skirmish|duel|codex shots=DIR (png every shot_every s) shot_every=2 quit_at=60 crash_at=5
##   sfxlog (print each sound + frame; tools/record_sfx_scene.sh)

const BASE := Vector2(1280, 720)
const MIN_SCALE := 0.8

## set by switch_lang before reloading the scene: reopen the saved game instead of the title
static var _resume_after_reload := false

var audio: Audio
var menus: Menus
var game: GameScreen
var flags := { }
var _shot_t := 0.0
var _shot_n := 0
var _t := 0.0

func _ready() -> void:
	var args := Array(OS.get_cmdline_user_args())
	if OS.has_feature("web"):
		# web: same debug flags from the page URL, e.g. index.html?screen=campaign&speed=3
		var q: Variant = JavaScriptBridge.eval("window.location.search", true)
		if q is String:
			var qs: String = q
			if qs.length() > 1:
				args += Array(qs.substr(1).split("&"))
	for a: String in args:
		var kv := a.uri_decode().split("=")
		flags[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if flags.has("profile"): # profile=test: settings / progress / save kept apart from the player's
		Store.use_profile(str(flags.profile))
	# language: debug flag lang=vi|en > the player's pick > the device language (scripts/core/lang.gd)
	Lang.apply(str(flags.get("lang", Store.get_v("lang", Lang.device_default()))))
	GameLog.boot(str(flags.get("profile", "")), args) # crash / error log per session (README "Log lỗi / crash")
	MatchRec.boot(str(flags.get("profile", "")), flags.has("bot")) # match replays (README "Ghi trận / phân tích")
	if flags.has("sfxlog"): # sfxlog: print every sound played with its frame (docs/design scene)
		Audio.log_sfx = true
	if flags.has("norig"): # norig: every attack uses the old FX.attack instead of the code-rigged animation
		Rigs.enabled = false
	if flags.has("sprite"): # TRY: start with the sprite-gen commander (docs/sprite_gen_try.md; F8 toggles live)
		Token.sprite_hero = true
	if flags.has("safe"): # safe=l,t,r,b: preview a phone's hidden edges (notch / rounded corners) on desktop
		var sp := str(flags.safe).split(",")
		if sp.size() == 4:
			Style.safe_override = Vector4(float(sp[0]), float(sp[1]), float(sp[2]), float(sp[3]))
	if flags.has("figstyle"): # figstyle=<dir> art set; figstyle=off -> silhouettes + procedural terrain
		Token.fig_style = "" if str(flags.figstyle) == "off" else str(flags.figstyle)
	EmojiFont.attach([Style.body, Style.semi, Style.bold, Style.xbold, Style.display, Style.display_x])
	theme = Style.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RenderingServer.set_default_clear_color(Style.LACQUER)
	audio = Audio.new()
	add_child(audio)
	menus = Menus.new()
	menus.main = self
	add_child(menus)
	process_mode = Node.PROCESS_MODE_ALWAYS # menus, audio, codex, debug flags run through the ⚙ pause
	game = GameScreen.new()
	game.main = self
	game.process_mode = Node.PROCESS_MODE_PAUSABLE # only the game screen stops (GameHud.show_menu)
	add_child(game)
	menus.add_overlays() # codex sits above the game screen
	if flags.has("speed"):
		FX.speed = str(flags.speed).to_float()
	if flags.has("fresh"):
		Store.clear_game()
	get_window().size_changed.connect(_fit_scale)
	_fit_scale()
	_boot()

# ---------- screen scale ----------
## canvas_items stretch scales the 1280x720 base by min(w/1280, h/720); on small windows that makes 13 px text ~6 px.
## Never let the UI shrink below MIN_SCALE: the layout gets a smaller logical area instead (menus scroll, board fits).

func _fit_scale() -> void:
	var w := get_window()
	var px := Vector2(w.size)
	var auto := minf(px.x / BASE.x, px.y / BASE.y)
	# portrait: scale as if the base were 720x1280 (a 1280-wide canvas on a phone held upright = unreadable text)
	var want := minf(px.x / BASE.y, px.y / BASE.x) if px.y > px.x else auto
	w.content_scale_factor = maxf(want / maxf(auto, 0.01), MIN_SCALE / maxf(auto, 0.01))

func _boot() -> void:
	GameLog.crumb("boot flags=%s" % [flags])
	if _resume_after_reload:
		_resume_after_reload = false
		var sv: Variant = Store.load_game()
		if sv != null:
			var d: Dictionary = sv
			var st: Dictionary = d.state
			var c: Dictionary = d.ctx
			start_game(st, c)
			return
	if flags.has("mission"):
		var mid := str(flags.mission)
		var md: Dictionary = Content.level(mid)
		var mctx := { "kind": "campaign", "id": flags.mission }
		start_game(Game.new_game(md), mctx)
		return
	var sc: String = flags.get("screen", "title")
	if sc == "levels":
		menus.show_levels()
	elif sc == "duel":
		menus.show_duel()
	elif sc == "codex":
		menus.show_title()
		menus.open_codex("p")
	else:
		menus.show_title()

# ---------- navigation (menus and the game screen call these) ----------
func show_title() -> void:
	GameLog.crumb("screen title")
	game.leave()
	menus.show_title()

func show_levels(focus_id := "") -> void:
	GameLog.crumb("screen levels")
	game.leave()
	menus.show_levels(focus_id)

## level entered fresh (grid / next level)
func play_mission(m: Dictionary) -> void:
	var mid: String = m.id
	menus.confirm_start(Game.new_game(m), { "kind": "campaign", "id": mid })

func show_duel() -> void:
	GameLog.crumb("screen duel")
	game.leave()
	menus.show_duel()

## ctx = {kind:'campaign', id} | {kind:'skirmish', hero, easy, map, gold, cap} | {kind:'duel', map, hero, heroE, ctrlE, gold, cap}
## next language in Lang.SUPPORTED, saved as the player's pick; every screen is built in the old language, so the
## whole scene reloads (back into the saved game when called from one)
func switch_lang(resume_game: bool) -> void:
	var i := Lang.SUPPORTED.find(Lang.current)
	var code: String = Lang.SUPPORTED[(i + 1) % Lang.SUPPORTED.size()]
	Store.set_v("lang", code)
	if resume_game:
		game.save()
		_resume_after_reload = true
	get_tree().paused = false
	PauseClock.hold(false) # static: would stay frozen across the reload when switched from the ⚙ menu
	get_tree().reload_current_scene()

func start_game(state: Dictionary, ctx: Dictionary) -> void:
	GameLog.crumb("game start turn=%s side=%s ctx=%s" % [state.get("turn"), state.get("side"), ctx])
	menus.hide_all()
	game.start(state, ctx)

## clean-exit / background markers for the session log (no marker at the end = crash)
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		GameLog.mark(GameLog.CLEAN)
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		GameLog.mark(GameLog.PAUSED)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		GameLog.mark(GameLog.RESUMED)
	elif what == NOTIFICATION_CRASH:
		GameLog.crumb("engine crash handler fired")

func _unhandled_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k != null and k.pressed and k.keycode == KEY_ESCAPE:
		if menus.is_codex_open():
			menus.close_codex()
		elif game.visible:
			game.cancel()
		get_viewport().set_input_as_handled()
	elif k != null and k.pressed and not k.echo and k.keycode == KEY_F8: # TRY: sprite-gen commander <-> SVG rig
		Token.sprite_hero = not Token.sprite_hero
		print("sprite_hero = ", Token.sprite_hero)
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	_t += dt
	if flags.has("shots"):
		_shot_t -= dt
		if _shot_t <= 0.0:
			_shot_t = str(flags.get("shot_every", "2")).to_float()
			shot(str(flags.get("tag", "s")) + "_%03d" % _shot_n)
			_shot_n += 1
	if flags.has("quit_at") and _t >= str(flags.quit_at).to_float():
		get_tree().quit()
	if flags.has("crash_at") and _t >= str(flags.crash_at).to_float(): # crash_at=5: test the crash log (README)
		OS.crash("crash_at flag")

func shot(shot_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return # nothing is rendered (and frame_post_draw never fires)
	await RenderingServer.frame_post_draw
	var dir: String = flags.get("shots", "res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var err := get_viewport().get_texture().get_image().save_png(dir.path_join(shot_name + ".png"))
	if err != OK:
		push_warning("shot: save %s failed (%s)" % [shot_name, error_string(err)])
