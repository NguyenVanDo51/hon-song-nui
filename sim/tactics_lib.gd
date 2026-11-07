extends RefCounted
## tactic metrics shared by sim/probes/tactics_probe.gd and the match review (sim/review_lib.gd). Static, read-only on s.

## me's units where they stand: [{u, hero, killable, allies, full}]. full = enemy damage if every attacker that can reach
## the tile hits (threat map, mid rolls); killable = full >= hp; allies = own units within 2
static func exposure(s: Dictionary, me: String) -> Array:
	var threat := AI.threat_map(s, me)
	var out := []
	for u: Dictionary in s.units:
		if u.side != me:
			continue
		var ux: int = u.x
		var uy: int = u.y
		var hp: int = u.hp
		var full := AI.expected_hit(s, u, ux, uy, threat.get(Vector2i(ux, uy)), 1.0)
		var allies := 0
		for o: Dictionary in s.units:
			var ox: int = o.x
			var oy: int = o.y
			if o.side == me and o.id != u.id and Game.dist(ox, oy, ux, uy) <= 2:
				allies += 1
		out.append({ "u": u, "hero": u.type == "hero", "killable": full >= hp, "allies": allies, "full": full })
	return out

## own non-commander units in enemy reach, killable by focus (mid rolls), no ally within 2
static func lone(s: Dictionary, me: String) -> Array:
	var out := []
	for x: Dictionary in exposure(s, me):
		if not x.hero and x.killable and x.allies == 0:
			out.append(x.u)
	return out

static func unit_str(u: Dictionary) -> String:
	return "%s#%d (%d,%d) %dhp" % [u.type, u.id, u.x, u.y, u.hp]

## steps as one line, unit types looked up in start
static func fmt_steps(start: Dictionary, steps: Array) -> String:
	var out := []
	for st: Dictionary in steps:
		if st.kind == "buy":
			out.append("buy %s@(%d,%d)" % [st.type, st.x, st.y])
			continue
		if st.kind != "act":
			out.append(str(st.kind))
			continue
		var a: Dictionary = st.act
		var aid: int = a.id
		var u: Variant = Game.unit_by_id(start, aid)
		var who: String = u.type if u != null else "new"
		var tail := ""
		if a.kind == "attack":
			var tid: int = a.target
			var tg: Variant = Game.unit_by_id(start, tid)
			tail = " #%d %s" % [tid, tg.type if tg != null else "?"]
		elif a.get("target") is Array:
			tail = " (%d,%d)" % [a.target[0], a.target[1]]
		out.append("%s#%d->(%d,%d) %s%s" % [who, aid, a.to[0], a.to[1], a.kind, tail])
	return "; ".join(out)
