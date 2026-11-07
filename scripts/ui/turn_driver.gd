class_name TurnDriver
extends RefCounted
## GameScreen part (review E5): turn flow: turn start, end turn, enemy AI loop (+ ⏩), `bot` loop,
## hotseat handoff, finish (result + end card buttons). Async: every await re-checks gs.gen. Reads / calls the screen (gs) directly.

signal handoff_closed

var gs: GameScreen
## enemy turn fast-forward: ⏩ pressed for this turn; speed the player chose, restored after
var ff := false
var user_speed := 1.0
var handoff_layer: Control = null

func _init(screen: GameScreen) -> void:
	gs = screen

func begin() -> void:
	if gs._hotseat():
		_hotseat_start()
		return
	var ai := gs._is_ai(gs._turn_side())
	gs.hud.banner(Content.text("enemyTurn") if ai else _turn_banner(), gs._turn_side() == "e")
	if not ai:
		gs.cards.intro_new_units.call_deferred()
		_maybe_bot()
	else:
		ai_turn()

## hotseat game opened (new or continued): hand the device to the side to move first
func _hotseat_start() -> void:
	var my := gs.gen
	gs.ui.busy = true
	gs.refresh()
	await _handoff()
	if gs.gen != my:
		return
	gs.ui.busy = false
	gs.hud.banner(_turn_banner(), gs._turn_side() == "e")
	gs.refresh()
	_maybe_bot()

func _turn_banner() -> String:
	if gs._hotseat():
		return Content.text("duelTurn").format({ "turn": gs.s.turn, "side": gs._side_name(gs._turn_side()) })
	return Content.text("turnBanner").format({ "turn": gs.s.turn })

func end_player_turn(_force := false) -> void: # _force: legacy arg (end turn no longer asks twice)
	if gs.ui.busy or not gs._human_turn() or gs.s.winner != null:
		return
	if not gs.tutorial.allows("end_turn"):
		gs.tutorial.refuse()
		return
	if gs._stuck_unit() != null: # a unit bought onto an occupied castle has not stepped off yet
		gs._clear_sel()
		gs._force_stack()
		gs.main.audio.play("select")
		gs.refresh()
		return
	var my := gs.gen
	gs._clear_sel()
	var before := gs.player.snapshot()
	var ev := Game.end_turn(gs.s)
	gs.hud.quests.celebrate(Quests.note(gs.s, "end_turn", null) + Quests.observe(gs.s, ev))
	_count_from(ev)
	gs.save()
	if gs.s.winner != null:
		finish()
		return
	gs.ui.busy = true
	gs.refresh()
	if gs._human_turn(): # two humans: hand the device over, then the new side's turn start plays
		await _handoff()
		if gs.gen == my:
			await _turn_start(ev, before)
		return
	gs.hud.banner(Content.text("enemyTurn"), true)
	await gs.player.play(ev, before)
	if gs.gen != my:
		return
	await ai_turn()

## the next person takes the device: full-screen card, any tap / Space / Enter goes on (`bot` runs skip it)
func _handoff() -> void:
	if gs.main.flags.has("bot"):
		return
	var turn: int = gs.s.turn
	var side_txt: String = Content.theme().factions[gs.s.side].name
	handoff_layer = HudWidgets.Handoff.make(
		Content.text("handoffTitle").format({ "side": side_txt }),
		Content.text("handoffSub").format({ "turn": turn }),
		Style.P_NAME if gs.s.side == "p" else Style.SEA_HI,
		handoff_closed.emit,
	)
	gs.add_child(handoff_layer)
	gs.main.audio.play("drum")
	if gs.main.flags.has("shots"):
		gs.main.shot(str(gs.main.flags.get("tag", "s")) + "_handoff")
	await handoff_closed
	gs.main.audio.play("ui")
	handoff_layer.queue_free()
	handoff_layer = null

## income about to play for the side on screen: its total counts up from before the coins
func _count_from(ev: Array) -> void:
	for e: Dictionary in ev:
		if e.t == "income" and e.side == gs._me() and e.amount:
			gs.hud.gold_shown = gs.s.gold[gs._me()] - e.amount

## a human side's turn begins: banner, income / heal / reinforcement playback, then input opens
func _turn_start(ev: Array, before: Dictionary) -> void:
	var my := gs.gen
	gs.hud.banner(_turn_banner(), gs._hotseat() and gs._turn_side() == "e")
	gs.refresh()
	await gs.player.play(ev, before) # income, heal, reinforcements: input stays closed until they finish
	if gs.gen != my:
		return
	gs.ui.busy = false
	gs.refresh()
	_maybe_bot()

func ai_turn() -> void:
	var my := gs.gen
	var side: String = gs.s.side
	var game_seed: int = gs.s.get("seed", 0)
	var turn: int = gs.s.turn
	AI.seed_game(game_seed * 1000 + turn) # same game + turn -> same enemy choices after a reload
	user_speed = FX.speed
	ff = false
	gs.hud.btn_ff.visible = not gs.main.flags.has("bot")
	gs.ui.busy = true
	gs.refresh()
	await gs.fx.sleep(900.0)
	if gs.gen != my:
		return
	var mem := { } # difficulty: s.aiParams (Game.new_game from ctrl)
	while gs.s.winner == null and gs.s.side == side:
		var next: Variant = AI.next_step(gs.s, mem)
		if next == null:
			break
		var step: Dictionary = next
		var before := gs.player.snapshot()
		var sig := _progress_sig()
		var ev := AI.apply_step(gs.s, step)
		if ev.is_empty() and _progress_sig() == sig:
			push_warning("AI step rejected, ending enemy turn: %s" % [step])
			break # a rejected step would repeat forever
		var done := Quests.observe(gs.s, ev) # our counter-attacks on their turn count
		gs.hud.quests.hold(done)
		gs.save()
		if not (step.kind == "act" and step.act.kind == "wait" and ev.is_empty()):
			await gs.player.play(ev, before)
		if gs.gen == my:
			gs.hud.quests.celebrate(done)
		await gs.fx.sleep(90.0)
		if gs.gen != my:
			return
	gs.hud.btn_ff.visible = false
	FX.speed = user_speed
	if gs.s.winner != null:
		gs.ui.busy = false
		finish()
		return
	var before := gs.player.snapshot()
	var ev := Game.end_turn(gs.s)
	var healed := Quests.observe(gs.s, ev) # heal on our turn start
	gs.hud.quests.hold(healed)
	_count_from(ev) # our income lands here (AI's end_turn): total counts up when coins land
	gs.save()
	if gs.s.winner != null:
		gs.ui.busy = false
		finish()
		return
	gs.hud.btn_ff.visible = false
	ff = false
	FX.speed = user_speed
	await _turn_start(ev, before)
	if gs.gen == my:
		gs.hud.quests.celebrate(healed)

## changes whenever an AI step did anything (moved / acted / bought)
func _progress_sig() -> String:
	var acted := 0
	var units: Array = gs.s.units
	for u: Dictionary in units:
		if u.acted:
			acted += 1
	return "%d %d %d %d" % [units.size(), acted, gs.s.gold.p, gs.s.gold.e]

## debug flag `bot`: the AI plays our side too (screenshots / soak test)
func _maybe_bot() -> void:
	if gs.main.flags.has("bot") and gs._human_turn() and gs.s.winner == null:
		_bot_turn.call_deferred()

func _bot_turn() -> void:
	var my := gs.gen
	await gs.fx.sleep(400.0)
	var mem := { }
	while gs.gen == my and gs._human_turn() and gs.s.winner == null:
		var step: Variant = AI.next_step(gs.s, mem)
		if step == null:
			break
		if step.kind == "buy":
			var sig := _progress_sig()
			gs.ui.buyAt = [step.x, step.y]
			var type: String = step.type
			gs.buy_unit(type)
			if _progress_sig() == sig:
				break # buy refused: would loop without yielding
			continue
		gs.ui.sel = step.act.id
		gs.ui.dest = step.act.to
		var act: Dictionary = step.act
		var rest: Dictionary = act.duplicate()
		rest.erase("id")
		rest.erase("to")
		await gs.commit(rest)
	if gs.gen == my and gs.s.winner == null:
		await end_player_turn(true)

func finish() -> void:
	Store.clear_game()
	var campaign: bool = gs.ctx.kind == "campaign"
	var star_goals: Array = Stars.check(gs.s, gs.def) if campaign else []
	var stars := Stars.final(gs.s, gs.def) if campaign else 0
	var best_before := Store.stars_of(str(gs.ctx.get("id", ""))) if campaign else 0
	Store.record_result(gs.ctx, gs.s.winner, stars) # before any await: leaving during the pause must not lose the win
	var duel: bool = gs.ctx.kind == "duel"
	var win: bool = gs.s.winner == gs._me() or (duel and gs._hotseat()) # two humans: someone at the screen won
	gs.refresh()
	var my := gs.gen
	var hero_keys: Dictionary = gs.s.heroKey
	var reason_text := Content.end_text(gs.s.winner, str(gs.s.reason), hero_keys)
	if duel: # ends[] lines speak as p ("Quân ta đã tan"): name the losing side instead
		var loser: String = Content.theme().factions[Game.other(str(gs.s.winner))].name
		reason_text = Content.text("duelEnd_" + str(gs.s.reason)).format({ "loser": loser })
		reason_text = "" if reason_text.begins_with("duelEnd_") else reason_text
	if not win and not duel:
		var tip := Content.text("loseTip_" + str(gs.s.reason))
		if not tip.begins_with("loseTip_"):
			reason_text += "\n" + tip
	await gs.get_tree().create_timer(0.6).timeout
	if gs.gen != my:
		return
	gs.main.audio.play("win" if win else "lose")
	var buttons := []
	if gs.ctx.kind == "campaign":
		var mission_id: String = gs.ctx.id
		var back := func() -> void:
			gs.main.show_levels(LevelSelect.page_of(maxi(0, Content.level_index(mission_id))))
		if win:
			var nx: Variant = Content.next_level(mission_id)
			if nx != null:
				var next: Dictionary = nx
				buttons.append(
					[
						"Thử thách tiếp ›",
						func() -> void:
							gs.main.play_mission(next),
						true,
					]
				)
			else:
				reason_text += " Đã thắng mọi thử thách!"
			buttons.append(["Chọn thử thách", back, false])
		else:
			var c2 := gs.ctx.duplicate()
			var retry := func() -> void:
				var m: Dictionary = Content.level(mission_id)
				gs.main.start_game(Game.new_game(m), c2)
			buttons.append(["Đánh lại", retry, true])
			buttons.append(["Chọn thử thách", back, false])
	elif duel:
		var c3 := gs.ctx.duplicate()
		buttons.append(
			[
				"Chơi lại",
				func() -> void:
					gs.main.start_game(Game.new_game(gs._def_for(c3)), c3),
				true,
			]
		)
		buttons.append(["Về menu", gs.main.show_title, false])
	else:
		buttons.append(["Ván mới", gs.main.show_skirmish, true])
		buttons.append(["Menu", gs.main.show_title, false])
	gs.cards.show_end(win, reason_text, buttons, star_goals if win else [], best_before, stars)
	if gs.main.flags.has("shots"):
		gs.get_tree().create_timer(1.5).timeout.connect(
			func() -> void:
				var tag: String = gs.main.flags.get("tag", "s")
				gs.main.shot(tag + "_end"),
		)
