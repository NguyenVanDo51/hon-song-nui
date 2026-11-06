class_name Menus
extends Control
## menu screens over the animated backdrop: title, campaign (chapter tabs + clickable map), skirmish,
## plus the codex overlay (added above the game screen). Port of the menu half of src/ui/screens.js + shell.html.

const LOGO_SHADER := preload("res://shaders/logo.gdshader")
const CREDITS := [
	["Trò chơi", "Công Thành Chiến · chiến thuật theo lượt, viết bằng Godot Engine 4.7 (MIT)."],
	["Phông chữ", "Be Vietnam Pro, Alegreya SC, Noto Sans Symbols 2 · SIL Open Font License 1.1."],
	["Biểu tượng", "Noto Emoji của Google · Apache License 2.0."],
	["Hình quân", "Icons made by Delapouite, HeavenlyDog, Lorc, Cathelineau. Available on game-icons.net · CC BY 3.0."],
	["Mô hình 3D", "KayKit của Kay Lousberg (www.kaylousberg.com) · CC0."],
	["Âm thanh", "Tổng hợp bằng mã ngay khi chạy, nhạc nền theo thang ngũ cung."],
	["Sử liệu",
		# gdlint:ignore = max-line-length
		"Phỏng theo Đại Việt sử ký toàn thư, Hậu Hán thư, Tam quốc chí và truyền thuyết dân gian. Bản đồ là sơ đồ, không đúng tỉ lệ; một số chi tiết được lược bớt hoặc thêm thắt cho hợp lối chơi."],
	["Tưởng nhớ", "Hai Bà Trưng và các nữ tướng đã đứng lên giành lại non sông."],
]

var main: Main
var bg: MenuBg
var root: Control # current page lives here
var page: Control = null
var codex: Control = null
var codex_side := "p"
var hero_choice := ""
var easy := true
var sk_gold := 300 # AE2 skirmish options: starting gold, unit cap
var sk_cap := 15
var map_choice := "dong_bang"
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

# ---------- helpers ----------
func _sfx(sfx: String) -> void:
	if main and main.audio:
		main.audio.play(sfx)

func _on(b: BaseButton, fn: Callable, sound := "ui") -> BaseButton:
	b.pressed.connect(func() -> void:
		_sfx(sound)
		fn.call())
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
		sc.tree_exiting.connect(func() -> void: root.resized.disconnect(fit))
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
	return Style.lbl(text.to_upper(), fs, Style.BRONZE, f)

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
	var normal := Style.box(Style.GLASS, Style.LACQUER_3, 12, 14)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.border_color = Style.GOLD
	hover.shadow_color = Color(0, 0, 0, 0.55)
	hover.shadow_size = 16
	if hot:
		normal = Style.box(Color(0.22, 0.14, 0.08, 0.9), Style.GOLD, 12, 14)
		normal.shadow_color = Color(Style.GOLD, 0.15)
		normal.shadow_size = 14
		hover = normal
		if pulse:
			var tw := p.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
			tw.tween_property(normal, "shadow_size", 22, 1.2)
			tw.parallel().tween_property(normal, "shadow_color", Color(Style.GOLD, 0.3), 1.2)
			tw.tween_property(normal, "shadow_size", 14, 1.2)
			tw.parallel().tween_property(normal, "shadow_color", Color(Style.GOLD, 0.15), 1.2)
	p.add_theme_stylebox_override("panel", normal)
	p.add_child(content)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ignore_mouse(content)
	if enabled:
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.mouse_entered.connect(func() -> void: p.add_theme_stylebox_override("panel", hover))
		p.mouse_exited.connect(func() -> void: p.add_theme_stylebox_override("panel", normal))
		p.gui_input.connect(func(ev: InputEvent) -> void:
			var mb := ev as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				on_click.call())
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
	g.resized.connect(func() -> void:
		var n := maxi(1, int((g.size.x + gap) / (min_w + gap)))
		if auto_fit:
			n = clampi(g.get_child_count(), 1, n)
		if n != g.columns:
			g.columns = n)
	g.columns = 4
	return g

static func goal_text(def: Dictionary) -> String:
	var win: Dictionary = def.get("win", {})
	return Content.goal_text(win, "brief", { "p": def.get("hero"), "e": def.get("enemyHero") }, {})

# ---------- title ----------
func show_title() -> void:
	var th := Content.theme()
	var v := _page(640, true)
	var tagline: String = th.tagline
	var title: String = th.title
	var lede_text: String = th.lede
	v.add_child(_eyebrow(tagline))
	v.add_child(_logo(title))
	var lede := Style.lbl(lede_text, 16, Style.INK, null, true)
	lede.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lede.add_theme_constant_override("shadow_offset_y", 1)
	lede.add_theme_constant_override("line_spacing", 6)
	lede.custom_minimum_size.x = 560
	lede.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(lede)
	var list := Style.vbox(10)
	list.custom_minimum_size.x = 420
	list.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var camp := Content.campaign()
	var ui := Store.unlocked_index()
	var prog := "Đã hoàn thành cả hai chương"
	if ui < camp.size():
		var cm: Dictionary = camp[ui]
		var cid := Content.chapter_of(cm)
		var ms := Content.missions_of(cid)
		prog = "Chương %d · Màn %d/%d: %s" % [Content.chapters().find(Content.chapter(cid)) + 1, ms.find(cm) + 1, ms.size(), cm.title]
	var sv: Variant = Store.load_game()
	if sv != null:
		var svd: Dictionary = sv
		var sst: Dictionary = svd.state
		list.add_child(_on(Style.menu_button("Đánh tiếp ván đang dở", "%s · lượt %d" % [svd.get("title", ""), sst.turn], true), func() -> void:
			var s2: Variant = Store.load_game()
			if s2 != null:
				var d2: Dictionary = s2
				var st2: Dictionary = d2.state
				var ctx2: Dictionary = d2.ctx
				main.start_game(st2, ctx2)))
	list.add_child(_on(Style.menu_button("Chiến dịch", prog, sv == null), show_campaign))
	list.add_child(_on(Style.menu_button("Đấu tự do", Content.text("skirmishBlurb")), show_skirmish))
	list.add_child(_on(Style.menu_button("Sách lính", "Xem tính chất từng loại quân"), func() -> void: open_codex()))
	v.add_child(list)
	var tg := Style.hbox(8)
	var snd := Style.button("", "ChipBtn")
	var mus := Style.button("", "ChipBtn")
	var spd := Style.button("", "ChipBtn")
	var b3 := Style.button("", "ChipBtn")
	b3.tooltip_text = "Sa bàn 3D hoặc bản đồ phẳng 2D (trong trận: menu cài đặt › Bàn cờ)"
	spd.tooltip_text = "Tốc độ hoạt cảnh x1 / x2 / x3"
	var sync := func() -> void:
		var a: Audio = null
		if main:
			a = main.audio
		var snd_on := a == null or not a.muted
		var mus_on := a == null or a.music_on
		snd.text = "Âm thanh: " + ("Bật" if snd_on else "Tắt")
		mus.text = "Nhạc nền: " + ("Bật" if mus_on else "Tắt")
		spd.text = "Tốc độ x%d" % int(FX.speed)
		b3.text = "Bàn cờ: " + ("3D" if Store.board_3d() else "2D")
		b3.theme_type_variation = "ChipOn"
		snd.theme_type_variation = "ChipOn" if snd_on else "ChipBtn"
		mus.theme_type_variation = "ChipOn" if mus_on else "ChipBtn"
		spd.theme_type_variation = "ChipOn"
	_on(b3, func() -> void:
		Store.set_board_3d(not Store.board_3d())
		sync.call())
	_on(spd, func() -> void:
		FX.speed = 2.0 if FX.speed == 1.0 else (3.0 if FX.speed == 2.0 else 1.0)
		Store.set_v("speed", FX.speed)
		sync.call())
	_on(snd, func() -> void:
		if main and main.audio:
			main.audio.set_muted(not main.audio.muted)
		sync.call())
	_on(mus, func() -> void:
		if main and main.audio:
			main.audio.set_music(not main.audio.music_on)
		sync.call())
	sync.call()
	tg.add_child(snd)
	tg.add_child(mus)
	tg.add_child(spd)
	tg.add_child(b3)
	tg.add_child(_on(Style.button("Ghi công ›", "LinkBtn"), _open_credits))
	v.add_child(tg)

func _open_credits() -> void:
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.008, 0.004, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.box(Color("#1d100b"), Style.BRONZE_2, 16, 22))
	card.custom_minimum_size.x = 620
	center.add_child(card)
	var v := Style.vbox(12)
	v.add_child(_h2("Ghi công"))
	for row: Array in CREDITS:
		var r := Style.vbox(2)
		var head: String = row[0]
		var body: String = row[1]
		r.add_child(Style.lbl(head, 15, Style.GOLD, Style.display))
		r.add_child(Style.lbl(body, 14, Style.INK, null, true))
		v.add_child(r)
	var close := Style.button("Đóng ✕", "BackBtn")
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_on(close, func() -> void: ov.queue_free())
	v.add_child(close)
	card.add_child(v)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed:
			ov.queue_free())
	add_child(ov)

## gold-leaf logo: shimmer shader label over a dark offset copy (CSS drop-shadow 0 3px 0 #4a2c0e)
func _logo(text: String) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := 104
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
	gold.resized.connect(func() -> void:
		mat.set_shader_parameter("width", gold.size.x)
		holder.custom_minimum_size = gold.size + Vector2(0, 3))
	return holder

# ---------- campaign ----------
## chapter "" = the chapter of the first unwon mission
func show_campaign(chapter_id := "") -> void:
	var open := Store.unlocked_index()
	if chapter_id == "":
		var camp0 := Content.campaign()
		var cm0: Dictionary = camp0[mini(open, camp0.size() - 1)]
		chapter_id = Content.chapter_of(cm0)
	Content.use_chapter(chapter_id)
	var ch: Dictionary = Content.theme().get("chapter", {})
	var v := _page(1040)
	var ch_title: String = ch.get("title", "Chiến dịch")
	v.add_child(_head("‹ Trở lại", func() -> void: main.show_title(), ch_title))
	# chapter tabs
	var tabs := Style.hbox(8)
	var chs := Content.chapters()
	for k in chs.size():
		var c: Dictionary = chs[k]
		var cid: String = c.id
		var unlocked := Content.chapter_unlocked(cid, open)
		var label := "Chương %d · %s" % [k + 1, c.get("years", "")] + ("" if unlocked else "  🔒")
		var b := Style.button(label, "SegOn" if c.id == chapter_id else "SegBtn")
		b.disabled = not unlocked
		b.tooltip_text = c.title + ("" if unlocked else " · thắng hết chương trước để mở")
		_on(b, func() -> void: show_campaign(cid))
		tabs.add_child(b)
	v.add_child(tabs)
	var subtitle: String = ch.get("subtitle", "")
	var blurb: String = ch.get("blurb", "")
	var sub := Style.lbl(subtitle, 15, Style.MUTED)
	v.add_child(sub)
	if blurb != "":
		v.add_child(Style.lbl(blurb, 14, Style.INK, null, true))
	var map := CampMap.new()
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.setup(open)
	map.picked.connect(func(id: String) -> void:
		_sfx("ui")
		var md: Dictionary = Content.mission(id)
		main.play_mission(md))
	var mv := Style.vbox(6)
	mv.add_child(map)
	var note: String = ch.get("note", "")
	mv.add_child(Style.lbl(note, 12, Style.MUTED))
	v.add_child(mv)
	# no mission cards: the map is the menu (hover a node for its title, click to start it: story plays over the map)

# ---------- skirmish ----------
func show_skirmish() -> void:
	var v := _page(1040)
	v.add_child(_head("‹ Trở lại", func() -> void: main.show_title(), "Đấu tự do"))
	var grid := _grid(220, 12, true)
	var heroes := Content.heroes_of("p")
	if hero_choice == "" or not heroes.has(hero_choice):
		hero_choice = heroes[0]
	for key: String in (heroes if heroes.size() > 1 else []): # one commander: nothing to choose
		var h := Content.hero_look(key)
		var st: Dictionary = Rules.HEROES[key]
		var cv := Style.vbox(8)
		var top := Style.hbox(12)
		top.add_child(Token.make("p", "hero", key, 56))
		var tv := Style.vbox(2)
		tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var h_name: String = h.name
		var h_blurb: String = h.blurb
		tv.add_child(Style.lbl(h_name, 21, Style.GOLD, Style.display))
		tv.add_child(Style.lbl("Công %d · Thủ %d · Đi %d" % [st.atk, st.def, st.mv], 12, Style.MUTED))
		top.add_child(tv)
		cv.add_child(top)
		cv.add_child(Style.lbl(h_blurb, 14, Style.INK, null, true))
		var card := _click_card(cv, func() -> void:
			hero_choice = key
			_sfx("select")
			show_skirmish(), true, key == hero_choice)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
	v.add_child(grid)
	# battlefield
	var maps := Style.hbox(10)
	for mid: String in Content.SKIRMISH.MAPS:
		var md: Dictionary = Content.SKIRMISH.MAPS[mid]
		var mv := Style.vbox(2)
		var md_name: String = md.name
		var md_blurb: String = md.get("blurb", "")
		mv.add_child(Style.lbl(md_name, 18, Style.GOLD, Style.display))
		mv.add_child(Style.lbl(md_blurb, 13, Style.MUTED, null, true))
		var mcard := _click_card(mv, func() -> void:
			map_choice = mid
			_sfx("select")
			show_skirmish(), true, mid == map_choice)
		mcard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		maps.add_child(mcard)
	v.add_child(maps)
	var row := Style.hbox(10)
	var seg := Style.hbox(0)
	var e_btn := Style.button("Dễ", "SegOn" if easy else "SegBtn")
	var n_btn := Style.button("Thường", "SegBtn" if easy else "SegOn")
	_on(e_btn, func() -> void:
		easy = true
		show_skirmish())
	_on(n_btn, func() -> void:
		easy = false
		show_skirmish())
	seg.add_child(e_btn)
	seg.add_child(n_btn)
	row.add_child(seg)
	var note := Style.lbl("Dễ: địch khởi đầu với nửa số vàng." if easy else "Thường: hai bên ngang vàng.", 13, Style.MUTED, null, true)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(note)
	var go := Style.menu_button("Xuất quân", "", true)
	go.custom_minimum_size.x = 200
	_on(go, func() -> void:
		confirm_start(Game.new_game(Content.skirmish_def(map_choice, hero_choice, easy, sk_gold, sk_cap)),
			{ "kind": "skirmish", "hero": hero_choice, "easy": easy, "map": map_choice, "gold": sk_gold, "cap": sk_cap }))
	# AE2 options: starting gold + unit cap
	var opts := Style.hbox(10)
	for spec: Array in [["Vàng khởi đầu", [300, 500, 1000, 2000], "gold"], ["Giới hạn quân", [10, 15, 20, 30], "cap"]]:
		var spec_name: String = spec[0]
		opts.add_child(Style.lbl(spec_name, 14, Style.MUTED))
		var sg := Style.hbox(0)
		for val: int in spec[1]:
			var cur: int = sk_gold if spec[2] == "gold" else sk_cap
			var b := Style.button(str(val), "SegOn" if val == cur else "SegBtn")
			var key: String = spec[2]
			_on(b, func() -> void:
				if key == "gold": sk_gold = val
				else: sk_cap = val
				show_skirmish())
			sg.add_child(b)
		opts.add_child(sg)
	v.add_child(opts)
	row.add_child(go)
	v.add_child(row)
	# no enter-slide jitter when only the selection changed
	if page:
		page.modulate.a = 1.0
		page.offset_top = 0
		page.offset_bottom = 0

## start a game; if it would replace a different game in progress, ask first (one save slot)
func confirm_start(state: Dictionary, ctx: Dictionary) -> void:
	var sv: Variant = Store.load_game()
	if sv == null:
		main.start_game(state, ctx)
		return
	var svd: Dictionary = sv
	var sctx: Dictionary = svd.ctx
	if sctx.get("kind") == ctx.get("kind") and sctx.get("id") == ctx.get("id") and sctx.get("map") == ctx.get("map"):
		main.start_game(state, ctx)
		return
	var sst: Dictionary = svd.state
	confirm("Ván đang dở [b]%s · lượt %d[/b] sẽ bị thay bằng ván mới." % [svd.get("title", ""), sst.turn], "Xuất quân",
		func() -> void: main.start_game(state, ctx))

## small modal: message + [yes] [Thôi]
func confirm(bb: String, yes: String, fn: Callable) -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 120
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.008, 0.004, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var card := Style.card(Color("#1f110b"), Style.BRONZE, 14, 20)
	card.custom_minimum_size.x = 420
	var v := Style.vbox(14)
	v.add_child(Style.rich(bb, 16, Style.INK, Style.GOLD))
	var row := Style.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(_on(Style.button("Thôi", "ActBtn"), func() -> void: layer.queue_free()))
	row.add_child(_on(Style.button(yes, "ActGo"), func() -> void:
		layer.queue_free()
		fn.call()))
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
	codex.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.008, 0.004, 0.72)
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
	var cs := Style.box(Color("#1d100b"), Style.BRONZE_2, 16, 18)
	cs.shadow_color = Color(0, 0, 0, 0.55)
	cs.shadow_size = 30
	cs.shadow_offset = Vector2(0, 10)
	card.add_theme_stylebox_override("panel", cs)
	center.add_child(card)
	_codex_card = card
	var v := Style.vbox(14)
	var head := Style.hbox(14)
	head.add_child(_h2("Sách lính"))
	var seg := Style.hbox(0)
	for pair: Array in [["p", "Quân ta"], ["e", "Quân địch"], ["terrain", "Địa hình"]]:
		var pair_name: String = pair[1]
		var b := Style.button(pair_name, "SegBtn")
		var sd: String = pair[0]
		_on(b, func() -> void: open_codex(sd))
		seg.add_child(b)
		_codex_seg.append([sd, b])
	head.add_child(seg)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(_on(Style.button("Đóng ✕", "BackBtn"), close_codex))
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
		card.custom_minimum_size = Vector2(minf(1000, mc.size.x - 32), mc.size.y - 32)
	mc.resized.connect(fit)
	if main:
		main.add_child(codex)
	else:
		add_child(codex)

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
		var uc := Style.unit_card(side, "hero", hk, { "tag": "Tướng" })
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
	var classes := [["foot", "Bộ"], ["water", "Thủy binh"], ["fly", "Rồng"]]
	for t: String in Rules.TERRAIN:
		var ter: Dictionary = Rules.TERRAIN[t]
		var card := Style.card(Color(0, 0, 0, 0.3), Style.LACQUER_3, 10, 12)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := Style.vbox(4)
		var t_name: String = Content.terrain(t).name
		v.add_child(Style.lbl(t_name, 19, Style.GOLD, Style.display))
		v.add_child(Style.lbl("Thủ +%d" % ter.def, 15, Style.INK, Style.semi))
		var costs := []
		for mc: Array in classes:
			var mcls: String = mc[0]
			var c := Game.move_cost(mcls, t)
			costs.append("%s %s" % [mc[1], "—" if c == INF else str(int(c))])
		v.add_child(Style.lbl("Bước đi: " + " · ".join(costs), 13, Style.MUTED, null, true))
		var note := Content.tile_note(t)
		if note != "":
			v.add_child(Style.lbl(note, 13, Style.INK, null, true))
		card.add_child(v)
		_codex_grid.add_child(card)

func close_codex() -> void:
	if codex:
		codex.visible = false

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
