class_name GameHud
extends RefCounted
## GameScreen part (review E5): map frame + board mount, floating HUD (turn / gold TC, ⏩ ⚙ + quest slip TR, Hết lượt), ⚙ pause,
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
var menu: Control # ⚙ pause screen (dim + card); .visible = open
var hud_tr: Control
var card_avoid: Array[Vector2i] = [] # tiles the corner card must not cover (rects rebuilt on placement)
var card_terrain := false # card shows a tile, not a unit: HUD stays up
var card: PanelContainer
var card_box: VBoxContainer
var map_wrap: Control
var btn_end: Button
var quests: QuestPanel
var queued_runs := 0 # deferred place_hud runs (driver: at most 1 per frame)

var _gold_box: HBoxContainer
var _income: Label
var _btn_speed: Button
var _btn_sound: Button
var _btn_restart: Button
var _btn_surrender: Button # duel / skirmish only: give the game up (Objectives.surrender)
var _btn_music: Button
var _btn_skip: Button
var _pause: PanelContainer
var _ribbon: HudWidgets.Ribbon
var _hud_tc: HBoxContainer
var _safe := Rect2() # map area (in _wrap) left free by the HUD
var _frame: Panel
var _banner: HudWidgets.Banner
var _end_pulse: Tween = null
var _place_queued := false
var _under := false # ⚙ card hidden for the codex / restart ask, game still paused; closing it comes back to the card
var _placed_frame := -1

func _init(screen: GameScreen) -> void:
	gs = screen

## backdrop, map wrap (frame, board, coins, banner), top-centre / top-right HUD, quest slip, ⚙ menu, corner card, Hết lượt
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
	# top-centre: turn + gold, bare ink-outlined text (no panel: covers less of the map)
	_hud_tc = Style.hbox(16)
	_hud_tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_tc.z_index = 40
	gs.add_child(_hud_tc)
	turn_label = Style.lbl(Lang.t("Lượt 1"), 22, Style.PAPER_HI, Style.display_x)
	Style.ink_outline(turn_label, 7)
	_hud_tc.add_child(turn_label)
	_gold_box = Style.hbox(5)
	_gold_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := HudWidgets.Coin.new()
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gold_box.add_child(coin)
	gold_num = Style.lbl("0", 22, Style.LEAF, Style.display_x)
	Style.ink_outline(gold_num, 7)
	gold_num.pivot_offset = Vector2(10, 14)
	_gold_box.add_child(gold_num)
	_income = Style.lbl("", 16, Color("#9ad36f"), Style.display_x)
	Style.ink_outline(_income, 6)
	_gold_box.add_child(_income)
	_hud_tc.add_child(_gold_box)
	# top-right: ⏩ (enemy turn) + ⚙
	var top_r := Style.hbox(8)
	top_r.z_index = 40
	top_r.minimum_size_changed.connect(queue_place) # ⏩ shown / hidden
	gs.add_child(top_r)
	hud_tr = top_r
	btn_ff = _ibtn(
		Lang.t("» Tua lượt địch"),
		Lang.t("Chạy nhanh lượt địch (giữ Space / chuột cũng tua)"),
		func() -> void:
			gs.turns.ff = true
			btn_ff.visible = false,
	)
	btn_ff.visible = false
	top_r.add_child(btn_ff)
	gear = _ibtn(
		"",
		Lang.t("Menu, cài đặt"),
		func() -> void:
			show_menu(not menu.visible),
	)
	gear.custom_minimum_size = Vector2(44, 40)
	var gi := HudWidgets.GearIcon.new() # no gear glyph in the bundled fonts: drawn
	gi.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear.add_child(gi)
	top_r.add_child(gear)
	# under ⏩ ⚙: quests + win line (replaces the old top-left goal slip)
	quests = QuestPanel.new()
	quests.sfx = func() -> void:
		gs.main.audio.play("ui")
	quests.minimum_size_changed.connect(queue_place)
	gs.add_child(quests)
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
	card.minimum_size_changed.connect(queue_place) # wrapped text settles after a pass: size shrinks back with it
	# bottom-right: Hết lượt
	btn_end = Style.menu_button(Lang.t("Hết lượt"), Lang.t("Còn 0 quân chưa đi"), true)
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
	btn_end.tooltip_text = Lang.t("Kết thúc lượt (phím E)")
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
	gs.fx.view_board = gs.board
	gs.board.auto_rotate = true
	if coins != null:
		coins.board = gs.board
	gs.board.tile_clicked.connect(gs._on_tile_clicked)
	gs.board.hover_changed.connect(
		func(t: Variant) -> void:
			gs.ui.hover = t
			gs._hover_at = Time.get_ticks_msec()
			gs._build_view()
			cover_quests(),
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

## ⚙ pause screen: dim board, paper card under a "Tạm dừng" ribbon; resume / hint (big), sound / music / speed (round
## toggles), unit book / restart / leave (small tiles)
func _build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.z_index = 55
	menu.process_mode = Node.PROCESS_MODE_ALWAYS # the rest of the game screen pauses under it
	menu.visible = false
	gs.add_child(menu)
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.10, 0.05, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(
		func(e: InputEvent) -> void:
			var mb := e as InputEventMouseButton
			if mb != null and mb.pressed:
				show_menu(false),
	)
	menu.add_child(dim)
	_pause = PanelContainer.new()
	var ps := Style.paper(22.0)
	ps.content_margin_top = 46
	_pause.add_theme_stylebox_override("panel", ps)
	menu.add_child(_pause)
	_ribbon = HudWidgets.Ribbon.new(Lang.t("Tạm dừng"))
	menu.add_child(_ribbon)
	var v := Style.vbox(12)
	v.custom_minimum_size.x = 380
	_pause.add_child(v)
	var go := _ibtn(
		Lang.t("▶ Tiếp tục"),
		Lang.t("Quay lại ván (Esc)"),
		func() -> void:
			show_menu(false),
	)
	go.theme_type_variation = "PrimaryBtn"
	go.add_theme_font_size_override("font_size", 22)
	go.add_theme_constant_override("icon_max_width", 22)
	v.add_child(go)
	btn_hint = _ibtn(
		Lang.t("💬 Gợi ý nước đi"),
		Lang.t("Gợi ý (phím H)"),
		func() -> void:
			show_menu(false)
			gs._on_hint(),
	)
	btn_hint.theme_type_variation = "RoyalBtn"
	btn_hint.add_theme_constant_override("icon_max_width", 22)
	v.add_child(btn_hint)
	var toggles := Style.hbox(26)
	toggles.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(toggles)
	_btn_sound = _toggle(
		toggles,
		Lang.t("Âm thanh"),
		func() -> void:
			gs.main.audio.set_muted(not gs.main.audio.muted)
			sound_label(),
	)
	_btn_music = _toggle(
		toggles,
		Lang.t("Nhạc"),
		func() -> void:
			gs.main.audio.set_music(not gs.main.audio.music_on)
			sound_label(),
	)
	_btn_speed = _toggle(toggles, Lang.t("Tốc độ"), on_speed)
	_btn_speed.tooltip_text = Lang.t("Tốc độ hoạt cảnh")
	var lang := _toggle(
		toggles,
		Lang.t("Ngôn ngữ"),
		func() -> void:
			gs.main.switch_lang(true),
	)
	lang.text = Lang.current.to_upper()
	lang.tooltip_text = Lang.NAMES[Lang.current]
	var hr := ColorRect.new()
	hr.color = Color(Style.INK_D, 0.25)
	hr.custom_minimum_size.y = 2
	v.add_child(hr)
	var row := Style.hbox(10)
	v.add_child(row)
	var tile := func(text: String, tip: String, fn: Callable, keep_paused: bool) -> Button:
		var b := _ibtn(
			text,
			tip,
			func() -> void:
				if keep_paused:
					_under = true
					menu.visible = false
				else:
					show_menu(false)
				fn.call(),
		)
		b.theme_type_variation = "TileBtn"
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 64
		row.add_child(b)
		return b
	tile.call(
		Lang.t("📖 Sách lính"),
		Lang.t("Tính chất từng loại quân"),
		func() -> void:
			gs.main.menus.open_codex(gs._me()),
		true,
	)
	gs.main.menus.codex_closed.connect(back_to_menu)
	_btn_restart = tile.call(Lang.t("↩ Đánh lại"), Lang.t("Chơi lại màn này từ đầu"), _confirm_restart, true)
	var home: Button = tile.call(
		Lang.t("🏠 Về menu"),
		Lang.t("Lưu ván và về menu chính"),
		func() -> void:
			gs.save()
			gs.main.show_title(),
		false,
	)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		home.add_theme_color_override(c, Style.CRIMSON_D)
	_btn_surrender = _ibtn(
		Lang.t("🏳 Đầu hàng"),
		Lang.t("Chịu thua ván này ngay"),
		func() -> void:
			_under = true
			menu.visible = false
			_confirm_surrender(),
	)
	_btn_surrender.theme_type_variation = "TileBtn"
	_btn_surrender.custom_minimum_size.y = 48
	v.add_child(_btn_surrender)
	_btn_skip = _ibtn(
		Content.text("tutSkip"),
		Content.text("tutSkipTip"),
		func() -> void:
			show_menu(false)
			_skip_tutorial(),
	)
	_btn_skip.theme_type_variation = "TileBtn"
	_btn_skip.custom_minimum_size.y = 48
	v.add_child(_btn_skip)

## round on/off button with a small caption under it
func _toggle(parent: Control, caption: String, fn: Callable) -> Button:
	var col := Style.vbox(4)
	parent.add_child(col)
	var b := _ibtn("", caption, fn)
	b.theme_type_variation = "RoundOn"
	b.custom_minimum_size = Vector2(58, 58)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 28)
	col.add_child(b)
	var l := Style.lbl(caption, 12, Style.MUTED, Style.bold)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	return b

## ⚙ = real pause: game screen (its _process, tweens, FX.sleep timers) + FX.now() stop; resume continues mid-animation
func show_menu(on: bool) -> void:
	_under = false
	menu.visible = on
	gs.get_tree().paused = on
	PauseClock.hold(on)
	if on and gs.tutorial != null:
		gs.tutorial.visible = false # its _process (which hides it under the menu) is paused too
	_btn_skip.visible = gs.def.has("tutorial")
	_btn_surrender.visible = can_surrender()
	_btn_surrender.disabled = not gs._human_turn() # vs AI: only on our own turn (state is not mid-AI-step)
	if on:
		sound_label()
		speed_label()
		place_hud()

## map fills the screen; HUD floats over it. Nothing picked: turn/gold (TC), ⏩ ⚙ + quest slip (TR), end turn (BR).
## Unit picked: only its card, on the screen half away from the picked tile, first corner keeping picked tiles visible.
## Terrain picked: HUD stays; card prefers the free bottom-left corner, else takes a top corner from its HUD panel.
func _side_w() -> float:
	return maxf(card.get_combined_minimum_size().x, 210.0)

## layout from a minimum_size_changed: never more than 1 queued, and at most 1 per frame -> no emit pattern can loop
func queue_place() -> void:
	if _place_queued:
		return
	_place_queued = true
	if Engine.get_process_frames() == _placed_frame:
		gs.get_tree().process_frame.connect(_queued_place, CONNECT_ONE_SHOT)
	else:
		_queued_place.call_deferred()

func _queued_place() -> void:
	_place_queued = false
	_placed_frame = Engine.get_process_frames()
	queued_runs += 1
	place_hud()

func place_hud() -> void:
	if btn_end == null:
		return
	var e := Style.safe_insets(gs) # phone notch / rounded corners
	var L := HUD_M + e.x
	var T := HUD_M + e.y
	var R := HUD_M + e.z
	var B := HUD_M + e.w
	var picked := card.visible
	var unit_card := picked and not card_terrain
	# visibility set once at the end: toggling mid-layout re-fires minimum_size_changed -> place_hud loop
	var tc_on := not unit_card
	var tr_on := not unit_card or (gs.tutorial != null and gs.tutorial.active()) # ⚙ (Bỏ qua hướng dẫn) reachable in every step
	btn_end.visible = not unit_card
	hud_tr.reset_size()
	var trs := hud_tr.get_combined_minimum_size()
	hud_tr.position = Vector2(gs.size.x - trs.x - R, T)
	_hud_tc.reset_size()
	var tcs := _hud_tc.get_combined_minimum_size()
	var tc_x := maxf((gs.size.x - tcs.x) / 2.0, L)
	if tc_x + tcs.x > hud_tr.position.x - 10: # narrow screen: top-left is free
		tc_x = L + 6
	_hud_tc.position = Vector2(tc_x, T + 2)
	# quest slip right-aligned under ⏩ ⚙; drops below turn / gold if they would touch
	quests.reset_size()
	var qs := quests.get_combined_minimum_size()
	var qp := Vector2(gs.size.x - qs.x - R, T + trs.y + 6)
	var tc_r := Rect2(_hud_tc.position, tcs).grow(6)
	if Rect2(qp, qs).intersects(tc_r):
		qp.y = tc_r.end.y
	quests.position = qp
	btn_end.custom_minimum_size = Vector2(SEAL, SEAL)
	var eb := btn_end.get_combined_minimum_size()
	btn_end.size = eb
	btn_end.position = gs.size - eb - Vector2(R, B)
	if picked:
		card.reset_size()
		var cs := card.get_combined_minimum_size()
		var c_tl := Vector2(L, T)
		var c_tr := Vector2(gs.size.x - cs.x - R, T)
		var c_bl := Vector2(L, gs.size.y - cs.y - B)
		var c_br := gs.size - cs - Vector2(R, B)
		# picked tile on the left half (even by a hair) -> card on the right side, else on the left; top before bottom
		var on_left := true
		if not card_avoid.is_empty():
			var pk: Vector2i = card_avoid[0]
			on_left = map_wrap.position.x + gs.board.tile_rect(pk.x, pk.y).get_center().x < gs.size.x / 2.0
		var cands: Array[Vector2] = []
		if card_terrain: # bottom-right = end turn button, never covered
			cands.assign([c_tr, c_bl, c_tl] if on_left else [c_bl, c_tl, c_tr])
		else:
			cands.assign([c_tr, c_br, c_tl, c_bl] if on_left else [c_tl, c_bl, c_tr, c_br])
			if gs.tutorial != null and gs.tutorial.active(): # ⚙ (Bỏ qua hướng dẫn) stays reachable: no top-right card
				cands.erase(c_tr)
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
		if card_terrain: # card took a top corner: that corner's HUD yields
			tr_on = card.position.y > T or card.position.x <= L
			tc_on = not Rect2(card.position, cs).intersects(Rect2(_hud_tc.position, tcs))
	_set_shown(_hud_tc, tc_on)
	_set_shown(hud_tr, tr_on)
	_set_shown(quests, tr_on and not unit_card)
	if menu.visible:
		_place_pause()
	cover_quests()

static func _set_shown(c: Control, on: bool) -> void:
	if c.visible != on:
		c.visible = on

## quest slip fades while board content is under it
func cover_quests() -> void:
	if quests != null and gs.board != null and not gs.s.is_empty():
		quests.update_cover(gs.board, map_wrap.position)

## pause card centred (ribbon overhangs its top edge), shrunk to fit short phone screens
func _place_pause() -> void:
	_pause.reset_size()
	_ribbon.reset_size()
	var ps := _pause.get_combined_minimum_size()
	var rs := _ribbon.get_combined_minimum_size()
	var e := Style.safe_insets(gs)
	var room := gs.size - Vector2(e.x + e.z, e.y + e.w)
	var k := minf(1.0, minf((room.y - 24.0) / (ps.y + rs.y / 2.0), (room.x - 24.0) / ps.x))
	var top := e.y + (room.y - (ps.y + rs.y / 2.0) * k) / 2.0 + rs.y / 2.0 * k
	_pause.scale = Vector2(k, k)
	_pause.position = Vector2(e.x + (room.x - ps.x * k) / 2.0, top).floor()
	_ribbon.scale = Vector2(k, k)
	_ribbon.position = (_pause.position + Vector2((ps.x - rs.x) / 2.0, -rs.y / 2.0 - 4.0) * k).floor()

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
	_btn_speed.text = "x%d" % int(FX.speed)

func on_speed() -> void:
	FX.speed = 2.0 if FX.speed == 1.0 else (3.0 if FX.speed == 2.0 else 1.0)
	Store.set_v("speed", FX.speed)
	speed_label()

## tutorial level: counts as a 1-star win (best kept), back to the level grid
func _skip_tutorial() -> void:
	var id := str(gs.ctx.get("id", ""))
	Store.clear_game()
	Store.record_result(gs.ctx, "p", 1)
	gs.main.show_levels(id)

## codex / restart ask opened from ⚙ closed without leaving: back to the pause card
func back_to_menu() -> void:
	if _under:
		show_menu(true)

func _confirm_restart() -> void:
	if gs.s.is_empty() or gs.ui.busy:
		back_to_menu() # nothing to ask mid-animation: stay on the card
		return
	gs.main.menus.confirm(
		Lang.t("Chơi lại [b]%s[/b] từ đầu? Ván này sẽ mất.") % gs.def.get("title", ""),
		Lang.t("Đánh lại"),
		func() -> void:
			var c := gs.ctx.duplicate()
			gs.main.start_game(Game.new_game(gs._def_for(c)), c),
		"",
		Callable(),
		back_to_menu,
	)

## Đầu hàng only where a lost game cannot be won back by retrying a level: 1 vs 1 + skirmish
func can_surrender() -> bool:
	var kind: String = gs.ctx.get("kind", "")
	return kind == "duel" or kind == "skirmish"

func _confirm_surrender() -> void:
	if gs.s.is_empty() or gs.ui.busy or gs.s.winner != null or not gs._human_turn():
		back_to_menu()
		return
	var side := gs._me()
	var who := gs._side_name(side) if gs._hotseat() else Lang.t("Quân ta")
	gs.main.menus.confirm(
		Lang.t("Đầu hàng? [b]%s[/b] sẽ thua ván này.") % who,
		Lang.t("Đầu hàng"),
		func() -> void:
			show_menu(false)
			Objectives.surrender(gs.s, side)
			MatchRec.step(gs.s, { "kind": "surrender", "side": side })
			GameLog.crumb("surrender side %s turn %s" % [side, gs.s.turn])
			gs.turns.finish(),
		"",
		Callable(),
		back_to_menu,
	)

func sound_label() -> void:
	var muted := gs.main.audio.muted
	var music := gs.main.audio.music_on
	_btn_sound.icon = Icons.tex("mute" if muted else "sound")
	_btn_sound.theme_type_variation = "RoundOff" if muted else "RoundOn"
	_btn_sound.tooltip_text = Lang.t("Âm thanh: %s") % (Lang.t("tắt") if muted else Lang.t("bật"))
	_btn_music.icon = Icons.tex("music_off" if not music else "music")
	_btn_music.theme_type_variation = "RoundOff" if not music else "RoundOn"
	_btn_music.tooltip_text = Lang.t("Nhạc: %s") % (Lang.t("tắt") if not music else Lang.t("bật"))

func fit() -> void:
	if gs.s.is_empty():
		return
	_layout()
	gs.board.fit(_safe.size - Vector2(8, 8))
	gs.board.place((_safe.position + (_safe.size - gs.board.visual_size()) / 2.0).floor())
	var vr := gs.board.visual_rect()
	_frame.position = vr.position
	_frame.size = vr.size
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
	end_title.text = Lang.t("Lượt địch") if enemy_busy else Lang.t("Hết lượt")
	var sub := (
		(Lang.t("%s đang ra quân…") % Content.theme().factions[gs.s.side].short)
		if enemy_busy
		else ((Lang.t("Còn %d quân chưa đi") % left) if left > 0 else Lang.t("Mọi quân đã ra lệnh"))
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

## the turn banner is still on screen (the tutorial guide waits for it)
func banner_on() -> bool:
	return _banner.visible

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
	return obj

## top-centre turn / gold / income, quest slip (win line changes with the turns left)
func refresh_top() -> void:
	var me := gs._me()
	turn_label.text = Lang.t("Lượt %d") % gs.s.turn + ((" · " + gs._side_name(me)) if gs._hotseat() else "")
	turn_label.add_theme_color_override("font_color", (Style.P_NAME if me == "p" else Style.E_NAME) if gs._hotseat() else Style.PAPER_HI)
	gold_num.text = str(gs.s.gold[me] if gold_shown < 0 else gold_shown)
	var allowed_me: Array = gs.s.allowed[me]
	_gold_box.visible = allowed_me.size() > 0 or Game.castles(gs.s, me) > 0
	_income.text = "+%d" % Game.income(gs.s, me)
	quests.win_line = _goal_line()
	quests.refresh()
