class_name Menus
extends Control
## menu screens over the animated backdrop: title, levels (Thử thách grid), skirmish, 1 vs 1,
## plus the codex overlay (added above the game screen). Port of the menu half of src/ui/screens.js + shell.html.

signal codex_closed

const LOGO_SHADER := preload("res://shaders/logo.gdshader")
const TITLE_SIZE := Vector2(1000, 560) # title stage, scaled to fit the window
## 1 vs 1: who plays Blue (s.ctrl.e)
## Khó = ai:army (hard v5b, varied army) = strongest offered; ai:hard (v3b) no longer offered (user 2026-11-09), old saves still load
## labels go through Lang.t where shown (i18n-const)
const OPPONENTS := [["human", "Người"], ["ai:easy", "Máy Dễ"], ["ai:normal", "Máy Trung bình"], ["ai:army", "Máy Khó"]]

var main: Main
var bg: MenuBg
var root: Control # current page lives here
var page: Control = null
var codex: Control = null
var codex_side := "p"
var hero_choice := ""
var easy := true
var sk_gold := 500 # AE2 skirmish defaults: starting gold 500, unit cap 10
var sk_cap := 10
var map_choice := "dong_bang"
var duel_opts := { "map": "dong_bang", "gold": 500, "cap": 10, "hero": "", "heroE": "", "ctrlE": "human" }
var _codex_card: Control
var _codex_grid: GridContainer
var _codex_seg: Array = []

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg = MenuBg.new()
	add_child(bg)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	hero_choice = Content.heroes_of("p")[0]
	resized.connect(_fit_safe)

## pages stay out of the phone's notch / rounded corners (backdrop still fills the screen)
func _fit_safe() -> void:
	var e := Style.safe_insets(self)
	root.offset_left = e.x
	root.offset_top = e.y
	root.offset_right = -e.z
	root.offset_bottom = -e.w

# ---------- helpers ----------
func _sfx(sfx: String) -> void:
	if main and main.audio:
		main.audio.play(sfx)

func _on(b: BaseButton, fn: Callable, sound := "ui") -> BaseButton:
	b.pressed.connect(
		func() -> void:
			_sfx(sound)
			fn.call(),
	)
	return b

## fresh scrolling page, content centred at max_w; center_v = title-style vertical centring
func _page(max_w := 1040.0, center_v := false) -> VBoxContainer:
	visible = true
	bg.visible = true
	if page:
		page.queue_free()
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var mc := MarginContainer.new()
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(mc)
	var v := Style.vbox(18)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if center_v:
		v.alignment = BoxContainer.ALIGNMENT_CENTER
	mc.add_child(v)
	var fit := func() -> void:
		# margins from the screen width, never from sc.size: the margins feed sc's own minimum width, so measuring sc
		# made them grow without end after a scale change (page 600 000 px wide, nothing visible)
		var avail: float = root.size.x if root else sc.size.x
		var m := maxf(16.0, floorf((avail - max_w - 12.0) / 2.0)) # 12: room for the vertical scrollbar
		mc.add_theme_constant_override("margin_left", int(m))
		mc.add_theme_constant_override("margin_right", int(m))
		mc.add_theme_constant_override("margin_top", 28)
		mc.add_theme_constant_override("margin_bottom", 28)
		if center_v:
			mc.custom_minimum_size.y = (root.size.y if root else sc.size.y) - 1
	sc.resized.connect(fit)
	if root:
		root.resized.connect(fit)
		sc.tree_exiting.connect(
			func() -> void:
				root.resized.disconnect(fit),
		)
	root.add_child(sc)
	page = sc
	# enter: fade + slide up 14px
	sc.modulate.a = 0.0
	sc.offset_top = 14
	sc.offset_bottom = 14
	var tw := sc.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(sc, "modulate:a", 1.0, 0.45)
	tw.tween_property(sc, "offset_top", 0.0, 0.45)
	tw.tween_property(sc, "offset_bottom", 0.0, 0.45)
	return v

func _eyebrow(text: String, fs := 12) -> Label:
	var f := FontVariation.new()
	f.base_font = Style.bold
	f.spacing_glyph = 2
	return Style.lbl(text.to_upper(), fs, Style.ROYAL, f)

func _h2(text: String, fs := 30) -> Label:
	return Style.lbl(text, fs, Style.GOLD, Style.display)

func _head(back_text: String, back_fn: Callable, title := "") -> HBoxContainer:
	var h := Style.hbox(14)
	h.add_child(_on(Style.button(back_text, "BackBtn"), back_fn))
	if title != "":
		h.add_child(_h2(title))
	return h

## clickable glass card (mission / hero pick): hover = gold border; hot = gold border + soft glow
func _click_card(content: Control, on_click: Callable, enabled := true, hot := false, pulse := false) -> PanelContainer:
	var p := PanelContainer.new()
	var normal := Style.paper(14.0)
	normal.frame = false
	normal.shadow = Vector2(4, 4)
	var hover: SkinBox = normal.duplicate()
	hover.shift = Vector2(-1, -1)
	hover.shadow = Vector2(6, 6)
	hover.face = Style.PAPER_HI
	if hot:
		normal = normal.duplicate()
		normal.face = Color("#f6dc8e")
		normal.inner = Style.CRIMSON
		hover = normal
		if pulse:
			var tw := p.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
			tw.tween_property(normal, "face", Color("#fbe7a8"), 1.2)
			tw.tween_property(normal, "face", Color("#f6dc8e"), 1.2)
	p.add_theme_stylebox_override("panel", normal)
	p.add_child(content)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ignore_mouse(content)
	if enabled:
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.mouse_entered.connect(
			func() -> void:
				p.add_theme_stylebox_override("panel", hover),
		)
		p.mouse_exited.connect(
			func() -> void:
				p.add_theme_stylebox_override("panel", normal),
		)
		p.gui_input.connect(
			func(ev: InputEvent) -> void:
				var mb := ev as InputEventMouseButton
				if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
					on_click.call(),
		)
	else:
		p.modulate = Color(0.75, 0.75, 0.75, 0.5)
	return p

func _ignore_mouse(n: Node) -> void:
	for c: Node in n.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(c)

## auto-fill grid: column count follows the width (CSS repeat(auto-fill, minmax(min_w, 1fr)));
## auto_fit = never more columns than children (CSS auto-fit collapses the empty tracks)
func _grid(min_w: float, gap := 12, auto_fit := false) -> GridContainer:
	var g := GridContainer.new()
	g.add_theme_constant_override("h_separation", gap)
	g.add_theme_constant_override("v_separation", gap)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.resized.connect(
		func() -> void:
			var n := maxi(1, int((g.size.x + gap) / (min_w + gap)))
			if auto_fit:
				n = clampi(g.get_child_count(), 1, n)
			if n != g.columns:
				g.columns = n,
	)
	g.columns = 4
	return g

# ---------- title ----------
## title: fixed stage (no scroll) laid out at TITLE_SIZE and scaled to the window; logo on top, menu left,
## castle + units right, round sound / music / speed / unit-book toggles under the menu
func show_title() -> void:
	visible = true
	bg.visible = true
	if page:
		page.queue_free()
	var th := Content.theme()
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	page = holder
	var stage := Control.new()
	stage.size = TITLE_SIZE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(stage)
	var fit := func() -> void:
		var k := clampf(minf(holder.size.x / TITLE_SIZE.x, holder.size.y / TITLE_SIZE.y), 0.5, 1.6)
		stage.scale = Vector2(k, k)
		stage.position = ((holder.size - TITLE_SIZE * k) / 2.0).floor()
	holder.resized.connect(fit)
	fit.call_deferred()
	var art := TitleArt.new()
	art.position = Vector2(420, 150)
	art.size = Vector2(580, 400)
	stage.add_child(art)
	var top := Style.vbox(0)
	top.position = Vector2(0, 10)
	top.size = Vector2(TITLE_SIZE.x, 0)
	stage.add_child(top)
	var tagline: String = th.tagline
	var eb := _eyebrow(tagline, 13)
	eb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(eb)
	var title: String = th.title
	var logo := _logo(title, 84)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(logo)
	var lede := Style.lbl(str(th.lede), 16, Style.INK, Style.semi) # premise line (docs/setting.md)
	lede.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(lede)
	var list := Style.vbox(10)
	list.position = Vector2(60, 168)
	list.size = Vector2(340, 0)
	stage.add_child(list)
	var camp := Content.levels()
	var nx := LevelSelect.first_unwon(camp, Store.unlocked_index())
	var prog := (Lang.t("Màn %d/%d") % [nx + 1, camp.size()]) if nx < camp.size() else Lang.t("Đã thắng hết")
	var sv: Variant = Store.load_game()
	if sv != null:
		var svd: Dictionary = sv
		var sst: Dictionary = svd.state
		list.add_child(
			_on(
				Style.menu_button(Lang.t("Đánh tiếp ván đang dở"), Lang.t("%s · lượt %d") % [_saved_title(svd), sst.turn], true),
				func() -> void:
					var s2: Variant = Store.load_game()
					if s2 != null:
						var d2: Dictionary = s2
						var st2: Dictionary = d2.state
						var ctx2: Dictionary = d2.ctx
						main.start_game(st2, ctx2),
			)
		)
	list.add_child(_on(Style.menu_button(Lang.t("Thử thách"), prog, sv == null), show_levels))
	list.add_child(_on(Style.menu_button(Lang.t("Đấu tự do")), show_skirmish))
	list.add_child(_on(Style.menu_button(Lang.t("1 đấu 1")), show_duel))
	var tg := Style.hbox(18)
	tg.position = Vector2(60, 462)
	stage.add_child(tg)
	var snd := _round(tg, Lang.t("Âm thanh"))
	var mus := _round(tg, Lang.t("Nhạc"))
	var spd := _round(tg, Lang.t("Tốc độ"))
	var book := _round(tg, Lang.t("Sách lính"))
	var lang := _round(tg, Lang.t("Ngôn ngữ"))
	lang.text = Lang.current.to_upper()
	lang.tooltip_text = Lang.NAMES[Lang.current]
	_on(
		lang,
		func() -> void:
			if main:
				main.switch_lang(false),
	)
	book.icon = Icons.tex("book")
	var about := _round(tg, Lang.t("Giới thiệu"))
	about.icon = Icons.tex("scroll")
	_on(about, show_credits)
	spd.tooltip_text = Lang.t("Tốc độ hoạt cảnh x1 / x2 / x3")
	var sync := func() -> void:
		var snd_on := main == null or not main.audio.muted
		var mus_on := main == null or main.audio.music_on
		snd.icon = Icons.tex("sound" if snd_on else "mute")
		mus.icon = Icons.tex("music" if mus_on else "music_off")
		snd.theme_type_variation = "RoundOn" if snd_on else "RoundOff"
		mus.theme_type_variation = "RoundOn" if mus_on else "RoundOff"
		snd.tooltip_text = Lang.t("Âm thanh: %s") % (Lang.t("bật") if snd_on else Lang.t("tắt"))
		mus.tooltip_text = Lang.t("Nhạc: %s") % (Lang.t("bật") if mus_on else Lang.t("tắt"))
		spd.text = "x%d" % int(FX.speed)
	_on(
		spd,
		func() -> void:
			FX.speed = 2.0 if FX.speed == 1.0 else (3.0 if FX.speed == 2.0 else 1.0)
			Store.set_v("speed", FX.speed)
			sync.call(),
	)
	_on(
		snd,
		func() -> void:
			if main and main.audio:
				main.audio.set_muted(not main.audio.muted)
			sync.call(),
	)
	_on(
		mus,
		func() -> void:
			if main and main.audio:
				main.audio.set_music(not main.audio.music_on)
			sync.call(),
	)
	_on(
		book,
		func() -> void:
			open_codex(),
	)
	sync.call()
	# enter: fade + slide up 14px
	holder.modulate.a = 0.0
	holder.offset_top = 14
	holder.offset_bottom = 14
	var tw := holder.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "modulate:a", 1.0, 0.45)
	tw.tween_property(holder, "offset_top", 0.0, 0.45)
	tw.tween_property(holder, "offset_bottom", 0.0, 0.45)

## a saved game's name in the current language (the save keeps the title as it was when saved)
func _saved_title(svd: Dictionary) -> String:
	var c: Dictionary = svd.get("ctx", { })
	if c.get("kind") == "campaign":
		var m: Variant = Content.level(str(c.get("id", "")))
		if m != null:
			var md: Dictionary = m
			return str(md.get("title", ""))
	return Lang.t(svd.get("title", ""))

## round toggle (RoundOn face) with a small caption under it
func _round(parent: Control, caption: String) -> Button:
	var col := Style.vbox(4)
	parent.add_child(col)
	var b := Style.button("", "RoundOn")
	b.tooltip_text = caption
	b.custom_minimum_size = Vector2(56, 56)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 28)
	col.add_child(b)
	var l := Style.lbl(caption, 14, Style.INK, Style.bold)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	return b

func _logo(text: String, fs := 104) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow := Style.lbl(text, fs, Color("#4a2c0e"), Style.display_x)
	var glow := Style.lbl(text, fs, Color(Style.GOLD, 0.0), Style.display_x)
	glow.add_theme_color_override("font_shadow_color", Color(Style.GOLD, 0.16))
	glow.add_theme_constant_override("shadow_outline_size", 24)
	glow.add_theme_constant_override("shadow_offset_y", 0)
	var gold := Style.lbl(text, fs, Color.WHITE, Style.display_x)
	var mat := ShaderMaterial.new()
	mat.shader = LOGO_SHADER
	gold.material = mat
	for l: Label in [glow, shadow, gold]:
		holder.add_child(l)
	shadow.position = Vector2(0, 3)
	# label size is only known once it is laid out in the tree
	gold.resized.connect(
		func() -> void:
			mat.set_shader_parameter("width", gold.size.x)
			holder.custom_minimum_size = gold.size + Vector2(0, 3),
	)
	return holder

# ---------- credits ----------
## "Giới thiệu": makers + asset credits + Godot notice (licence obligations); full licence texts on a 2nd page
func show_credits() -> void:
	var v := _page(760)
	v.add_child(
		_head(
			Lang.t("‹ Trở lại"),
			func() -> void:
				main.show_title(),
			Lang.t("Giới thiệu"),
		)
	)
	var head := Style.vbox(2)
	head.add_child(_h2(str(Content.theme().title), 26))
	head.add_child(Style.lbl(Lang.t("Phiên bản %s") % ProjectSettings.get_setting("application/config/version", ""), 14, Style.MUTED))
	v.add_child(_credit_card([head]))
	for sec: Array in Credits.sections():
		var lines: Array = sec[1]
		var kids: Array = [_eyebrow(str(sec[0]), 13)]
		for line: String in lines:
			kids.append(Style.lbl(line, 15, Style.INK, Style.body, true))
		v.add_child(_credit_card(kids))
	v.add_child(_credit_card([_eyebrow(Lang.t("Giấy phép Godot Engine"), 13), Style.lbl(Credits.godot_notice(), 12, Style.INK, Style.body, true)]))
	var more := _on(Style.button(Lang.t("📜 Toàn văn giấy phép"), "ActBtn"), show_licenses)
	more.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(more)

## every licence text in full (OFL, Apache, Godot third-party), one card per licence
func show_licenses() -> void:
	var v := _page(760)
	v.add_child(_head(Lang.t("‹ Trở lại"), show_credits, Lang.t("Giấy phép")))
	for block: Array in Credits.full_texts():
		v.add_child(_credit_card([_eyebrow(str(block[0]), 13), Style.lbl(str(block[1]), 12, Style.INK, Style.body, true)]))

func _credit_card(kids: Array) -> PanelContainer:
	var c := Style.card()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := Style.vbox(8)
	c.add_child(col)
	for k: Control in kids:
		col.add_child(k)
	return c

# ---------- campaign ----------
## "Thử thách" kingdom map (WorldMap), centred on `focus_id` or the next level; full screen (a page scroll would eat
## the map's drag), only a back button on top (user 2026-11-08)
func show_levels(focus_id := "") -> void:
	visible = true
	bg.visible = true
	if page:
		page.queue_free()
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	page = holder
	var all := Content.levels()
	var wm := WorldMap.new()
	holder.add_child(wm)
	wm.setup(all, Store.unlocked_index(), focus_id)
	wm.level_picked.connect(
		func(id: String) -> void:
			_sfx("ui")
			var md: Dictionary = Content.level(id)
			main.play_mission(md),
	)
	var e := Style.safe_insets(holder)
	var back := _on(
		Style.button(Lang.t("‹ Trở lại"), "BackBtn"),
		func() -> void:
			main.show_title(),
	)
	back.position = Vector2(14 + e.x, 12 + e.y)
	holder.add_child(back)

# ---------- skirmish ----------
func show_skirmish() -> void:
	var v := _page(1040)
	v.add_child(
		_head(
			Lang.t("‹ Trở lại"),
			func() -> void:
				main.show_title(),
			Lang.t("Đấu tự do"),
		)
	)
	var grid := _grid(220, 12, true)
	var heroes := Content.heroes_of("p")
	if hero_choice == "" or not heroes.has(hero_choice):
		hero_choice = heroes[0]
	for key: String in (heroes if heroes.size() > 1 else []): # one commander: nothing to choose
		grid.add_child(
			_hero_card(
				"p",
				key,
				key == hero_choice,
				func() -> void:
					hero_choice = key
					show_skirmish(),
			)
		)
	v.add_child(grid)
	v.add_child(
		_map_cards(
			map_choice,
			func(mid: String) -> void: # battlefield
				map_choice = mid
				show_skirmish(),
		)
	)
	var row := _flow(10)
	var seg := Style.hbox(0)
	var e_btn := Style.button(Lang.t("Dễ"), "SegOn" if easy else "SegBtn")
	var n_btn := Style.button(Lang.t("Thường"), "SegBtn" if easy else "SegOn")
	_on(
		e_btn,
		func() -> void:
			easy = true
			show_skirmish(),
	)
	_on(
		n_btn,
		func() -> void:
			easy = false
			show_skirmish(),
	)
	seg.add_child(e_btn)
	seg.add_child(n_btn)
	row.add_child(seg)
	var note := Style.lbl(
		Lang.t("Dễ: địch khởi đầu với nửa số vàng.") if easy else Lang.t("Thường: hai bên ngang vàng."),
		13,
		Style.MUTED,
		null,
		true,
	)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(note)
	var go := Style.menu_button(Lang.t("Xuất quân"), "", true)
	go.custom_minimum_size.x = 200
	_on(
		go,
		func() -> void:
			confirm_start(
				Game.new_game(Content.skirmish_def(map_choice, hero_choice, easy, sk_gold, sk_cap)),
				{ "kind": "skirmish", "hero": hero_choice, "easy": easy, "map": map_choice, "gold": sk_gold, "cap": sk_cap },
			),
	)
	v.add_child(
		_gold_cap_row(
			sk_gold,
			sk_cap,
			func(key: String, val: int) -> void:
				if key == "gold":
					sk_gold = val
				else:
					sk_cap = val
				show_skirmish(),
		)
	)
	row.add_child(go)
	v.add_child(row)
	_settle_page()

## no enter-slide jitter when only the selection changed
func _settle_page() -> void:
	if page:
		page.modulate.a = 1.0
		page.offset_top = 0
		page.offset_bottom = 0

## commander pick card: token, name, stats, blurb (tooltip only when blurb = false); hot = the picked one
func _hero_card(side: String, key: String, hot: bool, on_pick: Callable, blurb := true) -> PanelContainer:
	var h := Content.hero_look(key)
	var st := Content.type_stat("hero", key) # hero overrides on the base unit
	var cv := Style.vbox(8)
	var top := Style.hbox(12)
	top.add_child(Token.make(side, "hero", key, 56))
	var tv := Style.vbox(2)
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h_name: String = h.name
	var h_blurb: String = h.blurb
	tv.add_child(Style.lbl(h_name, 21, Style.GOLD, Style.display))
	tv.add_child(Style.lbl(Lang.t("Công %d · Thủ %d · Đi %d") % [st.atk, st.def, st.mv], 12, Style.MUTED))
	top.add_child(tv)
	cv.add_child(top)
	if blurb:
		cv.add_child(Style.lbl(h_blurb, 14, Style.INK, null, true))
	var card := _click_card(
		cv,
		func() -> void:
			_sfx("select")
			on_pick.call(),
		true,
		hot,
	)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not blurb:
		card.tooltip_text = h_blurb
	return card

## battlefield cards (skirmish maps); on_pick(map_id)
func _map_cards(cur: String, on_pick: Callable) -> HFlowContainer:
	var maps := _flow(10)
	for mid: String in Content.SKIRMISH.MAPS:
		var md: Dictionary = Content.SKIRMISH.MAPS[mid]
		var mv := Style.vbox(2)
		var md_name: String = md.name
		var md_blurb: String = md.get("blurb", "")
		mv.add_child(Style.lbl(md_name, 18, Style.GOLD, Style.display))
		mv.add_child(Style.lbl(md_blurb, 13, Style.MUTED, null, true))
		var mcard := _click_card(
			mv,
			func() -> void:
				_sfx("select")
				on_pick.call(mid),
			true,
			mid == cur,
		)
		mcard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		maps.add_child(mcard)
	return maps

## AE2 options: starting gold + unit cap; on_set("gold" | "cap", value)
func _gold_cap_row(gold: int, cap: int, on_set: Callable) -> HFlowContainer:
	var opts := _flow(16)
	for spec: Array in [[Lang.t("Vàng khởi đầu"), [500, 1000, 2000], "gold"], [Lang.t("Giới hạn quân"), [10, 20, 25], "cap"]]:
		var spec_name: String = spec[0]
		var pair := Style.hbox(10) # label + its buttons wrap as one piece
		pair.add_child(Style.lbl(spec_name, 14, Style.MUTED))
		var sg := Style.hbox(0)
		for val: int in spec[1]:
			var cur: int = gold if spec[2] == "gold" else cap
			var b := Style.button(str(val), "SegOn" if val == cur else "SegBtn")
			var key: String = spec[2]
			_on(
				b,
				func() -> void:
					on_set.call(key, val),
			)
			sg.add_child(b)
		pair.add_child(sg)
		opts.add_child(pair)
	return opts

## row that wraps onto more lines when the page is narrow (phone held upright)
static func _flow(sep: int) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	return f

# ---------- 1 vs 1 (docs/1v1.md) ----------
func show_duel() -> void:
	var v := _page(1040)
	v.add_child(
		_head(
			Lang.t("‹ Trở lại"),
			func() -> void:
				main.show_title(),
			Lang.t("1 đấu 1"),
		)
	)
	var intro := Lang.t("Hai người chung một máy (đổi tay mỗi lượt), hoặc đấu với máy. Không tính vào chiến dịch.")
	v.add_child(Style.lbl(intro, 14, Style.MUTED, null, true))
	var cols := _flow(12)
	for side: String in ["p", "e"]:
		cols.add_child(_duel_side(side))
	v.add_child(cols)
	var map_id: String = duel_opts.map
	v.add_child(
		_map_cards(
			map_id,
			func(mid: String) -> void:
				duel_opts.map = mid
				show_duel(),
		)
	)
	var row := _flow(10)
	var gold: int = duel_opts.gold
	var cap: int = duel_opts.cap
	var opts := _gold_cap_row(
		gold,
		cap,
		func(key: String, val: int) -> void:
			duel_opts[key] = val
			show_duel(),
	)
	opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(opts)
	var go := Style.menu_button(Lang.t("Xuất quân"), "", true)
	go.custom_minimum_size.x = 200
	_on(go, _start_duel)
	row.add_child(go)
	v.add_child(row)
	_settle_page()

## one side's column: faction, who plays it (Blue: person or AI level), commander
func _duel_side(side: String) -> Control:
	var f: Dictionary = Content.theme().factions[side]
	var card := Style.card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cv := Style.vbox(10)
	card.add_child(cv)
	cv.add_child(_eyebrow(Lang.t("Bên Xanh · đi trước") if side == "p" else Lang.t("Bên Đỏ")))
	var f_name: String = f.name
	cv.add_child(Style.lbl(f_name, 24, Style.P_NAME if side == "p" else Style.E_NAME, Style.display))
	var ctrl_e: String = duel_opts.ctrlE
	if side == "p":
		cv.add_child(Style.lbl(Lang.t("Người chơi 1"), 14, Style.MUTED))
	else:
		var seg := _flow(0) # 4 choices: wraps on a phone held upright
		seg.add_theme_constant_override("v_separation", 4)
		for o: Array in OPPONENTS:
			var key: String = o[0]
			var label := Lang.t(str(o[1]))
			var b := Style.button(label, "SegOn" if key == ctrl_e else "SegBtn")
			_on(
				b,
				func() -> void:
					duel_opts.ctrlE = key
					show_duel(),
			)
			seg.add_child(b)
		cv.add_child(seg)
		var who := Lang.t("Người chơi 2, chung máy: đổi tay mỗi lượt.") if ctrl_e == "human" else Lang.t("Máy chơi bên Đỏ.")
		cv.add_child(Style.lbl(who, 14, Style.MUTED))
	var hk := "hero" if side == "p" else "heroE"
	var heroes := Content.heroes_of(side)
	if not heroes.has(duel_opts[hk]):
		duel_opts[hk] = heroes[0]
	var cur: String = duel_opts[hk]
	for key: String in heroes:
		var hc := _hero_card(
			side,
			key,
			key == cur,
			func() -> void: # no blurb: keeps Xuất quân on a phone screen
				duel_opts[hk] = key
				show_duel(),
			false,
		)
		hc.set_meta("duel_pick", side + ":" + key) # click driver finds the commander cards by this
		cv.add_child(hc)
	return card

func _start_duel() -> void:
	var map_id: String = duel_opts.map
	var hero: String = duel_opts.hero
	var hero_e: String = duel_opts.heroE
	var ctrl_e: String = duel_opts.ctrlE
	var gold: int = duel_opts.gold
	var cap: int = duel_opts.cap
	var ctx := { "kind": "duel", "map": map_id, "hero": hero, "heroE": hero_e, "ctrlE": ctrl_e, "gold": gold, "cap": cap }
	confirm_start(Game.new_game(Content.duel_def(map_id, hero, hero_e, ctrl_e, gold, cap)), ctx)

## start a game; if it would replace a different game in progress, ask first (one save slot)
func confirm_start(state: Dictionary, ctx: Dictionary) -> void:
	var sv: Variant = Store.load_game()
	if sv == null:
		main.start_game(state, ctx)
		return
	var svd: Dictionary = sv
	var sctx: Dictionary = svd.ctx
	var sst: Dictionary = svd.state
	if sctx.get("kind") == ctx.get("kind") and sctx.get("id") == ctx.get("id") and sctx.get("map") == ctx.get("map"):
		if ctx.get("kind") != "campaign": # skirmish / duel setup "Xuất quân" = a new game on purpose
			main.start_game(state, ctx)
			return
		# one tap on the map node must not wipe the game in progress
		confirm(
			Lang.t("Màn này đang đánh dở [b]lượt %d[/b].") % sst.turn,
			Lang.t("Đánh lại từ đầu"),
			func() -> void:
				main.start_game(state, ctx),
			Lang.t("Đánh tiếp"),
			func() -> void:
				main.start_game(sst, sctx),
		)
		return
	main.start_game(state, ctx) # another game in progress: replaced, no ask (user 2026-11-09: "Thôi / Xuất quân" popup = noise)

## small modal: message + [Thôi] [alt] [yes]; no_fn = after Thôi
func confirm(bb: String, yes: String, fn: Callable, alt := "", alt_fn := Callable(), no_fn := Callable()) -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 120
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.10, 0.05, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	center.ready.connect(Style.inset_safe.bind(center))
	var card := Style.card(Color("#1f110b"), Style.BRONZE, 14, 20)
	card.custom_minimum_size.x = 420
	var v := Style.vbox(14)
	v.add_child(Style.rich(bb, 16, Style.LIGHT, Style.GOLD)) # dark card: light text (INK was unreadable)
	var row := Style.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(
		_on(
			Style.button(Lang.t("Thôi"), "ActBtn"),
			func() -> void:
				layer.queue_free()
				if no_fn.is_valid():
					no_fn.call(),
		)
	)
	if alt != "":
		row.add_child(
			_on(
				Style.button(alt, "ActBtn"),
				func() -> void:
					layer.queue_free()
					alt_fn.call(),
			)
		)
	row.add_child(
		_on(
			Style.button(yes, "ActGo"),
			func() -> void:
				layer.queue_free()
				fn.call(),
		)
	)
	v.add_child(row)
	card.add_child(v)
	center.add_child(card)
	if main:
		main.add_child(layer)
	else:
		add_child(layer)

func hide_all() -> void:
	visible = false
	if page:
		page.queue_free()
		page = null

# ---------- codex ----------
func add_overlays() -> void:
	if codex:
		return
	codex = Control.new()
	codex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	codex.z_index = 110 # over the in-game HUD (40) and ⚙ (55), under confirm (120)
	codex.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.10, 0.05, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	codex.add_child(dim)
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, 16)
	codex.add_child(mc)
	var center := CenterContainer.new()
	mc.add_child(center)
	var card := PanelContainer.new()
	var cs := Style.paper(18.0, 10.0)
	card.add_theme_stylebox_override("panel", cs)
	center.add_child(card)
	_codex_card = card
	var v := Style.vbox(14)
	var head := Style.hbox(14)
	head.add_child(_h2(Lang.t("Sách lính")))
	var seg := Style.hbox(0)
	for pair: Array in [["p", Lang.t("Quân ta")], ["e", Lang.t("Quân địch")], ["terrain", Lang.t("Địa hình")]]:
		var pair_name: String = pair[1]
		var b := Style.button(pair_name, "SegBtn")
		var sd: String = pair[0]
		_on(
			b,
			func() -> void:
				open_codex(sd),
		)
		seg.add_child(b)
		_codex_seg.append([sd, b])
	head.add_child(seg)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(_on(Style.button(Lang.t("Đóng ✕"), "BackBtn"), close_codex))
	v.add_child(head)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_codex_grid = _grid(260)
	_codex_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_codex_grid)
	v.add_child(sc)
	card.add_child(v)
	var fit := func() -> void:
		var e := Style.safe_insets(mc)
		mc.add_theme_constant_override("margin_left", 16 + int(e.x))
		mc.add_theme_constant_override("margin_top", 16 + int(e.y))
		mc.add_theme_constant_override("margin_right", 16 + int(e.z))
		mc.add_theme_constant_override("margin_bottom", 16 + int(e.w))
		# viewport, not mc.size: the card's minimum holds mc at its old size, so a smaller window never shrank it
		var vs := mc.get_viewport_rect().size
		card.custom_minimum_size = Vector2(minf(1000, vs.x - 32 - e.x - e.z), vs.y - 32 - e.y - e.w)
		# grid columns from the card width: the grid's own resize never shrinks below 4 columns (phone: card wider than screen)
		_codex_grid.columns = clampi(int((vs.x - 32 - e.x - e.z - 60.0 + 12.0) / (260.0 + 12.0)), 1, 4)
		# portrait: the tabs get their own row under the title (title + tabs + close is wider than a phone held upright)
		var seg_host: Container = head
		if vs.y > vs.x:
			seg_host = v
		if seg.get_parent() != seg_host:
			seg.get_parent().remove_child(seg)
			seg_host.add_child(seg)
			seg_host.move_child(seg, 1)
	mc.resized.connect(fit)
	if main:
		main.add_child(codex)
	else:
		add_child(codex)
	codex.get_viewport().size_changed.connect(fit)

func open_codex(side := "p") -> void:
	if codex == null:
		add_overlays()
	codex_side = side
	for pair: Array in _codex_seg:
		var pb: Button = pair[1]
		pb.theme_type_variation = "SegOn" if pair[0] == side else "SegBtn"
	for c in _codex_grid.get_children():
		c.queue_free()
	if side == "terrain":
		_codex_terrain()
		_show_codex()
		return
	var types: Array = Rules.BUY_ORDER.duplicate()
	for ty: String in Rules.UNITS: # non-buyables (raised ghosts...) last
		var ud: Dictionary = Rules.UNITS[ty]
		if not ud.get("buyable", true):
			types.append(ty)
	for ty: String in types:
		var uc := Style.unit_card(side, ty, null)
		uc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_codex_grid.add_child(uc)
	for hk: String in Content.heroes_of(side):
		var uc := Style.unit_card(side, "hero", hk, { "tag": Lang.t("Tướng") })
		uc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_codex_grid.add_child(uc)
	_show_codex()

func _show_codex() -> void:
	if not codex.visible:
		codex.visible = true
		codex.modulate.a = 0.0
		_codex_card.pivot_offset = _codex_card.size / 2.0
		_codex_card.scale = Vector2(0.9, 0.9)
		var tw := codex.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(codex, "modulate:a", 1.0, 0.3)
		tw.tween_property(_codex_card, "scale", Vector2.ONE, 0.4)

## one card per terrain: name, defence bonus, move cost per move class, rule note
func _codex_terrain() -> void:
	var classes := [["foot", Lang.t("Đi bộ")], ["water", Lang.t("Hải tặc")], ["fly", "Bay"]]
	for t: String in Rules.TERRAIN:
		var ter: Dictionary = Rules.TERRAIN[t]
		var card := Style.card(Color(0, 0, 0, 0.3), Style.LACQUER_3, 10, 12)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := Style.vbox(4)
		var t_name: String = Content.terrain(t).name
		v.add_child(Style.lbl(t_name, 19, Style.GOLD, Style.display))
		v.add_child(Style.lbl(Lang.t("Thủ +%d") % ter.def, 15, Style.INK, Style.semi))
		var costs := []
		for mc: Array in classes:
			var mcls: String = mc[0]
			var c := Game.move_cost(mcls, t)
			costs.append("%s %s" % [mc[1], "—" if c == INF else str(int(c))])
		v.add_child(Style.lbl(Lang.t("Bước đi: ") + " · ".join(costs), 13, Style.MUTED, null, true))
		var note := Content.tile_note(t)
		if note != "":
			v.add_child(Style.lbl(note, 13, Style.INK, null, true))
		card.add_child(v)
		_codex_grid.add_child(card)

func close_codex() -> void:
	if codex and codex.visible:
		codex.visible = false
		codex_closed.emit()

func is_codex_open() -> bool:
	return codex != null and codex.visible

## numbered gold medallion on mission cards (green once won)
class Medal extends Control:
	var n := 1
	var done := false

	static func make(p_n: int, p_done: bool) -> Medal:
		var m := Medal.new()
		m.n = p_n
		m.done = p_done
		m.custom_minimum_size = Vector2(44, 44)
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return m

	func _draw() -> void:
		var c := Vector2(22, 22)
		var hi := Color("#c7f0a8") if done else Color("#ffe9a8")
		var lo := Color("#5f9a3c") if done else Color("#b8873a")
		var rim := Color("#3b6524") if done else Color("#7a5320")
		draw_circle(c + Vector2(0, 1.5), 22, rim, true, -1.0, true)
		Draw.radial(self, c, 20.5, [[0.0, hi], [1.0, lo]], 32, Vector2.ONE, Vector2(-6.6, -8.8))
		Draw.text_c(self, Style.display_x, c, str(n), 21, Style.LACQUER)
