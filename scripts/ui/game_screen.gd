class_name GameScreen
extends Control
## the war table: game state, board view, selection + input, hint. The rest lives in helpers that read / call it directly
## (review E5): hud = GameHud (map frame, floating HUD, ⚙ menu, corner card), panel = InfoPanel (orders / unit / buy popup,
## card text), player = EventPlayer (event playback, income / heal count-ups), turns = TurnDriver (turn flow, AI / bot loop,
## hotseat handoff, finish), cards = GameCards (new-unit intro, end screen), tutorial = Tutorial (step lock of t01 / t02).
## "me" = the side the person at the screen plays (_me); "p" / "e" literals left here mean faction colour.
## Port of the game half of src/ui/screens.js.

## selection modes: idle = nothing / choosing where to go; moved = destination picked; target = enemy aimed
const M_IDLE := "idle"
const M_MOVED := "moved"
const M_TARGET := "target"

var main: Main
var s: Dictionary = { }
var ctx: Dictionary = { }
var def: Dictionary = { }
## bumps on start / leave so stale async turn loops stop
var gen := 0
var ui := { }
var stats := { "p": 0, "e": 0 } # units lost per side
var fx: FX
var board: Board
var hud: GameHud
var panel: InfoPanel
var player: EventPlayer
var turns: TurnDriver
var cards: GameCards
var tutorial: Tutorial

var _hover_at := 0
# reach / best attack tile, memoised per board position: hovering re-asks them every mouse move
var _memo := { }
var _memo_fp := 0
var _intro_on := false

func _init() -> void:
	hud = GameHud.new(self)
	panel = InfoPanel.new(self)
	player = EventPlayer.new(self)
	turns = TurnDriver.new(self)
	cards = GameCards.new(self)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	fx = FX.new()
	fx.audio = main.audio
	add_child(fx)
	var saved_speed: float = Store.get_v("speed", 1.0)
	FX.speed = saved_speed if not main.flags.has("speed") else FX.speed
	_reset_ui()
	_build()

func _reset_ui() -> void:
	ui = {
		"sel": null,
		"dest": null,
		"mode": M_IDLE,
		"target": null,
		"info": null,
		"buyAt": null,
		"busy": false,
		"hint": null,
		"hotBuy": null,
		"hover": ui.get("hover"),
		"tip": ui.get("tip", 0),
		"hintKind": null,
		"peek": null,
		"raze": null,
	}

# ---------- layout ----------
## HUD never covers the map: wide screen -> left sidebar (⚙ + turn/gold/goal on top, unit card, Hết lượt at the bottom),
## tall screen -> top band (turn/gold/goal, ⚙) + bottom band (card left, Hết lượt right). Whichever gives bigger tiles.
## Only the orders popup (beside the selected tile) and the ⚙ menu float over the map.
func _build() -> void:
	hud.build_hud()
	panel.build_pop()
	cards.build_end()
	tutorial = Tutorial.new()
	add_child(tutorial) # last child: on top of the HUD for clicks
	resized.connect(hud.place_hud)

## while the enemy moves: hold Space or a mouse button (or ⏩) to run x4
func _process(_dt: float) -> void:
	if not visible or s.is_empty() or not _is_ai(_turn_side()) or not ui.busy:
		return
	var held := Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	FX.speed = maxf(turns.user_speed, 4.0) if (turns.ff or held) else turns.user_speed

# ---------- lifecycle ----------
func _def_for(c: Dictionary) -> Dictionary:
	if c.kind == "campaign":
		var mid: String = c.id
		return Content.level(mid)
	var map_id: String = c.get("map", "dong_bang")
	var hero: String = c.hero
	var gold: int = c.get("gold", 300)
	var cap: int = c.get("cap", 15)
	if c.kind == "duel":
		var hero_e: String = c.heroE
		var ctrl_e: String = c.ctrlE
		return Content.duel_def(map_id, hero, hero_e, ctrl_e, gold, cap)
	var easy: bool = c.easy
	return Content.skirmish_def(map_id, hero, easy, gold, cap)

func start(state: Dictionary, c: Dictionary) -> void:
	gen += 1
	if hud.gold_tw != null:
		hud.gold_tw.kill()
	hud.gold_shown = -1
	player.stop_heal_counts()
	hud.coins.clear()
	s = state
	ctx = c
	def = _def_for(c)
	_reset_ui()
	stats = { "p": 0, "e": 0 }
	var view_hide: Dictionary = board.view.hide
	var view_hold: Dictionary = board.view.hold
	view_hide.clear()
	view_hold.clear()
	board.view.sprites = []
	board.view.hp = null
	fx.clear()
	board.set_state(s)
	cards.end_layer.visible = false
	visible = true
	hud.speed_label()
	hud.sound_label()
	hud.show_menu(false)
	hud.fit.call_deferred()
	board.refresh_terrain()
	ctx.erase("story") # old saves / old ctx may carry it
	if ctx.kind == "campaign":
		Quests.on_open(s, def)
	hud.quests.bind(s, "")
	var tut_steps: Array = def.get("tutorial", []) if ctx.kind == "campaign" else []
	tutorial.bind(self, tut_steps)
	save()
	refresh()
	turns.begin()

# ---------- sides ----------
## the side the person at the screen plays: the side to move, unless the AI has it
func _me() -> String:
	var side := _turn_side()
	var other := Game.other(side)
	return other if _is_ai(side) and not _is_ai(other) else side

func _foe() -> String:
	return Game.other(_me())

func _turn_side() -> String:
	return str(s.get("side", "p"))

func _is_ai(side: String) -> bool:
	return Content.is_ai(s, side)

## two humans share the device: texts name the factions instead of "ta" / "địch"
func _hotseat() -> bool:
	return not _is_ai("p") and not _is_ai("e")

## a person (or the `bot` flag) moves now
func _human_turn() -> bool:
	return not _is_ai(_turn_side())

func _side_name(side: String) -> String:
	var f: Dictionary = Content.theme().factions[side]
	return str(f.get("duelShort", f.name)) if _hotseat() else str(f.short)

func leave() -> void:
	if not s.is_empty() and _is_ai(_turn_side()):
		FX.speed = turns.user_speed
	hud.btn_ff.visible = false
	gen += 1
	if cards.intro_layer != null:
		cards.intro_closed.emit()
	if turns.handoff_layer != null:
		turns.handoff_closed.emit()
	visible = false
	cards.end_layer.visible = false
	fx.clear()

func save() -> void:
	if s.is_empty() or s.winner != null:
		return
	var title: String = def.get("title", "")
	Store.save_game(s, ctx, title)

# ---------- view ----------
func _sel_unit() -> Variant:
	if ui.sel == null:
		return null
	var id: int = ui.sel
	return Game.unit_by_id(s, id)

func _name_of(u: Dictionary) -> String:
	return Content.unit_look(s, u).name

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
	return _memo_get(
		"r%d" % u.id,
		func() -> Dictionary:
			return Game.reachable(s, u),
	)

func _build_view() -> void:
	if s.is_empty():
		return
	var v: Dictionary = board.view
	v.hpCount = player.hp_count
	var u: Variant = _sel_unit()
	var su: Dictionary = u if u != null else { } # u typed; read only where u != null
	var my_turn: bool = _human_turn() and not ui.busy and s.winner == null
	v.busy = ui.busy
	v.sel = u if u != null and not ui.busy else null
	v.selMine = u != null and my_turn and u.side == _me() and not u.acted
	v.reach = null
	v.threat = null
	v.threatFill = null
	v.danger = []
	if u != null and not ui.busy and ui.mode == M_IDLE:
		v.reach = _reach(su)
		if su.side == _foe(): # enemy picked: where it can hit next turn + which of ours stand there
			var reach_e: Dictionary = v.reach
			var th: Dictionary = _memo_get(
				"t%d" % su.id,
				func() -> Dictionary:
					return Game.threat_tiles(s, su, reach_e),
			)
			v.threat = th
			# tint = tiles it hits but cannot walk to; siege fires only from where it stands, so all of them
			var siege: bool = Game.stat(s, su).get("siege", false)
			v.threatFill = (
				th
				if siege
				else _memo_get(
					"tf%d" % su.id,
					func() -> Dictionary:
						var only := { }
						for key: Vector2i in th:
							if not reach_e.has(key):
								only[key] = true
						return only,
				)
			)
			var danger: Array = []
			for o: Dictionary in s.units:
				var ox: int = o.x
				var oy: int = o.y
				if o.side == _me() and th.has(Vector2i(ox, oy)):
					danger.append(o.id)
			v.danger = danger
	v.attackable = []
	if v.selMine and ui.mode == M_IDLE:
		var reach_now: Dictionary = v.reach
		v.attackable = _memo_get(
			"a%d" % su.id,
			func() -> Array:
				return _attackable_anywhere(su, reach_now),
		)
	v.dest = ui.dest if u != null and not ui.busy and ui.mode != M_IDLE else null
	v.targets = []
	if ui.mode == M_TARGET and u != null:
		var tdx: int = ui.dest[0]
		var tdy: int = ui.dest[1]
		v.targets = Game.targets_from(s, su, tdx, tdy)
	v.target = ui.target
	var stays: bool = ui.mode == M_IDLE or (ui.mode == M_MOVED and ui.dest != null and u != null and ui.dest[0] == u.x and ui.dest[1] == u.y)
	v.razable = []
	if v.selMine and stays:
		var ux: int = su.x
		var uy: int = su.y
		v.razable = Game.razable_from(s, su, ux, uy)
	v.razeAt = ui.raze
	v.path = null
	v.preview = null
	var plan: Variant = _hover_attack() if v.selMine else null
	if plan != null:
		# hovering an enemy we can hit: path to the attack tile + damage preview on the board
		var pfx: int = plan.from[0]
		var pfy: int = plan.from[1]
		var ptgt: Dictionary = plan.target
		var p := Game.preview(s, su, pfx, pfy, ptgt)
		v.preview = p.merged({ "x": plan.target.x, "y": plan.target.y })
		v.path = Game.path_for(s, su, pfx, pfy)
		if ui.mode == M_IDLE:
			v.dest = plan.from
	elif v.selMine and ui.mode == M_IDLE and ui.hover != null and ui.hover in v.reach:
		var hx: int = ui.hover.x
		var hy: int = ui.hover.y
		v.path = Game.path_for(s, su, hx, hy)
	elif v.selMine and ui.mode != M_IDLE and ui.dest != null:
		var r := _reach(su)
		var ddx: int = ui.dest[0]
		var ddy: int = ui.dest[1]
		if r.has(Vector2i(ddx, ddy)):
			v.path = Game.path_for(s, su, ddx, ddy)
	v.info = ui.info
	v.buyAt = ui.buyAt
	v.hover = ui.hover

## the attack the selected unit would make on the hovered enemy: {target, from} or null
func _hover_attack() -> Variant:
	if ui.hover == null:
		return null
	var hx: int = ui.hover.x
	var hy: int = ui.hover.y
	var e: Variant = Game.unit_at(s, hx, hy)
	if e == null or e.side != _foe():
		return null
	var su: Dictionary = _sel_unit()
	var ed: Dictionary = e
	var from: Variant = _attack_from(su, ed)
	if from == null:
		return null
	return { "target": e, "from": from }

## where the selected unit attacks `e` from: the chosen tile if e is in range from it, else the best reachable tile
func _attack_from(u: Dictionary, e: Dictionary) -> Variant:
	if ui.mode != M_IDLE and ui.dest != null:
		var dx: int = ui.dest[0]
		var dy: int = ui.dest[1]
		if Game.targets_from(s, u, dx, dy).any(
			func(o: Dictionary) -> bool:
				return o.id == e.id,
		):
			return ui.dest
	return _best_attack_tile(u, e)

func _attackable_anywhere(u: Dictionary, reach: Dictionary) -> Array:
	var seen := { }
	var out := []
	for r: Dictionary in reach.values():
		var rx: int = r.x
		var ry: int = r.y
		for e: Dictionary in Game.targets_from(s, u, rx, ry):
			if not seen.has(e.id):
				seen[e.id] = true
				out.append(e)
	return out

func _best_attack_tile(u: Dictionary, target: Dictionary) -> Variant:
	return _memo_get(
		"b%d_%d" % [u.id, target.id],
		func() -> Variant:
			return _best_attack_tile_now(u, target),
	)

func _best_attack_tile_now(u: Dictionary, target: Dictionary) -> Variant:
	var best: Variant = null
	for r: Dictionary in _reach(u).values():
		var rx: int = r.x
		var ry: int = r.y
		if not Game.targets_from(s, u, rx, ry).any(
			func(o: Dictionary) -> bool:
				return o.id == target.id,
		):
			continue
		var p := Game.preview(s, u, rx, ry, target)
		var sc: float = _attack_score(p) + Game.terrain_def(s, u, rx, ry) * 0.3 - r.cost * 0.1
		if best == null or sc > best.sc:
			best = { "sc": sc, "x": r.x, "y": r.y }
	if best == null:
		return null
	return [best.x, best.y]

## one yardstick for "which attack is best" (hover tile choice and the ⚔ Đánh button): a kill beats any trade
func _attack_score(p: Dictionary) -> float:
	return p.dmg - p.counter * 1.1 + (50.0 if p.kill else (20.0 if p.mayKill else 0.0)) - (50.0 if p.die else (20.0 if p.mayDie else 0.0))

# ---------- input ----------
func _on_tile_clicked(x: int, y: int) -> void:
	if hud.menu.visible: # a click on the map closes the ⚙ menu first
		hud.show_menu(false)
		return
	if s.is_empty() or ui.busy or s.winner != null:
		return
	if not tutorial.allows(Vector2i(x, y)):
		tutorial.refuse()
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
	if ui.peek == id:
		ui.peek = null
	else:
		ui.peek = id
	refresh()

func cancel() -> void:
	if hud.menu.visible:
		hud.show_menu(false)
		return
	if ui.busy or s.is_empty():
		return
	if ui.peek != null:
		ui.peek = null
	elif ui.mode == M_TARGET:
		ui.mode = M_MOVED
		ui.target = null
	elif ui.mode == M_IDLE and _unbuy_sel():
		return
	else:
		_clear_sel()
		_force_stack()
	refresh()

## selected unit was just bought on top of another unit and has not stepped off: take the buy back (refund)
func _unbuy_sel() -> bool:
	var sel: Variant = _sel_unit()
	var u: Dictionary = sel if sel != null else { }
	if sel == null or not _human_turn() or not Game.can_unbuy(s, u):
		return false
	var x: int = u.x
	var y: int = u.y
	var cost: int = u.paid.cost
	var id: int = u.id
	Game.unbuy(s, id)
	_clear_sel()
	hud.coins.board = board
	hud.coins.play([{ "x": x, "y": y, "amount": cost }])
	main.audio.play("coin")
	save()
	refresh()
	return true

func _on_tile(x: int, y: int) -> void:
	var my_turn := _human_turn()
	var me := _me()
	var foe := _foe()
	var clicked: Variant = Game.unit_at(s, x, y)
	var cd: Dictionary = clicked if clicked != null else { } # clicked typed; read only where clicked != null
	var u: Variant = _sel_unit()
	var info_was: Variant = ui.info
	ui.hint = null
	ui.hotBuy = null
	ui.hintKind = null
	if u != null and my_turn and not u.acted and u.side == me:
		var su: Dictionary = u
		var ux: int = su.x
		var uy: int = su.y
		if clicked != null and clicked.side == foe:
			var from: Variant = _attack_from(su, cd)
			if from != null:
				# mouse: the preview was already on the board while hovering -> one click attacks.
				# touch (no settled hover): first tap aims and previews, second tap attacks.
				var aimed: bool = ui.mode == M_TARGET and ui.target == clicked.id and ui.dest == from
				if aimed or _hover_settled(x, y):
					ui.dest = from
					commit({ "kind": "attack", "target": clicked.id })
					return
				_aim(from, M_TARGET, clicked.id, ui.raze)
				main.audio.play("select")
				refresh()
				return
		# catapult: click a village ringed orange = aim at it (orders popup on the catapult); click it again = wreck it
		if clicked == null and Game.razable_from(s, su, ux, uy).has([x, y]):
			if ui.raze == [x, y] and ui.mode != M_IDLE:
				ui.dest = [u.x, u.y]
				commit({ "kind": "raze", "target": [x, y] })
				return
			_aim([u.x, u.y], M_MOVED, null, [x, y])
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
			if _in_place_work(su):
				_set_dest(x, y)
			else:
				_clear_sel()
				refresh()
			return
		var reach := _reach(su)
		if reach.has(Vector2i(x, y)) and clicked == null:
			_set_dest(x, y)
			return
		# outside the reach of a unit bought on top of another one = take the buy back (not its own castle tile)
		if ui.mode == M_IDLE and (x != u.x or y != u.y) and _unbuy_sel():
			return
	_clear_sel()
	if my_turn and (clicked == null or clicked.side == me) and _stuck_unit() != null and (clicked == null or not Game.stacked(s, cd)):
		_force_stack()
		main.audio.play("select")
		refresh()
		return
	if clicked != null:
		# AE2: our castle opens the shop even when the unit on it has acted, or is an enemy (new unit steps off)
		if my_turn and (clicked.side == foe or clicked.acted) and Game.buy_options(s, me, x, y).size():
			ui.buyAt = [x, y]
			main.audio.play("select")
			refresh()
			return
		ui.sel = clicked.id
		if clicked.side == me:
			hud.quests.celebrate(Quests.note(s, "select", clicked.type))
		# standing on a village/castle to take (or a ruin to repair): orders open on the first click
		if my_turn and clicked.side == me and not clicked.acted \
				and (Game.can_capture(s, cd, x, y) or Game.can_repair(s, cd, x, y)):
			_set_dest(x, y)
			return
		main.audio.play("select")
		refresh()
		return
	ui.sel = null
	if my_turn and Game.buy_options(s, me, x, y).size():
		ui.buyAt = [x, y]
		main.audio.play("select")
		refresh()
		return
	# same terrain tile again = close its card (HUD back)
	if info_was == null or info_was.x != x or info_was.y != y:
		ui.info = { "x": x, "y": y }
	refresh()

## something worth doing without moving: capture the tile it stands on, or raise a grave next to it
func _in_place_work(u: Dictionary) -> bool:
	var ux: int = u.x
	var uy: int = u.y
	return (
		Game.can_capture(s, u, ux, uy) or Game.raisable_graves(s, u, ux, uy).size() > 0 or Game.can_repair(s, u, ux, uy) \
				or Game.razable_from(s, u, ux, uy).size() > 0
		or _can_buy_here(u)
	)

## our unit stands on our castle and something can be bought there (the new unit then steps off)
func _can_buy_here(u: Dictionary) -> bool:
	var ux: int = u.x
	var uy: int = u.y
	return u.side == _me() and _human_turn() and Game.buy_options(s, _me(), ux, uy).any(
			func(o: Dictionary) -> bool:
				return o.ok,
		)

## true when the mouse has rested on (x,y) long enough that the board preview was visible
func _hover_settled(x: int, y: int) -> bool:
	return ui.hover != null and ui.hover == Vector2i(x, y) and Time.get_ticks_msec() - _hover_at >= 150

## the village a catapult would wreck when none is aimed: an enemy one first, then the nearest
func _best_raze(list: Array) -> Array:
	var u: Dictionary = _sel_unit()
	var best: Array = list[0]
	var best_sc := -INF
	var owners: Dictionary = s.owner
	var ux: int = u.x
	var uy: int = u.y
	for t: Array in list:
		var tx: int = t[0]
		var ty: int = t[1]
		var sc := (100.0 if owners.get(Vector2i(tx, ty)) == _foe() else 0.0) - Game.dist(ux, uy, tx, ty)
		if sc > best_sc:
			best_sc = sc
			best = t
	return best

## Space / Enter / clicking the chosen tile again: attack the aimed target, else capture, else wait
func default_action() -> void:
	var u: Variant = _sel_unit()
	if ui.busy or u == null or u.side != _me() or u.acted or not _human_turn() or s.winner != null:
		return
	var su: Dictionary = u
	var ux: int = su.x
	var uy: int = su.y
	if ui.mode == M_IDLE:
		ui.dest = [u.x, u.y]
		ui.mode = M_MOVED
		if not _in_place_work(su): # Space on a unit that stays: "giữ chỗ" = done for this turn, no move
			commit({ "kind": "wait" })
			return
	if ui.mode == M_TARGET and ui.target != null:
		commit({ "kind": "attack", "target": ui.target })
		return
	var dx: int = ui.dest[0] # every branch below reads dest
	var dy: int = ui.dest[1]
	if ui.raze != null and ui.dest[0] == u.x and ui.dest[1] == u.y:
		commit({ "kind": "raze", "target": ui.raze })
	elif Game.can_capture(s, su, dx, dy):
		commit({ "kind": "capture" })
	elif Game.can_repair(s, su, dx, dy):
		commit({ "kind": "repair" })
	elif ui.dest[0] == u.x and ui.dest[1] == u.y and Game.raisable_graves(s, su, ux, uy).size():
		var g0: Dictionary = Game.raisable_graves(s, su, ux, uy)[0]
		commit({ "kind": "raise", "target": [g0.x, g0.y] })
	else:
		commit({ "kind": "wait" })

## Tab: select the next unit of ours that hasn't acted
func select_next() -> void:
	if ui.busy or not _human_turn() or s.winner != null:
		return
	var units: Array = s.units
	var me := _me()
	var mine: Array = units.filter(
		func(o: Dictionary) -> bool:
			return o.side == me and not o.acted,
	)
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
	hud.quests.celebrate(Quests.note(s, "select", mine[i].type))

func _unhandled_input(ev: InputEvent) -> void:
	var key := ev as InputEventKey # null for mouse / touch events
	if _intro_on:
		if key != null and key.pressed and not key.echo and key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			cards.intro_closed.emit()
			get_viewport().set_input_as_handled()
		return
	if turns.handoff_layer != null:
		if key != null and key.pressed and not key.echo and key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			turns.handoff_closed.emit()
			get_viewport().set_input_as_handled()
		return
	if not visible or s.is_empty() or cards.end_layer.visible or main.menus.is_codex_open():
		return
	if not (key != null and key.pressed and not key.echo):
		return
	if tutorial.active() and key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_E, KEY_H]:
		tutorial.refuse()
		get_viewport().set_input_as_handled()
		return
	match key.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			default_action()
		KEY_TAB:
			select_next()
		KEY_E:
			turns.end_player_turn()
		KEY_H:
			_on_hint()
		_:
			return
	get_viewport().set_input_as_handled()

## drop the selection and everything hanging off it (destination, aim, buy / info popups, hint, unit card)
func _clear_sel() -> void:
	ui.sel = null
	ui.dest = null
	ui.mode = M_IDLE
	ui.target = null
	ui.buyAt = null
	ui.info = null
	ui.raze = null
	ui.hint = null
	ui.hotBuy = null
	ui.hintKind = null
	ui.peek = null

## point the selection: destination, mode, attack target, village to wreck; closes the buy / info popups
func _aim(dest: Variant, mode: String, target: Variant, raze: Variant) -> void:
	ui.dest = dest
	ui.mode = mode
	ui.target = target
	ui.buyAt = null
	ui.info = null
	ui.raze = raze

func _set_dest(x: int, y: int) -> void:
	_aim([x, y], M_MOVED, null, null)
	main.audio.play("select")
	refresh()

func commit(extra: Dictionary) -> void:
	if not tutorial.allows("act:" + str(extra.kind)):
		tutorial.refuse()
		return
	player.stop_heal_counts() # an action's own hp playback must not be overridden by a heal still counting
	var my := gen
	var u: Dictionary = _sel_unit()
	var act := { "id": u.id, "to": ui.dest }
	act.merge(extra, true)
	_clear_sel()
	ui.busy = true
	refresh()
	var before := player.snapshot()
	var ev := Game.do_action(s, act)
	var done := Quests.observe(s, ev) # before save: progress persists; stamp after playback
	hud.quests.hold(done)
	save()
	await player.play(ev, before)
	if gen != my:
		return
	ui.busy = false
	refresh()
	hud.quests.celebrate(done)
	if s.winner != null:
		turns.finish()

func buy_unit(type: String) -> void:
	if not tutorial.allows("buy:" + type):
		tutorial.refuse()
		return
	var x: int = ui.buyAt[0]
	var y: int = ui.buyAt[1]
	var nu: Variant = Game.buy(s, x, y, type)
	if nu == null:
		return
	fx.buy_fx(x, y)
	hud.bump_gold()
	_clear_sel()
	ui.sel = nu.id # AE2: the new unit moves / attacks right away (must step off if the castle was occupied)
	_stack_hint()
	var done := Quests.note(s, "buy", type)
	save()
	refresh()
	hud.quests.celebrate(done)

## our unit that shares a tile (bought onto an occupied castle) and still has to step off
func _stuck_unit() -> Variant:
	var units: Array = s.units
	for i in range(units.size() - 1, -1, -1):
		var u: Dictionary = units[i]
		if u.side == _me() and not u.acted and Game.stacked(s, u):
			return u
	return null

## keep a stacked unit selected until one of the pair moves away; true when it took over the selection
func _force_stack() -> bool:
	var st: Variant = _stuck_unit()
	if st == null:
		return false
	var cur: Variant = _sel_unit()
	var cu: Dictionary = cur if cur != null else { }
	if cur != null and Game.stacked(s, cu) and not cur.acted:
		return false
	_clear_sel()
	ui.sel = st.id
	_stack_hint()
	return true

func _stack_hint() -> void:
	var sel: Variant = _sel_unit()
	var u: Dictionary = sel if sel != null else { }
	if sel != null and Game.stacked(s, u):
		ui.hint = "Hai quân đứng chung lâu đài: cho [b]%s[/b] bước ra ô khác%s." % [
			_name_of(u),
			", hoặc bấm ra ngoài vùng đi để hủy mua (hoàn vàng)" if Game.can_unbuy(s, u) else "",
		]

## units of ours that could still attack or capture this turn
func _open_work() -> int:
	var n := 0
	for u: Dictionary in s.units:
		if u.side != _me() or u.acted:
			continue
		var reach := _reach(u)
		for r: Dictionary in reach.values():
			var rx: int = r.x
			var ry: int = r.y
			if Game.can_capture(s, u, rx, ry) or Game.targets_from(s, u, rx, ry).size() or Game.can_repair(s, u, rx, ry) \
					or Game.razable_from(s, u, rx, ry).size():
				n += 1
				break
	return n

# ---------- hint ----------
func _on_hint() -> void:
	if s.is_empty() or ui.busy or not _human_turn() or s.winner != null or tutorial.active():
		return
	_reset_ui()
	var step: Variant = AI.next_step(s.duplicate(true), { }) # next_step may clear guard flags: ask on a copy
	if step == null:
		ui.hint = "Không còn việc gì đáng làm. Bấm [b]Hết lượt[/b]."
		refresh()
		return
	if step.kind == "buy":
		ui.buyAt = [step.x, step.y]
		ui.hotBuy = step.type
		var hot_type: String = step.type
		ui.hint = "Gợi ý: mua [b]%s[/b]." % Content.unit_type_look(_me(), hot_type, s.heroKey[_me()]).name
		refresh()
		return
	var a: Dictionary = step.act
	var aid: int = a.id
	var u: Dictionary = Game.unit_by_id(s, aid)
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
	ui.raze = a.target if a.kind == "raze" else null
	var kind: String = a.kind
	var verb: String = Content.text("raiseVerb") if kind == "raise" else Content.text("hint_" + kind)
	ui.hint = "Gợi ý: [b]%s[/b] %s. Bấm nút sáng để làm theo." % [_name_of(u), verb]
	ui.hintKind = a.kind
	refresh()

func refresh() -> void:
	if s.is_empty():
		return
	tutorial.advance()
	_build_view()
	hud.refresh_top()
	panel.clear_pop()
	var my_turn: bool = _human_turn() and not ui.busy and s.winner == null
	hud.btn_hint.disabled = not my_turn or tutorial.active()
	hud.refresh_end_button(my_turn)
	panel.render_pop(my_turn)
