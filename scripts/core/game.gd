class_name Game
extends RefCounted
## pure rules engine, no nodes. A game starts from a mission/scenario def (docs/content.md).
## State is a Dictionary; tile keys are Vector2i. Rules follow AE2 (docs/review/rules_compare.html).

const DIRS := [[1, 0], [-1, 0], [0, 1], [0, -1]]
## highest roll value: damage(..., ROLL_TOP) = the real max
const ROLL_TOP := 0.999999

## stat tables the rules read (tests may swap them)
static var UNITS: Dictionary = Rules.UNITS
static var HEROES: Dictionary = Rules.HEROES
static var RULES: Dictionary = Rules.RULES
static var TERRAIN: Dictionary = Rules.TERRAIN
## seeded per game: same save -> same rolls. fixed_roll >= 0 overrides (tests / scripted runs): 0 = min, ->1 = atkMax - 1
static var fixed_roll := -1.0
static var _hero_stat_cache := { }

static func other(side: String) -> String:
	return "e" if side == "p" else "p"

static func dist(ax: int, ay: int, bx: int, by: int) -> int:
	return absi(ax - bx) + absi(ay - by)

## JS Math.round (half up)
static func jround(x: float) -> int:
	return floori(x + 0.5)

static func _or(d: Dictionary, key: String, def: Variant) -> Variant:
	var v: Variant = d.get(key)
	return def if v == null else v

# ---------- setup ----------
static func new_game(def: Dictionary, opts := { }) -> Dictionary:
	var tiles := []
	for r: String in def.map.rows:
		var row := []
		for i in r.length():
			row.append(r[i])
		tiles.append(row)
	var gold := { "p": RULES.startGold, "e": RULES.startGold }
	var gold_def: Dictionary = _or(def, "gold", { })
	gold.merge(gold_def, true)
	var win := { "type": "castles" }
	var win_def: Dictionary = _or(def, "win", { })
	win.merge(win_def, true)
	var allowed: Dictionary = _or(def, "allowed", { })
	var waves := []
	for w: Dictionary in _or(def, "waves", []):
		var c := w.duplicate()
		c.done = false
		waves.append(c)
	var row0: Array = tiles[0]
	var allowed_p: Array = _or(allowed, "p", Rules.BUY_ORDER)
	var allowed_e: Array = _or(allowed, "e", Rules.BUY_ORDER)
	var night: bool = def.get("night", false)
	var s := {
		"v": Content.STATE_V,
		"seed": randi(),
		"scenario": def.id,
		"w": row0.size(),
		"h": tiles.size(),
		"tiles": tiles,
		"owner": { },
		"units": [],
		"graves": [],
		"gold": gold,
		"turn": 1,
		"side": "p",
		"heroKey": { "p": _or(opts, "hero", def.get("hero")), "e": def.get("enemyHero") },
		"heroDead": { "p": false, "e": false },
		"heroDeaths": { "p": 0, "e": 0 },
		"heroSaved": { "p": { }, "e": { } },
		"lost": { "p": 0, "e": 0 },
		"winner": null,
		"reason": null,
		"nextId": 1,
		"win": win,
		"allowed": { "p": allowed_p.duplicate(), "e": allowed_e.duplicate() },
		"waves": waves,
		"night": night,
		"hadCastle": { },
		"unitCap": _or(def, "unitCap", RULES.unitCap),
	}
	var rules_def: Dictionary = _or(def, "rules", { }) # per-game RULES overrides (duel / skirmish comeback), Rules.of
	if not rules_def.is_empty():
		s.rules = rules_def.duplicate()
	var lv_ai: String = def.get("ai", "normal") # level enemy preset; "normal" = no ctrl key (state as before levels)
	var ctrl: Dictionary = def.get("ctrl", { "p": "human", "e": "ai:" + lv_ai } if lv_ai != "normal" else { })
	if not ctrl.is_empty(): # 1 vs 1 sets ctrl, a level may set ai; neither = p human, e AI normal (Content.ctrl_of)
		s.ctrl = ctrl.duplicate()
		var aip := { }
		for side: String in ["p", "e"]:
			var p := Content.ai_params_for(s, side)
			if not p.is_empty():
				aip[side] = p.duplicate()
		if not aip.is_empty(): # saved with the game: replay / continue use the same AI
			s.aiParams = aip
	for o: Array in _or(def, "owner", []):
		var ox: int = o[0]
		var oy: int = o[1]
		s.owner[Vector2i(ox, oy)] = o[2]
	for u: Array in _or(def, "units", []):
		var side: String = u[0]
		var type: String = u[1]
		var ux: int = u[2]
		var uy: int = u[3]
		var extra: Dictionary = u[4] if u.size() > 4 else { }
		spawn(s, side, type, ux, uy, false, extra)
	var seed_v: int = s.seed
	s.rng = seed_v & 0x7FFFFFFF
	for side: String in ["p", "e"]:
		s.hadCastle[side] = castles(s, side) > 0
	return s

static func use_tables(units: Dictionary, heroes: Dictionary, rules: Dictionary, terrain: Dictionary) -> void:
	UNITS = units
	HEROES = heroes
	RULES = rules
	TERRAIN = terrain
	_hero_stat_cache.clear()

static func spawn(s: Dictionary, side: String, type: String, x: int, y: int, acted := false, extra := { }) -> Dictionary:
	var u := { "id": s.nextId, "side": side, "type": type, "x": x, "y": y, "hp": 100, "xp": 0, "rank": 0, "acted": acted }
	s.nextId += 1
	u.merge(extra, true)
	var units: Array = s.units
	units.append(u)
	return u

static func stat(s: Dictionary, u: Dictionary) -> Dictionary:
	var base: Dictionary = UNITS[u.type]
	if u.type != "hero":
		return base
	var hk: Variant = s.heroKey[u.side]
	if not _hero_stat_cache.has(hk):
		var st := base.duplicate()
		if hk != null:
			var hero: Dictionary = HEROES[hk]
			st.merge(hero, true)
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
	var m := { }
	for u: Dictionary in s.units:
		var ux: int = u.x
		var uy: int = u.y
		var key := Vector2i(ux, uy)
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

## TERRAIN entry of a tile letter ({} off the map)
static func ter(t: Variant) -> Dictionary:
	return TERRAIN.get(t, { }) if t != null else { }

## gold per turn a tile pays its owner
static func income_of(t: Variant) -> int:
	var n: int = ter(t).get("income", 0)
	return n

## the owner buys units here (a castle)
static func sells(t: Variant) -> bool:
	return ter(t).get("sells", false)

## unit flag needed to capture the tile ("" = not capturable)
static func cap_flag(t: Variant) -> String:
	return ter(t).get("cap", "")

## stats st can capture or repair tile t (owner not checked)
static func can_take(st: Dictionary, t: Variant) -> bool:
	var f := cap_flag(t)
	if f != "" and st.get(f, false):
		return true
	var by: String = ter(t).get("repairBy", "")
	return by != "" and st.get(by, false)

## a unit of `side` standing on (x, y) heals at its turn start
static func heals_at(s: Dictionary, side: String, x: int, y: int) -> bool:
	var h: String = ter(tile_at(s, x, y)).get("heals", "")
	var owner: Dictionary = s.owner
	return h == "any" or (h == "owner" and owner.get(Vector2i(x, y)) == side)

static func move_cost(move_class: String, t: Variant) -> float:
	if t == null:
		return INF
	if move_class == "fly":
		return 1
	var tt: Dictionary = TERRAIN[t]
	if tt.get("water", false) and move_class == "water":
		return 1
	if move_class == "beast" and tt.get("rough", false):
		return 1
	return tt.cost

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
	var ux: int = u.x
	var uy: int = u.y
	var best := { Vector2i(ux, uy): { "cost": 0.0, "prev": null, "x": u.x, "y": u.y } }
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
		var ux: int = u.x
		var uy: int = u.y
		best.erase(Vector2i(ux, uy))
	return best

## UI only: tiles u could hit next turn (in range of any `reach` stop tile; siege: only from its own tile). { Vector2i: true }
static func threat_tiles(s: Dictionary, u: Dictionary, reach: Dictionary) -> Dictionary:
	var st := stat(s, u)
	var rmin: int = st.rmin
	var rmax: int = st.rmax
	var w: int = s.w
	var h: int = s.h
	var ux: int = u.x
	var uy: int = u.y
	var froms: Array = [Vector2i(ux, uy)] if st.get("siege", false) else reach.keys()
	var out := { }
	for f: Vector2i in froms:
		for dy in range(-rmax, rmax + 1):
			for dx in range(-rmax, rmax + 1):
				var d := absi(dx) + absi(dy)
				var tx := f.x + dx
				var ty := f.y + dy
				if d >= rmin and d <= rmax and tx >= 0 and ty >= 0 and tx < w and ty < h:
					out[Vector2i(tx, ty)] = true
	return out

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
		var ox: int = o.x
		var oy: int = o.y
		if o.side != u.side and in_range(st, dist(fx, fy, ox, oy)):
			out.append(o)
	return out

## stamps on a unit: `aura` / `poison` = side that laid it (wears off at that side's next turn), auraAtk / poisonAmt = amount
static func aura_atk(u: Dictionary) -> int:
	if u.get("aura") == null:
		return 0
	var n: int = u.get("auraAtk", 0)
	return n

static func poison_amt(u: Dictionary) -> int:
	if u.get("poison") == null:
		return 0
	var n: int = u.get("poisonAmt", 0)
	return n

static func terrain_def(s: Dictionary, _u: Dictionary, x: int, y: int) -> int:
	return TERRAIN[tile_at(s, x, y)].def

## attack values a can actually roll [min, max], before bonuses (rank adds to both ends).
## AE2 never rolls the table max: rnd in [atk, atkMax) (RM Renderer.java:120-123)
static func atk_range(s: Dictionary, a: Dictionary) -> Array:
	var sa := stat(s, a)
	var r: int = RULES.rankBonus * a.rank
	var atk: int = sa.atk
	var atk_max: int = sa.get("atkMax", sa.atk)
	return [atk + r, maxi(atk, atk_max - 1) + r]

## everything on top of the rolled attack: +bonuses of a (at ax, ay) vs d, minus d's defence at its tile
static func _mods(s: Dictionary, a: Dictionary, ax: int, ay: int, d: Dictionary) -> int:
	var sa := stat(s, a)
	var sd := stat(s, d)
	var m := 0
	if sa.get("antiAir", 0) and sd.move == "fly":
		m += sa.antiAir
	var vs: Dictionary = sa.get("vsType", { })
	var vs_bonus: int = vs.get(d.type, 0)
	m += vs_bonus
	if sa.get("waterAtk", 0):
		var at: Dictionary = TERRAIN[tile_at(s, ax, ay)]
		if at.get("water", false):
			m += sa.waterAtk
	m += aura_atk(a)
	m -= poison_amt(a)
	var dx: int = d.x
	var dy: int = d.y
	var D: int = sd.def + RULES.rankBonus * d.rank
	if not sa.get("pierce", false): # catapult: terrain gives no cover
		D += terrain_def(s, d, dx, dy)
	if sd.get("waterDef", 0):
		var dt: Dictionary = TERRAIN[tile_at(s, dx, dy)]
		if dt.get("water", false):
			D += sd.waterDef
	D -= poison_amt(d)
	return m - D

## AE2: (rolled atk + bonuses - defence) x attacker hp / 100, rounded down, 0..d.hp. rv in [0,1): 0 = min, ->1 = atkMax - 1
static func damage(s: Dictionary, a: Dictionary, ax: int, ay: int, att_hp: int, d: Dictionary, rv := 0.5) -> int:
	var r := atk_range(s, a)
	var lo: int = r[0]
	var hi: int = r[1]
	var A: int = lo + mini(hi - lo, floori(rv * (hi - lo + 1)))
	var raw := A + _mods(s, a, ax, ay, d)
	var dhp: int = d.hp
	return clampi(floori(raw * att_hp / 100.0), 0, dhp)

static func roll(s: Dictionary) -> float:
	if fixed_roll >= 0.0:
		return fixed_roll
	var prev: int = s.get("rng", 1)
	var next := (prev * 1103515245 + 12345) & 0x7FFFFFFF
	s.rng = next
	return float(next) / 2147483648.0

## AE2: only an adjacent defender that can hit at range 1 strikes back
static func can_counter(s: Dictionary, d: Dictionary, ax: int, ay: int) -> bool:
	var sd := stat(s, d)
	var dx: int = d.x
	var dy: int = d.y
	return sd.rmin == 1 and dist(ax, ay, dx, dy) == 1

## forecast: dmg / counter as min..max (+ mid for the AI). kill = sure kill, mayKill = possible; die / mayDie likewise
static func preview(s: Dictionary, u: Dictionary, fx: int, fy: int, target: Dictionary) -> Dictionary:
	var ox: int = u.x
	var oy: int = u.y
	u.x = fx # temp move so positions are right
	u.y = fy
	var uhp: int = u.hp
	var lo := damage(s, u, fx, fy, uhp, target, 0.0)
	var hi := damage(s, u, fx, fy, uhp, target, ROLL_TOP)
	var mid := damage(s, u, fx, fy, uhp, target, 0.5)
	var c_lo := 0
	var c_hi := 0
	var c_mid := 0
	var thp: int = target.hp
	var tx: int = target.x
	var ty: int = target.y
	if can_counter(s, target, fx, fy):
		if hi < thp:
			target.hp = thp - hi
			c_lo = damage(s, target, tx, ty, thp - hi, u, 0.0)
		if lo < thp:
			target.hp = thp - lo
			c_hi = damage(s, target, tx, ty, thp - lo, u, ROLL_TOP)
		if mid < thp:
			target.hp = thp - mid
			c_mid = damage(s, target, tx, ty, thp - mid, u, 0.5)
		target.hp = thp
	u.x = ox
	u.y = oy
	return {
		"dmg": mid,
		"dmgMin": lo,
		"dmgMax": hi,
		"counter": c_mid,
		"counterMin": c_lo,
		"counterMax": c_hi,
		"kill": lo >= thp,
		"mayKill": hi >= thp,
		"die": c_lo >= u.hp,
		"mayDie": c_hi >= u.hp,
	}

static func can_capture(s: Dictionary, u: Dictionary, x: int, y: int) -> bool:
	var t: Variant = tile_at(s, x, y)
	var st := stat(s, u)
	var owner: Dictionary = s.owner
	if owner.get(Vector2i(x, y)) == u.side:
		return false
	var f := cap_flag(t)
	return f != "" and st.get(f, false)

## buildings (razeTo) a raze unit can wreck from (fx, fy): siege, so only from where it stands; enemy or unowned, in range, empty
static func razable_from(s: Dictionary, u: Dictionary, fx: int, fy: int) -> Array:
	var st := stat(s, u)
	if not st.get("raze", false) or fx != u.x or fy != u.y:
		return []
	var out := []
	var r: int = st.rmax
	var owner: Dictionary = s.owner
	for y in range(fy - r, fy + r + 1):
		for x in range(fx - r, fx + r + 1):
			if ter(tile_at(s, x, y)).has("razeTo") and owner.get(Vector2i(x, y)) != u.side and in_range(st, dist(fx, fy, x, y)) \
					and unit_at(s, x, y) == null:
				out.append([x, y])
	return out

## a ruin (repairTo) is repaired (back to an unowned building) by a unit with its repairBy flag, standing on it
static func can_repair(s: Dictionary, u: Dictionary, x: int, y: int) -> bool:
	var by: String = ter(tile_at(s, x, y)).get("repairBy", "")
	return by != "" and stat(s, u).get(by, false)

static func raisable_graves(s: Dictionary, u: Dictionary, x: int, y: int) -> Array:
	if not stat(s, u).get("raise", false): # AE2: raised ghosts do not count toward the cap, so no cap check
		return []
	var out := []
	for g: Dictionary in s.graves:
		var gx: int = g.x
		var gy: int = g.y
		if dist(gx, gy, x, y) == 1 and unit_at(s, gx, gy) == null:
			out.append(g)
	return out

## AE2 "quality": atk + atkMax + def incl. rank bonus (+2 each per level) (RM Unit.java:255-258)
static func quality(s: Dictionary, u: Dictionary) -> int:
	var st := stat(s, u)
	var rank: int = u.rank
	return st.atk + st.get("atkMax", st.atk) + st.def + 3 * RULES.rankBonus * rank

## xp for dealing dmg to victim: dmg x victim quality (RM Unit.java:250)
static func _gain_xp(s: Dictionary, u: Dictionary, dmg: int, victim: Dictionary) -> void:
	u.xp += dmg * quality(s, victim)

## xp needed for u's next level: own quality x xpScale (RM Unit.java:260-263)
static func xp_need(s: Dictionary, u: Dictionary) -> int:
	var scale: float = RULES.xpScale
	return int(quality(s, u) * scale)

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
	var units: Array = s.units
	s.units = units.filter(
		func(o: Dictionary) -> bool:
			return o.id != u.id,
	)
	if u.type == "hero":
		s.heroDead[u.side] = true
		var deaths: Dictionary = s.heroDeaths
		deaths[u.side] = deaths.get(u.side, 0) + 1
		s.heroSaved[u.side] = { "rank": u.rank, "xp": u.xp }
	else:
		var base: Dictionary = UNITS[u.type]
		if base.get("buyable", true): # summons (ghosts) don't count as losses (mission stars)
			var lost: Dictionary = s.get("lost", { })
			var nl: int = lost.get(u.side, 0)
			lost[u.side] = nl + 1
			s.lost = lost
		if not base.get("noGrave", false):
			var graves: Array = s.graves
			graves = graves.filter(
				func(g: Dictionary) -> bool:
					return g.x != u.x or g.y != u.y,
			)
			graves.append({ "x": u.x, "y": u.y, "ttl": RULES.graveRounds })
			s.graves = graves
	s.gold["e" if u.side == "p" else "p"] += Rules.bounty(s, u) # kill bounty by rank (s.rules, research; 0 by default)
	ev.append({ "t": "die", "id": u.id, "x": u.x, "y": u.y, "side": u.side, "type": u.type })

## act = {id, to:[x,y], kind:'attack'|'capture'|'raise'|'repair'|'raze'|'wait', target?: unit id | [x,y]}; returns events
static func do_action(s: Dictionary, act: Dictionary) -> Array:
	if s.winner != null:
		push_error("game over")
		return []
	var aid: int = act.id
	var uv: Variant = unit_by_id(s, aid)
	if uv == null or uv.side != s.side or uv.acted:
		push_error("bad unit %s" % act)
		return []
	var u: Dictionary = uv
	var tx: int = act.to[0]
	var ty: int = act.to[1]
	var reach := reachable(s, u)
	if not reach.has(Vector2i(tx, ty)):
		push_error("unreachable %s" % act)
		return []
	var d: Dictionary = { } # set only for attack
	if act.kind == "attack":
		var tid: int = act.target
		var dv: Variant = unit_by_id(s, tid)
		if dv == null or not targets_from(s, u, tx, ty).has(dv):
			push_error("out of range %s" % act)
			return []
		d = dv
	if act.kind == "raze" and not razable_from(s, u, tx, ty).has(act.get("target")):
		push_error("cannot raze %s" % act)
		return []
	if act.kind == "capture" or act.kind == "raise" or act.kind == "repair":
		# judged as if already standing on (tx, ty) — exactly what the checks below the move used to see
		var ox: int = u.x
		var oy: int = u.y
		u.x = tx
		u.y = ty
		var ok := (
			can_capture(s, u, tx, ty)
			if act.kind == "capture"
			else (
				can_repair(s, u, tx, ty) if act.kind == "repair" \
						else raisable_graves(s, u, tx, ty).any(
					func(g: Dictionary) -> bool:
						return g.x == act.target[0] and g.y == act.target[1],
				)
			)
		)
		u.x = ox
		u.y = oy
		if not ok:
			push_error("cannot %s %s" % [act.kind, act])
			return []
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
		var graves: Array = s.graves
		var left := graves.filter(
			func(g: Dictionary) -> bool:
				return g.x != tx or g.y != ty,
		)
		s.graves = left
		if left.size() != graves.size():
			ev.append({ "t": "graveGone", "x": tx, "y": ty })

	if act.kind == "attack":
		var uhp: int = u.hp
		var dmg := damage(s, u, tx, ty, uhp, d, roll(s))
		d.hp -= dmg
		ev.append({ "t": "hit", "from": u.id, "fx": tx, "fy": ty, "id": d.id, "amount": dmg, "x": d.x, "y": d.y, "type": u.type, "side": u.side })
		_gain_xp(s, u, dmg, d)
		if d.hp <= 0:
			_kill(s, d, ev)
		else:
			if can_counter(s, d, tx, ty):
				var dx: int = d.x
				var dy: int = d.y
				var dhp: int = d.hp
				var c := damage(s, d, dx, dy, dhp, u, roll(s))
				u.hp -= c
				ev.append(
					{
						"t": "hit",
						"from": d.id,
						"fx": d.x,
						"fy": d.y,
						"id": u.id,
						"amount": c,
						"x": u.x,
						"y": u.y,
						"counter": true,
						"type": d.type,
						"side": d.side,
					}
				)
				_gain_xp(s, d, c, u)
				if u.hp <= 0:
					_kill(s, u, ev)
			# AE2 wolf: after the counter, any hit the target survives (even 0 dmg, even if the wolf fell) weakens it
			# until our next turn (RM MainDisplayable finishAttack)
			var pa: int = stat(s, u).get("poison", 0)
			if pa:
				d.poison = u.side
				d.poisonAmt = pa
				ev.append({ "t": "poison", "id": d.id, "x": d.x, "y": d.y, "amount": pa })
		_promote(s, u, ev)
		if d.hp > 0:
			_promote(s, d, ev)
	elif act.kind == "capture":
		var key := Vector2i(tx, ty)
		var owner: Dictionary = s.owner
		var prev: Variant = owner.get(key)
		s.owner[key] = u.side
		if sells(tile_at(s, tx, ty)):
			s.hadCastle[u.side] = true # spec: only a side that never held a castle falls by rout alone
		ev.append({ "t": "capture", "x": tx, "y": ty, "side": u.side, "prev": prev, "tile": tile_at(s, tx, ty) })
	elif act.kind == "raze":
		var rx: int = act.target[0]
		var ry: int = act.target[1]
		var key := Vector2i(rx, ry)
		var owner: Dictionary = s.owner
		var prev: Variant = owner.get(key)
		var was: String = s.tiles[key.y][key.x]
		owner.erase(key)
		s.tiles[key.y][key.x] = ter(was).razeTo
		ev.append(
			{ "t": "raze", "from": u.id, "fx": tx, "fy": ty, "x": key.x, "y": key.y, "prev": prev, "tile": was, "type": u.type, "side": u.side }
		)
	elif act.kind == "repair":
		var was: String = s.tiles[ty][tx]
		s.tiles[ty][tx] = ter(was).repairTo
		ev.append({ "t": "repair", "id": u.id, "x": tx, "y": ty, "tile": was, "side": u.side })
	elif act.kind == "raise":
		var gx: int = act.target[0]
		var gy: int = act.target[1]
		var graves: Array = s.graves
		s.graves = graves.filter(
			func(g: Dictionary) -> bool:
				return g.x != gx or g.y != gy,
		)
		var side: String = u.side
		var raised: String = stat(s, u).raise
		var gh := spawn(s, side, raised, gx, gy, true)
		ev.append({ "t": "raise", "id": gh.id, "x": gx, "y": gy, "from": u.id })
	u.acted = true
	var aa: int = stat(s, u).get("aura", 0)
	if aa: # AE2 wisp: allies within 2 get +atk until our next turn; also from where it fell (RM finishMove)
		var ids := []
		var ux: int = u.x
		var uy: int = u.y
		for o: Dictionary in s.units:
			var ox: int = o.x
			var oy: int = o.y
			if o.side == u.side and o.id != u.id and dist(ox, oy, ux, uy) <= 2:
				o.auraAtk = maxi(aura_atk(o), aa) # two drums do not stack: the bigger one counts
				o.aura = u.side
				ids.append(o.id)
		if ids.size():
			ev.append({ "t": "aura", "from": u.id, "ids": ids, "amount": aa })
	_check_winner(s, ev)
	return ev

## own castle (sells); may hold one of our units (AE2: the new unit appears on it and must step off), never two
static func buy_options(s: Dictionary, side: String, x: int, y: int) -> Array:
	var owner: Dictionary = s.owner
	if not sells(tile_at(s, x, y)) or owner.get(Vector2i(x, y)) != side:
		return []
	var units: Array = s.units
	var here: Array = units.filter(
		func(o: Dictionary) -> bool:
			return o.x == x and o.y == y,
	)
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
		var otype: String = o.type
		o.ok = not full and s.gold[side] >= o.cost and (not busy or _can_step_off(s, side, otype, x, y))
	return list

## a unit of `type` placed on (x,y) next to another would have a free tile to move to
static func _can_step_off(s: Dictionary, side: String, type: String, x: int, y: int) -> bool:
	var probe := { "id": -1, "side": side, "type": type, "x": x, "y": y, "hp": 100, "xp": 0, "rank": 0, "acted": false }
	var units: Array = s.units
	units.append(probe)
	var ok := reachable(s, probe).size() > 0
	units.pop_back()
	return ok

static func buy(s: Dictionary, x: int, y: int, type: String) -> Variant:
	var side: String = s.side
	var opt: Variant = null
	for o: Dictionary in buy_options(s, side, x, y):
		if o.type == type:
			opt = o
	if opt == null or not opt.ok:
		push_error("cannot buy %s" % type)
		return null
	s.gold[s.side] -= opt.cost
	var extra := { }
	if type == "hero":
		s.heroDead[s.side] = false
		var saved_all: Dictionary = s.heroSaved
		var saved: Dictionary = saved_all.get(s.side, { })
		extra = saved.duplicate() # AE2: the commander comes back with its level / xp
		var win: Dictionary = s.win
		var goals: Array = win.get("at", [])
		if goals.has([x, y]):
			extra.offGoal = true # bought on a reach goal: must walk off and back, buying there is not "reaching"
	extra.paid = { "cost": opt.cost, "turn": s.turn } # lets a buy on top of another unit be taken back (see unbuy)
	var ae2: bool = RULES.get("buyAE2", false)
	return spawn(s, side, type, x, y, not ae2, extra) # AE2: a bought unit moves / attacks this turn

## a unit bought this turn onto an occupied castle that has not stepped off yet (castle may be boxed in)
static func can_unbuy(s: Dictionary, u: Dictionary) -> bool:
	var p: Variant = u.get("paid")
	return p != null and p.turn == s.turn and u.side == s.side and not u.acted and stacked(s, u)

## take back such a buy: unit removed, gold refunded (commander: back to "dead", same rebuy price)
static func unbuy(s: Dictionary, id: int) -> bool:
	var uv: Variant = unit_by_id(s, id)
	if uv == null:
		return false
	var u: Dictionary = uv
	if not can_unbuy(s, u):
		return false
	s.gold[u.side] += u.paid.cost
	if u.type == "hero":
		s.heroDead[u.side] = true
	var units: Array = s.units
	units.erase(u)
	return true

## AE2: 200 + 200 per death so far, capped at 1000 (duel / skirmish: heroStep 0 = flat 200)
static func hero_cost(s: Dictionary, side: String) -> int:
	var deaths: Dictionary = s.get("heroDeaths", { })
	var n: int = deaths.get(side, 0)
	return mini(Rules.of(s, "heroMax"), Rules.of(s, "heroBase") + Rules.of(s, "heroStep") * n)

## owned tiles that sell units (castles), in owner order
static func castle_tiles(s: Dictionary, side: String) -> Array:
	var out := []
	for key: Vector2i in s.owner:
		if s.owner[key] == side and sells(tile_at(s, key.x, key.y)):
			out.append(key)
	return out

static func castles(s: Dictionary, side: String) -> int:
	return castle_tiles(s, side).size()

## owned buildings that do not sell (villages)
static func villages(s: Dictionary, side: String) -> int:
	var n := 0
	for key: Vector2i in s.owner:
		if s.owner[key] == side and not sells(tile_at(s, key.x, key.y)):
			n += 1
	return n

## sum of what every owned tile pays + the game's flat base pay (duel / skirmish comeback rule; 0 elsewhere)
static func income(s: Dictionary, side: String) -> int:
	var n := Rules.of(s, "baseIncome")
	for key: Vector2i in s.owner:
		if s.owner[key] == side:
			n += income_of(tile_at(s, key.x, key.y))
	return n

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
		if u.side != side:
			continue
		var base: Dictionary = UNITS[u.type]
		if not base.get("noCap", false):
			n += 1
	return n

static func hero_alive(s: Dictionary, side: String) -> bool:
	var units: Array = s.units
	return units.any(
		func(u: Dictionary) -> bool:
			return u.side == side and u.type == "hero",
	)

static func pending_waves(s: Dictionary) -> bool:
	var waves: Array = s.waves
	return waves.any(
		func(w: Dictionary) -> bool:
			return not w.done,
	)

## win type "reach": our hero stands on one of win.at
static func hero_on_goal(s: Dictionary) -> bool:
	var win: Dictionary = s.win
	for u: Dictionary in s.units:
		if u.side == "p" and u.type == "hero" and not u.get("offGoal", false):
			for g: Array in win.get("at", []):
				if u.x == g[0] and u.y == g[1]:
					return true
	return false

## a reason string when `side` has lost, else null.
## AE2: out = commander dead and no castle left, or no unit and no castle left. Mission goals (Objectives) on top.
static func loss_reason(s: Dictionary, side: String) -> Variant:
	var goal: Variant = Objectives.loss(s, side)
	if goal != null:
		return goal
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
	var cur: String = s.side
	for side: String in [other(cur), cur]:
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
		var cx: int = c[0]
		var cy: int = c[1]
		if unit_at(s, cx, cy) == null and move_cost(mv, tile_at(s, cx, cy)) != INF:
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
	var prev_side: String = s.side
	s.side = other(prev_side)
	# AE2 graves: count down at the start of every side's turn
	var graves: Array = s.graves
	for g: Dictionary in graves:
		g.ttl -= 1
	s.graves = graves.filter(
		func(g: Dictionary) -> bool:
			return g.ttl > 0,
	)
	if s.side == "p":
		s.turn += 1
		var w: Variant = Objectives.on_round(s) # [winner, reason]: survive / time limits
		if w != null:
			s.winner = w[0]
			s.reason = w[1]
			ev.append({ "t": "win", "side": w[0], "reason": w[1] })
			return ev
	else:
		for w: Dictionary in s.waves:
			if w.done or w.turn > s.turn:
				continue
			w.done = true
			for wu: Array in w.units:
				var wtype: String = wu[0]
				var wx: int = wu[1]
				var wy: int = wu[2]
				var at: Variant = _free_tile_near(s, wx, wy, wtype)
				if at == null:
					push_warning("wave unit %s dropped: no free tile near %d,%d" % [wu[0], wu[1], wu[2]])
					continue
				var ax: int = at[0]
				var ay: int = at[1]
				var extra: Dictionary = wu[3] if wu.size() > 3 else { }
				var u := spawn(s, "e", wtype, ax, ay, true, extra)
				ev.append({ "t": "spawn", "id": u.id, "x": at[0], "y": at[1] })
	# aura / poison laid by this side last turn wear off now
	for u: Dictionary in s.units:
		if u.get("aura") == s.side:
			u.erase("aura")
			u.erase("auraAtk")
		if u.get("poison") == s.side:
			u.erase("poison")
			u.erase("poisonAmt")
	var side: String = s.side
	var inc := income(s, side)
	s.gold[s.side] += inc
	ev.append({ "t": "income", "side": s.side, "amount": inc })
	var heal: int = RULES.heal
	for u: Dictionary in s.units:
		if u.side != s.side:
			continue
		if not ev.any(
			func(e: Dictionary) -> bool:
				return e.t == "spawn" and e.id == u.id,
		):
			u.acted = false
		var ux: int = u.x
		var uy: int = u.y
		var uhp: int = u.hp
		var amt := heal if heals_at(s, side, ux, uy) else 0
		amt = maxi(amt, Buffs.heal_aura(s, u))
		if amt > 0 and uhp < 100:
			var h := mini(amt, 100 - uhp)
			u.hp += h
			ev.append({ "t": "heal", "id": u.id, "amount": h, "x": u.x, "y": u.y })
	_check_winner(s, ev)
	return ev
