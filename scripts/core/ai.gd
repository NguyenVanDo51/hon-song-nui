class_name AI
extends RefCounted
## enemy AI (also the hint button and the sim's player side). Port of src/core/ai.js.
## One step at a time so the UI can animate: next_step() -> {kind:'act', act} | {kind:'buy', x, y, type} | null (= end turn).

## sim swaps in a seeded rng
static var rng: Callable = randf

const WEIGHTS := { "soldier": 3, "archer": 2, "drum": 0.5, "shaman": 0.7, "elephant": 1.6, "bird": 1, "catapult": 0.7 }

static func value(_s: Dictionary, u: Dictionary) -> float:
	return (900 if u.type == "hero" else Rules.UNITS[u.type].cost) * (1 + 0.2 * u.rank)

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

## tile -> list of enemy attackers that could hit it next turn
static func threat_map(s: Dictionary, side: String) -> Dictionary:
	var m := {}
	for e: Dictionary in s.units:
		if e.side == side:
			continue
		var st := Game.stat(s, e)
		var from := []
		if st.get("siege", false):
			from = [[e.x, e.y]]
		else:
			for r: Dictionary in Game.reachable(s, e).values():
				from.append([r.x, r.y])
		var hit := {}
		var rmax: int = st.rmax
		for f: Array in from:
			var fx: int = f[0]
			var fy: int = f[1]
			for y in range(fy - rmax, fy + rmax + 1):
				for x in range(fx - rmax, fx + rmax + 1):
					var dd := absi(x - fx) + absi(y - fy)
					if dd >= st.rmin and dd <= rmax and Game.tile_at(s, x, y) != null:
						hit[Vector2i(x, y)] = true
		for key: Vector2i in hit:
			if not m.has(key):
				m[key] = []
			m[key].append(e)
	return m

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
	var cap_v: bool = st.get("capV", false)
	var cap_c: bool = st.get("capC", false)
	if cap_v or cap_c:
		for y in s.h:
			for x in s.w:
				var t: String = s.tiles[y][x]
				var key := Vector2i(x, y)
				if s.owner.get(key) == u.side or claims.has(key):
					continue
				if (t == "v" and cap_v) or (t == "c" and cap_c):
					out.append([x, y])
	if not out.size() or u.type != "soldier":
		for e: Dictionary in s.units:
			if e.side != u.side:
				out.append([e.x, e.y])
		for key: Vector2i in s.owner:
			var o: Variant = s.owner[key]
			if o != null and o != u.side and s.tiles[key.y][key.x] == "c":
				out.append([key.x, key.y])
	return out

## own castles an enemy castle-capturer could step on next turn
static func endangered_castles(s: Dictionary, side: String) -> Dictionary:
	var out := {}
	for e: Dictionary in s.units:
		if e.side == side or not Game.stat(s, e).get("capC", false):
			continue
		var reach := Game.reachable(s, e)
		for key: Vector2i in Game.castle_tiles(s, side):
			if Game.unit_at(s, key.x, key.y) != null:
				continue
			if reach.has(key) or Game.dist(e.x, e.y, key.x, key.y) <= Game.stat(s, e).mv:
				out[key] = true
	return out

static func best_for_unit(s: Dictionary, u: Dictionary, threat: Dictionary, claims: Dictionary, danger: Dictionary) -> Variant:
	var st := Game.stat(s, u)
	var reach := Game.reachable(s, u)
	var mc: String = st.move if st.move in ["heavy", "fly", "water", "mount"] else "foot"
	var df := dist_field(s, mc, goals_for(s, u, claims))
	var val := value(s, u)
	var caution := (2.5 if s.heroMustLive and u.side == "p" else 1.3) if u.type == "hero" else 0.6
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
		var tdef: int = Rules.TERRAIN[t].def
		var pos := -gd * 12 + tdef * 0.8
		var hurt := expected_hit(s, u, rx, ry, threat.get(key))
		pos -= (hurt / 100.0) * val * caution
		var own: Variant = s.owner.get(key)
		if own == u.side and u.hp < 70:
			pos += (100 - u.hp) * val * 0.004
		if t == "c" and own == u.side:
			pos -= 400 if s.heroDead[u.side] else (40 if u.type == "hero" else 150)

		if danger.has(key):
			pos += 900 # block the capture
		consider.call(pos, { "id": u.id, "to": [rx, ry], "kind": "wait" })

		if Game.can_capture(s, u, rx, ry):
			var c := 700 if t == "c" else 220
			if own != null:
				c += 400 if t == "c" else 100
			if t == "c" and own == Game.other(u.side) and enemy_castles == 1:
				c += 10000
			consider.call(pos + c + gd * 12, { "id": u.id, "to": [rx, ry], "kind": "capture" })
		for g: Dictionary in Game.raisable_graves(s, u, rx, ry):
			consider.call(pos + 250, { "id": u.id, "to": [rx, ry], "kind": "raise", "target": [g.x, g.y] })

		for d: Dictionary in Game.targets_from(s, u, rx, ry):
			var p := Game.preview(s, u, rx, ry, d)
			var dv := value(s, d)
			var sc: float = (p.dmg / 100.0) * dv - (p.counter / 100.0) * val
			if p.kill:
				sc += dv * 0.6 + (600 if d.type == "hero" else 0)
			if p.die:
				sc -= val
			# after counter, remaining exposure scales with remaining hp
			var left := maxi(0, u.hp - p.counter)
			var exposure := minf(left, hurt) / 100.0 * val * caution
			consider.call(sc + (-gd * 12 + tdef * 0.8) * 0.3 - exposure + 40, { "id": u.id, "to": [rx, ry], "kind": "attack", "target": d.id })
	return best[0]

static func choose_buy(s: Dictionary, side: String) -> Variant:
	var counts := {}
	var enemy_fly := false
	for u: Dictionary in s.units:
		if u.side == side:
			counts[u.type] = counts.get(u.type, 0) + 1
		elif Rules.UNITS[u.type].move == "fly":
			enemy_fly = true
	var open := 0
	for y in s.h:
		for x in s.w:
			if s.tiles[y][x] == "v" and s.owner.get(Vector2i(x, y)) != side:
				open += 1
	var best: Variant = null
	for type: String in s.allowed[side]:
		var cost: int = Rules.UNITS[type].cost
		if cost > s.gold[side]:
			continue
		var w: float = WEIGHTS[type]
		if type == "archer" and enemy_fly:
			w += 2
		if type == "soldier" and open > counts.get("soldier", 0) * 3:
			w += 2
		if type == "shaman" and s.graves.size():
			w += 0.5
		var sc: float = (w / (1 + counts.get(type, 0))) * pow(cost / 300.0, 0.35)
		if best == null or sc > best.sc:
			best = { "type": type, "sc": sc }
	return best.type if best != null else null

static func _claim_nearest(s: Dictionary, act: Dictionary, claims: Dictionary) -> void:
	var u: Dictionary = Game.unit_by_id(s, act.id)
	var st := Game.stat(s, u)
	if not st.get("capV", false) or act.kind == "capture":
		return
	var best: Variant = null
	for y in s.h:
		for x in s.w:
			var t: String = s.tiles[y][x]
			var key := Vector2i(x, y)
			if s.owner.get(key) == u.side or claims.has(key):
				continue
			if not (t == "v" or (t == "c" and st.get("capC", false))):
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
		var threat := threat_map(s, side)
		var danger := endangered_castles(s, side)
		var best: Variant = null
		for u: Dictionary in mine:
			var b: Variant = best_for_unit(s, u, threat, mem.claims, danger)
			if b != null and (best == null or b.score > best.score):
				best = b
		_claim_nearest(s, best.act, mem.claims)
		return { "kind": "act", "act": best.act }
	if Game.unit_count(s, side) >= s.unitCap:
		return null
	for key: Vector2i in Game.castle_tiles(s, side):
		if Game.unit_at(s, key.x, key.y) != null:
			continue
		var want_hero: bool = s.heroDead[side] and s.heroKey[side] != null
		if want_hero and s.gold[side] >= Rules.UNITS.hero.cost:
			return { "kind": "buy", "x": key.x, "y": key.y, "type": "hero" }
		if want_hero and s.gold[side] < Rules.UNITS.hero.cost and Game.unit_count(s, side) >= 4:
			return null
		var type: Variant = choose_buy(s, side)
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
	return { "kind": "act", "act": acts[int(floor(r.call() * acts.size()))] }

static func apply_step(s: Dictionary, step: Dictionary) -> Array:
	if step.kind == "act":
		return Game.do_action(s, step.act)
	Game.buy(s, step.x, step.y, step.type)
	return [{ "t": "buy", "x": step.x, "y": step.y, "type": step.type, "side": s.side }]
