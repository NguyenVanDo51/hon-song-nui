extends SceneTree
## level generator driver (lib: sim/levelgen_lib.gd, recipes: sim/level_recipes.gd, skill: .claude/skills/level-maker):
##   godot --headless --path . -s sim/levelgen.gd -- recipe=<id|all> seeds=12 out=<dir>
##     -> builds seeds 1..N, drops invalid ones, writes <out>/<id>_s<seed>.gd, prints one line per candidate, best first
##   godot --headless --path . -s sim/levelgen.gd -- install=<out>/<id>_s<seed>.gd
##     -> copies that candidate to content/levels/<id>.gd (then: gdscript-formatter + --import + tests)

const LevelGen := preload("res://sim/levelgen_lib.gd")
const Recipes := preload("res://sim/level_recipes.gd")

func _init() -> void:
	var args := { }
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("install"):
		quit(_install(str(args.install)))
		return
	var want := str(args.get("recipe", "all"))
	var seeds := int(str(args.get("seeds", "12")))
	var out := str(args.get("out", "user://levelgen"))
	DirAccess.make_dir_recursive_absolute(out)
	var found := false
	for r: Dictionary in Recipes.RECIPES:
		if want != "all" and r.id != want:
			continue
		found = true
		_candidates(r, seeds, out)
	if not found:
		printerr("levelgen: no recipe " + want)
	quit(0 if found else 1)

## lower = better: villages even, no bare castle, sides a sensible walk apart
static func score(m: Dictionary, w: int) -> float:
	var bal: float = m.balance
	var open_c: int = m.open_castles
	var pl: int = m.path_len
	var s := absf(bal - 0.5) * 10.0 + open_c * 2.0
	if pl < 0:
		s += 50.0
	elif pl < w * 0.6 or pl > w * 1.8:
		s += 3.0
	return s

func _candidates(r: Dictionary, seeds: int, out: String) -> void:
	var rows := []
	var w: int = r.w
	for sd in range(1, seeds + 1):
		var d := LevelGen.build(r, sd)
		if d.has("error"):
			print("%s s%d  error: %s" % [r.id, sd, d.error])
			continue
		var pr := LevelGen.problems(d)
		if pr.size():
			print("%s s%d  invalid: %s" % [r.id, sd, ", ".join(pr)])
			continue
		var m := LevelGen.metrics(d)
		var path := "%s/%s_s%d.gd" % [out, r.id, sd]
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			printerr("levelgen: cannot write " + path)
			continue
		f.store_string(LevelGen.to_source(d))
		f.close()
		rows.append(
			[
				score(m, w),
				"%s s%d  score %.1f  balance %.2f  open_castles %d  path_len %d  -> %s"
				% [r.id, sd, score(m, w), m.balance, m.open_castles, m.path_len, path],
			]
		)
	rows.sort_custom(
		func(a: Array, b: Array) -> bool:
			var sa: float = a[0]
			var sb: float = b[0]
			return sa < sb,
	)
	for row: Array in rows:
		print(row[1])

func _install(src: String) -> int:
	var text := FileAccess.get_file_as_string(src)
	var sc := GDScript.new()
	sc.source_code = text
	if text == "" or sc.reload() != OK:
		printerr("levelgen: cannot read " + src)
		return 1
	var def: Dictionary = sc.get_script_constant_map().DEF
	var dst := "res://content/levels/%s.gd" % def.id
	var f := FileAccess.open(dst, FileAccess.WRITE)
	if f == null:
		printerr("levelgen: cannot write " + dst)
		return 1
	f.store_string(text)
	f.close()
	print("installed %s" % dst)
	return 0
