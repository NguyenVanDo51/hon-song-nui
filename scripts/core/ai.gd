class_name AI
extends RefCounted
## enemy AI (also the hint button and the sim's player side). Scores use the mid damage roll.
## One step at a time so the UI can animate: next_step() -> {kind:'act', act} | {kind:'buy', x, y, type} | null (= end turn).

## buy weight for a type without `aiWeight` (a new unit still gets bought, never crashes the AI)
const DEFAULT_WEIGHT := 1.0

## every scoring knob; a side's override = s.aiParams[side] (partial dict merged over this; absent = DEFAULT, save unchanged)
## 1 vs 1 difficulty: partial overrides of DEFAULT (measured in docs/ai.md: easy < normal < hard)
const PRESETS := {
	"easy": { "noise": 60.0, "caution": 0.0, "caution_hero": 0.3, "home_hp": 0.0, "heal_hp": 0.0, "maydie_w": 0.1 }, # reckless
	"normal": { },
	# v1 knobs (sim/tuned_params.txt) + whole-turn planner (AIPlan, docs/ai.md "Khó v2") + human tactics (v3)
	"hard": {
		"hp_cap": 81.2937,
		"kill_hero": 552.335,
		"planner": 2,
		"lone_w": 0.3,
		"tgt_sup": 0.5,
		"tgt_thr": 2.0,
		"trade_w": 1.0,
		"order_w": 1.0,
		"feed_w": 1.0,
	},
}

const DEFAULT := {
	"noise": 8.0, # +-noise/2 per candidate: ties break, play varies
	"goal_w": 12.0, # per tile-cost of distance to the nearest goal
	"def_w": 0.8, # per terrain def point
	"caution": 0.6,
	"caution_hero": 1.3, # x death risk (unit value above hp_cap)
	"hp_cap": 150.0,
	"hp_w": 0.6, # hp loss priced as min(value, hp_cap) x hp_w / 100 per hp
	"reach_w": 0.6, # share of the threat-map damage expected to land
	"heal_hp": 70.0,
	"heal_cap": 300.0,
	"heal_w": 0.004, # on a heal tile below heal_hp: (100-hp) x min(value, cap) x w
	"home_hp": 50.0, # below: goals = own heal tiles (walk home over turns); heal_hp bonus then keeps it there
	"home_turns": 4.0, # nearest heal tile further than this many moves: no way home -> fight on
	"aura": 15.0, # per unacted ally within 2 of an aura unit
	"own_castle": 40.0, # penalty: standing on own castle
	"block_castle": 600.0, # penalty: parked on an enemy castle it cannot take
	"guard_castle": 900.0, # standing on an own castle an enemy capturer can reach
	"cap_castle": 700.0,
	"cap_village": 220.0,
	"cap_owned_castle": 400.0,
	"cap_owned_village": 100.0,
	"cap_last": 10000.0,
	"repair": 180.0,
	"raze": 260.0,
	"raise": 250.0,
	"atk_bias": 40.0,
	"atk_pos_w": 0.3, # attacks: + bias, tile score x pos_w
	"kill_w": 0.6,
	"kill_hero": 600.0,
	"maykill_w": 0.3,
	"maykill_hero": 300.0, # x target value / flat for a commander
	"die_w": 1.0,
	"maydie_w": 0.5, # x own value
	"buy_aa": 2.0,
	"buy_takes": 2.0,
	"buy_takes_per": 3.0,
	"buy_raise": 0.5,
	"buy_sea": 1.5,
	"buy_cost_exp": 0.35,
	"save_hero_units": 4.0, # commander dead + this many units: save gold for the rebuy
	# human tactics (docs/ai.md "Kinh nghiệm người chơi"), 0 = off
	"lone_w": 0.0, # x own value x focus-kill chance: ending in enemy reach with < lone_n allies within 2 (no lone crossing)
	"lone_n": 1.0,
	"tgt_sup": 0.0, # target worth x (1 + this) for support units (shaman, wolf, drum)
	"tgt_thr": 0.0, # target worth + this x its own hit (mid atk + rank + aura) x hp / 100 (kill what hurts most)
	"home_val": 0.0, # non-commander walk-home hp + this x (value - 150) / 100, capped at home_cap
	"home_rank": 0.0, # + this per rank (veterans walk home earlier)
	"home_cap": 80.0,
	"bld_w": 0.0, # wounded non-commander on an own heal tile: + this x (value - 150) / 100
	"trade_w": 0.0, # non-kill hit: - this x value lost beyond value dealt (counter x own vs dmg x target) / 100
	"order_w": 0.0, # melee non-kill hit while an unacted ranged ally can hit the target: - this x counter x own value / 100
	"feed_w": 0.0, # non-kill hit whose counter levels the target up: - this x 0.2 x target value
	"escort_w": 0.0, # non-commander ending within 2 of own commander while it has < 3 such allies
	"hero_cgoal": 0.0, # 1 = commander heads for castles only (villages left to the others)
	# internet tactics (docs/ai.md "Mẹo người chơi trên mạng"), 0 = off
	"buy_threat": 0.0, # > 0: foe castles threaten like the unit it can buy next turn (acts at once), at this x 100 hp
	"promo_w": 0.0, # hit that levels our attacker up: + this x the rank's worth (0.2 x base value); also in AIPlan.focus
	"ret_terr": 0.0, # non-commander walk-home hp x lerp(1, clamp((40 - unit def - rank - tile def) / 20, 0.5, 1.5), this)
	"buy_sup": 0.0, # n > 0: army >= n without a drum / wolf -> save up for one (_support_want)
	# flexible army (docs/ai.md "Đội hình linh hoạt = Khó v5"), 0 = off
	"role_w": 0.0, # unit jobs: shaman acts last + waits by fresh graves, drum acts first, boats count waterDef as cover
	"mix_w": 0.0, # situational buys, affordable now only (AIBuy._mix_bonus)
	"mix_save": 0.0, # > 0: material lead >= 1 + this -> save one turn of income for a called-for unit costing >= 500
	"sham_save": 0.0, # 1 = mix_save also saves for a shaman when graves are within its reach from the castle
}
const SUPPORT := ["shaman", "wolf", "drum"]

## own stream (UI effects draw from the global randf); seeded per game by the screen, swapped by the sims
static var _gen := RandomNumberGenerator.new()
static var rng: Callable = _gen.randf

static func seed_game(v: int) -> void:
	_gen.seed = v

## side's knobs: DEFAULT, or DEFAULT merged with s.aiParams[side] (cached in mem for the turn)
static func params(s: Dictionary, side: String, mem := { }) -> Dictionary:
	var all: Dictionary = s.get("aiParams", { })
	var over: Dictionary = all.get(side, { })
	if over.is_empty():
		return DEFAULT
	var key := "P" + side
	if not mem.has(key):
		mem[key] = DEFAULT.merged(over, true)
	return mem[key]

static func weight(type: String) -> float:
	var b: Dictionary = Game.UNITS[type]
	var w: float = b.get("aiWeight", DEFAULT_WEIGHT) # int or float in the table
	return w

static func value(_s: Dictionary, u: Dictionary) -> float:
	var b: Dictionary = Game.UNITS[u.type]
	return b.get("aiValue", b.cost) * (1 + 0.2 * u.rank)

## worth as a target: value, support units up, + what it hits for next turn (tgt_sup / tgt_thr; 0 = value)
static func tvalue(s: Dictionary, d: Dictionary, sup_w: float, thr_w: float) -> float:
	var v := value(s, d)
	if sup_w > 0.0 and SUPPORT.has(d.type):
		v *= 1.0 + sup_w
	if thr_w > 0.0:
		var r := Game.atk_range(s, d)
		var lo: int = r[0]
		var hi: int = r[1]
		var hp: int = d.hp
		v += thr_w * ((lo + hi) * 0.5 + Game.aura_atk(d)) * hp / 100.0
	return v

## AE2 xp = dmg x victim quality on every hit, +1 rank = +2 atk / +2 def: worth 0.2 x base value if this hit levels u up
static func promo_gain(s: Dictionary, u: Dictionary, dmg: int, d: Dictionary) -> float:
	var rank: int = u.rank
	var uxp: int = u.xp
	if rank >= Game.RULES.maxRank or uxp + dmg * Game.quality(s, d) < Game.xp_need(s, u):
		return 0.0
	return value(s, u) / (1.0 + 0.2 * rank) * 0.2

## own units per tile within 2 (lone_w): built once per greedy step
static func support_map(s: Dictionary, side: String) -> Dictionary:
	var out := { }
	for o: Dictionary in s.units:
		if o.side != side:
			continue
		var ox: int = o.x
		var oy: int = o.y
		for dy in range(-2, 3):
			for dx in range(-2 + absi(dy), 3 - absi(dy)):
				var k := Vector2i(ox + dx, oy + dy)
				out[k] = out.get(k, 0) + 1
	return out

## an unacted ranged ally (not u) that can hit d this turn: melee should wait for it (order_w)
static func ranged_ready(s: Dictionary, u: Dictionary, d: Dictionary) -> bool:
	var dx: int = d.x
	var dy: int = d.y
	for o: Dictionary in s.units:
		if o.side != u.side or o.acted or o.id == u.id:
			continue
		var st := Game.stat(s, o)
		var rmax: int = st.rmax
		if rmax < 2:
			continue
		var ox: int = o.x
		var oy: int = o.y
		var dd := Game.dist(ox, oy, dx, dy)
		var mv: int = 0 if st.get("siege", false) else st.mv
		if dd <= mv + rmax:
			return true
	return false

## multi-source terrain distance (ignores units)
static func dist_field(s: Dictionary, move_class: String, sources: Array) -> Dictionary:
	var d := { }
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

## tile -> list of enemy attackers that could hit it next turn; mem (one turn) keeps each enemy's reach + hits across steps.
## buy_hp > 0: + the foe's next-turn buys (buy_threats) as attackers at that hp
static func threat_map(s: Dictionary, side: String, reach_of := { }, mem := { }, buy_hp := 0.0) -> Dictionary:
	var m := { }
	var foes: Array = s.units
	if buy_hp > 0.0:
		foes = foes + buy_threats(s, side, buy_hp)
	for e: Dictionary in foes:
		if e.side == side:
			continue
		var st := Game.stat(s, e)
		var siege: bool = st.get("siege", false)
		var ck: Variant = null
		var tm: Dictionary = { }
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
			hit = { }
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

## foe castles' next-turn buys as virtual attackers (AIBuy.buy_threats)
static func buy_threats(s: Dictionary, side: String, buy_hp: float) -> Array:
	return AIBuy.buy_threats(s, side, buy_hp)

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
		mem.df = { }
	var key := [mc, goals] # array key: hashed natively, no str() of every goal per unit per step
	var df: Dictionary = mem.df
	if not df.has(key):
		df[key] = dist_field(s, mc, goals)
	return df[key]

static func expected_hit(s: Dictionary, u: Dictionary, x: int, y: int, attackers: Variant, reach_w := 0.6) -> float:
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
	return minf(uhp, sum * reach_w) # not every attacker reaches

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
		mem.heal = { }
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
static func endangered_castles(s: Dictionary, side: String, reach_of := { }) -> Dictionary:
	var out := { }
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

static func best_for_unit(s: Dictionary, u: Dictionary, threat: Dictionary, claims: Dictionary, danger: Dictionary, mem := { }) -> Variant:
	var u_side: String = u.side
	var P := params(s, u_side, mem)
	var st := Game.stat(s, u)
	var reach := _reach_cached(s, u, mem)
	var mc: String = st.move if st.move in ["fly", "water"] else "foot"
	var df := { }
	var homeless := false
	var val := value(s, u)
	var is_hero: bool = u.type == "hero"
	var home_hp: float = P.home_hp
	var home_val: float = P.home_val
	var home_rank: float = P.home_rank
	var ret_terr: float = P.ret_terr
	if ret_terr > 0.0 and not is_hero: # thin armour on open ground walks home earlier, tanks / cover later
		var ux0: int = u.x
		var uy0: int = u.y
		var udef: int = st.def + Game.RULES.rankBonus * u.rank + Game.terrain_def(s, u, ux0, uy0)
		home_hp *= lerpf(1.0, clampf((40.0 - udef) / 20.0, 0.5, 1.5), ret_terr)
	if (home_val > 0.0 or home_rank > 0.0) and not is_hero: # dearer / veteran units walk home earlier
		var home_cap: float = P.home_cap
		var cost: float = Game.UNITS[u.type].cost
		var rank: int = u.rank
		home_hp = maxf(home_hp, minf(home_hp + home_val * (cost - 150.0) / 100.0 + home_rank * rank, home_cap))
	if u.hp < home_hp and Objectives.ai_goals(s, u) == null: # wounded: walk home over turns (reach objective first)
		var home := _home_goals(s, u, mem)
		if home.size():
			df = _dist_cached(s, mc, home, mem)
		var mv: int = st.mv
		var ux: int = u.x
		var uy: int = u.y
		var home_turns: float = P.home_turns
		if df.get(Vector2i(ux, uy), INF) > home_turns * mv:
			df = { }
			homeless = true
	if df.is_empty():
		var hero_goals: Array = []
		var hcg: float = P.hero_cgoal
		if hcg > 0.0 and is_hero and Objectives.ai_goals(s, u) == null:
			var owner0: Dictionary = s.owner
			for y: int in s.h:
				for x: int in s.w:
					if owner0.get(Vector2i(x, y)) != u.side and Game.sells(s.tiles[y][x]):
						hero_goals.append([x, y])
		df = _dist_cached(s, mc, hero_goals if hero_goals.size() else goals_for(s, u, claims), mem)
	var caution: float = P.caution_hero if u.type == "hero" else P.caution
	var hp_cap: float = P.hp_cap
	var hp_w: float = P.hp_w
	# hp heals: every hp costs the same (soldier price); the unit's full value only as death risk -> a healthy commander advances
	var hp_val := minf(val, hp_cap) * hp_w / 100.0
	var die_val := maxf(0.0, val - hp_cap) * caution # soldier-priced hp already covers a soldier's death
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
	# hot loop: knobs as typed locals, not a dict lookup per tile
	var noise: float = P.noise
	var goal_w: float = P.goal_w
	var def_w: float = P.def_w
	var reach_w: float = P.reach_w
	var heal_hp: float = P.heal_hp
	var heal_cap: float = P.heal_cap
	var heal_w: float = P.heal_w
	var aura_w: float = P.aura
	var own_castle: float = P.own_castle
	var block_castle: float = P.block_castle
	var guard_castle: float = P.guard_castle
	var cap_castle: float = P.cap_castle
	var cap_village: float = P.cap_village
	var cap_owned_castle: float = P.cap_owned_castle
	var cap_owned_village: float = P.cap_owned_village
	var cap_last: float = P.cap_last
	var repair_w: float = P.repair
	var raze_w: float = P.raze
	var raise_w: float = P.raise
	var atk_bias: float = P.atk_bias
	var atk_pos_w: float = P.atk_pos_w
	var kill_w: float = P.kill_w
	var kill_hero: float = P.kill_hero
	var maykill_w: float = P.maykill_w
	var maykill_hero: float = P.maykill_hero
	var die_w: float = P.die_w
	var maydie_w: float = P.maydie_w
	var lone_w: float = P.lone_w
	var lone_n: float = P.lone_n
	var tgt_sup: float = P.tgt_sup
	var tgt_thr: float = P.tgt_thr
	var bld_w: float = 0.0 if is_hero else P.bld_w * maxf(0.0, val - 150.0) / 100.0
	var trade_w: float = P.trade_w
	var order_w: float = P.order_w
	var feed_w: float = P.feed_w
	var promo_w: float = P.promo_w
	var escort_w: float = 0.0 if is_hero else P.escort_w
	var role_w: float = P.role_w
	var wdef: int = st.get("waterDef", 0)
	var wet_def: int = roundi(role_w * wdef)
	var bite: int = st.get("poison", 0) if role_w > 0.0 else 0
	var fresh: Array = _fresh_graves(s) if role_w > 0.0 and st.get("raise", "") != "" else []
	var sup: Dictionary = mem.get("sup", { }) if lone_w > 0.0 else { }
	var hero_at: Vector2i = mem.get("hero_at", Vector2i(-99, -99))
	var u0x: int = u.x
	var u0y: int = u.y
	var u0 := Vector2i(u0x, u0y)
	var ranged_ok := { } # target id -> ranged_ready (order_w)
	var tv_of := { } # target id -> tvalue
	var best: Array = [null] # [ {score, act} ]
	var consider := func(score: float, act: Dictionary) -> void:
		score += (rng.call() - 0.5) * noise
		if best[0] == null or score > best[0].score:
			best[0] = { "score": score, "act": act }

	for r: Dictionary in reach.values():
		var rx: int = r.x
		var ry: int = r.y
		var key := Vector2i(rx, ry)
		var t: String = s.tiles[ry][rx]
		var gd: float = df.get(key, 30.0) if has_df else 0.0
		var tdef: int = Game.TERRAIN[t].def
		var tt: Dictionary = Game.TERRAIN[t]
		if wet_def > 0 and tt.get("water", false):
			tdef += wet_def # boats: river cover the terrain table does not show
		var pos := -gd * goal_w + tdef * def_w
		var hurt := expected_hit(s, u, rx, ry, threat.get(key), reach_w)
		var uhp: int = u.hp
		pos -= _risk(hurt, uhp, hp_val, die_val)
		var lone_full := 0.0 # alone in reach: every attacker can pick this unit (lone_w)
		if lone_w > 0.0 and not is_hero and threat.has(key):
			var n_sup: int = sup.get(key, 0)
			if Game.dist(u0.x, u0.y, rx, ry) <= 2:
				n_sup -= 1
			if n_sup < lone_n:
				lone_full = expected_hit(s, u, rx, ry, threat.get(key), 1.0)
				pos -= lone_w * val * clampf((lone_full / uhp - 0.6) / 0.4, 0.0, 1.0)
		var own: Variant = owner.get(key)
		var heals := Game.heals_at(s, side, rx, ry)
		if heals and u.hp < heal_hp:
			pos += (100 - u.hp) * minf(val, heal_cap) * heal_w # capped: a 60-hp commander must not glue to a village
		if heals and bld_w > 0.0 and u.hp < 100:
			pos += bld_w
		if escort_w > 0.0 and Game.dist(hero_at.x, hero_at.y, rx, ry) <= 2:
			var near_hero: int = mem.get("hero_near", 0)
			if near_hero - (1 if Game.dist(hero_at.x, hero_at.y, u0.x, u0.y) <= 2 else 0) < 3:
				pos += escort_w
		if st.get("aura", 0): # drum: allies within 2 get +atk after it acts
			for o: Dictionary in s.units:
				var ox: int = o.x
				var oy: int = o.y
				if o.side == u.side and o.id != u.id and not o.acted and Game.dist(ox, oy, rx, ry) <= 2:
					pos += aura_w
		var castle := Game.sells(t)
		if castle and own == u.side:
			pos -= own_castle # AE2 sells under one unit: only a nudge to keep moving (it also guards the castle)
		elif castle and own != null and not st.get(Game.cap_flag(t), false):
			pos -= block_castle # parked on an enemy castle it cannot take: blocks our commander

		if danger.has(key):
			pos += guard_castle # block the capture
		if has_goal_tile:
			pos += goal_tile.call(s, u, rx, ry)
		for g: Vector2i in fresh: # raisable next turn from here (a grave made this turn lasts one more of ours)
			if Game.dist(g.x, g.y, rx, ry) == 1:
				pos += role_w * raise_w * 0.5
				break
		consider.call(pos, { "id": u.id, "to": [rx, ry], "kind": "wait" })

		if Game.can_capture(s, u, rx, ry):
			var c := cap_castle if castle else cap_village
			if own != null:
				c += cap_owned_castle if castle else cap_owned_village
			if castle and own == Game.other(side) and enemy_castles == 1:
				c += cap_last
			consider.call(pos + c + gd * goal_w, { "id": u.id, "to": [rx, ry], "kind": "capture" })
		if Game.can_repair(s, u, rx, ry):
			consider.call(pos + repair_w + gd * goal_w, { "id": u.id, "to": [rx, ry], "kind": "repair" })
		for v: Array in Game.razable_from(s, u, rx, ry):
			# only enemy villages (their income + healing); unowned ones are worth more captured than wrecked
			var vx: int = v[0]
			var vy: int = v[1]
			if owner.get(Vector2i(vx, vy)) != null:
				consider.call(pos + raze_w, { "id": u.id, "to": [rx, ry], "kind": "raze", "target": v })
		for g: Dictionary in Game.raisable_graves(s, u, rx, ry):
			consider.call(pos + raise_w, { "id": u.id, "to": [rx, ry], "kind": "raise", "target": [g.x, g.y] })

		for d: Dictionary in Game.targets_from(s, u, rx, ry):
			var p := Game.preview(s, u, rx, ry, d)
			if p.dmgMax <= 0:
				continue # AE2: armour can soak the whole hit
			if not tv_of.has(d.id):
				tv_of[d.id] = tvalue(s, d, tgt_sup, tgt_thr)
			var dv: float = tv_of[d.id]
			var sc: float = (p.dmg / 100.0) * dv - (p.counter / 100.0) * val
			if p.kill:
				sc += dv * kill_w + (kill_hero if d.type == "hero" else 0.0)
			elif p.mayKill:
				sc += dv * maykill_w + (maykill_hero if d.type == "hero" else 0.0)
			if p.die:
				sc -= val * die_w
			elif p.mayDie:
				sc -= val * maydie_w
			elif promo_w > 0.0:
				var pd: int = p.dmg
				sc += promo_w * promo_gain(s, u, pd, d)
			# after counter, remaining exposure scales with remaining hp
			var counter: int = p.counter
			var left := maxi(0, uhp - counter)
			var exposure := _risk(minf(left, hurt), left, hp_val, die_val) if left > 0 else 0.0
			if not p.kill:
				var pdmg: int = p.dmg
				if trade_w > 0.0:
					sc -= trade_w * maxf(0.0, counter * val - pdmg * dv) / 100.0
				if order_w > 0.0 and counter > 0:
					if not ranged_ok.has(d.id):
						ranged_ok[d.id] = ranged_ready(s, u, d)
					var rdy: bool = ranged_ok[d.id]
					if rdy:
						sc -= order_w * counter * val / 100.0
				if feed_w > 0.0 and counter > 0:
					var dxp: int = d.xp
					if dxp + counter * Game.quality(s, u) >= Game.xp_need(s, d):
						sc -= feed_w * 0.2 * value(s, d)
				if lone_full > 0.0 and left > 0:
					exposure += lone_w * val * clampf((minf(lone_full, left) / left - 0.6) / 0.4, 0.0, 1.0)
				if bite > 0: # wolf first: every follow-up hit on the bitten target lands +bite
					sc += role_w * bite * AIPlan._followers(s, u, d, rx, ry) * dv / 100.0
			var atk_sc := sc + (-gd * goal_w + tdef * def_w) * atk_pos_w - exposure + atk_bias
			consider.call(atk_sc, { "id": u.id, "to": [rx, ry], "kind": "attack", "target": d.id })
	return best[0]

## AIBuy.choose_buy
static func choose_buy(s: Dictionary, side: String, ok: Variant = null, mem := { }, at: Variant = null) -> Variant:
	return AIBuy.choose_buy(s, side, ok, mem, at)

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
	var plan: float = params(s, side, mem).get("planner", 0.0)
	if plan == 2.0:
		return AIPlan.next_step(s, mem)
	return greedy_step(s, mem)

## v1: best single action over every unit (one ply), then buys
static func greedy_step(s: Dictionary, mem: Dictionary) -> Variant:
	var side: String = s.side
	if not mem.has("claims"):
		mem.claims = { }
	var units: Array = s.units
	var mine: Array = units.filter(
		func(u: Dictionary) -> bool:
			return u.side == side and not u.acted,
	)
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
			mem.tm = { }
			mem.rc = { }
		mem.tiles_h = hash(s.tiles) # raze / repair change a tile mid-turn
		mem.erase("heal") # captures change heal tile owners mid-turn
		var reach_of := { }
		var P := params(s, side, mem)
		var buy_hp: float = P.buy_threat
		var threat := threat_map(s, side, reach_of, mem, buy_hp)
		var danger := endangered_castles(s, side, reach_of)
		var lone_w: float = P.lone_w
		if lone_w > 0.0:
			mem.sup = support_map(s, side)
		var escort_w: float = P.escort_w
		if escort_w > 0.0:
			_hero_near(s, side, mem)
		var best: Variant = null
		var claims: Dictionary = mem.claims
		var role_w: float = P.role_w
		var first: Variant = null # role_w: a drum covering >= 2 attackers acts before them
		var late: Variant = null # role_w: a shaman with no raise waits for this turn's graves
		for u: Dictionary in mine:
			var b: Variant = best_for_unit(s, u, threat, claims, danger, mem)
			if b == null:
				continue
			if role_w > 0.0:
				var ust := Game.stat(s, u)
				var bact: Dictionary = b.act
				if ust.get("raise", "") != "" and bact.kind != "raise":
					if late == null or b.score > late.score:
						late = b
					continue
				var bto: Array = bact.to
				if ust.get("aura", 0) > 0 and _aura_cover(s, u, bto) >= 2 and (first == null or b.score > first.score):
					first = b
			if best == null or b.score > best.score:
				best = b
		if first != null:
			best = first
		if best == null:
			best = late
		if best == null:
			return null # nothing legal left (boxed in): end the turn
		var best_act: Dictionary = best.act
		_claim_nearest(s, best_act, claims)
		return { "kind": "act", "act": best.act }
	return buy_step(s, mem)

## graves made this turn (ttl untouched): still raisable on our next turn
static func _fresh_graves(s: Dictionary) -> Array:
	var out := []
	var full: int = Game.RULES.graveRounds
	for g: Dictionary in s.graves:
		var ttl: int = g.ttl
		var gx: int = g.x
		var gy: int = g.y
		if ttl >= full and Game.unit_at(s, gx, gy) == null:
			out.append(Vector2i(gx, gy))
	return out

## unacted allies of u within 2 of tile `to` that can still reach an enemy this turn (drum aura worth)
static func _aura_cover(s: Dictionary, u: Dictionary, to: Array) -> int:
	var tx: int = to[0]
	var ty: int = to[1]
	var n := 0
	for o: Dictionary in s.units:
		if o.side != u.side or o.acted or o.id == u.id:
			continue
		var ox: int = o.x
		var oy: int = o.y
		if Game.dist(ox, oy, tx, ty) > 2:
			continue
		var st := Game.stat(s, o)
		var mv: int = 0 if st.get("siege", false) else st.mv
		var rmax: int = st.rmax
		for e: Dictionary in s.units:
			var ex: int = e.x
			var ey: int = e.y
			if e.side != u.side and Game.dist(ox, oy, ex, ey) <= mv + rmax:
				n += 1
				break
	return n

## escort_w: own commander's tile + allies within 2 of it (mem.hero_at / hero_near)
static func _hero_near(s: Dictionary, side: String, mem: Dictionary) -> void:
	mem.hero_at = Vector2i(-99, -99)
	mem.hero_near = 0
	for h: Dictionary in s.units:
		if h.side != side or h.type != "hero":
			continue
		var hx: int = h.x
		var hy: int = h.y
		mem.hero_at = Vector2i(hx, hy)
		var n := 0
		for o: Dictionary in s.units:
			var ox: int = o.x
			var oy: int = o.y
			if o.side == side and o.id != h.id and Game.dist(ox, oy, hx, hy) <= 2:
				n += 1
		mem.hero_near = n
		return

## v1's buy (AIBuy.buy_step)
static func buy_step(s: Dictionary, mem: Dictionary) -> Variant:
	return AIBuy.buy_step(s, mem)

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
