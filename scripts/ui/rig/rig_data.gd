class_name RigData
extends RefCounted
## one exported attack spec (assets/units/rig/<name>.json, made by tools/rig_export.mjs): parts, bones, draw order,
## points, spring constants, attacks with their tracks as keys. Pure data; the spec's functions live in specs/<unit>.gd.

const DIR := "res://assets/units/rig/"
## enemy = our art with only the team colours swapped (SHARED.md); commanders have their own spec instead
const TEAM_SWAP := [["#c9503f", "#4f74c9"], ["#93362b", "#32508f"]]
const EASES := ["lin", "out", "in", "io", "outExpo", "outBack", "hold"]

static var _cache := {}

var name := ""
var feet := 244.0
var cx := 128.0
var outline := 7.0
var range_tiles := 1.0
var target_front := 84.0
var target_cy := 150.0
var shadow_r := 62.0
var parts := {} # part -> inner markup
var raw := {} # part -> true: drawn without the outline group (faces, eyes)
var bones := [] # [{name, parent, pivot: Vector2, ch, tx, ty, sc, stretch}] parent before child
var draw := [] # [[part, bone, alpha channel or ""]]
var points := {} # name -> [bone, Vector2]
var springs := {} # name -> {k, c}
var hooks := {} # idle / order present in the JS spec (the port must implement them)
var attacks := {} # id -> {id, label, dur, tr: {ch: [[t, v, ease index], ...]}, smear, ev_times, draw, sampled}
var attack_ids := []
var consts := {} # every plain top-level const of the spec (HIT, DMG, timings, colours), evaluated
var base := {} # channel -> value at rest (engine basePose)
var _svg := {}

static func path_of(spec: String) -> String:
	return DIR + spec + ".json"

static func exists(spec: String) -> bool:
	return FileAccess.file_exists(path_of(spec))

static func get_data(spec: String) -> RigData:
	if _cache.has(spec):
		return _cache[spec]
	var d := RigData.new()
	if not d._load(spec):
		d = null
	_cache[spec] = d
	return d

func _load(spec: String) -> bool:
	var txt := FileAccess.get_file_as_string(path_of(spec))
	var j: Variant = JSON.parse_string(txt) if txt != "" else null
	if not (j is Dictionary):
		push_error("rig: cannot read %s" % path_of(spec))
		return false
	name = spec
	feet = j.feet
	cx = j.cx
	outline = j.outline
	range_tiles = j.range
	target_front = j.targetFront
	target_cy = j.targetCY
	shadow_r = j.shadowR
	parts = j.parts
	for r: String in j.raw:
		raw[r] = true
	for b: Dictionary in j.bones:
		var o := b.duplicate()
		o.pivot = Vector2(b.pivot[0], b.pivot[1])
		bones.append(o)
	for e: Array in j.draw:
		draw.append([e[0], e[1], e[2] if e.size() > 2 else ""])
	for k: String in j.points:
		var q: Array = j.points[k]
		points[k] = [q[0], Vector2(q[1], q[2])]
	springs = j.springs
	hooks = j.hooks
	consts = j.consts
	for a: Dictionary in j.attacks:
		var tr := {}
		for ch: String in a.tr:
			var keys := []
			for q: Array in a.tr[ch]:
				keys.append([float(q[0]), float(q[1]), maxi(0, EASES.find(q[2]))])
			tr[ch] = keys
		var o := a.duplicate()
		o.tr = tr
		attacks[a.id] = o
		attack_ids.append(a.id)
	# engine basePose: root channels, bone channels at 0, springs at 0, track-only channels at their t=0 value
	base = { "x": 0.0, "y": 0.0, "sy": 1.0, "face": 1.0, "spin": 0.0 }
	for b: Dictionary in bones:
		for k: String in ["ch", "tx", "ty", "sc"]:
			if b.has(k):
				base[b[k]] = 0.0
	for k: String in springs:
		base[k] = 0.0
	for id: String in attack_ids:
		var tr: Dictionary = attacks[id].tr
		for ch: String in tr:
			if not base.has(ch):
				base[ch] = tr[ch][0][1]
	return true

static func ease_i(i: int, u: float) -> float:
	match i:
		0: return u
		1: return 1.0 - pow(1.0 - u, 3.0)
		2: return u * u * u
		3: return 4.0 * u * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 3.0) / 2.0
		4: return 1.0 if u >= 1.0 else 1.0 - pow(2.0, -10.0 * u)
		5: return 1.0 + 2.9 * pow(u - 1.0, 3.0) + 1.9 * pow(u - 1.0, 2.0)
	return 0.0

static func ease_by_name(n: String, u: float) -> float:
	return ease_i(maxi(0, EASES.find(n)), u)

## engine track(): keys [[t, v, ease of the segment ending here], ...]
static func sample(keys: Array, t: float) -> float:
	if t <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		var k1: Array = keys[i]
		if t <= k1[0]:
			var k0: Array = keys[i - 1]
			return k0[1] + (k1[1] - k0[1]) * ease_i(k1[2], (t - k0[0]) / (k1[0] - k0[0]))
	return keys[keys.size() - 1][1]

## a track given as JSON keys (e.g. consts.X = {track: [...]}) -> same key format as attacks
static func keys_of(js: Array) -> Array:
	var out := []
	for q: Array in js:
		out.append([float(q[0]), float(q[1]), maxi(0, EASES.find(q[2]))])
	return out

## the part as engine.js builds it: full 256 viewBox, wrapped in the outline group unless raw; swap = enemy colours
func part_svg(part: String, swap: bool) -> String:
	var key := "%s|%s" % [part, swap]
	if _svg.has(key):
		return _svg[key]
	var inner: String = parts[part]
	if not raw.has(part):
		inner = '<g stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round">%s</g>' % ["#" + RigFx.INK.to_html(false), _num(outline), inner]
	var s := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">%s</svg>' % inner
	if swap:
		for pr: Array in TEAM_SWAP:
			s = s.replacen(pr[0], pr[1])
	_svg[key] = s
	return s

static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else str(v)
