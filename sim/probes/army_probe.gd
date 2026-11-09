extends SceneTree
## army mix metrics (docs/ai.md "Đội hình linh hoạt = Khó v5"): A vs B on every skirmish map, both seats, tune.gd seeds.
## <godot> --headless --path . -s sim/probes/army_probe.gd -- a=<spec> b=<spec> [games=2] [salt=9200000]
##   spec = sim/tune.gd frozen name + overrides (hard_v3+mix_w:1); sum=<log,log,..> merges raw lines of parallel runs
## per A unit type: buys / game, acts split work (attack, raise, capture, repair, raze, drum aura on an unacted ally) /
## move / idle (wait in place); ghosts raised, boat acts ending on water, A turns at the unit cap, gold banked
const Tune := preload("res://sim/tune.gd")
const TYPES := ["soldier", "archer", "boat", "shaman", "drum", "wolf", "elephant", "catapult", "bird", "ghost", "hero"]

var seed_v := 1.0
var m := { }
var ex_left := 0 # examples=N: print N support jobs (raise, drum aura on >= 3 attackers, bitten target killed)
var bitten := { } # target id -> wolf tile, this A turn

func _init() -> void:
	var args := { }
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	Tune.apply_econ(args)
	var sum_of: String = args.get("sum", "")
	if sum_of != "":
		for path: String in sum_of.split(",", false):
			for line: String in FileAccess.get_file_as_string(path).split("\n"):
				if line.begins_with("  raw "):
					var raw: Dictionary = str_to_var(line.substr(6))
					for k: String in raw:
						var v: float = raw[k]
						add(k, v)
		_report()
		quit()
		return
	var games := int(str(args.get("games", "2")))
	ex_left = int(str(args.get("examples", "0")))
	var salt := int(str(args.get("salt", "9200000")))
	var A := Tune.spec_of(str(args.get("a", "hard_v3")))
	var B := Tune.spec_of(str(args.get("b", "hard_v3")))
	AI.rng = rng
	for map_id: String in Content.SKIRMISH.MAPS:
		for me: String in ["p", "e"]:
			for k in games:
				_play(map_id, me, A, B, salt, k)
	_report()
	print("  raw " + var_to_str(m).replace("\n", ""))
	quit()

func rng() -> float:
	seed_v = fmod(seed_v * 1103515245.0 + 12345.0, 2147483648.0)
	return seed_v / 2147483648.0

func add(k: String, v := 1.0) -> void:
	m[k] = m.get(k, 0.0) + v

func gm(k: String) -> float:
	var v: float = m.get(k, 0.0)
	return v

func _play(map_id: String, me: String, A: Dictionary, B: Dictionary, salt: int, k: int) -> void:
	seed_v = 1000.0 + (salt * 64.0 + k) * 7919.0
	var s := Game.new_game(Content.skirmish_def(map_id, "anhhung", false, Tune.start_gold))
	s.seed = int(seed_v)
	s.rng = int(seed_v)
	var foe := Game.other(me)
	for side: String in ["p", "e"]:
		var sp: Dictionary = A if side == me else B
		if sp.get("_spam", 0.0) > 0.0:
			s.allowed[side] = Tune.spam_types.duplicate()
	s.aiParams = { me: A, foe: B }
	var mem := { }
	var steps := 0
	var bought := false # first buy of this A turn seen
	while s.winner == null and s.turn <= 60 and steps < 30000:
		var stv: Variant = AI.next_step(s, mem)
		if stv == null:
			if s.side == me:
				bitten = { }
				add("turns")
				if Game.cap_count(s, me) >= s.unitCap:
					add("at_cap")
				var g: int = s.gold[me]
				add("gold_end", g)
				if g >= 150 and Game.cap_count(s, me) < s.unitCap:
					add("unspent") # could afford a soldier, did not buy
			bought = false
			Game.end_turn(s)
			mem = { }
			continue
		var st: Dictionary = stv
		if s.side != me:
			if st.kind == "buy":
				add("foe_buy_" + str(st.type))
			AI.apply_step(s, st)
			steps += 1
			continue
		if st.kind == "buy":
			if not bought:
				bought = true
				var g0: int = s.gold[me]
				add("buy0_n")
				add("buy0_gold", g0)
				if g0 >= 400:
					add("buy0_400")
				if g0 >= 600:
					add("buy0_600")
			add("buy_" + str(st.type))
			add("buys")
			AI.apply_step(s, st)
			steps += 1
			continue
		var act: Dictionary = st.act
		var aid: int = act.id
		var u: Dictionary = Game.unit_by_id(s, aid)
		var ty: String = u.type
		var ux: int = u.x
		var uy: int = u.y
		var tx: int = act.to[0]
		var tyy: int = act.to[1]
		var moved := ux != tx or uy != tyy
		var kind: String = act.kind
		var ev := AI.apply_step(s, st)
		steps += 1
		var work := kind != "wait"
		var cover := 0
		for e: Dictionary in ev:
			if e.t == "aura":
				var ids: Array = e.ids
				for oid: int in ids:
					var o: Variant = Game.unit_by_id(s, oid)
					if o != null and not o.acted:
						work = true
						cover += 1
						add("aura_on_unacted")
			if e.t == "raise":
				add("raised")
				_ex("%s t%d (A=%s): shaman #%d -> (%d,%d) raises ghost on grave (%d,%d)" % [map_id, s.turn, me, aid, tx, tyy, e.x, e.y])
			if e.t == "poison":
				add("poison_bites")
				bitten[e.id] = [tx, tyy, aid]
			if e.t == "die" and bitten.has(e.id) and e.side != me:
				var bw: Array = bitten[e.id]
				_ex(
					"%s t%d (A=%s): wolf #%d bit %s #%d from (%d,%d), then %s #%d killed it"
					% [map_id, s.turn, me, bw[2], e.type, e.id, bw[0], bw[1], ty, aid]
				)
		if cover >= 3:
			_ex("%s t%d (A=%s): drum #%d -> (%d,%d) first, aura on %d unacted allies" % [map_id, s.turn, me, aid, tx, tyy, cover])
		var tt: Dictionary = Game.TERRAIN[Game.tile_at(s, tx, tyy)]
		if ty == "boat" and tt.get("water", false):
			add("boat_on_water")
		add("act_" + ty)
		if work:
			add("work_" + ty)
		elif moved:
			add("move_" + ty)
	add("games")
	if s.winner == me:
		add("wins")
	elif s.winner == null:
		add("wins", 0.5)

func _ex(line: String) -> void:
	if ex_left > 0:
		ex_left -= 1
		print("  ex " + line)

func _report() -> void:
	var n := maxf(gm("games"), 1.0)
	print("games %d  A score %.3f" % [gm("games"), gm("wins") / n])
	var line := "buys / game:"
	for t: String in TYPES:
		if gm("buy_" + t) > 0.0:
			line += " %s %.2f" % [t, gm("buy_" + t) / n]
	print(line + "  (total %.2f)" % (gm("buys") / n))
	var fl := "foe buys / game:"
	for t: String in TYPES:
		if gm("foe_buy_" + t) > 0.0:
			fl += " %s %.2f" % [t, gm("foe_buy_" + t) / n]
	print(fl)
	print("type      acts/game  work%  move%  idle%")
	for t: String in TYPES:
		var a := gm("act_" + t)
		if a <= 0.0:
			continue
		var w := gm("work_" + t)
		var mv := gm("move_" + t)
		print("  %-9s %7.2f  %5.1f  %5.1f  %5.1f" % [t, a / n, 100.0 * w / a, 100.0 * mv / a, 100.0 * (a - w - mv) / a])
	var ba := maxf(gm("act_boat"), 1.0)
	print(
		"ghosts raised / game %.2f; poison bites / game %.2f; aura on unacted ally / game %.2f"
		% [gm("raised") / n, gm("poison_bites") / n, gm("aura_on_unacted") / n]
	)
	print(
		"boat acts ending on water %.1f%%; A turns at unit cap %.1f%%; gold banked at A turn end %.0f"
		% [100.0 * gm("boat_on_water") / ba, 100.0 * gm("at_cap") / maxf(gm("turns"), 1.0), gm("gold_end") / maxf(gm("turns"), 1.0)]
	)
	var b0 := maxf(gm("buy0_n"), 1.0)
	print(
		"first buy of a turn: gold %.0f, >= 400 %.1f%%, >= 600 %.1f%%; turn ends with >= 150 unspent below cap %.1f%%"
		% [gm("buy0_gold") / b0, 100.0 * gm("buy0_400") / b0, 100.0 * gm("buy0_600") / b0, 100.0 * gm("unspent") / maxf(gm("turns"), 1.0)]
	)
	var kinds := 0
	for t: String in TYPES:
		if t != "hero" and t != "ghost" and gm("buy_" + t) / n >= 0.25:
			kinds += 1
	print("types bought >= 0.25 / game: %d" % kinds)
