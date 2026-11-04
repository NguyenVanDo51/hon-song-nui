extends SceneTree
## headless tests (port of tests/*.test.cjs): <godot> --headless --path . -s sim/tests.gd   -> exit code 1 on failure

var failed := 0
var passed := 0
var _cur := ""
var _ok := true

func check(cond: bool, msg: String) -> void:
	if not cond:
		_ok = false
		printerr("  FAIL %s: %s" % [_cur, msg])

func eq(a: Variant, b: Variant, msg := "") -> void:
	check(a == b, "%s expected %s got %s" % [msg, b, a])

func run(name: String, fn: Callable) -> void:
	_cur = name
	_ok = true
	fn.call()
	if _ok:
		passed += 1
	else:
		failed += 1
		print("FAIL " + name)

func _init() -> void:
	content_tests()
	rule_tests()
	mission_tests()
	print("tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

# ---------- content ----------
func content_tests() -> void:
	var all: Array = Content.campaign().duplicate()
	for mid: String in Content.SKIRMISH.MAPS:
		all.append(Content.skirmish_def(mid, Content.heroes_of("p")[0], false))
	run("skirmish: new maps are 180° rotations (fair start)", func() -> void:
		for mid: String in ["cua_bien", "nui_rung"]:
			var rows: Array = Content.SKIRMISH.MAPS[mid].rows
			for y in rows.size():
				eq(rows[y], (rows[rows.size() - 1 - y] as String).reverse(), "%s row %d" % [mid, y])
	)
	eq(Content.campaign().size(), 16, "campaign size")
	run("chapters: 2 chapters, every mission in one, missions of a chapter are consecutive", func() -> void:
		eq(Content.chapters().map(func(c: Dictionary) -> String: return c.id), ["c1", "c2"])
		var seen := []
		for m: Dictionary in Content.campaign():
			var c := Content.chapter_of(m)
			check(Content.chapter(c) != null, "chapter of " + m.id)
			if seen.is_empty() or seen.back() != c:
				check(not seen.has(c), "chapter %s split" % c)
				seen.append(c)
		for c: Dictionary in Content.chapters():
			for key: String in ["title", "subtitle", "rivers", "labels", "outro"]:
				check(c.has(key), "%s.%s" % [c.id, key])
			check(Content.missions_of(c.id).size() >= 6, c.id + " has missions")
		check(Content.chapter_unlocked("c1", 0) and not Content.chapter_unlocked("c2", 7) and Content.chapter_unlocked("c2", 8), "unlock order")
	)
	run("our commander can walk (over turns) to every castle, the enemy commander and the reach goal", func() -> void:
		for m: Dictionary in Content.campaign():
			var s := Game.new_game(m)
			var hero: Variant = null
			for u: Dictionary in s.units:
				if u.side == "p" and u.type == "hero":
					hero = u
			if hero == null:
				continue
			var mc: String = Game.stat(s, hero).move
			var seen := { Vector2i(hero.x, hero.y): true }
			var q := [Vector2i(hero.x, hero.y)]
			while q.size():
				var c: Vector2i = q.pop_back()
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := c + d
					if not seen.has(n) and Game.tile_at(s, n.x, n.y) != null and Game.move_cost(mc, Game.tile_at(s, n.x, n.y)) < INF:
						seen[n] = true
						q.append(n)
			var need := []
			for y in s.h:
				for x in s.w:
					if s.tiles[y][x] == "c":
						need.append(Vector2i(x, y))
			for u: Dictionary in s.units:
				if u.side == "e" and u.type == "hero":
					need.append(Vector2i(u.x, u.y))
			for at: Array in s.win.get("at", []):
				need.append(Vector2i(at[0], at[1]))
			for t: Vector2i in need:
				# the enemy commander may stand on water: a neighbouring land tile is enough to strike it
				var ok := seen.has(t) or [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)].any(func(d: Vector2i) -> bool: return seen.has(t + d))
				check(ok, "%s: commander cannot reach %s" % [m.id, t])
	)
	run("one roster for both sides; one commander for us; enemy commanders share one look", func() -> void:
		for c: String in ["c1", "c2"]:
			Content.use_chapter(c)
			for ty: String in Rules.UNITS:
				if ty == "hero":
					continue
				eq(Content.unit_type_look("e", ty, null).name, Content.unit_type_look("p", ty, null).name, ty)
				eq(Content.unit_type_look("e", ty, null).icon, Content.unit_type_look("p", ty, null).icon, ty)
		Content.use_chapter("c1")
		eq(Content.heroes_of("p"), ["trungtrac"])
		for m: Dictionary in Content.campaign():
			eq(m.hero, "trungtrac", m.id)
			if m.enemyHero != null:
				eq(m.enemyHero, "todinh" if Content.chapter_of(m) == "c1" else "mavien", m.id)
		eq(Content.hero_look("todinh").icon, Content.hero_look("mavien").icon)
		eq(Rules.HEROES.todinh, Rules.HEROES.mavien)
	)
	run("reach: hero on the goal wins, time runs out loses", func() -> void:
		var s := Game.new_game(Content.mission("m13"))
		var hero: Dictionary = s.units.filter(func(u: Dictionary) -> bool: return u.type == "hero")[0]
		var goal: Array = s.win.at[0]
		for u: Dictionary in s.units:
			if u.side == "e" and abs(u.x - goal[0]) + abs(u.y - goal[1]) <= 1:
				u.x = 0
				u.y = 0
		hero.x = goal[0]
		hero.y = goal[1] + 1
		Game.do_action(s, { "id": hero.id, "to": goal, "kind": "wait" })
		eq(s.winner, "p")
		eq(s.reason, "reached")
		var s2 := Game.new_game(Content.mission("m13"))
		for i in 60:
			if s2.winner != null:
				break
			Game.end_turn(s2)
		eq(s2.winner, "e")
		eq(s2.reason, "timeUp")
	)
	for def: Dictionary in all:
		run("content valid: " + def.id, func() -> void:
			var rows: Array = def.map.rows
			for r: String in rows:
				check(r.length() == rows[0].length(), "rows equal length")
				for i in r.length():
					check(Rules.TERRAIN.has(r[i]), "unknown tile " + r[i])
			var s := Game.new_game(def)
			var seen := {}
			for u: Dictionary in s.units:
				check(Game.move_cost(Game.stat(s, u).move, Game.tile_at(s, u.x, u.y)) != INF, "%s %s on impassable %d,%d" % [u.side, u.type, u.x, u.y])
				check(not seen.has(Vector2i(u.x, u.y)), "two units on %d,%d" % [u.x, u.y])
				seen[Vector2i(u.x, u.y)] = true
			for key: Vector2i in s.owner:
				check(Game.tile_at(s, key.x, key.y) in ["v", "c"], "owner on non-building %s" % key)
			for side: String in ["p", "e"]:
				if s.units.any(func(u: Dictionary) -> bool: return u.side == side and u.type == "hero"):
					check(s.heroKey[side] != null, side + " hero unit but no hero key")
			for w: Dictionary in def.get("waves", []):
				for wu: Array in w.units:
					check(Game.tile_at(s, wu[1], wu[2]) != null, "wave off map %d,%d" % [wu[1], wu[2]])
			for t: String in def.get("newUnits", []):
				check(Rules.UNITS.has(t), "newUnits " + t)
			for side: String in ["p", "e"]:
				for t: String in s.allowed[side]:
					check(Content.theme().units[side].has(t), "no skin %s %s" % [side, t])
			var story: Dictionary = def.get("story", {})
			for line: Array in story.get("intro", []) + story.get("outro", []):
				check(Content.speaker(line[0]).icon != "💬", "speaker " + line[0])
			check(s.winner == null, "no winner at start")
			# foot path from hero to enemy castle on castle maps
			if s.win.type == "castles":
				var hero: Dictionary = s.units.filter(func(u: Dictionary) -> bool: return u.side == "p" and u.type == "hero")[0]
				var goal: Vector2i = Game.castle_tiles(s, "e")[0]
				var seen_p := { Vector2i(hero.x, hero.y): true }
				var q := [Vector2i(hero.x, hero.y)]
				while q.size():
					var c: Vector2i = q.pop_front()
					for d: Array in Game.DIRS:
						var n := Vector2i(c.x + d[0], c.y + d[1])
						if seen_p.has(n) or Game.move_cost("foot", Game.tile_at(s, n.x, n.y)) == INF:
							continue
						seen_p[n] = true
						q.append(n)
				check(seen_p.has(goal), "foot path to enemy castle")
		)
	run("theme: every terrain painter has the colors it reads", func() -> void:
		var need := { "field": ["base", "line"], "forest": ["base", "tree", "tree2"], "hill": ["base", "hill", "hill2"], "mountain": ["base", "rock", "rock2", "snow"],
			"water": ["base", "deep", "wave"], "bridge": ["base", "deep", "plank", "plank2"], "village": ["base", "line", "wall"], "castle": ["base", "wall", "wall2"] }
		for ch: String in Content.theme().terrain:
			var t: Dictionary = Content.theme().terrain[ch]
			check(Rules.TERRAIN.has(ch), "theme tile %s has rules" % ch)
			for key: String in need.get(t.paint, []):
				check(t.has(key), "%s (%s) missing %s" % [ch, t.paint, key])
		for ch: String in Rules.TERRAIN:
			check(Content.theme().terrain.has(ch), "rules tile %s has theme" % ch)
	)

# ---------- rules ----------
func blank(units: Array) -> Dictionary:
	var s := Game.new_game(Content.skirmish_def("dong_bang", "trungnhi", false))
	s.tiles = []
	for y in 6:
		s.tiles.append([".", ".", ".", ".", ".", "."])
	s.w = 6
	s.h = 6
	s.owner = { Vector2i(0, 0): "p", Vector2i(5, 5): "e" }
	s.tiles[0][0] = "c"
	s.tiles[5][5] = "c"
	s.units = []
	s.nextId = 1
	s.hadCastle = { "p": true, "e": true }
	for spec: Array in units:
		s.units.append({ "id": s.nextId, "side": spec[0], "type": spec[1], "x": spec[2], "y": spec[3], "hp": spec[4] if spec.size() > 4 else 100, "xp": 0, "rank": 0, "acted": false })
		s.nextId += 1
	return s

func rule_tests() -> void:
	run("damage = (atk - def - terrain) scaled by attacker hp", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 2, 1]])
		var a: Dictionary = s.units[0]
		var d: Dictionary = s.units[1]
		eq(Game.damage(s, a, 1, 1, 100, d), 40)
		eq(Game.damage(s, a, 1, 1, 50, d), 20)
		s.tiles[1][2] = "f"
		eq(Game.damage(s, a, 1, 1, 100, d), 30)
	)
	run("attack applies damage + counter; preview matches", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 3, 1]])
		var a: Dictionary = s.units[0]
		var d: Dictionary = s.units[1]
		var p := Game.preview(s, a, 2, 1, d)
		eq([p.dmg, p.counter], [40, 24])
		Game.do_action(s, { "id": a.id, "to": [2, 1], "kind": "attack", "target": d.id })
		eq([d.hp, a.hp], [60, 76])
	)
	run("buffs_at (UI) agrees with damage(): drum aura +10 atk, guard hero +10 def, only when adjacent", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["p", "drum", 1, 2], ["e", "soldier", 2, 1], ["e", "hero", 3, 1]])
		s.heroKey.e = "lucdan" # guard 10
		var a: Dictionary = s.units[0]
		var d: Dictionary = s.units[2]
		var ba := Game.buffs_at(s, a, 1, 1)
		var bd := Game.buffs_at(s, d, 2, 1)
		eq([ba.atk, ba.def, bd.atk, bd.def], [10, 0, 0, 10])
		eq(ba.atk_from.type, "drum")
		var st_a := Game.stat(s, a)
		var st_d := Game.stat(s, d)
		eq(Game.damage(s, a, 1, 1, 100, d), int(st_a.atk + ba.atk - (st_d.def + bd.def + bd.terrain)))
		eq(Game.buffs_at(s, a, 0, 0).atk, 0) # (0,0) is not next to the drum at (1,2)
		eq(Content.traits("drum", null).any(func(t: String) -> bool: return "+10 công" in t), true)
		eq(Content.how_to_play("archer") != "", true)
	)
	run("path_for walks through an ally (the drawn route used to lose its start there)", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["p", "archer", 2, 1], ["e", "soldier", 5, 4]])
		s.tiles[0][2] = "m"; s.tiles[2][2] = "m" # only way east is through the archer
		var u: Dictionary = s.units[0]
		eq(Game.path_for(s, u, 3, 1), [[1, 1], [2, 1], [3, 1]])
		var ev := Game.do_action(s, { "id": u.id, "to": [3, 1], "kind": "wait" })
		eq(ev[0].path, [[1, 1], [2, 1], [3, 1]])
	)
	run("archer at range 2 takes no counter from melee", func() -> void:
		var s := blank([["p", "archer", 1, 1], ["e", "soldier", 3, 1]])
		Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
		eq(s.units[0].hp, 100)
	)
	run("siege cannot move and attack same turn", func() -> void:
		var s := blank([["p", "catapult", 1, 1], ["e", "soldier", 4, 1]])
		eq(Game.targets_from(s, s.units[0], 2, 1).size(), 0)
		eq(Game.targets_from(s, s.units[0], 1, 1).size(), 1)
	)
	run("only hero captures castle; soldier captures village", func() -> void:
		var s := blank([["p", "soldier", 4, 4], ["p", "hero", 4, 5], ["e", "soldier", 2, 2]])
		s.tiles[3][4] = "v"
		check(not Game.can_capture(s, s.units[0], 5, 5), "soldier vs castle")
		check(Game.can_capture(s, s.units[0], 4, 3), "soldier vs village")
		var ev := Game.do_action(s, { "id": s.units[1].id, "to": [5, 5], "kind": "capture" })
		eq(s.winner, "p")
		check(ev.any(func(e: Dictionary) -> bool: return e.t == "win"), "win event")
	)
	run("kill leaves grave; shaman raises ghost", func() -> void:
		var s := blank([["p", "elephant", 1, 1], ["e", "soldier", 2, 1, 10], ["p", "shaman", 1, 3], ["e", "soldier", 5, 4]])
		Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
		eq(s.graves.size(), 1)
		Game.do_action(s, { "id": 3, "to": [2, 2], "kind": "raise", "target": [2, 1] })
		check(s.units.any(func(u: Dictionary) -> bool: return u.type == "ghost" and u.side == "p"), "ghost raised")
	)
	run("income + heal at turn start; buy respects cap", func() -> void:
		var s := blank([["p", "soldier", 0, 0, 50], ["e", "soldier", 5, 4]])
		s.side = "e"
		s.gold.p = 0
		Game.end_turn(s)
		eq(s.gold.p, Rules.RULES.incomeCastle)
		eq(s.units[0].hp, 70)
		s.units[0].x = 1
		s.gold.p = 99999
		for i in 19:
			s.units.append({ "id": 100 + i, "side": "p", "type": "soldier", "x": 3, "y": i % 6, "hp": 100, "xp": 0, "rank": 0 })
		check(Game.buy_options(s, "p", 0, 0).all(func(o: Dictionary) -> bool: return not o.ok), "cap blocks buy")
	)
	run("rank up from xp", func() -> void:
		var s := blank([["p", "elephant", 1, 1], ["e", "soldier", 2, 1, 50]])
		Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
		eq(s.units[0].rank, 1) # 50 dmg (capped at hp) + 50 kill = 100
	)
	run("save round-trip keeps types", func() -> void:
		var s := Game.new_game(Content.mission("m02"))
		var back: Dictionary = str_to_var(var_to_str(s))
		eq(back, s)
		check(back.owner.keys()[0] is Vector2i, "Vector2i keys")
		check(back.units[0].hp is int, "int hp")
	)

# ---------- missions ----------
func mission_tests() -> void:
	run("rout mission: enemy without castle does not lose at start; loses when wiped", func() -> void:
		var s := Game.new_game(Content.mission("m01"))
		Game.end_turn(s)
		Game.end_turn(s)
		eq(s.winner, null)
		var first_e: Dictionary = s.units.filter(func(u: Dictionary) -> bool: return u.side == "e")[0]
		s.units = s.units.filter(func(u: Dictionary) -> bool: return u.side == "p" or u.id == first_e.id)
		var last: Dictionary = first_e
		last.hp = 1
		var hero: Dictionary = s.units.filter(func(u: Dictionary) -> bool: return u.type == "hero")[0]
		hero.x = last.x - 1
		hero.y = last.y
		for u: Dictionary in s.units:
			if u.id != hero.id and u.x == hero.x and u.y == hero.y:
				u.x = 0
		Game.do_action(s, { "id": hero.id, "to": [hero.x, hero.y], "kind": "attack", "target": last.id })
		eq(s.winner, "p")
		eq(s.reason, "routed")
	)
	run("heroMustLive: hero death = loss", func() -> void:
		var s := Game.new_game(Content.mission("m01"))
		var hero: Dictionary = s.units.filter(func(u: Dictionary) -> bool: return u.type == "hero")[0]
		var e: Dictionary = s.units.filter(func(u: Dictionary) -> bool: return u.side == "e")[0]
		hero.hp = 1
		hero.x = e.x - 1
		hero.y = e.y
		for u: Dictionary in s.units:
			if u.id != hero.id and u.x == hero.x and u.y == hero.y:
				u.y = 7
				u.x = 0
		Game.end_turn(s)
		Game.do_action(s, { "id": e.id, "to": [e.x, e.y], "kind": "attack", "target": hero.id })
		eq(s.winner, "e")
		eq(s.reason, "heroFell")
	)
	run("survive: win when turn passes limit; waves spawn, occupied tile shifts", func() -> void:
		var def: Dictionary = Content.mission("m03")
		var s := Game.new_game(def)
		var w: Array = def.waves[0].units[0]
		Game.spawn(s, "p", "soldier", w[1], w[2])
		Game.end_turn(s)
		Game.end_turn(s)
		Game.end_turn(s)
		var spawned: Array = s.units.filter(func(u: Dictionary) -> bool: return u.side == "e")
		eq(spawned.size(), 3)
		check(not spawned.any(func(u: Dictionary) -> bool: return u.x == w[1] and u.y == w[2]), "occupied tile skipped")
		for i in 40:
			if s.winner != null:
				break
			Game.end_turn(s)
		eq(s.winner, "p")
		eq(s.reason, "survived")
		eq(s.turn, 11)
	)
	run("hero mission: killing enemy hero wins even with castles left", func() -> void:
		var s := Game.new_game(Content.mission("m04"))
		var eh: Dictionary = s.units.filter(func(u: Dictionary) -> bool: return u.side == "e" and u.type == "hero")[0]
		var el: Dictionary = s.units.filter(func(u: Dictionary) -> bool: return u.side == "p" and u.type == "elephant")[0]
		eh.hp = 1
		el.x = eh.x
		el.y = eh.y + 1
		for u: Dictionary in s.units:
			if u.id != el.id and u.x == el.x and u.y == el.y:
				u.x = 13
				u.y = 9
		Game.do_action(s, { "id": el.id, "to": [el.x, el.y], "kind": "attack", "target": eh.id })
		eq(s.winner, "p")
		eq(s.reason, "heroKilled")
	)
	run("guard unit holds until player near", func() -> void:
		var s := Game.new_game(Content.mission("m04"))
		Game.end_turn(s)
		var eh: Dictionary = s.units.filter(func(u: Dictionary) -> bool: return u.side == "e" and u.type == "hero")[0]
		var at := [eh.x, eh.y]
		var n := 0
		while n < 50:
			n += 1
			var step: Variant = AI.next_step(s, {})
			if step == null:
				break
			AI.apply_step(s, step)
		eq([eh.x, eh.y], at)
		check(eh.guard, "still guarding")
	)
	run("allowed list limits buys", func() -> void:
		var s := Game.new_game(Content.mission("m02"))
		s.units = s.units.filter(func(u: Dictionary) -> bool: return not (u.x == 1 and u.y == 2))
		eq(Game.buy_options(s, "p", 1, 2).map(func(o: Dictionary) -> String: return o.type), ["soldier", "archer"])
	)
