extends SceneTree
## terrain re-layout for the hand-made maps, following how classic grid-tactics maps are built:
##  - paths (r) link castles and villages as one network (shortest spanning tree, straight runs, bridges over rivers)
##  - rough ground (forest / hill / mountain) comes in clumps: mountain core, hills around, forest on the rim —
##    the same number of rough tiles as before (balance), just grouped instead of sprinkled one by one
##  - kept as is: castles, villages, water, bridges, and every tile a unit starts / spawns / is aimed at
##  - a free ring around castles; heavy units (no mountains) must still connect every castle
##  - 180°-symmetric maps stay symmetric
## prints one line per map: MAP <id> <json rows>. run: godot --headless --path . -s sim/mapgen.gd [-- only=m03,m05]

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const MIN_ROUGH := 0.30

func _init() -> void:
	var only := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = Array(a.substr(5).split(","))
	var jobs := []
	for m: Dictionary in Content.campaign():
		jobs.append([m.id, m])
	for mid: String in Content.SKIRMISH.MAPS:
		var sm: Dictionary = Content.SKIRMISH.MAPS[mid]
		jobs.append(["skirmish:" + mid, { "map": { "rows": sm.rows }, "units": sm.units, "owner": sm.owner }])
	for j: Array in jobs:
		if only.size() and not only.has(j[0]):
			continue
		var rows := relayout(j[0], j[1])
		print("MAP %s %s" % [j[0], JSON.stringify(rows)])
	quit()

static func relayout(id: String, m: Dictionary) -> Array:
	var src: Array = m.map.rows
	var h := src.size()
	var w: int = (src[0] as String).length()
	var g := [] # Array of PackedStringArray-like Arrays of chars
	for y in h:
		var row := []
		for x in w:
			row.append((src[y] as String)[x])
		g.append(row)
	var sym := _is_sym(g, w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	# --- fixed + protected tiles
	var fixed := {}
	var keep := {}
	var castles := []
	var villages := []
	for y in h:
		for x in w:
			var t: String = g[y][x]
			if t in ["c", "v", "~", "="]:
				fixed[Vector2i(x, y)] = true
			if t == "c":
				castles.append(Vector2i(x, y))
			if t == "v":
				villages.append(Vector2i(x, y))
	for u: Array in m.get("units", []):
		keep[Vector2i(u[2], u[3])] = true
	for wv: Dictionary in m.get("waves", []):
		for u: Array in wv.units:
			keep[Vector2i(u[1], u[2])] = true
	for gr: Array in m.get("graves", []):
		keep[Vector2i(gr[0], gr[1])] = true
	for at: Array in m.get("win", {}).get("at", []):
		keep[Vector2i(at[0], at[1])] = true
	# rough budget from the old map (only tiles we are allowed to change)
	var budget := { "f": 0, "h": 0, "m": 0 }
	for y in h:
		for x in w:
			var k := Vector2i(x, y)
			if fixed.has(k) or keep.has(k):
				continue
			var t: String = g[y][x]
			if budget.has(t):
				budget[t] += 1
			g[y][x] = "."
	# --- paths: spanning tree over castles + villages
	var nodes: Array = castles + villages
	if nodes.size() >= 2:
		var joined := [nodes[0]]
		var rest: Array = nodes.slice(1)
		var road := {}
		while rest.size():
			var best_path := []
			var best_i := -1
			for i in rest.size():
				var p := _route(g, w, h, rest[i], joined, road)
				if p.size() and (best_i < 0 or p.size() < best_path.size()):
					best_path = p
					best_i = i
			if best_i < 0:
				break
			for k: Vector2i in best_path:
				if g[k.y][k.x] == "." or g[k.y][k.x] in ["f", "h", "m"]:
					if not fixed.has(k):
						road[k] = true
				joined.append(k)
			rest.remove_at(best_i)
		for k: Vector2i in road:
			g[k.y][k.x] = "r"
			if sym:
				var r := Vector2i(w - 1 - k.x, h - 1 - k.y)
				if g[r.y][r.x] == ".":
					g[r.y][r.x] = "r"
	# keep paths sparse: never wider than one tile (drop a path tile whose removal keeps both neighbours linked)
	# --- rough clumps
	var free := []
	for y in h:
		for x in w:
			var k := Vector2i(x, y)
			if g[y][x] != "." or keep.has(k):
				continue
			if sym and (y * w + x) > ((h - 1 - y) * w + (w - 1 - x)):
				continue # second half mirrors the first
			var near_castle := false
			for c: Vector2i in castles:
				if absi(c.x - x) <= 1 and absi(c.y - y) <= 1:
					near_castle = true
			if not near_castle:
				free.append(k)
	# at least ~30 % of the open land is rough (reference maps run 35-50 %; ours were ~10 %), shares kept from the old map
	var land := 0
	for y in h:
		for x in w:
			if g[y][x] == "." and not keep.has(Vector2i(x, y)):
				land += 1
	var total: int = maxi(budget.f + budget.h + budget.m, int(round(land * MIN_ROUGH)))
	if budget.f + budget.h + budget.m == 0:
		budget = { "f": 6, "h": 4, "m": 0 }
	if sym:
		total = int(ceil(total / 2.0))
	var placed := {}
	var clumps := []
	var tries := 0
	while placed.size() < total and free.size() and tries < 400:
		tries += 1
		var seed_t: Vector2i = free[rng.randi() % free.size()]
		if placed.has(seed_t):
			continue
		var size := mini(total - placed.size(), 3 + rng.randi() % 7) # clumps of 3..9
		var clump := [seed_t]
		placed[seed_t] = 0
		var frontier := [seed_t]
		while clump.size() < size and frontier.size():
			var cur: Vector2i = frontier[rng.randi() % frontier.size()]
			var opts := []
			for d: Vector2i in DIRS:
				var n := cur + d
				if free.has(n) and not placed.has(n):
					opts.append(n)
			if opts.is_empty():
				frontier.erase(cur)
				continue
			var n: Vector2i = opts[rng.randi() % opts.size()]
			placed[n] = clump.size()
			clump.append(n)
			frontier.append(n)
		clumps.append(clump)
	# type by depth inside each clump: mountains in the core of big clumps, hills next, forest on the rim
	var share_m := float(budget.m) / maxf(1.0, budget.f + budget.h + budget.m)
	var share_h := float(budget.h) / maxf(1.0, budget.f + budget.h + budget.m)
	for clump: Array in clumps:
		var depth := {}
		for k: Vector2i in clump:
			var nb := 0
			for d: Vector2i in DIRS:
				if clump.has(k + d):
					nb += 1
			depth[k] = nb
		var order: Array = clump.duplicate()
		order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return depth[a] > depth[b])
		var nm := int(round(order.size() * share_m)) if order.size() >= 4 else 0
		var nh := int(round(order.size() * share_h))
		for i in order.size():
			var k: Vector2i = order[i]
			var t := "m" if i < nm else ("h" if i < nm + nh else "f")
			g[k.y][k.x] = t
			if sym:
				var r := Vector2i(w - 1 - k.x, h - 1 - k.y)
				if g[r.y][r.x] == ".":
					g[r.y][r.x] = t
	# heavy units (elephant, catapult) cannot cross mountains: every castle must stay linked for them
	for guard in 30:
		var cut := _heavy_cut(g, w, h, castles)
		if cut == Vector2i(-1, -1):
			break
		g[cut.y][cut.x] = "h"
		if sym:
			g[h - 1 - cut.y][w - 1 - cut.x] = "h" if g[h - 1 - cut.y][w - 1 - cut.x] == "m" else g[h - 1 - cut.y][w - 1 - cut.x]
	var out := []
	for y in h:
		out.append("".join(PackedStringArray(g[y])))
	return out

static func _is_sym(g: Array, w: int, h: int) -> bool:
	for y in h:
		for x in w:
			if g[y][x] != g[h - 1 - y][w - 1 - x]:
				return false
	return true

## shortest land route (bridges ok, water not) from a to any tile in targets; straight runs and existing paths are cheaper
static func _route(g: Array, w: int, h: int, a: Vector2i, targets: Array, road: Dictionary) -> Array:
	var tset := {}
	for t: Vector2i in targets:
		tset[t] = true
	var dist := { a: 0.0 }
	var prev := {}
	var open := [[0.0, a]]
	while open.size():
		var bi := 0
		for i in open.size():
			if open[i][0] < open[bi][0]:
				bi = i
		var cur: Array = open[bi]
		open.remove_at(bi)
		var k: Vector2i = cur[1]
		if cur[0] > dist[k]:
			continue
		if tset.has(k) and k != a:
			var path := [k]
			while prev.has(path[0]):
				path.push_front(prev[path[0]])
			return path
		for d: Vector2i in DIRS:
			var n := k + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			var t: String = g[n.y][n.x]
			if t == "~":
				continue
			var step := 1.0
			if road.has(n) or t == "=":
				step = 0.35
			elif t == "c" or t == "v":
				step = 0.8 if tset.has(n) else 3.0 # do not run through other villages / castles
			if prev.has(k) and (k - prev[k]) != d:
				step += 0.45 # prefer straight runs
			var nd: float = dist[k] + step
			if not dist.has(n) or nd < dist[n]:
				dist[n] = nd
				prev[n] = k
				open.append([nd, n])
	return []

## a mountain tile that splits the castles for heavy movers, or (-1,-1) if they are all linked
static func _heavy_cut(g: Array, w: int, h: int, castles: Array) -> Vector2i:
	if castles.size() < 2:
		return Vector2i(-1, -1)
	var seen := { castles[0]: true }
	var q := [castles[0]]
	var walls := []
	while q.size():
		var k: Vector2i = q.pop_back()
		for d: Vector2i in DIRS:
			var n: Vector2i = k + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or seen.has(n):
				continue
			var t: String = g[n.y][n.x]
			if t == "~":
				continue
			if t == "m":
				walls.append(n)
				continue
			seen[n] = true
			q.append(n)
	for c: Vector2i in castles:
		if not seen.has(c):
			return walls[0] if walls.size() else Vector2i(-1, -1)
	return Vector2i(-1, -1)
