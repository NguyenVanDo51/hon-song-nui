class_name InfoPanel
extends RefCounted
## GameScreen part (review E5): orders / unit / buy popup beside the selection (content + placement), corner card text,
## attack forecast + modifier lines. Reads / calls the screen (gs) directly.

const POP_W := 290.0

var gs: GameScreen
var info: VBoxContainer
var actions: GridContainer
var pop: PanelContainer

var _pop_box: StyleBox # popup panel; dropped when the popup holds only buttons
var _pop_anchor: Variant = null # [x, y] tile the popup belongs to; null = top centre of the board
var _pop_pending := false
var _pop_placed_at: Variant = null

func _init(screen: GameScreen) -> void:
	gs = screen

## orders popup pinned next to the selected tile
func build_pop() -> void:
	pop = PanelContainer.new()
	var ps := Style.paper(11.0, 6.0)
	_pop_box = ps
	pop.add_theme_stylebox_override("panel", ps)
	pop.z_index = 50 # above board tokens / FX and the HUD
	pop.visible = false
	gs.hud.map_wrap.add_child(pop)
	var pv := Style.vbox(8)
	pv.custom_minimum_size.x = POP_W
	pop.add_child(pv)
	info = Style.vbox(6)
	pv.add_child(info)
	actions = GridContainer.new() # columns set per content in refresh(): 2 -> 1 row, 3 -> 1 row, 4 -> 2x2
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	pv.add_child(actions)

func _note(bb: String, color := Style.MUTED, fs := 14) -> RichTextLabel:
	return Style.rich(bb, fs, color, Style.INK)

func _head(token: Control, title: String, sub: String, side := "") -> HBoxContainer:
	var h := Style.hbox(10)
	if token:
		h.add_child(token)
	var v := Style.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := Style.P_NAME if side == "p" else (Style.SEA_HI if side == "e" else Style.GOLD)
	v.add_child(Style.lbl(title, 20, col, Style.display))
	if sub != "":
		v.add_child(Style.lbl(sub, 13, Style.MUTED, null, true))
	h.add_child(v)
	return h

func _act(label: String, fn: Callable, opts := { }) -> Button:
	var hot: bool = opts.get("hot", false)
	var go: bool = opts.get("go", false)
	var b := Style.button(label, ("ActGoHot" if hot else "ActGo") if go else ("ActHot" if hot else "ActBtn"))
	if opts.has("act"): # order kind: the tutorial holes the button that finishes its step
		b.set_meta("act", opts.act)
	b.disabled = opts.get("disabled", false)
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(52, 44)
	b.pressed.connect(
		func() -> void:
			gs.main.audio.play("ui")
			fn.call(),
	)
	if hot:
		var tw := b.create_tween().set_loops()
		tw.tween_property(b, "modulate", Color(1.18, 1.12, 1.0), 0.7)
		tw.tween_property(b, "modulate", Color.WHITE, 0.7)
	return b

## where the unit is shown standing: its picked destination while selected, else its tile
func _shown_at(u: Dictionary) -> Array:
	return gs.ui.dest if u.id == gs.ui.sel and gs.ui.dest != null and gs.ui.mode != gs.M_IDLE else [u.x, u.y]

## "Công · Thủ · Đi · Tầm" line with live buffs (unit card + corner card)
func _stat_note(u: Dictionary, st: Dictionary, b: Dictionary) -> Control:
	return _note(
		"Công %s · Thủ %s · Đi [b]%d[/b] · Tầm [b]%s[/b]" % [_atk_txt(u, b), _def_txt(u, st, b), st.mv, Style.stat_range(st)],
		Style.MUTED,
		14,
	)

## compact unit card for the popup: token + name + side/HP/XP, HP bar, one stat line; full = also the unit's description
func _unit_info(u: Dictionary, full := false) -> void:
	var st := Game.stat(gs.s, u)
	var look := Content.unit_look(gs.s, u)
	var dt := _shown_at(u)
	var dtx: int = dt[0]
	var dty: int = dt[1]
	var t: String = gs.s.tiles[dty][dtx]
	var next: Variant = null
	if u.rank < Rules.RULES.maxRank:
		next = Game.xp_need(gs.s, u)
	var look_name: String = look.name
	var rank: int = u.rank
	var side: String = u.side
	var type: String = u.type
	var hp: float = u.hp
	var title: String = Content.unit_title(look_name, rank, type == "hero")
	var sub := "Máu %d · KN %d%s · %s +%d thủ" % [
		u.hp,
		u.xp,
		("/%d" % next) if next != null else " (tối đa)",
		Content.terrain(t).name,
		Game.terrain_def(gs.s, u, dtx, dty),
	]
	info.add_child(_head(Token.make(side, type, gs.s.heroKey[side], 40), title, sub, side))
	info.add_child(Style.Bar.make(hp / 100.0, 6, Color("#5fa83c"), Style.GOOD))
	var b := Game.buffs_at(gs.s, u, dtx, dty)
	info.add_child(_stat_note(u, st, b))
	for line: String in _buff_lines(u, b):
		info.add_child(_note(line, Style.INK, 13))
	if full:
		var desc: String = look.blurb if u.type == "hero" else look.desc
		info.add_child(_note(desc, Style.MUTED, 13))
		var traits: Array = Content.traits(type, gs.s.heroKey[side])
		if traits.size():
			info.add_child(
				_note(
					"\n".join(
						traits.map(
							func(x: String) -> String:
								return "• " + x,
						)
					),
					Style.INK,
					13,
				)
			)
		info.add_child(_note("[b]Cách dùng:[/b] " + Content.how_to_play(type), Style.GOLD, 13))
	if u.get("guard", false):
		info.add_child(_note("💤 Đang canh gác: chỉ ra tay khi quân ta tới gần.", Style.MUTED, 13))

## bottom-left card: the selected unit's basics + "Chi tiết", or the clicked tile. Hidden when nothing is picked
## (or while the full unit card is open beside its tile).
func _render_card(u: Variant, peek: Variant) -> void:
	for c in gs.hud.card_box.get_children():
		gs.hud.card_box.remove_child(c)
		c.queue_free()
	var show_card := false
	gs.hud.card_terrain = false
	gs.hud.card_avoid.clear()
	if peek == null and u != null:
		show_card = true
		var cu: Dictionary = u
		var st := Game.stat(gs.s, cu)
		var look := Content.unit_look(gs.s, cu)
		var dt := _shown_at(cu)
		var ux: int = cu.x
		var uy: int = cu.y
		var dtx: int = dt[0]
		var dty: int = dt[1]
		_avoid_tile(ux, uy)
		_avoid_tile(dtx, dty)
		var look_name: String = look.name
		var rank: int = cu.rank
		var side: String = cu.side
		var type: String = cu.type
		var hp: float = cu.hp
		var title: String = Content.unit_title(look_name, rank, type == "hero")
		var side_txt: String = gs._side_name(side)
		var sub := "%s · Máu %d%s" % [side_txt, u.hp, " · đã đi" if u.side == gs._me() and u.acted else ""]
		gs.hud.card_box.add_child(_head(Token.make(side, type, gs.s.heroKey[side], 38), title, sub, side))
		gs.hud.card_box.add_child(Style.Bar.make(hp / 100.0, 5, Color("#5fa83c"), Style.GOOD))
		var b := Game.buffs_at(gs.s, cu, dtx, dty)
		gs.hud.card_box.add_child(_stat_note(cu, st, b))
		var id: int = u.id
		var more := Style.button("📜 Chi tiết", "ChipBtn")
		more.tooltip_text = "Tính chất, cách dùng, kinh nghiệm"
		more.size_flags_horizontal = Control.SIZE_SHRINK_END
		more.pressed.connect(
			func() -> void:
				gs._on_info_requested(id),
		)
		gs.hud.card_box.add_child(more)
	elif peek == null and gs.ui.info != null:
		show_card = true
		gs.hud.card_terrain = true
		var x: int = gs.ui.info.x
		var y: int = gs.ui.info.y
		var t: String = gs.s.tiles[y][x]
		_avoid_tile(x, y)
		var owners: Dictionary = gs.s.owner
		var own: Variant = owners.get(Vector2i(x, y))
		var ter: Dictionary = Rules.TERRAIN[t]
		var own_txt := ""
		if ter.has("building"):
			own_txt = " · " + (_owner_txt(str(own)) if own != null else "chưa ai chiếm")
		var ter_name: String = Content.terrain(t).name
		var ter_cost: float = ter.cost
		var cost_txt := "không qua" if ter_cost == INF else str(int(ter_cost))
		gs.hud.card_box.add_child(_head(null, ter_name + own_txt, "Thủ +%d · Giá đi %s" % [ter.def, cost_txt]))
		var note := Content.tile_note(t)
		if note != "":
			gs.hud.card_box.add_child(_note(note, Style.MUTED, 13))
		if Game.grave_at(gs.s, x, y) != null:
			gs.hud.card_box.add_child(_note(Content.text("graveNote"), Style.MUTED, 13))
	gs.hud.card.visible = show_card
	gs.hud.card.reset_size()
	gs.hud.place_hud() # swap HUD vs card now, so a click this frame finds the right buttons
	gs.hud.place_hud.call_deferred() # wrapped text knows its height after one layout pass

func _owner_txt(own: String) -> String:
	if gs._hotseat():
		return "của " + gs._side_name(own)
	return "của ta" if own == gs._me() else "của địch"

## picked tile + a half-tile ring, in screen coords
func _avoid_tile(x: int, y: int) -> void:
	gs.hud.card_avoid.append(Vector2i(x, y))

## "50–55 +10" (roll range incl. level, then live bonus / malus)
func _atk_txt(u: Dictionary, b: Dictionary) -> String:
	var r := Game.atk_range(gs.s, u)
	var lo: int = r[0]
	var hi: int = r[1]
	var t := "[b]%s[/b]" % Style.range_txt(lo, hi)
	var net: int = b.atk - b.poison
	if net:
		t += " [color=#%s][b]%+d[/b][/color]" % [(Board.BUFF_UP if net > 0 else Style.BAD).to_html(false), net]
	return t

func _def_txt(u: Dictionary, st: Dictionary, b: Dictionary) -> String:
	var t := "[b]%d[/b]" % (st.def + Rules.RULES.rankBonus * u.rank)
	var net: int = b.def - b.poison
	if net:
		t += " [color=#%s][b]%+d[/b][/color]" % [(Board.BUFF_UP if net > 0 else Style.BAD).to_html(false), net]
	return t

## the live bonuses as words: who gives them and when they count
func _buff_lines(u: Dictionary, b: Dictionary) -> Array:
	var out := []
	if b.atk_from == "aura":
		out.append("[color=#%s]⚔ +%d công[/color] nhờ tu sĩ ban phước, tới lượt sau của phe mình." % [Board.BUFF_UP.to_html(false), b.aura])
	if b.def_from == "water":
		out.append(
			"[color=#%s]🛡 +%d thủ, +%d công[/color] khi đứng dưới sông."
			% [Board.BUFF_UP.to_html(false), b.def, Game.stat(gs.s, u).get("waterAtk", 0)]
		)
	if b.poison:
		out.append("[color=#%s]🐺 Bị sói cắn: −%d công, −%d thủ[/color] tới lượt sau của phe kia." % [Style.BAD.to_html(false), b.poison, b.poison])
	return out

## why the forecast numbers are what they are: every modifier that touches this attack
func _mods_line(u: Dictionary, dx: int, dy: int, tgt: Dictionary) -> String:
	var parts := []
	var su := Game.stat(gs.s, u)
	var stg := Game.stat(gs.s, tgt)
	var bu := Game.buffs_at(gs.s, u, dx, dy)
	var r := Game.atk_range(gs.s, u)
	var lo: int = r[0]
	var hi: int = r[1]
	parts.append("công " + Style.range_txt(lo, hi))
	if bu.atk:
		parts.append(
			"[color=#%s]+%d công[/color] (%s)" % [Board.BUFF_UP.to_html(false), bu.atk, "tu sĩ ban phước" if bu.atk_from == "aura" else "dưới sông"]
		)
	if bu.poison:
		parts.append("[color=#%s]−%d công[/color] (bị cắn)" % [Style.BAD.to_html(false), bu.poison])
	if su.get("antiAir", 0) and stg.move == "fly":
		parts.append("+%d công đánh rồng" % su.antiAir)
	var vs_type: Dictionary = su.get("vsType", { })
	var vs: int = vs_type.get(tgt.type, 0)
	var tside: String = tgt.side
	var ttype: String = tgt.type
	var tx: int = tgt.x
	var ty: int = tgt.y
	if vs:
		var tname: String = Content.unit_type_look(tside, ttype, null).name
		parts.append("+%d công đánh %s" % [vs, tname.to_lower()])
	var bt := Game.buffs_at(gs.s, tgt, tx, ty)
	if bt.terrain:
		var tt: String = gs.s.tiles[ty][tx]
		var ter_name: String = Content.terrain(tt).name
		parts.append("địch được %s +%d thủ" % [ter_name.to_lower(), bt.terrain])
	if bt.def:
		parts.append("[color=#%s]địch +%d thủ[/color] dưới sông" % [Style.BAD.to_html(false), bt.def])
	if bt.poison:
		parts.append("[color=#%s]địch −%d thủ[/color] (bị cắn)" % [Board.BUFF_UP.to_html(false), bt.poison])
	if not Game.can_counter(gs.s, tgt, dx, dy):
		parts.append("địch không đánh trả được")
	return " · ".join(parts)

func clear_pop() -> void:
	for c in info.get_children() + actions.get_children():
		c.get_parent().remove_child(c) # now, so the popup measures only the new content
		c.queue_free()

## corner card + orders / unit / buy popup for the current selection
func render_pop(my_turn: bool) -> void:
	var me := gs._me()
	_pop_anchor = null
	var u: Variant = gs._sel_unit()
	var peek: Variant = null
	if gs.ui.peek != null:
		var peek_id: int = gs.ui.peek
		peek = Game.unit_by_id(gs.s, peek_id)
	_render_card(u, peek)
	if gs.ui.busy:
		pass
	elif peek != null:
		_pop_anchor = [peek.x, peek.y]
		var pu: Dictionary = peek
		_unit_info(pu, true)
		actions.add_child(
			_act(
				"✖ Đóng",
				func() -> void:
					gs.ui.peek = null
					gs.refresh(),
			)
		)
	elif u != null:
		var su: Dictionary = u
		if my_turn and u.side == me and not u.acted and gs.ui.mode != gs.M_IDLE:
			_pop_anchor = gs.ui.dest
			var dx: int = gs.ui.dest[0]
			var dy: int = gs.ui.dest[1]
			var targets := Game.targets_from(gs.s, su, dx, dy)
			if gs.ui.mode == gs.M_TARGET:
				var tgt: Variant = null
				if gs.ui.target != null:
					var target_id: int = gs.ui.target
					tgt = Game.unit_by_id(gs.s, target_id)
				if tgt != null:
					var td: Dictionary = tgt
					var p := Game.preview(gs.s, su, dx, dy, td)
					info.add_child(_note("Đánh [b]%s[/b] (máu %d):" % [gs._name_of(td), tgt.hp]))
					info.add_child(_preview_box(p))
					var mods := _mods_line(su, dx, dy, td)
					if mods != "":
						info.add_child(_note(mods, Style.MUTED, 12))
					var tid: int = tgt.id
					actions.add_child(
						_act(
							"⚔ Đánh",
							func() -> void:
								gs.commit({ "kind": "attack", "target": tid }),
							{ "act": "attack", "hot": true, "go": true },
						)
					)
				else:
					info.add_child(_note("Bấm vào kẻ địch viền đỏ để chọn mục tiêu."))
				actions.add_child(
					_act(
						"↩ Quay lại",
						func() -> void:
							gs.ui.mode = gs.M_MOVED
							gs.ui.target = null
							gs.refresh(),
					)
				)
			else:
				var hk: Variant = gs.ui.hintKind
				if targets.size():
					actions.add_child(
						_act(
							"⚔ Đánh (%d)" % targets.size(),
							func() -> void:
								gs.ui.mode = gs.M_TARGET
								var best: Variant = null
								var best_sc := -INF
								for t2: Dictionary in targets:
									var sc2 := gs._attack_score(Game.preview(gs.s, su, dx, dy, t2))
									if sc2 > best_sc:
										best_sc = sc2
										best = t2
								gs.ui.target = best.id
								gs.refresh(),
							{ "act": "attack" },
						)
					)
				if Game.can_capture(gs.s, su, dx, dy):
					actions.add_child(
						_act(
							"🏯 Chiếm lâu đài" if Game.sells(gs.s.tiles[dy][dx]) else "🏠 Chiếm làng",
							func() -> void:
								gs.commit({ "kind": "capture" }),
							{ "act": "capture", "hot": hk == "capture" or hk == null, "go": true },
						)
					)
				if Game.can_repair(gs.s, su, dx, dy):
					info.add_child(_note("Làng cháy: dựng lại xong thành làng chưa ai chiếm, lượt sau mới chiếm được."))
					actions.add_child(
						_act(
							"🔨 Dựng lại làng",
							func() -> void:
								gs.commit({ "kind": "repair" }),
							{ "act": "repair", "hot": hk == "repair" or hk == null, "go": true },
						)
					)
				var razes := Game.razable_from(gs.s, su, dx, dy)
				if razes.size():
					var rt: Array = gs.ui.raze if gs.ui.raze != null and razes.has(gs.ui.raze) else gs._best_raze(razes)
					if gs.ui.raze != null:
						info.add_child(_note("Đốt làng viền vàng: thành [b]làng cháy[/b], ai muốn chiếm phải cho lính dựng lại trước."))
					actions.add_child(
						_act(
							"💥 Đốt làng",
							func() -> void:
								gs.commit({ "kind": "raze", "target": rt }),
							{ "act": "raze", "hot": gs.ui.raze != null or hk == "raze", "go": true },
						)
					)
				var graves := Game.raisable_graves(gs.s, su, dx, dy)
				if graves.size():
					var g0: Dictionary = graves[0]
					actions.add_child(
						_act(
							Content.text("raiseButton"),
							func() -> void:
								gs.commit({ "kind": "raise", "target": [g0.x, g0.y] }),
							{ "act": "raise", "hot": hk == "raise" },
						)
					)
				if dx == u.x and dy == u.y and gs._can_buy_here(su):
					var bx: int = u.x
					var by: int = u.y
					actions.add_child(
						_act(
							"🏯 Mộ quân",
							func() -> void:
								gs._clear_sel()
								gs.ui.buyAt = [bx, by]
								gs.main.audio.play("select")
								gs.refresh(),
						)
					)
				if dx != u.x or dy != u.y: # no "wait" on its own tile
					actions.add_child(
						_act(
							"⏳ Chờ",
							func() -> void:
								gs.commit({ "kind": "wait" }),
							{ "act": "wait", "hot": hk == "wait" },
						)
					)
				actions.add_child(_act("✖ Hủy", gs.cancel))
		else:
			pass # stats live in the corner card; choosing where to go = the board (blue tiles, red-ringed enemies)
	elif gs.ui.buyAt != null:
		var x: int = gs.ui.buyAt[0]
		var y: int = gs.ui.buyAt[1]
		_pop_anchor = [x, y]
		info.add_child(
			_head(
				null,
				Content.text("buyTitle"),
				"Có %d vàng · Quân %d/%d · lính mới đi được ngay" % [gs.s.gold[me], Game.cap_count(gs.s, me), gs.s.unitCap],
			)
		)
		var grid := GridContainer.new()
		grid.columns = 1
		grid.add_theme_constant_override("v_separation", 6)
		grid.custom_minimum_size.x = POP_W
		for o: Dictionary in Game.buy_options(gs.s, me, x, y):
			var type: String = o.type
			var look := Content.unit_type_look(me, type, gs.s.heroKey[me])
			var b := _act(
				"",
				func() -> void:
					gs.buy_unit(type),
				{ "disabled": not o.ok or not my_turn, "hot": gs.ui.hotBuy == o.type },
			)
			b.tooltip_text = look.blurb if o.type == "hero" else look.desc
			b.set_meta("buy", type) # tutorial: the step's buy button gets the hole
			b.custom_minimum_size = Vector2(POP_W, 46)
			var row := Style.hbox(8)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			row.offset_left = 8
			row.offset_right = -12
			var tk := Token.make(me, type, gs.s.heroKey[me], 32)
			tk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(tk)
			var look_name: String = look.name
			var nm := Style.lbl(look_name, 16, Style.INK if o.ok else Color(Style.INK, 0.45), Style.bold)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			nm.size_flags_vertical = Control.SIZE_FILL
			row.add_child(nm)
			var cost := Style.lbl(str(o.cost), 16, Style.GOLD if o.ok else Color(Style.GOLD, 0.45), Style.semi)
			cost.size_flags_vertical = Control.SIZE_FILL
			cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(cost)
			b.add_child(row)
			grid.add_child(b)
		actions.add_child(grid)
		actions.add_child(_act("✖ Đóng", gs.cancel))
	if gs.ui.hint != null:
		var hint: String = gs.ui.hint
		info.add_child(Style.rich(hint, 14, Style.GOLD, Style.GOLD_HI))
	pop.visible = info.get_child_count() + actions.get_child_count() > 0
	var na := actions.get_child_count()
	var all_btn := actions.get_children().all(
		func(c: Node) -> bool:
			return c is Button,
	)
	actions.columns = (2 if na == 4 else mini(na, 3)) if all_btn and na > 0 else 1
	for c: Node in actions.get_children():
		(c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bare := all_btn and info.get_child_count() == 0 # buttons only: no panel behind them
	pop.add_theme_stylebox_override("panel", StyleBoxEmpty.new() if bare else _pop_box)
	(info.get_parent() as Control).custom_minimum_size.x = POP_W if info.get_child_count() > 0 or actions.get_child_count() > 3 else 0.0
	if pop.visible:
		place_pop.call_deferred()

## put the popup beside its tile: right / left / below / above, whichever hides the fewest units (enemies count
## triple) and never the tile itself or the aimed target. No anchor (a lone hint) -> top centre of the board.
func place_pop() -> void:
	if pop == null or not pop.visible or _pop_pending:
		return
	_pop_pending = true
	# wrapped text only knows its height after one layout pass at the final width: shrink, wait a frame, measure
	pop.size = Vector2.ZERO
	var moved: bool = _pop_anchor != _pop_placed_at
	if moved:
		pop.modulate.a = 0.0 # hidden while measuring, so it never flashes at the old spot
	await gs.get_tree().process_frame
	_pop_pending = false
	pop.modulate.a = 1.0
	_pop_placed_at = _pop_anchor
	if not pop.visible:
		return
	pop.size = Vector2.ZERO
	var sz := pop.get_combined_minimum_size()
	pop.size = sz
	var lim := gs.hud.map_wrap.size
	if _pop_anchor == null:
		pop.position = Vector2(((lim.x - sz.x) / 2.0), gs.board.position.y + 10).floor()
		return
	var anc_x: int = _pop_anchor[0]
	var anc_y: int = _pop_anchor[1]
	var tile_r: Rect2 = gs.board.tile_rect(anc_x, anc_y)
	var tile := tile_r.position
	var tw := tile_r.size
	var keep: Array[Rect2] = [
		tile_r,
		Rect2(gs.hud.card.position, gs.hud.card.size) if gs.hud.card.visible else Rect2(gs.hud.btn_end.position, gs.hud.btn_end.size),
	]
	if gs.ui.mode == gs.M_TARGET and gs.ui.target != null:
		var target_id: int = gs.ui.target
		var tg: Variant = Game.unit_by_id(gs.s, target_id)
		if tg != null:
			var tg_x: int = tg.x
			var tg_y: int = tg.y
			var tg_r: Rect2 = gs.board.tile_rect(tg_x, tg_y)
			keep.append(tg_r)
	var gap := 10.0
	var cands: Array[Vector2] = [
		tile + Vector2(tw.x + gap, (tw.y - sz.y) / 2),
		tile + Vector2(-sz.x - gap, (tw.y - sz.y) / 2),
		tile + Vector2((tw.x - sz.x) / 2, tw.y + gap),
		tile + Vector2((tw.x - sz.x) / 2, -sz.y - gap),
	]
	var best := cands[0]
	var best_cost := INF
	for k in cands.size():
		var p := cands[k]
		p.x = clampf(p.x, 6, maxf(6.0, lim.x - sz.x - 6))
		p.y = clampf(p.y, 6, maxf(6.0, lim.y - sz.y - 6))
		var r := Rect2(p, sz)
		var cost := float(k) * 0.1
		for kr: Rect2 in keep:
			if r.intersects(kr.grow(-2)):
				cost += 100.0
		for o: Dictionary in gs.s.units:
			if o.id == gs.ui.sel:
				continue
			var o_x: int = o.x
			var o_y: int = o.y
			var orr: Rect2 = gs.board.tile_rect(o_x, o_y)
			if r.intersects(orr.grow(-orr.size.x * 0.2)):
				cost += 3.0 if o.side != gs._me() else 1.0
		if cost < best_cost:
			best_cost = cost
			best = p
	pop.position = best.floor()

func _preview_box(p: Dictionary) -> Control:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 6)
	var dmg_lo: int = p.dmgMin
	var dmg_hi: int = p.dmgMax
	var ctr_lo: int = p.counterMin
	var ctr_hi: int = p.counterMax
	for cell: Array in [
		["Gây", Style.range_txt(dmg_lo, dmg_hi), " hạ gục" if p.kill else (" có thể hạ" if p.mayKill else ""), Style.GOOD],
		["Bị đánh trả", Style.range_txt(ctr_lo, ctr_hi), " ngã" if p.die else (" có thể ngã" if p.mayDie else ""), Style.BAD],
	]:
		var pc := Style.card(Color(0, 0, 0, 0.4), Style.LACQUER_3, 8, 6)
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := Style.vbox(0)
		var cell_title: String = cell[0]
		var cell_note: String = cell[2]
		var cell_col: Color = cell[3]
		v.add_child(Style.lbl(cell_title, 12, Style.MUTED))
		var h := Style.hbox(4)
		h.add_child(Style.lbl(str(cell[1]), 20, cell_col, Style.xbold))
		if cell[2] != "":
			var l := Style.lbl(cell_note, 13, Style.INK)
			l.size_flags_vertical = Control.SIZE_SHRINK_END
			h.add_child(l)
		v.add_child(h)
		pc.add_child(v)
		g.add_child(pc)
	return g
