class_name GameScreen
extends Control
## the war table: top bar (with Hết lượt), tips strip, board + one popup pinned beside the selection; input, event playback, enemy turn loop, hint, end screen.
## Port of the game half of src/ui/screens.js.

const DEFAULT_TIPS := [
	"Bấm lính để xem ô đi được. Bấm kẻ địch viền đỏ để xem trước rồi [b]Đánh[/b].",
	"Bấm [b]thành[/b] của ta khi ô trống để mua lính. Làng, thành cho vàng mỗi lượt.",
	"Mở [b]Sách lính[/b] để xem tính chất từng loại quân.",
]

## selection modes: idle = nothing / choosing where to go; moved = destination picked; target = enemy aimed
const M_IDLE := "idle"
const M_MOVED := "moved"
const M_TARGET := "target"

var main: Main
var s: Dictionary = {}
var ctx: Dictionary = {}
var def: Dictionary = {}
## bumps on start / leave so stale async turn loops stop
var gen := 0
var ui := {}
var stats := { "kills": 0, "losses": 0 }
var fx: FX
var board: Board
var battle: BattleView

var _turn: Label
var _gold_box: Control
var _gold_num: Label
var _income: Label
var _goal: RichTextLabel
var _btn_hint: Button
var _btn_speed: Button
var _btn_sound: Button
var _btn_battle: Button
var _coach: PanelContainer
var _coach_n: Label
var _coach_text: RichTextLabel
var _coach_next: Button
var _wrap: Control
var _frame: Panel
var _banner: Banner
var _info: VBoxContainer
var _actions: HFlowContainer
var _btn_end: Button
var _end_pulse: Tween = null
var _end: Control
var _pop: PanelContainer
var _pop_anchor: Variant = null # [x, y] tile the popup belongs to; null = top centre of the board
var _hover_at := 0
const POP_W := 290.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	fx = FX.new()
	fx.audio = main.audio
	add_child(fx)
	FX.speed = float(Store.get_v("speed", 1.0)) if not main.flags.has("speed") else FX.speed
	_reset_ui()
	_build()
	var bl := CanvasLayer.new() # above the top bar and the Hết lượt button
	bl.layer = 20
	add_child(bl)
	battle = BattleView.new()
	battle.main = main
	bl.add_child(battle)

func _reset_ui() -> void:
	ui = { "sel": null, "dest": null, "mode": M_IDLE, "target": null, "info": null, "buyAt": null, "busy": false, "hint": null,
		"hotBuy": null, "hover": ui.get("hover"), "tip": ui.get("tip", 0), "hintKind": null, "peek": null }

# ---------- layout ----------
func _build() -> void:
	var bg := BgPaint.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := Style.vbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	# top bar
	var bar := PanelContainer.new()
	var bs := Style.box(Color("#22130d"), Color.TRANSPARENT, 0, 0)
	bs.content_margin_left = 14; bs.content_margin_right = 14; bs.content_margin_top = 8; bs.content_margin_bottom = 8
	bs.border_color = Style.LACQUER_3; bs.border_width_bottom = 1
	bs.shadow_color = Color(0, 0, 0, 0.5); bs.shadow_size = 8
	bar.add_theme_stylebox_override("panel", bs)
	bar.z_index = 1
	root.add_child(bar)
	var bh := Style.hbox(12)
	bar.add_child(bh)
	_turn = Style.lbl("Lượt 1", 21, Style.GOLD, Style.display_x)
	bh.add_child(_turn)
	_gold_box = PanelContainer.new()
	var gs := Style.box(Color(0, 0, 0, 0.45), Style.LACQUER_3, 99, 0)
	gs.content_margin_left = 4; gs.content_margin_right = 12; gs.content_margin_top = 3; gs.content_margin_bottom = 3
	_gold_box.add_theme_stylebox_override("panel", gs)
	var gh := Style.hbox(6)
	gh.add_child(Coin.new())
	_gold_num = Style.lbl("0", 16, Style.GOLD, Style.bold)
	_gold_num.pivot_offset = Vector2(10, 10)
	gh.add_child(_gold_num)
	_income = Style.lbl("", 13, Style.GOOD, Style.semi)
	gh.add_child(_income)
	_gold_box.add_child(gh)
	bh.add_child(_gold_box)
	_goal = Style.rich("", 13, Style.MUTED)
	_goal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bh.add_child(_goal)
	_btn_hint = _ibtn("Gợi ý", "Gợi ý nước đi", _on_hint)
	bh.add_child(_btn_hint)
	bh.add_child(_ibtn("Sách lính", "Sách lính", func() -> void: main.menus.open_codex("p")))
	_btn_speed = _ibtn("x1", "Tốc độ hiệu ứng", _on_speed)
	bh.add_child(_btn_speed)
	_btn_battle = _ibtn("⚔", "Cảnh giao chiến khi đánh: bật / tắt (phím B). Tắt = đánh ngay trên bàn cờ.", _toggle_battle)
	bh.add_child(_btn_battle)
	_battle_label()
	_btn_sound = _ibtn("🔊", "Âm thanh", func() -> void:
		main.audio.set_muted(not main.audio.muted)
		_sound_label())
	bh.add_child(_btn_sound)
	bh.add_child(_ibtn("Menu", "Về menu", func() -> void:
		save()
		main.show_title()))
	# tips strip
	_coach = PanelContainer.new()
	var cs := Style.box(Color(0.94, 0.79, 0.42, 0.13), Color.TRANSPARENT, 0, 0)
	cs.content_margin_left = 14; cs.content_margin_right = 14; cs.content_margin_top = 7; cs.content_margin_bottom = 7
	cs.border_color = Color(0.94, 0.79, 0.42, 0.25); cs.border_width_bottom = 1
	_coach.add_theme_stylebox_override("panel", cs)
	var ch := Style.hbox(10)
	_coach_n = Style.lbl("", 15, Style.GOLD, Style.display_x)
	ch.add_child(_coach_n)
	_coach_text = Style.rich("", 14, Style.INK, Style.GOLD)
	_coach_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coach_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.add_child(_coach_text)
	_coach_next = Style.button("Tiếp ›", "LinkBtn")
	_coach_next.pressed.connect(func() -> void:
		main.audio.play("ui")
		ui.tip = (ui.tip + 1) % _tips().size()
		_render_tip())
	ch.add_child(_coach_next)
	var hide := Style.button("Ẩn", "LinkBtn")
	hide.add_theme_color_override("font_color", Style.MUTED)
	hide.pressed.connect(func() -> void:
		main.audio.play("ui")
		Store.hide_tips(s.scenario)
		_coach.visible = false)
	ch.add_child(hide)
	_coach.add_child(ch)
	root.add_child(_coach)
	# board + panel
	var body := Style.hbox(0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	_wrap = Control.new()
	_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wrap.clip_contents = true
	_wrap.resized.connect(_fit)
	body.add_child(_wrap)
	_frame = Panel.new()
	var fs := Style.box(Color.TRANSPARENT, Style.BRONZE_2, 8, 0, 2)
	fs.shadow_color = Color(0, 0, 0, 0.7); fs.shadow_size = 24; fs.shadow_offset = Vector2(0, 12)
	fs.expand_margin_left = 2; fs.expand_margin_right = 2; fs.expand_margin_top = 2; fs.expand_margin_bottom = 2
	_frame.add_theme_stylebox_override("panel", fs)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wrap.add_child(_frame)
	board = Board.new()
	board.fx = fx
	board.tile_clicked.connect(_on_tile_clicked)
	board.hover_changed.connect(func(t: Variant) -> void:
		ui.hover = t
		_hover_at = Time.get_ticks_msec()
		_build_view())
	board.cancel_requested.connect(cancel)
	board.info_requested.connect(_on_info_requested)
	_wrap.add_child(board)
	_banner = Banner.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wrap.add_child(_banner)
	_btn_end = Style.menu_button("Hết lượt", "Còn 0 quân chưa đi", true)
	(_btn_end.get_meta("title") as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(_btn_end.get_meta("sub") as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_btn_end.custom_minimum_size.x = 210
	_btn_end.tooltip_text = "Kết thúc lượt (phím E)"
	_btn_end.z_index = 40 # over the board, under the orders popup
	_btn_end.pressed.connect(func() -> void:
		main.audio.play("ui")
		end_player_turn())
	_wrap.add_child(_btn_end)
	# no side panel: everything about the current selection lives in one popup pinned next to its tile
	_pop = PanelContainer.new()
	var ps := Style.box(Color(0.075, 0.045, 0.03, 0.96), Style.BRONZE_2, 12, 12)
	ps.shadow_color = Color(0, 0, 0, 0.55); ps.shadow_size = 14; ps.shadow_offset = Vector2(0, 6)
	_pop.add_theme_stylebox_override("panel", ps)
	_pop.z_index = 50 # above board tokens / FX
	_pop.visible = false
	_wrap.add_child(_pop)
	var pv := Style.vbox(8)
	pv.custom_minimum_size.x = POP_W
	_pop.add_child(pv)
	_info = Style.vbox(6)
	pv.add_child(_info)
	_actions = HFlowContainer.new()
	_actions.add_theme_constant_override("h_separation", 6)
	_actions.add_theme_constant_override("v_separation", 6)
	pv.add_child(_actions)
	_end = Control.new()
	_end.z_index = 60 # over the top bar (1), Hết lượt (40) and the popup (50)
	_end.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end.visible = false
	add_child(_end)

func _ibtn(text: String, tip: String, fn: Callable) -> Button:
	var b := Style.button(text, "IconBtn")
	b.tooltip_text = tip
	b.pressed.connect(func() -> void:
		main.audio.play("ui")
		fn.call())
	return b

func _speed_label() -> void:
	_btn_speed.text = "x%d" % int(FX.speed)

func _on_speed() -> void:
	FX.speed = 2.0 if FX.speed == 1.0 else (3.0 if FX.speed == 2.0 else 1.0)
	Store.set_v("speed", FX.speed)
	_speed_label()

func _toggle_battle() -> void:
	BattleView.set_enabled(not BattleView.enabled())
	_battle_label()

func _battle_label() -> void:
	var on := BattleView.enabled()
	_btn_battle.add_theme_color_override("font_color", Style.INK if on else Style.MUTED)
	_btn_battle.text = "⚔ Cảnh đánh" if on else "⚔ Tắt cảnh"

func _sound_label() -> void:
	_btn_sound.add_theme_color_override("font_color", Style.MUTED if main.audio.muted else Style.INK)
	_btn_sound.text = "🔇" if main.audio.muted else "🔊"

func _fit() -> void:
	if s.is_empty():
		return
	board.fit(_wrap.size - Vector2(16, 16))
	var eb := _btn_end.get_combined_minimum_size()
	if (_wrap.size.x - board.size.x) / 2.0 < eb.x + 24: # no side margin for Hết lượt -> keep a strip under the board
		board.fit(_wrap.size - Vector2(16, 16 + eb.y + 10))
	board.position = ((_wrap.size - board.size) / 2.0).floor()
	if (_wrap.size.x - board.size.x) / 2.0 < eb.x + 24:
		board.position.y = floorf((_wrap.size.y - board.size.y - eb.y - 10) / 2.0)
	_frame.position = board.position
	_frame.size = board.size
	_place_end()
	_place_pop.call_deferred()

## Hết lượt lives on the table: right of the board's bottom corner when there is room, else just under it
func _place_end() -> void:
	var eb := _btn_end.get_combined_minimum_size()
	_btn_end.size = eb
	var br := board.position + board.size
	if (_wrap.size.x - board.size.x) / 2.0 >= eb.x + 24:
		_btn_end.position = Vector2(br.x + 14, br.y - eb.y)
	else:
		_btn_end.position = Vector2(br.x - eb.x, br.y + 10)

func _refresh_end_button(my_turn: bool) -> void:
	var left: int = s.units.filter(func(o: Dictionary) -> bool: return o.side == "p" and not o.acted).size()
	var enemy_busy: bool = ui.busy and s.side == "e"
	_btn_end.disabled = not my_turn
	(_btn_end.get_meta("title") as Label).text = "Lượt địch" if enemy_busy else "Hết lượt"
	var sub := ("%s đang ra quân…" % Content.theme().factions.e.short) if enemy_busy else (
		("Còn %d quân chưa đi" % left) if left > 0 else "Mọi quân đã ra lệnh")
	Style.set_sub(_btn_end, sub if (my_turn or enemy_busy) else "")
	# everyone has moved: the button breathes so the next step is obvious
	var hot := my_turn and left == 0
	if hot and _end_pulse == null:
		_end_pulse = _btn_end.create_tween().set_loops()
		_end_pulse.tween_property(_btn_end, "modulate", Color(1.22, 1.12, 0.95), 0.6)
		_end_pulse.tween_property(_btn_end, "modulate", Color.WHITE, 0.6)
	elif not hot and _end_pulse != null:
		_end_pulse.kill()
		_end_pulse = null
		_btn_end.modulate = Color.WHITE
	_place_end()

# ---------- lifecycle ----------
func _def_for(c: Dictionary) -> Dictionary:
	if c.kind == "campaign":
		return Content.mission(c.id)
	return Content.skirmish_def(c.get("map", "dong_bang"), c.hero, c.easy)

func start(state: Dictionary, c: Dictionary) -> void:
	gen += 1
	s = state
	ctx = c
	def = _def_for(c)
	Content.use_chapter(Content.chapter_of(def)) # enemy skin + wording of this chapter
	_reset_ui()
	stats = { "kills": 0, "losses": 0 }
	board.view.hide.clear()
	board.view.sprites = []
	board.view.hp = null
	fx.clear()
	board.set_state(s)
	_end.visible = false
	visible = true
	_speed_label()
	_sound_label()
	_battle_label()
	_tips_init()
	_fit.call_deferred()
	board.refresh_terrain()
	save()
	refresh()
	banner(_turn_banner() if s.side == "p" else Content.text("enemyTurn"), s.side != "p")
	if s.side == "p":
		_intro_new_units.call_deferred() # on a resumed enemy turn, play() introduces new units itself
	if s.side == "e":
		enemy_turn()
	else:
		_maybe_bot()

func _turn_banner() -> String:
	return Content.text("turnBanner").format({ "turn": s.turn })

func leave() -> void:
	gen += 1
	battle.skip()
	if _intro_layer != null:
		_intro_closed.emit()
	visible = false
	_end.visible = false
	fx.clear()

func save() -> void:
	if s.is_empty() or s.winner != null:
		return
	Store.save_game(s, ctx, def.get("title", ""))

# ---------- tips ----------
func _tips() -> Array:
	return def.get("tips", DEFAULT_TIPS)

func _tips_init() -> void:
	ui.tip = 0
	_coach.visible = not Store.tips_hidden(s.scenario)
	_render_tip()

func _render_tip() -> void:
	var list := _tips()
	_coach_n.text = "Mẹo %d/%d" % [ui.tip + 1, list.size()]
	_coach_text.text = Style.bold_in(list[ui.tip], Style.GOLD)
	_coach_next.text = "Tiếp ›" if ui.tip + 1 < list.size() else "Từ đầu"

# ---------- view ----------
func _sel_unit() -> Variant:
	return Game.unit_by_id(s, ui.sel) if ui.sel != null else null

func _name_of(u: Dictionary) -> String:
	return Content.unit_look(s, u).name

# reach / best attack tile, memoised per board position: hovering re-asks them every mouse move
var _memo := {}
var _memo_fp := 0

func _fingerprint() -> int:
	var h: int = s.turn * 31 + (1 if s.side == "p" else 2)
	for o: Dictionary in s.units:
		h = hash([h, o.id, o.x, o.y, o.acted, o.hp])
	return h

func _memo_get(key: String, fn: Callable) -> Variant:
	var fp := _fingerprint()
	if fp != _memo_fp:
		_memo.clear()
		_memo_fp = fp
	if not _memo.has(key):
		_memo[key] = fn.call()
	return _memo[key]

func _reach(u: Dictionary) -> Dictionary:
	return _memo_get("r%d" % u.id, func() -> Dictionary: return Game.reachable(s, u))

func _build_view() -> void:
	if s.is_empty():
		return
	var v := board.view
	var u: Variant = _sel_unit()
	var my_turn: bool = s.side == "p" and not ui.busy and s.winner == null
	v.busy = ui.busy
	v.sel = u if u != null and not ui.busy else null
	v.selMine = u != null and my_turn and u.side == "p" and not u.acted
	v.reach = _reach(u) if u != null and not ui.busy and ui.mode == M_IDLE else null
	v.attackable = _attackable_anywhere(u, v.reach) if v.selMine and ui.mode == M_IDLE else []
	v.dest = ui.dest if u != null and not ui.busy and ui.mode != M_IDLE else null
	v.targets = Game.targets_from(s, u, ui.dest[0], ui.dest[1]) if ui.mode == M_TARGET and u != null else []
	v.target = ui.target
	v.path = null
	v.preview = null
	var plan: Variant = _hover_attack() if v.selMine else null
	if plan != null:
		# hovering an enemy we can hit: path to the attack tile + damage preview on the board
		var p := Game.preview(s, u, plan.from[0], plan.from[1], plan.target)
		v.preview = { "x": plan.target.x, "y": plan.target.y, "dmg": p.dmg, "counter": p.counter, "kill": p.kill, "die": p.die }
		v.path = Game.path_for(s, u, plan.from[0], plan.from[1])
		if ui.mode == M_IDLE:
			v.dest = plan.from
	elif v.selMine and ui.mode == M_IDLE and ui.hover != null and v.reach.has(ui.hover):
		v.path = Game.path_for(s, u, ui.hover.x, ui.hover.y)
	elif v.selMine and ui.mode != M_IDLE and ui.dest != null:
		var r := _reach(u)
		if r.has(Vector2i(ui.dest[0], ui.dest[1])):
			v.path = Game.path_for(s, u, ui.dest[0], ui.dest[1])
	v.info = ui.info
	v.buyAt = ui.buyAt
	v.hover = ui.hover

## the attack the selected unit would make on the hovered enemy: {target, from} or null
func _hover_attack() -> Variant:
	if ui.hover == null:
		return null
	var e: Variant = Game.unit_at(s, ui.hover.x, ui.hover.y)
	if e == null or e.side != "e":
		return null
	var from: Variant = _attack_from(_sel_unit(), e)
	return { "target": e, "from": from } if from != null else null

## where the selected unit attacks `e` from: the chosen tile if e is in range from it, else the best reachable tile
func _attack_from(u: Dictionary, e: Dictionary) -> Variant:
	if ui.mode != M_IDLE and ui.dest != null:
		if Game.targets_from(s, u, ui.dest[0], ui.dest[1]).any(func(o: Dictionary) -> bool: return o.id == e.id):
			return ui.dest
	return _best_attack_tile(u, e)

func _attackable_anywhere(u: Dictionary, reach: Dictionary) -> Array:
	var seen := {}
	var out := []
	for r: Dictionary in reach.values():
		for e: Dictionary in Game.targets_from(s, u, r.x, r.y):
			if not seen.has(e.id):
				seen[e.id] = true
				out.append(e)
	return out

func _best_attack_tile(u: Dictionary, target: Dictionary) -> Variant:
	return _memo_get("b%d_%d" % [u.id, target.id], func() -> Variant: return _best_attack_tile_now(u, target))

func _best_attack_tile_now(u: Dictionary, target: Dictionary) -> Variant:
	var best: Variant = null
	for r: Dictionary in _reach(u).values():
		if not Game.targets_from(s, u, r.x, r.y).any(func(o: Dictionary) -> bool: return o.id == target.id):
			continue
		var p := Game.preview(s, u, r.x, r.y, target)
		var sc: float = _attack_score(p) + Game.terrain_def(s, u, r.x, r.y) * 0.3 - r.cost * 0.1
		if best == null or sc > best.sc:
			best = { "sc": sc, "x": r.x, "y": r.y }
	return [best.x, best.y] if best != null else null

## one yardstick for "which attack is best" (hover tile choice and the ⚔ Đánh button): a kill beats any trade
func _attack_score(p: Dictionary) -> float:
	return p.dmg - p.counter * 1.1 + (50.0 if p.kill else 0.0) - (50.0 if p.die else 0.0)

# ---------- input ----------
func _on_tile_clicked(x: int, y: int) -> void:
	if s.is_empty() or ui.busy or s.winner != null:
		return
	if ui.peek != null: # first click anywhere just closes the unit card
		ui.peek = null
		refresh()
		return
	_on_tile(x, y)

## ⓘ on a token: show that unit's card (stats, live buffs, traits, how to play) without touching the selection
func _on_info_requested(id: int) -> void:
	if s.is_empty() or ui.busy or s.winner != null:
		return
	main.audio.play("ui")
	ui.peek = null if ui.peek == id else id
	refresh()

func cancel() -> void:
	if ui.busy or s.is_empty():
		return
	if ui.peek != null:
		ui.peek = null
	elif ui.mode == M_TARGET:
		ui.mode = M_MOVED
		ui.target = null
	else:
		_clear_sel()
	refresh()

func _on_tile(x: int, y: int) -> void:
	var my_turn: bool = s.side == "p"
	var clicked: Variant = Game.unit_at(s, x, y)
	var u: Variant = _sel_unit()
	ui.hint = null; ui.hotBuy = null; ui.hintKind = null
	if u != null and my_turn and not u.acted and u.side == "p":
		if clicked != null and clicked.side == "e":
			var from: Variant = _attack_from(u, clicked)
			if from != null:
				# mouse: the preview was already on the board while hovering -> one click attacks.
				# touch (no settled hover): first tap aims and previews, second tap attacks.
				var aimed: bool = ui.mode == M_TARGET and ui.target == clicked.id and ui.dest == from
				if aimed or _hover_settled(x, y):
					ui.dest = from
					commit({ "kind": "attack", "target": clicked.id })
					return
				ui.dest = from; ui.mode = M_TARGET; ui.target = clicked.id; ui.buyAt = null; ui.info = null
				main.audio.play("select")
				refresh()
				return
		# clicking the chosen tile again = default action (capture if possible, else wait)
		if ui.mode != M_IDLE and ui.dest != null and ui.dest[0] == x and ui.dest[1] == y:
			default_action()
			return
		# its own tile: no "move in place". Open orders only when there is real work right here (capture / raise);
		# otherwise the click just puts the unit down. (Attacks from here: click the enemy.)
		if clicked != null and clicked.id == u.id:
			if _in_place_work(u):
				_set_dest(x, y)
			else:
				_clear_sel()
				refresh()
			return
		var reach := _reach(u)
		if reach.has(Vector2i(x, y)) and clicked == null:
			_set_dest(x, y)
			return
	_clear_sel()
	if clicked != null:
		ui.sel = clicked.id
		main.audio.play("select")
		refresh()
		return
	ui.sel = null
	if my_turn and Game.buy_options(s, "p", x, y).size():
		ui.buyAt = [x, y]
		main.audio.play("select")
		refresh()
		return
	ui.info = { "x": x, "y": y }
	refresh()

## something worth doing without moving: capture the tile it stands on, or raise a grave next to it
func _in_place_work(u: Dictionary) -> bool:
	return Game.can_capture(s, u, u.x, u.y) or Game.raisable_graves(s, u, u.x, u.y).size() > 0

## true when the mouse has rested on (x,y) long enough that the board preview was visible
func _hover_settled(x: int, y: int) -> bool:
	return ui.hover != null and ui.hover == Vector2i(x, y) and Time.get_ticks_msec() - _hover_at >= 150

## Space / Enter / clicking the chosen tile again: attack the aimed target, else capture, else wait
func default_action() -> void:
	var u: Variant = _sel_unit()
	if ui.busy or u == null or u.side != "p" or u.acted or s.side != "p" or s.winner != null:
		return
	if ui.mode == M_IDLE:
		if not _in_place_work(u): # no "wait in place" from the keyboard either
			return
		ui.dest = [u.x, u.y]
		ui.mode = M_MOVED
	if ui.mode == M_TARGET and ui.target != null:
		commit({ "kind": "attack", "target": ui.target })
	elif Game.can_capture(s, u, ui.dest[0], ui.dest[1]):
		commit({ "kind": "capture" })
	elif ui.dest[0] == u.x and ui.dest[1] == u.y and Game.raisable_graves(s, u, u.x, u.y).size():
		var g0: Dictionary = Game.raisable_graves(s, u, u.x, u.y)[0]
		commit({ "kind": "raise", "target": [g0.x, g0.y] })
	else:
		commit({ "kind": "wait" })

## Tab: select the next unit of ours that hasn't acted
func select_next() -> void:
	if ui.busy or s.side != "p" or s.winner != null:
		return
	var mine: Array = s.units.filter(func(o: Dictionary) -> bool: return o.side == "p" and not o.acted)
	if mine.is_empty():
		return
	var i := 0
	for k in mine.size():
		if ui.sel != null and mine[k].id == ui.sel:
			i = (k + 1) % mine.size()
	_reset_ui()
	ui.sel = mine[i].id
	main.audio.play("select")
	refresh()

func _unhandled_input(ev: InputEvent) -> void:
	if _intro_on:
		if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			_intro_closed.emit()
			get_viewport().set_input_as_handled()
		return
	if not visible or s.is_empty() or _end.visible or main.menus.is_codex_open():
		return
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	match ev.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			default_action()
		KEY_TAB:
			select_next()
		KEY_E:
			end_player_turn()
		KEY_H:
			_on_hint()
		KEY_B:
			_toggle_battle()
		_:
			return
	get_viewport().set_input_as_handled()

## drop the selection and everything hanging off it (destination, aim, buy / info popups, hint, unit card)
func _clear_sel() -> void:
	ui.sel = null; ui.dest = null; ui.mode = M_IDLE; ui.target = null; ui.buyAt = null; ui.info = null
	ui.hint = null; ui.hotBuy = null; ui.hintKind = null; ui.peek = null

func _set_dest(x: int, y: int) -> void:
	ui.dest = [x, y]; ui.mode = M_MOVED; ui.target = null; ui.buyAt = null; ui.info = null
	main.audio.play("select")
	refresh()

func commit(extra: Dictionary) -> void:
	var my := gen
	var u: Dictionary = _sel_unit()
	var act := { "id": u.id, "to": ui.dest }
	act.merge(extra, true)
	_clear_sel()
	ui.busy = true
	refresh()
	var before := _snapshot()
	var ev := Game.do_action(s, act)
	save()
	await play(ev, before)
	if gen != my:
		return
	ui.busy = false
	refresh()
	if s.winner != null:
		finish()

func buy_unit(type: String) -> void:
	var x: int = ui.buyAt[0]
	var y: int = ui.buyAt[1]
	if Game.buy(s, x, y, type) == null:
		return
	fx.buy_fx(x, y)
	_bump_gold()
	ui.buyAt = null
	ui.hotBuy = null
	save()
	refresh()
	_intro_new_units()

func end_player_turn() -> void:
	if ui.busy or s.side != "p" or s.winner != null:
		return
	var my := gen
	_clear_sel()
	var before := _snapshot()
	var ev := Game.end_turn(s)
	save()
	if s.winner != null:
		finish()
		return
	ui.busy = true
	refresh()
	banner(Content.text("enemyTurn"), true)
	await play(ev, before)
	if gen != my:
		return
	await enemy_turn()

func enemy_turn() -> void:
	var my := gen
	ui.busy = true
	refresh()
	await fx.sleep(900.0)
	if gen != my:
		return
	var mem := {}
	while s.winner == null and s.side == "e":
		var step: Variant = AI.next_step(s, mem)
		if step == null:
			break
		var before := _snapshot()
		var ev := AI.apply_step(s, step)
		save()
		if not (step.kind == "act" and step.act.kind == "wait" and ev.is_empty()):
			await play(ev, before)
		await fx.sleep(90.0)
		if gen != my:
			return
	if s.winner != null:
		ui.busy = false
		finish()
		return
	var before := _snapshot()
	var ev := Game.end_turn(s)
	save()
	if s.winner != null:
		ui.busy = false
		finish()
		return
	banner(_turn_banner())
	refresh()
	await play(ev, before) # income, heal, reinforcements: input stays closed until they finish
	if gen != my:
		return
	ui.busy = false
	refresh()
	_maybe_bot()

## debug flag `bot`: the AI plays our side too (screenshots / soak test)
func _maybe_bot() -> void:
	if main.flags.has("bot") and s.side == "p" and s.winner == null:
		_bot_turn.call_deferred()

func _bot_turn() -> void:
	var my := gen
	await fx.sleep(400.0)
	var mem := {}
	while gen == my and s.side == "p" and s.winner == null:
		var step: Variant = AI.next_step(s, mem)
		if step == null:
			break
		if step.kind == "buy":
			ui.buyAt = [step.x, step.y]
			buy_unit(step.type)
			continue
		ui.sel = step.act.id
		ui.dest = step.act.to
		var rest: Dictionary = step.act.duplicate()
		rest.erase("id")
		rest.erase("to")
		await commit(rest)
	if gen == my and s.winner == null:
		await end_player_turn()

func _bump_gold() -> void:
	var tw := _gold_num.create_tween()
	tw.tween_property(_gold_num, "scale", Vector2(1.25, 1.25), 0.15)
	tw.parallel().tween_property(_gold_num, "modulate", Color(1.2, 1.15, 1.0), 0.15)
	tw.tween_property(_gold_num, "scale", Vector2.ONE, 0.35)
	tw.parallel().tween_property(_gold_num, "modulate", Color.WHITE, 0.35)

func banner(text: String, foe := false) -> void:
	_banner.show_text(text, foe)
	main.audio.play("drum")

# ---------- event playback ----------
func _snapshot() -> Dictionary:
	var m := {}
	for u: Dictionary in s.units:
		m[u.id] = u.duplicate()
	return m

func play(events: Array, before: Dictionary) -> void:
	var my := gen
	var v := board.view
	var hp := {}
	for id: int in before:
		hp[id] = before[id].hp
	v.hp = hp
	var dying := {}
	for e: Dictionary in events:
		if e.t == "die" and before.has(e.id):
			var copy: Dictionary = before[e.id].duplicate()
			copy.x = e.x
			copy.y = e.y
			var sp := { "u": copy, "hidden": false }
			dying[e.id] = sp
			v.sprites.append(sp)
		if e.t == "raise" or e.t == "spawn":
			v.hide[e.id] = true
	var done_ev := {}
	for ei in events.size():
		var e: Dictionary = events[ei]
		if gen != my:
			return
		if done_ev.has(ei):
			continue
		if e.t == "hit" and not e.get("counter", false) and _battle_on():
			await _duel(events, ei, before, hp, done_ev)
			continue
		match e.t:
			"move":
				var ds: Variant = dying.get(e.id)
				var src: Variant = ds.u if ds != null else before.get(e.id, Game.unit_by_id(s, e.id))
				var copy: Dictionary = src.duplicate()
				if ds != null:
					ds.hidden = true
				v.hide[e.id] = true
				var sp := { "u": copy }
				v.sprites.append(sp)
				main.audio.play("move")
				for i in range(1, e.path.size()):
					var a: Array = e.path[i - 1]
					var b: Array = e.path[i]
					await fx.tween(95.0, func(t: float) -> void:
						copy.x = a[0] + (b[0] - a[0]) * t
						copy.y = a[1] + (b[1] - a[1]) * t)
					fx.dust(b[0], b[1])
				if gen != my:
					return
				v.sprites.erase(sp)
				v.hide.erase(e.id)
				if ds != null:
					var last: Array = e.path[e.path.size() - 1]
					ds.u.x = last[0]
					ds.u.y = last[1]
					ds.hidden = false
			"hit":
				var kill := events.any(func(o: Dictionary) -> bool: return o.t == "die" and o.id == e.id)
				await fx.attack({ "x": e.fx, "y": e.fy, "id": e.from, "type": e.type, "side": e.side }, { "x": e.x, "y": e.y, "id": e.id }, e.amount,
					{ "counter": e.get("counter", false), "kill": kill })
				hp[e.id] = hp.get(e.id, 100) - e.amount
			"die":
				var sp: Variant = dying.get(e.id)
				if sp != null:
					v.sprites.erase(sp)
					fx.death(sp.u)
				if e.side == "e":
					stats.kills += 1
				else:
					stats.losses += 1
				await fx.sleep(380.0)
			"capture":
				fx.capture(e.x, e.y, e.side)
				fx.float_text(e.x, e.y - 0.3, Content.text("captureCastle") if e.tile == "c" else Content.text("captureVillage"), "#ffe08a", 1300.0, e.tile == "c")
				await fx.sleep(700.0 if e.tile == "c" else 450.0)
			"rank":
				var u: Variant = Game.unit_by_id(s, e.id)
				if u != null:
					fx.rank(u.x, u.y)
					await fx.sleep(350.0)
			"raise":
				fx.raise_fx(e.x, e.y)
				await fx.sleep(450.0)
				v.hide.erase(e.id)
				await fx.sleep(250.0)
			"spawn":
				v.hide.erase(e.id)
				fx.spawn_fx(e.x, e.y)
				await fx.sleep(220.0)
			"buy":
				fx.buy_fx(e.x, e.y)
				await fx.sleep(250.0)
			"heal":
				fx.heal(e.x, e.y, e.amount)
				main.audio.play("heal")
			"income":
				if e.side == "p" and e.amount:
					_bump_gold()
	v.hp = null
	v.sprites = v.sprites.filter(func(sp: Dictionary) -> bool: return not dying.has(sp.u.id))
	if gen == my:
		await _intro_new_units() # reinforcements / raised units of a kind never met before

## cut-away duel for the attack at events[i] (+ its counter); marks both hits handled and applies their damage to the shown hp
func _battle_on() -> bool:
	return BattleView.enabled() and not main.flags.has("nobattle") and (not main.flags.has("bot") or main.flags.has("battle"))

func _duel(events: Array, i: int, before: Dictionary, hp: Dictionary, done_ev: Dictionary) -> void:
	var e: Dictionary = events[i]
	var counter: Variant = null
	for j in range(i + 1, events.size()):
		var o: Dictionary = events[j]
		if o.t == "hit":
			if o.get("counter", false) and o.from == e.id and o.id == e.from:
				counter = o
				done_ev[j] = true
			break
	var dies := {}
	for o: Dictionary in events:
		if o.t == "die":
			dies[o.id] = true
	var au: Dictionary = before.get(e.from, Game.unit_by_id(s, e.from)).duplicate()
	var du: Dictionary = before.get(e.id, Game.unit_by_id(s, e.id)).duplicate()
	au.x = e.fx; au.y = e.fy
	var side_unit := func(u: Dictionary) -> Dictionary:
		var t: String = Game.tile_at(s, u.x, u.y)
		return { "side": u.side, "type": u.type, "hero": s.heroKey[u.side] if u.type == "hero" else null, "hp0": float(hp.get(u.id, u.hp)),
			"tile": t, "owner": s.owner.get(Vector2i(u.x, u.y)), "rank": u.get("rank", 0), "def": Game.terrain_def(s, u, u.x, u.y) }
	var shot_of := func(u: Dictionary, d: Dictionary) -> String:
		var dd: int = absi(u.x - d.x) + absi(u.y - d.y)
		return Rules.UNITS.get(u.type, {}).get("shot", "") if dd > 1 else ""
	var d := { "night": s.get("night", false), "att": e.side, "counter": null,
		"first": { "amount": e.amount, "kill": dies.has(e.id), "shot": shot_of.call(au, du) } }
	d[au.side] = side_unit.call(au)
	d[du.side] = side_unit.call(du)
	if counter != null:
		d.counter = { "amount": counter.amount, "kill": dies.has(e.from), "shot": shot_of.call(du, au) }
	var my := gen
	await battle.run(d)
	if gen != my:
		return
	hp[e.id] = hp.get(e.id, 100) - e.amount
	if counter != null:
		hp[e.from] = hp.get(e.from, 100) - counter.amount
	fx.flash(e.id)
	board.queue_redraw()

# ---------- new unit intro ----------
signal _intro_closed
var _intro_on := false
var _intro_layer: Control = null

func _look_key(u: Dictionary) -> String:
	return ("hero:%s" % s.heroKey[u.side]) if u.type == "hero" else ("unit:%s" % u.type) # both sides share one roster

## the first time a kind of unit (or a hero) shows up on the board, stop and introduce it: role, traits, how to play.
## Remembered per player (Store "seen_units"). Off for bot / nointro runs, which also never write the seen list.
func _intro_new_units() -> void:
	if main.flags.has("bot") or main.flags.has("nointro") or _intro_on or s.is_empty() or not visible:
		return
	var seen: Array = Store.get_v("seen_units", [])
	var fresh := []
	var keys := []
	for side: String in ["p", "e"]:
		for hero_first: bool in [true, false]:
			for u: Dictionary in s.units:
				if u.side != side or (u.type == "hero") != hero_first:
					continue
				var k := _look_key(u)
				if seen.has(k) or keys.has(k):
					continue
				keys.append(k)
				fresh.append(u)
	if fresh.is_empty():
		return
	_intro_on = true
	var my := gen
	for i in fresh.size():
		await _intro_card(fresh[i], i, fresh.size())
		seen.append(keys[i])
		Store.set_v("seen_units", seen)
		if gen != my:
			break
	_intro_on = false

## one animated card; returns when the player dismisses it (button, Space/Enter, or a click outside after a moment)
func _intro_card(u: Dictionary, i: int, n: int) -> void:
	var hk: Variant = s.heroKey[u.side]
	var look := Content.unit_type_look(u.side, u.type, hk)
	var st := Content.type_stat(u.type, hk)
	var mine: bool = u.side == "p"
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 100
	add_child(layer)
	_intro_layer = layer
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var card := PanelContainer.new()
	var cs := Style.box(Color(0.10, 0.06, 0.04, 0.98), Color(Style.GOLD, 0.7), 16, 22, 2)
	cs.shadow_color = Color(0, 0, 0, 0.6); cs.shadow_size = 30; cs.shadow_offset = Vector2(0, 10)
	card.add_theme_stylebox_override("panel", cs)
	card.custom_minimum_size.x = 620
	center.add_child(card)
	var v := Style.vbox(12)
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
	var head := Style.hbox(18)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(120, 120)
	var glow := IntroGlow.new()
	glow.col = side_col
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(glow)
	var tok := Token.make(u.side, u.type, hk, 104)
	tok.position = Vector2(8, 8)
	tok.pivot_offset = Vector2(52, 52)
	tok.scale = Vector2(0.2, 0.2)
	holder.add_child(tok)
	head.add_child(holder)
	var tv := Style.vbox(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(Style.lbl(look.name, 32, Style.GOLD, Style.display_x))
	tv.add_child(Style.lbl(Content.role(u.type), 15, side_col, Style.semi))
	var desc: String = look.blurb if u.type == "hero" else look.desc
	tv.add_child(Style.lbl(desc, 14, Style.INK, null, true))
	head.add_child(tv)
	v.add_child(head)
	v.add_child(Style.stat_bars([["Công", st.atk, 75], ["Thủ", st.def, 30], ["Đi", st.mv, 7], ["Tầm", Style.stat_range(st)]]))
	var lines: Array = []
	for t: String in Content.traits(u.type, hk):
		var l := Style.rich("[color=#%s]•[/color] %s" % [Style.GOLD.to_html(false), t], 15, Style.INK, Style.GOLD)
		lines.append(l)
		v.add_child(l)
	var how := Style.rich("[b]Cách dùng:[/b] " + Content.how_to_play(u.type), 15, Style.GOLD, Style.GOLD_HI)
	lines.append(how)
	v.add_child(how)
	var br := Style.hbox(10)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(sp)
	br.add_child(Style.lbl("Space / Enter", 12, Style.MUTED))
	var ok := Style.button("Tiếp ›" if i < n - 1 else "Đã hiểu", "PrimaryBtn")
	ok.custom_minimum_size = Vector2(150, 48)
	ok.pressed.connect(func() -> void: _intro_closed.emit())
	br.add_child(ok)
	v.add_child(br)
	var t0 := Time.get_ticks_msec()
	layer.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and Time.get_ticks_msec() - t0 > 600:
			_intro_closed.emit())
	# animate: fade in, card rises, token pops, lines appear one by one
	main.audio.play("spawn" if not mine else "rank")
	layer.modulate.a = 0.0
	card.pivot_offset = Vector2(310, 200)
	card.scale = Vector2(0.94, 0.94)
	for l: Control in lines:
		l.modulate.a = 0.0
	var tw := layer.create_tween().set_parallel(true)
	tw.tween_property(layer, "modulate:a", 1.0, 0.22)
	tw.tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tok, "scale", Vector2.ONE, 0.5).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for k in lines.size():
		tw.tween_property(lines[k], "modulate:a", 1.0, 0.25).set_delay(0.35 + k * 0.12)
	await _intro_closed
	main.audio.play("ui")
	var out := layer.create_tween()
	out.tween_property(layer, "modulate:a", 0.0, 0.15)
	await out.finished
	layer.queue_free()
	_intro_layer = null

## soft pulsing halo behind the token on the intro card
class IntroGlow extends Control:
	var col := Color.WHITE
	func _process(_dt: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 400.0)
		Draw.glow(self, size / 2, size.x * (0.62 + 0.06 * k), Color(col, 0.35 + 0.2 * k))

# ---------- end ----------
func finish() -> void:
	Store.clear_game()
	var win: bool = s.winner == "p"
	if win and ctx.kind == "campaign":
		Store.mark_done(ctx.id) # before any await: leaving during the pause must not lose the win
	refresh()
	var my := gen
	var reason_text := Content.end_text(s.winner, str(s.reason), s.heroKey)
	await get_tree().create_timer(0.6).timeout
	if gen != my:
		return
	main.audio.play("win" if win else "lose")
	var buttons := []
	var outro: Array = def.get("story", {}).get("outro", []) if win else []
	if ctx.kind == "campaign":
		var i := Content.mission_index(ctx.id)
		var cid := Content.chapter_of(def)
		if win:
			var c := Content.campaign()
			var chapter_ms := Content.missions_of(cid)
			if chapter_ms.back().id == ctx.id:
				# last mission of a chapter: the chapter's closing lines follow the mission's
				outro = outro + Content.chapter(cid).get("outro", [])
				reason_text += " Hết chương: %s." % Content.chapter(cid).title
			if i + 1 < c.size():
				var next: Dictionary = c[i + 1]
				var new_chapter := Content.chapter_of(next) != cid
				buttons.append(["Chương tiếp ›" if new_chapter else "Màn tiếp ›", func() -> void: main.show_briefing(next), true])
			else:
				reason_text += " Toàn bộ chiến dịch đã hoàn thành!"
			buttons.append(["Bản đồ chiến dịch", func() -> void: main.show_campaign(cid), false])
		else:
			var c2 := ctx.duplicate()
			buttons.append(["Đánh lại", func() -> void: main.start_game(Game.new_game(Content.mission(c2.id)), c2), true])
			buttons.append(["Bản đồ chiến dịch", func() -> void: main.show_campaign(cid), false])
	else:
		buttons.append(["Ván mới", main.show_skirmish, true])
		buttons.append(["Menu", main.show_title, false])
	_show_end(win, reason_text, outro, buttons)
	if main.flags.has("shots"):
		get_tree().create_timer(1.5).timeout.connect(func() -> void: main.shot((main.flags.get("tag", "s")) + "_end"))

func _show_end(win: bool, text: String, outro: Array, buttons: Array) -> void:
	for c in _end.get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.008, 0.004, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end.add_child(center)
	var card := PanelContainer.new()
	var cs := Style.box(Color("#1f110b"), Style.GOLD if win else Style.SEA, 16, 26)
	cs.shadow_color = Color(0, 0, 0, 0.55); cs.shadow_size = 30
	card.add_theme_stylebox_override("panel", cs)
	card.custom_minimum_size.x = 500
	card.clip_contents = true
	center.add_child(card)
	if win:
		var rays := Rays.new()
		rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(rays)
	var v := Style.vbox(12)
	card.add_child(v)
	var title := Style.lbl(Content.text("victory") if win else Content.text("defeat"), 46, Style.GOLD if win else Style.SEA_HI, Style.display_x)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	if text != "":
		var t := Style.lbl(text, 16, Style.INK, null, true)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
	if outro.size():
		v.add_child(Style.dialogue(outro, 0.5, true))
	var st := Style.hbox(26)
	st.alignment = BoxContainer.ALIGNMENT_CENTER
	for pair: Array in [[s.turn, "lượt"], [stats.kills, "địch bị hạ"], [stats.losses, "quân ta ngã"]]:
		var col := Style.vbox(0)
		var n := Style.lbl(str(pair[0]), 24, Style.INK, Style.display_x)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
		col.add_child(Style.lbl(pair[1], 13, Style.MUTED))
		st.add_child(col)
	v.add_child(st)
	var row := Style.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for b: Array in buttons:
		var btn := Style.menu_button(b[0], "", b[2])
		(btn.get_meta("title") as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.custom_minimum_size.x = maxf(190.0, btn.custom_minimum_size.x)
		var fn: Callable = b[1]
		btn.pressed.connect(func() -> void:
			main.audio.play("ui")
			_end.visible = false
			fn.call())
		row.add_child(btn)
	v.add_child(row)
	_end.visible = true
	card.pivot_offset = Vector2(250, 200)
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw := card.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE, 0.5)
	tw.parallel().tween_property(card, "modulate:a", 1.0, 0.3)

# ---------- hint ----------
func _on_hint() -> void:
	if s.is_empty() or ui.busy or s.side != "p" or s.winner != null:
		return
	_reset_ui()
	var step: Variant = AI.next_step(s.duplicate(true), {}) # next_step may clear guard flags: ask on a copy
	if step == null:
		ui.hint = "Không còn việc gì đáng làm. Bấm [b]Hết lượt[/b]."
		refresh()
		return
	if step.kind == "buy":
		ui.buyAt = [step.x, step.y]
		ui.hotBuy = step.type
		ui.hint = "Gợi ý: mua [b]%s[/b]." % Content.unit_type_look("p", step.type, s.heroKey.p).name
		refresh()
		return
	var a: Dictionary = step.act
	var u: Dictionary = Game.unit_by_id(s, a.id)
	if a.kind == "wait" and a.to[0] == u.x and a.to[1] == u.y: # there is no "wait in place" any more
		ui.hint = "Gợi ý: [b]%s[/b] cứ đứng yên giữ chỗ. Ra lệnh cho quân khác hoặc bấm [b]Hết lượt[/b]." % _name_of(u)
		refresh()
		return
	ui.sel = u.id
	ui.dest = a.to
	if a.kind == "attack":
		ui.mode = M_TARGET
		ui.target = a.target
	else:
		ui.mode = M_MOVED
	var verb: String = Content.text("raiseVerb") if a.kind == "raise" else Content.text("hint_" + a.kind)
	ui.hint = "Gợi ý: [b]%s[/b] %s. Bấm nút sáng để làm theo." % [_name_of(u), verb]
	ui.hintKind = a.kind
	refresh()

# ---------- panel ----------
func _note(bb: String, color := Style.MUTED, size := 14) -> RichTextLabel:
	return Style.rich(bb, size, color, Style.INK)

func _head(token: Control, name: String, sub: String, side := "") -> HBoxContainer:
	var h := Style.hbox(10)
	if token:
		h.add_child(token)
	var v := Style.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := Style.P_NAME if side == "p" else (Style.SEA_HI if side == "e" else Style.GOLD)
	v.add_child(Style.lbl(name, 20, col, Style.display))
	if sub != "":
		v.add_child(Style.lbl(sub, 13, Style.MUTED, null, true))
	h.add_child(v)
	return h

func _act(label: String, fn: Callable, opts := {}) -> Button:
	var hot: bool = opts.get("hot", false)
	var go: bool = opts.get("go", false)
	var b := Style.button(label, ("ActGoHot" if hot else "ActGo") if go else ("ActHot" if hot else "ActBtn"))
	b.disabled = opts.get("disabled", false)
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(52, 44)
	b.pressed.connect(func() -> void:
		main.audio.play("ui")
		fn.call())
	if hot:
		var tw := b.create_tween().set_loops()
		tw.tween_property(b, "modulate", Color(1.18, 1.12, 1.0), 0.7)
		tw.tween_property(b, "modulate", Color.WHITE, 0.7)
	return b

func _goal_line() -> String:
	var ec := Game.castles(s, "e")
	var obj := Content.goal_text(s.win, "bar", s.heroKey, {
		"n": ec if s.win.type == "castles" else Game.unit_count(s, "e"), "left": maxi(0, int(s.win.get("turns", 0)) - s.turn + 1) }, s.heroMustLive)
	var pc := Game.castles(s, "p")
	var castle_txt := " · Thành [b]%d/%d[/b]" % [pc, ec] if pc or ec else ""
	return "[b][color=#%s]%s[/color][/b]%s · Làng [b]%d/%d[/b] · Quân [b]%d/%d[/b]" % [Style.GOLD.to_html(false), obj, castle_txt,
		Game.villages(s, "p"), Game.villages(s, "e"), Game.unit_count(s, "p"), s.unitCap]

## compact unit card for the popup: token + name + side/HP/XP, HP bar, one stat line; full = also the unit's description
func _unit_info(u: Dictionary, full := false) -> void:
	var st := Game.stat(s, u)
	var look := Content.unit_look(s, u)
	var dt: Array = ui.dest if u.id == ui.sel and ui.dest != null and ui.mode != M_IDLE else [u.x, u.y]
	var t: String = s.tiles[dt[1]][dt[0]]
	var xl: Array = Rules.RULES.xpLevels
	var next: Variant = xl[u.rank] if u.rank < xl.size() else null
	var name: String = look.name + (" " + "★".repeat(u.rank) if u.rank else "")
	var sub := "Máu %d · KN %d%s · %s +%d thủ" % [u.hp, u.xp, ("/%d" % next) if next != null else "",
		Content.terrain(t).name, Game.terrain_def(s, u, dt[0], dt[1])]
	_info.add_child(_head(Token.make(u.side, u.type, s.heroKey[u.side], 40), name, sub, u.side))
	_info.add_child(Style.Bar.make(u.hp / 100.0, 6, Color("#5fa83c"), Style.GOOD))
	var r: int = 5 * u.rank
	var b := Game.buffs_at(s, u, dt[0], dt[1])
	var atk_txt := "[b]%d[/b]" % (st.atk + r) + (" [color=#%s][b]+%d[/b][/color]" % [Board.BUFF_ATK.to_html(false), b.atk] if b.atk else "")
	var def_txt := "[b]%d[/b]" % (st.def + r) + (" [color=#%s][b]+%d[/b][/color]" % [Board.BUFF_DEF.to_html(false), b.def] if b.def else "")
	_info.add_child(_note("Công %s · Thủ %s · Đi [b]%d[/b] · Tầm [b]%s[/b]" % [atk_txt, def_txt, st.mv, Style.stat_range(st)], Style.MUTED, 14))
	for line: String in _buff_lines(u, b):
		_info.add_child(_note(line, Style.INK, 13))
	if full:
		var desc: String = look.blurb if u.type == "hero" else look.desc
		_info.add_child(_note(desc, Style.MUTED, 13))
		var tr: Array = Content.traits(u.type, s.heroKey[u.side])
		if tr.size():
			_info.add_child(_note("\n".join(tr.map(func(x: String) -> String: return "• " + x)), Style.INK, 13))
		_info.add_child(_note("[b]Cách dùng:[/b] " + Content.how_to_play(u.type), Style.GOLD, 13))
	if u.get("guard", false):
		_info.add_child(_note("💤 Đang canh gác: chỉ ra tay khi quân ta tới gần.", Style.MUTED, 13))

## the live bonuses as words: who gives them and when they count
func _buff_lines(u: Dictionary, b: Dictionary) -> Array:
	var out := []
	if b.atk:
		out.append("[color=#%s]⚔ +%d công[/color] khi ra đòn: đứng cạnh %s." % [Board.BUFF_ATK.to_html(false), b.atk, _name_of(b.atk_from)])
	if b.def:
		out.append("[color=#%s]🛡 +%d thủ[/color] khi bị đánh: đứng cạnh %s." % [Board.BUFF_DEF.to_html(false), b.def, _name_of(b.def_from)])
	return out

## why the forecast numbers are what they are: every modifier that touches this attack
func _mods_line(u: Dictionary, dx: int, dy: int, tgt: Dictionary) -> String:
	var parts := []
	var su := Game.stat(s, u)
	var stg := Game.stat(s, tgt)
	var bu := Game.buffs_at(s, u, dx, dy)
	if bu.atk:
		parts.append("[color=#%s]+%d công[/color] nhờ %s" % [Board.BUFF_ATK.to_html(false), bu.atk, _name_of(bu.atk_from)])
	if su.get("antiAir", 0) and stg.move == "fly":
		parts.append("+%d công đánh kỵ binh" % su.antiAir)
	if u.rank:
		parts.append("+%d công (%s)" % [Rules.RULES.rankBonus * u.rank, "★".repeat(u.rank)])
	var bt := Game.buffs_at(s, tgt, tgt.x, tgt.y)
	if su.get("magic", false):
		parts.append("phép bỏ qua địa hình")
	elif bt.terrain:
		parts.append("địch được %s +%d thủ" % [Content.terrain(s.tiles[tgt.y][tgt.x]).name.to_lower(), bt.terrain])
	if bt.def:
		parts.append("[color=#%s]địch +%d thủ[/color] nhờ %s" % [Board.BUFF_DEF.to_html(false), bt.def, _name_of(bt.def_from)])
	if stg.get("siege", false):
		parts.append("địch không đánh trả được")
	return " · ".join(parts)

func refresh() -> void:
	if s.is_empty():
		return
	_build_view()
	_turn.text = "Lượt %d" % s.turn
	_gold_num.text = str(s.gold.p)
	_gold_box.visible = s.allowed.p.size() > 0 or Game.castles(s, "p") > 0
	_income.text = "+%d" % Game.income(s, "p")
	_goal.text = Style.bold_in(_goal_line(), Style.INK)
	for c in _info.get_children() + _actions.get_children():
		c.get_parent().remove_child(c) # now, so the popup measures only the new content
		c.queue_free()
	var my_turn: bool = s.side == "p" and not ui.busy and s.winner == null
	_btn_hint.disabled = not my_turn
	_refresh_end_button(my_turn)
	_pop_anchor = null
	var u: Variant = _sel_unit()
	var peek: Variant = Game.unit_by_id(s, ui.peek) if ui.peek != null else null
	if ui.busy:
		pass
	elif peek != null:
		_pop_anchor = [peek.x, peek.y]
		_unit_info(peek, true)
		_actions.add_child(_act("Đóng", func() -> void:
			ui.peek = null
			refresh()))
		_actions.add_child(_act("Sách lính ›", func() -> void: main.menus.open_codex(peek.side)))
	elif u != null:
		if my_turn and u.side == "p" and not u.acted and ui.mode != M_IDLE:
			_pop_anchor = ui.dest
			_unit_info(u)
			var dx: int = ui.dest[0]
			var dy: int = ui.dest[1]
			var targets := Game.targets_from(s, u, dx, dy)
			if ui.mode == M_TARGET:
				var tgt: Variant = Game.unit_by_id(s, ui.target) if ui.target != null else null
				if tgt != null:
					var p := Game.preview(s, u, dx, dy, tgt)
					_info.add_child(_note("Đánh [b]%s[/b] (máu %d):" % [_name_of(tgt), tgt.hp]))
					_info.add_child(_preview_box(p))
					var mods := _mods_line(u, dx, dy, tgt)
					if mods != "":
						_info.add_child(_note(mods, Style.MUTED, 12))
					var tid: int = tgt.id
					_actions.add_child(_act("⚔ Đánh", func() -> void: commit({ "kind": "attack", "target": tid }), { "hot": true, "go": true }))
				else:
					_info.add_child(_note("Bấm vào kẻ địch viền đỏ để chọn mục tiêu."))
				_actions.add_child(_act("Quay lại", func() -> void:
					ui.mode = M_MOVED
					ui.target = null
					refresh()))
			else:
				var hk: Variant = ui.hintKind
				if targets.size():
					_actions.add_child(_act("⚔ Đánh (%d)" % targets.size(), func() -> void:
						ui.mode = M_TARGET
						var best: Variant = null
						var best_sc := -INF
						for t2: Dictionary in targets:
							var sc2 := _attack_score(Game.preview(s, u, dx, dy, t2))
							if sc2 > best_sc:
								best_sc = sc2
								best = t2
						ui.target = best.id
						refresh()))
				if Game.can_capture(s, u, dx, dy):
					_actions.add_child(_act("🏯 Chiếm thành" if s.tiles[dy][dx] == "c" else "🏠 Chiếm làng", func() -> void: commit({ "kind": "capture" }),
						{ "hot": hk == "capture" or hk == null, "go": true }))
				var graves := Game.raisable_graves(s, u, dx, dy)
				if graves.size():
					var g0: Dictionary = graves[0]
					_actions.add_child(_act(Content.text("raiseButton"), func() -> void: commit({ "kind": "raise", "target": [g0.x, g0.y] }), { "hot": hk == "raise" }))
				if dx != u.x or dy != u.y: # no "wait" on its own tile
					_actions.add_child(_act("Chờ", func() -> void: commit({ "kind": "wait" }), { "hot": hk == "wait" }))
				_actions.add_child(_act("Hủy", cancel))
		elif my_turn and u.side == "p" and not u.acted:
			pass # choosing where to go: the board (blue tiles, red-ringed enemies, hover forecast) is the whole UI
		else:
			_pop_anchor = [u.x, u.y]
			_unit_info(u, true)
			if u.side == "p" and u.acted:
				_info.add_child(_note("Đã hành động lượt này.", Style.MUTED, 13))
	elif ui.buyAt != null:
		var x: int = ui.buyAt[0]
		var y: int = ui.buyAt[1]
		_pop_anchor = [x, y]
		_info.add_child(_head(null, Content.text("buyTitle"), "Có %d vàng · Quân %d/%d · lính mới đi được từ lượt sau" % [s.gold.p, Game.unit_count(s, "p"), s.unitCap]))
		var grid := GridContainer.new()
		grid.columns = 1
		grid.add_theme_constant_override("v_separation", 6)
		grid.custom_minimum_size.x = POP_W
		for o: Dictionary in Game.buy_options(s, "p", x, y):
			var look := Content.unit_type_look("p", o.type, s.heroKey.p)
			var type: String = o.type
			var b := _act("", func() -> void: buy_unit(type), { "disabled": not o.ok or not my_turn, "hot": ui.hotBuy == o.type })
			b.tooltip_text = look.blurb if o.type == "hero" else look.desc
			b.custom_minimum_size = Vector2(POP_W, 46)
			var row := Style.hbox(8)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			row.offset_left = 8
			row.offset_right = -12
			var tk := Token.make("p", o.type, s.heroKey.p, 32)
			tk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(tk)
			var nm := Style.lbl(look.name, 16, Style.INK if o.ok else Color(Style.INK, 0.45), Style.bold)
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
		_actions.add_child(grid)
		_actions.add_child(_act("Đóng", cancel))
	elif ui.info != null:
		var x: int = ui.info.x
		var y: int = ui.info.y
		_pop_anchor = [x, y]
		var t: String = s.tiles[y][x]
		var own: Variant = s.owner.get(Vector2i(x, y))
		var tr: Dictionary = Rules.TERRAIN[t]
		var own_txt := ""
		if tr.has("building"):
			own_txt = " · " + (("của ta" if own == "p" else "của địch") if own != null else "chưa ai chiếm")
		_info.add_child(_head(null, Content.terrain(t).name + own_txt, "Thủ +%d · Giá đi %s" % [tr.def, "không qua" if tr.cost == INF else str(int(tr.cost))]))
		var note := Content.tile_note(t)
		if note != "":
			_info.add_child(_note(note, Style.MUTED, 13))
		if Game.grave_at(s, x, y) != null:
			_info.add_child(_note(Content.text("graveNote"), Style.MUTED, 13))
	if ui.hint != null:
		_info.add_child(Style.rich(ui.hint, 14, Style.GOLD, Style.GOLD_HI))
	_pop.visible = _info.get_child_count() + _actions.get_child_count() > 0
	if _pop.visible:
		_place_pop.call_deferred()

## put the popup beside its tile: right / left / below / above, whichever hides the fewest units (enemies count
## triple) and never the tile itself or the aimed target. No anchor (a lone hint) -> top centre of the board.
var _pop_pending := false
var _pop_placed_at: Variant = null

func _place_pop() -> void:
	if _pop == null or not _pop.visible or _pop_pending:
		return
	_pop_pending = true
	# wrapped text only knows its height after one layout pass at the final width: shrink, wait a frame, measure
	_pop.size = Vector2.ZERO
	var moved: bool = _pop_anchor != _pop_placed_at
	if moved:
		_pop.modulate.a = 0.0 # hidden while measuring, so it never flashes at the old spot
	await get_tree().process_frame
	_pop_pending = false
	_pop.modulate.a = 1.0
	_pop_placed_at = _pop_anchor
	if not _pop.visible:
		return
	_pop.size = Vector2.ZERO
	var sz := _pop.get_combined_minimum_size()
	_pop.size = sz
	var lim := _wrap.size
	if _pop_anchor == null:
		_pop.position = Vector2(((lim.x - sz.x) / 2.0), board.position.y + 10).floor()
		return
	var T := board.T
	var tile := board.position + Vector2(_pop_anchor[0] * T, _pop_anchor[1] * T)
	var keep: Array[Rect2] = [Rect2(tile, Vector2(T, T)), Rect2(_btn_end.position, _btn_end.size)]
	if ui.mode == M_TARGET and ui.target != null:
		var tg: Variant = Game.unit_by_id(s, ui.target)
		if tg != null:
			keep.append(Rect2(board.position + Vector2(tg.x * T, tg.y * T), Vector2(T, T)))
	var gap := 10.0
	var cands: Array[Vector2] = [
		tile + Vector2(T + gap, (T - sz.y) / 2), tile + Vector2(-sz.x - gap, (T - sz.y) / 2),
		tile + Vector2((T - sz.x) / 2, T + gap), tile + Vector2((T - sz.x) / 2, -sz.y - gap),
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
		for o: Dictionary in s.units:
			if o.id == ui.sel:
				continue
			if r.intersects(Rect2(board.position + Vector2(o.x * T, o.y * T), Vector2(T, T)).grow(-T * 0.2)):
				cost += 3.0 if o.side != "p" else 1.0
		if cost < best_cost:
			best_cost = cost
			best = p
	_pop.position = best.floor()

func _preview_box(p: Dictionary) -> Control:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 6)
	for cell: Array in [["Gây", p.dmg, " hạ gục" if p.kill else "", Style.GOOD], ["Bị đánh trả", p.counter, " ngã" if p.die else "", Style.BAD]]:
		var pc := Style.card(Color(0, 0, 0, 0.4), Style.LACQUER_3, 8, 6)
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := Style.vbox(0)
		v.add_child(Style.lbl(cell[0], 12, Style.MUTED))
		var h := Style.hbox(4)
		h.add_child(Style.lbl(str(cell[1]), 20, cell[3], Style.xbold))
		if cell[2] != "":
			var l := Style.lbl(cell[2], 13, Style.INK)
			l.size_flags_vertical = Control.SIZE_SHRINK_END
			h.add_child(l)
		v.add_child(h)
		pc.add_child(v)
		g.add_child(pc)
	return g


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
		Draw.radial(self, size * Vector2(0.5, 0.4), size.length() * 0.45, [[0.0, Color("#2a1810")], [1.0, Style.LACQUER]], 40, Vector2(1.0, size.y / size.x * 1.4))
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
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * R, c + Vector2(cos(a1), sin(a1)) * R]), Color(0.94, 0.79, 0.42, 0.08))
