extends "res://sim/tests/test_base.gd"
## content tests (run by sim/tests.gd)

# ---------- content ----------
func content_tests() -> void:
	var all: Array = Content.campaign().duplicate()
	var hero_p: String = Content.heroes_of("p")[0]
	var hero_e1: String = Content.heroes_of("e")[0]
	for mid: String in Content.SKIRMISH.MAPS:
		all.append(Content.skirmish_def(mid, hero_p, false))
		all.append(Content.duel_def(mid, hero_p, hero_e1, "human"))
	run(
		"skirmish: new maps are 180° rotations (fair start)",
		func() -> void:
			for mid: String in ["cua_bien", "nui_rung"]:
				var rows: Array = Content.SKIRMISH.MAPS[mid].rows
				for y in rows.size():
					var mirror: String = rows[rows.size() - 1 - y]
					eq(rows[y], mirror.reverse(), "%s row %d" % [mid, y]),
	)
	eq(Content.campaign().size(), 16, "campaign size")
	run(
		"chapters: 2 chapters, every mission in one, missions of a chapter are consecutive",
		func() -> void:
			eq(
				Content.chapters().map(
					func(c: Dictionary) -> String:
						return c.id,
				),
				["c1", "c2"],
			)
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
			check(Content.chapter_unlocked("c1", 0) and not Content.chapter_unlocked("c2", 7) and Content.chapter_unlocked("c2", 8), "unlock order"),
	)
	run(
		"our commander can walk (over turns) to every castle, the enemy commander and the reach goal",
		func() -> void:
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
					var ok := (
						seen.has(t)
						or [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)].any(
							func(d: Vector2i) -> bool:
								return seen.has(t + d),
						)
					)
					check(ok, "%s: commander cannot reach %s" % [m.id, t]),
	)
	run(
		"one roster for both sides; one commander for us; enemy commanders share one look",
		func() -> void:
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
				eq(Content.skirmish_def(mid, "anhhung", false).enemyHero, "tuonggiac", mid),
	)
	run(
		"reach: hero on the goal wins, time runs out loses",
		func() -> void:
			var s := Game.new_game(mission("m13"))
			var hero: Dictionary = units_of(s).filter(
				func(u: Dictionary) -> bool:
					return u.type == "hero",
			)[0]
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
			eq(s2.reason, "timeUp"),
	)
	for def: Dictionary in all:
		run(
			"content valid: %s" % def.id,
			func() -> void:
				var rows: Array = def.map.rows
				for r: String in rows:
					var row0: String = rows[0]
					check(r.length() == row0.length(), "rows equal length")
					for i in r.length():
						check(Rules.TERRAIN.has(r[i]), "unknown tile " + r[i])
				var s := Game.new_game(def)
				var seen := { }
				for u: Dictionary in s.units:
					var mc: String = Game.stat(s, u).move
					var at := pos(u)
					check(Game.move_cost(mc, Game.tile_at(s, at.x, at.y)) != INF, "%s %s on impassable %d,%d" % [u.side, u.type, u.x, u.y])
					check(not seen.has(at), "two units on %d,%d" % [u.x, u.y])
					seen[at] = true
				for key: Vector2i in s.owner:
					check(Game.cap_flag(Game.tile_at(s, key.x, key.y)) != "", "owner on non-building %s" % key)
				for side: String in ["p", "e"]:
					if units_of(s).any(
						func(u: Dictionary) -> bool:
							return u.side == side and u.type == "hero",
					):
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
				var story: Dictionary = def.get("story", { })
				for line: Array in story.get("intro", []) + story.get("outro", []):
					var who: String = line[0]
					var named: bool = Content.speaker(who).icon != "💬"
					check(named, "speaker " + who)
				check(s.winner == null, "no winner at start")
				# foot path from hero to enemy castle on castle maps
				if s.win.type == "castles":
					var hero: Dictionary = units_of(s).filter(
						func(u: Dictionary) -> bool:
							return u.side == "p" and u.type == "hero",
					)[0]
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
					check(seen_p.has(goal), "foot path to enemy castle"),
		)
	run(
		"theme: every terrain painter has the colors it reads",
		func() -> void:
			var need := {
				"field": ["base", "line"],
				"forest": ["base", "tree", "tree2"],
				"hill": ["base", "hill", "hill2"],
				"mountain": ["base", "rock", "rock2", "snow"],
				"water": ["base", "deep", "wave"],
				"bridge": ["base", "deep", "plank", "plank2"],
				"village": ["base", "line", "wall"],
				"castle": ["base", "wall", "wall2"],
			}
			for ch: String in Content.theme().terrain:
				var t: Dictionary = Content.theme().terrain[ch]
				check(Rules.TERRAIN.has(ch), "theme tile %s has rules" % ch)
				for key: String in need.get(t.paint, []):
					check(t.has(key), "%s (%s) missing %s" % [ch, t.paint, key])
			var terrain: Dictionary = Content.theme().terrain
			for ch: String in Rules.TERRAIN:
				check(terrain.has(ch), "rules tile %s has theme" % ch),
	)
