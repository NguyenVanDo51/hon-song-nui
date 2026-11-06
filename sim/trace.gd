extends SceneTree
## regression trace: one line per game = winner, reason, turns, steps, FNV-1a hash of every AI step + final units/gold.
## <godot> --headless --path . -s sim/trace.gd [-- only=m01,m02,sk_dong_bang,naive] > out.txt; diff with sim/golden.txt
## Regenerate sim/golden.txt only after an intended rules / AI / map change. tests.gd replays a few games every run.

const Parity := preload("res://sim/parity.gd")

func _init() -> void:
	var p := Parity.new()
	p.apply()
	var only := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = Array(a.substr(5).split(","))
	for r: Array in p.runs():
		if only.size() and not only.has(r[0]):
			continue
		for g: int in r[1]:
			print("%s %d %s" % [r[0], g, p.replay("%s %d" % [r[0], g])])
	quit()
