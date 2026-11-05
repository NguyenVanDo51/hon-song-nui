extends SceneTree
## parity trace: one line per game = winner, reason, turns, steps, FNV-1a hash of every AI step + final units/gold.
## Same seeds and format as the JS-side trace, so `diff` proves the two engines play identical games.
## <godot> --headless --path . -s sim/trace.gd [-- only=m01,m02,skirmish,skirmish-easy,naive]
## Golden output (2026-11-05, from the code last diffed 1:1 against the JS original) lives in sim/legacy/golden.txt: `... > gd.txt; diff <(sort sim/legacy/golden.txt) <(sort gd.txt)`.
## tests.gd replays a few of those games on every run.

func _init() -> void:
	var p: RefCounted = load("res://sim/parity.gd").new()
	p.apply()
	var only := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = Array(a.substr(5).split(","))
	for r: Array in p.runs():
		if only.size() and not only.has(r[0]):
			continue
		for g in r[1]:
			print("%s %d %s" % [r[0], g, p.replay("%s %d" % [r[0], g])])
	quit()
