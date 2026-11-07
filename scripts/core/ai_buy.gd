class_name AIBuy
extends RefCounted
## AI buys (split from ai.gd): what to buy and where

## ok: types buy_options allows at the chosen castle (gold, cap, step-off); null = any allowed type within gold.
## at: the castle tile (mix_w: graves a shaman bought there reaches this turn, water shortcut from there)
static func choose_buy(s: Dictionary, side: String, ok: Variant = null, mem := { }, at: Variant = null) -> Variant:
	var P := AI.params(s, side, mem)
	var buy_aa: float = P.buy_aa
	var buy_takes: float = P.buy_takes
	var buy_takes_per: float = P.buy_takes_per
	var buy_raise: float = P.buy_raise
	var buy_sea: float = P.buy_sea
	var buy_cost_exp: float = P.buy_cost_exp
	var counts := { }
	var enemy_fly := false
	for u: Dictionary in s.units:
		if u.side == side:
			counts[u.type] = counts.get(u.type, 0) + 1
		elif Game.UNITS[u.type].move == "fly":
			enemy_fly = true
	var open := { } # cap flag -> buildings needing it that are not ours
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
	var ok_types: Dictionary = { }
	if ok != null:
		ok_types = ok
	var graves: Array = s.graves
	var mix_w: float = P.mix_w
	var mix := _mix_bonus(s, side, counts, at, mem) if mix_w > 0.0 else { }
	var big := _big_want(s, side, mix, P) if mix_w > 0.0 else ""
	if big != "": # ahead: the called-for heavy unit now, or nothing (one turn of saving)
		var bcost: int = Game.UNITS[big].cost
		if bcost > s.gold[side]:
			return null
		if ok == null or ok_types.has(big):
			return big
	var best: Variant = null
	for type: String in s.allowed[side]:
		var st: Dictionary = Game.UNITS[type]
		var cost: int = st.cost
		if cost > s.gold[side] or (ok != null and not ok_types.has(type)):
			continue
		var swims: bool = st.move == "water"
		if swims and water == 0:
			continue # no river: a boat is a soldier at twice the price
		var w := AI.weight(type)
		if st.get("antiAir", 0) and enemy_fly:
			w += buy_aa
		var takes := 0
		for f: String in open:
			if st.get(f, false):
				takes += open[f]
		var n: int = counts.get(type, 0)
		if takes > n * buy_takes_per:
			w += buy_takes
		if st.get("raise", "") and graves.size():
			w += buy_raise
		if swims and water * 8 > s.w * s.h:
			w += buy_sea
		var mb: float = mix.get(type, 0.0)
		w += mix_w * mb
		var sc: float = (w / (1 + n)) * pow(cost / 300.0, buy_cost_exp)
		if best == null or sc > best.sc:
			best = { "type": type, "sc": sc }
	return best.type if best != null else null

## hero_bt: [castle index, virtual unit, cost] for every type the foe of side could buy at each castle on its next turn
## (gold + income, cap, <= 1 unit on the castle). Siege left out: it cannot move and hit the turn it is bought
static func buy_reach(s: Dictionary, side: String) -> Array:
	var foe := Game.other(side)
	var out := []
	if Game.cap_count(s, foe) >= s.unitCap:
		return out
	var g: int = s.gold[foe]
	var budget: int = g + Game.income(s, foe)
	var allowed: Array = s.allowed[foe]
	var types: Array = allowed.duplicate()
	if s.heroDead[foe] and s.heroKey[foe] != null:
		types.append("hero")
	var ci := 0
	for key: Vector2i in Game.castle_tiles(s, foe):
		ci += 1
		var on := 0
		for o: Dictionary in s.units:
			var ox: int = o.x
			var oy: int = o.y
			if ox == key.x and oy == key.y:
				on += 1
		if on > 1:
			continue
		var ti := 0
		for t: String in types:
			ti += 1
			var st: Dictionary = Game.UNITS[t]
			var c: int = Game.hero_cost(s, foe) if t == "hero" else st.cost
			if c > budget or st.get("siege", false):
				continue
			var vu := { "id": -1000 - ci * 32 - ti, "side": foe, "type": t, "x": key.x, "y": key.y, "hp": 100, "xp": 0, "rank": 0, "acted": false }
			out.append([ci, vu, c])
	return out

## v1's buy: the next unit to buy (commander first, else choose_buy per castle) or null (none / saving for the commander)
static func buy_step(s: Dictionary, mem: Dictionary) -> Variant:
	var side: String = s.side
	if Game.cap_count(s, side) >= s.unitCap:
		return null
	# AE2: a castle with one unit on it (ours or theirs) still sells; buy_options folds in gold, cap and step-off room
	for key: Vector2i in Game.castle_tiles(s, side):
		var ok := { }
		for o: Dictionary in Game.buy_options(s, side, key.x, key.y):
			if o.ok:
				ok[o.type] = true
		if ok.is_empty():
			continue
		if ok.has("hero"):
			return { "kind": "buy", "x": key.x, "y": key.y, "type": "hero" }
		var want_hero: bool = s.heroDead[side] and s.heroKey[side] != null
		var save_units: float = AI.params(s, side, mem).save_hero_units
		if want_hero and s.gold[side] < Game.hero_cost(s, side) and Game.unit_count(s, side) >= save_units:
			return null # save up: the commander is the only castle taker
		var type: Variant = choose_buy(s, side, ok, mem, key)
		if type != null:
			return { "kind": "buy", "x": key.x, "y": key.y, "type": type }
	return null

## v5 (mix_w): the job each type is bought for, when the board asks for it -> buy weight bonus per type (x mix_w).
## Only shifts which affordable type is bought (never saves up: v4 buy_sup, removed, lost on tempo)
static func _mix_bonus(s: Dictionary, side: String, counts: Dictionary, at: Variant, mem: Dictionary) -> Dictionary:
	var out := { }
	var foe := Game.other(side)
	var ax := -99
	var ay := -99
	if at != null:
		var k: Vector2i = at
		ax = k.x
		ay = k.y
	# shaman: graves it reaches + raises this very turn (bought units act), or several graves on the board
	var near := 0
	var free := 0
	var sh_mv: int = Game.UNITS.shaman.mv
	for g: Dictionary in s.graves:
		var gx: int = g.x
		var gy: int = g.y
		if Game.unit_at(s, gx, gy) != null:
			continue
		free += 1
		if Game.dist(ax, ay, gx, gy) <= sh_mv + 1:
			near += 1
	var n_sh: int = counts.get("shaman", 0)
	if n_sh < 2:
		out.shaman = 2.0 * mini(near, 2) + (1.5 if n_sh == 0 and (free >= 1 or _in_contact(s, side)) else 0.0)
	# boat: a river route to the foe's castles shorter than walking
	if at != null:
		var goals := []
		for key: Vector2i in Game.castle_tiles(s, foe):
			goals.append([key.x, key.y])
		if goals.size():
			var dw: float = AI._dist_cached(s, "water", goals, mem).get(Vector2i(ax, ay), INF)
			var df: float = AI._dist_cached(s, "foot", goals, mem).get(Vector2i(ax, ay), INF)
			if dw + 2.0 < df:
				out.boat = 1.0
	# drum: a cluster of >= 4 of our fighters in contact (aura + pl_chain); wolf: a tough / veteran foe to soften;
	# elephant: a ranged-heavy foe (armour 30); catapult: foes dug into buildings; bird: foe without anti-air
	var best_cluster := 0
	for u: Dictionary in s.units:
		if u.side != side or u.type == "hero":
			continue
		var ux: int = u.x
		var uy: int = u.y
		var contact := false
		for e: Dictionary in s.units:
			var ex: int = e.x
			var ey: int = e.y
			if e.side == foe and Game.dist(ux, uy, ex, ey) <= 5:
				contact = true
				break
		if not contact:
			continue
		var n := 0
		for o: Dictionary in s.units:
			var ox: int = o.x
			var oy: int = o.y
			if o.side == side and o.type != "hero" and Game.dist(ux, uy, ox, oy) <= 2:
				n += 1
		best_cluster = maxi(best_cluster, n)
	var tough := false
	var ranged := 0
	var dug := 0
	var aa := false
	for e: Dictionary in s.units:
		if e.side != foe:
			continue
		var est := Game.stat(s, e)
		var erank: int = e.rank
		var edef: int = est.def
		if e.type != "hero" and (edef >= 15 or erank >= 2):
			tough = true
		var ermax: int = est.rmax
		if ermax >= 2:
			ranged += 1
		if est.get("antiAir", 0):
			aa = true
		var ex: int = e.x
		var ey: int = e.y
		if Game.cap_flag(Game.tile_at(s, ex, ey)) != "":
			dug += 1
	if best_cluster >= 4 and counts.get("drum", 0) == 0:
		out.drum = 1.5
	if tough and counts.get("wolf", 0) == 0:
		out.wolf = 1.0
	if ranged >= 3:
		out.elephant = 1.0
	if dug >= 2:
		out.catapult = 1.0
	if not aa:
		out.bird = 0.5
	return out

## any of our non-commanders within 5 of a foe (fighting -> graves soon)
static func _in_contact(s: Dictionary, side: String) -> bool:
	for u: Dictionary in s.units:
		if u.side != side or u.type == "hero":
			continue
		var ux: int = u.x
		var uy: int = u.y
		for e: Dictionary in s.units:
			var ex: int = e.x
			var ey: int = e.y
			if e.side != side and Game.dist(ux, uy, ex, ey) <= 5:
				return true
	return false

## mix_save: material (value x hp + gold) >= (1 + mix_save) x the foe's -> the called-for unit costing >= 500 that
## gold + one income reaches (biggest bonus, then cheapest); "" = buy as usual. Never while behind (v4 buy_sup lost tempo)
static func _big_want(s: Dictionary, side: String, mix: Dictionary, P: Dictionary) -> String:
	var ms: float = P.mix_save
	if ms <= 0.0:
		return ""
	var mine := 0.0
	var theirs := 0.0
	for u: Dictionary in s.units:
		var hp: float = u.hp
		var v := AI.value(s, u) * hp / 100.0
		if u.side == side:
			mine += v
		else:
			theirs += v
	var foe := Game.other(side)
	var g_me: int = s.gold[side]
	var g_foe: int = s.gold[foe]
	if mine + g_me < (1.0 + ms) * (theirs + g_foe):
		return ""
	var reach: int = g_me + Game.income(s, side)
	var sham_save: bool = P.sham_save > 0.0
	var allowed: Array = s.allowed[side]
	var best := ""
	var best_b := 0.0
	var best_c := 0
	for t: String in mix:
		var b: float = mix[t]
		var c: int = Game.UNITS[t].cost
		var floor_c := 400 if t == "shaman" and b >= 2.0 and sham_save else 500 # sham_save: graves it reaches
		if b <= 0.0 or c < floor_c or c > reach or not allowed.has(t):
			continue
		if best == "" or b > best_b or (b == best_b and c < best_c):
			best = t
			best_b = b
			best_c = c
	return best
