extends SceneTree
## headless tests: <godot> --headless --path . -s sim/tests.gd   -> exit code 1 on failure

const Parity := preload("res://sim/parity.gd")

var failed := 0
var passed := 0
var _cur := ""
var _ok := true

func check(cond: bool, msg: String) -> void:
	if not cond:
		_ok = false
		printerr("  FAIL %s: %s" % [_cur, msg])

func eq(a: Variant, b: Variant, msg := "") -> void:
	var same: bool = a == b
	check(same, "%s expected %s got %s" % [msg, b, a])

## s.units / s.owner / s.graves read fresh (Game swaps s.units when a unit dies)
static func units_of(s: Dictionary) -> Array:
	return s.units

static func unit(s: Dictionary, i: int) -> Dictionary:
	return s.units[i]

static func owner_of(s: Dictionary) -> Dictionary:
	return s.owner

static func graves_of(s: Dictionary) -> Array:
	return s.graves

static func acted(u: Dictionary) -> bool:
	return u.acted

static func id_of(u: Dictionary) -> int:
	return u.id

## unit tile
static func pos(u: Dictionary) -> Vector2i:
	var x: int = u.x
	var y: int = u.y
	return Vector2i(x, y)

## tile from a[i], a[i + 1]
static func xy(a: Array, i := 0) -> Vector2i:
	var x: int = a[i]
	var y: int = a[i + 1]
	return Vector2i(x, y)

static func mission(id: String) -> Dictionary:
	return Content.mission(id)

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
	duel_tests()
	print("tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

# ---------- content ----------
func content_tests() -> void:
	var all: Array = Content.campaign().duplicate()
	var hero_p: String = Content.heroes_of("p")[0]
	var hero_e1: String = Content.heroes_of("e")[0]
	for mid: String in Content.SKIRMISH.MAPS:
		all.append(Content.skirmish_def(mid, hero_p, false))
		all.append(Content.duel_def(mid, hero_p, hero_e1, "human"))
	run("skirmish: new maps are 180° rotations (fair start)", func() -> void:
		for mid: String in ["cua_bien", "nui_rung"]:
			var rows: Array = Content.SKIRMISH.MAPS[mid].rows
			for y in rows.size():
				var mirror: String = rows[rows.size() - 1 - y]
				eq(rows[y], mirror.reverse(), "%s row %d" % [mid, y])
	)
	eq(Content.campaign().size(), 16, "campaign size")
	run("chapters: 2 chapters, every mission in one, missions of a chapter are consecutive", func() -> void:
		eq(Content.chapters().map(func(c: Dictionary) -> String: return c.id), ["c1", "c2"])
		var seen := []
		for m: Dictionary in Content.campaign():
			var c := Content.chapter_of(m)
			check(Content.chapter(c) != null, "chapter of %s" % m.id)
			if seen.is_empty() or seen.back() != c:
				check(not seen.has(c), "chapter %s split" % c)
				seen.append(c)
		for c: Dictionary in Content.chapters():
			for key: String in ["title", "subtitle", "rivers", "labels", "outro"]:
				check(c.has(key), "%s.%s" % [c.id, key])
			var cid: String = c.id
			check(Content.missions_of(cid).size() >= 6, cid + " has missions")
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
			var hu: Dictionary = hero
			var mc: String = Game.stat(s, hu).move
			var seen := { pos(hu): true }
			var q := [pos(hu)]
			while q.size():
				var c: Vector2i = q.pop_back()
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := c + d
					if not seen.has(n) and Game.tile_at(s, n.x, n.y) != null and Game.move_cost(mc, Game.tile_at(s, n.x, n.y)) < INF:
						seen[n] = true
						q.append(n)
			var need := []
			for y: int in s.h:
				for x: int in s.w:
					if Game.sells(s.tiles[y][x]):
						need.append(Vector2i(x, y))
			for u: Dictionary in s.units:
				if u.side == "e" and u.type == "hero":
					need.append(pos(u))
			var win: Dictionary = s.win
			for at: Array in win.get("at", []):
				need.append(xy(at))
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
			var mid: String = m.id
			eq(m.hero, "anhhung", mid)
			var eh_ok: bool = m.enemyHero == null or m.enemyHero == "tuonggiac"
			check(eh_ok, mid + " enemy commander")
		for mid: String in Content.SKIRMISH.MAPS:
			eq(Content.skirmish_def(mid, "anhhung", false).enemyHero, "tuonggiac", mid)
	)
	run("reach: hero on the goal wins, time runs out loses", func() -> void:
		var s := Game.new_game(mission("m13"))
		var hero: Dictionary = units_of(s).filter(func(u: Dictionary) -> bool: return u.type == "hero")[0]
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
		var s2 := Game.new_game(mission("m13"))
		for i in 60:
			if s2.winner != null:
				break
			Game.end_turn(s2)
		eq(s2.winner, "e")
		eq(s2.reason, "timeUp")
	)
	for def: Dictionary in all:
		run("content valid: %s" % def.id, func() -> void:
			var rows: Array = def.map.rows
			for r: String in rows:
				var row0: String = rows[0]
				check(r.length() == row0.length(), "rows equal length")
				for i in r.length():
					check(Rules.TERRAIN.has(r[i]), "unknown tile " + r[i])
			var s := Game.new_game(def)
			var seen := {}
			for u: Dictionary in s.units:
				var mc: String = Game.stat(s, u).move
				var at := pos(u)
				check(Game.move_cost(mc, Game.tile_at(s, at.x, at.y)) != INF, "%s %s on impassable %d,%d" % [u.side, u.type, u.x, u.y])
				check(not seen.has(at), "two units on %d,%d" % [u.x, u.y])
				seen[at] = true
			for key: Vector2i in s.owner:
				check(Game.cap_flag(Game.tile_at(s, key.x, key.y)) != "", "owner on non-building %s" % key)
			for side: String in ["p", "e"]:
				if units_of(s).any(func(u: Dictionary) -> bool: return u.side == side and u.type == "hero"):
					check(s.heroKey[side] != null, side + " hero unit but no hero key")
			for w: Dictionary in def.get("waves", []):
				for wu: Array in w.units:
					var at := xy(wu, 1)
					check(Game.tile_at(s, at.x, at.y) != null, "wave off map %d,%d" % [wu[1], wu[2]])
					check(Rules.UNITS.has(wu[0]), "wave unit type " + str(wu[0]))
					var wst := Game.stat(s, { "type": wu[0], "side": "e" })
					var mc: String = wst.move
					check(Game.move_cost(mc, Game.tile_at(s, at.x, at.y)) != INF, "wave %s on impassable %d,%d" % [wu[0], wu[1], wu[2]])
			# win schema
			eq(Objectives.check(s), "", "win spec")
			for side: String in ["p", "e"]:
				for t: String in s.allowed[side]:
					var ut: Dictionary = Rules.UNITS[t]
					check(ut.has("aiWeight"), "no aiWeight (AI falls back to DEFAULT_WEIGHT) for " + t)
			for t: String in def.get("newUnits", []):
				check(Rules.UNITS.has(t), "newUnits " + t)
			for side: String in ["p", "e"]:
				var skins: Dictionary = Content.theme().units[side]
				for t: String in s.allowed[side]:
					check(skins.has(t), "no skin %s %s" % [side, t])
			var story: Dictionary = def.get("story", {})
			for line: Array in story.get("intro", []) + story.get("outro", []):
				var who: String = line[0]
				var named: bool = Content.speaker(who).icon != "💬"
				check(named, "speaker " + who)
			check(s.winner == null, "no winner at start")
			# foot path from hero to enemy castle on castle maps
			if s.win.type == "castles":
				var hero: Dictionary = units_of(s).filter(func(u: Dictionary) -> bool: return u.side == "p" and u.type == "hero")[0]
				var goal: Vector2i = Game.castle_tiles(s, "e")[0]
				var seen_p := { pos(hero): true }
				var q := [pos(hero)]
				while q.size():
					var c: Vector2i = q.pop_front()
					for d: Array in Game.DIRS:
						var n := c + xy(d)
						if seen_p.has(n) or Game.move_cost("foot", Game.tile_at(s, n.x, n.y)) == INF:
							continue
						seen_p[n] = true
						q.append(n)
				check(seen_p.has(goal), "foot path to enemy castle")
		)
	run("theme: every terrain painter has the colors it reads", func() -> void:
		var need := { "field": ["base", "line"], "forest": ["base", "tree", "tree2"], "hill": ["base", "hill", "hill2"],
			"mountain": ["base", "rock", "rock2", "snow"], "water": ["base", "deep", "wave"], "bridge": ["base", "deep", "plank", "plank2"],
			"village": ["base", "line", "wall"], "castle": ["base", "wall", "wall2"] }
		for ch: String in Content.theme().terrain:
			var t: Dictionary = Content.theme().terrain[ch]
			check(Rules.TERRAIN.has(ch), "theme tile %s has rules" % ch)
			for key: String in need.get(t.paint, []):
				check(t.has(key), "%s (%s) missing %s" % [ch, t.paint, key])
		var terrain: Dictionary = Content.theme().terrain
		for ch: String in Rules.TERRAIN:
			check(terrain.has(ch), "rules tile %s has theme" % ch)
	)

# ---------- rules ----------
func blank(units: Array) -> Dictionary:
	var s := Game.new_game(Content.skirmish_def("dong_bang", "anhhung", false))
	var tiles := []
	s.tiles = tiles
	for y in 6:
		tiles.append([".", ".", ".", ".", ".", "."])
	s.w = 6
	s.h = 6
	s.owner = { Vector2i(0, 0): "p", Vector2i(5, 5): "e" }
	s.tiles[0][0] = "c"
	s.tiles[5][5] = "c"
	var list := []
	s.units = list
	s.nextId = 1
	s.hadCastle = { "p": true, "e": true }
	for spec: Array in units:
		list.append({ "id": s.nextId, "side": spec[0], "type": spec[1], "x": spec[2], "y": spec[3], "hp": spec[4] if spec.size() > 4 else 100,
			"xp": 0, "rank": 0, "acted": false })
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
		check(not owner_of(s).has(Vector2i(4, 1)), "owner cleared")
		check(ev.any(func(e: Dictionary) -> bool: return e.t == "raze" and e.prev == "e"), "raze event with prev owner")
		check(acted(c), "catapult done for the turn")
		eq(Game.income(s, "e"), Rules.TERRAIN.c.income, "enemy lost the village income")
	)
	run("ruined village: no capture; capV unit repairs -> unowned village, capture on a later turn", func() -> void:
		var s := blank([["p", "soldier", 2, 2], ["p", "archer", 3, 3], ["e", "soldier", 5, 4]])
		var sol: Dictionary = s.units[0]
		s.tiles[2][2] = "x"
		check(not Game.can_capture(s, sol, 2, 2), "cannot capture a ruin")
		check(not Game.can_repair(s, unit(s, 1), 2, 2), "archer cannot repair")
		check(Game.can_repair(s, sol, 2, 2), "soldier can repair")
		Game.do_action(s, { "id": sol.id, "to": [2, 2], "kind": "repair" })
		eq(s.tiles[2][2], "v", "repaired")
		check(not owner_of(s).has(Vector2i(2, 2)), "still unowned")
		check(acted(sol), "repair takes the turn")
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
		var mem := {}
		var st2: Dictionary = AI.next_step(s2, mem)
		AI.apply_step(s2, st2)
		eq(s2.tiles[3][4], "v", "AI soldier repaired the adjacent ruin (got %s)" % [st2.act])
	)
	run("illegal capture / raise changes nothing (unit stays, can still act)", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 4, 4]])
		var u: Dictionary = s.units[0]
		var n: int = units_of(s).size()
		Game.do_action(s, { "id": u.id, "to": [2, 2], "kind": "capture" }) # plain field: nothing to capture
		eq([u.x, u.y], [1, 1], "position")
		check(not acted(u), "still can act")
		Game.do_action(s, { "id": u.id, "to": [2, 1], "kind": "raise", "target": [3, 1] }) # soldier cannot raise, no grave
		eq([u.x, u.y], [1, 1], "position after bad raise")
		eq(units_of(s).size(), n, "no unit spawned")
	)
	run("AE2: raised ghosts ignore the unit cap and do not count toward it", func() -> void:
		var s := blank([["p", "shaman", 1, 1], ["e", "soldier", 4, 4]])
		s.graves = [{ "x": 2, "y": 1, "ttl": 2 }]
		s.unitCap = 1
		eq(Game.raisable_graves(s, unit(s, 0), 1, 1).size(), 1, "raise at cap")
		Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "raise", "target": [2, 1] })
		eq(Game.cap_count(s, "p"), 1, "ghost not counted")
	)
	run("AE2 graves: ttl 3, down 1 at every side's turn start; stepping on one clears it", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 4, 4]])
		s.graves = [{ "x": 3, "y": 3, "ttl": Rules.RULES.graveRounds }]
		Game.end_turn(s); Game.end_turn(s)
		eq(graves_of(s).size(), 1, "alive after 2 half-turns")
		Game.end_turn(s)
		eq(graves_of(s).size(), 0, "gone after 3")
		s.graves = [{ "x": 2, "y": 1, "ttl": 3 }]
		s.side = "p"
		s.units[0].acted = false
		Game.do_action(s, { "id": 1, "to": [2, 1], "kind": "wait" })
		eq(graves_of(s).size(), 0, "stepped on")
	)
	run("buildings are descriptors: a new tile type works from TERRAIN alone (income, capture, heal, sells, raze / repair)", func() -> void:
		var ter: Dictionary = Rules.TERRAIN.duplicate(true)
		ter["p"] = { "def": 10, "cost": 1, "building": "port", "income": 40, "cap": "capV", "heals": "owner", "razeTo": "q" }
		ter["q"] = { "def": 5, "cost": 1, "repairTo": "p", "repairBy": "capV" }
		ter["o"] = { "def": 20, "cost": 1, "building": "fort", "income": 10, "cap": "capC", "heals": "owner", "sells": true }
		Game.use_tables(Rules.UNITS, Rules.HEROES, Rules.RULES, ter)
		eq([Game.income_of("p"), Game.income_of("."), Game.sells("o"), Game.sells("p"), Game.cap_flag("o"), Game.cap_flag("t")],
			[40, 0, true, false, "capC", ""])
		var s := blank([["p", "soldier", 2, 2, 50], ["p", "hero", 3, 3], ["e", "catapult", 5, 1]])
		s.tiles[2][2] = "p"
		s.tiles[3][3] = "o"
		check(Game.can_capture(s, unit(s, 0), 2, 2), "soldier takes a port (cap capV)")
		check(not Game.can_capture(s, unit(s, 0), 3, 3) and Game.can_capture(s, unit(s, 1), 3, 3), "fort needs capC")
		Game.do_action(s, { "id": 1, "to": [2, 2], "kind": "capture" })
		Game.do_action(s, { "id": 2, "to": [3, 3], "kind": "capture" })
		eq(Game.income(s, "p"), 50 + 40 + 10, "income = sum over owned tiles")
		eq(Game.castle_tiles(s, "p"), [Vector2i(0, 0), Vector2i(3, 3)], "fort sells")
		check(Game.buy_options(s, "p", 3, 3).size() > 0 and Game.buy_options(s, "p", 2, 2).is_empty(), "buy only where it sells")
		Game.end_turn(s); Game.end_turn(s)
		eq(s.units[0].hp, 70, "port heals its owner")
		s.units[0].x = 1
		s.units[1].x = 4; s.units[1].y = 4
		s.side = "e"
		s.units[2].acted = false
		check(Game.razable_from(s, unit(s, 2), 5, 1).has([2, 2]), "port razable (razeTo)")
		Game.do_action(s, { "id": 3, "to": [5, 1], "kind": "raze", "target": [2, 2] })
		eq(s.tiles[2][2], "q", "razed into razeTo")
		Game.end_turn(s)
		s.units[0].acted = false
		check(Game.can_repair(s, unit(s, 0), 2, 2), "repairBy capV")
		Game.do_action(s, { "id": 1, "to": [2, 2], "kind": "repair" })
		eq(s.tiles[2][2], "p", "repaired into repairTo")
		Game.use_tables(Rules.UNITS, Rules.HEROES, Rules.RULES, Rules.TERRAIN)
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
		eq(Game.damage(e, unit(e, 0), 1, 1, 100, unit(e, 1), 0.0), 0, "armour soaks the hit")
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
		check(Game.can_counter(s, unit(s, 1), 1, 1), "archer adjacent counters")
		check(not Game.can_counter(s, unit(s, 1), 0, 1), "archer at 2 does not")
		check(not Game.can_counter(s, unit(s, 2), 1, 1), "catapult never")
	)
	run("AE2 drum: after acting, allies within 2 get +10 atk until the drum side's next turn", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["p", "drum", 1, 3], ["p", "archer", 4, 1], ["e", "soldier", 2, 1]])
		var a: Dictionary = s.units[0]
		var d: Dictionary = s.units[3]
		var before := Game.damage(s, a, 1, 1, 100, d, 0.0)
		Game.do_action(s, { "id": 2, "to": [1, 3], "kind": "wait" })
		var buffed: bool = a.get("aura") == "p" and unit(s, 2).get("aura") == null
		check(buffed, "soldier (2 away) buffed, archer (far) not")
		eq(Game.damage(s, a, 1, 1, 100, d, 0.0), before + 10)
		eq(Game.buffs_at(s, a, 1, 1).atk, 10, "buffs_at shows it")
		Game.end_turn(s)
		var lasts: bool = a.get("aura") == "p"
		check(lasts, "lasts through the enemy turn")
		Game.end_turn(s)
		check(a.get("aura") == null, "gone at our next turn")
		eq(Content.traits("drum", null).any(func(t: String) -> bool: return "+10 công" in t), true)
		# AE2: a drum killed by the counter still drums, from the tile it fell on (RM Unit.finishMove)
		var k := blank([["p", "drum", 1, 1, 1], ["p", "soldier", 1, 3], ["p", "archer", 4, 4], ["e", "soldier", 2, 2]])
		Game.fixed_roll = 0.0
		Game.do_action(k, { "id": 1, "to": [1, 2], "kind": "attack", "target": 4 })
		Game.fixed_roll = -1.0
		check(Game.unit_by_id(k, 1) == null, "drum died")
		var near_buffed: bool = unit(k, 0).get("aura") == "p"
		check(near_buffed, "ally 1 from the death tile buffed")
		var far_plain: bool = unit(k, 1).get("aura") == null
		check(far_plain, "far ally not")
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
		var hits: Array = ev.filter(func(e: Dictionary) -> bool: return e.t == "hit" or e.t == "poison")
		var order: Array = hits.map(func(e: Dictionary) -> String: return "c" if e.get("counter", false) else e.t)
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
		eq(Game.damage(s, b, 1, 1, 100, unit(s, 1), 0.0), 50, "50 + 10 water - 10")
		eq(Game.damage(s, unit(s, 1), 2, 1, 100, b, 0.0), 25, "50 - (10 + 15)")
	)
	run("temple heals any side, cannot be captured", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 3, 3, 50]])
		s.tiles[3][3] = "t"
		check(not Game.can_capture(s, unit(s, 0), 3, 3), "no capture")
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
		eq(Game.targets_from(s, unit(s, 0), 2, 1).size(), 0)
		eq(Game.targets_from(s, unit(s, 0), 1, 1).size(), 1)
	)
	run("rules tables = docs/spec.md (cost, atk, atkMax, def, mv, rmin, rmax; terrain def / cost)", func() -> void:
		var spec := { "hero": [200, 55, 65, 20, 5, 1, 1], "soldier": [150, 50, 55, 5, 5, 1, 1], "archer": [250, 50, 55, 5, 5, 1, 2],
			"boat": [300, 50, 55, 10, 5, 1, 1], "shaman": [400, 40, 45, 5, 5, 1, 1], "drum": [500, 35, 40, 10, 5, 1, 1],
			"wolf": [600, 60, 65, 15, 6, 1, 1], "elephant": [600, 60, 70, 30, 5, 1, 1], "catapult": [700, 50, 70, 10, 4, 2, 4],
			"bird": [1000, 70, 80, 25, 7, 1, 1], "ghost": [150, 40, 50, 2, 5, 1, 1] }
		for t: String in spec:
			var u: Dictionary = Rules.UNITS[t]
			eq([u.cost, u.atk, u.atkMax, u.def, u.mv, u.rmin, u.rmax], spec[t], t)
		eq(Rules.UNITS.keys().size(), spec.size(), "unit types")
		var ter := { ".": [5, 1], "r": [0, 1], "f": [10, 2], "h": [10, 2], "m": [15, 3], "~": [0, 3], "=": [5, 1],
			"v": [15, 1], "c": [15, 1], "x": [15, 1], "t": [15, 1] }
		for k: String in ter:
			eq([Rules.TERRAIN[k].def, Rules.TERRAIN[k].cost], ter[k], "terrain " + k)
	)
	run("AE2 damage modifiers: archer vs fly, drum vs ghost, poisoned attacker, defender rank, flyer terrain def", func() -> void:
		var s := blank([["p", "archer", 1, 1], ["p", "soldier", 1, 2], ["e", "bird", 2, 1], ["p", "drum", 3, 3], ["e", "ghost", 4, 3],
			["e", "soldier", 2, 2]])
		var ar: Dictionary = s.units[0]
		var so: Dictionary = s.units[1]
		var bird: Dictionary = s.units[2]
		var foe: Dictionary = s.units[5]
		eq(Game.damage(s, ar, 1, 1, 100, bird, 0.0) - Game.damage(s, so, 1, 1, 100, bird, 0.0), 15, "archer +15 vs flyer")
		eq(Game.damage(s, unit(s, 3), 3, 3, 100, unit(s, 4), 0.0), 43, "drum 35 +15 vs ghost - 2 def - 5 field")
		eq(Game.damage(s, so, 1, 2, 100, foe, 0.0), 40, "plain soldier hit")
		so.poison = "e"
		so.poisonAmt = 10
		eq(Game.damage(s, so, 1, 2, 100, foe, 0.0), 30, "poisoned attacker -10 atk")
		so.erase("poison")
		foe.rank = 2
		eq(Game.damage(s, so, 1, 2, 100, foe, 0.0), 36, "defender rank 2 -> +4 def")
		var field := Game.damage(s, so, 1, 1, 100, bird, 0.0)
		s.tiles[1][2] = "f"
		eq(field - Game.damage(s, so, 1, 1, 100, bird, 0.0), 5, "flyer still gets terrain def (forest 10 vs field 5)")
	)
	run("AE2 levels: capped at 9; an attacker killed by the counter does not level", func() -> void:
		var s := blank([["p", "soldier", 1, 1], ["e", "soldier", 2, 1], ["p", "soldier", 3, 3, 1], ["e", "elephant", 4, 3]])
		s.units[0].rank = Rules.RULES.maxRank
		s.units[0].xp = 10000000
		Game.fixed_roll = 0.0
		var ev := Game.do_action(s, { "id": 1, "to": [1, 1], "kind": "attack", "target": 2 })
		eq(s.units[0].rank, Rules.RULES.maxRank, "stays at max")
		check(not ev.any(func(e: Dictionary) -> bool: return e.t == "rank"), "no rank event at max")
		var weak: Dictionary = s.units[2]
		weak.xp = 10000000
		var ev2 := Game.do_action(s, { "id": weak.id, "to": [3, 3], "kind": "attack", "target": s.units[3].id })
		check(Game.unit_by_id(s, id_of(weak)) == null, "killed by the counter")
		check(not ev2.any(func(e: Dictionary) -> bool: return e.t == "rank" and e.id == weak.id), "dead attacker never ranks up")
	)
	run("loss: a side that captures its first castle mid-game falls like a castled side (spec: never held a castle)", func() -> void:
		var s := blank([["p", "hero", 3, 3], ["e", "hero", 4, 4], ["e", "soldier", 1, 4]])
		owner_of(s).erase(Vector2i(5, 5))
		s.tiles[5][5] = "c"
		s.hadCastle.e = false
		s.side = "e"
		Game.do_action(s, { "id": 2, "to": [5, 5], "kind": "capture" })
		var had: bool = s.hadCastle.e
		check(had, "capturing a castle marks the side")
		s.owner[Vector2i(5, 5)] = "p" # we retake it
		s.units = units_of(s).filter(func(u: Dictionary) -> bool: return u.id != 2)
		s.heroDead.e = true
		eq(Game.loss_reason(s, "e"), "castlesLost", "no castle + commander dead, army left")
	)
	run("reach mission: commander dead and no castle to rebuy it = lost (no soft-lock until timeUp)", func() -> void:
		var s := blank([["p", "soldier", 3, 3], ["e", "soldier", 5, 4]])
		s.win = { "type": "reach", "at": [[2, 5]] }
		owner_of(s).erase(Vector2i(0, 0))
		s.hadCastle.p = false
		s.heroDead.p = true
		eq(Game.loss_reason(s, "p"), "heroFell")
		s.owner[Vector2i(0, 0)] = "p"
		eq(Game.loss_reason(s, "p"), null, "a castle left: can rebuy, still playing")
	)
	run("AI: commander rebought on the reach goal steps off (offGoal) instead of waiting there", func() -> void:
		var s := blank([["e", "soldier", 5, 4]])
		s.win = { "type": "reach", "at": [[0, 0]] }
		s.heroDead.p = true
		s.heroKey.p = "anhhung"
		s.gold.p = 1000
		var h: Dictionary = Game.buy(s, 0, 0, "hero")
		AI.rng = func() -> float: return 0.5
		var step: Variant = AI.next_step(s, {})
		AI.rng = AI._gen.randf
		var acts: bool = step != null and step.kind == "act" and step.act.id == h.id
		check(acts, "acts with the commander")
		var leaves: bool = step != null and step.act.to != [0, 0]
		check(leaves, "leaves the goal tile (got %s)" % [step.act.to if step != null else null])
	)
	run("AE2 loss: castles gone AND commander dead; hero capture of the last castle wins only then", func() -> void:
		var s := blank([["p", "soldier", 4, 4], ["p", "hero", 4, 5], ["e", "hero", 1, 4]])
		s.tiles[3][4] = "v"
		check(not Game.can_capture(s, unit(s, 0), 5, 5), "soldier vs castle")
		check(Game.can_capture(s, unit(s, 0), 4, 3), "soldier vs village")
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
		eq(graves_of(s).size(), 1)
		Game.do_action(s, { "id": 3, "to": [2, 2], "kind": "raise", "target": [2, 1] })
		check(units_of(s).any(func(u: Dictionary) -> bool: return u.type == "ghost" and u.side == "p"), "ghost raised")
	)
	run("income + heal at turn start; buy respects cap", func() -> void:
		var s := blank([["p", "soldier", 0, 0, 50], ["e", "soldier", 5, 4]])
		s.side = "e"
		s.gold.p = 0
		Game.end_turn(s)
		eq(s.gold.p, Rules.TERRAIN.c.income)
		eq(s.units[0].hp, 70)
		s.units[0].x = 1
		s.gold.p = 99999
		for i in 19:
			units_of(s).append({ "id": 100 + i, "side": "p", "type": "soldier", "x": 3, "y": i % 6, "hp": 100, "xp": 0, "rank": 0 })
		check(Game.buy_options(s, "p", 0, 0).all(func(o: Dictionary) -> bool: return not o.ok), "cap blocks buy")
	)
	run("AE2 buy: new unit acts at once; buy on own-occupied castle -> must step off", func() -> void:
		var s := blank([["p", "soldier", 0, 0], ["e", "soldier", 5, 4]])
		s.gold.p = 5000
		var ok := func(t: String) -> bool: return Game.buy_options(s, "p", 0, 0).any(func(o: Dictionary) -> bool: return o.type == t and o.ok)
		var can_archer: bool = ok.call("archer")
		check(can_archer, "buy allowed with our soldier on the castle")
		var a: Dictionary = Game.buy(s, 0, 0, "archer")
		check(not acted(a), "bought unit can act this turn")
		check(Game.stacked(s, a) and Game.stacked(s, unit(s, 0)), "both stacked")
		check(not Game.reachable(s, a).has(Vector2i(0, 0)), "new unit cannot stay on the shared tile")
		check(not Game.reachable(s, unit(s, 0)).has(Vector2i(0, 0)), "old unit cannot stay either")
		check(Game.buy_options(s, "p", 0, 0).is_empty(), "no 3rd unit on a stacked castle")
		eq(Game.do_action(s, { "id": a.id, "to": [0, 0], "kind": "wait" }), [], "wait in place rejected")
		Game.do_action(s, { "id": a.id, "to": [1, 1], "kind": "wait" })
		check(not Game.stacked(s, unit(s, 0)), "stack cleared after stepping off")
		var can_again: bool = ok.call("soldier")
		check(can_again, "can buy again on the same castle this turn")
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
		check(Game.unbuy(s, id_of(a)), "unbuy ok")
		eq(s.gold.p, 1000, "full refund")
		check(Game.unit_by_id(s, id_of(a)) == null and not Game.stacked(s, unit(s, 0)), "new unit gone, castle unit alone")
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
		var undone: bool = Game.unbuy(h, id_of(hero)) and h.heroDead.p and h.gold.p == 1000 and Game.hero_cost(h, "p") == cost
		check(undone, "commander rebuy taken back: dead again, same price")
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
			var sd: Dictionary = st
			AI.apply_step(s, sd)
		var nu: Array = units_of(s).filter(func(u: Dictionary) -> bool: return u.side == "e" and u.type != "hero")
		check(bought and nu.size() == 1, "AI bought")
		var nu_acted: bool = nu.size() == 1 and nu[0].acted
		check(nu_acted, "bought unit acted this turn")
	)
	run("AI buys under a unit on its castle (own acted / enemy), never a boat without water", func() -> void:
		var s := blank([["p", "soldier", 0, 0], ["e", "hero", 5, 5]])
		s.side = "e"
		s.gold.e = 300
		s.units[1].acted = true
		var st: Variant = AI.next_step(s, {})
		var under_own: bool = st != null and st.kind == "buy" and st.x == 5 and st.y == 5
		check(under_own, "buys under own acted hero (got %s)" % [st])
		var no_boat: bool = st == null or st.type != "boat"
		check(no_boat, "no boat on a dry map")
		var c := blank([["p", "soldier", 0, 0], ["p", "soldier", 5, 5], ["e", "hero", 3, 0]])
		c.side = "e"
		c.gold.e = 150
		c.units[2].acted = true
		var st2: Variant = AI.next_step(c, {})
		var under_foe: bool = st2 != null and st2.kind == "buy"
		check(under_foe, "buys under an enemy on its castle (got %s)" % [st2])
	)
	run("AI commander: healthy -> advances through one unit's threat (no retreat to a safe rear tile); "
		+ "hurt -> never ends where it can die", func() -> void:
		var wide := func(units: Array) -> Dictionary:
			var s := blank(units)
			s.w = 12
			s.h = 7
			var tiles := []
			s.tiles = tiles
			for y in 7:
				var row := []
				row.resize(12)
				row.fill(".")
				tiles.append(row)
			s.tiles[0][0] = "c"
			s.tiles[6][11] = "c"
			s.owner = { Vector2i(0, 0): "p", Vector2i(11, 6): "e" }
			s.side = "e"
			return s
		AI.rng = func() -> float: return 0.5
		# user report (m07): commander backed off to a tile nobody threatens instead of heading for the fight
		var a: Dictionary = wide.call([["e", "hero", 8, 3], ["p", "soldier", 0, 3]])
		var st: Variant = AI.next_step(a, {})
		var to_a: Array = st.act.to
		var to := xy(to_a)
		var gd := mini(Game.dist(to.x, to.y, 0, 3), Game.dist(to.x, to.y, 0, 0))
		check(gd <= 4, "commander closes in (dist to nearest goal %d, start 8, got %s)" % [gd, st.act])
		var b: Dictionary = wide.call([["e", "hero", 8, 3, 35], ["p", "soldier", 1, 2], ["p", "soldier", 1, 4], ["p", "archer", 0, 3]])
		var st2: Variant = AI.next_step(b, {})
		var h: Dictionary = b.units[0]
		h.x = st2.act.to[0]
		h.y = st2.act.to[1]
		var worst := 0
		for e: Dictionary in AI.threat_map(b, "e").get(pos(h), []):
			var e_hp: int = e.hp
			worst += Game.damage(b, e, pos(e).x, pos(e).y, e_hp, h, Game.ROLL_TOP)
		var survives: bool = worst < h.hp
		check(survives, "hurt commander out of lethal reach (max incoming %d vs hp %d at %s)" % [worst, h.hp, st2.act.to])
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
		@warning_ignore("integer_division")
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
				@warning_ignore("integer_division")
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
		var dead: bool = s.heroDead.p
		check(dead, "dead")
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
			eq(Game.new_game(m).unitCap, m.get("unitCap", 100), str(m.id))
		eq(Game.new_game(Content.skirmish_def("dong_bang", "anhhung", false)).unitCap, 15, "skirmish default")
		eq(Game.new_game(Content.skirmish_def("dong_bang", "anhhung", false, 300, 30)).unitCap, 30, "skirmish chosen")
		var d: Dictionary = mission("m02").duplicate()
		d.unitCap = 12
		eq(Game.new_game(d).unitCap, 12, "mission override")
	)
	run("AE2 titles: 4 tiers (0-1 none, 2-3, 4-5, 6-9); commanders only LvN; big level-up only on renames", func() -> void:
		eq(Content.unit_title("Bộ binh", 0), "Bộ binh")
		eq(Content.unit_title("Bộ binh", 1), "Bộ binh Lv1")
		eq(Content.unit_title("Bộ binh", 3), "Bộ binh lão luyện Lv3")
		eq(Content.unit_title("Bộ binh", 5), "Bộ binh tinh nhuệ Lv5")
		eq(Content.unit_title("Bộ binh", 6), "Bộ binh dũng mãnh Lv6")
		eq(Content.unit_title("Bộ binh", 9), "Bộ binh dũng mãnh Lv9")
		eq(Content.unit_title("Anh hùng", 4, true), "Anh hùng Lv4")
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
		var s := Game.new_game(mission("m03"))
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
	run("v3 save (stamps without amounts) migrates to v4: aura / poison keep their old 10", func() -> void:
		var s := Game.new_game(mission("m03"))
		var v3: Dictionary = { "state": s.duplicate(true), "ctx": { "kind": "campaign", "id": "m03" } }
		v3.state.v = 3
		v3.state.units[0].aura = "p"
		v3.state.units[1].poison = "e"
		check(not Content.save_fits(v3), "v3 does not fit before migrating")
		Content.migrate_save(v3)
		eq(v3.state.v, Content.STATE_V)
		check(Content.save_fits(v3), "migrated v3 fits")
		var st3: Dictionary = v3.state
		eq([Game.aura_atk(unit(st3, 0)), Game.poison_amt(unit(st3, 1))], [10, 10])
		eq(Game.aura_atk(unit(st3, 2)), 0, "no stamp -> 0")
	)
	run("unit flags are data: heavy set, aiWeight on buyables, raise / vsType name real types", func() -> void:
		var heavy := []
		for t: String in Rules.UNITS:
			var ut: Dictionary = Rules.UNITS[t]
			if ut.get("heavy", false):
				heavy.append(t)
			var r: Variant = ut.get("raise")
			check(r == null or Rules.UNITS.has(r), "%s raises a known type" % t)
			for v: String in ut.get("vsType", {}):
				check(Rules.UNITS.has(v), "%s vsType %s" % [t, v])
			if ut.get("buyable", true) and t != "hero":
				check(ut.has("aiWeight"), "aiWeight " + t)
		eq(heavy, ["hero", "elephant", "catapult", "bird"])
	)
	run("a new unit type defined only in UNITS: AI buys it (default weight), its flags work (vsType, aura, poison, raise)", func() -> void:
		var units: Dictionary = Rules.UNITS.duplicate(true)
		units["monk"] = { "cost": 100, "atk": 30, "atkMax": 31, "def": 5, "mv": 4, "rmin": 1, "rmax": 1, "move": "foot",
			"vsType": { "soldier": 7 }, "aura": 4, "poison": 3, "raise": "soldier" }
		Game.use_tables(units, Rules.HEROES, Rules.RULES, Rules.TERRAIN)
		eq(AI.weight("monk"), AI.DEFAULT_WEIGHT)
		var s := blank([["p", "monk", 1, 1], ["p", "soldier", 1, 3], ["e", "soldier", 2, 1]])
		s.allowed.p = ["monk"]
		s.gold.p = 1000
		eq(AI.choose_buy(s, "p"), "monk", "no aiWeight: still bought, no crash")
		var mk: Dictionary = s.units[0]
		var foe: Dictionary = s.units[2]
		var plain := Game.damage(s, unit(s, 1), 1, 1, 100, foe, 0.0) # soldier 50 - 5 def - 5 field
		eq(Game.damage(s, mk, 1, 1, 100, foe, 0.0), 30 + 7 - 10, "vsType bonus")
		Game.fixed_roll = 0.0
		Game.do_action(s, { "id": mk.id, "to": [1, 1], "kind": "attack", "target": foe.id })
		eq(Game.poison_amt(foe), 3, "poison amount from data")
		eq(Game.aura_atk(unit(s, 1)), 4, "aura amount from data")
		eq(Game.damage(s, unit(s, 1), 1, 1, 100, foe, 0.0), plain + 4 + 3, "aura +4, target -3 def")
		s.graves = [{ "x": 0, "y": 1, "ttl": 3 }]
		mk.acted = false
		s.side = "p"
		Game.do_action(s, { "id": mk.id, "to": [1, 1], "kind": "raise", "target": [0, 1] })
		var raised: Variant = Game.unit_at(s, 0, 1)
		var raised_ok: bool = raised != null and raised.type == "soldier"
		check(raised_ok, "raise spawns the type named by `raise`")
		Game.use_tables(Rules.UNITS, Rules.HEROES, Rules.RULES, Rules.TERRAIN)
	)
	run("objectives registry: a new win type is one entry (loss, round, AI goal, marks, bar)", func() -> void:
		eq(Objectives.types(), ["castles", "rout", "hero", "survive", "reach"])
		var s := blank([["p", "hero", 1, 1], ["e", "soldier", 4, 4]])
		s.win = { "type": "flag", "at": [[3, 1]] }
		check(Objectives.check(s).begins_with("unknown"), "unknown type flagged")
		var loss := func(st: Dictionary, side: String) -> Variant:
			if side == "e" and Game.unit_at(st, 3, 1) != null:
				return "flagTaken"
			return null
		var on_round := func(st: Dictionary) -> Variant:
			if st.turn > 3:
				return ["e", "late"]
			return null
		var ai_goals := func(st: Dictionary, _u: Dictionary) -> Variant:
			var at: Array = st.win.at
			return at.duplicate()
		Objectives.TYPES["flag"] = { "loss": loss,
			"on_round": on_round,
			"ai_goals": ai_goals,
			"marks": func(st: Dictionary) -> Array: return st.win.at, "bar_n": func(_st: Dictionary) -> int: return 7 }
		eq([Objectives.check(s), Objectives.marks(s), Objectives.bar_n(s)], ["", [[3, 1]], 7])
		eq(AI.goals_for(s, unit(s, 0), {}), [[3, 1]], "AI heads for the objective")
		Game.do_action(s, { "id": 1, "to": [3, 1], "kind": "wait" })
		eq([s.winner, s.reason], ["p", "flagTaken"], "loss hook")
		var s2 := blank([["p", "hero", 1, 1], ["e", "soldier", 4, 4]])
		s2.win = { "type": "flag", "at": [[3, 1]] }
		for i in 6:
			Game.end_turn(s2)
		eq([s2.winner, s2.reason, s2.turn], ["e", "late", 4], "round hook")
		Objectives.TYPES.erase("flag")
		eq(Objectives.marks(s), [], "no entry: no marks")
	)
	run("goal / end texts: every win type has copy, unknown types fall back", func() -> void:
		for t: String in Objectives.types():
			check(Content.goal_text({ "type": t, "turns": 5, "at": [[0, 0]] }, "brief", { "p": "anhhung", "e": "tuonggiac" }) != t, "brief copy " + t)
			var bar := Content.goal_text({ "type": t, "turns": 5, "at": [[0, 0]] }, "bar", { "p": "anhhung", "e": "tuonggiac" }, { "n": 1, "left": 2 })
			check(bar != t, "bar copy " + t)
		eq(Content.goal_text({ "type": "teleport" }, "brief", { "p": "anhhung", "e": null }), "teleport")
		check(Content.tile_note("c").find("tướng") >= 0, "castle note names who captures")
	)
	run("mission opening: history -> story intro -> goal; only on a fresh campaign start", func() -> void:
		var m := mission("m02")
		var lines := StoryOverlay.lines_for(m)
		var story: Dictionary = m.story
		var intro: Array = story.intro
		eq(lines.size(), intro.size() + 2, "line count")
		eq(lines[0], ["sutich", m.history], "history first")
		eq(lines.slice(1, -1), intro, "intro in order")
		eq(lines[-1], ["muctieu", Menus.goal_text(m)], "goal last")
		for c: Dictionary in Content.campaign():
			for l: Array in StoryOverlay.lines_for(c):
				var key: String = l[0]
				var icon: String = Content.speaker(key).icon
				check(icon != "💬", "%s: speaker '%s' declared" % [c.id, key])
		var fresh := { "kind": "campaign", "id": "m02", "story": true }
		check(StoryOverlay.should_play(fresh, {}), "fresh campaign start plays")
		check(not StoryOverlay.should_play({ "kind": "campaign", "id": "m02" }, {}), "continue / restart (no key) does not")
		check(not StoryOverlay.should_play({ "kind": "skirmish", "story": true }, {}), "skirmish never")
		check(not StoryOverlay.should_play(fresh, { "nointro": "1" }), "nointro skips")
		check(not StoryOverlay.should_play(fresh, { "bot": "1" }), "bot skips")
		check(StoryOverlay.should_play(fresh, { "bot": "1", "story": "1" }), "story flag forces")
	)
	run("save round-trip keeps types", func() -> void:
		var s := Game.new_game(mission("m02"))
		var back: Dictionary = str_to_var(var_to_str(s))
		eq(back, s)
		check(owner_of(back).keys()[0] is Vector2i, "Vector2i keys")
		check(back.units[0].hp is int, "int hp")
	)
	run("saves from older content are refused (removed commander / mission), current ones kept", func() -> void:
		var s := Game.new_game(mission("m03"))
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
		var s := Game.new_game(mission("m01"))
		Game.end_turn(s)
		Game.end_turn(s)
		eq(s.winner, null)
		var first_e: Dictionary = units_of(s).filter(func(u: Dictionary) -> bool: return u.side == "e")[0]
		s.units = units_of(s).filter(func(u: Dictionary) -> bool: return u.side == "p" or u.id == first_e.id)
		var last: Dictionary = first_e
		last.hp = 1
		var hero: Dictionary = units_of(s).filter(func(u: Dictionary) -> bool: return u.type == "hero")[0]
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
		Game.spawn(s, "p", "soldier", xy(w, 1).x, xy(w, 1).y)
		Game.end_turn(s)
		Game.end_turn(s)
		Game.end_turn(s)
		var spawned: Array = units_of(s).filter(func(u: Dictionary) -> bool: return u.side == "e")
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
		var s := Game.new_game(mission("m04"))
		var eh: Dictionary = units_of(s).filter(func(u: Dictionary) -> bool: return u.side == "e" and u.type == "hero")[0]
		var el: Dictionary = units_of(s).filter(func(u: Dictionary) -> bool: return u.side == "p" and u.type == "soldier")[0]
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
		var s := Game.new_game(mission("m04"))
		Game.end_turn(s)
		var eh: Dictionary = units_of(s).filter(func(u: Dictionary) -> bool: return u.side == "e" and u.type == "hero")[0]
		var at := [eh.x, eh.y]
		var n := 0
		while n < 50:
			n += 1
			var step: Variant = AI.next_step(s, {})
			if step == null:
				break
			var sd: Dictionary = step
			AI.apply_step(s, sd)
		eq([eh.x, eh.y], at)
		var guarding: bool = eh.guard
		check(guarding, "still guarding")
	)
	run("allowed list limits buys", func() -> void:
		var s := Game.new_game(mission("m02"))
		s.units = units_of(s).filter(func(u: Dictionary) -> bool: return not (u.x == 1 and u.y == 2))
		eq(Game.buy_options(s, "p", 1, 2).map(func(o: Dictionary) -> String: return o.type), ["soldier", "archer"])
	)


# ---------- 1 vs 1 (docs/1v1.md) ----------
func duel(map_id: String, ctrl_e: String) -> Dictionary:
	var hp: String = Content.heroes_of("p")[0]
	var he: String = Content.heroes_of("e")[0]
	return Content.duel_def(map_id, hp, he, ctrl_e)

static func duel_ctx(map_id: String, ctrl_e: String) -> Dictionary:
	return { "kind": "duel", "map": map_id, "hero": Content.heroes_of("p")[0], "heroE": Content.heroes_of("e")[0], "ctrlE": ctrl_e,
		"gold": 300, "cap": 15 }

func duel_tests() -> void:
	run("ctrl missing = old behavior: p human, e AI normal, AI mem untouched", func() -> void:
		var hp: String = Content.heroes_of("p")[0]
		for def: Dictionary in [mission("m01"), Content.skirmish_def("dong_bang", hp, true)]:
			var s := Game.new_game(def)
			check(not s.has("ctrl"), "%s: no ctrl key in state" % def.id)
			eq(Content.ctrl_of(s, "p"), "human")
			eq(Content.ctrl_of(s, "e"), "ai:normal")
			check(not Content.is_ai(s, "p") and Content.is_ai(s, "e"), "p human, e AI")
			eq(Content.ai_level(s, "e"), "normal")
			eq(Content.ai_mem(s, "e"), {}, "default AI gets the same empty mem as before")
	)
	run("duel_def valid on every skirmish map", func() -> void:
		for mid: String in Content.SKIRMISH.MAPS:
			for ctrl_e: String in ["human", "ai:easy", "ai:normal", "ai:hard"]:
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
					check(units_of(s).any(func(u: Dictionary) -> bool: return u.side == side and u.type == "hero"), "%s: %s commander" % [mid, side])
				check(not def.has("skirmish") and str(def.id).begins_with("duel:"), mid + " is a duel, not a skirmish")
		check(Content.ai_params_for(Game.new_game(duel("dong_bang", "ai:hard")), "e") is Dictionary, "params hook returns a dict")
	)
	run("2 humans: full game by do_action on both sides, step-replayable", func() -> void:
		var s := Game.new_game(duel("dong_bang", "human"))
		var s0: Dictionary = s.duplicate(true)
		var steps := []
		var moves := { "p": 0, "e": 0 }
		AI.seed_game(7)
		while s.winner == null and s.turn <= 60:
			var mem := {}
			var side: String = s.side
			check(not Content.is_ai(s, side), "side to move is human")
			for i in 80: # AI only picks the moves; they go in like a player's clicks
				var step: Variant = AI.next_step(s, mem)
				if step == null or s.winner != null:
					break
				var sd: Dictionary = step
				if sd.kind == "buy":
					var bx: int = sd.x; var by: int = sd.y; var bt: String = sd.type
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
		eq(var_to_str(s0), var_to_str(s), "replay matches")
	)
	run("save / load keeps ctrl; bad duel saves refused", func() -> void:
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
		check(not Content.save_fits({ "state": odd, "ctx": duel_ctx("cua_bien", "human") }), "unknown controller refused")
	)
	run("duel / skirmish results never touch campaign progress", func() -> void:
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
	)


# ---------- regression games (sim/golden.txt, current rules) ----------
func parity_tests() -> void:
	run("rules + AI still play the golden games (m01, m07, sk_dong_bang, naive)", func() -> void:
		var golden := {}
		for line: String in FileAccess.get_file_as_string("res://sim/golden.txt").split("\n", false):
			var p := line.split(" ", false, 2)
			golden[p[0] + " " + p[1]] = p[2]
		var par := Parity.new()
		par.apply()
		for key: String in ["m01 0", "m07 1", "sk_dong_bang 0", "naive 0"]:
			eq(par.replay(key), golden.get(key, "?"), key)
		par.restore()
	)
