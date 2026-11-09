class_name Buffs
extends RefCounted
## bonuses a unit gets from what is around it (split from game.gd for the file-length cap)

## healAura (drum): biggest heal an ally healer within 2 gives u at its side's turn start (not itself), 0 = none
static func heal_aura(s: Dictionary, u: Dictionary) -> int:
	var best := 0
	var ux: int = u.x
	var uy: int = u.y
	for o: Dictionary in s.units:
		if o.side != u.side or o.id == u.id:
			continue
		var n: int = Game.stat(s, o).get("healAura", 0)
		var ox: int = o.x
		var oy: int = o.y
		if n > best and Game.dist(ox, oy, ux, uy) <= 2:
			best = n
	return best

## UI helper, no rule effect: live bonuses on u if it stood at (x, y): aura (+atk, from a drum, until its side's next
## turn), poison (-atk / -def), water bonus for the water class, terrain def. { atk, atk_from, aura, def, poison, terrain }
static func at(s: Dictionary, u: Dictionary, x: int, y: int) -> Dictionary:
	var st := Game.stat(s, u)
	var tt: Dictionary = Game.TERRAIN[Game.tile_at(s, x, y)]
	var wet: bool = tt.get("water", false)
	var out := { "atk": 0, "atk_from": null, "aura": 0, "def": 0, "def_from": null, "poison": 0, "terrain": Game.terrain_def(s, u, x, y) }
	if u.get("aura") != null:
		out.aura = Game.aura_atk(u)
		out.atk += out.aura
		out.atk_from = "aura"
	if wet and st.get("waterAtk", 0):
		out.atk += st.waterAtk
		out.def += st.get("waterDef", 0)
		out.def_from = "water"
	out.poison = Game.poison_amt(u)
	return out
