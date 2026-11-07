extends SceneTree
## checks every hover path the board would draw: starts at the unit, steps between neighbours, ends at the tile,
## and the dashed renderer puts ink on every step. run: godot --headless --path . -s sim/path_check.gd

var bad := 0
var checked := 0

func _init() -> void:
	for m: Dictionary in Content.campaign():
		var s := Game.new_game(m)
		var mid: String = m.id
		for u: Dictionary in s.units:
			if u.side != "p":
				continue
			var reach := Game.reachable(s, u)
			for key: Vector2i in reach:
				_check(mid, s, u, Game.path_for(s, u, key.x, key.y), key)
	print("paths checked %d, bad %d" % [checked, bad])
	quit()

func _check(mid: String, _s: Dictionary, u: Dictionary, path: Array, to: Vector2i) -> void:
	checked += 1
	var why := ""
	if path.is_empty():
		why = "empty"
	elif path[0][0] != u.x or path[0][1] != u.y:
		why = "does not start at the unit"
	elif path[path.size() - 1][0] != to.x or path[path.size() - 1][1] != to.y:
		why = "does not end at the tile"
	else:
		for i in range(1, path.size()):
			var a: Array = path[i - 1]
			var b: Array = path[i]
			var dx: int = b[0] - a[0]
			var dy: int = b[1] - a[1]
			if absi(dx) + absi(dy) != 1:
				why = "jump at step %d" % i
				break
	if why == "" and path.size() > 1:
		# replay the dash maths with T = 64 and several phases: every step must get some ink
		var T := 64.0
		var pts := []
		for p: Array in path:
			var px: float = p[0]
			var py: float = p[1]
			pts.append(Vector2((px + 0.5) * T, (py + 0.5) * T))
		for phase: float in [0.0, 5.0, 11.0, 17.0]:
			var inked := _ink(pts, T * 0.12, T * 0.14, phase)
			for i in range(1, pts.size()):
				if not inked[i - 1]:
					why = "step %d has no dash (phase %.0f)" % [i, phase]
					break
			if why != "":
				break
	if why != "":
		bad += 1
		if bad <= 20:
			print("BAD %s unit %s@%d,%d -> %s: %s  path=%s" % [mid, u.type, u.x, u.y, to, why, path])

## which segments receive at least one dash (same maths as Board._dashed / _sub_path)
func _ink(pts: Array, on: float, off: float, phase: float) -> Array:
	var period := on + off
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		var p0: Vector2 = pts[i - 1]
		var p1: Vector2 = pts[i]
		cum.append(cum[i - 1] + p1.distance_to(p0))
	var total := cum[cum.size() - 1]
	var inked := []
	inked.resize(pts.size() - 1)
	inked.fill(false)
	var start := -fposmod(phase, period)
	var n := ceili((total - start) / period) + 1
	for k in mini(n, 400):
		var s0 := maxf(0.0, start + k * period)
		var s1 := minf(total, start + k * period + on)
		if s1 <= s0:
			continue
		for i in range(1, pts.size()):
			if cum[i] > s0 and cum[i - 1] < s1:
				inked[i - 1] = true
	return inked
