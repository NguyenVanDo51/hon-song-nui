extends "res://sim/tests/test_base.gd"
## quest suite: Quests (data, progress from Game events), Stars.final

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
			eq(Quests.total(s0), Quests.for_level(def).size(), "a save with quests keeps them"),
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
		"quest content: tutorial levels t01 t02 exist, first in order",
		func() -> void:
			var ids: Array = Content.levels().map(
				func(m: Dictionary) -> String:
					return m.id,
			)
			eq(ids.slice(0, 3), ["t01", "t02", "m01"], "t01, t02 before m01")
			for id: String in ["t01", "t02"]:
				var d := _lv(id)
				eq(Stars.check_def(d), "", id + " stars")
				eq(d.get("tier"), "easy", id + " tier")
				eq(d.get("ai", "normal"), "normal", id + " ai")
				check(d.has("tutorial") and d.has("quests"), id + " tutorial + quests")
			var t01 := _lv("t01")
			var t02 := _lv("t02")
			var w1: Dictionary = t01.get("win", { })
			var w2: Dictionary = t02.get("win", { })
			eq(t01.get("newUnits"), ["hero"], "t01 newUnits")
			eq(t02.get("newUnits"), ["soldier"], "t02 newUnits")
			eq(w1.get("type"), "rout", "t01 win")
			eq(w2.get("type"), "castles", "t02 win")
			var q1 := [["select", "hero"], ["capture", "v"], ["end_turn", null], ["stand_on", "f"], ["attack_with", "hero"]]
			eq(_pairs(t01), q1, "t01 quests")
			eq(_pairs(t02), [["buy", "soldier"], ["stand_on", "v"], ["end_turn", null], ["heal_on", "v"]], "t02 quests")
			# t01: our hero only; enemies = low-hp guards
			var units: Array = t01.get("units", [])
			for u: Array in units:
				if u[0] == "p":
					eq(u[1], "hero", "t01 p hero only")
					continue
				var o: Dictionary = u[4] if u.size() > 4 else { }
				var hp: int = o.get("hp", 100)
				var guard: bool = o.get("guard", false)
				check(guard and hp < 100, "t01 e guard + low hp"),
	)
	run(
		"quest content: tutorial steps valid (q, point in allow, tiles on map)",
		func() -> void:
			for def: Dictionary in Content.levels():
				if def.has("tutorial"):
					_check_steps(def)
			var s1: Array = _lv("t01").get("tutorial", [])
			check(s1.size() >= 2, "t01 steps")
			if s1.size() >= 2:
				var a: Dictionary = s1[0]
				var b: Dictionary = s1[1]
				eq(a.get("say"), "Chọn tướng", "t01 step 1 say")
				eq(b.get("say"), "Làng: vàng mỗi lượt, đứng trên thì hồi máu", "t01 village say"),
	)
	run(
		"quest content: t02 has no enemy units and never loses by it",
		func() -> void:
			var t02 := _lv("t02")
			check(not t02.is_empty(), "t02")
			if t02.is_empty():
				return
			var gold: Dictionary = t02.gold
			var allowed: Dictionary = t02.allowed
			var cost: int = Rules.UNITS.soldier.cost
			var gp: int = gold.p
			eq(gold.e, 0, "gold.e 0")
			eq(allowed.e, [], "allowed.e []")
			eq(allowed.p, ["soldier"], "allowed.p soldier")
			check(gp >= cost, "gold for 1 soldier")
			var s := Game.new_game(t02)
			eq(_side(s, "e").size(), 0, "e has 0 units")
			Game.end_turn(s)
			Game.end_turn(s)
			eq(s.winner, null, "nobody lost after 2 end_turns"),
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
		"quest content: t01 steps walk through on the real map",
		func() -> void:
			for sd: int in 8:
				_walk_t01(sd),
	)
	run("quest content: t02 steps walk through on the real map", _walk_t02)

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
	for i in steps.size():
		var st: Dictionary = steps[i]
		var tag := "%s step %d" % [id, i + 1]
		var q: int = st.get("q", -1)
		check(q >= 0 and q < qs.size(), tag + " q index")
		check(q >= last_q, tag + " q order")
		last_q = q
		var allow: Array = st.get("allow", [])
		check(allow.has(st.get("point")), tag + " point in allow")
		for a: Variant in allow:
			if a is Array:
				var t: Array = a
				var tx: int = t[0]
				var ty: int = t[1]
				check(t.size() == 2 and tx >= 0 and ty >= 0 and ty < rows.size() and tx < row0.length(), tag + " tile on map")
			else:
				var tok: String = a
				var buy_ok: bool = tok.begins_with("buy:") and Quests.feasible(def, { "do": "buy", "what": tok.substr(4) }) == ""
				check(tok == "end_turn" or buy_ok, tag + " token " + tok)
		var say: String = st.get("say", "x")
		check(say.length() > 0, tag + " say")
	eq(last_q, qs.size() - 1, id + " every quest has a step")

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

## scripted player follows t01 steps 1–5, the real bot plays the enemy turns (AI rng seeded by sd)
func _walk_t01(sd: int) -> void:
	var def := _lv("t01")
	if def.is_empty():
		check(false, "t01")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + sd * 131
	var old: Callable = AI.rng
	AI.rng = rng.randf
	var s := Game.new_game(def)
	s.rng = 1000 + sd * 7919
	Quests.init_state(s, def)
	var hero: Dictionary = _side(s, "p")[0]
	var tag := "seed %d " % sd
	# 1 select hero
	eq(_tile(_step(def, 0)), [hero.x, hero.y], tag + "step 1 points at the hero")
	Quests.note(s, "select", "hero")
	# 2 capture the village
	check(_allows(_step(def, 1), hero), tag + "hero clickable at step 2")
	Quests.observe(s, Game.do_action(s, { "id": hero.id, "to": _tile(_step(def, 1)), "kind": "capture" }))
	eq(Quests.done_count(s), 2, tag + "capture v")
	# 3 end turn: guards hold
	Quests.note(s, "end_turn", null)
	var e0 := _spots(s)
	Game.end_turn(s)
	_ai_turn(s)
	eq(_spots(s), e0, tag + "guards hold while we take the village")
	eq(Quests.done_count(s), 3, tag + "end_turn")
	# 4 forest; the enemy turn after it: a guard wakes and strikes
	var f := _tile(_step(def, 3))
	var fx: int = f[0]
	var fy: int = f[1]
	eq(Game.tile_at(s, fx, fy), "f", tag + "step 4 point = forest")
	check(_allows(_step(def, 3), hero), tag + "hero clickable at step 4")
	Quests.observe(s, Game.do_action(s, { "id": hero.id, "to": f, "kind": "wait" }))
	eq(Quests.done_count(s), 4, tag + "stand_on f")
	var hp0: int = hero.hp
	Game.end_turn(s)
	_ai_turn(s)
	eq(s.winner, null, tag + "no winner after the enemy turn")
	var hp1: int = hero.hp
	check(hp1 < hp0, tag + "an enemy woke up and hit the hero")
	# 5 attack the pointed enemy
	var t := _tile(_step(def, 4))
	var tx: int = t[0]
	var ty: int = t[1]
	var foe: Variant = Game.unit_at(s, tx, ty)
	check(foe != null, tag + "step 5 point holds an enemy")
	check(_allows(_step(def, 4), hero), tag + "hero clickable at step 5")
	if foe != null:
		var fd: Dictionary = foe
		eq(fd.side, "e", tag + "step 5 target side")
		Quests.observe(s, Game.do_action(s, { "id": hero.id, "to": [hero.x, hero.y], "kind": "attack", "target": fd.id }))
	eq(Quests.done_count(s), 5, tag + "attack_with hero")
	AI.rng = old

## scripted player follows t02 steps 1–4 (no enemy units: the bot only ends its turn)
func _walk_t02() -> void:
	var def := _lv("t02")
	if def.is_empty():
		check(false, "t02")
		return
	var s := Game.new_game(def)
	Quests.init_state(s, def)
	# 1 buy a soldier at the pointed castle
	var c := _tile(_step(def, 0))
	var cx: int = c[0]
	var cy: int = c[1]
	check(Game.sells(Game.tile_at(s, cx, cy)), "step 1 point = castle")
	var own: Dictionary = s.owner
	eq(own.get(Vector2i(cx, cy)), "p", "our castle")
	check(Game.buy(s, cx, cy, "soldier") != null, "buy soldier")
	Quests.note(s, "buy", "soldier")
	eq(Quests.done_count(s), 1, "buy done")
	# 2 hurt soldier -> our village
	var hurt: Array = _side(s, "p").filter(
		func(u: Dictionary) -> bool:
			return u.type == "soldier" and u.hp < 100,
	)
	check(hurt.size() == 1, "one hurt soldier")
	if hurt.is_empty():
		return
	var hs: Dictionary = hurt[0]
	var v := _tile(_step(def, 1))
	var vx: int = v[0]
	var vy: int = v[1]
	check(_allows(_step(def, 1), hs), "hurt soldier clickable")
	eq(Game.tile_at(s, vx, vy), "v", "step 2 point = village")
	eq(own.get(Vector2i(vx, vy)), "p", "our village (heals)")
	Quests.observe(s, Game.do_action(s, { "id": hs.id, "to": v, "kind": "wait" }))
	eq(Quests.done_count(s), 2, "stand_on v done")
	# 3 end turn, 4 heal at our next turn start
	eq(_step(def, 2).get("point"), "end_turn", "step 3 end_turn")
	Quests.note(s, "end_turn", null)
	var ev := Game.end_turn(s)
	ev.append_array(_ai_turn(s))
	Quests.observe(s, ev)
	eq(Quests.done_count(s), 4, "all quests done")
	eq(s.winner, null, "game goes on")
