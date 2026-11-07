class_name Main
extends Control
## app shell: theme, audio, menus (title / campaign / skirmish / 1 vs 1 / codex), the game screen, debug flags.
## debug args (after `--`): mission=m01 (start it) bot (AI plays our side) speed=3
##   fresh (ignore save) screen=title|campaign|skirmish|duel|codex shots=DIR (png every shot_every s) shot_every=2 quit_at=60

const BASE := Vector2(1280, 720)
const MIN_SCALE := 0.8

var audio: Audio
var menus: Menus
var game: GameScreen
var flags := { }
var _shot_t := 0.0
var _shot_n := 0
var _t := 0.0
var _rotate: Control

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
	if flags.has("norig"): # norig: every attack uses the old FX.attack instead of the code-rigged animation
		Rigs.enabled = false
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
	game = GameScreen.new()
	game.main = self
	add_child(game)
	menus.add_overlays() # codex sits above the game screen
	if flags.has("speed"):
		FX.speed = str(flags.speed).to_float()
	if flags.has("fresh"):
		Store.clear_game()
	_build_rotate_hint()
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
	var icon := Style.lbl("🔄", 64, Style.GOLD, Style.display_x)
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
		var mid := str(flags.mission)
		var md: Dictionary = Content.mission(mid)
		var mctx := { "kind": "campaign", "id": flags.mission }
		start_game(Game.new_game(md), mctx)
		return
	var sc: String = flags.get("screen", "title")
	if sc.begins_with("campaign"):
		menus.show_campaign(sc.split(":")[1] if ":" in sc else "")
	elif sc == "skirmish":
		menus.show_skirmish()
	elif sc == "duel":
		menus.show_duel()
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

## campaign mission entered fresh (map / next mission)
func play_mission(m: Dictionary) -> void:
	var mid: String = m.id
	menus.confirm_start(Game.new_game(m), { "kind": "campaign", "id": mid })

func show_skirmish() -> void:
	game.leave()
	menus.show_skirmish()

func show_duel() -> void:
	game.leave()
	menus.show_duel()

## ctx = {kind:'campaign', id} | {kind:'skirmish', hero, easy, map, gold, cap} | {kind:'duel', map, hero, heroE, ctrlE, gold, cap}
func start_game(state: Dictionary, ctx: Dictionary) -> void:
	menus.hide_all()
	game.start(state, ctx)

func _unhandled_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k != null and k.pressed and k.keycode == KEY_ESCAPE:
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
			_shot_t = str(flags.get("shot_every", "2")).to_float()
			shot(str(flags.get("tag", "s")) + "_%03d" % _shot_n)
			_shot_n += 1
	if flags.has("quit_at") and _t >= str(flags.quit_at).to_float():
		get_tree().quit()

func shot(shot_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return # nothing is rendered (and frame_post_draw never fires)
	await RenderingServer.frame_post_draw
	var dir: String = flags.get("shots", "res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var err := get_viewport().get_texture().get_image().save_png(dir.path_join(shot_name + ".png"))
	if err != OK:
		push_warning("shot: save %s failed (%s)" % [shot_name, error_string(err)])
