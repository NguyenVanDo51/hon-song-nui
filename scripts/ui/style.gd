class_name Style
extends RefCounted
## the look shared by every screen: lacquer + bronze palette, fonts, the Godot Theme, and widget builders
## (menu button, action button, card, unit card, stat bars, dialogue). Port of src/ui/style.css.

const LACQUER := Color("#140b08")
const LACQUER_2 := Color("#22130d")
const LACQUER_3 := Color("#34201a")
const GLASS := Color(0.11, 0.059, 0.039, 0.78)
const BRONZE := Color("#b8924f")
const BRONZE_2 := Color("#8a6a35")
const GOLD := Color("#f0c96c")
const GOLD_HI := Color("#fff0c2")
const INK := Color("#f4e8cf")
const MUTED := Color("#bba78a")
const CINNABAR := Color("#c8432f")
const CINNABAR_HI := Color("#e8634a")
const SEA := Color("#2c8c8a")
const SEA_HI := Color("#6fd6cf")
const GOOD := Color("#8fd16a")
const BAD := Color("#ff6b57")
const AMBER := Color("#ffd166")
const P_NAME := Color("#ffb38a")

static var body: Font = load("res://assets/fonts/BeVietnamPro-Regular.ttf")
static var semi: Font = load("res://assets/fonts/BeVietnamPro-SemiBold.ttf")
static var bold: Font = load("res://assets/fonts/BeVietnamPro-Bold.ttf")
static var xbold: Font = load("res://assets/fonts/BeVietnamPro-ExtraBold.ttf")
static var display: Font = load("res://assets/fonts/AlegreyaSC-Bold.ttf")
static var display_x: Font = load("res://assets/fonts/AlegreyaSC-ExtraBold.ttf")

static func box(bg: Color, border := Color.TRANSPARENT, radius := 12, pad := 14.0, bw := 1) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(bw if border.a > 0 else 0)
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(pad)
	b.anti_aliasing = true
	return b

static func _btn(t: Theme, type: String, base: String, normal: StyleBoxFlat, hover: StyleBoxFlat, fg: Color, fg_hover := Color.TRANSPARENT,
	font: Font = null, size := 0) -> void:
	t.set_type_variation(type, base)
	var pressed: StyleBoxFlat = hover.duplicate()
	pressed.bg_color = pressed.bg_color.darkened(0.15)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color.a *= 0.45
	disabled.border_color.a *= 0.45
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_color("font_color", type, fg)
	t.set_color("font_hover_color", type, fg_hover if fg_hover.a > 0 else fg)
	t.set_color("font_pressed_color", type, fg_hover if fg_hover.a > 0 else fg)
	t.set_color("font_hover_pressed_color", type, fg_hover if fg_hover.a > 0 else fg)
	t.set_color("font_disabled_color", type, Color(fg, 0.4))
	if font:
		t.set_font("font", type, font)
	if size:
		t.set_font_size("font_size", type, size)

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = body
	t.default_font_size = 15
	t.set_color("font_color", "Label", INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("normal_font", "RichTextLabel", body)
	t.set_font("bold_font", "RichTextLabel", bold)
	t.set_font_size("normal_font_size", "RichTextLabel", 15)
	t.set_font_size("bold_font_size", "RichTextLabel", 15)
	t.set_constant("line_separation", "RichTextLabel", 3)
	t.set_stylebox("panel", "PanelContainer", box(GLASS, LACQUER_3))
	t.set_stylebox("panel", "TooltipPanel", box(LACQUER_2, BRONZE_2, 8, 8))
	t.set_color("font_color", "TooltipLabel", INK)
	# scrollbars: thin bronze
	var grab := box(BRONZE_2, Color.TRANSPARENT, 4, 0)
	var grab_hi := box(BRONZE, Color.TRANSPARENT, 4, 0)
	var track := box(Color(0, 0, 0, 0.25), Color.TRANSPARENT, 4, 0)
	track.content_margin_left = 4
	track.content_margin_right = 4
	for sb: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb, track)
		t.set_stylebox("grabber", sb, grab)
		t.set_stylebox("grabber_highlight", sb, grab_hi)
		t.set_stylebox("grabber_pressed", sb, grab_hi)
	# buttons
	var mb := box(Color(0.17, 0.10, 0.08, 0.94), BRONZE_2, 12, 0)
	mb.content_margin_left = 18; mb.content_margin_right = 18; mb.content_margin_top = 12; mb.content_margin_bottom = 12
	mb.shadow_color = Color(0, 0, 0, 0.4); mb.shadow_size = 8; mb.shadow_offset = Vector2(0, 4)
	var mbh: StyleBoxFlat = mb.duplicate(); mbh.border_color = GOLD; mbh.bg_color = Color(0.22, 0.13, 0.10, 0.96)
	_btn(t, "MenuBtn", "Button", mb, mbh, GOLD, Color.TRANSPARENT, display, 21)
	var pb: StyleBoxFlat = mb.duplicate(); pb.bg_color = Color("#b1412d"); pb.border_color = Color("#f08a63")
	var pbh: StyleBoxFlat = pb.duplicate(); pbh.bg_color = Color("#c84a33"); pbh.border_color = GOLD_HI
	_btn(t, "PrimaryBtn", "Button", pb, pbh, Color("#fff6e3"), Color.TRANSPARENT, display, 21)
	var act := box(Color("#301d16"), BRONZE_2, 10, 0)
	act.content_margin_left = 12; act.content_margin_right = 12; act.content_margin_top = 8; act.content_margin_bottom = 8
	var acth: StyleBoxFlat = act.duplicate(); acth.border_color = GOLD
	_btn(t, "ActBtn", "Button", act, acth, INK, Color.TRANSPARENT, bold, 14)
	var hot: StyleBoxFlat = act.duplicate(); hot.border_color = GOLD; hot.set_border_width_all(2)
	hot.shadow_color = Color(GOLD, 0.35); hot.shadow_size = 10
	_btn(t, "ActHot", "Button", hot, hot, INK, Color.TRANSPARENT, bold, 14)
	var go: StyleBoxFlat = act.duplicate(); go.bg_color = Color("#b1412d"); go.border_color = Color("#f08a63")
	var goh: StyleBoxFlat = go.duplicate(); goh.border_color = GOLD_HI; goh.bg_color = Color("#c84a33")
	_btn(t, "ActGo", "Button", go, goh, Color("#fff6e3"), Color.TRANSPARENT, bold, 14)
	var gohot: StyleBoxFlat = go.duplicate(); gohot.border_color = GOLD; gohot.set_border_width_all(2)
	gohot.shadow_color = Color(GOLD, 0.4); gohot.shadow_size = 10
	_btn(t, "ActGoHot", "Button", gohot, gohot, Color("#fff6e3"), Color.TRANSPARENT, bold, 14)
	var ib := box(Color(0, 0, 0, 0.4), LACQUER_3, 8, 0)
	ib.content_margin_left = 10; ib.content_margin_right = 10; ib.content_margin_top = 6; ib.content_margin_bottom = 6
	var ibh: StyleBoxFlat = ib.duplicate(); ibh.border_color = BRONZE; ibh.bg_color = LACQUER_3
	_btn(t, "IconBtn", "Button", ib, ibh, INK, Color.TRANSPARENT, semi, 14)
	var chip := box(Color(0.13, 0.075, 0.05, 0.8), LACQUER_3, 99, 0)
	chip.content_margin_left = 12; chip.content_margin_right = 12; chip.content_margin_top = 6; chip.content_margin_bottom = 6
	var chiph: StyleBoxFlat = chip.duplicate(); chiph.border_color = BRONZE_2
	_btn(t, "ChipBtn", "Button", chip, chiph, MUTED, GOLD, body, 13)
	var chip_on: StyleBoxFlat = chip.duplicate(); chip_on.border_color = BRONZE_2
	_btn(t, "ChipOn", "Button", chip_on, chip_on, GOLD, GOLD, body, 13)
	var back := box(Color.TRANSPARENT, LACQUER_3, 99, 0)
	back.content_margin_left = 12; back.content_margin_right = 12; back.content_margin_top = 6; back.content_margin_bottom = 6
	var backh: StyleBoxFlat = back.duplicate(); backh.border_color = BRONZE_2
	_btn(t, "BackBtn", "Button", back, backh, MUTED, GOLD, body, 14)
	var seg := box(Color(0.08, 0.043, 0.03, 0.8), LACQUER_3, 99, 0)
	seg.content_margin_left = 16; seg.content_margin_right = 16; seg.content_margin_top = 8; seg.content_margin_bottom = 8
	var segh: StyleBoxFlat = seg.duplicate(); segh.border_color = BRONZE_2
	_btn(t, "SegBtn", "Button", seg, segh, MUTED, INK, body, 14)
	var seg_on: StyleBoxFlat = seg.duplicate(); seg_on.bg_color = LACQUER_3; seg_on.border_color = BRONZE_2
	_btn(t, "SegOn", "Button", seg_on, seg_on, GOLD, GOLD, semi, 14)
	var link := StyleBoxEmpty.new()
	link.set_content_margin_all(4)
	t.set_type_variation("LinkBtn", "Button")
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(st, "LinkBtn", link)
	t.set_color("font_color", "LinkBtn", GOLD)
	t.set_color("font_hover_color", "LinkBtn", GOLD_HI)
	t.set_font("font", "LinkBtn", semi)
	t.set_font_size("font_size", "LinkBtn", 14)
	# card-ish buttons (mission, hero pick): text lives in child labels
	var cb := box(GLASS, LACQUER_3, 12, 14)
	var cbh: StyleBoxFlat = cb.duplicate(); cbh.border_color = GOLD
	_btn(t, "CardBtn", "Button", cb, cbh, INK)
	var cbon := box(Color(0.25, 0.18, 0.09, 0.9), GOLD, 12, 14)
	cbon.shadow_color = Color(GOLD, 0.18); cbon.shadow_size = 14
	_btn(t, "CardOn", "Button", cbon, cbon, INK)
	return t

# ---------- builders ----------
static func lbl(text: String, size := 15, color := INK, font: Font = null, autowrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	if autowrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## bbcode text that sizes to its content; [b] renders bold in `bold_color`
static func rich(bb: String, size := 15, color := INK, bold_color := INK) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", color)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = bold_in(bb, bold_color)
	r.custom_minimum_size.x = 40
	return r

## colour every [b]..[/b] span
static func bold_in(bb: String, bold_color: Color) -> String:
	return bb.replace("[b]", "[b][color=#%s]" % bold_color.to_html(false)).replace("[/b]", "[/color][/b]")

static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func card(bg := GLASS, border := LACQUER_3, radius := 12, pad := 14.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, radius, pad))
	return p

static func button(text: String, variation := "ActBtn") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

## two-line menu button: display-font title + small muted line (sub may be updated later via get_meta("sub"))
static func menu_button(title: String, sub := "", primary := false) -> Button:
	var b := button("", "PrimaryBtn" if primary else "MenuBtn")
	var v := vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 18; v.offset_right = -18; v.offset_top = 10; v.offset_bottom = -10
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := lbl(title, 21, Color("#fff6e3") if primary else GOLD, display)
	var s := lbl(sub, 13, Color("#ffd9c4") if primary else MUTED)
	s.visible = sub != ""
	v.add_child(t)
	v.add_child(s)
	b.add_child(v)
	b.set_meta("title", t)
	b.set_meta("sub", s)
	b.custom_minimum_size = Vector2(display.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 44, 66 if sub != "" else 50)
	return b

static func set_sub(b: Button, sub: String) -> void:
	var s: Label = b.get_meta("sub")
	s.text = sub
	s.visible = sub != ""
	b.custom_minimum_size.y = 66 if sub != "" else 50

## hp bar colour: green > 60, amber > 30, else red
static func hp_color(hp: int) -> Color:
	return GOOD if hp > 60 else (AMBER if hp > 30 else BAD)

## "3" or "2–4"
static func range_txt(lo: int, hi: int) -> String:
	return str(lo) if lo == hi else "%d–%d" % [lo, hi]

static func stat_range(st: Dictionary) -> String:
	var lo: int = st.rmin
	var hi: int = st.rmax
	return range_txt(lo, hi)

## bars: rows = [[name, value, max] or [name, text]]
static func stat_bars(rows: Array, size := 13) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 4)
	for r: Array in rows:
		var rname: String = r[0]
		g.add_child(lbl(rname, size, MUTED))
		if r.size() == 3:
			var val: float = r[1]
			var top: float = r[2]
			g.add_child(Bar.make(clampf(val / top, 0.0, 1.0)))
			g.add_child(lbl(str(r[1]), size, INK, semi))
		else:
			g.add_child(Control.new())
			g.add_child(lbl(str(r[1]), size, INK, semi))
	return g

## unit card for briefing + codex: token, name, description, stat bars, optional tag ribbon
static func unit_card(side: String, type: String, hero_key: Variant, opts := {}) -> Control:
	var base: Dictionary = Rules.UNITS[type]
	var st := base.duplicate()
	if type == "hero" and hero_key != null:
		var hd: Dictionary = Rules.HEROES[hero_key]
		st.merge(hd, true)
	var look := Content.unit_type_look(side, type, hero_key)
	var c := card(GLASS, BRONZE_2, 12, 14)
	c.add_theme_stylebox_override("panel", box(Color(0.16, 0.10, 0.06, 0.88), BRONZE_2, 12, 14))
	var v := vbox(8)
	var head := hbox(14)
	head.add_child(Token.make(side, type, hero_key, 64))
	var txt := vbox(2)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lname: String = look.name
	txt.add_child(lbl(lname, 20, GOLD, display))
	var desc: String = (look.blurb + " Tướng chiếm được cả làng và thành.") if type == "hero" else look.desc
	txt.add_child(lbl(desc, 14, INK, null, true))
	head.add_child(txt)
	v.add_child(head)
	var rows := [["Công", st.atk, 75], ["Thủ", st.def, 30], ["Đi", st.mv, 7], ["Tầm", stat_range(st)]]
	if type != "ghost":
		rows.append(["Giá", st.cost])
	v.add_child(stat_bars(rows))
	c.add_child(v)
	# every card gets the same top gap so tagged and untagged cards line up in a grid; the ribbon sits across the top edge
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_top", 10)
	outer.add_child(c)
	if opts.has("tag"):
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tag := PanelContainer.new()
		var ts := box(CINNABAR, Color.TRANSPARENT, 99, 2)
		ts.content_margin_left = 8
		ts.content_margin_right = 8
		tag.add_theme_stylebox_override("panel", ts)
		tag.add_child(lbl(str(opts.tag).to_upper(), 11, Color("#fff6e3"), xbold))
		tag.position = Vector2(12, -10)
		holder.add_child(tag)
		outer.add_child(holder)
	return outer

## dialogue lines [[speaker, text], ...]; lines slide in one after another
static func dialogue(lines: Array, stagger := 0.35, small := false) -> VBoxContainer:
	var v := vbox(10)
	var i := 0
	for line: Array in lines:
		var key: String = line[0]
		var text: String = line[1]
		var sp := Content.speaker(key)
		var foe := Content.is_foe(key)
		var icon: String = sp.icon
		var sname: String = sp.name
		var row := hbox(10)
		var who := PanelContainer.new()
		var ws := 34 if small else 44
		who.custom_minimum_size = Vector2(ws, ws)
		who.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		who.add_theme_stylebox_override("panel", box(Color("#10353a") if foe else LACQUER_3, SEA_HI if foe else BRONZE_2, 99, 0))
		var ic := lbl(icon, 18 if small else 24)
		ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		who.add_child(ic)
		row.add_child(who)
		var bub := PanelContainer.new()
		var bs := box(GLASS, LACQUER_3, 12, 10)
		bs.corner_radius_top_left = 4
		bs.content_margin_left = 12; bs.content_margin_right = 12
		bub.add_theme_stylebox_override("panel", bs)
		bub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bv := vbox(2)
		bv.add_child(lbl(sname, 15, SEA_HI if foe else GOLD, display))
		bv.add_child(lbl(text, 14 if small else 15, INK, null, true))
		bub.add_child(bv)
		row.add_child(bub)
		row.modulate.a = 0.0
		row.set_meta("delay", i * stagger)
		v.add_child(row)
		i += 1
	v.ready.connect(func() -> void:
		for r: Control in v.get_children():
			var tw := r.create_tween()
			var delay: float = r.get_meta("delay")
			tw.tween_interval(delay)
			tw.tween_property(r, "modulate:a", 1.0, 0.5)
	)
	return v


## thin rounded progress bar (stat bars, hp)
class Bar extends Control:
	var frac := 0.0
	var col_a := BRONZE
	var col_b := GOLD
	var h := 6.0
	var shown := 0.0

	static func make(f: float, height := 6.0, a := BRONZE, b := GOLD) -> Bar:
		var bar := Bar.new()
		bar.frac = f
		bar.h = height
		bar.col_a = a
		bar.col_b = b
		bar.custom_minimum_size = Vector2(60, height)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return bar

	func _ready() -> void:
		var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "shown", frac, 0.8)
		tw.finished.connect(func() -> void: set_process(false); queue_redraw())

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var r := h / 2.0
		draw_style_box(Style.box(Color(0, 0, 0, 0.5), Color.TRANSPARENT, int(r), 0), Rect2(0, (size.y - h) / 2, size.x, h))
		if shown > 0.001:
			var w := maxf(h, size.x * shown)
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(int(r))
			sb.bg_color = col_a.lerp(col_b, 0.6)
			sb.anti_aliasing = true
			draw_style_box(sb, Rect2(0, (size.y - h) / 2, w, h))
