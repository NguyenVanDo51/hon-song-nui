extends "res://sim/tests/test_base.gd"
## level generator tests (sim/levelgen_lib.gd; run by sim/tests.gd)

const LevelGen := preload("res://sim/levelgen_lib.gd")

const RECIPE := {
	"id": "gtest",
	"title": "Thử",
	"order": 5,
	"tier": "mid",
	"ai": "normal",
	"w": 15,
	"h": 10,
	"castles": { "p": 1, "e": 1 },
	"villages": 6,
	"river": "v",
	"bridges": 2,
	"rough": 0.3,
	"temples": 2,
	"sym": true,
	"win": { "type": "castles" },
	"allowed": { "p": ["soldier", "archer"], "e": ["soldier", "archer"] },
	"gold": { "p": 300, "e": 300 },
	"start": { "p": ["hero", "soldier"], "e": ["hero", "soldier"] },
	"waves": [],
	"night": false,
	"unitCap": 15,
	"stars": { "turns": 12 },
	"newUnits": [],
}

func levelgen_tests() -> void:
	run(
		"levelgen: deterministic per seed, valid, sized, round-trips through source",
		func() -> void:
			var a := LevelGen.build(RECIPE, 7)
			check(not a.has("error"), "built: %s" % a.get("error", ""))
			var rows: Array = a.map.rows
			eq(rows, LevelGen.build(RECIPE, 7).map.rows, "same seed same map")
			var b := LevelGen.build(RECIPE, 8)
			var rows_b: Array = b.map.rows
			check(rows != rows_b, "seed changes map")
			eq(LevelGen.problems(a), [])
			eq(rows.size(), 10)
			eq(str(rows[0]).length(), 15)
			var sc := GDScript.new()
			sc.source_code = LevelGen.to_source(a)
			eq(sc.reload(), OK, "source parses")
			eq(sc.get_script_constant_map().DEF, a, "source round-trip")
			var temples := 0
			for r: String in rows:
				temples += r.count("t")
			eq(temples, 2, "recipe temples kept through relayout")
			var m := LevelGen.metrics(a)
			var bal: float = m.balance
			check(absf(bal - 0.5) <= 0.1, "villages balanced (%.2f)" % bal),
	)
	run(
		"levelgen: most seeds build a valid level",
		func() -> void:
			var bad := 0
			for sd in range(1, 31):
				var d := LevelGen.build(RECIPE, sd)
				if d.has("error") or LevelGen.problems(d).size() > 0:
					bad += 1
			check(bad <= 3, "%d of 30 seeds failed" % bad),
	)
	run(
		"levelgen: problems() catches a bad level",
		func() -> void:
			var m02: Dictionary = Content.level("m02")
			var bad := m02.duplicate(true)
			bad.ai = "easy"
			check(LevelGen.problems(bad).size() > 0, "easy bot rejected")
			eq(LevelGen.problems(m02), [], "a shipped level passes"),
	)
