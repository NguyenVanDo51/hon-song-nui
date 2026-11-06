class_name HudWidgets
extends RefCounted
## small drawn pieces of the game screen HUD: gear, coin, backdrop, turn banner, victory rays, intro glow (split from game_screen, E5)

## ⚙ drawn (the bundled fonts have no gear glyph)
class GearIcon extends Control:
	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.24
		var col := Style.INK
		var pts := PackedVector2Array()
		for i in 48:
			var a := TAU * i / 48.0
			@warning_ignore("integer_division")
			var tooth := 1.0 if (i / 3) % 2 == 0 else 0.0
			pts.append(c + Vector2(cos(a), sin(a)) * r * (1.0 + 0.32 * tooth))
		draw_colored_polygon(pts, col)
		draw_circle(c, r * 0.45, Color("#3a2416"))

## gold coin icon in the top bar
class Coin extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(20, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(10, 10)
		Draw.radial(self, c, 9.5, [[0.0, Color("#fff0b3")], [0.6, Color("#e0a43a")], [1.0, Color("#9a6a1e")]], 24, Vector2.ONE, Vector2(-2.5, -3))
		draw_arc(c, 8.5, 0, TAU, 24, Color("#b8873a"), 2.0, true)
		draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), Color("#8a5a16"), false, 1.5)

## warm radial backdrop behind the table
class BgPaint extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Style.LACQUER)
		Draw.radial(
			self,
			size * Vector2(0.5, 0.4),
			size.length() * 0.45,
			[[0.0, Color("#2a1810")], [1.0, Style.LACQUER]],
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
		_label = Style.lbl("", 44, Style.GOLD, Style.display_x)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_constant_override("outline_size", 0)
		_label.add_theme_color_override("font_shadow_color", Color("#4a2c0e"))
		_label.add_theme_constant_override("shadow_offset_x", 0)
		_label.add_theme_constant_override("shadow_offset_y", 2)
		add_child(_label)
		visible = false

	func show_text(text: String, foe: bool) -> void:
		_label.text = text
		_foe = foe
		_label.add_theme_color_override("font_color", Style.SEA_HI if foe else Style.GOLD)
		_label.add_theme_color_override("font_shadow_color", Color("#0b2a2e") if foe else Color("#4a2c0e"))
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
		var w := size.x * open
		var r := Rect2((size.x - w) / 2, size.y / 2 - h / 2 - up, w, h)
		var band := Color(0.08, 0.043, 0.03, 0.85 * a)
		Draw.gradient_rect(self, r, [[0.0, Color(band, 0.0)], [0.2, band], [0.8, band], [1.0, Color(band, 0.0)]], false)

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
				Color(0.94, 0.79, 0.42, 0.08),
			)

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
		dim.color = Color(0.02, 0.01, 0.0, 0.82)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(center)
		var card := PanelContainer.new()
		var cs := Style.box(Color(0.10, 0.06, 0.04, 0.98), Color(col, 0.8), 16, 26, 2)
		cs.shadow_color = Color(0, 0, 0, 0.6)
		cs.shadow_size = 30
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
