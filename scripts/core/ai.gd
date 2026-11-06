class_name AI
extends RefCounted
## enemy AI (also the hint button and the sim's player side). Scores use the mid damage roll.
## One step at a time so the UI can animate: next_step() -> {kind:'act', act} | {kind:'buy', x, y, type} | null (= end turn).

## own stream (UI effects draw from the global randf); seeded per game by the screen, swapped by the sims
static var _gen := RandomNumberGenerator.new()
static var rng: Callable = _gen.randf

static func seed_game(v: int) -> void:
	_gen.seed = v

const WEIGHTS := { "soldier": 3, "archer": 2, "boat": 0.8, "shaman": 0.6, "drum": 0.5, "wolf": 1.2, "elephant": 1.4, "catapult": 0.7, "bird": 1 }

static func value(_s: Dictionary, u: Dictionary) -> float:
	return (900 if u.type == "hero" else Game.UNITS[u.type].cost) * (1 + 0.2 * u.rank)

## multi-source terrain distance (ignores units)
static func dist_field(s: Dictionary, move_class: String, sources: Array) -> Dictionary:
	var d := {}
	var open := []
	for p: Array in sources:
		d[Vector2i(p[0], p[1])] = 0.0
		open.append([0.0, p[0], p[1]])
	while open.size():
		var cur := Game._pop_min(open)
		var c: float = cur[0]
		var x: int = cur[1]
		var y: int = cur[2]
		if c > d[Vector2i(x, y)]:
			continue
		for dd: Array in Game.DIRS:
			var nx: int = x + dd[0]
			var ny: int = y + dd[1]
			var step := Game.move_cost(move_class, Game.tile_at(s, nx, ny))
			if step == INF:
				continue
			var nc := c + step
			var key := Vector2i(nx, ny)
			if nc < d.get(key, INF):
				d[key] = nc
				open.append([nc, nx, ny])
	return d

## tile -> list of enemy attackers that could hit it next turn; mem (one turn) keeps each enemy's reach + hits across steps
static func threat_map(s: Dictionary, side: String, reach_of := {}, mem := {}) -> Dictionary:
	var m := {}
	for e: Dictionary in s.units:
		if e.side == side:
			continue
		var st := Game.stat(s, e)
		var siege: bool = st.get("siege", false)
		var ck: Variant = _local_key(s, e, mem) if mem.has("tiles_h") else null
		var hit: Dictionary
		if ck != null and mem.tm.has(ck):
			var c: Array = mem.tm[ck]
			hit = c[1]
			if not siege:
				reach_of[e.id] = c[0]
		else:
			var from := []
			if siege:
				from = [[e.x, e.y]]
			else:
				for r: Dictionary in _reach_of(s, e, reach_of).values():
					from.append([r.x, r.y])
			hit = {}
			var rmax: int = st.rmax
			for f: Array in from:
				var fx: int = f[0]
				var fy: int = f[1]
				for y in range(fy - rmax, fy + rmax + 1):
					for x in range(fx - rmax, fx + rmax + 1):
						var dd := absi(x - fx) + absi(y - fy)
						if dd >= st.rmin and dd <= rmax and Game.tile_at(s, x, y) != null:
							hit[Vector2i(x, y)] = true
			if ck != null:
				mem.tm[ck] = [reach_of.get(e.id), hit]
		for key: Vector2i in hit:
			if not m.has(key):
				m[key] = []
			m[key].append(e)
	return m

## everything Game.reachable(s, u) reads: u, the terrain, and the units within its move range (costs are >= 1)
static func _local_key(s: Dictionary, u: Dictionary, mem: Dictionary) -> Array:
	var mv: int = Game.stat(s, u).mv
	var k := [mem.tiles_h, u.id, u.type, u.side, u.x, u.y]
	for o: Dictionary in s.units:
		if absi(o.x - u.x) + absi(o.y - u.y) <= mv:
			k.append_array([o.id, o.side, o.x, o.y])
	return k

## Game.reachable, memoised for the turn by _local_key (same dict, same order -> same candidate order in best_for_unit)
static func _reach_cached(s: Dictionary, u: Dictionary, mem: Dictionary) -> Dictionary:
	if not mem.has("tiles_h"):
		return Game.reachable(s, u)
	var k := _local_key(s, u, mem)
	if not mem.rc.has(k):
		mem.rc[k] = Game.reachable(s, u)
	return mem.rc[k]

## enemy reach shared by threat_map + endangered_castles within one step (state does not change between them)
static func _reach_of(s: Dictionary, e: Dictionary, cache: Dictionary) -> Dictionary:
	if not cache.has(e.id):
		cache[e.id] = Game.reachable(s, e)
	return cache[e.id]

## dist_field depends only on terrain, move class and goals: memoised for the turn in mem.df
static func _dist_cached(s: Dictionary, mc: String, goals: Array, mem: Dictionary) -> Dictionary:
	if not mem.has("df"):
		mem.df = {}
	var key := [mc, goals] # array key: hashed natively, no str() of every goal per unit per step
	if not mem.df.has(key):
		mem.df[key] = dist_field(s, mc, goals)
	return mem.df[key]

static func expected_hit(s: Dictionary, u: Dictionary, x: int, y: int, attackers: Variant) -> float:
	if attackers == null:
		return 0.0
	var ox: int = u.x
	var oy: int = u.y
	u.x = x
	u.y = y
	var sum := 0
	for a: Dictionary in attackers:
		sum += Game.damage(s, a, a.x, a.y, a.hp, u)
	u.x = ox
	u.y = oy
	return minf(u.hp, sum * 0.6) # not every attacker reaches

static func goals_for(s: Dictionary, u: Dictionary, claims: Dictionary) -> Array:
	var st := Game.stat(s, u)
	var out := []
	if s.win.type == "reach" and u.side == "p" and u.type == "hero":
		return s.win.get("at", []).duplicate() # escape missions: the hero only cares about the goal
	var cap_v: bool = st.get("capV", false)
	var cap_c: bool = st.get("capC", false)
	if cap_v or cap_c:
		for y in s.h:
			for x in s.w:
				var t: String = s.tiles[y][x]
				var key := Vector2i(x, y)
				if s.owner.get(key) == u.side or claims.has(key):
					continue
				if (t == "v" and cap_v) or (t == "c" and cap_c) or (t == "x" and cap_v):
					out.append([x, y])
	if not out.size() or u.type != "soldier":
		for e: Dictionary in s.units:
			if e.side != u.side:
				out.append([e.x, e.y])
		for key: Vector2i in s.owner:
			var o: Variant = s.owner[key]
			if o != null and o != u.side and s.tiles[key.y][key.x] == "c":
				if cap_c:
					out.append([key.x, key.y])
				else: # crowd round it, never stand on it (that blocks our own commander's capture)
					for d: Array in Game.DIRS:
						if Game.tile_at(s, key.x + d[0], key.y + d[1]) != null:
							out.append([key.x + d[0], key.y + d[1]])
	return out

## own castles an enemy castle-capturer could step on next turn
static func endangered_castles(s: Dictionary, side: String, reach_of := {}) -> Dictionary:
	var out := {}
	for e: Dictionary in s.units:
		if e.side == side or not Game.stat(s, e).get("capC", false):
			continue
		var reach := _reach_of(s, e, reach_of)
		for key: Vector2i in Game.castle_tiles(s, side):
			if Game.unit_at(s, key.x, key.y) != null:
				continue
			if reach.has(key) or Game.dist(e.x, e.y, key.x, key.y) <= Game.stat(s, e).mv:
				out[key] = true
	return out

## hp loss + death risk on the full attacker sum (hurt / 0.6): 0 at <= 0.6 hp -> 1 at 1.4 hp, smooth so 1 hp never flips the pick
static func _risk(hurt: float, hp: float, hp_val: float, die_val: float) -> float:
	return hurt * hp_val + clampf((hurt / 0.6 / hp - 0.6) / 0.8, 0.0, 1.0) * die_val

static func best_for_unit(s: Dictionary, u: Dictionary, threat: Dictionary, claims: Dictionary, danger: Dictionary, mem := {}) -> Variant:
	var st := Game.stat(s, u)
	var reach := _reach_cached(s, u, mem)
	var mc: String = st.move if st.move in ["fly", "water"] else "foot"
	var df := _dist_cached(s, mc, goals_for(s, u, claims), mem)
	var val := value(s, u)
	var caution := 1.3 if u.type == "hero" else 0.6
	# hp heals: every hp costs the same (soldier price); the unit's full value only as death risk -> a healthy commander advances
	var hp_val := minf(val, 150.0) * 0.6 / 100.0
	var die_val := maxf(0.0, val - 150.0) * caution # soldier-priced hp already covers a soldier's death
	var has_df := df.size() > 0
	var enemy_castles := Game.castles(s, Game.other(u.side))
	var best: Array = [null] # [ {score, act} ]
	var consider := func(score: float, act: Dictionary) -> void:
		score += (rng.call() - 0.5) * 8
		if best[0] == null or score > best[0].score:
			best[0] = { "score": score, "act": act }

	for r: Dictionary in reach.values():
		var rx: int = r.x
		var ry: int = r.y
		var key := Vector2i(rx, ry)
		var t: String = s.tiles[ry][rx]
		var gd: float = df.get(key, 30.0) if has_df else 0.0
		var tdef: int = Game.TERRAIN[t].def
		var pos := -gd * 12 + tdef * 0.8
		var hurt := expected_hit(s, u, rx, ry, threat.get(key))
		pos -= _risk(hurt, u.hp, hp_val, die_val)
		var own: Variant = s.owner.get(key)
		if (own == u.side or Game.TERRAIN[t].get("temple", false)) and u.hp < 70:
			pos += (100 - u.hp) * minf(val, 300.0) * 0.004 # capped: a 60-hp commander must not glue to a village
		if st.get("aura", 0): # drum: allies within 2 get +atk after it acts
			for o: Dictionary in s.units:
				if o.side == u.side and o.id != u.id and not o.acted and Game.dist(o.x, o.y, rx, ry) <= 2:
					pos += 15
		if t == "c" and own == u.side:
			pos -= 40 # AE2 sells under one unit: only a nudge to keep moving (it also guards the castle)
		elif t == "c" and own != null and not st.get("capC", false):
			pos -= 600 # parked on an enemy castle it cannot take: blocks our commander

		if danger.has(key):
			pos += 900 # block the capture
		if s.win.type == "reach" and u.side == "p" and u.type == "hero":
			for g: Array in s.win.get("at", []):
				if g[0] == rx and g[1] == ry:
					# stepping on the goal wins; rebought on it (offGoal) -> must step off first, back next turn
					pos += -500.0 if u.get("offGoal", false) else 20000.0
		consider.call(pos, { "id": u.id, "to": [rx, ry], "kind": "wait" })

		if Game.can_capture(s, u, rx, ry):
			var c := 700 if t == "c" else 220
			if own != null:
				c += 400 if t == "c" else 100
			if t == "c" and own == Game.other(u.side) and enemy_castles == 1:
				c += 10000
			consider.call(pos + c + gd * 12, { "id": u.id, "to": [rx, ry], "kind": "capture" })
		if Game.can_repair(s, u, rx, ry):
			consider.call(pos + 180 + gd * 12, { "id": u.id, "to": [rx, ry], "kind": "repair" })
		for v: Array in Game.razable_from(s, u, rx, ry):
			# only enemy villages (their income + healing); unowned ones are worth more captured than wrecked
			if s.owner.get(Vector2i(v[0], v[1])) != null:
				consider.call(pos + 260, { "id": u.id, "to": [rx, ry], "kind": "raze", "target": v })
		for g: Dictionary in Game.raisable_graves(s, u, rx, ry):
			consider.call(pos + 250, { "id": u.id, "to": [rx, ry], "kind": "raise", "target": [g.x, g.y] })

		for d: Dictionary in Game.targets_from(s, u, rx, ry):
			var p := Game.preview(s, u, rx, ry, d)
			if p.dmgMax <= 0:
				continue # AE2: armour can soak the whole hit
			var dv := value(s, d)
			var sc: float = (p.dmg / 100.0) * dv - (p.counter / 100.0) * val
			if p.kill:
				sc += dv * 0.6 + (600 if d.type == "hero" else 0)
			elif p.mayKill:
				sc += dv * 0.3 + (300 if d.type == "hero" else 0)
			if p.die:
				sc -= val
			elif p.mayDie:
				sc -= val * 0.5
			# after counter, remaining exposure scales with remaining hp
			var left := maxi(0, u.hp - p.counter)
			var exposure := _risk(minf(left, hurt), left, hp_val, die_val) if left > 0 else 0.0
			consider.call(sc + (-gd * 12 + tdef * 0.8) * 0.3 - exposure + 40, { "id": u.id, "to": [rx, ry], "kind": "attack", "target": d.id })
	return best[0]

## ok: types buy_options allows at the chosen castle (gold, cap, step-off); null = any allowed type within gold
static func choose_buy(s: Dictionary, side: String, ok: Variant = null) -> Variant:
	var counts := {}
	var enemy_fly := false
	for u: Dictionary in s.units:
		if u.side == side:
			counts[u.type] = counts.get(u.type, 0) + 1
		elif Game.UNITS[u.type].move == "fly":
			enemy_fly = true
	var open := 0
	var water := 0
	for y in s.h:
		for x in s.w:
			if s.tiles[y][x] == "v" and s.owner.get(Vector2i(x, y)) != side:
				open += 1
			elif s.tiles[y][x] == "~":
				water += 1
	var best: Variant = null
	for type: String in s.allowed[side]:
		var cost: int = Game.UNITS[type].cost
		if cost > s.gold[side] or (ok != null and not ok.has(type)):
			continue
		if type == "boat" and water == 0:
			continue # no river: a boat is a soldier at twice the price
		var w: float = WEIGHTS[type]
		if type == "archer" and enemy_fly:
			w += 2
		if type == "soldier" and open > counts.get("soldier", 0) * 3:
			w += 2
		if type == "shaman" and s.graves.size():
			w += 0.5
		if type == "boat" and water * 8 > s.w * s.h:
			w += 1.5
		var sc: float = (w / (1 + counts.get(type, 0))) * pow(cost / 300.0, 0.35)
		if best == null or sc > best.sc:
			best = { "type": type, "sc": sc }
	return best.type if best != null else null

static func _claim_nearest(s: Dictionary, act: Dictionary, claims: Dictionary) -> void:
	var u: Dictionary = Game.unit_by_id(s, act.id)
	var st := Game.stat(s, u)
	if not st.get("capV", false) or act.kind == "capture" or act.kind == "repair":
		return
	var best: Variant = null
	for y in s.h:
		for x in s.w:
			var t: String = s.tiles[y][x]
			var key := Vector2i(x, y)
			if s.owner.get(key) == u.side or claims.has(key):
				continue
			if not (t == "v" or t == "x" or (t == "c" and st.get("capC", false))):
				continue
			var d := absi(x - act.to[0]) + absi(y - act.to[1])
			if best == null or d < best.d:
				best = { "d": d, "key": key }
	if best != null:
		claims[best.key] = true

static func next_step(s: Dictionary, mem: Dictionary) -> Variant:
	var side: String = s.side
	if not mem.has("claims"):
		mem.claims = {}
	var mine: Array = s.units.filter(func(u: Dictionary) -> bool: return u.side == side and not u.acted)
	# guards hold position until an enemy comes close
	for u: Dictionary in mine:
		if not u.get("guard", false):
			continue
		var st := Game.stat(s, u)
		var near := false
		for o: Dictionary in s.units:
			if o.side != side and Game.dist(o.x, o.y, u.x, u.y) <= st.mv + st.rmax + 1:
				near = true
				break
		if near:
			u.guard = false
		else:
			return { "kind": "act", "act": { "id": u.id, "to": [u.x, u.y], "kind": "wait" } }
	if mine.size():
		if not mem.has("tm"):
			mem.tm = {}
			mem.rc = {}
		mem.tiles_h = hash(s.tiles) # raze / repair change a tile mid-turn
		var reach_of := {}
		var threat := threat_map(s, side, reach_of, mem)
		var danger := endangered_castles(s, side, reach_of)
		var best: Variant = null
		for u: Dictionary in mine:
			var b: Variant = best_for_unit(s, u, threat, mem.claims, danger, mem)
			if b != null and (best == null or b.score > best.score):
				best = b
		if best == null:
			return null # nothing legal left (boxed in): end the turn
		_claim_nearest(s, best.act, mem.claims)
		return { "kind": "act", "act": best.act }
	if Game.cap_count(s, side) >= s.unitCap:
		return null
	# AE2: a castle with one unit on it (ours or theirs) still sells; buy_options folds in gold, cap and step-off room
	for key: Vector2i in Game.castle_tiles(s, side):
		var ok := {}
		for o: Dictionary in Game.buy_options(s, side, key.x, key.y):
			if o.ok:
				ok[o.type] = true
		if ok.is_empty():
			continue
		if ok.has("hero"):
			return { "kind": "buy", "x": key.x, "y": key.y, "type": "hero" }
		var want_hero: bool = s.heroDead[side] and s.heroKey[side] != null
		if want_hero and s.gold[side] < Game.hero_cost(s, side) and Game.unit_count(s, side) >= 4:
			return null # save up: the commander is the only castle taker
		var type: Variant = choose_buy(s, side, ok)
		if type != null:
			return { "kind": "buy", "x": key.x, "y": key.y, "type": type }
	return null

## naive bot for sim baseline: random legal action
static func random_step(s: Dictionary, r: Callable) -> Variant:
	var u: Variant = null
	for o: Dictionary in s.units:
		if o.side == s.side and not o.acted:
			u = o
			break
	if u == null:
		var opts := []
		for key: Vector2i in s.owner:
			if s.owner[key] != s.side:
				continue
			for o: Dictionary in Game.buy_options(s, s.side, key.x, key.y):
				if o.ok:
					opts.append({ "kind": "buy", "x": key.x, "y": key.y, "type": o.type })
		return opts[int(floor(r.call() * opts.size()))] if opts.size() and r.call() < 0.7 else null
	var acts := []
	for rr: Dictionary in Game.reachable(s, u).values():
		acts.append({ "id": u.id, "to": [rr.x, rr.y], "kind": "wait" })
		if Game.can_capture(s, u, rr.x, rr.y):
			acts.append({ "id": u.id, "to": [rr.x, rr.y], "kind": "capture" })
		for d: Dictionary in Game.targets_from(s, u, rr.x, rr.y):
			acts.append({ "id": u.id, "to": [rr.x, rr.y], "kind": "attack", "target": d.id })
		if Game.can_repair(s, u, rr.x, rr.y):
			acts.append({ "id": u.id, "to": [rr.x, rr.y], "kind": "repair" })
		for v: Array in Game.razable_from(s, u, rr.x, rr.y):
			acts.append({ "id": u.id, "to": [rr.x, rr.y], "kind": "raze", "target": v })
	return { "kind": "act", "act": acts[int(floor(r.call() * acts.size()))] }

static func apply_step(s: Dictionary, step: Dictionary) -> Array:
	if step.kind == "act":
		return Game.do_action(s, step.act)
	Game.buy(s, step.x, step.y, step.type)
	return [{ "t": "buy", "x": step.x, "y": step.y, "type": step.type, "side": s.side }]
