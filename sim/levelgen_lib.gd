extends RefCounted
## level generator (design: docs/superpowers/specs/2026-11-07-levels-design.md §10). Recipe + seed -> level DEF:
## castles on opposite halves (p west, e east), villages spread by side, river + bridges, temples in the middle,
## start troops by their castle / commander, waves on the east edge, then sim/mapgen.gd relayout (roads + rough clumps).
## Static only: `const LevelGen := preload("res://sim/levelgen_lib.gd")`. Driver: sim/levelgen.gd. Skill: .claude/skills/level-maker.

const MapGen := preload("res://sim/mapgen.gd")
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const ROUGH_MIX := { "f": 0.5, "h": 0.35, "m": 0.15 }
## DEF keys written in this order (matches content/levels/m*.gd)
const KEYS := [
	"id",
	"order",
	"title",
	"tier",
	"ai",
	"hero",
	"enemyHero",
	"newUnits",
	"allowed",
	"gold",
	"win",
	"stars",
	"unitCap",
	"night",
	"map",
	"owner",
	"units",
	"waves",
	"gen",
]

## recipe keys: docs (skill level-maker) + sim/level_recipes.gd. {"error": why} when a piece cannot be placed.
static func build(recipe: Dictionary, seed_n: int) -> Dictionary:
	var rid: String = recipe.id
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([rid, seed_n])
	var w: int = recipe.w
	var h: int = recipe.h
	var sym: bool = recipe.get("sym", false)
	var g := []
	for y in h:
		var row := []
		row.resize(w)
		row.fill(".")
		g.append(row)
	var put := func(k: Vector2i, t: String) -> void:
		g[k.y][k.x] = t
		if sym:
			g[h - 1 - k.y][w - 1 - k.x] = t
	var err := _river(g, w, h, recipe, rng, sym)
	if err != "":
		return { "error": err }
	# castles: p west, e east (mirrored when sym)
	var cs: Dictionary = recipe.get("castles", { "p": 1, "e": 1 })
	var cp: int = cs.get("p", 0)
	var ce: int = cs.get("e", 0)
	if sym and cp != ce:
		return { "error": "sym needs equal castles" }
	var owner := []
	var cas_p := []
	var cas_e := []
	for i in cp:
		var c := _spot(g, w, h, rng, Vector2i(1, 0), Vector2i(maxi(2, floori(w / 5.0)), h - 1), (cas_p + cas_e), 3, i, cp)
		if c == Vector2i(-1, -1):
			return { "error": "no room for a p castle" }
		put.call(c, "c")
		cas_p.append(c)
		owner.append([c.x, c.y, "p"])
		if sym:
			var mc := Vector2i(w - 1 - c.x, h - 1 - c.y)
			cas_e.append(mc)
			owner.append([mc.x, mc.y, "e"])
	if not sym:
		for i in ce:
			var c := _spot(g, w, h, rng, Vector2i(w - 1 - maxi(2, floori(w / 5.0)), 0), Vector2i(w - 2, h - 1), (cas_p + cas_e), 3, i, ce)
			if c == Vector2i(-1, -1):
				return { "error": "no room for an e castle" }
			put.call(c, "c")
			cas_e.append(c)
			owner.append([c.x, c.y, "e"])
	# villages: half by each side, spread out (best of 10 candidates by distance to other buildings)
	var nv: int = recipe.get("villages", 4)
	var vil := []
	var halves := [[Vector2i(0, 0), Vector2i((w >> 1) - 1, h - 1)], [Vector2i(((w + 1) >> 1), 0), Vector2i(w - 1, h - 1)]]
	var per_side := [ceili(nv / 2.0), (nv >> 1)]
	if sym:
		per_side = [(nv >> 1), 0]
	for side_i in 2:
		var cnt: int = per_side[side_i]
		var area: Array = halves[side_i]
		var lo: Vector2i = area[0]
		var hi: Vector2i = area[1]
		for i in cnt:
			var v := _spread(g, w, h, rng, lo, hi, (cas_p + cas_e) + vil, 2)
			if v == Vector2i(-1, -1):
				return { "error": "no room for a village" }
			put.call(v, "v")
			vil.append(v)
			if sym:
				vil.append(Vector2i(w - 1 - v.x, h - 1 - v.y))
	var own_v: int = recipe.get("own_villages", 0)
	for side: String in ["p", "e"]:
		var mine: Array = cas_p if side == "p" else cas_e
		if mine.is_empty():
			continue
		var by_d := vil.duplicate()
		var home: Vector2i = mine[0]
		by_d.sort_custom(
			func(a: Vector2i, b: Vector2i) -> bool:
				return _cheb(a, home) < _cheb(b, home),
		)
		for i in mini(own_v, by_d.size()):
			var v: Vector2i = by_d[i]
			owner.append([v.x, v.y, side])
	# temples: middle band, between the sides
	var nt: int = recipe.get("temples", 0)
	for i in ((nt >> 1) if sym else nt):
		var t := _spread(g, w, h, rng, Vector2i((w >> 1) - 2, 1), Vector2i((w >> 1) + (0 if sym else 2), h - 2), (cas_p + cas_e) + vil, 2)
		if t != Vector2i(-1, -1):
			put.call(t, "t")
	# troops
	var units := []
	var taken := { }
	var start: Dictionary = recipe.get("start", { })
	var sp: Array = start.get("p", ["hero"])
	var se: Array = start.get("e", ["hero"])
	var p_home: Vector2i = cas_p[0] if cas_p.size() else Vector2i(1, (h >> 1))
	if _place_group(g, w, h, rng, "p", sp, p_home, units, taken) != "":
		return { "error": "no room for p troops" }
	if sym and se == sp:
		for u: Array in units.duplicate():
			var ux: int = u[2]
			var uy: int = u[3]
			units.append(["e", u[1], w - 1 - ux, h - 1 - uy])
			taken[Vector2i(w - 1 - ux, h - 1 - uy)] = true
	else:
		var e_home: Vector2i = cas_e[0] if cas_e.size() else Vector2i(w - 2, (h >> 1))
		if _place_group(g, w, h, rng, "e", se, e_home, units, taken) != "":
			return { "error": "no room for e troops" }
	# waves: east edge columns
	var waves := []
	for wv: Dictionary in recipe.get("waves", []):
		var wu := []
		for ty: String in wv.units:
			var k := _free_near(g, w, h, rng, Vector2i(w - 1, rng.randi_range(0, h - 1)), taken, 4, ty)
			if k == Vector2i(-1, -1):
				return { "error": "no room for a wave" }
			taken[k] = true
			wu.append([ty, k.x, k.y])
		waves.append({ "turn": wv.turn, "units": wu })
	# objective
	var win_r: Dictionary = recipe.get("win", { "type": "castles" })
	var win := win_r.duplicate(true)
	if win.type == "reach" and not win.has("at"):
		var goal := _free_near(g, w, h, rng, Vector2i(w - 2, rng.randi_range(1, h - 2)), taken, 3, "hero")
		if goal == Vector2i(-1, -1):
			return { "error": "no reach goal" }
		taken[goal] = true
		win.at = [[goal.x, goal.y]]
	# rough seed (mapgen keeps the counts, regroups them into clumps), then relayout
	var rough: float = recipe.get("rough", 0.3)
	_seed_rough(g, w, h, rng, rough, taken, sym)
	var rows := []
	for y in h:
		var row: Array = g[y]
		rows.append("".join(PackedStringArray(row)))
	var pre := { "map": { "rows": rows }, "units": units, "waves": waves, "win": win }
	rows = MapGen.relayout("%s_s%d" % [rid, seed_n], pre)
	var e_hero: Variant = null
	if se.has("hero"):
		e_hero = "tuonggiac"
	var def := {
		"id": rid,
		"order": recipe.get("order", 999),
		"title": recipe.get("title", rid),
		"tier": recipe.get("tier", "mid"),
		"ai": recipe.get("ai", "normal"),
		"hero": "anhhung",
		"enemyHero": e_hero,
		"newUnits": recipe.get("newUnits", []),
		"allowed": recipe.get("allowed", { "p": ["soldier"], "e": ["soldier"] }),
		"gold": recipe.get("gold", { "p": 300, "e": 300 }),
		"win": win,
		"stars": recipe.get("stars", { "turns": 12 }),
		"unitCap": recipe.get("unitCap", 15),
		"night": recipe.get("night", false),
		"map": { "rows": rows },
		"owner": owner,
		"units": units,
		"waves": waves,
		"gen": { "recipe": rid, "seed": seed_n },
	}
	return def.duplicate(true)

## [] when the level is playable content (same bar as the hand-made ones + the generator's own checks)
static func problems(def: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var rows: Array = def.map.rows
	var row0: String = rows[0]
	for r: String in rows:
		if r.length() != row0.length():
			out.append("rows differ in length")
		for i in r.length():
			if not Rules.TERRAIN.has(r[i]):
				out.append("unknown tile " + r[i])
	if not out.is_empty():
		return out
	if not Content.TIERS.has(def.get("tier")):
		out.append("tier %s" % def.get("tier"))
	if not Content.LEVEL_AI.has(def.get("ai", "normal")):
		out.append("ai %s" % def.get("ai"))
	var sc := Stars.check_def(def)
	if sc != "":
		out.append(sc)
	var s := Game.new_game(def)
	var oc := Objectives.check(s)
	if oc != "":
		out.append(oc)
	var seen := { }
	for u: Dictionary in s.units:
		var at := _upos(u)
		var mc: String = Game.stat(s, u).move
		if Game.move_cost(mc, Game.tile_at(s, at.x, at.y)) == INF:
			out.append("%s %s on impassable %s" % [u.side, u.type, at])
		if seen.has(at):
			out.append("two units on %s" % at)
		seen[at] = true
	for wv: Dictionary in def.get("waves", []):
		for wu: Array in wv.units:
			var ty: String = wu[0]
			var mc: String = Rules.UNITS[ty].move
			var wx: int = wu[1]
			var wy: int = wu[2]
			if Game.move_cost(mc, Game.tile_at(s, wx, wy)) == INF:
				out.append("wave %s on impassable" % ty)
	# our commander walks (over turns) to every castle, the enemy commander and the reach goals
	var hero := _hero(s, "p")
	if hero.is_empty():
		out.append("no p commander")
		return out
	var reach := _flood(s, _upos(hero), "foot")
	var targets := []
	var sw: int = s.w
	var sh: int = s.h
	for y in sh:
		for x in sw:
			if Game.sells(Game.tile_at(s, x, y)):
				targets.append(Vector2i(x, y))
	var eh := _hero(s, "e")
	if not eh.is_empty():
		targets.append(_upos(eh))
	var swin: Dictionary = s.win
	for at: Array in swin.get("at", []):
		var ax: int = at[0]
		var ay: int = at[1]
		targets.append(Vector2i(ax, ay))
	for t: Vector2i in targets:
		if not reach.has(t):
			out.append("commander cannot reach %s" % t)
	return out

## structure numbers for picking among candidates (no sims): village split, bare castles, distance between the sides
static func metrics(def: Dictionary) -> Dictionary:
	var s := Game.new_game(def)
	var hp := []
	var he := []
	for u: Dictionary in s.units:
		if u.type == "hero":
			(hp if u.side == "p" else he).append(_upos(u))
	var own: Dictionary = s.owner
	for k: Vector2i in own:
		if Game.sells(Game.tile_at(s, k.x, k.y)):
			(hp if own[k] == "p" else he).append(k)
	var np := 0.0
	var ne := 0.0
	var open_c := 0
	var sw: int = s.w
	var sh: int = s.h
	for y in sh:
		for x in sw:
			var k := Vector2i(x, y)
			var t: Variant = Game.tile_at(s, x, y)
			if t == "v":
				var dp := _nearest(k, hp)
				var de := _nearest(k, he)
				if dp < de:
					np += 1.0
				elif de < dp:
					ne += 1.0
				else:
					np += 0.5
					ne += 0.5
			if Game.sells(t) and _bare(s, k):
				open_c += 1
	var tot := np + ne
	var bal := 0.5 if tot == 0.0 else np / tot
	var p0: Vector2i = hp[0] if hp.size() else Vector2i.ZERO
	var e0: Vector2i = he[0] if he.size() else Vector2i(sw - 1, sh - 1)
	var steps := _flood(s, p0, "foot")
	var path_len: int = steps.get(e0, -1)
	return { "villages_near": { "p": np, "e": ne }, "balance": bal, "open_castles": open_c, "path_len": path_len }

## GDScript source of a level file (content/levels/<id>.gd); gdscript-formatter lays it out on install
static func to_source(def: Dictionary) -> String:
	var gen: Dictionary = def.get("gen", { })
	var lines := [
		"extends RefCounted",
		"## level %s: drawn by sim/levelgen.gd (recipe %s, seed %s). Format: docs/content.md" % [def.id, gen.get("recipe", "?"), gen.get("seed", "?")],
		"",
		"const DEF := {",
	]
	for k: String in KEYS:
		if not def.has(k):
			continue
		if k == "map":
			lines.append('\t"map": {')
			lines.append('\t\t"rows": [')
			for r: String in def.map.rows:
				lines.append('\t\t\t"%s",' % r)
			lines.append("\t\t],")
			lines.append("\t},")
		else:
			lines.append('\t"%s": %s,' % [k, _lit(def[k])])
	lines.append("}")
	return "\n".join(PackedStringArray(lines)) + "\n"

# ---------- helpers ----------
static func _lit(v: Variant) -> String:
	if v == null:
		return "null"
	if v is bool:
		return "true" if v else "false"
	if v is int:
		return str(v)
	if v is float:
		return var_to_str(v)
	if v is String:
		var sv: String = v
		return '"%s"' % sv.c_escape()
	if v is Array:
		var a: Array = v
		var parts := PackedStringArray()
		for x: Variant in a:
			parts.append(_lit(x))
		return "[" + ", ".join(parts) + "]"
	if v is Dictionary:
		var d: Dictionary = v
		if d.is_empty():
			return "{ }"
		var parts := PackedStringArray()
		for k: Variant in d:
			parts.append("%s: %s" % [_lit(k), _lit(d[k])])
		return "{ " + ", ".join(parts) + " }"
	return str(v)

static func _river(g: Array, w: int, h: int, recipe: Dictionary, rng: RandomNumberGenerator, sym: bool) -> String:
	var kind: String = recipe.get("river", "none")
	if kind == "none":
		return ""
	var vert := kind == "v"
	var n := h if vert else w # cells along the river
	var span := w if vert else h # the other axis
	var mid := ((span - 1) >> 1)
	var off := []
	off.resize(n)
	var o := 0
	var half := n if not sym else ((n + 1) >> 1)
	for i in half:
		if i > 0:
			var step: int = [-1, 0, 0, 0, 1][rng.randi_range(0, 4)] # mostly straight: bridges need straight runs
			o = clampi(o + step, -2, 2)
		off[i] = o
	if sym:
		for i in range(half, n):
			var oi: int = off[n - 1 - i]
			off[i] = (span - 1 - 2 * mid) - oi # mirrored: cell (mid + o) -> (span - 1 - mid - o)
	var cells := []
	var prev := -1
	for i in n:
		var oi: int = off[i]
		var c := mid + oi
		var from := c if prev < 0 else mini(prev, c)
		var to := c if prev < 0 else maxi(prev, c)
		for j in range(from, to + 1):
			cells.append(Vector2i(j, i) if vert else Vector2i(i, j))
		prev = c
	for k: Vector2i in cells:
		g[k.y][k.x] = "~"
	# bridges: river cells with land on both sides across the flow, spread along it
	var nb: int = recipe.get("bridges", 2)
	var cand := []
	for k: Vector2i in cells:
		var a := k + (Vector2i(-1, 0) if vert else Vector2i(0, -1))
		var b := k + (Vector2i(1, 0) if vert else Vector2i(0, 1))
		if _in(a, w, h) and _in(b, w, h) and g[a.y][a.x] != "~" and g[b.y][b.x] != "~":
			var along := k.y if vert else k.x
			if along > 0 and along < n - 1:
				cand.append(k)
	# sym: pick in the first half only, the mirror adds the other; picks keep 2+ cells apart along the river
	var want := ceili(nb / 2.0) if sym else nb
	var span_n := ((n + 1) >> 1) if sym else n
	var picked := []
	for i in want:
		var target := roundi((i + 0.5) * span_n / float(want))
		var best := Vector2i(-1, -1)
		var best_d := 999
		for k: Vector2i in cand:
			var along := k.y if vert else k.x
			if sym and (along >= span_n or (n - 1 - along) - along < 3): # its mirror lands 3+ cells away
				continue
			var near := false
			for q: Vector2i in picked:
				if absi((q.y if vert else q.x) - along) < 3:
					near = true
			if not near and absi(along - target) < best_d:
				best = k
				best_d = absi(along - target)
		if best == Vector2i(-1, -1):
			return "river has no room for %d bridges" % nb
		picked.append(best)
		g[best.y][best.x] = "="
		if sym:
			var m := Vector2i(w - 1 - best.x, h - 1 - best.y)
			if g[m.y][m.x] == "~":
				g[m.y][m.x] = "="
	return ""

## a building tile in [lo, hi] at least `gap` (Chebyshev) from `others`, stacked i of n top to bottom
static func _spot(
	g: Array,
	w: int,
	h: int,
	rng: RandomNumberGenerator,
	lo: Vector2i,
	hi: Vector2i,
	others: Array,
	gap: int,
	i: int,
	n: int,
) -> Vector2i:
	var band := (hi.y - lo.y + 1) / float(maxi(1, n))
	for tries in 60:
		var y := clampi(lo.y + int(band * i + rng.randf_range(0.2, 0.8) * band), 1, h - 2)
		var x := rng.randi_range(lo.x, hi.x)
		var k := Vector2i(x, y)
		if _ok_building(g, w, h, k, others, gap):
			return k
	return Vector2i(-1, -1)

static func _spread(g: Array, w: int, h: int, rng: RandomNumberGenerator, lo: Vector2i, hi: Vector2i, others: Array, gap: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := -1
	for tries in 40:
		var k := Vector2i(rng.randi_range(lo.x, hi.x), rng.randi_range(lo.y, hi.y))
		if not _ok_building(g, w, h, k, others, gap):
			continue
		var d := _nearest(k, others) if others.size() else 99
		if d > best_d:
			best = k
			best_d = d
	return best

static func _ok_building(g: Array, w: int, h: int, k: Vector2i, others: Array, gap: int) -> bool:
	if not _in(k, w, h) or g[k.y][k.x] != ".":
		return false
	var m := Vector2i(w - 1 - k.x, h - 1 - k.y)
	if g[m.y][m.x] != "." and m != k: # its mirror (sym maps) must be free too; harmless otherwise
		return false
	for o: Vector2i in others:
		if _cheb(o, k) < gap:
			return false
	return true

## hero next to home, the rest within 3 tiles; boats on water, others on land
static func _place_group(
	g: Array,
	w: int,
	h: int,
	rng: RandomNumberGenerator,
	side: String,
	types: Array,
	home: Vector2i,
	units: Array,
	taken: Dictionary,
) -> String:
	for ty: String in types:
		var k := _free_near(g, w, h, rng, home, taken, 3, ty)
		if k == Vector2i(-1, -1):
			return "no room"
		taken[k] = true
		units.append([side, ty, k.x, k.y])
	return ""

static func _free_near(g: Array, w: int, h: int, rng: RandomNumberGenerator, c: Vector2i, taken: Dictionary, r: int, ty: String) -> Vector2i:
	var opts := []
	var rr := r * 2 if ty == "boat" else r # boats need the river, which may run further off
	for dy in range(-rr, rr + 1):
		for dx in range(-rr, rr + 1):
			var k := c + Vector2i(dx, dy)
			if not _in(k, w, h) or taken.has(k):
				continue
			var t: String = g[k.y][k.x]
			var water := t == "~"
			if ty == "boat":
				if not water:
					continue
			elif t != "." and t != "c":
				continue
			if k == c and t == "c" and ty != "hero":
				continue # castle tile: commander only (buying needs it free otherwise)
			opts.append(k)
	if opts.is_empty():
		return Vector2i(-1, -1)
	opts.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return _cheb(a, c) < _cheb(b, c),
	)
	var n := mini(3, opts.size())
	return opts[rng.randi_range(0, n - 1)]

static func _seed_rough(g: Array, w: int, h: int, rng: RandomNumberGenerator, rough: float, keep: Dictionary, sym: bool) -> void:
	var free := []
	for y in h:
		for x in w:
			var k := Vector2i(x, y)
			if g[y][x] == "." and not keep.has(k) and (not sym or (y * w + x) <= ((h - 1 - y) * w + (w - 1 - x))):
				free.append(k)
	var n := roundi(free.size() * rough)
	for i in n:
		if free.is_empty():
			break
		var k: Vector2i = free.pop_at(rng.randi_range(0, free.size() - 1))
		var r := rng.randf()
		var t := "f" if r < ROUGH_MIX.f else ("h" if r < ROUGH_MIX.f + ROUGH_MIX.h else "m")
		g[k.y][k.x] = t
		if sym:
			g[h - 1 - k.y][w - 1 - k.x] = t

static func _hero(s: Dictionary, side: String) -> Dictionary:
	for u: Dictionary in s.units:
		if u.side == side and u.type == "hero":
			return u
	return { }

## step counts from `from` over passable tiles (units ignored)
static func _flood(s: Dictionary, from: Vector2i, move_class: String) -> Dictionary:
	var dist := { from: 0 }
	var q := [from]
	var qi := 0
	while qi < q.size():
		var c: Vector2i = q[qi]
		qi += 1
		for d: Vector2i in DIRS:
			var n := c + d
			if dist.has(n):
				continue
			var t: Variant = Game.tile_at(s, n.x, n.y)
			if t == null or Game.move_cost(move_class, t) == INF:
				continue
			var dc: int = dist[c]
			dist[n] = dc + 1
			q.append(n)
	return dist

## no rough / water / building within 2 tiles: a castle out in the open
static func _bare(s: Dictionary, k: Vector2i) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var t: Variant = Game.tile_at(s, k.x + dx, k.y + dy)
			if t in ["f", "h", "m", "~"]:
				return false
	return true

static func _nearest(k: Vector2i, pts: Array) -> int:
	var best := 999
	for p: Vector2i in pts:
		best = mini(best, _cheb(k, p))
	return best

static func _upos(u: Dictionary) -> Vector2i:
	var x: int = u.x
	var y: int = u.y
	return Vector2i(x, y)

static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

static func _in(k: Vector2i, w: int, h: int) -> bool:
	return k.x >= 0 and k.y >= 0 and k.x < w and k.y < h
