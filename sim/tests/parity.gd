extends "res://sim/tests/test_base.gd"
## parity tests (run by sim/tests.gd)

# ---------- regression games (sim/golden.txt, current rules) ----------
func parity_tests() -> void:
	run(
		"rules + AI still play the golden games (m01, m07, sk_dong_bang, naive)",
		func() -> void:
			var golden := { }
			for line: String in FileAccess.get_file_as_string("res://sim/golden.txt").split("\n", false):
				var p := line.split(" ", false, 2)
				golden[p[0] + " " + p[1]] = p[2]
			var par := Parity.new()
			par.apply()
			for key: String in ["m01 0", "m07 1", "sk_dong_bang 0", "naive 0"]:
				eq(par.replay(key), golden.get(key, "?"), key)
			par.restore(),
	)
