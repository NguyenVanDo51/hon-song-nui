class_name Style
extends RefCounted
## the look shared by every screen: lacquer + bronze palette, fonts, the Godot Theme, and widget builders
## (menu button, action button, card, unit card, stat bars, dialogue). Port of src/ui/style.css.

# ---------- F1 "Truyện Kỵ Sĩ" palette (fantasy reskin 2026-11-07) ----------
const PAPER := Color("#f2e3c0")
const PAPER_2 := Color("#dcc596")
const PAPER_HI := Color("#fbf3df")
const INK_D := Color("#231a15") # woodblock ink: every edge, hard shadow, text on paper
const CRIMSON := Color("#b3262e")
const CRIMSON_D := Color("#7d1720")
const LEAF := Color("#e3b345") # gold leaf
const ROYAL := Color("#27477a")
const ROYAL_D := Color("#1b3359")
const LIGHT := Color("#fbf3df") # text over the board / dark table
const FADED := Color("#8d7c63") # disabled ink

# legacy names, remapped to the parchment look (call sites keep their meaning: text / accent / panel / enemy...)
const LACQUER := Color("#2a1d14") # dark wood table around the board / menus
const LACQUER_2 := Color("#3a2a1e")
const LACQUER_3 := INK_D
const GLASS := PAPER
const BRONZE := LEAF
const BRONZE_2 := Color("#a8802c")
const GOLD := CRIMSON_D # headings / accent text on paper
const GOLD_HI := CRIMSON
const INK := INK_D # body text on paper
const MUTED := Color("#6d5643")
const CINNABAR := CRIMSON
const CINNABAR_HI := Color("#d2444a")
const SEA := ROYAL
const SEA_HI := ROYAL
const GOOD := Color("#3f7a2e")
const BAD := Color("#b3262e")
const AMBER := Color("#a8700a")
const P_NAME := ROYAL # our side name (setting v2: we are blue)
const E_NAME := CRIMSON # the Demon Lord's side name

const EDGE_MOBILE := 14.0 # min room kept from every screen edge on phones / tablets (rounded corners)
static var safe_override := Vector4(-1, -1, -1, -1) # debug flag safe=l,t,r,b (canvas units)
static var body: Font = load("res://assets/fonts/BeVietnamPro-Regular.ttf")
static var semi: Font = load("res://assets/fonts/BeVietnamPro-SemiBold.ttf")
static var bold: Font = load("res://assets/fonts/BeVietnamPro-Bold.ttf")
static var xbold: Font = load("res://assets/fonts/BeVietnamPro-ExtraBold.ttf")
## display = Paytone One (C · Đông Hồ font kept by the user): titles, buttons, numbers
static var display: Font = load("res://assets/fonts/PaytoneOne-Regular.ttf")
static var display_x: Font = display

static func box(bg: Color, border := Color.TRANSPARENT, radius := 12, pad := 14.0, bw := 1) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(bw if border.a > 0 else 0)
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(pad)
	b.anti_aliasing = true
	return b

static func _btn(
	t: Theme,
	type: String,
	base: String,
	normal: StyleBox,
	hover: StyleBox,
	fg: Color,
	fg_hover := Color.TRANSPARENT,
	font: Font = null,
	size := 0,
) -> void:
	t.set_type_variation(type, base)
	var pressed: StyleBox
	var disabled: StyleBox
	if normal is SkinBox:
		var sk: SkinBox = normal
		pressed = sk.pressed()
		var dis: SkinBox = sk.duplicate()
		dis.face = Color("#e6d3a8")
		dis.edge = FADED
		dis.shadow_col = FADED
		dis.shadow = Vector2(3, 3)
		dis.inner = Color(0, 0, 0, 0)
		dis.shine = 0.0
		disabled = dis
	else:
		var hf: StyleBoxFlat = hover
		var pf: StyleBoxFlat = hf.duplicate()
		pf.bg_color = pf.bg_color.darkened(0.15)
		pressed = pf
		var nf: StyleBoxFlat = normal
		var df: StyleBoxFlat = nf.duplicate()
		df.bg_color.a *= 0.45
		df.border_color.a *= 0.45
		disabled = df
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
	t.set_color("font_disabled_color", type, FADED if normal is SkinBox else Color(fg, 0.4))
	t.set_color("icon_normal_color", type, Color.WHITE)
	t.set_color("icon_disabled_color", type, Color(1, 1, 1, 0.45))
	if font:
		t.set_font("font", type, font)
	if size:
		t.set_font_size("font_size", type, size)

## F1 button face: ink edge, hard shadow, thin inner line; hover = lifted 1 px + longer shadow
static func skin_btn(face: Color, pad: Vector4, shadow := 4.0, inner := Color(1, 1, 1, 0), radii := Vector4(13, 9, 15, 8)) -> Array[SkinBox]:
	var n := SkinBox.make(face, pad, { "shadow": Vector2(shadow, shadow), "inner": inner, "radii": radii })
	var h: SkinBox = n.duplicate()
	h.face = face.lightened(0.07)
	h.shift = Vector2(-1, -1)
	h.shadow = Vector2(shadow + 2, shadow + 2)
	var out: Array[SkinBox] = [n, h]
	return out

## ink outline on light button text (Paytone over crimson / blue faces)
static func _outline(t: Theme, type: String, size := 4) -> void:
	t.set_color("font_outline_color", type, INK_D)
	t.set_constant("outline_size", type, size)

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
	t.set_stylebox("panel", "PanelContainer", paper(16.0))
	t.set_constant("icon_max_width", "Button", 18)
	t.set_constant("h_separation", "Button", 6)
	var tip := SkinBox.make(PAPER_HI, Vector4(9, 6, 9, 7), { "shadow": Vector2(3, 3), "edge_w": 2.0, "radii": Vector4(7, 5, 8, 5) })
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", INK)
	# scrollbars: ink grabber on a paper groove
	var grab := box(BRONZE_2, INK_D, 4, 0, 1)
	var grab_hi := box(LEAF, INK_D, 4, 0, 1)
	var track := box(Color(0.14, 0.10, 0.08, 0.18), Color.TRANSPARENT, 4, 0)
	track.content_margin_left = 4
	track.content_margin_right = 4
	for sb: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb, track)
		t.set_stylebox("grabber", sb, grab)
		t.set_stylebox("grabber_highlight", sb, grab_hi)
		t.set_stylebox("grabber_pressed", sb, grab_hi)
	# buttons (F1: paper / crimson / royal faces, ink edge, hard shadow, pressed = lands on the shadow)
	var paper_line := Color(INK_D, 0.45)
	var light_line := Color(PAPER, 0.7)
	var mb := skin_btn(PAPER, Vector4(18, 11, 18, 13), 4.0, paper_line)
	_btn(t, "MenuBtn", "Button", mb[0], mb[1], GOLD, Color.TRANSPARENT, display, 21)
	var pb := skin_btn(CRIMSON, Vector4(18, 11, 18, 13), 4.0, light_line)
	_btn(t, "PrimaryBtn", "Button", pb[0], pb[1], PAPER_HI, Color.TRANSPARENT, display, 21)
	_outline(t, "PrimaryBtn")
	var act := skin_btn(PAPER_HI, Vector4(12, 7, 12, 9), 3.0, paper_line, Vector4(9, 6, 10, 6))
	_btn(t, "ActBtn", "Button", act[0], act[1], INK, Color.TRANSPARENT, bold, 14)
	var hot := skin_btn(Color("#f6dc8e"), Vector4(12, 7, 12, 9), 3.0, Color(CRIMSON, 0.9), Vector4(9, 6, 10, 6))
	_btn(t, "ActHot", "Button", hot[0], hot[1], INK, Color.TRANSPARENT, bold, 14)
	var go := skin_btn(CRIMSON, Vector4(12, 7, 12, 9), 3.0, light_line, Vector4(9, 6, 10, 6))
	_btn(t, "ActGo", "Button", go[0], go[1], PAPER_HI, Color.TRANSPARENT, bold, 14)
	_outline(t, "ActGo", 3)
	var gohot := skin_btn(CRIMSON, Vector4(12, 7, 12, 9), 3.0, LEAF, Vector4(9, 6, 10, 6))
	_btn(t, "ActGoHot", "Button", gohot[0], gohot[1], PAPER_HI, Color.TRANSPARENT, bold, 14)
	_outline(t, "ActGoHot", 3)
	var ib := skin_btn(ROYAL, Vector4(10, 6, 10, 7), 3.0, light_line, Vector4(8, 6, 9, 5))
	_btn(t, "IconBtn", "Button", ib[0], ib[1], PAPER_HI, Color.TRANSPARENT, semi, 14)
	_outline(t, "IconBtn", 3)
	var chip := skin_btn(PAPER_HI, Vector4(12, 5, 12, 7), 2.0, Color(0, 0, 0, 0), Vector4(8, 5, 9, 5))
	for c: SkinBox in chip:
		c.edge_w = 2.5
	_btn(t, "ChipBtn", "Button", chip[0], chip[1], INK, CRIMSON_D, body, 13)
	var chip_on := skin_btn(LEAF, Vector4(12, 5, 12, 7), 2.0, Color(0, 0, 0, 0), Vector4(8, 5, 9, 5))
	for c: SkinBox in chip_on:
		c.edge_w = 2.5
	_btn(t, "ChipOn", "Button", chip_on[0], chip_on[1], INK, INK, semi, 13)
	var back := skin_btn(PAPER, Vector4(18, 10, 18, 12), 3.0, Color(0, 0, 0, 0), Vector4(10, 7, 11, 7))
	_btn(t, "BackBtn", "Button", back[0], back[1], INK, CRIMSON_D, bold, 18)
	var seg := skin_btn(PAPER_HI, Vector4(16, 7, 16, 9), 3.0, Color(0, 0, 0, 0), Vector4(9, 6, 10, 6))
	_btn(t, "SegBtn", "Button", seg[0], seg[1], MUTED, INK, body, 14)
	var seg_on := skin_btn(CRIMSON, Vector4(16, 7, 16, 9), 3.0, light_line, Vector4(9, 6, 10, 6))
	_btn(t, "SegOn", "Button", seg_on[0], seg_on[1], PAPER_HI, PAPER_HI, semi, 14)
	_outline(t, "SegOn", 3)
	# pause menu: big blue button, round on/off toggles, small paper tiles (icon over text)
	var rb := skin_btn(ROYAL, Vector4(18, 11, 18, 13), 4.0, light_line)
	_btn(t, "RoyalBtn", "Button", rb[0], rb[1], PAPER_HI, Color.TRANSPARENT, display, 19)
	_outline(t, "RoyalBtn")
	var round_r := Vector4(29, 29, 29, 29)
	var r_on := skin_btn(LEAF, Vector4(6, 6, 6, 6), 3.0, Color(0, 0, 0, 0), round_r)
	_btn(t, "RoundOn", "Button", r_on[0], r_on[1], INK, Color.TRANSPARENT, display, 18)
	var r_off := skin_btn(Color("#e6d3a8"), Vector4(6, 6, 6, 6), 3.0, Color(0, 0, 0, 0), round_r)
	_btn(t, "RoundOff", "Button", r_off[0], r_off[1], MUTED, Color.TRANSPARENT, display, 18)
	var tile := skin_btn(PAPER_HI, Vector4(6, 8, 6, 10), 3.0, paper_line, Vector4(11, 7, 12, 7))
	_btn(t, "TileBtn", "Button", tile[0], tile[1], INK, Color.TRANSPARENT, display, 15)
	var link := StyleBoxEmpty.new()
	link.set_content_margin_all(4)
	t.set_type_variation("LinkBtn", "Button")
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(st, "LinkBtn", link)
	t.set_color("font_color", "LinkBtn", CRIMSON_D)
	t.set_color("font_hover_color", "LinkBtn", CRIMSON)
	t.set_font("font", "LinkBtn", semi)
	t.set_font_size("font_size", "LinkBtn", 14)
	# card-ish buttons (mission, hero pick): text lives in child labels
	var cb := skin_btn(PAPER, Vector4(14, 14, 14, 14), 4.0, paper_line, Vector4(14, 10, 16, 9))
	_btn(t, "CardBtn", "Button", cb[0], cb[1], INK)
	var cbon := skin_btn(Color("#f6dc8e"), Vector4(14, 14, 14, 14), 4.0, Color(CRIMSON, 0.9), Vector4(14, 10, 16, 9))
	_btn(t, "CardOn", "Button", cbon[0], cbon[1], INK)
	# Hết lượt: wax seal (round; text sits in child labels)
	var seal := WaxBox.new()
	var seal_h: WaxBox = seal.duplicate()
	seal_h.wax = Color("#d23a40")
	var seal_off: WaxBox = seal.duplicate()
	seal_off.wax = Color("#9a7f72")
	seal_off.rim = Color("#7a645a")
	seal_off.crown = false
	t.set_type_variation("SealBtn", "Button")
	t.set_stylebox("normal", "SealBtn", seal)
	t.set_stylebox("hover", "SealBtn", seal_h)
	t.set_stylebox("pressed", "SealBtn", seal.pressed())
	t.set_stylebox("hover_pressed", "SealBtn", seal.pressed())
	t.set_stylebox("disabled", "SealBtn", seal_off)
	t.set_stylebox("focus", "SealBtn", StyleBoxEmpty.new())
	return t

## parchment panel: ink edge, double frame, gold diamond corners; `drop` = soft shade under panels floating on the board
static func paper(pad := 16.0, drop := 0.0, face := PAPER) -> SkinBox:
	return SkinBox.make(
		face,
		Vector4(pad + 4, pad, pad + 4, pad + 2),
		{ "shadow": Vector2(5, 5), "frame": true, "radii": Vector4(18, 12, 20, 11), "drop": drop },
	)

## room (left, top, right, bottom) the device hides under notch / rounded corners / home bar, in canvas units.
## Desktop / web: 0. Mobile: the OS safe area, at least EDGE_MOBILE, at most 15 % of the side (guards a bad unit guess).
static func safe_insets(c: CanvasItem) -> Vector4:
	if safe_override.x >= 0:
		return safe_override
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var vp := c.get_viewport_rect().size
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ONE * EDGE_MOBILE
	var k := vp / win
	var cap := vp * 0.15
	return Vector4(
		clampf(safe.position.x * k.x, EDGE_MOBILE, cap.x),
		clampf(safe.position.y * k.y, EDGE_MOBILE, cap.y),
		clampf((win.x - safe.end.x) * k.x, EDGE_MOBILE, cap.x),
		clampf((win.y - safe.end.y) * k.y, EDGE_MOBILE, cap.y),
	)

## full-rect control c pulled in by the safe area (centred cards / overlays stay clear of the notch)
static func inset_safe(c: Control) -> void:
	var e := safe_insets(c)
	c.offset_left = e.x
	c.offset_top = e.y
	c.offset_right = -e.z
	c.offset_bottom = -e.w

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
	r.text = Icons.bb_text(bold_in(bb, bold_color), size + 3)
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
	if bg == GLASS and border == LACQUER_3:
		p.add_theme_stylebox_override("panel", paper(pad))
	else:
		p.add_theme_stylebox_override("panel", box(bg, border, radius, pad))
	return p

static func button(text: String, variation := "ActBtn") -> Button:
	var b := Button.new()
	set_btn_text(b, text)
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

## button label; a leading emoji ("⚔ Đánh") becomes the drawn icon + plain text
static func set_btn_text(b: Button, text: String) -> void:
	var parts := Icons.split(text)
	b.icon = Icons.tex(parts[0]) if parts[0] != "" else null
	b.text = parts[1]

## two-line menu button: display-font title + small muted line (sub may be updated later via get_meta("sub"))
static func menu_button(title: String, sub := "", primary := false) -> Button:
	var b := button("", "PrimaryBtn" if primary else "MenuBtn")
	var v := vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 18
	v.offset_right = -18
	v.offset_top = 10
	v.offset_bottom = -10
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := lbl(title, 21, PAPER_HI if primary else GOLD, display)
	var s := lbl(sub, 13, Color("#ffe3cf") if primary else MUTED, semi if primary else null)
	if primary:
		ink_outline(t, 5)
		ink_outline(s, 3)
	s.visible = sub != ""
	v.add_child(t)
	v.add_child(s)
	b.add_child(v)
	b.set_meta("title", t)
	b.set_meta("sub", s)
	b.custom_minimum_size = Vector2(display.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 44, 66 if sub != "" else 50)
	return b

## ink outline around a label (light text on crimson / board)
static func ink_outline(l: Label, size := 4) -> void:
	l.add_theme_color_override("font_outline_color", INK_D)
	l.add_theme_constant_override("outline_size", size)

static func set_sub(b: Button, sub: String) -> void:
	var s: Label = b.get_meta("sub")
	s.text = sub
	s.visible = sub != ""
	if b.theme_type_variation != "SealBtn":
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

## unit card for codex + new-unit intro: token, name, description, stat bars, optional tag ribbon
static func unit_card(side: String, type: String, hero_key: Variant, opts := { }) -> Control:
	var base: Dictionary = Rules.UNITS[type]
	var st := base.duplicate()
	if type == "hero" and hero_key != null:
		var hd: Dictionary = Rules.HEROES[hero_key]
		st.merge(hd, true)
	var look := Content.unit_type_look(side, type, hero_key)
	var c := card()
	var v := vbox(8)
	var head := hbox(14)
	head.add_child(Token.make(side, type, hero_key, 64))
	var txt := vbox(2)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lname: String = look.name
	txt.add_child(lbl(lname, 20, GOLD, display))
	var desc: String = (look.blurb + Lang.t(" Tướng chiếm được cả làng và lâu đài.")) if type == "hero" else look.desc
	txt.add_child(lbl(desc, 14, INK, null, true))
	head.add_child(txt)
	v.add_child(head)
	var rows := [[Lang.t("Công"), st.atk, 75], [Lang.t("Thủ"), st.def, 30], [Lang.t("Đi"), st.mv, 6], [Lang.t("Tầm"), stat_range(st)]]
	if type != "ghost":
		rows.append([Lang.t("Giá"), st.cost])
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
		var ts := box(ROYAL, INK_D, 3, 2, 2)
		ts.content_margin_left = 8
		ts.content_margin_right = 8
		tag.add_theme_stylebox_override("panel", ts)
		tag.add_child(lbl(str(opts.tag).to_upper(), 11, PAPER_HI, xbold))
		tag.position = Vector2(12, -10)
		holder.add_child(tag)
		outer.add_child(holder)
	return outer

## thin rounded progress bar (stat bars, hp)
class Bar extends Control:
	var frac := 0.0
	var col_a := Color("#c98a1e")
	var col_b := LEAF
	var h := 6.0
	var shown := 0.0

	static func make(f: float, height := 8.0, a := Color("#c98a1e"), b := LEAF) -> Bar:
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
		tw.finished.connect(
			func() -> void:
				set_process(false)
				queue_redraw(),
		)

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(0, (size.y - h) / 2, size.x, h)
		draw_style_box(Style.box(Style.PAPER_2, Style.INK_D, 3, 0, 2), r.grow(1))
		if shown > 0.001:
			var w := maxf(h, size.x * shown)
			draw_rect(Rect2(r.position, Vector2(w, h)), col_a.lerp(col_b, 0.6))
			draw_line(Vector2(w, r.position.y), Vector2(w, r.end.y), Style.INK_D, 2.0)
