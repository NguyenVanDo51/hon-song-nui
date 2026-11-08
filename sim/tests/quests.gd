extends "res://sim/tests/test_base.gd"
## quest suite: Quests (data, progress from Game events), Stars.final

const TUT := ["t01", "t02", "t03"]

var _rng: RandomNumberGenerator

func _def(quests: Array) -> Dictionary:
	return { "quests": quests }

func _q(verb: String, what: Variant = null) -> Dictionary:
	return { "do": verb, "what": what }

## the win card's goal rows hold `text`
func _card_has(s: Dictionary, def: Dictionary, text: String) -> bool:
	var v := VBoxContainer.new()
	HudWidgets.end_stars(v, Stars.check(s, def), 0, Stars.final(s, def))
	var found := _labels(v).any(
		func(t: String) -> bool:
			return t.contains(text),
	)
	v.free()
	return found

func _labels(n: Node) -> Array[String]:
	var out: Array[String] = []
	var lb := n as Label
	if lb != null:
		out.append(lb.text)
	for c: Node in n.get_children():
		out.append_array(_labels(c))
	return out

func quest_tests() -> void:
	run(
		"quests: for_level adds the DEBUT of newUnits",
		func() -> void:
			var qs := Quests.for_level(mission("m02"))
			check(
				qs.any(
					func(q: Dictionary) -> bool:
						return q.do == "attack_with" and q.what == "archer",
				),
				"m02 attack_with archer",
			)
			check(
				not qs.any(
					func(q: Dictionary) -> bool:
						return q.do == "win",
				),
				"no win line",
			)
			# enemy-only new unit -> kill_type
			var def := {
				"newUnits": ["elephant"],
				"units": [["p", "hero", 0, 0], ["e", "elephant", 3, 3]],
				"allowed": { "p": ["soldier"], "e": ["elephant"] },
			}
			var q2 := Quests.for_level(def)
			eq(q2.size(), 1, "one quest")
			eq(q2[0].do, "kill_type", "enemy-only -> kill_type")
			eq(q2[0].what, "elephant", "what")
			def.tutorial = []
			eq(Quests.for_level(def).size(), 0, "tutorial level: no DEBUT")
			# dup of a manual quest skipped
			var def3 := { "quests": [_q("attack_with", "archer")], "newUnits": ["archer"], "allowed": { "p": ["archer"] } }
			eq(Quests.for_level(def3).size(), 1, "duplicate skipped")
			eq(Quests.for_level(def3)[0].have, 0, "have 0"),
	)
	run(
		"quests: observe credits only side p",
		func() -> void:
			var s := blank([["p", "archer", 1, 1], ["e", "soldier", 1, 3], ["e", "archer", 4, 4]])
			Quests.init_state(s, _def([_q("attack_with", "archer")]))
			var ev := Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
			eq(Quests.observe(s, ev), [0], "p archer hit")
			eq(Quests.done_count(s), 1, "done")
			var s2 := blank([["e", "archer", 1, 1], ["p", "soldier", 1, 3]])
			Quests.init_state(s2, _def([_q("attack_with", "archer")]))
			s2.side = "e"
			var ev2 := Game.do_action(s2, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
			eq(Quests.observe(s2, ev2), [], "e archer hit")
			eq(Quests.done_count(s2), 0, "not done"),
	)
	run(
		"quests: kill by counter-attack credits p",
		func() -> void:
			var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 2, 1, 1]])
			Quests.init_state(s, _def([_q("kill_with"), _q("kill_type", "soldier")]))
			Game.fixed_roll = Game.ROLL_TOP
			s.side = "e"
			var ev := Game.do_action(s, { "id": 2, "to": [2, 1], "kind": "attack", "target": 1 })
			check(
				ev.any(
					func(e: Dictionary) -> bool:
						return e.t == "die",
				),
				"e soldier died to the counter",
			)
			eq(Quests.observe(s, ev), [0, 1], "both kill quests"),
	)
	run(
		"quests: heal in enemy end_turn credits p",
		func() -> void:
			var s := blank([["p", "soldier", 2, 2, 50]])
			s.tiles[2][2] = "v"
			s.owner[Vector2i(2, 2)] = "p"
			Quests.init_state(s, _def([_q("heal_on", "v"), _q("heal_on", "c")]))
			var ev := Game.end_turn(s)
			ev.append_array(Game.end_turn(s))
			check(
				ev.any(
					func(e: Dictionary) -> bool:
						return e.t == "heal",
				),
				"heal event",
			)
			eq(Quests.observe(s, ev), [0], "heal_on v only"),
	)
	run(
		"quests: move / stand_on / capture / hit_type",
		func() -> void:
			var s := blank([["p", "hero", 1, 1]])
			s.tiles[3][1] = "v"
			Quests.init_state(s, _def([_q("move", "hero"), _q("stand_on", "v"), _q("capture", "v"), _q("capture", "c"), _q("move", "archer")]))
			var ev := Game.do_action(s, { "id": 1, "to": [1, 3], "kind": "capture" })
			eq(Quests.observe(s, ev), [0, 1, 2], "move + stand_on + capture")
			var s2 := blank([["p", "soldier", 1, 1], ["e", "soldier", 1, 2, 1], ["e", "archer", 4, 4]])
			Quests.init_state(s2, _def([_q("hit_type", "archer"), _q("hit_type", "soldier"), _q("kill_type", "soldier")]))
			var ev2 := Game.do_action(s2, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
			eq(Quests.observe(s2, ev2), [1, 2], "hit_type of a victim that died + kill_type"),
	)
	run(
		"quests: note completes UI verbs",
		func() -> void:
			var s := blank([])
			Quests.init_state(s, _def([_q("buy", "archer"), _q("select", "hero"), _q("end_turn")]))
			eq(Quests.note(s, "buy", "soldier"), [], "wrong type")
			eq(Quests.note(s, "buy", "archer"), [0], "right type")
			eq(Quests.note(s, "select", "hero"), [1], "select")
			eq(Quests.note(s, "end_turn", null), [2], "end_turn")
			eq(Quests.done_count(s), 3, "done")
			eq(Quests.total(s), 3, "total"),
	)
	run(
		"quests: text",
		func() -> void:
			eq(Quests.text(_q("attack_with", "archer")), "Đánh bằng Cung thủ", "attack_with")
			eq(Quests.text(_q("buy")), "Mua 1 quân", "buy any")
			eq(Quests.text(_q("capture", "v")), "Chiếm 1 Làng", "capture")
			eq(Quests.text({ "do": "move", "what": null, "text": "X" }), "X", "override")
			eq(Quests.text(_q("move", "hero")), "Đi Tướng", "our commander")
			eq(Quests.text(_q("hit_type", "hero")), "Đánh tướng địch", "hit_type hero = theirs")
			eq(Quests.text(_q("kill_type", "hero")), "Hạ 1 tướng địch", "kill_type hero = theirs")
			eq(Quests.text(_q("kill_type", "soldier")), "Hạ 1 Vệ binh", "kill_type troop"),
	)
	run(
		"quests: feasible",
		func() -> void:
			var m := mission("m02")
			eq(Quests.feasible(m, _q("attack_with", "archer")), "", "archer ok")
			check(Quests.feasible(m, _q("attack_with", "elephant")) != "", "no elephant")
			check(Quests.feasible(m, _q("repair")) != "", "no ruin")
			eq(Quests.feasible(m, _q("capture", "c")), "", "capture c")
			check(Quests.feasible(m, _q("zzz")) != "", "unknown verb"),
	)
	run(
		"quests: every campaign level's quests are doable",
		func() -> void:
			for def: Dictionary in Content.levels():
				for q: Dictionary in Quests.for_level(def):
					eq(Quests.feasible(def, q), "", "%s %s" % [def.id, q.do]),
	)
	run(
		"quests: Stars.final",
		func() -> void:
			var s := blank([])
			s.winner = "p"
			s.turn = 3
			s.heroDeaths = { "p": 0 }
			s.lost = { "p": 0 }
			var def := { "stars": { "turns": 5 } }
			eq(Stars.count(s, def), 3, "base 3")
			eq(Stars.final(s, def), 3, "no quests key")
			s.quests = [{ "do": "move", "what": null, "n": 1, "have": 0, "done": false }]
			eq(Stars.final(s, def), 2, "3 -> 2")
			eq(Stars.count(s, def), 3, "count ignores penalty goal")
			s.turn = 99
			s.heroDeaths = { "p": 1 }
			eq(Stars.count(s, def), 1, "base 1")
			eq(Stars.final(s, def), 1, "floor 1")
			var goals := Stars.check(s, def)
			eq(goals.size(), 4, "4th goal")
			eq(goals[3].key, "quests", "key")
			eq(goals[3].text, "Nhiệm vụ 0/1", "text")
			var qs: Array = s.quests
			var q0: Dictionary = qs[0]
			q0.done = true
			eq(Stars.final(s, def), 1, "all done, base 1")
			s.winner = "e"
			eq(Stars.final(s, def), 0, "not won"),
	)
	run(
		"quests: old save without quests key",
		func() -> void:
			var s := blank([])
			check(not s.has("quests"), "no key")
			eq(Quests.done_count(s), 0, "done 0")
			eq(Quests.total(s), 0, "total 0")
			eq(Quests.observe(s, [{ "t": "hit" }]), [], "observe no-op")
			eq(Quests.note(s, "buy", "archer"), [], "note no-op"),
	)
	run(
		"quests: a save from before quests resumed mid-level gets none (no surprise -1 star)",
		func() -> void:
			var def := mission("m01")
			var s0 := Game.new_game(def)
			check(Quests.fresh(s0, def), "new game is fresh")
			Quests.on_open(s0, def)
			eq(Quests.total(s0), Quests.for_level(def).size(), "new game: the level's quests")
			var s := Game.new_game(def)
			var own: Dictionary = s.owner
			var rows: Array = s.tiles
			for y in rows.size():
				var row: Array = rows[y]
				for x in row.size():
					if row[x] == "v":
						own[Vector2i(x, y)] = "p"
			s.turn = 3
			s.erase("quests")
			Quests.on_open(s, def)
			eq(Quests.total(s), 0, "mid-level old save: no quests")
			s.winner = "p"
			eq(Stars.count(s, def), 3, "base 3")
			eq(Stars.final(s, def), Stars.count(s, def), "no penalty")
			Quests.init_state(s, def) # what the old path did: capture v can no longer happen
			eq(Stars.final(s, def), 2, "old path: -1 star")
			var s1 := Game.new_game(def)
			unit(s1, 0).acted = true
			check(not Quests.fresh(s1, def), "turn 1, a unit acted: not fresh")
			var s2 := Game.new_game(def)
			s2.nextId += 1
			check(not Quests.fresh(s2, def), "turn 1, a unit bought: not fresh")
			var s3 := Game.new_game(def)
			s3.side = "e"
			check(not Quests.fresh(s3, def), "enemy's turn 1: not fresh")
			Quests.on_open(s0, def)
			eq(Quests.total(s0), Quests.for_level(def).size(), "a save with quests keeps them")
			for d: Dictionary in Content.levels(): # a level spawning extra units at start would lose its quests
				check(Quests.fresh(Game.new_game(d), d), "%s: new game is fresh" % d.id),
	)
	run(
		"quests: win card shows -1 star only when the open quest took one",
		func() -> void:
			var s := blank([])
			s.winner = "p"
			s.turn = 99
			s.heroDeaths = { "p": 1 }
			s.lost = { "p": 0 }
			s.quests = [{ "do": "move", "what": null, "n": 1, "have": 0, "done": false }]
			var def := { "stars": { "turns": 5 } }
			var pen := Content.text("star_penalty")
			check(not _card_has(s, def, pen), "base 1 + open quest: floor, no -1 star line")
			s.turn = 3
			s.heroDeaths = { "p": 0 }
			check(_card_has(s, def, pen), "base 3 + open quest: -1 star line"),
	)

## hand quests + tutorial levels t01 / t02 (spec §6.4, §7)
func quest_content_tests() -> void:
	run(
		"quest content: hand quests on m01–m04 / m10",
		func() -> void:
			var want := {
				"m01": [["move", "hero"], ["capture", "v"], ["attack_with", "soldier"], ["kill_with", null]],
				"m02": [["buy", "archer"], ["capture", "c"]],
				"m03": [["heal_on", "v"]],
				"m04": [["buy", "drum"], ["hit_type", "hero"]],
				"m10": [["repair", null]],
			}
			for id: String in want:
				eq(_pairs(_lv(id)), want[id], id)
			eq(_lv("m01").get("newUnits"), [], "m01 debut moved to t01 / t02"),
	)
	run(
		"quest content: tutorial levels t01 t02 t03 exist, first in order",
		func() -> void:
			var ids: Array = Content.levels().map(
				func(m: Dictionary) -> String:
					return m.id,
			)
			eq(ids.slice(0, 4), ["t01", "t02", "t03", "m01"], "t01–t03 before m01")
			for id: String in TUT:
				var d := _lv(id)
				eq(Stars.check_def(d), "", id + " stars")
				eq(d.get("tier"), "easy", id + " tier")
				eq(d.get("ai", "normal"), "normal", id + " ai")
				check(d.has("tutorial") and d.has("quests"), id + " tutorial + quests")
				var al: Dictionary = d.get("allowed", { })
				eq(al.get("e"), [], id + " enemy cannot buy")
				for u: Array in d.get("units", []):
					var ut: String = u[1]
					check(ut in ["hero", "soldier"], id + " hero + soldier only (no archer yet)")
				for w: Dictionary in d.get("waves", []):
					for wu: Array in w.units:
						eq(wu[0], "soldier", id + " wave soldiers only")
				var buys: Array = al.get("p", [])
				check(
					buys.all(
						func(x: String) -> bool:
							return x == "soldier",
					),
					id + " buys soldiers only",
				)
			var wt := ["rout", "castles", "castles"]
			for i in TUT.size():
				var tid: String = TUT[i]
				var w: Dictionary = _lv(tid).get("win", { })
				eq(w.get("type"), wt[i], tid + " win")
			var m1: Dictionary = _lv("t01").get("map", { })
			var rows1: Array = m1.get("rows", [])
			var built := rows1.any(
				func(r: String) -> bool:
					return r.contains("v") or r.contains("c"),
			)
			check(not built, "t01: no village / castle yet")
			var q1 := [
				["select", "hero"],
				["move", "hero"],
				["move", "soldier"],
				["end_turn", null],
				["attack_with", "hero"],
				["kill_with", "soldier"],
			]
			eq(_pairs(_lv("t01")), q1, "t01 quests")
			eq(_pairs(_lv("t02")), [["stand_on", "f"], ["kill_with", null]], "t02 quests")
			var q3 := [["stand_on", "v"], ["buy", "soldier"], ["capture", "v"], ["end_turn", null], ["heal_on", "v"]]
			eq(_pairs(_lv("t03")), q3, "t03 quests"),
	)
	run(
		"quest content: tutorial steps valid (q, point in allow, tiles on map, cards)",
		func() -> void:
			for def: Dictionary in Content.levels():
				if def.has("tutorial"):
					_check_steps(def)
			for id: String in TUT:
				var s0: Array = _lv(id).get("tutorial", [])
				var first: Dictionary = s0[0] if s0.size() else { }
				check(first.has("card"), id + " opens on a card (goal)")
				var last: Dictionary = s0[s0.size() - 1] if s0.size() else { }
				eq(last.get("card"), "Tự chỉ huy", id + " ends handing control over"),
	)
	run(
		"quest content: old progress keeps everything up to m05 + next open",
		func() -> void:
			Store.use_profile("unit_tests")
			Store.set_v("campaign_done", ["m05"])
			var open := Store.unlocked_index()
			for id: String in ["t01", "t02", "m01", "m02", "m03", "m04", "m05"]:
				var i := Content.level_index(id)
				check(i >= 0 and i <= open, id + " open") # level_select: locked = i > open
			var nx: Dictionary = Content.next_level("m05")
			var nid: String = nx.id
			eq(Content.level_index(nid), open, "level after m05 = the one open level not won")
			Store.set_v("campaign_done", []),
	)
	run(
		"quest content: t01 steps walk through on the real map, then the player wins",
		func() -> void:
			for sd: int in 8:
				_walk_t01(sd),
	)
	run(
		"quest content: t02 forest step, then the scripted push takes the castle",
		func() -> void:
			for sd: int in 8:
				_walk_t02(sd),
	)
	run(
		"quest content: t03 steps walk through (buy, village, heal), enemy wave comes",
		func() -> void:
			for sd: int in 8:
				_walk_t03(sd),
	)

func _lv(id: String) -> Dictionary:
	var d: Variant = Content.level(id)
	return d if d != null else { }

## [[do, what], ...] of a level's hand quests
func _pairs(def: Dictionary) -> Array:
	var qs: Array = def.get("quests", [])
	return qs.map(
		func(q: Dictionary) -> Array:
			return [q.do, q.get("what")],
	)

func _side(s: Dictionary, side: String) -> Array:
	var units: Array = s.units
	return units.filter(
		func(u: Dictionary) -> bool:
			return u.side == side,
	)

func _step(def: Dictionary, i: int) -> Dictionary:
	var steps: Array = def.get("tutorial", [])
	return steps[i] if i < steps.size() else { "point": [-1, -1], "allow": [] }

func _tile(st: Dictionary) -> Array:
	var p: Variant = st.get("point")
	return p if p is Array else [-1, -1]

func _allows(st: Dictionary, u: Dictionary) -> bool:
	var allow: Array = st.get("allow", [])
	return allow.has([u.x, u.y])

func _check_steps(def: Dictionary) -> void:
	var steps: Array = def.tutorial
	var qs: Array = def.get("quests", [])
	var rows: Array = def.map.rows
	var row0: String = rows[0]
	var id: String = def.id
	var last_q := -1
	check(steps.size() > 0, id + " steps")
	var on_map := func(a: Variant) -> bool:
		if not (a is Array):
			return false
		var t: Array = a
		var tx: int = t[0]
		var ty: int = t[1]
		return t.size() == 2 and tx >= 0 and ty >= 0 and ty < rows.size() and tx < row0.length()
	for i in steps.size():
		var st: Dictionary = steps[i]
		var tag := "%s step %d" % [id, i + 1]
		var say: String = st.get("say", "")
		check(say.length() > 0, tag + " say")
		if st.has("card"):
			var title: String = st.card
			check(title.length() > 0 and not st.has("q") and not st.has("allow"), tag + " card: title, no q / allow")
			var cp: Variant = st.get("point")
			var cp_ok: bool = cp == null or (cp is String and cp == "end_turn") or on_map.call(cp)
			check(cp_ok, tag + " card point")
			continue
		var q: int = st.get("q", -1)
		check(q >= 0 and q < qs.size(), tag + " q index")
		check(q >= last_q, tag + " q order")
		last_q = q
		var allow: Array = st.get("allow", [])
		check(allow.has(st.get("point")), tag + " point in allow")
		for a: Variant in allow:
			if a is Array:
				var a_ok: bool = on_map.call(a)
				check(a_ok, tag + " tile on map")
			else:
				var tok: String = a
				var buy_ok: bool = tok.begins_with("buy:") and Quests.feasible(def, { "do": "buy", "what": tok.substr(4) }) == ""
				check(tok == "end_turn" or buy_ok, tag + " token " + tok)
	check(last_q >= 0 and last_q < qs.size(), id + " steps cover the quests in order (later ones = free play)")

## enemy side plays its turn with the real bot, then hands back; returns the events of the hand-back
func _ai_turn(s: Dictionary) -> Array:
	var mem := { }
	var out := []
	for i in 200:
		if s.winner != null or s.side != "e":
			break
		var st: Variant = AI.next_step(s, mem)
		if st == null:
			out.append_array(Game.end_turn(s))
			break
		var step: Dictionary = st
		AI.apply_step(s, step)
	return out

func _spots(s: Dictionary) -> Array:
	return _side(s, "e").map(
		func(u: Dictionary) -> Array:
			return [u.x, u.y],
	)

## the side to move plays its whole turn with the real bot, then hands over; returns every event
func _bot_turn(s: Dictionary) -> Array:
	var mem := { }
	var side: String = s.side
	var out := []
	for i in 200:
		if s.winner != null or s.side != side:
			break
		var st: Variant = AI.next_step(s, mem)
		if st == null:
			out.append_array(Game.end_turn(s))
			break
		var step: Dictionary = st
		out.append_array(AI.apply_step(s, step))
	return out

func _at(s: Dictionary, t: Array) -> Dictionary:
	var tx: int = t[0]
	var ty: int = t[1]
	var u: Variant = Game.unit_at(s, tx, ty)
	return u if u != null else { }

func _first(s: Dictionary, side: String, type: String) -> Dictionary:
	for u: Dictionary in _side(s, side):
		if u.type == type:
			return u
	return { }

## u moves to `to` (in its reach, as the guide allows) and does kind; the events are fed to the quests
func _go(s: Dictionary, u: Dictionary, to: Array, kind: String, tag: String) -> Array:
	var tx: int = to[0]
	var ty: int = to[1]
	check(Game.reachable(s, u).has(Vector2i(tx, ty)), "%s: %s reaches %s" % [tag, u.type, to])
	var ev := Game.do_action(s, { "id": u.id, "to": to, "kind": kind })
	Quests.observe(s, ev)
	return ev

## u strikes `foe` from the cheapest free tile next to it that u reaches (the UI's auto tile does the same)
func _strike(s: Dictionary, u: Dictionary, foe: Dictionary, tag: String) -> Array:
	var reach := Game.reachable(s, u)
	var best: Variant = null
	var best_c := INF
	for k: Vector2i in reach:
		var fx: int = foe.x
		var fy: int = foe.y
		var r: Dictionary = reach[k]
		var c: float = r.cost
		if Game.dist(k.x, k.y, fx, fy) == 1 and c < best_c:
			best = [k.x, k.y]
			best_c = c
	check(best != null, "%s: %s reaches %s" % [tag, u.type, [foe.x, foe.y]])
	if best == null:
		return []
	var ev := Game.do_action(s, { "id": u.id, "to": best, "kind": "attack", "target": foe.id })
	Quests.observe(s, ev)
	return ev

## both sides on the bot until someone wins or round `last` ends
func _finish(s: Dictionary, last: int) -> void:
	for i in 80:
		if s.winner != null or s.turn > last:
			return
		_bot_turn(s)

## AI rng seeded by sd (the generator lives in _rng: a Callable on a freed one is null)
func _seed(sd: int) -> Callable:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 7 + sd * 131
	var old: Callable = AI.rng
	AI.rng = _rng.randf
	return old

## t01: move both (steps 2–5), Hết lượt -> wave on the pointed tiles, hero hits A, soldier finishes A, bot plays the rest
func _walk_t01(sd: int) -> void:
	var def := _lv("t01")
	var old := _seed(sd)
	var s := Game.new_game(def)
	s.rng = 1000 + sd * 7919
	Quests.init_state(s, def)
	var tag := "t01 seed %d" % sd
	var hero := _first(s, "p", "hero")
	var sol := _first(s, "p", "soldier")
	eq(_side(s, "e").size(), 0, tag + ": no enemy before the move lesson")
	eq(_tile(_step(def, 1)), [hero.x, hero.y], tag + ": select step points at the hero")
	Quests.note(s, "select", "hero")
	check(_allows(_step(def, 2), hero), tag + ": hero clickable at the move step")
	_go(s, hero, _tile(_step(def, 2)), "wait", tag)
	eq(_step(def, 3).get("point"), [hero.x, hero.y], tag + ": grey card points at the moved hero")
	check(_allows(_step(def, 4), sol), tag + ": soldier clickable at its move step")
	_go(s, sol, _tile(_step(def, 4)), "wait", tag)
	Quests.note(s, "end_turn", null)
	eq(Quests.done_count(s), 4, tag + ": select, 2 moves, end turn")
	Game.end_turn(s)
	_ai_turn(s)
	eq(s.side, "p", tag + ": back to us")
	var a := _at(s, _tile(_step(def, 7)))
	check(not a.is_empty() and str(a.get("side")) == "e", tag + ": wave enemy on the attack step's point")
	eq(_step(def, 6).get("point"), _tile(_step(def, 7)), tag + ": 'Địch tới' card on the same enemy")
	eq(_side(s, "e").size(), 2, tag + ": 2 enemies arrived")
	if a.is_empty():
		AI.rng = old
		return
	_strike(s, hero, a, tag)
	eq(Quests.done_count(s), 5, tag + ": hero attacked")
	var a_hp: int = a.hp
	check(a_hp > 0 and a_hp <= 35, tag + ": A hurt, alive (%d)" % a_hp)
	_strike(s, sol, a, tag)
	eq(Quests.done_count(s), 6, tag + ": soldier finished A")
	var aid: int = a.id
	eq(Game.unit_by_id(s, aid), null, tag + ": A dead")
	Game.end_turn(s)
	_finish(s, 12)
	eq(s.winner, "p", tag + ": the rest is won (bot plays us)")
	AI.rng = old

## t02: soldier into the forest (guide), then the bot plays us: castle guard falls, hero takes the castle
func _walk_t02(sd: int) -> void:
	var def := _lv("t02")
	var old := _seed(sd)
	var s := Game.new_game(def)
	s.rng = 1000 + sd * 7919
	Quests.init_state(s, def)
	var tag := "t02 seed %d" % sd
	var castle := _tile(_step(def, 0))
	var cx: int = castle[0]
	var cy: int = castle[1]
	eq(Game.tile_at(s, cx, cy), "c", tag + ": goal card on the castle")
	var own: Dictionary = s.owner
	eq(own.get(Vector2i(cx, cy)), "e", tag + ": enemy castle")
	check(not _at(s, castle).is_empty(), tag + ": a guard stands on it")
	var f := _tile(_step(def, 3))
	var fx: int = f[0]
	var fy: int = f[1]
	eq(Game.tile_at(s, fx, fy), "f", tag + ": forest step on a forest")
	var sol: Dictionary = { }
	for u: Dictionary in _side(s, "p"):
		if u.type == "soldier" and _allows(_step(def, 3), u):
			sol = u
	check(not sol.is_empty(), tag + ": a soldier is clickable at the forest step")
	if sol.is_empty():
		AI.rng = old
		return
	_go(s, sol, f, "wait", tag)
	eq(Quests.done_count(s), 1, tag + ": stand_on f")
	_finish(s, 14)
	eq(s.winner, "p", tag + ": the bot playing us wins")
	eq(s.get("reason"), "castlesLost", tag + ": by taking the castle")
	AI.rng = old

## t03: hurt soldier to our village, buy on our castle, the new soldier takes a village, Hết lượt, heal; then the bot
func _walk_t03(sd: int) -> void:
	var def := _lv("t03")
	var old := _seed(sd)
	var s := Game.new_game(def)
	s.rng = 1000 + sd * 7919
	Quests.init_state(s, def)
	var tag := "t03 seed %d" % sd
	var own: Dictionary = s.owner
	var hurt := _first(s, "p", "soldier")
	var hurt_hp: int = hurt.hp
	check(_allows(_step(def, 1), hurt) and hurt_hp < 100, tag + ": the hurt soldier is clickable at the heal step")
	var hv := _tile(_step(def, 1))
	var hx: int = hv[0]
	var hy: int = hv[1]
	eq(own.get(Vector2i(hx, hy)), "p", tag + ": our village (heals)")
	_go(s, hurt, hv, "wait", tag)
	eq(Quests.done_count(s), 1, tag + ": stand_on v")
	var c := _tile(_step(def, 3))
	var cx: int = c[0]
	var cy: int = c[1]
	check(Game.sells(Game.tile_at(s, cx, cy)), tag + ": buy step on a castle")
	eq(own.get(Vector2i(cx, cy)), "p", tag + ": our castle")
	eq(_step(def, 2).get("point"), c, tag + ": castle card on it")
	var nu: Variant = Game.buy(s, cx, cy, "soldier")
	check(nu != null, tag + ": buy soldier")
	if nu == null:
		AI.rng = old
		return
	Quests.note(s, "buy", "soldier")
	var fresh: Dictionary = nu
	var did: bool = fresh.acted
	check(not did, tag + ": the bought soldier acts this turn (AE2)")
	check(_allows(_step(def, 4), fresh), tag + ": bought soldier clickable at the village step")
	var v := _tile(_step(def, 4))
	var vx: int = v[0]
	var vy: int = v[1]
	eq(Game.tile_at(s, vx, vy), "v", tag + ": village step on a village")
	_go(s, fresh, v, "capture", tag)
	eq(Quests.done_count(s), 3, tag + ": capture v")
	Quests.note(s, "end_turn", null)
	var ev := Game.end_turn(s)
	ev.append_array(_ai_turn(s))
	Quests.observe(s, ev)
	eq(Quests.done_count(s), 5, tag + ": all quests done")
	eq(hurt.hp, 60, tag + ": +20 on the village")
	var gold: Dictionary = s.gold
	var g: int = gold.p
	check(g >= Rules.UNITS.soldier.cost, tag + ": gold for one more soldier on turn 2 (%d)" % g)
	_finish(s, 2)
	var w0: Dictionary = s.waves[0]
	var came: bool = w0.done
	check(came, tag + ": the wave came on turn 2")
	_finish(s, 16)
	eq(s.winner, "p", tag + ": the bot playing us wins")
	AI.rng = old
