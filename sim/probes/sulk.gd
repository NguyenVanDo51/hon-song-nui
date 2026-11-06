extends SceneTree
## wounded AI units idling away from heal ("corner sulking").
## -- scene        scripted: wounded e unit far from its village, p passive; e unit position + hp per e turn
## -- scene nohome same, e owns no heal tile (must still rejoin the fight)
## -- scan [games] AI-vs-AI on every mission + skirmish map, each move of a unit < 50 hp off a heal tile:
##                 fight (any non-wait act) / homeward (wait closer to own heal) / idle (neither); longest idle streak
const SimLib := preload("res://sim/sim_lib.gd")
var lib := SimLib.new()

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "scene"
	AI.rng = lib.rng
	if mode == "scene":
		var nohome := args.size() > 1 and args[1] == "nohome"
		for type: String in ["elephant", "wolf", "hero"]:
			scene(type, nohome)
	elif mode == "scan":
		scan(int(args[1]) if args.size() > 1 else 4)
	quit()

## 20x9 plain: e castle + village bottom right, passive p units across the middle, wounded e unit top left (home > 1 move)
func scene(type: String, nohome: bool) -> void:
	lib.seed_v = 1000.0
	var s := Game.new_game(Content.skirmish_def("dong_bang", "anhhung", false))
	s.w = 20
	s.h = 9
	var tiles := []
	for y in 9:
		var row := []
		row.resize(20)
		row.fill(".")
		tiles.append(row)
	s.tiles = tiles
	s.tiles[0][0] = "c"
	s.tiles[8][19] = "c"
	s.tiles[8][16] = "v"
	s.owner = { Vector2i(0, 0): "p", Vector2i(19, 8): "e", Vector2i(16, 8): "e" }
	if nohome:
		s.owner = { Vector2i(0, 0): "p" }
		s.tiles[8][16] = "."
	var units := []
	s.units = units
	s.nextId = 1
	s.gold = { "p": 0, "e": 0 }
	s.unitCap = 1 # no buys: one e unit on the board
	s.hadCastle = { "p": true, "e": not nohome }
	for spec: Array in [["p", "soldier", 8, 3], ["p", "soldier", 9, 6], ["p", "archer", 5, 7], ["p", "hero", 0, 0], ["e", type, 4, 1, 25]]:
		units.append(
			{
				"id": s.nextId,
				"side": spec[0],
				"type": spec[1],
				"x": spec[2],
				"y": spec[3],
				"hp": spec[4] if spec.size() > 4 else 100,
				"xp": 0,
				"rank": 0,
				"acted": false,
			}
		)
		s.nextId += 1
	var u: Dictionary = s.units[4]
	var line := []
	var mem := { }
	s.side = "e"
	for _turn in 12:
		line.append("%d,%d/%d" % [u.x, u.y, u.hp])
		for _i in 20:
			var step: Variant = AI.next_step(s, mem)
			if step == null or s.winner != null:
				break
			var stp: Dictionary = step
			AI.apply_step(s, stp)
		var alive: Array = s.units
		if not alive.has(u):
			line.append("dead")
			break
		mem = { }
		Game.end_turn(s) # -> p: passive
		Game.end_turn(s) # -> e: heals on own heal tile
		if s.winner != null:
			line.append("end:%s" % s.reason)
			break
	print("%s%s  x,y/hp per e turn: %s" % [type.rpad(9), " nohome" if nohome else "", "  ".join(line)])

func scan(games: int) -> void:
	var parity: GDScript = load("res://sim/parity.gd")
	var pobj: Object = parity.new()
	var runs: Array = pobj.call("runs")
	var tot := { "moves": 0, "idle": 0, "nohome": 0, "home": 0, "fight": 0, "worst": 0 }
	var by_type := { }
	for r: Array in runs:
		if r[3]:
			continue
		var name: String = r[0]
		var mk: Callable = r[2]
		var ms := { "moves": 0, "idle": 0, "nohome": 0, "home": 0, "fight": 0, "worst": 0 }
		for g in games:
			lib.seed_v = 1000.0 + g * 7919
			var def: Dictionary = mk.call(g)
			var s := Game.new_game(def)
			s.rng = int(lib.seed_v)
			var streak := { }
			var sref := [s]
			lib.run_ai(
				s,
				false,
				60,
				Callable(),
				func(step: Variant) -> void:
					if step == null or step.kind != "act":
						return
					var st: Dictionary = sref[0]
					var a: Dictionary = step.act
					var aid: int = a.id
					var u: Dictionary = Game.unit_by_id(st, aid)
					var uside: String = u.side
					var ux: int = u.x
					var uy: int = u.y
					var uhp: int = u.hp
					if uhp >= 50 or Game.heals_at(st, uside, ux, uy):
						return
					ms.moves += 1
					var heal := []
					for y: int in st.h:
						for x: int in st.w:
							if Game.heals_at(st, uside, x, y):
								heal.append([x, y])
					var mc: String = Game.stat(st, u).move
					var df := AI.dist_field(st, mc if mc in ["fly", "water"] else "foot", heal)
					var to: Array = a.to
					var tx: int = to[0]
					var ty: int = to[1]
					var closer: bool = df.get(Vector2i(tx, ty), INF) < df.get(Vector2i(ux, uy), INF)
					if a.kind != "wait":
						ms.fight += 1
						streak[u.id] = 0
					elif closer:
						ms.home += 1
						streak[u.id] = 0
					else:
						ms.idle += 1
						if heal.is_empty():
							ms.nohome += 1
						var run_n: int = streak.get(u.id, 0) + 1
						streak[u.id] = run_n
						var worst: int = ms.worst
						ms.worst = maxi(worst, run_n)
						by_type[u.type] = by_type.get(u.type, 0) + 1,
				30000,
			)
		print(
			"%-14s wounded moves %4d  fight %4d  homeward %4d  idle %4d (no heal tile %d)  longest idle streak %2d"
			% [name, ms.moves, ms.fight, ms.home, ms.idle, ms.nohome, ms.worst]
		)
		for k: String in tot:
			var tv: int = tot[k]
			var mv: int = ms[k]
			tot[k] = maxi(tv, mv) if k == "worst" else tv + mv
	print(
		"TOTAL wounded moves %d  fight %d  homeward %d  idle %d (no heal tile %d)  longest idle streak %d  idle by type %s"
		% [tot.moves, tot.fight, tot.home, tot.idle, tot.nohome, tot.worst, by_type]
	)
