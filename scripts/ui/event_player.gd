class_name EventPlayer
extends RefCounted
## GameScreen part (review E5): plays Game events on the board (move tweens, attacks, deaths, capture, raze, raise…),
## income coins + gold count-up, heal pops + hp count-up. Reads / calls the screen (gs) directly.

var gs: GameScreen
var hp_count := { } # unit id -> hp shown while a heal counts up

var _heal_tws: Array[Tween] = []

func _init(screen: GameScreen) -> void:
	gs = screen

## every paying building pops its own "+N"; the total counts up as they land
func income_fx() -> void:
	var items: Array = []
	var me := gs._me()
	for k: Vector2i in gs.s.owner:
		if gs.s.owner[k] == me:
			items.append({ "x": k.x, "y": k.y, "amount": Game.income_of(gs.s.tiles[k.y][k.x]) })
	items.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x),
	)
	gs.hud.coins.board = gs.board
	gs.hud.coins.play(items)
	gs.main.audio.play("coin")
	var from: int = gs.hud.gold_shown if gs.hud.gold_shown >= 0 else gs.s.gold[me]
	if gs.hud.gold_tw != null:
		gs.hud.gold_tw.kill()
	gs.hud.gold_tw = _count_up(
		gs.hud.gold_num,
		CoinPop.RISE,
		0.9,
		func(k: float) -> void:
			var gold_now: float = gs.s.gold[me] # live target: a buy mid-count still ends right
			gs.hud.gold_shown = roundi(lerpf(from, gold_now, k))
			gs.hud.gold_num.text = str(gs.hud.gold_shown),
	)
	gs.hud.gold_tw.tween_callback(
		func() -> void:
			gs.hud.gold_shown = -1
			gs.hud.gold_num.text = str(gs.s.gold[me])
			gs.hud.bump_gold(),
	)

## heal = same pop as income (green +N over the unit, after the coins) + the hp bar counting up
func heal_fx(e: Dictionary) -> void:
	var id: int = e.id
	var u: Variant = Game.unit_by_id(gs.s, id)
	if u == null:
		return
	var from: int = u.hp - e.amount
	hp_count[id] = from
	gs.hud.coins.board = gs.board
	gs.hud.coins.play([{ "x": e.x, "y": e.y, "amount": e.amount }], "heal", 0.3)
	var ex: float = e.x
	var ey: float = e.y
	gs.fx.heal_sparkle(ex, ey)
	gs.main.audio.play("heal")
	var tw := _count_up(
		gs,
		0.3 + CoinPop.RISE,
		0.7,
		func(k: float) -> void:
			var cur: Variant = Game.unit_by_id(gs.s, id)
			if cur == null:
				hp_count.erase(id)
				return
			var cur_hp: float = cur.hp
			hp_count[id] = roundi(lerpf(from, cur_hp, k))
			gs.board.queue_redraw(),
	)
	_heal_tws.append(tw)
	tw.tween_callback(
		func() -> void:
			hp_count.erase(id)
			gs.board.queue_redraw(),
	)

## a shown number counting up: wait delay s, then step(k) for k 0 -> 1 over dur s (ease-out); chain the end on it
func _count_up(host: Node, delay: float, dur: float, step: Callable) -> Tween:
	var tw := host.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(step, 0.0, 1.0, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tw

func stop_heal_counts() -> void:
	for tw: Tween in _heal_tws:
		if tw.is_valid():
			tw.kill()
	_heal_tws.clear()
	hp_count.clear()

func snapshot() -> Dictionary:
	var m := { }
	for u: Dictionary in gs.s.units:
		m[u.id] = u.duplicate()
	return m

func play(events: Array, before: Dictionary) -> void:
	var my := gs.gen
	var v: Dictionary = gs.board.view
	var hp := { }
	for id: int in before:
		hp[id] = before[id].hp
	v.hp = hp
	var dying := { }
	for e: Dictionary in events:
		if e.t == "die" and before.has(e.id):
			var bu: Dictionary = before[e.id]
			var copy: Dictionary = bu.duplicate()
			copy.x = e.x
			copy.y = e.y
			var sp := { "u": copy, "hidden": false }
			dying[e.id] = sp
			var sprites: Array = v.sprites
			sprites.append(sp)
		if e.t == "raise" or e.t == "spawn":
			v.hide[e.id] = true
		if e.t == "raze": # keep the village standing until the rock lands
			var rx: int = e.x
			var ry: int = e.y
			v.hold[Vector2i(rx, ry)] = [e.tile, e.prev]
		if e.t == "repair":
			var px: int = e.x
			var py: int = e.y
			v.hold[Vector2i(px, py)] = [e.tile, null]
	var dived := false
	for ei in events.size():
		var e: Dictionary = events[ei]
		var ex: int = e.get("x", 0) # tile; events without one (move, rank, aura, income) never read it
		var ey: int = e.get("y", 0)
		if gs.gen != my:
			return
		if dived and e.t != "hit" and e.t != "die":
			dived = false
			await gs.board.unfocus()
		if e.t == "hit" and not dived and not e.get("counter", false) and _zoom_on():
			dived = true
			var zfx: int = e.fx
			var zfy: int = e.fy
			await gs.board.focus(Vector2i(zfx, zfy), Vector2i(ex, ey))
		match e.t:
			"move":
				var eid: int = e.id
				var ds: Variant = dying.get(eid)
				var src: Variant = ds.u if ds != null else before.get(eid, Game.unit_by_id(gs.s, eid))
				var src_u: Dictionary = src
				var copy: Dictionary = src_u.duplicate()
				if ds != null:
					ds.hidden = true
				v.hide[e.id] = true
				var sp := { "u": copy }
				var sprites: Array = v.sprites
				sprites.append(sp)
				gs.main.audio.play("move")
				var path: Array = e.path
				if path.size() > 1:
					var p0x: float = path[0][0]
					var p0y: float = path[0][1]
					gs.fx.dust(p0x, p0y) # the first step kicks up dust where it starts
				for i in range(1, path.size()):
					var a: Array = path[i - 1]
					var b: Array = path[i]
					await gs.fx.tween(
						95.0,
						func(t: float) -> void:
							copy.x = a[0] + (b[0] - a[0]) * t
							copy.y = a[1] + (b[1] - a[1]) * t,
					)
					var bx: float = b[0]
					var by: float = b[1]
					gs.fx.dust(bx, by)
				if gs.gen != my:
					return
				var sprites_now: Array = v.sprites
				var hide_now: Dictionary = v.hide
				sprites_now.erase(sp)
				hide_now.erase(e.id)
				if ds != null:
					var last: Array = path[path.size() - 1]
					ds.u.x = last[0]
					ds.u.y = last[1]
					ds.hidden = false
			"hit":
				var kill := events.any(
					func(o: Dictionary) -> bool:
						return o.t == "die" and o.id == e.id,
				)
				var att := { "x": e.fx, "y": e.fy, "id": e.from, "type": e.type, "side": e.side }
				var eid: int = e.id
				var tu: Variant = before.get(eid, Game.unit_by_id(gs.s, eid))
				var dfd := { "x": e.x, "y": e.y, "id": e.id, "type": tu.type if tu != null else "soldier" }
				var etype: String = e.type
				var eside: String = e.side
				var amount: int = e.amount
				var rig: Rig = Rigs.make(etype, eside) if gs.board is Board else null
				if rig != null: # code-rigged attack: hp drops at its big HIT (on_hit runs exactly once)
					await gs.fx.rig_attack(
						gs.board,
						rig,
						att,
						dfd,
						amount,
						{
							"counter": e.get("counter", false),
							"kill": kill,
							"on_hit": func() -> void:
								hp[e.id] = hp.get(e.id, 100) - e.amount,
						},
					)
				else:
					await gs.fx.attack(att, dfd, amount, { "counter": e.get("counter", false), "kill": kill })
					hp[e.id] = hp.get(e.id, 100) - e.amount
			"die":
				var sp: Variant = dying.get(e.id)
				if sp != null:
					var sprites: Array = v.sprites
					sprites.erase(sp)
					var spu: Dictionary = sp.u
					gs.fx.death(spu)
				gs.stats[e.side] += 1
				await gs.fx.sleep(380.0)
			"capture":
				var eside: String = e.side
				gs.fx.capture(ex, ey, eside)
				var castle := Game.sells(e.tile)
				var cap_txt := Content.text("captureCastle") if castle else Content.text("captureVillage")
				gs.fx.float_text(ex, ey - 0.3, cap_txt, "#ffe08a", 1300.0, castle)
				await gs.fx.sleep(700.0 if castle else 450.0)
			"raze":
				await gs.fx.raze({ "x": e.fx, "y": e.fy, "id": e.from }, ex, ey)
				var hold: Dictionary = v.hold
				hold.erase(Vector2i(ex, ey))
				gs.board.refresh_terrain()
				gs.fx.float_text(ex, ey - 0.3, Content.text("razeText"), "#ffb36b", 1300.0, true)
				await gs.fx.sleep(600.0)
			"repair":
				gs.fx.repair(ex, ey)
				var hold: Dictionary = v.hold
				hold.erase(Vector2i(ex, ey))
				gs.board.refresh_terrain()
				gs.fx.float_text(ex, ey - 0.3, Content.text("repairText"), "#ffe08a", 1300.0)
				await gs.fx.sleep(450.0)
			"rank":
				var eid: int = e.id
				var u: Variant = Game.unit_by_id(gs.s, eid)
				if u != null:
					var ux: int = u.x
					var uy: int = u.y
					var utype: String = u.type
					var rank: int = e.rank
					# AE2 announces only the renames (even levels <= 6, never the commander); other levels: quiet LvN
					gs.fx.rank(ux, uy, rank, Content.rank_announced(utype, rank))
					await gs.fx.sleep(350.0)
			"aura":
				for id: int in e.ids:
					var au: Variant = Game.unit_by_id(gs.s, id)
					if au != null:
						var ax: float = au.x
						var ay: float = au.y
						gs.fx.ring(ax, ay, "#5fd35a", 500.0, 0.6, 0.06)
				gs.main.audio.play("ui")
			"poison":
				gs.fx.ring(ex, ey, "#e0503f", 600.0, 0.7, 0.08)
				gs.fx.float_text(ex, ey - 0.3, "−%d công/thủ" % e.amount, "#ff8a7a", 1000.0)
			"graveGone":
				pass
			"raise":
				gs.fx.raise_fx(ex, ey)
				await gs.fx.sleep(450.0)
				var hide_ids: Dictionary = v.hide
				hide_ids.erase(e.id)
				await gs.fx.sleep(250.0)
			"spawn":
				var hide_ids: Dictionary = v.hide
				hide_ids.erase(e.id)
				gs.fx.spawn_fx(ex, ey)
				await gs.fx.sleep(220.0)
			"buy":
				gs.fx.buy_fx(ex, ey)
				await gs.fx.sleep(250.0)
			"heal":
				heal_fx(e)
			"income":
				if e.side == gs._me() and e.amount:
					income_fx()
	if dived and gs.gen == my:
		await gs.board.unfocus()
	v.hp = null
	var hold_end: Dictionary = v.hold
	hold_end.clear()
	var sprites_end: Array = v.sprites
	v.sprites = sprites_end.filter(
		func(sp: Dictionary) -> bool:
			return not dying.has(sp.u.id),
	)

## attacks zoom onto the two units unless fast-forwarding
func _zoom_on() -> bool:
	return not gs.turns.ff and not gs.main.flags.has("nozoom") and (not gs.main.flags.has("bot") or gs.main.flags.has("zoom"))
