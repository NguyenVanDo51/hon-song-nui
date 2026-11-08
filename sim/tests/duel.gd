extends "res://sim/tests/test_base.gd"
## duel tests (run by sim/tests.gd)

func duel_tests() -> void:
	run(
		"ctrl missing = old behavior: p human, e AI normal, AI mem untouched",
		func() -> void:
			var hp: String = Content.heroes_of("p")[0]
			for def: Dictionary in [mission("m01"), Content.skirmish_def("dong_bang", hp, true)]:
				var s := Game.new_game(def)
				check(not s.has("ctrl"), "%s: no ctrl key in state" % def.id)
				eq(Content.ctrl_of(s, "p"), "human")
				eq(Content.ctrl_of(s, "e"), "ai:normal")
				check(not Content.is_ai(s, "p") and Content.is_ai(s, "e"), "p human, e AI")
				eq(Content.ai_level(s, "e"), "normal")
				check(not s.has("aiParams"), "%s: default AI, no aiParams" % def.id),
	)
	run(
		"duel_def valid on every skirmish map",
		func() -> void:
			for mid: String in Content.SKIRMISH.MAPS:
				for ctrl_e: String in Content.CTRLS:
					var def := duel(mid, ctrl_e)
					var s := Game.new_game(def)
					eq(s.ctrl, { "p": "human", "e": ctrl_e }, mid)
					eq(Content.is_ai(s, "e"), ctrl_e != "human", mid + " " + ctrl_e)
					eq(Content.ai_level(s, "e"), ctrl_e.substr(3) if ctrl_e != "human" else "", mid + " level")
					eq(s.heroKey, { "p": Content.heroes_of("p")[0], "e": Content.heroes_of("e")[0] }, mid + " commanders")
					eq(s.gold.p, s.gold.e, mid + " same gold")
					eq(Objectives.check(s), "", mid + " win spec")
					for side: String in ["p", "e"]:
						check(Game.castles(s, side) > 0, "%s: %s has a castle" % [mid, side])
						check(
							units_of(s).any(
								func(u: Dictionary) -> bool:
									return u.side == side and u.type == "hero",
							),
							"%s: %s commander" % [mid, side],
						)
					check(not def.has("skirmish") and str(def.id).begins_with("duel:"), mid + " is a duel, not a skirmish")
			var hard := Game.new_game(duel("dong_bang", "ai:hard"))
			eq(hard.aiParams, { "e": AI.PRESETS.hard }, "hard: tuned knobs stored in state")
			eq(AI.params(hard, "e").kill_hero, AI.PRESETS.hard.kill_hero, "AI reads the preset")
			eq(AI.params(hard, "p"), AI.DEFAULT, "human side untouched")
			check(not Game.new_game(duel("dong_bang", "ai:normal")).has("aiParams"), "normal = built-in AI")
			check(not Game.new_game(duel("dong_bang", "human")).has("aiParams"), "2 humans: no AI params")
			var easy := Game.new_game(duel("dong_bang", "ai:easy"))
			eq(AI.params(easy, "e").noise, 60.0, "easy: noisy picks")
			var back: Dictionary = str_to_var(var_to_str(hard))
			eq(back.aiParams, hard.aiParams, "save text keeps aiParams"),
	)
	run(
		"2 humans: full game by do_action on both sides, step-replayable",
		func() -> void:
			var s := Game.new_game(duel("dong_bang", "human"))
			var s0: Dictionary = s.duplicate(true)
			var steps := []
			var moves := { "p": 0, "e": 0 }
			AI.seed_game(7)
			while s.winner == null and s.turn <= 60:
				var mem := { }
				var side: String = s.side
				check(not Content.is_ai(s, side), "side to move is human")
				for i in 80: # AI only picks the moves; they go in like a player's clicks
					var step: Variant = AI.next_step(s, mem)
					if step == null or s.winner != null:
						break
					var sd: Dictionary = step
					if sd.kind == "buy":
						var bx: int = sd.x
						var by: int = sd.y
						var bt: String = sd.type
						check(Game.buy(s, bx, by, bt) != null, "buy ok")
					else:
						var act: Dictionary = sd.act
						Game.do_action(s, act)
						moves[side] += 1
					steps.append(sd)
				if s.winner == null:
					Game.end_turn(s)
					steps.append({ "kind": "end" })
			check(s.winner != null, "someone won (turn %d)" % s.turn)
			var both: bool = moves.p > 0 and moves.e > 0
			check(both, "both sides acted %s" % [moves])
			eq(s.ctrl, { "p": "human", "e": "human" }, "ctrl kept")
			# same start + same steps = same game (online relay)
			for sd: Dictionary in steps:
				if sd.kind == "end":
					Game.end_turn(s0)
				else:
					AI.apply_step(s0, sd)
			eq(var_to_str(s0), var_to_str(s), "replay matches"),
	)
	run(
		"ai:army (UI Khó) = hard v5 preset; ai:hard (UI Siêu khó) = v3 unchanged",
		func() -> void:
			eq(AI.PRESETS.army, AI.PRESETS.hard.merged(AI.V5_ARMY), "army = hard + V5_ARMY")
			var army := Game.new_game(duel("dong_bang", "ai:army"))
			eq(army.aiParams, { "e": AI.PRESETS.army }, "army stored in state")
			eq(Content.ai_level(army, "e"), "army")
			eq(AI.params(army, "e").mix_w, 1.0, "AI reads the army knobs")
			eq(Game.new_game(duel("dong_bang", "ai:hard")).aiParams, { "e": AI.PRESETS.hard }, "hard unchanged")
			check(Content.save_fits({ "state": army, "ctx": duel_ctx("dong_bang", "ai:army") }), "ai:army save fits"),
	)
	run(
		"ai:army vs normal: whole game to a winner, legal steps",
		func() -> void:
			var s := Game.new_game(duel("dong_bang", "ai:army"))
			s.seed = 4242
			s.rng = 4242
			planner_game("dong_bang", 40, s)
			check(s.winner != null, "game ends by turn 40 (turn %d)" % s.turn),
	)
	run(
		"save / load keeps ctrl; bad duel saves refused",
		func() -> void:
			Store.use_profile("unit_tests")
			var s := Game.new_game(duel("cua_bien", "ai:hard"))
			Store.save_game(s, duel_ctx("cua_bien", "ai:hard"), "x")
			var v: Variant = Store.load_game()
			check(v != null, "duel save loads")
			if v != null:
				var vd: Dictionary = v
				var st: Dictionary = vd.state
				eq(st.ctrl, { "p": "human", "e": "ai:hard" })
				var ctx: Dictionary = vd.ctx
				eq(ctx.ctrlE, "ai:hard")
			Store.clear_game()
			var bad := duel_ctx("cua_bien", "human")
			bad.heroE = "nobody"
			check(not Content.save_fits({ "state": s, "ctx": bad }), "unknown Blue commander refused")
			var odd: Dictionary = s.duplicate(true)
			odd.ctrl.e = "ai:godlike"
			check(not Content.save_fits({ "state": odd, "ctx": duel_ctx("cua_bien", "human") }), "unknown controller refused"),
	)
	run(
		"duel / skirmish results never touch campaign progress",
		func() -> void:
			Store.use_profile("unit_tests")
			Store.set_v("campaign_done", [])
			for w: String in ["p", "e"]:
				Store.record_result(duel_ctx("dong_bang", "human"), w)
				Store.record_result(duel_ctx("dong_bang", "ai:easy"), w)
				Store.record_result({ "kind": "skirmish", "hero": Content.heroes_of("p")[0], "easy": true }, w)
			eq(Store.done_list(), [], "no progress from duels / skirmish")
			Store.record_result({ "kind": "campaign", "id": "m01" }, "e")
			eq(Store.done_list(), [], "campaign loss")
			Store.record_result({ "kind": "campaign", "id": "m01" }, "p")
			eq(Store.done_list(), ["m01"], "campaign win counts")
			Store.set_v("campaign_done", [])
			Store.set_v("campaign_stars", { })
			Store.record_result({ "kind": "campaign", "id": "m01" }, "p", 2)
			Store.record_result({ "kind": "campaign", "id": "m01" }, "p", 1)
			eq(Store.stars_of("m01"), 2, "stars keep the best")
			Store.record_result({ "kind": "campaign", "id": "m01" }, "e", 3)
			eq(Store.stars_of("m01"), 2, "a loss never adds stars")
			Store.record_result({ "kind": "skirmish", "id": "m01" }, "p", 3)
			eq(Store.stars_of("m01"), 2, "only campaign games give stars")
			Store.record_result({ "kind": "campaign", "id": "m01" }, "p", 3)
			eq(Store.stars_of("m01"), 3, "a better run raises it")
			Store.set_v("campaign_done", [])
			Store.set_v("campaign_stars", { }),
	)
	run(
		"level ai: hard preset saved in state, normal = built-in",
		func() -> void:
			var m02: Dictionary = Content.level("m02")
			var d := m02.duplicate(true)
			d.ai = "hard"
			var s := Game.new_game(d)
			var aip: Dictionary = s.aiParams
			eq(aip.e, AI.PRESETS.hard)
			eq(Content.ctrl_of(s, "e"), "ai:hard")
			eq(Content.ctrl_of(s, "p"), "human")
			d.ai = "normal"
			check(not Game.new_game(d).has("aiParams"), "normal adds no params"),
	)
	run(
		"old save of a level (ctx carries the dropped story key) still fits the content",
		func() -> void:
			var m05: Dictionary = Content.level("m05")
			var sv := { "state": Game.new_game(m05), "ctx": { "kind": "campaign", "id": "m05", "story": true }, "title": "x" }
			check(Store.fits_content(sv), "m05 save fits")
			var gone := { "state": Game.new_game(m05), "ctx": { "kind": "campaign", "id": "m99" }, "title": "x" }
			check(not Store.fits_content(gone), "unknown level id does not fit"),
	)
	run(
		"level map: opens with no card (next level pulsing); tap = card, Xuất quân starts it; locked level never starts",
		func() -> void:
			Store.use_profile("unit_tests")
			var lv := Content.levels()
			var ids: Array = lv.map(
				func(m: Dictionary) -> String:
					return m.id,
			)
			Store.set_v("campaign_done", [ids[0], ids[2]])
			eq(Store.unlocked_index(), 3, "open up to the furthest win + 1")
			eq(LevelSelect.first_unwon(lv, 3), 3, "level 2 skipped -> still the one after the furthest win")
			var wm := WorldMap.new()
			wm.setup(lv, Store.unlocked_index())
			eq(wm.sel, -1, "no card before a tap")
			eq(wm.next, 3, "next level = after the furthest win")
			eq(wm.focus, 3, "centred on it")
			var got := []
			wm.level_picked.connect(
				func(id: String) -> void:
					got.append(id),
			)
			wm.go()
			eq(got, [], "nothing selected: Xuất quân does nothing")
			wm.select(1)
			eq(got, [], "tap on a node: card only")
			eq(wm.sel, 1)
			wm.go()
			eq(got, [ids[1]], "Xuất quân: start (a skipped level stays open)")
			wm.select(5)
			wm.go()
			eq(got, [ids[1]], "locked level never starts")
			var wm2 := WorldMap.new()
			wm2.setup(lv, Store.unlocked_index(), str(ids[2]))
			eq(wm2.focus, 2, "focus id (back from a level): centred on it")
			eq(wm2.sel, -1, "still no card")
			wm.free()
			wm2.free()
			Store.set_v("campaign_done", []),
	)
	run(
		"level ring: a veteran who won m05 is pointed past it, not back at t01; last level won -> first gap",
		func() -> void:
			Store.use_profile("unit_tests")
			var lv := Content.levels()
			var ids: Array = lv.map(
				func(m: Dictionary) -> String:
					return m.id,
			)
			Store.set_v("campaign_done", ["m01", "m02", "m03", "m04", "m05"])
			var nx: Dictionary = Content.next_level("m05")
			eq(LevelSelect.first_unwon(lv, Store.unlocked_index()), Content.level_index(str(nx.id)), "ring on the level after m05")
			check(LevelSelect.first_unwon(lv, Store.unlocked_index()) != Content.level_index("t01"), "not t01")
			Store.set_v("campaign_done", [ids[ids.size() - 1]])
			eq(LevelSelect.first_unwon(lv, Store.unlocked_index()), 0, "last level won -> first not won")
			Store.set_v("campaign_done", ids)
			eq(LevelSelect.first_unwon(lv, Store.unlocked_index()), ids.size(), "all won -> size")
			Store.set_v("campaign_done", []),
	)
	run(
		"unlock: furthest win opens everything before it",
		func() -> void:
			Store.use_profile("unit_tests")
			var ids: Array = Content.levels().map(
				func(m: Dictionary) -> String:
					return m.id,
			)
			Store.set_v("campaign_done", [])
			eq(Store.unlocked_index(), 0)
			Store.set_v("campaign_done", [ids[3]])
			eq(Store.unlocked_index(), 4)
			Store.set_v("campaign_done", ids)
			eq(Store.unlocked_index(), ids.size())
			Store.set_v("campaign_done", []),
	)
