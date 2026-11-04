class_name Game
extends RefCounted
## pure rules engine, no nodes. A game starts from a mission/scenario def (docs/content.md).
## State is a Dictionary with the same fields as the JS version; tile keys are Vector2i.
## Port of src/core/engine.js: iteration orders and float expressions are kept identical so the sim matches.

const DIRS := [[1, 0], [-1, 0], [0, 1], [0, -1]]
static var _hero_stat_cache := {}

static func other(side: String) -> String:
	return "e" if side == "p" else "p"

static func dist(ax: int, ay: int, bx: int, by: int) -> int:
	return absi(ax - bx) + absi(ay - by)

## JS Math.round (half up)
static func jround(x: float) -> int:
	return int(floor(x + 0.5))

static func _or(d: Dictionary, key: String, def: Variant) -> Variant:
	var v: Variant = d.get(key)
	return def if v == null else v

# ---------- setup ----------
static func new_game(def: Dictionary, opts := {}) -> Dictionary:
	var tiles := []
	for r: String in def.map.rows:
		var row := []
		for i in r.length():
			row.append(r[i])
		tiles.append(row)
	var gold := { "p": Rules.RULES.startGold, "e": Rules.RULES.startGold }
	gold.merge(_or(def, "gold", {}), true)
	var mul := { "p": 1, "e": 1 }
	mul.merge(_or(def, "incomeMul", {}), true)
	var win := { "type": "castles" }
	win.merge(_or(def, "win", {}), true)
	var allowed: Dictionary = _or(def, "allowed", {})
	var waves := []
	for w: Dictionary in _or(def, "waves", []):
		var c := w.duplicate()
		c.done = false
		waves.append(c)
	var s := {
		"v": 2, "scenario": def.id, "w": tiles[0].size(), "h": tiles.size(), "tiles": tiles, "owner": {}, "units": [], "graves": [],
		"gold": gold, "incomeMul": mul, "turn": 1, "side": "p",
		"heroKey": { "p": _or(opts, "hero", def.get("hero")), "e": def.get("enemyHero") },
		"heroDead": { "p": false, "e": false }, "winner": null, "reason": null, "nextId": 1,
		"win": win, "heroMustLive": bool(def.get("heroMustLive", false)),
		"allowed": { "p": Array(_or(allowed, "p", Rules.BUY_ORDER)).duplicate(), "e": Array(_or(allowed, "e", Rules.BUY_ORDER)).duplicate() },
		"waves": waves, "night": bool(def.get("night", false)), "hadCastle": {}, "unitCap": _or(def, "unitCap", Rules.RULES.unitCap),
	}
	for o: Array in _or(def, "owner", []):
		s.owner[Vector2i(o[0], o[1])] = o[2]
	for u: Array in _or(def, "units", []):
		spawn(s, u[0], u[1], u[2], u[3], false, u[4] if u.size() > 4 else {})
	for g: Array in _or(def, "graves", []):
		s.graves.append({ "x": g[0], "y": g[1], "ttl": 99 })
	for side: String in ["p", "e"]:
		s.hadCastle[side] = castles(s, side) > 0
	return s

static func spawn(s: Dictionary, side: String, type: String, x: int, y: int, acted := false, extra := {}) -> Dictionary:
	var u := { "id": s.nextId, "side": side, "type": type, "x": x, "y": y, "hp": 100, "xp": 0, "rank": 0, "acted": acted }
	s.nextId += 1
	u.merge(extra, true)
	if u.rank and not u.xp:
		u.xp = Rules.RULES.xpLevels[u.rank - 1]
	s.units.append(u)
	return u

static func stat(s: Dictionary, u: Dictionary) -> Dictionary:
	var base: Dictionary = Rules.UNITS[u.type]
	if u.type != "hero":
		return base
	var hk: Variant = s.heroKey[u.side]
	if not _hero_stat_cache.has(hk):
		var st := base.duplicate()
		if hk != null:
			st.merge(Rules.HEROES[hk], true)
		_hero_stat_cache[hk] = st
	return _hero_stat_cache[hk]

static func tile_at(s: Dictionary, x: int, y: int) -> Variant:
	if x >= 0 and y >= 0 and x < s.w and y < s.h:
		return s.tiles[y][x]
	return null

static func unit_at(s: Dictionary, x: int, y: int) -> Variant:
	for u: Dictionary in s.units:
		if u.x == x and u.y == y:
			return u
	return null

## tile -> first unit standing there (same answer as unit_at, built once per call site)
static func occupancy(s: Dictionary) -> Dictionary:
	var m := {}
	for u: Dictionary in s.units:
		var key := Vector2i(u.x, u.y)
		if not m.has(key):
			m[key] = u
	return m

static func unit_by_id(s: Dictionary, id: int) -> Variant:
	for u: Dictionary in s.units:
		if u.id == id:
			return u
	return null

static func grave_at(s: Dictionary, x: int, y: int) -> Variant:
	for g: Dictionary in s.graves:
		if g.x == x and g.y == y:
			return g
	return null

static func move_cost(move_class: String, t: Variant) -> float:
	if t == null:
		return INF
	if move_class == "fly":
		return 1
	var tr: Dictionary = Rules.TERRAIN[t]
	if tr.get("water", false):
		return 1 if move_class == "water" else INF
	if t == "m" and move_class == "heavy":
		return INF
	if (t == "m" or t == "h") and move_class == "mount":
		return 1
	return tr.cost

## index of the cheapest open entry, earliest-inserted among ties (= JS stable sort + shift)
static func _pop_min(open: Array) -> Array:
	var bi := 0
	for i in range(1, open.size()):
		if open[i][0] < open[bi][0]:
			bi = i
	return open.pop_at(bi)

## Dijkstra within move budget; passes allies, blocked by enemies; excludes occupied tiles except own start.
## returns { Vector2i: {cost, prev, x, y} } in discovery order
## every tile the unit can reach (stop or pass) with intact prev links; reachable() then drops tiles where an ally stands
static func _reach_all(s: Dictionary, u: Dictionary, occ: Dictionary) -> Dictionary:
	var st := stat(s, u)
	var mv: float = st.mv
	var mc: String = st.move
	var best := { Vector2i(u.x, u.y): { "cost": 0.0, "prev": null, "x": u.x, "y": u.y } }
	var open := [[0.0, u.x, u.y]]
	while open.size():
		var cur := _pop_min(open)
		var c: float = cur[0]
		var x: int = cur[1]
		var y: int = cur[2]
		if c > best[Vector2i(x, y)].cost:
			continue
		for d: Array in DIRS:
			var nx: int = x + d[0]
			var ny: int = y + d[1]
			var nc: float = c + move_cost(mc, tile_at(s, nx, ny))
			if nc > mv:
				continue
			var key := Vector2i(nx, ny)
			var o: Variant = occ.get(key)
			if o != null and o.side != u.side:
				continue
			var cb: Variant = best.get(key)
			if cb == null or nc < cb.cost:
				best[key] = { "cost": nc, "prev": Vector2i(x, y), "x": nx, "y": ny }
				open.append([nc, nx, ny])
	return best

static func reachable(s: Dictionary, u: Dictionary) -> Dictionary:
	var occ := occupancy(s)
	var best := _reach_all(s, u, occ)
	for key: Vector2i in best.keys():
		var o: Variant = occ.get(key)
		if o != null and o.id != u.id:
			best.erase(key)
	return best

## UI / animation route from the unit to (x, y): walks through allies (path_to on reachable() breaks there,
## because tiles with allies are dropped from it; that older path is still what the guard rule looks at)
static func path_for(s: Dictionary, u: Dictionary, x: int, y: int) -> Array:
	return path_to(_reach_all(s, u, occupancy(s)), x, y)

static func path_to(reach: Dictionary, x: int, y: int) -> Array:
	var out := []
	var cur: Variant = reach.get(Vector2i(x, y))
	while cur != null:
		out.push_front([cur.x, cur.y])
		cur = reach.get(cur.prev) if cur.prev != null else null
	return out

static func in_range(st: Dictionary, d: int) -> bool:
	return d >= st.rmin and d <= st.rmax

static func targets_from(s: Dictionary, u: Dictionary, fx: int, fy: int) -> Array:
	var st := stat(s, u)
	if st.get("siege", false) and (fx != u.x or fy != u.y):
		return []
	var out := []
	for o: Dictionary in s.units:
		if o.side != u.side and in_range(st, dist(fx, fy, o.x, o.y)):
			out.append(o)
	return out

## an ally of `side` next to (x,y), other than self_id, whose stats carry `flag`
static func _adjacent_flag(s: Dictionary, side: String, x: int, y: int, flag: String, self_id: int) -> bool:
	for o: Dictionary in s.units:
		if o.side == side and o.id != self_id and dist(o.x, o.y, x, y) == 1 and stat(s, o).get(flag, 0):
			return true
	return false

## UI helper, no rule effect: the positional bonuses unit u would get standing at (x, y) — same adjacency test as
## damage(): aura ally next to it -> +10 atk when it attacks, guard ally -> +10 def when it is hit; plus terrain def.
## Returns { atk, atk_from (unit or null), def, def_from, terrain }.
static func buffs_at(s: Dictionary, u: Dictionary, x: int, y: int) -> Dictionary:
	var out := { "atk": 0, "atk_from": null, "def": 0, "def_from": null, "terrain": terrain_def(s, u, x, y) }
	for o: Dictionary in s.units:
		if o.side != u.side or o.id == u.id or dist(o.x, o.y, x, y) != 1:
			continue
		var st := stat(s, o)
		if st.get("aura", 0) and out.atk_from == null:
			out.atk = 10
			out.atk_from = o
		if st.get("guard", 0) and out.def_from == null:
			out.def = 10
			out.def_from = o
	return out

static func terrain_def(s: Dictionary, u: Dictionary, x: int, y: int, attacker_magic := false) -> int:
	var st := stat(s, u)
	var t: String = tile_at(s, x, y)
	if st.move == "fly" or attacker_magic:
		return 0
	return Rules.TERRAIN[t].def + st.get("tBonus", {}).get(t, 0)

## attacker a standing at (ax,ay) with hp att_hp hits defender d at its tile
static func damage(s: Dictionary, a: Dictionary, ax: int, ay: int, att_hp: int, d: Dictionary) -> int:
	var sa := stat(s, a)
	var sd := stat(s, d)
	var A: float = sa.atk + Rules.RULES.rankBonus * a.rank
	if _adjacent_flag(s, a.side, ax, ay, "aura", a.id):
		A += 10
	if sa.get("antiAir", 0) and sd.move == "fly":
		A += sa.antiAir
	var D: float = sd.def + Rules.RULES.rankBonus * d.rank + terrain_def(s, d, d.x, d.y, sa.get("magic", false))
	if _adjacent_flag(s, d.side, d.x, d.y, "guard", d.id):
		D += 10
	var raw := maxf(A * Rules.RULES.minDmgFrac, A - D)
	return mini(d.hp, maxi(1, jround((raw * att_hp) / 100.0)))

static func can_counter(s: Dictionary, d: Dictionary, ax: int, ay: int) -> bool:
	var sd := stat(s, d)
	return not sd.get("siege", false) and in_range(sd, dist(ax, ay, d.x, d.y))

static func preview(s: Dictionary, u: Dictionary, fx: int, fy: int, target: Dictionary) -> Dictionary:
	var ox: int = u.x
	var oy: int = u.y
	u.x = fx # temp move so auras/positions are right
	u.y = fy
	var dmg := damage(s, u, fx, fy, u.hp, target)
	var counter := 0
	if dmg < target.hp and can_counter(s, target, fx, fy):
		var thp: int = target.hp
		target.hp -= dmg
		counter = damage(s, target, target.x, target.y, target.hp, u)
		target.hp = thp
	u.x = ox
	u.y = oy
	return { "dmg": dmg, "counter": counter, "kill": dmg >= target.hp, "die": counter >= u.hp }

static func can_capture(s: Dictionary, u: Dictionary, x: int, y: int) -> bool:
	var t: Variant = tile_at(s, x, y)
	var st := stat(s, u)
	if s.owner.get(Vector2i(x, y)) == u.side:
		return false
	return (t == "v" and st.get("capV", false)) or (t == "c" and st.get("capC", false))

static func raisable_graves(s: Dictionary, u: Dictionary, x: int, y: int) -> Array:
	if not stat(s, u).get("raise", false):
		return []
	var out := []
	for g: Dictionary in s.graves:
		if dist(g.x, g.y, x, y) == 1 and unit_at(s, g.x, g.y) == null:
			out.append(g)
	return out

static func _gain_xp(s: Dictionary, u: Dictionary, amount: int, ev: Array) -> void:
	u.xp += amount
	var lv: Array = Rules.RULES.xpLevels
	while u.rank < lv.size() and u.xp >= lv[u.rank]:
		u.rank += 1
		ev.append({ "t": "rank", "id": u.id, "rank": u.rank })

static func _kill(s: Dictionary, u: Dictionary, ev: Array) -> void:
	s.units = s.units.filter(func(o: Dictionary) -> bool: return o.id != u.id)
	if u.type == "hero":
		s.heroDead[u.side] = true
	elif not Rules.UNITS[u.type].get("noGrave", false):
		s.graves = s.graves.filter(func(g: Dictionary) -> bool: return g.x != u.x or g.y != u.y)
		s.graves.append({ "x": u.x, "y": u.y, "ttl": Rules.RULES.graveRounds })
	ev.append({ "t": "die", "id": u.id, "x": u.x, "y": u.y, "side": u.side, "type": u.type })

## act = {id, to:[x,y], kind:'attack'|'capture'|'raise'|'wait', target?: unit id | [x,y]}; returns events
static func do_action(s: Dictionary, act: Dictionary) -> Array:
	if s.winner != null:
		push_error("game over"); return []
	var u: Variant = unit_by_id(s, act.id)
	if u == null or u.side != s.side or u.acted:
		push_error("bad unit %s" % act); return []
	var tx: int = act.to[0]
	var ty: int = act.to[1]
	var reach := reachable(s, u)
	if not reach.has(Vector2i(tx, ty)):
		push_error("unreachable %s" % act); return []
	var d: Variant = null
	if act.kind == "attack":
		d = unit_by_id(s, act.target)
		if d == null or not targets_from(s, u, tx, ty).has(d):
			push_error("out of range %s" % act); return []
	var ev := []
	var path := path_to(reach, tx, ty) # breaks at allies; kept for the guard rule (JS parity)
	var route := path_for(s, u, tx, ty) # full route for the move animation
	u.x = tx
	u.y = ty
	if path.size() > 1 or act.kind != "wait":
		u.guard = false
	if route.size() > 1:
		ev.append({ "t": "move", "id": u.id, "path": route })

	if act.kind == "attack":
		d.guard = false
		var dmg := damage(s, u, tx, ty, u.hp, d)
		d.hp -= dmg
		ev.append({ "t": "hit", "from": u.id, "fx": tx, "fy": ty, "id": d.id, "amount": dmg, "x": d.x, "y": d.y, "type": u.type, "side": u.side })
		_gain_xp(s, u, dmg, ev)
		if d.hp <= 0:
			_gain_xp(s, u, Rules.RULES.killXp, ev)
			_kill(s, d, ev)
		elif can_counter(s, d, tx, ty):
			var c := damage(s, d, d.x, d.y, d.hp, u)
			u.hp -= c
			ev.append({ "t": "hit", "from": d.id, "fx": d.x, "fy": d.y, "id": u.id, "amount": c, "x": u.x, "y": u.y, "counter": true, "type": d.type, "side": d.side })
			_gain_xp(s, d, c, ev)
			if u.hp <= 0:
				_gain_xp(s, d, Rules.RULES.killXp, ev)
				_kill(s, u, ev)
	elif act.kind == "capture":
		if not can_capture(s, u, tx, ty):
			push_error("cannot capture"); return ev
		var key := Vector2i(tx, ty)
		var prev: Variant = s.owner.get(key)
		s.owner[key] = u.side
		ev.append({ "t": "capture", "x": tx, "y": ty, "side": u.side, "prev": prev, "tile": tile_at(s, tx, ty) })
	elif act.kind == "raise":
		var gx: int = act.target[0]
		var gy: int = act.target[1]
		if not raisable_graves(s, u, tx, ty).any(func(g: Dictionary) -> bool: return g.x == gx and g.y == gy):
			push_error("no grave"); return ev
		s.graves = s.graves.filter(func(g: Dictionary) -> bool: return g.x != gx or g.y != gy)
		var gh := spawn(s, u.side, "ghost", gx, gy, true)
		ev.append({ "t": "raise", "id": gh.id, "x": gx, "y": gy, "from": u.id })
	u.acted = true
	_check_winner(s, ev)
	return ev

static func buy_options(s: Dictionary, side: String, x: int, y: int) -> Array:
	if tile_at(s, x, y) != "c" or s.owner.get(Vector2i(x, y)) != side or unit_at(s, x, y) != null:
		return []
	var list := []
	for type: String in s.allowed[side]:
		list.append({ "type": type, "cost": Rules.UNITS[type].cost })
	if s.heroDead[side] and s.heroKey[side] != null:
		list.push_front({ "type": "hero", "cost": Rules.UNITS.hero.cost })
	var full: bool = unit_count(s, side) >= s.unitCap
	for o: Dictionary in list:
		o.ok = not full and s.gold[side] >= o.cost
	return list

static func buy(s: Dictionary, x: int, y: int, type: String) -> Variant:
	var opt: Variant = null
	for o: Dictionary in buy_options(s, s.side, x, y):
		if o.type == type:
			opt = o
	if opt == null or not opt.ok:
		push_error("cannot buy %s" % type); return null
	s.gold[s.side] -= opt.cost
	if type == "hero":
		s.heroDead[s.side] = false
	return spawn(s, s.side, type, x, y, true)

static func castle_tiles(s: Dictionary, side: String) -> Array:
	var out := []
	for key: Vector2i in s.owner:
		if s.owner[key] == side and tile_at(s, key.x, key.y) == "c":
			out.append(key)
	return out

static func castles(s: Dictionary, side: String) -> int:
	return castle_tiles(s, side).size()

static func villages(s: Dictionary, side: String) -> int:
	var n := 0
	for o: Variant in s.owner.values():
		if o == side:
			n += 1
	return n - castles(s, side)

static func income(s: Dictionary, side: String) -> int:
	return jround(((villages(s, side) * Rules.RULES.incomeVillage + castles(s, side) * Rules.RULES.incomeCastle) * s.incomeMul[side]) / 10.0) * 10

static func unit_count(s: Dictionary, side: String) -> int:
	var n := 0
	for u: Dictionary in s.units:
		if u.side == side:
			n += 1
	return n

static func pending_waves(s: Dictionary) -> bool:
	return s.waves.any(func(w: Dictionary) -> bool: return not w.done)

## win type "reach": our hero stands on one of win.at
static func hero_on_goal(s: Dictionary) -> bool:
	for u: Dictionary in s.units:
		if u.side == "p" and u.type == "hero":
			for g: Array in s.win.get("at", []):
				if u.x == g[0] and u.y == g[1]:
					return true
	return false

## a reason string when `side` has lost, else null
static func loss_reason(s: Dictionary, side: String) -> Variant:
	if side == "p" and s.heroMustLive and s.heroDead.p:
		return "heroFell"
	if side == "e" and s.win.type == "hero" and s.heroDead.e:
		return "heroKilled"
	if side == "e" and s.win.type == "reach" and hero_on_goal(s):
		return "reached"
	if side == "p" and s.win.type == "reach" and s.heroDead.p:
		return "heroFell"
	var c := castles(s, side)
	var n := unit_count(s, side)
	if c == 0 and s.hadCastle[side]:
		return "castlesLost"
	if n > 0:
		return null
	if side == "e" and pending_waves(s):
		return null
	if c == 0:
		return "routed"
	if s.gold[side] < Rules.UNITS.soldier.cost:
		return "routed"
	for key: Vector2i in castle_tiles(s, side):
		if unit_at(s, key.x, key.y) == null:
			return null
	return "routed"

static func _check_winner(s: Dictionary, ev: Array) -> void:
	if s.winner != null:
		return
	for side: String in [other(s.side), s.side]:
		var r: Variant = loss_reason(s, side)
		if r != null:
			s.winner = other(side)
			s.reason = r
			ev.append({ "t": "win", "side": s.winner, "reason": r })
			return

static func _free_tile_near(s: Dictionary, x: int, y: int, type: String) -> Variant:
	var mv: String = Rules.UNITS[type].move
	var seen := { Vector2i(x, y): true }
	var q := [[x, y]]
	while q.size():
		var c: Array = q.pop_front()
		if unit_at(s, c[0], c[1]) == null and move_cost(mv, tile_at(s, c[0], c[1])) != INF:
			return c
		for d: Array in DIRS:
			var nx: int = c[0] + d[0]
			var ny: int = c[1] + d[1]
			if tile_at(s, nx, ny) == null or seen.has(Vector2i(nx, ny)):
				continue
			seen[Vector2i(nx, ny)] = true
			q.append([nx, ny])
	return null

static func end_turn(s: Dictionary) -> Array:
	if s.winner != null:
		return []
	var ev := []
	s.side = other(s.side)
	if s.side == "p":
		s.turn += 1
		for g: Dictionary in s.graves:
			g.ttl -= 1
		s.graves = s.graves.filter(func(g: Dictionary) -> bool: return g.ttl > 0)
		if s.win.type == "survive" and s.turn > s.win.turns:
			s.winner = "p"
			s.reason = "survived"
			ev.append({ "t": "win", "side": "p", "reason": "survived" })
			return ev
		if s.win.type == "reach" and s.win.has("turns") and s.turn > s.win.turns:
			s.winner = "e"
			s.reason = "timeUp"
			ev.append({ "t": "win", "side": "e", "reason": "timeUp" })
			return ev
	else:
		for w: Dictionary in s.waves:
			if w.done or w.turn > s.turn:
				continue
			w.done = true
			for wu: Array in w.units:
				var at: Variant = _free_tile_near(s, wu[1], wu[2], wu[0])
				if at == null:
					continue
				var u := spawn(s, "e", wu[0], at[0], at[1], true, wu[3] if wu.size() > 3 else {})
				ev.append({ "t": "spawn", "id": u.id, "x": at[0], "y": at[1] })
	var inc := income(s, s.side)
	s.gold[s.side] += inc
	ev.append({ "t": "income", "side": s.side, "amount": inc })
	for u: Dictionary in s.units:
		if u.side != s.side:
			continue
		if not ev.any(func(e: Dictionary) -> bool: return e.t == "spawn" and e.id == u.id):
			u.acted = false
		if s.owner.get(Vector2i(u.x, u.y)) == u.side and u.hp < 100:
			var h := mini(Rules.RULES.heal, 100 - u.hp)
			u.hp += h
			ev.append({ "t": "heal", "id": u.id, "amount": h, "x": u.x, "y": u.y })
	_check_winner(s, ev)
	return ev
