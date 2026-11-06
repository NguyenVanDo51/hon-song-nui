extends SceneTree
## headless tests: <godot> --headless --path . -s sim/tests.gd   -> exit code 1 on failure

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
	Game.fixed_roll = -1.0
	fn.call()
	if _ok:
		passed += 1
	else:
		failed += 1
		print("FAIL " + name)

func _init() -> void:
	parity_tests()
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
		# exactly two commanders across every campaign + skirmish: one look + one stat line per side
		eq(Content.heroes_of("p"), ["anhhung"])
		eq(Content.heroes_of("e"), ["tuonggiac"])
		eq(Rules.HEROES.keys(), ["anhhung", "tuonggiac"])
		for m: Dictionary in Content.campaign():
			eq(m.hero, "anhhung", m.id)
			check(m.enemyHero == null or m.enemyHero == "tuonggiac", m.id + " enemy commander")
		for mid: String in Content.SKIRMISH.MAPS:
			eq(Content.skirmish_def(mid, "anhhung", false).enemyHero, "tuonggiac", mid)
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
					check(Rules.UNITS.has(wu[0]), "wave unit type " + str(wu[0]))
					var wst := Game.stat(s, { "type": wu[0], "side": "e" })
					check(Game.move_cost(wst.move, Game.tile_at(s, wu[1], wu[2])) != INF, "wave %s on impassable %d,%d" % [wu[0], wu[1], wu[2]])
			# win schema
			check(Content.WIN_TYPES.has(s.win.type), "win type " + str(s.win.type))
			if s.win.type == "survive":
				check(s.win.get("turns") is int and s.win.turns > 0, "survive needs turns")
			if s.win.type == "hero":
				check(s.heroKey.e != null, "hero win needs an enemy commander")
			if s.win.type == "reach":
				check(s.win.get("at", []).size() > 0, "reach needs at")
				var hst := Game.stat(s, { "type": "hero", "side": "p" })
				for g: Array in s.win.get("at", []):
					check(Game.move_cost(hst.move, Game.tile_at(s, g[0], g[1])) != INF, "reach tile %s impassable" % [g])
			for side: String in ["p", "e"]:
				for t: String in s.allowed[side]:
					check(AI.WEIGHTS.has(t), "AI has no buy weight for " + t)
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
	var s := Game.new_game(Content.skirmish_def("dong_bang", "anhhung", false))
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
	run("catapult razes an enemy / unowned village in range from where it stands; not own, not occupied, not after moving", func() -> void:
		var s := blank([["p", "catapult", 1, 1], ["e", "soldier", 4, 4]])
		var c: Dictionary = s.units[0]
		s.tiles[1][4] = "v"; s.owner[Vector2i(4, 1)] = "e" # dist 3: in range
		s.tiles[3][1] = "v" # unowned, dist 2
		s.tiles[1][2] = "v"; s.owner[Vector2i(2, 1)] = "p" # own: never
		s.tiles[4][4] = "v" # occupied by the enemy soldier: no
		s.tiles[1][1] = "." 
		var opts := Game.razable_from(s, c, 1, 1)
		check(opts.has([4, 1]) and opts.has([3, 1]) == false and opts.has([1, 3]), "options %s" % [opts])
		check(not opts.has([2, 1]) and not opts.has([4, 4]), "own / occupied excluded %s" % [opts])
		eq(Game.razable_from(s, c, 1, 2).size(), 0, "siege: not from another tile")
		var ev := Game.do_action(s, { "id": c.id, "to": [1, 1], "kind": "raze", "target": [4, 1] })
		eq(s.tiles[1][4], "x", "village ruined")
		check(not s.owner.has(Vector2i(4, 1)), "owner cleared")
		check(ev.any(func(e: Dictionary) -> bool: return e.t == "raze" and e.prev == "e"), "raze event with prev owner")
		check(c.acted, "catapult done for the turn")
		eq(Game.income(s, "e"), Rules.RULES.incomeCastle, "enemy lost the village income")
	)
	run("ruined village: no capture; capV unit repairs -> unowned village, capture on a later turn", func() -> void:
		var s := blank([["p", "soldier", 2, 2], ["p", "archer", 3, 3], ["e", "soldier", 5, 4]])
		var sol: Dictionary = s.units[0]
		s.tiles[2][2] = "x"
		check(not Game.can_capture(s, sol, 2, 2), "cannot capture a ruin")
		check(not Game.can_repair(s, s.units[1], 2, 2), "archer cannot repair")
		check(Game.can_repair(s, sol, 2, 2), "soldier can repair")
		Game.do_action(s, { "id": sol.id, "to": [2, 2], "kind": "repair" })
		eq(s.tiles[2][2], "v", "repaired")
		check(not s.owner.has(Vector2i(2, 2)), "still unowned")
		check(sol.acted, "repair takes the turn")
		Game.end_turn(s); Game.end_turn(s)
		check(Game.can_capture(s, sol, 2, 2), "capturable next turn")
		eq(Game.TERRAIN["x"].def, Game.TERRAIN["v"].def, "ruin keeps the village cover (as the original)")
	)
	run("AI catapult wrecks an enemy village when it has nothing to hit; AI soldier repairs a ruin", func() -> void:
		var s := blank([["e", "catapult", 4, 4], ["p", "soldier", 0, 1]])
		s.side = "e"
		s.tiles[1][4] = "v"; s.owner[Vector2i(4, 1)] = "p"
		var step: Variant = AI.next_step(s, {})
		eq(step.act.kind, "raze", "catapult razes")
		eq(step.act.target, [4, 1])
		var s2 := blank([["e", "soldier", 3, 3], ["p", "soldier", 0, 1]])
		s2.side = "e"
		s2.tiles[3][4] = "x"
		var acts := []
		var mem := {}
		var st2: Variant = AI.next_step(s2, mem)
		AI.apply_step(s2, st2)
		eq(s2.tiles[3][4], "v", "AI soldier repaired the adjacent ruin (got %s)" % [st2.act])
	)
	run("illegal capture / raise changes nothing (unit stays, can still act)", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 4, 4]])
		var u: Dictionary = s.units[0]
		var n: int = s.units.size()
		Game.do_action(s, { "id": u.id, "to": [2, 2], "kind": "capture" }) # plain field: nothing to capture
		eq([u.x, u.y], [1, 1], "position")
		check(not u.acted, "still can act")
		Game.do_action(s, { "id": u.id, "to": [2, 1], "kind": "raise", "target": [3, 1] }) # soldier cannot raise, no grave
		eq([u.x, u.y], [1, 1], "position after bad raise")
		eq(s.units.size(), n, "no unit spawned")
	)
	run("AE2: raised ghosts ignore the unit cap and do not count toward it", func() -> void:
		var s := blank([["p", "shaman", 1, 1], ["e", "soldier", 4, 4]])
		s.graves = [{ "x": 2, "y": 1, "ttl": 2 }]
		s.unitCap = 1
		eq(Game.raisable_graves(s, s.units[0], 1, 1).size(), 1, "raise at cap")
		Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "raise", "target": [2, 1] })
		eq(Game.cap_count(s, "p"), 1, "ghost not counted")
	)
	run("AE2 graves: ttl 3, down 1 at every side's turn start; stepping on one clears it", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 4, 4]])
		s.graves = [{ "x": 3, "y": 3, "ttl": Rules.RULES.graveRounds }]
		Game.end_turn(s); Game.end_turn(s)
		eq(s.graves.size(), 1, "alive after 2 half-turns")
		Game.end_turn(s)
		eq(s.graves.size(), 0, "gone after 3")
		s.graves = [{ "x": 2, "y": 1, "ttl": 3 }]
		s.side = "p"
		s.units[0].acted = false
		Game.do_action(s, { "id": 1, "to": [2, 1], "kind": "wait" })
		eq(s.graves.size(), 0, "stepped on")
	)
	run("AE2 income: village 30, castle 50", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 4, 4]])
		s.tiles[0][3] = "v"
		s.owner[Vector2i(3, 0)] = "e"
		eq(Game.income(s, "e"), 80)
		eq(Game.income(s, "p"), 50)
	)
	run("AE2 damage: (roll atk..atkMax-1 + bonus - def - terrain) x hp / 100, floor, >= 0", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 2, 1]])
		var a: Dictionary = s.units[0]
		var d: Dictionary = s.units[1]
		eq(Game.damage(s, a, 1, 1, 100, d, 0.0), 40) # 50 - 5 def - 5 field
		eq(Game.damage(s, a, 1, 1, 100, d, 0.999), 44, "never the table max 55") # 54 - 10
		eq(Game.damage(s, a, 1, 1, 100, d, Game.ROLL_TOP), 44)
		eq(Game.atk_range(s, a), [50, 54], "rollable range")
		# every roll in [0,1) lands in [min, max-1] and each value is reachable
		var seen := {}
		for i in 1000:
			seen[Game.damage(s, a, 1, 1, 100, d, i / 1000.0)] = true
		eq(seen.keys().map(func(k: int) -> int: return k + 10).reduce(func(m: int, k: int) -> int: return maxi(m, k), 0), 54, "max roll")
		eq(seen.size(), 5, "rolls 50..54")
		check(Content.traits("soldier", null).any(func(t: String) -> bool: return "Công 50–54" in t), "traits print the rollable range")
		eq(Game.damage(s, a, 1, 1, 50, d, 0.0), 20)
		s.tiles[1][2] = "f"
		eq(Game.damage(s, a, 1, 1, 100, d, 0.0), 35)
		var e := blank([["p", "ghost", 1, 1], ["e", "elephant", 2, 1]])
		e.tiles[1][2] = "m"
		eq(Game.damage(e, e.units[0], 1, 1, 100, e.units[1], 0.0), 0, "armour soaks the hit")
	)
	run("attack applies rolled damage + adjacent counter; preview gives the range", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 3, 1]])
		var a: Dictionary = s.units[0]
		var d: Dictionary = s.units[1]
		var p := Game.preview(s, a, 2, 1, d)
		eq([p.dmgMin, p.dmgMax, p.counterMin, p.counterMax], [40, 44, 22, 26])
		# forecast is exact: top roll -> hit = dmgMax (44); counter after it = (54 - 10) x 56 / 100 = 24
		var s2 := blank([["p", "soldier", 1, 1], ["e", "soldier", 3, 1]])
		Game.fixed_roll = Game.ROLL_TOP
		Game.do_action(s2, { "id": 1, "to": [2, 1], "kind": "attack", "target": 2 })
		Game.fixed_roll = -1.0
		eq([s2.units[1].hp, s2.units[0].hp], [100 - p.dmgMax, 76])
		Game.fixed_roll = 0.0
		Game.do_action(s, { "id": a.id, "to": [2, 1], "kind": "attack", "target": d.id })
		Game.fixed_roll = -1.0
		eq([d.hp, a.hp], [60, 76])
	)
	run("AE2 counter: only adjacent + rmin 1 (archer counters next to it, not at 2)", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["e", "archer", 2, 1], ["e", "catapult", 1, 2]])
		check(Game.can_counter(s, s.units[1], 1, 1), "archer adjacent counters")
		check(not Game.can_counter(s, s.units[1], 0, 1), "archer at 2 does not")
		check(not Game.can_counter(s, s.units[2], 1, 1), "catapult never")
	)
	run("AE2 drum: after acting, allies within 2 get +10 atk until the drum side's next turn", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["p", "drum", 1, 3], ["p", "archer", 4, 1], ["e", "soldier", 2, 1]])
		var a: Dictionary = s.units[0]
		var d: Dictionary = s.units[3]
		var before := Game.damage(s, a, 1, 1, 100, d, 0.0)
		Game.do_action(s, { "id": 2, "to": [1, 3], "kind": "wait" })
		check(a.get("aura") == "p" and s.units[2].get("aura") == null, "soldier (2 away) buffed, archer (far) not")
		eq(Game.damage(s, a, 1, 1, 100, d, 0.0), before + 10)
		eq(Game.buffs_at(s, a, 1, 1).atk, 10, "buffs_at shows it")
		Game.end_turn(s)
		check(a.get("aura") == "p", "lasts through the enemy turn")
		Game.end_turn(s)
		check(a.get("aura") == null, "gone at our next turn")
		eq(Content.traits("drum", null).any(func(t: String) -> bool: return "+10 công" in t), true)
		# AE2: a drum killed by the counter still drums, from the tile it fell on (RM Unit.finishMove)
		var k := blank([["p", "drum", 1, 1, 1], ["p", "soldier", 1, 3], ["p", "archer", 4, 4], ["e", "soldier", 2, 2]])
		Game.fixed_roll = 0.0
		Game.do_action(k, { "id": 1, "to": [1, 2], "kind": "attack", "target": 4 })
		Game.fixed_roll = -1.0
		check(Game.unit_by_id(k, 1) == null, "drum died")
		check(k.units[0].get("aura") == "p", "ally 1 from the death tile buffed")
		check(k.units[1].get("aura") == null, "far ally not")
		eq(Content.how_to_play("archer") != "", true)
	)
	run("AE2 wolf: counter first at full strength, then the bite lands (RM finishAttack)", func() -> void:
		var s := blank([["p", "wolf", 1, 1], ["e", "soldier", 2, 1]])
		var w: Dictionary = s.units[0]
		var d: Dictionary = s.units[1]
		Game.fixed_roll = 0.0
		var ev := Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
		Game.fixed_roll = -1.0
		# soldier at 100 - 50 = 50 hp, unpoisoned: (50 - 15 - 5) x 50 / 100 = 15
		eq(d.hp, 50)
		eq(100 - w.hp, 15, "counter not weakened by the bite")
		eq(d.get("poison"), "p", "poisoned after")
		var order: Array = ev.filter(func(e: Dictionary) -> bool: return e.t == "hit" or e.t == "poison").map(func(e: Dictionary) -> String: return "c" if e.get("counter", false) else e.t)
		eq(order, ["hit", "c", "poison"], "event order")
	)
	run("AE2 wolf: a 0-damage bite still poisons, even if the counter kills the wolf", func() -> void:
		var s := blank([["p", "wolf", 1, 1, 1], ["e", "soldier", 2, 1]])
		var d: Dictionary = s.units[1]
		Game.fixed_roll = 0.0
		var ev := Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
		Game.fixed_roll = -1.0
		eq(d.hp, 100, "bite at 1 hp: 0 dmg")
		check(Game.unit_by_id(s, 1) == null, "wolf died to the counter")
		eq(d.get("poison"), "p", "still poisoned")
		check(ev.any(func(e: Dictionary) -> bool: return e.t == "poison"), "poison event")
	)
	run("AE2 wolf bite: target -10 atk / -10 def until the wolf side's next turn", func() -> void:
		var s := blank([["p", "wolf", 1, 1], ["e", "elephant", 2, 1], ["p", "soldier", 3, 2]])
		var e: Dictionary = s.units[1]
		var sol: Dictionary = s.units[2]
		var hit_before := Game.damage(s, sol, 3, 2, 100, e, 0.0)
		Game.fixed_roll = 0.0
		Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
		Game.fixed_roll = -1.0
		eq(e.get("poison"), "p", "poisoned")
		eq(Game.damage(s, sol, 3, 2, 100, e, 0.0), hit_before + 10, "softer")
		Game.end_turn(s); Game.end_turn(s)
		eq(e.get("poison"), null, "worn off")
	)
	run("AE2 water: everyone wades at cost 3 / def 0; water class 1 and +10 atk +15 def there", func() -> void:
		eq(Game.move_cost("foot", "~"), 3.0)
		eq(Game.move_cost("water", "~"), 1.0)
		eq(Game.move_cost("fly", "m"), 1.0)
		eq(Game.move_cost("foot", "m"), 3.0)
		var s := blank([["p", "boat", 1, 1], ["e", "soldier", 2, 1]])
		s.tiles[1][1] = "~"
		var b: Dictionary = s.units[0]
		eq(Game.damage(s, b, 1, 1, 100, s.units[1], 0.0), 50, "50 + 10 water - 10")
		eq(Game.damage(s, s.units[1], 2, 1, 100, b, 0.0), 25, "50 - (10 + 15)")
	)
	run("temple heals any side, cannot be captured", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 3, 3, 50]])
		s.tiles[3][3] = "t"
		check(not Game.can_capture(s, s.units[0], 3, 3), "no capture")
		Game.end_turn(s)
		eq(s.units[1].hp, 70, "enemy healed on the temple")
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
	run("AE2 loss: castles gone AND commander dead; hero capture of the last castle wins only then", func() -> void:
		var s := blank([["p", "soldier", 4, 4], ["p", "hero", 4, 5], ["e", "hero", 1, 4]])
		s.tiles[3][4] = "v"
		check(not Game.can_capture(s, s.units[0], 5, 5), "soldier vs castle")
		check(Game.can_capture(s, s.units[0], 4, 3), "soldier vs village")
		Game.do_action(s, { "id": s.units[1].id, "to": [5, 5], "kind": "capture" })
		eq(s.winner, null, "enemy commander still alive")
		s.units[2].hp = 1
		Game.end_turn(s); Game.end_turn(s)
		s.units[0].x = 1; s.units[0].y = 3
		Game.do_action(s, { "id": s.units[0].id, "to": [1, 3], "kind": "attack", "target": s.units[2].id })
		eq(s.winner, "p")
		eq(s.reason, "castlesLost")
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
	run("AE2 buy: new unit acts at once; buy on own-occupied castle -> must step off", func() -> void:
		var s := blank([["p", "soldier", 0, 0], ["e", "soldier", 5, 4]])
		s.gold.p = 5000
		var ok := func(t: String) -> bool: return Game.buy_options(s, "p", 0, 0).any(func(o: Dictionary) -> bool: return o.type == t and o.ok)
		check(ok.call("archer"), "buy allowed with our soldier on the castle")
		var a: Dictionary = Game.buy(s, 0, 0, "archer")
		check(not a.acted, "bought unit can act this turn")
		check(Game.stacked(s, a) and Game.stacked(s, s.units[0]), "both stacked")
		check(not Game.reachable(s, a).has(Vector2i(0, 0)), "new unit cannot stay on the shared tile")
		check(not Game.reachable(s, s.units[0]).has(Vector2i(0, 0)), "old unit cannot stay either")
		check(Game.buy_options(s, "p", 0, 0).is_empty(), "no 3rd unit on a stacked castle")
		eq(Game.do_action(s, { "id": a.id, "to": [0, 0], "kind": "wait" }), [], "wait in place rejected")
		Game.do_action(s, { "id": a.id, "to": [1, 1], "kind": "wait" })
		check(not Game.stacked(s, s.units[0]), "stack cleared after stepping off")
		check(ok.call("soldier"), "can buy again on the same castle this turn")
		# boxed in: no free tile to step to -> cannot buy on top
		var b := blank([["p", "soldier", 0, 0], ["p", "soldier", 1, 0], ["p", "soldier", 0, 1], ["p", "soldier", 1, 1],
			["e", "soldier", 2, 0], ["e", "soldier", 2, 1], ["e", "soldier", 0, 2], ["e", "soldier", 1, 2]])
		b.gold.p = 5000
		for u: Dictionary in b.units:
			if u.id > 1: u.acted = true
		check(Game.buy_options(b, "p", 0, 0).all(func(o: Dictionary) -> bool: return not o.ok), "boxed-in castle blocks buying on top")
		# AE2 original: enemy standing on our castle does not block buying; the new unit steps off
		var c := blank([["e", "soldier", 0, 0]])
		c.gold.p = 500
		check(Game.buy_options(c, "p", 0, 0).any(func(o: Dictionary) -> bool: return o.ok), "buy under an enemy on our castle")
		var nb: Dictionary = Game.buy(c, 0, 0, "soldier")
		check(not Game.reachable(c, nb).has(Vector2i(0, 0)), "new unit must step off")
	)
	run("unbuy: take back a buy on top of another unit until it steps off", func() -> void:
		var s := blank([["p", "soldier", 0, 0], ["e", "soldier", 5, 4]])
		s.gold.p = 1000
		var a: Dictionary = Game.buy(s, 0, 0, "archer")
		check(Game.can_unbuy(s, a), "stacked fresh buy can be taken back")
		check(Game.unbuy(s, a.id), "unbuy ok")
		eq(s.gold.p, 1000, "full refund")
		check(Game.unit_by_id(s, a.id) == null and not Game.stacked(s, s.units[0]), "new unit gone, castle unit alone")
		var b: Dictionary = Game.buy(s, 0, 0, "archer")
		Game.do_action(s, { "id": b.id, "to": [1, 0], "kind": "wait" })
		check(not Game.can_unbuy(s, b), "no take-back once it stepped off")
		var c := blank([["e", "soldier", 4, 4]])
		c.gold.p = 1000
		var lone: Dictionary = Game.buy(c, 0, 0, "soldier")
		check(not Game.can_unbuy(c, lone), "buy on an empty castle cannot be taken back")
		var h := blank([["p", "soldier", 0, 0], ["e", "soldier", 5, 4]])
		h.gold.p = 1000
		h.heroDead.p = true
		var cost := Game.hero_cost(h, "p")
		var hero: Dictionary = Game.buy(h, 0, 0, "hero")
		check(Game.unbuy(h, hero.id) and h.heroDead.p and h.gold.p == 1000 and Game.hero_cost(h, "p") == cost, "commander rebuy taken back: dead again, same price")
	)
	run("AI moves a unit it bought the same turn", func() -> void:
		var s := blank([["p", "soldier", 0, 0], ["e", "hero", 4, 4]])
		s.side = "e"
		s.gold.e = 150
		s.units[1].acted = true
		var bought := false
		var mem := {}
		for i in 20:
			var st: Variant = AI.next_step(s, mem)
			if st == null: break
			if st.kind == "buy": bought = true
			AI.apply_step(s, st)
		var nu: Array = s.units.filter(func(u: Dictionary) -> bool: return u.side == "e" and u.type != "hero")
		check(bought and nu.size() == 1, "AI bought")
		check(nu.size() == 1 and nu[0].acted, "bought unit acted this turn")
	)
	run("AI buys under a unit on its castle (own acted / enemy), never a boat without water", func() -> void:
		var s := blank([["p", "soldier", 0, 0], ["e", "hero", 5, 5]])
		s.side = "e"
		s.gold.e = 300
		s.units[1].acted = true
		var st: Variant = AI.next_step(s, {})
		check(st != null and st.kind == "buy" and st.x == 5 and st.y == 5, "buys under own acted hero (got %s)" % [st])
		check(st == null or st.type != "boat", "no boat on a dry map")
		var c := blank([["p", "soldier", 0, 0], ["p", "soldier", 5, 5], ["e", "hero", 3, 0]])
		c.side = "e"
		c.gold.e = 150
		c.units[2].acted = true
		var st2: Variant = AI.next_step(c, {})
		check(st2 != null and st2.kind == "buy", "buys under an enemy on its castle (got %s)" % [st2])
	)
	run("AI commander: healthy -> advances through one unit's threat (no retreat to a safe rear tile); hurt -> never ends where it can die", func() -> void:
		var wide := func(units: Array) -> Dictionary:
			var s := blank(units)
			s.w = 12
			s.h = 7
			s.tiles = []
			for y in 7:
				var row := []
				row.resize(12)
				row.fill(".")
				s.tiles.append(row)
			s.tiles[0][0] = "c"
			s.tiles[6][11] = "c"
			s.owner = { Vector2i(0, 0): "p", Vector2i(11, 6): "e" }
			s.side = "e"
			return s
		AI.rng = func() -> float: return 0.5
		# user report (m07): commander backed off to a tile nobody threatens instead of heading for the fight
		var a: Dictionary = wide.call([["e", "hero", 8, 3], ["p", "soldier", 0, 3]])
		var st: Variant = AI.next_step(a, {})
		var gd := mini(Game.dist(st.act.to[0], st.act.to[1], 0, 3), Game.dist(st.act.to[0], st.act.to[1], 0, 0))
		check(gd <= 4, "commander closes in (dist to nearest goal %d, start 8, got %s)" % [gd, st.act])
		var b: Dictionary = wide.call([["e", "hero", 8, 3, 35], ["p", "soldier", 1, 2], ["p", "soldier", 1, 4], ["p", "archer", 0, 3]])
		var st2: Variant = AI.next_step(b, {})
		var h: Dictionary = b.units[0]
		h.x = st2.act.to[0]
		h.y = st2.act.to[1]
		var worst := 0
		for e: Dictionary in AI.threat_map(b, "e").get(Vector2i(h.x, h.y), []):
			worst += Game.damage(b, e, e.x, e.y, e.hp, h, Game.ROLL_TOP)
		check(worst < h.hp, "hurt commander out of lethal reach (max incoming %d vs hp %d at %s)" % [worst, h.hp, st2.act.to])
		AI.rng = AI._gen.randf
	)
	run("AE2 levels: xp = dmg x (victim atk+atkMax+def); 1 level per fight max, leftover carries, +2 atk/+2 def", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 2, 1]])
		var a: Dictionary = s.units[0]
		var need := Game.xp_need(s, a)
		eq(need, int((50 + 55 + 5) * 200.0 / 3.0))
		a.xp = need * 3
		Game.fixed_roll = 0.0
		Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
		Game.fixed_roll = -1.0
		eq(a.rank, 1, "only one level")
		eq(a.xp, need * 2 + 40 * 110, "leftover + this hit's xp")
		eq(Game.atk_range(s, a), [52, 56])
	)
	run("AE2 xp uses rank-boosted stats: victim quality for xp gained, own quality for the next level (RM Unit.java 250-263)", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 2, 1]])
		var a: Dictionary = s.units[0]
		var d: Dictionary = s.units[1]
		d.rank = 2 # quality 110 + 3 x 2 x 2 = 122
		a.rank = 1 # quality 116
		eq(Game.quality(s, d), 122)
		eq(Game.xp_need(s, a), 116 * 200 / 3, "own quality incl. rank")
		Game.fixed_roll = 0.0
		var ev := Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
		Game.fixed_roll = -1.0
		var hit: int = ev.filter(func(e: Dictionary) -> bool: return e.t == "hit" and not e.get("counter", false))[0].amount
		var back: int = ev.filter(func(e: Dictionary) -> bool: return e.t == "hit" and e.get("counter", false))[0].amount
		eq(a.xp, hit * 122, "xp = dmg x victim quality incl. its rank")
		eq(d.xp, back * 116, "counter xp = dmg x attacker quality incl. its rank")
		# float xpScale vs RM's integer q * 200 / 3: same for every quality a unit can have
		for type: String in Rules.UNITS:
			for r in Rules.RULES.maxRank + 1:
				var u := { "side": "p", "type": type, "rank": r }
				var q := Game.quality(s, u)
				eq(Game.xp_need(s, u), q * 200 / 3, "%s rank %d" % [type, r])
	)
	run("reach goal: a commander bought on the goal tile must walk off and back", func() -> void:
		var s := blank([["p", "soldier", 3, 3], ["e", "soldier", 5, 4]])
		s.win = { "type": "reach", "at": [[0, 0]] }
		s.heroDead.p = true
		s.heroKey.p = "anhhung"
		s.gold.p = 1000
		var h: Dictionary = Game.buy(s, 0, 0, "hero")
		check(not Game.hero_on_goal(s), "buying there is not reaching")
		Game.do_action(s, { "id": h.id, "to": [1, 0], "kind": "wait" })
		Game.end_turn(s); Game.end_turn(s)
		Game.do_action(s, { "id": h.id, "to": [0, 0], "kind": "wait" })
		eq(s.reason, "reached")
	)
	run("AE2 commander: rebuy 200 + 200/death (max 1000), comes back with its level", func() -> void:
		var s := blank([["p", "hero", 1, 1, 1], ["e", "elephant", 2, 1]])
		s.units[0].rank = 3
		s.side = "e"
		Game.fixed_roll = 0.0
		Game.do_action(s, { "id": 2, "to": [2, 1], "kind": "attack", "target": 1 })
		Game.fixed_roll = -1.0
		check(s.heroDead.p, "dead")
		eq(s.winner, null, "castle left: not out")
		eq(Game.hero_cost(s, "p"), 400)
		s.side = "p"
		s.gold.p = 400
		var h: Dictionary = Game.buy(s, 0, 0, "hero")
		eq(h.rank, 3, "level kept")
		s.heroDeaths.p = 9
		eq(Game.hero_cost(s, "p"), 1000)
	)
	run("AE2 unit cap: campaign 100 unless the mission sets one; skirmish keeps its chosen cap", func() -> void:
		for m: Dictionary in Content.campaign():
			eq(Game.new_game(m).unitCap, m.get("unitCap", 100), m.id)
		eq(Game.new_game(Content.skirmish_def("dong_bang", "anhhung", false)).unitCap, 15, "skirmish default")
		eq(Game.new_game(Content.skirmish_def("dong_bang", "anhhung", false, 300, 30)).unitCap, 30, "skirmish chosen")
		var d: Dictionary = Content.mission("m02").duplicate()
		d.unitCap = 12
		eq(Game.new_game(d).unitCap, 12, "mission override")
	)
	run("AE2 titles: 4 tiers (0-1 none, 2-3, 4-5, 6-9); commanders only ★N; big level-up only on renames", func() -> void:
		eq(Content.unit_title("Bộ binh", 0), "Bộ binh")
		eq(Content.unit_title("Bộ binh", 1), "Bộ binh ★1")
		eq(Content.unit_title("Bộ binh", 3), "Bộ binh lão luyện ★3")
		eq(Content.unit_title("Bộ binh", 5), "Bộ binh tinh nhuệ ★5")
		eq(Content.unit_title("Bộ binh", 6), "Bộ binh dũng mãnh ★6")
		eq(Content.unit_title("Bộ binh", 9), "Bộ binh dũng mãnh ★9")
		eq(Content.unit_title("Anh hùng", 4, true), "Anh hùng ★4")
		var loud := []
		for r in range(1, 10):
			if Content.rank_announced("soldier", r):
				loud.append(r)
		eq(loud, [2, 4, 6])
		check(not Content.rank_announced("hero", 2), "commander: no rename announcement")
	)
	run("mission order values are unique", func() -> void:
		var seen := {}
		for m: Dictionary in Content.campaign():
			check(not seen.has(m.order), "duplicate order %s (%s)" % [m.order, m.id])
			seen[m.order] = true
	)
	run("saves of an older state version / unknown unit type are refused", func() -> void:
		var s := Game.new_game(Content.mission("m03"))
		var old: Dictionary = s.duplicate(true)
		old.v = 1
		check(not Content.save_fits({ "state": old, "ctx": { "kind": "campaign", "id": "m03" } }), "old version refused")
		var bad: Dictionary = s.duplicate(true)
		bad.units[0].type = "wizard"
		check(not Content.save_fits({ "state": bad, "ctx": { "kind": "campaign", "id": "m03" } }), "unknown unit refused")
		var nowin: Dictionary = s.duplicate(true)
		nowin.win = { "type": "teleport" }
		check(not Content.save_fits({ "state": nowin, "ctx": { "kind": "campaign", "id": "m03" } }), "unknown win type refused")
	)
	run("goal / end texts: every win type has copy, unknown types fall back", func() -> void:
		for t: String in Content.WIN_TYPES:
			check(Content.goal_text({ "type": t, "turns": 5, "at": [[0, 0]] }, "brief", { "p": "anhhung", "e": "tuonggiac" }) != t, "brief copy " + t)
			check(Content.goal_text({ "type": t, "turns": 5, "at": [[0, 0]] }, "bar", { "p": "anhhung", "e": "tuonggiac" }, { "n": 1, "left": 2 }) != t, "bar copy " + t)
		eq(Content.goal_text({ "type": "teleport" }, "brief", { "p": "anhhung", "e": null }), "teleport")
		check(Content.tile_note("c").find("tướng") >= 0, "castle note names who captures")
	)
	run("save round-trip keeps types", func() -> void:
		var s := Game.new_game(Content.mission("m02"))
		var back: Dictionary = str_to_var(var_to_str(s))
		eq(back, s)
		check(back.owner.keys()[0] is Vector2i, "Vector2i keys")
		check(back.units[0].hp is int, "int hp")
	)
	run("saves from older content are refused (removed commander / mission), current ones kept", func() -> void:
		var s := Game.new_game(Content.mission("m03"))
		check(Content.save_fits({ "state": s, "ctx": { "kind": "campaign", "id": "m03" } }), "current save fits")
		var old: Dictionary = s.duplicate(true)
		old.heroKey.p = "trungnhi" # unknown commander key
		check(not Content.save_fits({ "state": old, "ctx": { "kind": "campaign", "id": "m03" } }), "unknown commander refused")
		# saves from before the two-commander change: named commanders map onto the fixed ones (same stats)
		var named: Dictionary = { "state": s.duplicate(true), "ctx": { "kind": "skirmish", "hero": "trungtrac", "easy": false } }
		named.state.heroKey = { "p": "trungtrac", "e": "mavien" }
		Content.migrate_save(named)
		eq([named.state.heroKey.p, named.state.heroKey.e, named.ctx.hero], ["anhhung", "tuonggiac", "anhhung"])
		check(Content.save_fits(named), "migrated save fits")
		check(not Content.save_fits({ "state": s, "ctx": { "kind": "campaign", "id": "m20" } }), "removed mission refused")
		check(not Content.save_fits({ "state": s, "ctx": { "kind": "skirmish", "hero": "lechan", "easy": false } }), "old skirmish hero refused")
		eq(Content.hero_look("lechan").name, "lechan") # stale key: placeholder, no crash
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
		var el: Dictionary = s.units.filter(func(u: Dictionary) -> bool: return u.side == "p" and u.type == "soldier")[0]
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


# ---------- regression games (sim/golden.txt, current rules) ----------
func parity_tests() -> void:
	run("rules + AI still play the golden games (m01, m07, sk_dong_bang, naive)", func() -> void:
		var golden := {}
		for line: String in FileAccess.get_file_as_string("res://sim/golden.txt").split("\n", false):
			var p := line.split(" ", false, 2)
			golden[p[0] + " " + p[1]] = p[2]
		var tr: RefCounted = load("res://sim/parity.gd").new()
		tr.apply()
		for key: String in ["m01 0", "m07 1", "sk_dong_bang 0", "naive 0"]:
			eq(tr.replay(key), golden.get(key, "?"), key)
		tr.restore()
	)
