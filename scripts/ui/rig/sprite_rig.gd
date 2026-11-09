class_name SpriteRig
extends Rig
## TRY (branch feat/sprite-hero-try): our commander's attack played from raster frames (sprite-gen: a Gemini still +
## Gemini video, keyed and cut in the scratchpad; assets/units/sprite_try/). Rides the normal rig path
## (FX.rig_attack): same token swap, target knock / flash, hit-stop, shake, numbers, sounds. Only the character
## drawing differs: one atlas cell per 41 ms instead of posed SVG parts. The cells are pre-placed in the token's
## 256-art square (`rect_sq`, square units), so cell 0 sits exactly on the standing figure (Token.SPRITE_STILL).
## Limits of the try: the art only lunges sideways (mirrored by facing; up / down targets keep the token's facing),
## the enemy commander keeps the rig.

const ATLAS := "res://assets/units/sprite_try/hero_p_attack.png"
const META := "res://assets/units/sprite_try/hero_p_attack.json"

static var _meta: Dictionary = { }
static var _tex: Texture2D = null

var n_cells := 1
var cols := 1
var frame_ms := 41.0
var cell_px := Vector2.ONE
var dst := Rect2() # cell rect in the 256-art square
var hit_ms := 0.0
var slash_ms := 0.0
var lift := PackedFloat32Array() # per cell: feet above the floor, token squares (shadow shrinks in the leap)

## a sprite attack for (type, side), or null (not ours / try off / assets missing)
static func make(type: String, side: String) -> SpriteRig:
	if not Token.sprite_hero or type != "hero" or side != "p" or Token.fig_style != "chibi":
		return null
	if not _load() or not RigData.exists("hero_p"):
		return null
	var rd := RigData.get_data("hero_p")
	if rd == null:
		return null
	var r := SpriteRig.new(rd, Spec.new())
	r._read(_meta)
	r.part_id = "sprite|hero_p"
	r.a_type = type
	var ud: Dictionary = Rules.UNITS.get(type, { })
	r.heavy = ud.get("heavy", false)
	return r

static func _load() -> bool:
	if _tex != null and not _meta.is_empty():
		return true
	if not ResourceLoader.exists(ATLAS) or not FileAccess.file_exists(META):
		return false
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(META))
	if not j is Dictionary:
		return false
	_meta = j
	_tex = load(ATLAS)
	return _tex != null

func _read(mm: Dictionary) -> void:
	var c: float = mm.cells
	var k: float = mm.cols
	n_cells = int(c)
	cols = int(k)
	frame_ms = mm.frame_ms
	var cp: Array = mm.cell_px
	var cw: float = cp[0]
	var ch: float = cp[1]
	cell_px = Vector2(cw, ch)
	var rs: Array = mm.rect_sq
	var x: float = rs[0]
	var y: float = rs[1]
	var w: float = rs[2]
	var h: float = rs[3]
	dst = Rect2(x * 256.0, y * 256.0, w * 256.0, h * 256.0)
	hit_ms = mm.hit_ms
	slash_ms = mm.slash_ms
	var lf: Array = mm.get("lift_sq", [])
	for v: float in lf:
		lift.append(v)
	var dur: float = mm.dur_ms
	A = { "id": "sprite", "dur": dur + 120.0, "tr": { } }
	pose = pose_at(0.0)

## the cell on screen at attack time t (held on the last one through the tail)
func cell() -> int:
	return clampi(int(t / frame_ms), 0, n_cells - 1)

func draw_char(ci: CanvasItem) -> void:
	if not shown:
		return
	_update_cam()
	var T := cam.T
	var base := cam.root(0.0, 0.0) - Vector2(0.0, (data.feet - 256.0) * cam.ca)
	var k := cell()
	var up: float = lift[k] if k < lift.size() else 0.0
	ci.draw_set_transform_matrix(Draw.xf)
	Token.draw_shadow(ci, base, T, 1.0, clampf(1.0 - up * 2.2, 0.45, 1.0))
	Token.halo(ci, base - Vector2(0.0, T * Token.FOOT), T, Token.HERO_GLOW)
	@warning_ignore("integer_division")
	var src := Rect2(Vector2(k % cols, k / cols) * cell_px, cell_px)
	# char_xf maps the 256-art square onto the token's square (feet on the token's feet, mirrored for facing -1)
	ci.draw_set_transform_matrix(Draw.xf * cam.char_xf(0.0, 0.0))
	ci.draw_texture_rect_region(_tex, dst, src)
	ci.draw_set_transform_matrix(Draw.xf)

## timeline: slash sound + dust at the swing, THE hit when the blade lands (cell 14), plant shake after
class Spec extends RigSpec:
	func events(r: Rig) -> Array:
		var sr: SpriteRig = r
		return [
			[
				sr.slash_ms,
				func(a: Rig) -> void:
					a.sound("slash")
					a.dust(140, 244, 5, -1),
			],
			[
				sr.hit_ms,
				func(a: Rig) -> void:
					a.hit(Rig.with(Rig.HIT, { "debris": "dust", "n": 8 })),
			],
			[
				sr.hit_ms + 60.0,
				func(a: Rig) -> void:
					a.dust(200, 244, 6, 1)
					a.shake(3, 90),
			],
		]
