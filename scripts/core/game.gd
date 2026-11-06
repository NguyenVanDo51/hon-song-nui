class_name Game
extends RefCounted
## pure rules engine, no nodes. A game starts from a mission/scenario def (docs/content.md).
## State is a Dictionary; tile keys are Vector2i. Rules follow AE2 (docs/review/rules_compare.html).

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
	var gold := { "p": RULES.startGold, "e": RULES.startGold }
	gold.merge(_or(def, "gold", {}), true)
	var win := { "type": "castles" }
	win.merge(_or(def, "win", {}), true)
	var allowed: Dictionary = _or(def, "allowed", {})
	var waves := []
	for w: Dictionary in _or(def, "waves", []):
		var c := w.duplicate()
		c.done = false
		waves.append(c)
	var s := {
		"v": 3, "seed": randi(), "scenario": def.id, "w": tiles[0].size(), "h": tiles.size(), "tiles": tiles, "owner": {}, "units": [], "graves": [],
		"gold": gold, "turn": 1, "side": "p",
		"heroKey": { "p": _or(opts, "hero", def.get("hero")), "e": def.get("enemyHero") },
		"heroDead": { "p": false, "e": false }, "heroDeaths": { "p": 0, "e": 0 }, "heroSaved": { "p": {}, "e": {} },
		"winner": null, "reason": null, "nextId": 1, "win": win,
		"allowed": { "p": Array(_or(allowed, "p", Rules.BUY_ORDER)).duplicate(), "e": Array(_or(allowed, "e", Rules.BUY_ORDER)).duplicate() },
		"waves": waves, "night": bool(def.get("night", false)), "hadCastle": {}, "unitCap": _or(def, "unitCap", RULES.unitCap),
	}
	for o: Array in _or(def, "owner", []):
		s.owner[Vector2i(o[0], o[1])] = o[2]
	for u: Array in _or(def, "units", []):
		spawn(s, u[0], u[1], u[2], u[3], false, u[4] if u.size() > 4 else {})
	s.rng = int(s.seed) & 0x7FFFFFFF
	for side: String in ["p", "e"]:
		s.hadCastle[side] = castles(s, side) > 0
	return s

## stat tables the rules read (tests may swap them)
static var UNITS: Dictionary = Rules.UNITS
static var HEROES: Dictionary = Rules.HEROES
static var RULES: Dictionary = Rules.RULES
static var TERRAIN: Dictionary = Rules.TERRAIN

static func use_tables(units: Dictionary, heroes: Dictionary, rules: Dictionary, terrain: Dictionary) -> void:
	UNITS = units; HEROES = heroes; RULES = rules; TERRAIN = terrain
	_hero_stat_cache.clear()

static func spawn(s: Dictionary, side: String, type: String, x: int, y: int, acted := false, extra := {}) -> Dictionary:
	var u := { "id": s.nextId, "side": side, "type": type, "x": x, "y": y, "hp": 100, "xp": 0, "rank": 0, "acted": acted }
	s.nextId += 1
	u.merge(extra, true)
	s.units.append(u)
	return u

static func stat(s: Dictionary, u: Dictionary) -> Dictionary:
	var base: Dictionary = UNITS[u.type]
	if u.type != "hero":
		return base
	var hk: Variant = s.heroKey[u.side]
	if not _hero_stat_cache.has(hk):
		var st := base.duplicate()
		if hk != null:
			st.merge(HEROES[hk], true)
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
	var tr: Dictionary = TERRAIN[t]
	if tr.get("water", false) and move_class == "water":
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
	if stacked(s, u): # two on one tile (just bought on an occupied castle): neither may stay put
		best.erase(Vector2i(u.x, u.y))
	return best

## another unit shares u's tile (only right after buying on an occupied castle)
static func stacked(s: Dictionary, u: Dictionary) -> bool:
	for o: Dictionary in s.units:
		if o.id != u.id and o.x == u.x and o.y == u.y:
			return true
	return false

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

## UI helper, no rule effect: live bonuses on u if it stood at (x, y): aura (+atk, from a drum, until its side's next
## turn), poison (-atk / -def), water bonus for the water class, terrain def. { atk, atk_from, def, poison, terrain }
static func buffs_at(s: Dictionary, u: Dictionary, x: int, y: int) -> Dictionary:
	var st := stat(s, u)
	var wet: bool = TERRAIN[tile_at(s, x, y)].get("water", false)
	var out := { "atk": 0, "atk_from": null, "def": 0, "def_from": null, "poison": 0, "terrain": terrain_def(s, u, x, y) }
	if u.get("aura") != null:
		out.atk += 10
		out.atk_from = "aura"
	if wet and st.get("waterAtk", 0):
		out.atk += st.waterAtk
		out.def += st.get("waterDef", 0)
		out.def_from = "water"
	if u.get("poison") != null:
		out.poison = 10
	return out

static func terrain_def(s: Dictionary, u: Dictionary, x: int, y: int) -> int:
	return TERRAIN[tile_at(s, x, y)].def

## attack values a can actually roll [min, max], before bonuses (rank adds to both ends).
## AE2 never rolls the table max: rnd in [atk, atkMax) (RM Renderer.java:120-123)
static func atk_range(s: Dictionary, a: Dictionary) -> Array:
	var sa := stat(s, a)
	var r: int = RULES.rankBonus * a.rank
	return [sa.atk + r, maxi(sa.atk, sa.get("atkMax", sa.atk) - 1) + r]

## everything on top of the rolled attack: +bonuses of a (at ax, ay) vs d, minus d's defence at its tile
static func _mods(s: Dictionary, a: Dictionary, ax: int, ay: int, d: Dictionary) -> int:
	var sa := stat(s, a)
	var sd := stat(s, d)
	var m := 0
	if sa.get("antiAir", 0) and sd.move == "fly":
		m += sa.antiAir
	if sa.get("vsGhost", 0) and d.type == "ghost":
		m += sa.vsGhost
	if sa.get("waterAtk", 0) and TERRAIN[tile_at(s, ax, ay)].get("water", false):
		m += sa.waterAtk
	if a.get("aura") != null:
		m += 10
	if a.get("poison") != null:
		m -= 10
	var D: int = sd.def + RULES.rankBonus * d.rank + terrain_def(s, d, d.x, d.y)
	if sd.get("waterDef", 0) and TERRAIN[tile_at(s, d.x, d.y)].get("water", false):
		D += sd.waterDef
	if d.get("poison") != null:
		D -= 10
	return m - D

## AE2: (rolled atk + bonuses - defence) x attacker hp / 100, rounded down, 0..d.hp. roll in [0,1): 0 = min, ->1 = atkMax - 1
static func damage(s: Dictionary, a: Dictionary, ax: int, ay: int, att_hp: int, d: Dictionary, roll := 0.5) -> int:
	var r := atk_range(s, a)
	var A: int = r[0] + mini(r[1] - r[0], int(floor(roll * (r[1] - r[0] + 1))))
	var raw := A + _mods(s, a, ax, ay, d)
	return clampi(int(floor(raw * att_hp / 100.0)), 0, d.hp)

## seeded per game: same save -> same rolls. fixed_roll >= 0 overrides (tests / scripted runs): 0 = min, ->1 = atkMax - 1
static var fixed_roll := -1.0
## highest roll value: damage(..., ROLL_TOP) = the real max
const ROLL_TOP := 0.999999

static func roll(s: Dictionary) -> float:
	if fixed_roll >= 0.0:
		return fixed_roll
	s.rng = (int(s.get("rng", 1)) * 1103515245 + 12345) & 0x7FFFFFFF
	return float(s.rng) / 2147483648.0

## AE2: only an adjacent defender that can hit at range 1 strikes back
static func can_counter(s: Dictionary, d: Dictionary, ax: int, ay: int) -> bool:
	var sd := stat(s, d)
	return not sd.get("siege", false) and sd.rmin == 1 and dist(ax, ay, d.x, d.y) == 1

## forecast: dmg / counter as min..max (+ mid for the AI). kill = sure kill, mayKill = possible; die / mayDie likewise
static func preview(s: Dictionary, u: Dictionary, fx: int, fy: int, target: Dictionary) -> Dictionary:
	var ox: int = u.x
	var oy: int = u.y
	u.x = fx # temp move so positions are right
	u.y = fy
	var lo := damage(s, u, fx, fy, u.hp, target, 0.0)
	var hi := damage(s, u, fx, fy, u.hp, target, ROLL_TOP)
	var mid := damage(s, u, fx, fy, u.hp, target, 0.5)
	var c_lo := 0
	var c_hi := 0
	var c_mid := 0
	var thp: int = target.hp
	if can_counter(s, target, fx, fy):
		if hi < thp:
			target.hp = thp - hi
			c_lo = damage(s, target, target.x, target.y, target.hp, u, 0.0)
		if lo < thp:
			target.hp = thp - lo
			c_hi = damage(s, target, target.x, target.y, target.hp, u, ROLL_TOP)
		if mid < thp:
			target.hp = thp - mid
			c_mid = damage(s, target, target.x, target.y, target.hp, u, 0.5)
		target.hp = thp
	u.x = ox
	u.y = oy
	return { "dmg": mid, "dmgMin": lo, "dmgMax": hi, "counter": c_mid, "counterMin": c_lo, "counterMax": c_hi,
		"kill": lo >= thp, "mayKill": hi >= thp, "die": c_lo >= u.hp, "mayDie": c_hi >= u.hp }

static func can_capture(s: Dictionary, u: Dictionary, x: int, y: int) -> bool:
	var t: Variant = tile_at(s, x, y)
	var st := stat(s, u)
	if s.owner.get(Vector2i(x, y)) == u.side:
		return false
	return (t == "v" and st.get("capV", false)) or (t == "c" and st.get("capC", false))

## villages a raze unit can wreck from (fx, fy): siege, so only from where it stands; enemy or unowned, in range, empty
static func razable_from(s: Dictionary, u: Dictionary, fx: int, fy: int) -> Array:
	var st := stat(s, u)
	if not st.get("raze", false) or fx != u.x or fy != u.y:
		return []
	var out := []
	var r: int = st.rmax
	for y in range(fy - r, fy + r + 1):
		for x in range(fx - r, fx + r + 1):
			if tile_at(s, x, y) == "v" and s.owner.get(Vector2i(x, y)) != u.side and in_range(st, dist(fx, fy, x, y)) \
					and unit_at(s, x, y) == null:
				out.append([x, y])
	return out

## a ruined village is repaired (back to an unowned village) by a unit that can capture villages, standing on it
static func can_repair(s: Dictionary, u: Dictionary, x: int, y: int) -> bool:
	return tile_at(s, x, y) == "x" and stat(s, u).get("capV", false)

static func raisable_graves(s: Dictionary, u: Dictionary, x: int, y: int) -> Array:
	if not stat(s, u).get("raise", false): # AE2: raised ghosts do not count toward the cap, so no cap check
		return []
	var out := []
	for g: Dictionary in s.graves:
		if dist(g.x, g.y, x, y) == 1 and unit_at(s, g.x, g.y) == null:
			out.append(g)
	return out

## AE2 "quality": atk + atkMax + def incl. rank bonus (+2 each per level) (RM Unit.java:255-258)
static func quality(s: Dictionary, u: Dictionary) -> int:
	var st := stat(s, u)
	return st.atk + st.get("atkMax", st.atk) + st.def + 3 * RULES.rankBonus * int(u.rank)

## xp for dealing dmg to victim: dmg x victim quality (RM Unit.java:250)
static func _gain_xp(s: Dictionary, u: Dictionary, dmg: int, victim: Dictionary) -> void:
	u.xp += dmg * quality(s, victim)

## xp needed for u's next level: own quality x xpScale (RM Unit.java:260-263)
static func xp_need(s: Dictionary, u: Dictionary) -> int:
	return int(quality(s, u) * RULES.xpScale)

## after a fight: at most one level, leftover xp carries
static func _promote(s: Dictionary, u: Dictionary, ev: Array) -> void:
	if u.hp <= 0 or u.rank >= RULES.maxRank:
		return
	var need := xp_need(s, u)
	if u.xp >= need:
		u.xp -= need
		u.rank += 1
		ev.append({ "t": "rank", "id": u.id, "rank": u.rank })

static func _kill(s: Dictionary, u: Dictionary, ev: Array) -> void:
	s.units = s.units.filter(func(o: Dictionary) -> bool: return o.id != u.id)
	if u.type == "hero":
		s.heroDead[u.side] = true
		s.heroDeaths[u.side] = int(s.heroDeaths.get(u.side, 0)) + 1
		s.heroSaved[u.side] = { "rank": u.rank, "xp": u.xp }
	elif not UNITS[u.type].get("noGrave", false):
		s.graves = s.graves.filter(func(g: Dictionary) -> bool: return g.x != u.x or g.y != u.y)
		s.graves.append({ "x": u.x, "y": u.y, "ttl": RULES.graveRounds })
	ev.append({ "t": "die", "id": u.id, "x": u.x, "y": u.y, "side": u.side, "type": u.type })

## act = {id, to:[x,y], kind:'attack'|'capture'|'raise'|'repair'|'raze'|'wait', target?: unit id | [x,y]}; returns events
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
	if act.kind == "raze" and not razable_from(s, u, tx, ty).has(act.get("target")):
		push_error("cannot raze %s" % act); return []
	if act.kind == "capture" or act.kind == "raise" or act.kind == "repair":
		# judged as if already standing on (tx, ty) — exactly what the checks below the move used to see
		var ox: int = u.x
		var oy: int = u.y
		u.x = tx
		u.y = ty
		var ok := can_capture(s, u, tx, ty) if act.kind == "capture" else (can_repair(s, u, tx, ty) if act.kind == "repair" \
			else raisable_graves(s, u, tx, ty).any(func(g: Dictionary) -> bool: return g.x == act.target[0] and g.y == act.target[1]))
		u.x = ox
		u.y = oy
		if not ok:
			push_error("cannot %s %s" % [act.kind, act]); return []
	var ev := []
	var route := path_for(s, u, tx, ty) # full route for the move animation
	u.x = tx
	u.y = ty
	if route.size() > 1 or act.kind != "wait":
		u.guard = false # scripted guards (mission defs) hold until they act
	if route.size() > 1:
		u.erase("offGoal")
	if act.kind == "attack":
		d.guard = false
	if route.size() > 1:
		ev.append({ "t": "move", "id": u.id, "path": route })
		# AE2: ending a move on a grave clears it
		var had: int = s.graves.size()
		s.graves = s.graves.filter(func(g: Dictionary) -> bool: return g.x != tx or g.y != ty)
		if s.graves.size() != had:
			ev.append({ "t": "graveGone", "x": tx, "y": ty })

	if act.kind == "attack":
		var dmg := damage(s, u, tx, ty, u.hp, d, roll(s))
		d.hp -= dmg
		ev.append({ "t": "hit", "from": u.id, "fx": tx, "fy": ty, "id": d.id, "amount": dmg, "x": d.x, "y": d.y, "type": u.type, "side": u.side })
		_gain_xp(s, u, dmg, d)
		if d.hp <= 0:
			_kill(s, d, ev)
		else:
			if can_counter(s, d, tx, ty):
				var c := damage(s, d, d.x, d.y, d.hp, u, roll(s))
				u.hp -= c
				ev.append({ "t": "hit", "from": d.id, "fx": d.x, "fy": d.y, "id": u.id, "amount": c, "x": u.x, "y": u.y, "counter": true, "type": d.type, "side": d.side })
				_gain_xp(s, d, c, u)
				if u.hp <= 0:
					_kill(s, u, ev)
			# AE2 wolf: after the counter, any hit the target survives (even 0 dmg, even if the wolf fell) weakens it
			# until our next turn (RM MainDisplayable finishAttack)
			if stat(s, u).get("poison", 0):
				d.poison = u.side
				ev.append({ "t": "poison", "id": d.id, "x": d.x, "y": d.y })
		_promote(s, u, ev)
		if d.hp > 0:
			_promote(s, d, ev)
	elif act.kind == "capture":
		var key := Vector2i(tx, ty)
		var prev: Variant = s.owner.get(key)
		s.owner[key] = u.side
		if tile_at(s, tx, ty) == "c":
			s.hadCastle[u.side] = true # spec: only a side that never held a castle falls by rout alone
		ev.append({ "t": "capture", "x": tx, "y": ty, "side": u.side, "prev": prev, "tile": tile_at(s, tx, ty) })
	elif act.kind == "raze":
		var key := Vector2i(act.target[0], act.target[1])
		var prev: Variant = s.owner.get(key)
		s.owner.erase(key)
		s.tiles[key.y][key.x] = "x"
		ev.append({ "t": "raze", "from": u.id, "fx": tx, "fy": ty, "x": key.x, "y": key.y, "prev": prev, "type": u.type, "side": u.side })
	elif act.kind == "repair":
		s.tiles[ty][tx] = "v"
		ev.append({ "t": "repair", "id": u.id, "x": tx, "y": ty, "side": u.side })
	elif act.kind == "raise":
		var gx: int = act.target[0]
		var gy: int = act.target[1]
		s.graves = s.graves.filter(func(g: Dictionary) -> bool: return g.x != gx or g.y != gy)
		var gh := spawn(s, u.side, "ghost", gx, gy, true)
		ev.append({ "t": "raise", "id": gh.id, "x": gx, "y": gy, "from": u.id })
	u.acted = true
	if stat(s, u).get("aura", 0): # AE2 wisp: allies within 2 get +atk until our next turn; also from where it fell (RM finishMove)
		var ids := []
		for o: Dictionary in s.units:
			if o.side == u.side and o.id != u.id and dist(o.x, o.y, u.x, u.y) <= 2:
				o.aura = u.side
				ids.append(o.id)
		if ids.size():
			ev.append({ "t": "aura", "from": u.id, "ids": ids })
	_check_winner(s, ev)
	return ev

## own castle; may hold one of our units (AE2: the new unit appears on it and must step off), never two
static func buy_options(s: Dictionary, side: String, x: int, y: int) -> Array:
	if tile_at(s, x, y) != "c" or s.owner.get(Vector2i(x, y)) != side:
		return []
	var here: Array = s.units.filter(func(o: Dictionary) -> bool: return o.x == x and o.y == y)
	# AE2 original (bytecode): the castle check looks only at the owner -> buying works under any one unit, even an
	# enemy standing there; the new unit stacks and must step off
	if here.size() > 1 or (here.size() == 1 and not RULES.get("buyAE2", false)):
		return []
	var busy: bool = here.size() == 1
	var list := []
	for type: String in s.allowed[side]:
		list.append({ "type": type, "cost": UNITS[type].cost })
	if s.heroDead[side] and s.heroKey[side] != null:
		list.push_front({ "type": "hero", "cost": hero_cost(s, side) })
	var full: bool = cap_count(s, side) >= s.unitCap
	for o: Dictionary in list:
		o.ok = not full and s.gold[side] >= o.cost and (not busy or _can_step_off(s, side, o.type, x, y))
	return list

## a unit of `type` placed on (x,y) next to another would have a free tile to move to
static func _can_step_off(s: Dictionary, side: String, type: String, x: int, y: int) -> bool:
	var probe := { "id": -1, "side": side, "type": type, "x": x, "y": y, "hp": 100, "xp": 0, "rank": 0, "acted": false }
	s.units.append(probe)
	var ok := reachable(s, probe).size() > 0
	s.units.pop_back()
	return ok

static func buy(s: Dictionary, x: int, y: int, type: String) -> Variant:
	var opt: Variant = null
	for o: Dictionary in buy_options(s, s.side, x, y):
		if o.type == type:
			opt = o
	if opt == null or not opt.ok:
		push_error("cannot buy %s" % type); return null
	s.gold[s.side] -= opt.cost
	var extra := {}
	if type == "hero":
		s.heroDead[s.side] = false
		extra = s.heroSaved.get(s.side, {}).duplicate() # AE2: the commander comes back with its level / xp
		if s.win.get("at", []).has([x, y]):
			extra.offGoal = true # bought on a reach goal: must walk off and back, buying there is not "reaching"
	extra.paid = { "cost": opt.cost, "turn": s.turn } # lets a buy on top of another unit be taken back (see unbuy)
	return spawn(s, s.side, type, x, y, not RULES.get("buyAE2", false), extra) # AE2: a bought unit moves / attacks this turn

## a unit bought this turn onto an occupied castle that has not stepped off yet (castle may be boxed in)
static func can_unbuy(s: Dictionary, u: Dictionary) -> bool:
	var p: Variant = u.get("paid")
	return p != null and p.turn == s.turn and u.side == s.side and not u.acted and stacked(s, u)

## take back such a buy: unit removed, gold refunded (commander: back to "dead", same rebuy price)
static func unbuy(s: Dictionary, id: int) -> bool:
	var u: Variant = unit_by_id(s, id)
	if u == null or not can_unbuy(s, u):
		return false
	s.gold[u.side] += u.paid.cost
	if u.type == "hero":
		s.heroDead[u.side] = true
	s.units.erase(u)
	return true

## AE2: 200 + 200 per death so far, capped at 1000
static func hero_cost(s: Dictionary, side: String) -> int:
	return mini(RULES.heroMax, RULES.heroBase + RULES.heroStep * int(s.get("heroDeaths", {}).get(side, 0)))

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
	return villages(s, side) * RULES.incomeVillage + castles(s, side) * RULES.incomeCastle

static func unit_count(s: Dictionary, side: String) -> int:
	var n := 0
	for u: Dictionary in s.units:
		if u.side == side:
			n += 1
	return n

## units counted toward unitCap (AE2: raised ghosts are not)
static func cap_count(s: Dictionary, side: String) -> int:
	var n := 0
	for u: Dictionary in s.units:
		if u.side == side and not UNITS[u.type].get("noCap", false):
			n += 1
	return n

static func hero_alive(s: Dictionary, side: String) -> bool:
	return s.units.any(func(u: Dictionary) -> bool: return u.side == side and u.type == "hero")

static func pending_waves(s: Dictionary) -> bool:
	return s.waves.any(func(w: Dictionary) -> bool: return not w.done)

## win type "reach": our hero stands on one of win.at
static func hero_on_goal(s: Dictionary) -> bool:
	for u: Dictionary in s.units:
		if u.side == "p" and u.type == "hero" and not u.get("offGoal", false):
			for g: Array in s.win.get("at", []):
				if u.x == g[0] and u.y == g[1]:
					return true
	return false

## a reason string when `side` has lost, else null.
## AE2: out = commander dead and no castle left, or no unit and no castle left. Mission goals (hero / reach) on top.
static func loss_reason(s: Dictionary, side: String) -> Variant:
	if side == "e" and s.win.type == "hero" and s.heroDead.e:
		return "heroKilled"
	if side == "e" and s.win.type == "reach" and hero_on_goal(s):
		return "reached"
	if side == "p" and s.win.type == "reach" and s.heroDead.p and castles(s, "p") == 0:
		return "heroFell" # reach needs the commander and no castle is left to rebuy it
	var c := castles(s, side)
	if c > 0:
		return null
	if s.hadCastle[side] and not hero_alive(s, side): # castle-less armies (some missions) only fall when wiped out
		return "castlesLost"
	if unit_count(s, side) > 0:
		return null
	if side == "e" and pending_waves(s):
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
	var mv: String = stat(s, { "type": type, "side": "e" }).move
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
	# AE2 graves: count down at the start of every side's turn
	for g: Dictionary in s.graves:
		g.ttl -= 1
	s.graves = s.graves.filter(func(g: Dictionary) -> bool: return g.ttl > 0)
	if s.side == "p":
		s.turn += 1
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
					push_warning("wave unit %s dropped: no free tile near %d,%d" % [wu[0], wu[1], wu[2]])
					continue
				var u := spawn(s, "e", wu[0], at[0], at[1], true, wu[3] if wu.size() > 3 else {})
				ev.append({ "t": "spawn", "id": u.id, "x": at[0], "y": at[1] })
	# aura / poison laid by this side last turn wear off now
	for u: Dictionary in s.units:
		if u.get("aura") == s.side:
			u.erase("aura")
		if u.get("poison") == s.side:
			u.erase("poison")
	var inc := income(s, s.side)
	s.gold[s.side] += inc
	ev.append({ "t": "income", "side": s.side, "amount": inc })
	for u: Dictionary in s.units:
		if u.side != s.side:
			continue
		if not ev.any(func(e: Dictionary) -> bool: return e.t == "spawn" and e.id == u.id):
			u.acted = false
		var k := Vector2i(u.x, u.y)
		var heals: bool = s.owner.get(k) == u.side or TERRAIN[tile_at(s, u.x, u.y)].get("temple", false)
		if heals and u.hp < 100:
			var h := mini(RULES.heal, 100 - u.hp)
			u.hp += h
			ev.append({ "t": "heal", "id": u.id, "amount": h, "x": u.x, "y": u.y })
	_check_winner(s, ev)
	return ev
