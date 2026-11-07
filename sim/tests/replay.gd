extends "res://sim/tests/test_base.gd"
## match replay tests (run by sim/tests.gd): recorder off headless, record + replay a whole 1 vs 1 to the same state,
## continue into the same file, line / scenario round-trips, analyzer flags a commander left killable

const ReviewLib := preload("res://sim/review_lib.gd")

func replay_tests() -> void:
	run(
		"headless run: recorder stays off",
		func() -> void:
			var s := Game.new_game(duel("dong_bang", "ai:hard"))
			var ctx := duel_ctx("dong_bang", "ai:hard")
			MatchRec.begin(s, ctx)
			check(not MatchRec.active(), "begin() must not record headless")
			check(not ctx.has("replay"), "ctx untouched")
			MatchRec.step(s, { "kind": "end" }) # inactive: no-op, no error
			MatchRec.finish(s),
	)
	run(
		"line + scenario round-trips",
		func() -> void:
			var rec := { "t": "step", "s": "x\ny\"z\\", "n": 3, "a": [1, [2, -4]], "f": 0.25, "z": null }
			eq(Replay.decode(Replay.encode(rec)), rec, "line")
			check(not Replay.encode(rec).contains("\n"), "one line")
			eq(Replay.decode("{\"t\": \"st"), { }, "cut line (crash) -> {}")
			var dir := _tmp()
			var s := Game.new_game(duel("cua_bien", "ai:hard"))
			var sc := { "format": 1, "replay": "x", "turn": 3, "side": "e", "note": "n", "state": s }
			var p := ReviewLib.save_scenario(dir.path_join("x_t3.scenario"), sc)
			check(p != "", "written")
			var back := ReviewLib.load_scenario(p)
			eq(var_to_str(back), var_to_str(sc), "scenario")
			var bs: Dictionary = back.state
			eq(Replay.state_hash(bs), Replay.state_hash(s), "state hash")
			var woke: Dictionary = s.duplicate(true)
			var u0: Dictionary = unit(woke, 0)
			u0.guard = false # AI.greedy_step wakes guards while choosing (not a step)
			woke.quests = [{ "done": true }]
			eq(Replay.state_hash(woke), Replay.state_hash(s), "guard wake / quests not hashed")
			u0.hp = 1
			check(Replay.state_hash(woke) != Replay.state_hash(s), "hp hashed")
			_rm(dir),
	)
	run(
		"AI choosing a step (guard wake) leaves the hash alone",
		func() -> void:
			var s := blank([["p", "soldier", 2, 2], ["e", "soldier", 3, 3], ["e", "archer", 5, 4]])
			var g: Dictionary = unit(s, 1)
			g.guard = true
			s.side = "e"
			var h0 := Replay.state_hash(s)
			AI.next_step(s, { }) # greedy: wakes the guard (enemy near) before picking
			var woke: bool = not g.get("guard", true)
			check(woke, "guard woken by next_step")
			eq(Replay.state_hash(s), h0, "hash unchanged by thinking"),
	)
	run(
		"1 vs 1 by do_action on both sides: file replays to the same final state",
		func() -> void:
			var dir := _tmp()
			var s := Game.new_game(duel("dong_bang", "human"))
			var ctx := duel_ctx("dong_bang", "human")
			var p := MatchRec.open_in(dir, s, ctx)
			check(p != "" and MatchRec.active(), "opened")
			eq(ctx.get("replay"), p, "ctx keeps the path")
			var n := _play(s, 60, true)
			MatchRec.finish(s)
			check(s.winner != null, "someone won")
			check(not MatchRec.active(), "closed on finish")
			var rep := Replay.load_file(p)
			var head: Dictionary = rep.head
			eq(head.format, Replay.FORMAT, "format")
			eq(head.ai, { "p": "human", "e": "human" }, "controllers")
			var w := ReviewLib.walk(rep)
			eq(w.div, { }, "no divergence")
			eq(w.steps, n, "every applied step recorded once")
			var fin: Dictionary = w.finish
			eq(fin.winner, s.winner, "finish line")
			var final: Dictionary = w.final
			eq(Replay.state_hash(final), Replay.state_hash(s), "final hash")
			eq(var_to_str(final), var_to_str(s), "final state")
			check(not FileAccess.get_file_as_string(p).contains("\"unbuy\""), "refused unbuy not recorded")
			_rm(dir),
	)
	run(
		"continue from a save: same file, resume line, still replays",
		func() -> void:
			var dir := _tmp()
			var s := Game.new_game(duel("cua_bien", "human"))
			var ctx := duel_ctx("cua_bien", "human")
			var p := MatchRec.open_in(dir, s, ctx)
			_play(s, 2, false)
			MatchRec.stop() # game left; the save keeps s + ctx
			var saved: Dictionary = str_to_var(var_to_str({ "state": s, "ctx": ctx }))
			var s2: Dictionary = saved.state
			var ctx2: Dictionary = saved.ctx
			eq(MatchRec.open_in(dir, s2, ctx2), p, "same file")
			_play(s2, 4, false)
			MatchRec.stop()
			var rep := Replay.load_file(p)
			check(FileAccess.get_file_as_string(p).contains("\"t\":\"resume\""), "resume line")
			var w := ReviewLib.walk(rep)
			eq(w.div, { }, "no divergence")
			var final: Dictionary = w.final
			eq(Replay.state_hash(final), Replay.state_hash(s2), "final hash")
			var fresh := Game.new_game(duel("cua_bien", "human"))
			var p3 := MatchRec.open_in(dir, fresh, ctx2) # "play again" copies the old ctx: new file
			check(p3 != p and p3 != "", "new game -> new file")
			MatchRec.stop()
			_rm(dir),
	)
	run(
		"review flags a commander left killable",
		func() -> void:
			var dir := _tmp()
			var s := blank([["p", "hero", 2, 2, 30], ["p", "soldier", 0, 1], ["e", "soldier", 4, 2], ["e", "archer", 4, 4], ["e", "soldier", 2, 4]])
			var ctx := { "kind": "skirmish", "map": "test", "hero": "anhhung", "easy": false }
			var p := MatchRec.open_in(dir, s, ctx)
			var hero_id: int = unit(s, 0).id
			for st: Dictionary in [{ "kind": "act", "act": { "id": hero_id, "to": [2, 2], "kind": "wait" } }, { "kind": "end" }]:
				Replay.apply(s, st)
				MatchRec.step(s, st)
			var mem := { }
			while s.winner == null and s.side == "e":
				var nv: Variant = AI.next_step(s, mem)
				if nv == null:
					break
				var st: Dictionary = nv
				AI.apply_step(s, st)
				MatchRec.step(s, st)
			if s.winner == null:
				Game.end_turn(s)
				MatchRec.step(s, { "kind": "end" })
			MatchRec.finish(s)
			var lib := ReviewLib.new()
			lib.scen_dir = dir
			var r := lib.review(Replay.load_file(p))
			var rp: Dictionary = r.replay
			var ok: bool = rp.verified
			check(ok, "replay verified %s" % rp)
			var tags: Dictionary = r.human_tags
			check(tags.has("hero_killable"), "hero_killable flagged: %s" % tags)
			var hm: Array = r.human_mistakes
			check(hm.size() > 0, "listed as a mistake")
			var tl: Array = r.timeline
			eq(tl.size(), 2, "2 half-turns")
			_rm(dir),
	)

## both sides play AI-picked steps by hand (Game.do_action / buy, like a player's clicks), recorded; returns steps applied
func _play(s: Dictionary, rounds: int, try_unbuy: bool) -> int:
	AI.seed_game(7)
	var n := 0
	while s.winner == null and s.turn <= rounds:
		var mem := { }
		for i in 80:
			var sv: Variant = AI.next_step(s, mem)
			if sv == null or s.winner != null:
				break
			var st: Dictionary = sv
			if st.kind == "buy":
				var bx: int = st.x
				var by: int = st.y
				var bt: String = st.type
				check(Game.buy(s, bx, by, bt) != null, "buy ok")
			else:
				var act: Dictionary = st.act
				Game.do_action(s, act)
			MatchRec.step(s, st)
			n += 1
			if try_unbuy:
				MatchRec.step(s, { "kind": "unbuy", "id": 1 }) # nothing changed: not written
		if s.winner == null:
			Game.end_turn(s)
			MatchRec.step(s, { "kind": "end" })
			n += 1
	return n

func _tmp() -> String:
	var d := "user://tmp_replay_test_%d_%d" % [Time.get_ticks_usec(), randi()]
	DirAccess.make_dir_recursive_absolute(d)
	return d

func _rm(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
