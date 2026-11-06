class_name AI
extends RefCounted
## enemy AI (also the hint button and the sim's player side). Scores use the mid damage roll.
## One step at a time so the UI can animate: next_step() -> {kind:'act', act} | {kind:'buy', x, y, type} | null (= end turn).

## buy weight for a type without `aiWeight` (a new unit still gets bought, never crashes the AI)
const DEFAULT_WEIGHT := 1.0
## below HOME_HP a unit heads for its side's heal tiles (the < 70 heal bonus then keeps it there to ~70 hp)
const HOME_HP := 50
## nearest free heal tile further than this many moves: no way home -> fight on instead of idling
const HOME_TURNS := 4

## own stream (UI effects draw from the global randf); seeded per game by the screen, swapped by the sims
static var _gen := RandomNumberGenerator.new()
static var rng: Callable = _gen.randf

static func seed_game(v: int) -> void:
	_gen.seed = v

static func weight(type: String) -> float:
	var b: Dictionary = Game.UNITS[type]
	var w: float = b.get("aiWeight", DEFAULT_WEIGHT) # int or float in the table
	return w

static func value(_s: Dictionary, u: Dictionary) -> float:
	var b: Dictionary = Game.UNITS[u.type]
	return b.get("aiValue", b.cost) * (1 + 0.2 * u.rank)

## multi-source terrain distance (ignores units)
static func dist_field(s: Dictionary, move_class: String, sources: Array) -> Dictionary:
	var d := {}
	var open := []
	for p: Array in sources:
		var px: int = p[0]
		var py: int = p[1]
		d[Vector2i(px, py)] = 0.0
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
		var ck: Variant = null
		var tm: Dictionary = {}
		if mem.has("tiles_h"):
			ck = _local_key(s, e, mem)
			tm = mem.tm
		var hit: Dictionary
		if ck != null and tm.has(ck):
			var c: Array = tm[ck]
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
				tm[ck] = [reach_of.get(e.id), hit]
		for key: Vector2i in hit:
			if not m.has(key):
				m[key] = []
			var on_key: Array = m[key]
			on_key.append(e)
	return m

## everything Game.reachable(s, u) reads: u, the terrain, and the units within its move range (costs are >= 1)
static func _local_key(s: Dictionary, u: Dictionary, mem: Dictionary) -> Array:
	var mv: int = Game.stat(s, u).mv
	var k := [mem.tiles_h, u.id, u.type, u.side, u.x, u.y]
	var ux: int = u.x
	var uy: int = u.y
	for o: Dictionary in s.units:
		var ox: int = o.x
		var oy: int = o.y
		if absi(ox - ux) + absi(oy - uy) <= mv:
			k.append_array([o.id, o.side, o.x, o.y])
	return k

## Game.reachable, memoised for the turn by _local_key (same dict, same order -> same candidate order in best_for_unit)
static func _reach_cached(s: Dictionary, u: Dictionary, mem: Dictionary) -> Dictionary:
	if not mem.has("tiles_h"):
		return Game.reachable(s, u)
	var k := _local_key(s, u, mem)
	var rc: Dictionary = mem.rc
	if not rc.has(k):
		rc[k] = Game.reachable(s, u)
	return rc[k]

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
	var df: Dictionary = mem.df
	if not df.has(key):
		df[key] = dist_field(s, mc, goals)
	return df[key]

static func expected_hit(s: Dictionary, u: Dictionary, x: int, y: int, attackers: Variant) -> float:
	if attackers == null:
		return 0.0
	var ox: int = u.x
	var oy: int = u.y
	u.x = x
	u.y = y
	var sum := 0
	for a: Dictionary in attackers:
		var ax: int = a.x
		var ay: int = a.y
		var ahp: int = a.hp
		sum += Game.damage(s, a, ax, ay, ahp, u)
	u.x = ox
	u.y = oy
	var uhp: int = u.hp
	return minf(uhp, sum * 0.6) # not every attacker reaches

static func goals_for(s: Dictionary, u: Dictionary, claims: Dictionary) -> Array:
	var st := Game.stat(s, u)
	var out := []
	var og: Variant = Objectives.ai_goals(s, u)
	if og != null:
		return og
	var cap_v: bool = st.get("capV", false)
	var cap_c: bool = st.get("capC", false)
	var owner: Dictionary = s.owner
	if cap_v or cap_c:
		for y: int in s.h:
			for x: int in s.w:
				var t: String = s.tiles[y][x]
				var key := Vector2i(x, y)
				if owner.get(key) == u.side or claims.has(key):
					continue
				if Game.can_take(st, t):
					out.append([x, y])
	if not out.size() or not cap_v or cap_c: # pure village takers (capV only) chase villages, not fights
		for e: Dictionary in s.units:
			if e.side != u.side:
				out.append([e.x, e.y])
		for key: Vector2i in s.owner:
			var o: Variant = s.owner[key]
			var kt: String = s.tiles[key.y][key.x]
			if o != null and o != u.side and Game.sells(kt):
				if st.get(Game.cap_flag(kt), false):
					out.append([key.x, key.y])
				else: # crowd round it, never stand on it (that blocks our own commander's capture)
					for d: Array in Game.DIRS:
						var nx: int = key.x + d[0]
						var ny: int = key.y + d[1]
						if Game.tile_at(s, nx, ny) != null:
							out.append([nx, ny])
	return out

## heal tiles of u's side (own villages / castles, temples) not taken by another unit; map scan once per step
static func _home_goals(s: Dictionary, u: Dictionary, mem: Dictionary) -> Array:
	var side: String = u.side
	if not mem.has("heal"):
		mem.heal = {}
	var cache: Dictionary = mem.heal
	if not cache.has(side):
		var tiles := []
		for y: int in s.h:
			for x: int in s.w:
				if Game.heals_at(s, side, x, y):
					tiles.append([x, y])
		cache[side] = tiles
	var out := []
	var tiles_of: Array = cache[side]
	for t: Array in tiles_of:
		var tx: int = t[0]
		var ty: int = t[1]
		var o: Variant = Game.unit_at(s, tx, ty)
		if o == null or o == u:
			out.append(t)
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
			var ex: int = e.x
			var ey: int = e.y
			if reach.has(key) or Game.dist(ex, ey, key.x, key.y) <= Game.stat(s, e).mv:
				out[key] = true
	return out

## hp loss + death risk on the full attacker sum (hurt / 0.6): 0 at <= 0.6 hp -> 1 at 1.4 hp, smooth so 1 hp never flips the pick
static func _risk(hurt: float, hp: float, hp_val: float, die_val: float) -> float:
	return hurt * hp_val + clampf((hurt / 0.6 / hp - 0.6) / 0.8, 0.0, 1.0) * die_val

static func best_for_unit(s: Dictionary, u: Dictionary, threat: Dictionary, claims: Dictionary, danger: Dictionary, mem := {}) -> Variant:
	var st := Game.stat(s, u)
	var reach := _reach_cached(s, u, mem)
	var mc: String = st.move if st.move in ["fly", "water"] else "foot"
	var df := {}
	var homeless := false
	if u.hp < HOME_HP and Objectives.ai_goals(s, u) == null: # wounded: walk home over turns (reach objective first)
		var home := _home_goals(s, u, mem)
		if home.size():
			df = _dist_cached(s, mc, home, mem)
		var mv: int = st.mv
		var ux: int = u.x
		var uy: int = u.y
		if df.get(Vector2i(ux, uy), INF) > HOME_TURNS * mv:
			df = {}
			homeless = true
	if df.is_empty():
		df = _dist_cached(s, mc, goals_for(s, u, claims), mem)
	var val := value(s, u)
	var caution := 1.3 if u.type == "hero" else 0.6
	# hp heals: every hp costs the same (soldier price); the unit's full value only as death risk -> a healthy commander advances
	var hp_val := minf(val, 150.0) * 0.6 / 100.0
	var die_val := maxf(0.0, val - 150.0) * caution # soldier-priced hp already covers a soldier's death
	if homeless and u.type != "hero":
		die_val = 0.0 # cannot heal: its hp is all it is worth, spend it rather than idle out of reach
	var has_df := df.size() > 0
	var side: String = u.side
	var enemy_castles := Game.castles(s, Game.other(side))
	var goal_hook: Variant = Objectives.hook(s, "ai_tile")
	var has_goal_tile := goal_hook != null
	var goal_tile: Callable
	if has_goal_tile:
		goal_tile = goal_hook
	var owner: Dictionary = s.owner
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
		var uhp: int = u.hp
		pos -= _risk(hurt, uhp, hp_val, die_val)
		var own: Variant = owner.get(key)
		if Game.heals_at(s, side, rx, ry) and u.hp < 70:
			pos += (100 - u.hp) * minf(val, 300.0) * 0.004 # capped: a 60-hp commander must not glue to a village
		if st.get("aura", 0): # drum: allies within 2 get +atk after it acts
			for o: Dictionary in s.units:
				var ox: int = o.x
				var oy: int = o.y
				if o.side == u.side and o.id != u.id and not o.acted and Game.dist(ox, oy, rx, ry) <= 2:
					pos += 15
		var castle := Game.sells(t)
		if castle and own == u.side:
			pos -= 40 # AE2 sells under one unit: only a nudge to keep moving (it also guards the castle)
		elif castle and own != null and not st.get(Game.cap_flag(t), false):
			pos -= 600 # parked on an enemy castle it cannot take: blocks our commander

		if danger.has(key):
			pos += 900 # block the capture
		if has_goal_tile:
			pos += goal_tile.call(s, u, rx, ry)
		consider.call(pos, { "id": u.id, "to": [rx, ry], "kind": "wait" })

		if Game.can_capture(s, u, rx, ry):
			var c := 700 if castle else 220
			if own != null:
				c += 400 if castle else 100
			if castle and own == Game.other(side) and enemy_castles == 1:
				c += 10000
			consider.call(pos + c + gd * 12, { "id": u.id, "to": [rx, ry], "kind": "capture" })
		if Game.can_repair(s, u, rx, ry):
			consider.call(pos + 180 + gd * 12, { "id": u.id, "to": [rx, ry], "kind": "repair" })
		for v: Array in Game.razable_from(s, u, rx, ry):
			# only enemy villages (their income + healing); unowned ones are worth more captured than wrecked
			var vx: int = v[0]
			var vy: int = v[1]
			if owner.get(Vector2i(vx, vy)) != null:
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
			var counter: int = p.counter
			var left := maxi(0, uhp - counter)
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
	var open := {} # cap flag -> buildings needing it that are not ours
	var water := 0
	var owner: Dictionary = s.owner
	for y: int in s.h:
		for x: int in s.w:
			var t: String = s.tiles[y][x]
			var f := Game.cap_flag(t)
			if f != "" and owner.get(Vector2i(x, y)) != side:
				open[f] = open.get(f, 0) + 1
			else:
				var tt: Dictionary = Game.TERRAIN[t]
				if tt.get("water", false):
					water += 1
	var ok_types: Dictionary = {}
	if ok != null:
		ok_types = ok
	var graves: Array = s.graves
	var best: Variant = null
	for type: String in s.allowed[side]:
		var st: Dictionary = Game.UNITS[type]
		var cost: int = st.cost
		if cost > s.gold[side] or (ok != null and not ok_types.has(type)):
			continue
		var swims: bool = st.move == "water"
		if swims and water == 0:
			continue # no river: a boat is a soldier at twice the price
		var w := weight(type)
		if st.get("antiAir", 0) and enemy_fly:
			w += 2
		var takes := 0
		for f: String in open:
			if st.get(f, false):
				takes += open[f]
		if takes > counts.get(type, 0) * 3:
			w += 2
		if st.get("raise", "") and graves.size():
			w += 0.5
		if swims and water * 8 > s.w * s.h:
			w += 1.5
		var sc: float = (w / (1 + counts.get(type, 0))) * pow(cost / 300.0, 0.35)
		if best == null or sc > best.sc:
			best = { "type": type, "sc": sc }
	return best.type if best != null else null

static func _claim_nearest(s: Dictionary, act: Dictionary, claims: Dictionary) -> void:
	var aid: int = act.id
	var u: Dictionary = Game.unit_by_id(s, aid)
	var st := Game.stat(s, u)
	if not st.get("capV", false) or act.kind == "capture" or act.kind == "repair":
		return
	var best: Variant = null
	var owner: Dictionary = s.owner
	var tx: int = act.to[0]
	var ty: int = act.to[1]
	for y: int in s.h:
		for x: int in s.w:
			var t: String = s.tiles[y][x]
			var key := Vector2i(x, y)
			if owner.get(key) == u.side or claims.has(key):
				continue
			if not Game.can_take(st, t):
				continue
			var d := absi(x - tx) + absi(y - ty)
			if best == null or d < best.d:
				best = { "d": d, "key": key }
	if best != null:
		claims[best.key] = true

static func next_step(s: Dictionary, mem: Dictionary) -> Variant:
	var side: String = s.side
	if not mem.has("claims"):
		mem.claims = {}
	var units: Array = s.units
	var mine: Array = units.filter(func(u: Dictionary) -> bool: return u.side == side and not u.acted)
	# guards hold position until an enemy comes close
	for u: Dictionary in mine:
		if not u.get("guard", false):
			continue
		var st := Game.stat(s, u)
		var near := false
		var ux: int = u.x
		var uy: int = u.y
		for o: Dictionary in s.units:
			var ox: int = o.x
			var oy: int = o.y
			if o.side != side and Game.dist(ox, oy, ux, uy) <= st.mv + st.rmax + 1:
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
		mem.erase("heal") # captures change heal tile owners mid-turn
		var reach_of := {}
		var threat := threat_map(s, side, reach_of, mem)
		var danger := endangered_castles(s, side, reach_of)
		var best: Variant = null
		var claims: Dictionary = mem.claims
		for u: Dictionary in mine:
			var b: Variant = best_for_unit(s, u, threat, claims, danger, mem)
			if b != null and (best == null or b.score > best.score):
				best = b
		if best == null:
			return null # nothing legal left (boxed in): end the turn
		var best_act: Dictionary = best.act
		_claim_nearest(s, best_act, claims)
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
	var side: String = s.side
	var found: Variant = null
	for o: Dictionary in s.units:
		if o.side == s.side and not o.acted:
			found = o
			break
	if found == null:
		var opts := []
		for key: Vector2i in s.owner:
			if s.owner[key] != s.side:
				continue
			for o: Dictionary in Game.buy_options(s, side, key.x, key.y):
				if o.ok:
					opts.append({ "kind": "buy", "x": key.x, "y": key.y, "type": o.type })
		if opts.size() and r.call() < 0.7: # roll order: buy-or-end test, then pick (seeded sims)
			var pick: float = r.call()
			return opts[floori(pick * opts.size())]
		return null
	var u: Dictionary = found
	var acts := []
	for rr: Dictionary in Game.reachable(s, u).values():
		var rx: int = rr.x
		var ry: int = rr.y
		acts.append({ "id": u.id, "to": [rr.x, rr.y], "kind": "wait" })
		if Game.can_capture(s, u, rx, ry):
			acts.append({ "id": u.id, "to": [rr.x, rr.y], "kind": "capture" })
		for d: Dictionary in Game.targets_from(s, u, rx, ry):
			acts.append({ "id": u.id, "to": [rr.x, rr.y], "kind": "attack", "target": d.id })
		if Game.can_repair(s, u, rx, ry):
			acts.append({ "id": u.id, "to": [rr.x, rr.y], "kind": "repair" })
		for v: Array in Game.razable_from(s, u, rx, ry):
			acts.append({ "id": u.id, "to": [rr.x, rr.y], "kind": "raze", "target": v })
	var pick: float = r.call()
	return { "kind": "act", "act": acts[floori(pick * acts.size())] }

static func apply_step(s: Dictionary, step: Dictionary) -> Array:
	if step.kind == "act":
		var act: Dictionary = step.act
		return Game.do_action(s, act)
	var bx: int = step.x
	var by: int = step.y
	var btype: String = step.type
	Game.buy(s, bx, by, btype)
	return [{ "t": "buy", "x": step.x, "y": step.y, "type": step.type, "side": s.side }]
