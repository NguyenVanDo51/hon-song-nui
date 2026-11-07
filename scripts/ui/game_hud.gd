class_name GameHud
extends RefCounted
## GameScreen part (review E5): map frame + board mount, floating HUD (turn / gold / goal, ⏩ ⚙, Hết lượt), ⚙ menu,
## corner card placement, gold count, turn banner. Reads / calls the screen (gs) directly.

const HUD_M := 10.0 # HUD distance from the screen edge

const SEAL := 128.0 # Hết lượt wax seal diameter
var gs: GameScreen
var turn_label: Label
var gold_num: Label
var coins: CoinPop
var gold_shown := -1 # count-up value on screen; -1 = show s.gold[_me()]
var gold_tw: Tween
var btn_hint: Button
var btn_ff: Button
var gear: Button
var menu: PanelContainer
var hud_tr: Control
var card_avoid: Array[Vector2i] = [] # tiles the corner card must not cover (rects rebuilt on placement)
var card_terrain := false # card shows a tile, not a unit: HUD stays up
var card: PanelContainer
var card_box: VBoxContainer
var map_wrap: Control
var btn_end: Button

var _gold_box: HBoxContainer
var _income: Label
var _goal: RichTextLabel
var _btn_speed: Button
var _btn_sound: Button
var _btn_restart: Button
var _hud_tl: Control
var _safe := Rect2() # map area (in _wrap) left free by the HUD
var _frame: Panel
var _banner: HudWidgets.Banner
var _end_pulse: Tween = null

func _init(screen: GameScreen) -> void:
	gs = screen

## backdrop, map wrap (frame, board, coins, banner), top-left / top-right HUD, ⚙ menu, corner card, Hết lượt
func build_hud() -> void:
	var bg := HudWidgets.BgPaint.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gs.add_child(bg)
	map_wrap = Control.new()
	map_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_wrap.clip_contents = true
	map_wrap.resized.connect(fit)
	gs.add_child(map_wrap)
	_frame = Panel.new()
	var fs := Style.box(Color.TRANSPARENT, Style.INK_D, 6, 0, 3)
	fs.shadow_color = Color(0.2, 0.12, 0.05, 0.45)
	fs.shadow_size = 14
	fs.shadow_offset = Vector2(5, 7)
	fs.expand_margin_left = 3
	fs.expand_margin_right = 3
	fs.expand_margin_top = 3
	fs.expand_margin_bottom = 3
	_frame.add_theme_stylebox_override("panel", fs)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_wrap.add_child(_frame)
	make_board()
	coins = CoinPop.new(gs.board)
	map_wrap.add_child(coins)
	_banner = HudWidgets.Banner.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_wrap.add_child(_banner)
	# top-left: turn, gold, goal
	var tl := PanelContainer.new()
	tl.add_theme_stylebox_override("panel", _hud_box())
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.z_index = 40
	gs.add_child(tl)
	_hud_tl = tl
	var tv := Style.vbox(2)
	tl.add_child(tv)
	var th := Style.hbox(10)
	tv.add_child(th)
	turn_label = Style.lbl("Lượt 1", 19, Style.GOLD, Style.display_x)
	th.add_child(turn_label)
	_gold_box = Style.hbox(5)
	_gold_box.add_child(HudWidgets.Coin.new())
	gold_num = Style.lbl("0", 16, Style.GOLD, Style.bold)
	gold_num.pivot_offset = Vector2(10, 10)
	_gold_box.add_child(gold_num)
	_income = Style.lbl("", 13, Style.GOOD, Style.semi)
	_gold_box.add_child(_income)
	th.add_child(_gold_box)
	_goal = Style.rich("", 13, Style.INK)
	_goal.fit_content = true
	_goal.autowrap_mode = TextServer.AUTOWRAP_OFF
	tv.add_child(_goal)
	# top-right: ⏩ (enemy turn) + ⚙
	var top_r := Style.hbox(8)
	top_r.z_index = 40
	top_r.minimum_size_changed.connect(
		func() -> void:
			place_hud.call_deferred(),
	) # ⏩ shown / hidden
	gs.add_child(top_r)
	hud_tr = top_r
	btn_ff = _ibtn(
		"» Tua lượt địch",
		"Chạy nhanh lượt địch (giữ Space / chuột cũng tua)",
		func() -> void:
			gs.turns.ff = true
			btn_ff.visible = false,
	)
	btn_ff.visible = false
	top_r.add_child(btn_ff)
	gear = _ibtn(
		"",
		"Menu, cài đặt",
		func() -> void:
			show_menu(not menu.visible),
	)
	gear.custom_minimum_size = Vector2(44, 40)
	var gi := HudWidgets.GearIcon.new() # no gear glyph in the bundled fonts: drawn
	gi.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear.add_child(gi)
	top_r.add_child(gear)
	_build_menu()
	# bottom-left: what is selected
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _hud_box())
	card.z_index = 40
	card.visible = false
	gs.add_child(card)
	card_box = Style.vbox(5)
	card_box.custom_minimum_size.x = 270
	card.add_child(card_box)
	# bottom-right: Hết lượt
	btn_end = Style.menu_button("Hết lượt", "Còn 0 quân chưa đi", true)
	var end_title: Label = btn_end.get_meta("title")
	var end_sub: Label = btn_end.get_meta("sub")
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# wax seal: round button, crown stamped on top, text below it
	btn_end.theme_type_variation = "SealBtn"
	btn_end.custom_minimum_size = Vector2(SEAL, SEAL)
	end_title.add_theme_font_size_override("font_size", 20)
	end_sub.add_theme_font_size_override("font_size", 10)
	end_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var end_box: VBoxContainer = end_title.get_parent()
	end_box.offset_top = 40
	end_box.offset_bottom = -18
	end_box.offset_left = 10
	end_box.offset_right = -10
	end_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	btn_end.tooltip_text = "Kết thúc lượt (phím E)"
	btn_end.z_index = 40 # over the board, under the orders popup
	btn_end.pressed.connect(
		func() -> void:
			gs.main.audio.play("ui")
			gs.turns.end_player_turn(),
	)
	gs.add_child(btn_end)

func make_board() -> void:
	gs.board = Board.new()
	gs.board.fx = gs.fx
	if coins != null:
		coins.board = gs.board
	gs.board.tile_clicked.connect(gs._on_tile_clicked)
	gs.board.hover_changed.connect(
		func(t: Variant) -> void:
			gs.ui.hover = t
			gs._hover_at = Time.get_ticks_msec()
			gs._build_view(),
	)
	gs.board.cancel_requested.connect(gs.cancel)
	gs.board.info_requested.connect(gs._on_info_requested)
	map_wrap.add_child(gs.board)

func _hud_box() -> StyleBox:
	var b := Style.paper(9.0, 6.0)
	b.frame = false
	b.content_margin_top = 8
	b.content_margin_bottom = 10
	return b

## ⚙ dropdown: hint, unit book, speed, sound, 2D/3D, restart, leave
func _build_menu() -> void:
	menu = PanelContainer.new()
	menu.add_theme_stylebox_override("panel", _hud_box())
	menu.z_index = 55
	menu.visible = false
	gs.add_child(menu)
	var v := Style.vbox(6)
	v.custom_minimum_size.x = 230
	menu.add_child(v)
	var item := func(text: String, tip: String, fn: Callable, close := true) -> Button:
		var b := _ibtn(
			text,
			tip,
			func() -> void:
				if close:
					show_menu(false)
				fn.call(),
		)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 40
		v.add_child(b)
		return b
	btn_hint = item.call("💬 Gợi ý nước đi", "Gợi ý (phím H)", gs._on_hint)
	item.call(
		"📖 Sách lính",
		"Tính chất từng loại quân",
		func() -> void:
			gs.main.menus.open_codex(gs._me()),
	)
	_btn_speed = item.call("", "Tốc độ hoạt cảnh", on_speed, false)
	_btn_sound = item.call(
		"",
		"Âm thanh",
		func() -> void:
			gs.main.audio.set_muted(not gs.main.audio.muted)
			sound_label(),
		false,
	)
	_btn_restart = item.call("↩ Đánh lại màn này", "Chơi lại màn này từ đầu", _confirm_restart)
	item.call(
		"🏠 Về menu chính",
		"Lưu ván và về menu",
		func() -> void:
			gs.save()
			gs.main.show_title(),
	)

func show_menu(on: bool) -> void:
	menu.visible = on
	if on:
		menu.size = Vector2.ZERO
		place_hud()

## map fills the screen; HUD floats over it. Nothing picked: turn/gold (TL), ⏩ ⚙ (TR), end turn (BR).
## Unit picked: only its card, in the first corner that keeps the picked tiles visible.
## Terrain picked: HUD stays; card prefers the free bottom-left corner, else takes a top corner from its HUD panel.
func _side_w() -> float:
	return maxf(card.get_combined_minimum_size().x, 210.0)

func place_hud() -> void:
	if btn_end == null:
		return
	var M := HUD_M
	var picked := card.visible
	var unit_card := picked and not card_terrain
	_hud_tl.visible = not unit_card
	hud_tr.visible = not unit_card
	btn_end.visible = not unit_card
	hud_tr.reset_size()
	var trs := hud_tr.get_combined_minimum_size()
	hud_tr.position = Vector2(gs.size.x - trs.x - M, M)
	_hud_tl.custom_minimum_size.x = 0
	_goal.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hud_tl.reset_size()
	_hud_tl.position = Vector2(M, M)
	btn_end.custom_minimum_size = Vector2(SEAL, SEAL)
	var eb := btn_end.get_combined_minimum_size()
	btn_end.size = eb
	btn_end.position = gs.size - eb - Vector2(M, M)
	if picked:
		card.reset_size()
		var cs := card.get_combined_minimum_size()
		var cands: Array[Vector2] = [Vector2(M, M), Vector2(gs.size.x - cs.x - M, M), Vector2(M, gs.size.y - cs.y - M), gs.size - cs - Vector2(M, M)]
		if card_terrain: # bottom-right = end turn button, never covered
			cands = [cands[2], cands[0], cands[1]]
		card.position = cands[0]
		var avoid: Array[Rect2] = []
		for k: Vector2i in card_avoid:
			var tile_r: Rect2 = gs.board.tile_rect(k.x, k.y)
			avoid.append(Rect2(map_wrap.position + tile_r.position, tile_r.size).grow(tile_r.size.x * 0.5))
		for c: Vector2 in cands:
			var r := Rect2(c, cs)
			if not avoid.any(
				func(a: Rect2) -> bool:
					return r.intersects(a),
			):
				card.position = c
				break
		if card_terrain: # card took a top corner: that corner's HUD panel yields
			_hud_tl.visible = card.position.y > M or card.position.x > M
			hud_tr.visible = card.position.y > M or card.position.x <= M
	if menu.visible:
		var ms := menu.get_combined_minimum_size()
		menu.position = Vector2(gs.size.x - ms.x - M, M + trs.y + 6)

## the whole window is map; the HUD overlays it
func _layout() -> void:
	_safe = Rect2(Vector2.ZERO, map_wrap.size)

func _ibtn(text: String, tip: String, fn: Callable) -> Button:
	var b := Style.button(text, "IconBtn")
	b.tooltip_text = tip
	b.pressed.connect(
		func() -> void:
			gs.main.audio.play("ui")
			fn.call(),
	)
	return b

func speed_label() -> void:
	_btn_speed.text = "» Tốc độ hoạt cảnh: x%d" % int(FX.speed)

func on_speed() -> void:
	FX.speed = 2.0 if FX.speed == 1.0 else (3.0 if FX.speed == 2.0 else 1.0)
	Store.set_v("speed", FX.speed)
	speed_label()

func _confirm_restart() -> void:
	if gs.s.is_empty() or gs.ui.busy:
		return
	gs.main.menus.confirm(
		"Chơi lại [b]%s[/b] từ đầu? Ván này sẽ mất." % gs.def.get("title", ""),
		"Đánh lại",
		func() -> void:
			var c := gs.ctx.duplicate()
			gs.main.start_game(Game.new_game(gs._def_for(c)), c),
	)

func sound_label() -> void:
	Style.set_btn_text(_btn_sound, "🔇 Âm thanh: Tắt" if gs.main.audio.muted else "🔊 Âm thanh: Bật")

func fit() -> void:
	if gs.s.is_empty():
		return
	_layout()
	gs.board.fit(_safe.size - Vector2(8, 8))
	gs.board.position = (_safe.position + (_safe.size - gs.board.size) / 2.0).floor()
	_frame.position = gs.board.position
	_frame.size = gs.board.size
	place_hud()
	gs.panel.place_pop.call_deferred()

func refresh_end_button(my_turn: bool) -> void:
	var units: Array = gs.s.units
	var me := gs._me()
	var left: int = units.filter(
		func(o: Dictionary) -> bool:
			return o.side == me and not o.acted,
	).size()
	var enemy_busy: bool = gs.ui.busy and gs._is_ai(gs._turn_side())
	btn_end.disabled = not my_turn
	var end_title: Label = btn_end.get_meta("title")
	end_title.text = "Lượt địch" if enemy_busy else "Hết lượt"
	var sub := (
		("%s đang ra quân…" % Content.theme().factions[gs.s.side].short)
		if enemy_busy
		else (("Còn %d quân chưa đi" % left) if left > 0 else "Mọi quân đã ra lệnh")
	)
	Style.set_sub(btn_end, sub if (my_turn or enemy_busy) else "")
	# everyone has moved: the button breathes so the next step is obvious
	var hot := my_turn and left == 0
	if hot and _end_pulse == null:
		# seal wobbles (C · Đông Hồ "lắc") so the next step is obvious
		btn_end.pivot_offset = btn_end.size / 2
		_end_pulse = btn_end.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		_end_pulse.tween_property(btn_end, "rotation_degrees", 4.0, 0.3)
		_end_pulse.parallel().tween_property(btn_end, "scale", Vector2(1.05, 1.05), 0.3)
		_end_pulse.tween_property(btn_end, "rotation_degrees", -5.0, 0.3)
		_end_pulse.parallel().tween_property(btn_end, "scale", Vector2.ONE, 0.3)
	elif not hot and _end_pulse != null:
		_end_pulse.kill()
		_end_pulse = null
		btn_end.rotation_degrees = 0.0
		btn_end.scale = Vector2.ONE
	place_hud()

func bump_gold() -> void:
	var tw := gold_num.create_tween()
	tw.tween_property(gold_num, "scale", Vector2(1.25, 1.25), 0.15)
	tw.parallel().tween_property(gold_num, "modulate", Color(1.2, 1.15, 1.0), 0.15)
	tw.tween_property(gold_num, "scale", Vector2.ONE, 0.35)
	tw.parallel().tween_property(gold_num, "modulate", Color.WHITE, 0.35)

func banner(text: String, foe := false) -> void:
	_banner.show_text(text, foe)
	gs.main.audio.play("drum")

func _goal_line() -> String:
	var win: Dictionary = gs.s.win
	var hero_keys: Dictionary = gs.s.heroKey
	var turns: int = win.get("turns", 0)
	var turn: int = gs.s.turn
	var n: Variant = Objectives.bar_n(gs.s)
	if gs.s.has("ctrl"): # 1 vs 1: goal said from the side on screen (bar_n / goal words read as p)
		hero_keys = { "p": gs.s.heroKey[gs._me()], "e": gs.s.heroKey[gs._foe()] }
		n = Game.castles(gs.s, gs._foe())
	var obj := Content.goal_text(win, "bar", hero_keys, { "n": n, "left": maxi(0, turns - turn + 1) })
	return "🎯 %s" % obj

## top-left HUD: turn, gold, income, goal
func refresh_top() -> void:
	var me := gs._me()
	turn_label.text = "Lượt %d" % gs.s.turn + ((" · " + gs._side_name(me)) if gs._hotseat() else "")
	turn_label.add_theme_color_override("font_color", (Style.P_NAME if me == "p" else Style.SEA_HI) if gs._hotseat() else Style.GOLD)
	gold_num.text = str(gs.s.gold[me] if gold_shown < 0 else gold_shown)
	var allowed_me: Array = gs.s.allowed[me]
	_gold_box.visible = allowed_me.size() > 0 or Game.castles(gs.s, me) > 0
	_income.text = "+%d" % Game.income(gs.s, me)
	_goal.text = Icons.bb_text(_goal_line(), 16)
