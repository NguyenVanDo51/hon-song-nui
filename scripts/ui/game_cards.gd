class_name GameCards
extends RefCounted
## GameScreen part (review E5): full-screen cards over the map: new-unit intro, end of game. Reads / calls the screen (gs) directly.

signal intro_closed

var gs: GameScreen
var end_layer: Control
var intro_layer: Control = null
var intro_stage: IntroStage = null

func _init(screen: GameScreen) -> void:
	gs = screen

func build_end() -> void:
	end_layer = Control.new()
	end_layer.z_index = 60 # over the HUD (40) and the popup (50)
	end_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_layer.visible = false
	gs.add_child(end_layer)

## entering a mission: introduce every kind of unit this mission brings (on the map, in its reinforcements, or
## buyable) that the player has never met — all at the start, never mid-battle. Remembered per player
## (Store "seen_units"). Off for bot / nointro runs, which also never write the seen list.
func intro_new_units() -> void:
	if gs.main.flags.has("bot") or gs.main.flags.has("nointro") or gs._intro_on or gs.s.is_empty() or not gs.visible or gs._hotseat():
		return
	var seen: Array = Store.get_v("seen_units", [])
	var fresh := [] # [side, type]
	var keys := []
	var add := func(side: String, type: String) -> void:
		var k := ("hero:%s" % gs.s.heroKey[side]) if type == "hero" else ("unit:%s" % type)
		if not seen.has(k) and not keys.has(k) and (type != "hero" or gs.s.heroKey[side] != null):
			keys.append(k)
			fresh.append({ "side": side, "type": type })
	for side: String in ["p", "e"]:
		for hero_first: bool in [true, false]:
			for u: Dictionary in gs.s.units:
				if u.side == side and (u.type == "hero") == hero_first:
					add.call(side, u.type)
			if side == "e":
				for w: Dictionary in gs.s.waves:
					for wu: Array in w.units:
						if (wu[0] == "hero") == hero_first:
							add.call("e", wu[0])
		var allowed: Dictionary = gs.s.allowed
		for t: String in allowed.get(side, []):
			add.call(side, t)
	if fresh.is_empty():
		return
	gs._intro_on = true
	var my := gs.gen
	for i in fresh.size():
		var card_u: Dictionary = fresh[i]
		await intro_card(card_u, i, fresh.size())
		seen.append(keys[i])
		Store.set_v("seen_units", seen)
		if gs.gen != my:
			break
	gs._intro_on = false

## one card = a short scene of the unit moving + attacking (IntroStage), name + stat icons, almost no text (role / traits
## stay in ⓘ and the codex). Returns when the player dismisses it (button, Space/Enter, or a click outside after a moment)
func intro_card(u: Dictionary, i: int, n: int) -> void:
	var hk: Variant = gs.s.heroKey[u.side]
	var side: String = u.side
	var type: String = u.type
	var look := Content.unit_type_look(side, type, hk)
	var st := Content.type_stat(type, hk)
	var mine: bool = u.side == gs._me()
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 100
	gs.add_child(layer)
	intro_layer = layer
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.16, 0.10, 0.05, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var card := PanelContainer.new()
	var cs := Style.paper(22.0, 10.0)
	card.add_theme_stylebox_override("panel", cs)
	center.add_child(card)
	var v := Style.vbox(6)
	card.add_child(v)
	var side_col := Style.P_NAME if mine else Style.SEA_HI
	var eyebrow := Content.text(("introHero" if u.type == "hero" else "introUnit") + ("P" if mine else "E"))
	var eh := Style.hbox(8)
	var el := Style.lbl(eyebrow, 13, side_col, Style.xbold)
	el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eh.add_child(el)
	if n > 1:
		eh.add_child(Style.lbl("%d / %d" % [i + 1, n], 13, Style.MUTED, Style.semi))
	v.add_child(eh)
	var look_name: String = look.name
	v.add_child(Style.lbl(look_name, 32, Style.GOLD, Style.display_x))
	var stage := IntroStage.new()
	stage.setup(side, type, hk)
	stage.fx.audio = gs.main.audio
	stage.set_meta("card", card)
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(stage)
	intro_stage = stage
	var br := Style.hbox(10)
	br.add_child(_stat_icons(st))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(sp)
	var again := Style.button(Content.text("introReplay"))
	again.custom_minimum_size = Vector2(0, 48)
	again.pressed.connect(stage.play)
	br.add_child(again)
	var ok := Style.button(Content.text("introNext" if i < n - 1 else "introOk"), "PrimaryBtn")
	ok.custom_minimum_size = Vector2(150, 48)
	ok.pressed.connect(
		func() -> void:
			intro_closed.emit(),
	)
	br.add_child(ok)
	v.add_child(br)
	var t0 := Time.get_ticks_msec()
	layer.gui_input.connect(
		func(ev: InputEvent) -> void:
			var mb := ev as InputEventMouseButton
			if mb != null and mb.pressed and Time.get_ticks_msec() - t0 > 600:
				intro_closed.emit(),
	)
	# animate: fade in, card rises, then the scene plays once
	gs.main.audio.play("spawn" if not mine else "rank")
	layer.modulate.a = 0.0
	card.resized.connect(
		func() -> void: # phone landscape: shrink to fit, never clip the top
			var f := minf(1.0, (center.size.y - 16.0) / card.size.y)
			center.pivot_offset = center.size / 2
			center.scale = Vector2(f, f)
			card.pivot_offset = card.size / 2,
	)
	card.scale = Vector2(0.94, 0.94)
	var tw := layer.create_tween().set_parallel(true)
	tw.tween_property(layer, "modulate:a", 1.0, 0.22)
	tw.tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stage.play()
	await intro_closed
	gs.main.audio.play("ui")
	again.disabled = true
	await stage.stop() # its coroutines let go before the layer is freed
	intro_stage = null
	var out := layer.create_tween()
	out.tween_property(layer, "modulate:a", 0.0, 0.15)
	await out.finished
	layer.queue_free()
	intro_layer = null

## ⚔ atk 🛡 def 👣 move 🎯 range: icon + number, nothing else
static func _stat_icons(st: Dictionary) -> HBoxContainer:
	var row := Style.hbox(14)
	var cells := [["sword", str(st.atk)], ["shield", str(st.def)], ["foot", str(st.mv)], ["target", Style.stat_range(st)]]
	for c: Array in cells:
		var cell := Style.hbox(4)
		var ic := TextureRect.new()
		var icon: String = c[0]
		ic.texture = Icons.tex(icon)
		ic.custom_minimum_size = Vector2(24, 24)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(ic)
		var val: String = c[1]
		cell.add_child(Style.lbl(val, 18, Style.INK, Style.xbold))
		row.add_child(cell)
	return row

func show_end(win: bool, text: String, buttons: Array, star_goals: Array = [], best_before := 0) -> void:
	for c in end_layer.get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.10, 0.05, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_layer.add_child(center)
	var card := PanelContainer.new()
	var cs := Style.paper(26.0, 10.0)
	cs.edge = Style.INK_D if win else Style.ROYAL_D
	card.add_theme_stylebox_override("panel", cs)
	card.custom_minimum_size.x = 500
	card.clip_contents = true
	center.add_child(card)
	if win:
		var rays := HudWidgets.Rays.new()
		rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(rays)
	var v := Style.vbox(12)
	card.add_child(v)
	var title_txt := Content.text("victory") if win else Content.text("defeat")
	var duel: bool = gs.ctx.get("kind") == "duel"
	if duel:
		title_txt = Content.text("duelWin").format({ "side": Content.theme().factions[gs.s.winner].name })
	var title := Style.lbl(title_txt, 34 if duel else 46, Style.GOLD if win else Style.SEA_HI, Style.display_x, duel)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var star_row: HudWidgets.StarRow = null
	if star_goals.size():
		star_row = HudWidgets.end_stars(v, star_goals, best_before)
	if text != "":
		var t := Style.lbl(text, 16, Style.INK, null, true)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
	var st := Style.hbox(26)
	st.alignment = BoxContainer.ALIGNMENT_CENTER
	var rows := [[gs.s.turn, "lượt"], [gs.stats[gs._foe()], "địch bị hạ"], [gs.stats[gs._me()], "quân ta ngã"]]
	if duel and gs._hotseat():
		rows = [[gs.s.turn, "lượt"], [gs.stats.p, gs._side_name("p") + " ngã"], [gs.stats.e, gs._side_name("e") + " ngã"]]
	for pair: Array in rows:
		var col := Style.vbox(0)
		var n := Style.lbl(str(pair[0]), 24, Style.INK, Style.display_x)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
		var caption: String = pair[1]
		col.add_child(Style.lbl(caption, 13, Style.MUTED))
		st.add_child(col)
	v.add_child(st)
	var row := Style.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for b: Array in buttons:
		var b_text: String = b[0]
		var b_primary: bool = b[2]
		var btn := Style.menu_button(b_text, "", b_primary)
		var btn_title: Label = btn.get_meta("title")
		btn_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.custom_minimum_size.x = maxf(190.0, btn.custom_minimum_size.x)
		var fn: Callable = b[1]
		btn.pressed.connect(
			func() -> void:
				gs.main.audio.play("ui")
				end_layer.visible = false
				fn.call(),
		)
		row.add_child(btn)
	v.add_child(row)
	end_layer.visible = true
	card.pivot_offset = Vector2(250, 200)
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw := card.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE, 0.5)
	tw.parallel().tween_property(card, "modulate:a", 1.0, 0.3)
	if star_row != null and star_row.got > 0:
		var st_tw := star_row.create_tween()
		st_tw.tween_interval(0.45)
		st_tw.tween_property(star_row, "k", float(star_row.got), 0.42 * star_row.got)
