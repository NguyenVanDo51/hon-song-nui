class_name HudWidgets
extends RefCounted
## small drawn pieces of the game screen HUD: gear, coin, backdrop, turn banner, victory rays, intro glow (split from game_screen, E5)

## ⚙ drawn (the bundled fonts have no gear glyph)
class GearIcon extends Control:
	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.24
		var col := Style.PAPER_HI
		var pts := PackedVector2Array()
		for i in 48:
			var a := TAU * i / 48.0
			@warning_ignore("integer_division")
			var tooth := 1.0 if (i / 3) % 2 == 0 else 0.0
			pts.append(c + Vector2(cos(a), sin(a)) * r * (1.0 + 0.32 * tooth))
		draw_colored_polygon(pts, col)
		draw_circle(c, r * 0.45, Style.ROYAL)

## gold coin icon in the top bar
class Coin extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(20, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(10, 10)
		draw_circle(c, 9.0, Style.LEAF, true, -1.0, true)
		draw_arc(c, 9.0, 0, TAU, 28, Style.INK_D, 2.0, true)
		Draw.star(self, c, 4.6, Color("#c98a1e"), Color(0, 0, 0, 0), 0.0)

## warm radial backdrop behind the table
class BgPaint extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#c9a66b"))
		Draw.radial(
			self,
			size * Vector2(0.5, 0.42),
			size.length() * 0.55,
			[[0.0, Color("#f2e3c0")], [0.6, Color("#e2cb98")], [1.0, Color("#c9a66b")]],
			40,
			Vector2(1.0, size.y / size.x * 1.4),
		)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

## turn banner sweeping across the board
class Banner extends Control:
	var _label: Label
	var _t := 1.0
	var _foe := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label = Style.lbl("", 44, Style.PAPER_HI, Style.display_x)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Style.ink_outline(_label, 8)
		_label.add_theme_color_override("font_shadow_color", Style.INK_D)
		_label.add_theme_constant_override("shadow_offset_x", 3)
		_label.add_theme_constant_override("shadow_offset_y", 4)
		add_child(_label)
		visible = false

	func show_text(text: String, foe: bool) -> void:
		_label.text = text
		_foe = foe
		_label.add_theme_color_override("font_color", Style.PAPER_HI)
		_t = 0.0
		visible = true

	func _process(dt: float) -> void:
		if not visible:
			return
		_t += dt / 1.5
		if _t >= 1.0:
			visible = false
			return
		queue_redraw()
		var a := clampf(_t / 0.18, 0.0, 1.0) if _t < 0.18 else (1.0 if _t < 0.78 else 1.0 - (_t - 0.78) / 0.22)
		var up := 0.0 if _t < 0.78 else (_t - 0.78) / 0.22 * 10.0
		_label.size = Vector2(size.x, 80)
		_label.position = Vector2(0, size.y / 2 - 40 - up)
		_label.modulate.a = a

	func _draw() -> void:
		var open := clampf(_t / 0.18, 0.0, 1.0)
		var a := 1.0 if _t < 0.78 else maxf(0.0, 1.0 - (_t - 0.78) / 0.22)
		var up := 0.0 if _t < 0.78 else (_t - 0.78) / 0.22 * 10.0
		var h := 84.0
		var w := minf(size.x * 0.86, 760.0) * open
		var r := Rect2((size.x - w) / 2, size.y / 2 - h / 2 - up, w, h)
		# swallow-tail ribbon: ink edge + hard shadow, crimson for us, royal blue for the foe
		var col := Color(Style.ROYAL if _foe else Style.CRIMSON, a)
		var ink := Color(Style.INK_D, a)
		var cut := 26.0 * open
		var rib := PackedVector2Array(
			[
				r.position,
				Vector2(r.end.x, r.position.y),
				Vector2(r.end.x - cut, r.get_center().y),
				r.end,
				Vector2(r.position.x, r.end.y),
				Vector2(r.position.x + cut, r.get_center().y),
			]
		)
		var sh := PackedVector2Array()
		for q in rib:
			sh.append(q + Vector2(5, 6))
		draw_colored_polygon(sh, ink)
		draw_colored_polygon(rib, col)
		var loop := rib.duplicate()
		loop.append(rib[0])
		draw_polyline(loop, ink, 3.0, true)
		var inner := Rect2(r.position + Vector2(cut + 6, 7), r.size - Vector2(2 * cut + 12, 14))
		if inner.size.x > 0:
			draw_rect(inner, Color(Style.PAPER, 0.55 * a), false, 1.5)

## small swallow-tail title ribbon pinned on a card's top edge (pause menu)
class Ribbon extends Control:
	const CUT := 18.0
	const SH := 4.0

	func _init(text: String) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Style.lbl(text, 24, Style.PAPER_HI, Style.display_x)
		Style.ink_outline(l, 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.offset_right = -SH
		l.offset_bottom = -SH - 2
		add_child(l)
		var w := Style.display_x.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		custom_minimum_size = Vector2(w + 2 * CUT + 60, 50)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size - Vector2(SH, SH))
		var mid := r.get_center().y
		var rib := PackedVector2Array([r.position, Vector2(r.end.x, 0), Vector2(r.end.x - CUT, mid), r.end, Vector2(0, r.end.y), Vector2(CUT, mid)])
		var sh := PackedVector2Array()
		for q in rib:
			sh.append(q + Vector2(SH, SH))
		draw_colored_polygon(sh, Style.INK_D)
		draw_colored_polygon(rib, Style.CRIMSON)
		var loop := rib.duplicate()
		loop.append(rib[0])
		draw_polyline(loop, Style.INK_D, 3.0, true)

## slow spinning victory rays behind the end card
class Rays extends Control:
	func _process(_dt: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var c := size / 2
		var R := size.length()
		var rot := FX.now() / 30000.0 * TAU
		for i in 18:
			var a0 := rot + i * TAU / 18.0
			var a1 := a0 + TAU / 36.0
			draw_colored_polygon(
				PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * R, c + Vector2(cos(a1), sin(a1)) * R]),
				Color(0.89, 0.70, 0.27, 0.16),
			)

## mission stars on the end card: `got` of Stars.MAX, popping in one by one (k: 0 -> MAX, tweened by the owner)
class StarRow extends Control:
	var got := 0
	var k := 0.0:
		set(v):
			k = v
			queue_redraw()

	func _draw() -> void:
		var r := size.y * 0.42
		var gap := r * 2.6
		var x0 := size.x / 2 - gap * (Stars.MAX - 1) / 2.0
		for i in Stars.MAX:
			var c := Vector2(x0 + gap * i, size.y / 2)
			Draw.star(self, c, r, Style.PAPER_2, Style.INK_D, 2.0)
			if i < got:
				var t := clampf(k - i, 0.0, 1.0)
				if t > 0.0:
					var pop := 1.0 + sin(t * PI) * 0.35 # overshoots then settles
					Draw.glow(self, c, r * 1.6 * t, Color(1.0, 0.85, 0.4, 0.35 * t))
					Draw.star(self, c, r * pop * t, Style.LEAF, Style.INK_D, 2.0)

## one goal's mark on the win card: gold star = met, dark = missed (the fonts have no check-mark glyph)
class StarIcon extends Control:
	var on := false

	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) * 0.5
		if on:
			Draw.star(self, c, r, Style.LEAF, Style.INK_D, 1.2)
		else:
			Draw.star(self, c, r, Style.PAPER_2, Style.INK_D, 1.2)

## win card: `got` stars popping in + each goal ticked / missed with the number it was judged on (+ best, if better before).
## A penalty goal (quests) earns no star: ✓ when met, red "−1 ★" when not.
static func end_stars(v: VBoxContainer, goals: Array, best_before: int, got: int) -> StarRow:
	var row := StarRow.new()
	row.got = got
	row.custom_minimum_size = Vector2(240, 54)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(row)
	var list := Style.vbox(2)
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for g: Dictionary in goals:
		var ok: bool = g.ok
		var have: int = g.have if g.has("have") else 0
		var note := ""
		match str(g.key):
			"turns":
				note = " (lượt %d)" % have
			"lost":
				note = " (mất %d)" % have
			"hero":
				note = "" if ok else " (ngã %d lần)" % have
		var line := Style.hbox(8)
		var col := Style.GOOD if ok else Style.MUTED
		if g.get("penalty", false):
			line.add_child(QuestPanel.Mark.new("done" if ok else "miss"))
			col = Style.GOOD if ok else Style.BAD
			note = "" if ok else "  −1 ★"
		else:
			var icon := StarIcon.new()
			icon.on = ok
			icon.custom_minimum_size = Vector2(16, 16)
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(icon)
		line.add_child(Style.lbl(str(g.text) + note, 15, col))
		list.add_child(line)
	v.add_child(list)
	if best_before > row.got:
		var best := Style.lbl(Content.text("star_best").format({ "n": best_before }), 13, Style.MUTED)
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(best)
	return row

## soft pulsing halo behind the token on the intro card
class IntroGlow extends Control:
	var col := Color.WHITE

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 400.0)
		Draw.glow(self, size / 2, size.x * (0.62 + 0.06 * k), Color(col, 0.35 + 0.2 * k))

## hotseat hand-over: dims the board, names the side to move; a tap anywhere / the button / Space goes on
class Handoff extends Control:
	static func make(title: String, sub: String, col: Color, on_go: Callable) -> Handoff:
		var h := Handoff.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.mouse_filter = Control.MOUSE_FILTER_STOP
		h.z_index = 70 # over the end card (60), under the codex
		var dim := ColorRect.new()
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.color = Color(0.16, 0.10, 0.05, 0.78)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(center)
		var card := PanelContainer.new()
		var cs := Style.paper(26.0, 10.0)
		card.add_theme_stylebox_override("panel", cs)
		card.custom_minimum_size.x = 460
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(card)
		var v := Style.vbox(14)
		card.add_child(v)
		var t := Style.lbl(title, 36, col, Style.display_x, true)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var st := Style.lbl(sub, 16, Style.MUTED)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(st)
		var go := Style.menu_button("Bắt đầu lượt", "", true)
		var go_title: Label = go.get_meta("title")
		go_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		go.custom_minimum_size = Vector2(220, 52)
		go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		go.pressed.connect(on_go)
		v.add_child(go)
		var t0 := Time.get_ticks_msec()
		h.gui_input.connect(
			func(ev: InputEvent) -> void:
				var mb := ev as InputEventMouseButton
				if mb != null and mb.pressed and Time.get_ticks_msec() - t0 > 400: # not the end-turn click itself
					on_go.call(),
		)
		h.modulate.a = 0.0
		h.create_tween().tween_property(h, "modulate:a", 1.0, 0.25)
		return h
