extends SceneTree
## track parity: prints every channel of an attack at the given ms in the same format as
## `node tools/rig_export.mjs --sample <spec> <attack> <times>`, so the two can be diffed:
##   diff <(node tools/rig_export.mjs --sample hero_p gale 0,160,290) \
##        <(godot --headless --path . -s sim/probes/rig_parity.gd -- hero_p gale 0,160,290 | grep '^[0-9]')
## No args: every exported spec at 25 ms steps vs the JSON keys' own evaluation (just runs it; prints max channel count).

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() >= 3:
		var d := RigData.get_data(a[0])
		var A: Dictionary = d.attacks[a[1]] if d.attacks.has(a[1]) else d.attacks[d.attack_ids[0]]
		for s: String in a[2].split(","):
			var t := float(s)
			var row := []
			for k: String in A.tr:
				var keys: Array = A.tr[k]
				row.append("%s=%s" % [k, _num(RigData.sample(keys, t))])
			print("%s: %s" % [s, " ".join(row)])
	quit()

## JS Math.round(v * 1e4) / 1e4 printed like Number.toString
static func _num(v: float) -> String:
	var r := roundf(v * 10000.0) / 10000.0
	if is_equal_approx(r, roundf(r)):
		return str(int(roundf(r)))
	var s := "%.4f" % r
	while s.ends_with("0"):
		s = s.left(-1)
	return s
