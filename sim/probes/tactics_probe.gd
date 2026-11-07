extends SceneTree
## human-tactics metrics of a hard AI (docs/ai.md "Kinh nghiệm người chơi"): A (AI.PRESETS.hard + over) vs B, every
## skirmish map, both seats. Counted at each of A's turn ends / over the foe's reply.
## <godot> --headless --path . -s sim/probes/tactics_probe.gd -- [games=2] [salt=9200000] [base=hard] [over=k:v+k:v]
##     [opp=v1|v2_0|v3|normal]
## base=v2_0 / v3 -> tune.gd's frozen hard_v2_0 / hard_v3 instead of AI.PRESETS.hard
## examples=N -> print N turns where ref (hard_v2_0, ref=v3: hard_v3) from the same start leaves a lone killable unit and A
##     does not
const Tune := preload("res://sim/tune.gd")
const TacticsLib := preload("res://sim/tactics_lib.gd")
const SUPPORT := ["shaman", "wolf", "drum"]

var seed_v := 1.0
var m := { }
var ex_left := 0 # examples=N: print N turns where ref (same start) leaves a lone killable unit and A does not
var ref: Dictionary = Tune.HARD_V2_0

func _init() -> void:
	var args := { }
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var games := int(str(args.get("games", "2")))
	var salt := int(str(args.get("salt", "9200000")))
	var base: String = args.get("base", "hard")
	var A: Dictionary = AI.PRESETS.hard.duplicate()
	if base == "v2_0":
		A = Tune.HARD_V2_0.duplicate()
	elif base == "v3":
		A = Tune.HARD_V2_0.merged(Tune.V3_TACTICS)
	var a_over: String = args.get("over", "")
	for kv: String in a_over.split("+", false):
		var p := kv.split(":", true, 1)
		A[p[0]] = float(p[1])
	ex_left = int(str(args.get("examples", "0")))
	if args.get("ref", "") == "v3":
		ref = Tune.HARD_V2_0.merged(Tune.V3_TACTICS)
	var opp: String = args.get("opp", "v1")
	var B: Dictionary = Tune.HARD_V1
	if opp == "v2_0":
		B = Tune.HARD_V2_0
	elif opp == "v3":
		B = Tune.HARD_V2_0.merged(Tune.V3_TACTICS)
	elif opp == "normal":
		B = { }
	var sum_of: String = args.get("sum", "")
	if sum_of != "": # merge the raw lines of parallel runs (tools/tactics_par.sh)
		for path: String in sum_of.split(",", false):
			for line: String in FileAccess.get_file_as_string(path).split("\n"):
				if line.begins_with("  raw "):
					var raw: Dictionary = str_to_var(line.substr(6))
					for k: String in raw:
						var v: float = raw[k]
						add(k, v)
		_report(args)
		quit()
		return
	AI.rng = rng
	for map_id: String in Content.SKIRMISH.MAPS:
		for a_side: String in ["p", "e"]:
			for k in games:
				_play(map_id, a_side, A, B, salt, k)
	_report(args)
	quit()

func rng() -> float:
	seed_v = fmod(seed_v * 1103515245.0 + 12345.0, 2147483648.0)
	return seed_v / 2147483648.0

func gm(k: String) -> float:
	var v: float = m.get(k, 0.0)
	return v

func add(k: String, v := 1.0) -> void:
	m[k] = m.get(k, 0.0) + v

func _play(map_id: String, me: String, A: Dictionary, B: Dictionary, salt: int, k: int) -> void:
	seed_v = 1000.0 + (salt * 64.0 + k) * 7919.0
	var s := Game.new_game(Content.skirmish_def(map_id, "anhhung", false))
	s.seed = int(seed_v)
	s.rng = int(seed_v)
	s.aiParams = { me: A, Game.other(me): B }
	var foe := Game.other(me)
	var mem := { }
	var watch := { } # own unit id -> tags at our turn end, judged after the foe's turn
	var turn_atk := { } # target id -> kinds of attackers so far this turn ("m" melee / "r" ranged)
	var start_support := { }
	var steps := 0
	var turn_start: Dictionary = s.duplicate(true)
	var turn_steps := []
	if s.side == me:
		start_support = _support_in_reach(s, me)
	while s.winner == null and s.turn <= 60 and steps < 30000:
		var stv: Variant = AI.next_step(s, mem)
		if stv == null:
			if s.side == me:
				watch = _turn_end(s, me, start_support)
				turn_atk = { }
				if ex_left > 0:
					_example(turn_start, turn_steps, s, me)
			Game.end_turn(s)
			mem = { }
			turn_start = s.duplicate(true)
			turn_steps = []
			if s.side == me and s.winner == null:
				_judge(s, watch)
				start_support = _support_in_reach(s, me)
			continue
		var st: Dictionary = stv
		if s.side == me and st.kind == "buy":
			add("buys")
			if SUPPORT.has(st.type):
				add("buys_support")
		if s.side == me and st.kind == "act":
			var act: Dictionary = st.act
			if act.kind == "attack":
				_attack(s, act, turn_atk)
		var before := { }
		for u: Dictionary in s.units:
			before[u.id] = u
		var ev := AI.apply_step(s, st)
		turn_steps.append(st)
		steps += 1
		if s.side == me:
			for e: Dictionary in ev:
				if e.t == "die" and e.side == foe:
					add("kills")
					if SUPPORT.has(e.type):
						add("kills_support")
					if e.type == "hero":
						add("kills_hero")
				if e.t == "rank" and before.has(e.id) and before[e.id].side == foe:
					add("fed_rankups") # foe leveled off our attack (its counter)
				if e.t == "capture" and Game.sells(e.tile):
					add("castle_caps")
				if e.t == "rank" and before.has(e.id) and before[e.id].side == me:
					add("own_rankups")
		else:
			var fresh := false # foe's attack by a unit bought this turn (AE2: acts at once)
			if st.kind == "act":
				var fa: Dictionary = st.act
				var fid: int = fa.id
				var fu: Dictionary = before.get(fid, { })
				var paid: Dictionary = fu.get("paid", { })
				fresh = fa.kind == "attack" and paid.get("turn", -1) == s.turn
			for e: Dictionary in ev:
				if fresh and e.t == "hit" and not e.get("counter", false):
					var amt: float = e.amount
					add("fresh_hits")
					add("fresh_dmg", amt)
				if fresh and e.t == "die" and e.side == me:
					add("fresh_kills")
	add("games")
	if s.winner == me:
		add("wins")
	elif s.winner == null:
		add("wins", 0.5)

## one of our attacks, before it lands (mid-roll forecast): trade + order bookkeeping
func _attack(s: Dictionary, act: Dictionary, turn_atk: Dictionary) -> void:
	var aid: int = act.id
	var tid: int = act.target
	var u: Dictionary = Game.unit_by_id(s, aid)
	var d: Dictionary = Game.unit_by_id(s, tid)
	var tx: int = act.to[0]
	var ty: int = act.to[1]
	var p := Game.preview(s, u, tx, ty, d)
	add("attacks")
	var ranged: bool = Game.stat(s, u).rmax >= 2
	var kinds: Array = turn_atk.get(tid, [])
	if ranged and kinds.has("m"):
		add("ranged_after_melee") # a ranged hit came after a melee one on the same target: wrong order
	kinds.append("r" if ranged else "m")
	turn_atk[tid] = kinds
	var dmg: int = p.dmg
	var counter: int = p.counter
	if dmg < d.hp:
		add("attacks_nokill")
		if counter * AI.value(s, u) > dmg * AI.value(s, d):
			add("bad_trades") # non-kill hit that loses more value than it deals
		var on := Game.terrain_def(s, u, tx, ty)
		var dx: int = d.x
		var dy: int = d.y
		if counter > 0 and on < Game.terrain_def(s, d, dx, dy):
			add("nokill_worse_ground") # trade from lower ground def than the target's

## foe support units (shaman / wolf / drum) any of our units could hit this turn
func _support_in_reach(s: Dictionary, me: String) -> Dictionary:
	var out := { }
	for d: Dictionary in s.units:
		if d.side == me or not SUPPORT.has(d.type):
			continue
		for u: Dictionary in s.units:
			if u.side != me:
				continue
			var st := Game.stat(s, u)
			var ux: int = u.x
			var uy: int = u.y
			var dx: int = d.x
			var dy: int = d.y
			var mv: int = st.mv
			var rmax: int = st.rmax
			if Game.dist(ux, uy, dx, dy) <= mv + rmax:
				out[d.id] = true
				break
	return out

## A's turn end: exposure / escort / retreat tags; returns id -> tags to judge after the foe's turn
func _turn_end(s: Dictionary, me: String, start_support: Dictionary) -> Dictionary:
	add("turns")
	for id: int in start_support:
		add("support_reachable")
		if Game.unit_by_id(s, id) == null:
			add("support_killed_same_turn")
	var watch := { }
	if not Game.hero_alive(s, Game.other(me)):
		add("foe_no_hero_turns")
	for x: Dictionary in TacticsLib.exposure(s, me):
		var u: Dictionary = x.u
		var ux: int = u.x
		var uy: int = u.y
		var hp: int = u.hp
		var allies: int = x.allies
		var killable: bool = x.killable
		var tags := []
		var hero: bool = u.type == "hero"
		var rank: int = u.rank
		var cost: int = Game.UNITS[u.type].cost
		var valuable := not hero and (rank >= 1 or cost >= 400)
		if hero:
			add("hero_turns")
			add("hero_allies2", allies)
			if allies == 0:
				add("hero_alone")
			if killable:
				add("hero_killable")
			tags.append("hero")
		else:
			add("unit_turns")
			if killable:
				add("killable")
				tags.append("killable")
				if allies == 0:
					add("lone_killable")
					tags.append("lone")
		if valuable:
			tags.append("valuable")
			if hp < 50:
				add("valuable_low")
				if Game.heals_at(s, me, ux, uy):
					add("valuable_low_healing")
		watch[u.id] = tags
	return watch

## same start, hard_v2_0's turn: it leaves a lone killable unit, A's turn does not -> print both
func _example(start: Dictionary, steps: Array, s: Dictionary, me: String) -> void:
	var c: Dictionary = start.duplicate(true)
	c.aiParams[me] = ref
	var mem := { }
	var v2_steps := []
	for i in 80:
		var stv: Variant = AI.next_step(c, mem)
		if stv == null:
			break
		var st: Dictionary = stv
		v2_steps.append(st)
		AI.apply_step(c, st)
	var lone2 := _lone(c, me)
	var lone3 := _lone(s, me)
	if lone2.is_empty() or lone3.size() >= lone2.size():
		return
	ex_left -= 1
	print("\n== %s turn %d side %s: lone killable ref %d -> A %d" % [start.scenario, start.turn, me, lone2.size(), lone3.size()])
	print(" ref lone: %s" % ", ".join(lone2))
	print(" A lone: %s" % ", ".join(lone3))
	print(" ref: %s" % _fmt(start, v2_steps))
	print(" A:    %s" % _fmt(start, steps))

## own non-commander units in enemy reach, killable by focus (mid rolls), no ally within 2
func _lone(s: Dictionary, me: String) -> Array:
	var out := []
	for u: Dictionary in TacticsLib.lone(s, me):
		out.append(TacticsLib.unit_str(u))
	return out

func _fmt(start: Dictionary, steps: Array) -> String:
	return TacticsLib.fmt_steps(start, steps)

## after the foe's turn: which watched units died
func _judge(s: Dictionary, watch: Dictionary) -> void:
	for id: int in watch:
		if Game.unit_by_id(s, id) != null:
			continue
		var tags: Array = watch[id]
		add("deaths")
		for t: String in tags:
			add("died_" + t)

func _report(args: Dictionary) -> void:
	var g: float = gm("games")
	var t: float = maxf(1.0, gm("turns"))
	var ut: float = maxf(1.0, gm("unit_turns"))
	var ht: float = maxf(1.0, gm("hero_turns"))
	print(
		"tactics A=%s over=%s opp=%s games %d salt %s"
		% [args.get("base", "hard"), args.get("over", ""), args.get("opp", "v1"), g, args.get("salt", "(summed)")]
	)
	print("  score %.3f  turns/game %.1f" % [gm("wins") / maxf(1.0, g), t / maxf(1.0, g)])
	var lines := [
		["lone killable / 100 unit-turns", gm("lone_killable") * 100.0 / ut],
		["  of them died next turn %", _pct("died_lone", "lone_killable")],
		["killable (any) / 100 unit-turns", gm("killable") * 100.0 / ut],
		["  of them died next turn %", _pct("died_killable", "killable")],
		["own deaths / game", gm("deaths") / maxf(1.0, g)],
		["valuable deaths / game (rank>=1 or cost>=400)", gm("died_valuable") / maxf(1.0, g)],
		["hero deaths / game", gm("died_hero") / maxf(1.0, g)],
		["valuable <50hp turn-ends / game", gm("valuable_low") / maxf(1.0, g)],
		["  of them on a heal tile %", _pct("valuable_low_healing", "valuable_low")],
		["support kills share of kills %", _pct("kills_support", "kills")],
		["support reachable -> killed same turn %", _pct("support_killed_same_turn", "support_reachable")],
		["kills / game", gm("kills") / maxf(1.0, g)],
		["hero kills / game", gm("kills_hero") / maxf(1.0, g)],
		["castle captures / game", gm("castle_caps") / maxf(1.0, g)],
		["hero allies within 2 (avg)", gm("hero_allies2") / ht],
		["hero alone (no ally within 2) %", gm("hero_alone") * 100.0 / ht],
		["hero killable at turn end %", gm("hero_killable") * 100.0 / ht],
		["bad trades (non-kill, lose value) %", _pct("bad_trades", "attacks_nokill")],
		["non-kill from worse ground %", _pct("nokill_worse_ground", "attacks_nokill")],
		["ranged after melee on same target / 100 attacks", gm("ranged_after_melee") * 100.0 / maxf(1.0, gm("attacks"))],
		["foe rank-ups fed / game", gm("fed_rankups") / maxf(1.0, g)],
		["own rank-ups on our turn / game", gm("own_rankups") / maxf(1.0, g)],
		["hits by fresh foe buys / game", gm("fresh_hits") / maxf(1.0, g)],
		["  dmg by fresh foe buys / game", gm("fresh_dmg") / maxf(1.0, g)],
		["  own deaths to fresh foe buys / game", gm("fresh_kills") / maxf(1.0, g)],
		["foe without commander at our turn end %", gm("foe_no_hero_turns") * 100.0 / t],
		["own buys / game", gm("buys") / maxf(1.0, g)],
		["  support buys / game", gm("buys_support") / maxf(1.0, g)],
	]
	for l: Array in lines:
		print("  %-46s %.2f" % [l[0], l[1]])
	print("  raw %s" % [m])

func _pct(a: String, b: String) -> float:
	return gm(a) * 100.0 / maxf(1.0, gm(b))
