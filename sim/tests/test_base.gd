extends RefCounted
## shared state + helpers of the test suites in sim/tests/ (runner: sim/tests.gd). Split from sim/tests.gd.

const Parity := preload("res://sim/parity.gd")

var failed := 0
var passed := 0
var _cur := ""
var _ok := true

func check(cond: bool, msg: String) -> void:
	if not cond:
		_ok = false
		printerr("  FAIL %s: %s" % [_cur, msg])

func eq(a: Variant, b: Variant, msg := "") -> void:
	var same: bool = a == b
	check(same, "%s expected %s got %s" % [msg, b, a])

## s.units / s.owner / s.graves read fresh (Game swaps s.units when a unit dies)
static func units_of(s: Dictionary) -> Array:
	return s.units

static func unit(s: Dictionary, i: int) -> Dictionary:
	return s.units[i]

static func owner_of(s: Dictionary) -> Dictionary:
	return s.owner

static func graves_of(s: Dictionary) -> Array:
	return s.graves

static func acted(u: Dictionary) -> bool:
	return u.acted

static func id_of(u: Dictionary) -> int:
	return u.id

## unit tile
static func pos(u: Dictionary) -> Vector2i:
	var x: int = u.x
	var y: int = u.y
	return Vector2i(x, y)

## tile from a[i], a[i + 1]
static func xy(a: Array, i := 0) -> Vector2i:
	var x: int = a[i]
	var y: int = a[i + 1]
	return Vector2i(x, y)

static func mission(id: String) -> Dictionary:
	return Content.mission(id)

func run(name: String, fn: Callable) -> void:
	_cur = name
	_ok = true
	Game.fixed_roll = -1.0
	fn.call()
	if _ok:
		passed += 1
	else:
		failed += 1
		print("FAIL " + name)

# ---------- rules ----------
func blank(units: Array) -> Dictionary:
	var s := Game.new_game(Content.skirmish_def("dong_bang", "anhhung", false))
	var tiles := []
	s.tiles = tiles
	for y in 6:
		tiles.append([".", ".", ".", ".", ".", "."])
	s.w = 6
	s.h = 6
	s.owner = { Vector2i(0, 0): "p", Vector2i(5, 5): "e" }
	s.tiles[0][0] = "c"
	s.tiles[5][5] = "c"
	var list := []
	s.units = list
	s.nextId = 1
	s.hadCastle = { "p": true, "e": true }
	for spec: Array in units:
		list.append(
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
	return s

# ---------- 1 vs 1 (docs/1v1.md) ----------
func duel(map_id: String, ctrl_e: String) -> Dictionary:
	var hp: String = Content.heroes_of("p")[0]
	var he: String = Content.heroes_of("e")[0]
	return Content.duel_def(map_id, hp, he, ctrl_e)

static func duel_ctx(map_id: String, ctrl_e: String) -> Dictionary:
	return {
		"kind": "duel",
		"map": map_id,
		"hero": Content.heroes_of("p")[0],
		"heroE": Content.heroes_of("e")[0],
		"ctrlE": ctrl_e,
		"gold": 300,
		"cap": 15,
	}

# ---------- hard v2 planner (scripts/core/ai_plan.gd) ----------
## duel with the hard AI on both sides, played by AI.next_step for `rounds` rounds; returns the step list
func planner_game(map_id: String, rounds: int, s: Dictionary) -> Array:
	var steps := []
	while s.winner == null and s.turn <= rounds:
		var mem := { }
		for i in 80:
			var before := var_to_str(s)
			var stv: Variant = AI.next_step(s, mem)
			check(var_to_str(s) == before, "%s: next_step leaves the state alone" % map_id)
			if stv == null:
				break
			var st: Dictionary = stv
			check(AIPlan.legal(s, st), "%s: legal step %s" % [map_id, st])
			var n_acted := units_of(s).filter(
				func(u: Dictionary) -> bool:
					return u.acted,
			).size()
			var gold: Dictionary = s.gold
			var sig := [units_of(s).size(), n_acted, gold.duplicate()]
			AI.apply_step(s, st)
			var n_after := units_of(s).filter(
				func(u: Dictionary) -> bool:
					return u.acted,
			).size()
			check([units_of(s).size(), n_after, s.gold] != sig or s.winner != null, "%s: step did something %s" % [map_id, st])
			steps.append(st)
			if s.winner != null:
				break
		if s.winner == null:
			Game.end_turn(s)
			steps.append({ "kind": "end" })
	return steps

func hard_duel(map_id: String) -> Dictionary:
	var s := Game.new_game(duel(map_id, "ai:hard"))
	s.aiParams.p = AI.PRESETS.hard.duplicate()
	s.seed = 4242
	s.rng = 4242
	return s
