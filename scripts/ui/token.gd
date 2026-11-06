class_name Token
extends Control
## unit token: lacquered disc in faction colours + the unit's emoji (or `img` from the theme).
## The board draws tokens from a pre-rendered Token.Atlas; the duel view and menus paint them with Token.paint().

const HERO_GLOW := Color("#ffd76a")
const HERO_RING := Color("#f3c95c")
const FOE_GLOW := Color("#ff4a36") # the enemy commander (villain): red glow + crimson ring instead of gold
const FOE_RING := Color("#d23a2c")

var side := "p"
var type := "soldier"
var hero_key: Variant = null
var px := 56.0
static var _tex := {}
static var _icon_w := {} # "icon|size" -> width, so the hot path never measures strings

static func make(p_side: String, p_type: String, p_hero: Variant, size := 56.0) -> Token:
	var t := Token.new()
	t.side = p_side
	t.type = p_type
	t.hero_key = p_hero
	t.px = size
	t.custom_minimum_size = Vector2(size, size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _enter_tree() -> void:
	add_to_group("token_icon")

func _draw() -> void:
	Draw.xf = Transform2D.IDENTITY
	paint(self, Vector2(px / 2.0, px / 2.0 - px * 0.04), px * 0.95, side, type, hero_key, { "mirror": false })

## art set: full-colour per-side figures assets/units/styles/<fig_style>/<type>_<side>.svg + terrain assets/terrain/<fig_style>/
## (raw SVG, importer "keep", rasterised at runtime). "" = old silhouettes + procedural terrain
static var fig_style := "chibi"
static var _rast := {} # "path@px" -> ImageTexture
static var _rast_old := {}
const RAST_GEN := 192
static var _has := {} # path -> bool

## SVG rasterised at the exact on-screen size (8 px steps): no mipmap blur from downscaling a big import
## 2-generation cache: full -> current gen becomes old, old gen freed. Hits in old gen move to current, so a texture used
## this frame is never freed mid-frame (freed RID = white square in a one-shot bake / an icon not redrawn).
## Rotation redraws every Token icon so its texture moves into the new gen.
## white = solid white silhouette (hit flash, like the demo's targetWhite)
static func raster(path: String, px: float, white := false) -> Texture2D:
	return raster_svg(path, func() -> String: return FileAccess.get_file_as_string(path), px, white)

## same cache for SVG markup built in code (rig parts): `src` returns the 256-viewBox SVG text, only called on a miss
static func raster_svg(id: String, src: Callable, px: float, white := false) -> Texture2D:
	var b := bucket(px)
	var key := "%s@%d%s" % [id, b, "|w" if white else ""]
	var tex: Texture2D = _rast.get(key)
	if tex != null:
		return tex
	tex = _rast_old.get(key)
	if tex == null:
		var img := Image.new()
		var svg: String = src.call()
		if svg == "" or img.load_svg_from_string(svg, b / 256.0) != OK:
			return null
		if white:
			img.adjust_bcs(0.0, -1.0, 1.0) # brightness 0 then contrast -1 -> rgb = 1, alpha kept
		tex = ImageTexture.create_from_image(img)
	if _rast.size() >= RAST_GEN:
		_rast_old = _rast
		_rast = {}
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			tree.call_group.call_deferred("token_icon", "queue_redraw")
	_rast[key] = tex
	return tex

## the texel size raster() really renders `px` at
static func bucket(px: float) -> int:
	return maxi(16, ceili(px / 8.0) * 8)

static func exists(path: String) -> bool:
	if not _has.has(path):
		_has[path] = FileAccess.file_exists(path)
	return _has[path]

static func image(path: Variant) -> Texture2D:
	if path == null or path == "":
		return null
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]

## o: alpha, bob (px up), glow, flash (0..1), mirror (false = never flip enemy icon), shadow (false = skip it),
## halo (false = skip the commander's glow), rs (px per canvas unit to rasterise SVG art at; default = on screen now).
## Composes with the item's current transform (Draw.xf).
static func paint(ci: CanvasItem, c: Vector2, T: float, p_side: String, p_type: String, p_hero: Variant, o := {}) -> void:
	var fac: Dictionary = Draw.pal().factions[p_side]
	var look := Content.unit_type_look(p_side, p_type, p_hero)
	var hero := p_type == "hero"
	var foe := hero and p_side == "e"
	if fig_style != "":
		var alt := "res://assets/units/styles/%s/%s_%s.svg" % [fig_style, p_type, p_side]
		if exists(alt):
			_standee(ci, c, T, p_side, hero, foe, fac, null, o.merged({ "color": true, "svg": alt }))
			return
	var fig := image(look.get("fig"))
	if fig:
		_standee(ci, c, T, p_side, hero, foe, fac, fig, o)
		return
	var R := T * 0.4
	var al: float = o.get("alpha", 1.0)
	if o.get("shadow", true):
		Draw.ellipse(ci, c + Vector2(0, R * 0.95), R * 0.85, R * 0.28, Color(0, 0, 0, 0.4 * al))
	var bc := Vector2(c.x, c.y - float(o.get("bob", 0.0)))
	if (hero or o.get("glow", false)) and o.get("halo", true):
		halo(ci, bc, T, (FOE_GLOW if foe else HERO_GLOW) if hero else fac.glow, al)
	var b1: Color = fac.body2
	var b0: Color = fac.body
	b1.a *= al
	b0.a *= al
	Draw.radial(ci, bc, R, [[0.0, b1], [0.55, b1.lerp(b0, 0.6)], [1.0, b0]], 32, Vector2.ONE, Vector2(-R * 0.35, -R * 0.45))
	var ring: Color = (FOE_RING if foe else HERO_RING) if hero else fac.ring
	ring.a *= al
	ci.draw_arc(bc, R, 0, TAU, 40, ring, maxf(2.5, T * 0.09) if hero else maxf(1.5, T * 0.05), true)
	if hero:
		ci.draw_arc(bc, R - T * 0.06, 0, TAU, 40, Color(0.1, 0.02, 0.02, al) if foe else Color(1, 0.953, 0.753, al), 1.0, true)
	# gloss
	Draw.ellipse(ci, bc + Vector2(-R * 0.2, -R * 0.5), R * 0.55, R * 0.25, Color(1, 1, 1, 0.13 * al), -0.3, 20)
	var tex := image(look.get("img"))
	if tex:
		ci.draw_texture_rect(tex, Rect2(bc - Vector2(R * 0.85, R * 0.85), Vector2(R * 1.7, R * 1.7)), false, Color(1, 1, 1, al))
	else:
		var icon: String = look.get("icon", "?")
		var fs := Draw.font_size(T * 0.46)
		var k := T * 0.46 / fs
		var key := "%s|%d" % [icon, fs]
		if not _icon_w.has(key):
			_icon_w[key] = Style.body.get_string_size(icon, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w: float = _icon_w[key]
		var dy := (Style.body.get_ascent(fs) - Style.body.get_descent(fs)) / 2.0
		var flip := -1.0 if p_side == "e" and o.get("mirror", true) else 1.0
		# icon drawn at a fixed font size, scaled (and mirrored for the enemy) around the disc centre
		ci.draw_set_transform_matrix(Draw.xf * Transform2D(0.0, Vector2(k * flip, k), 0.0, bc + Vector2(0, T * 0.02)))
		ci.draw_string(Style.body, Vector2(-w / 2.0, dy), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, al))
		ci.draw_set_transform_matrix(Draw.xf)
	var fl: float = o.get("flash", 0.0)
	if fl > 0:
		ci.draw_circle(bc, R, Color(1, 1, 1, minf(1.0, fl) * 0.85))

## standing figure: soft ground shadow + the silhouette in the faction's figure colour with a dark outline (mirrored for
## the enemy); no base, so it reads as standing on the ground. ~0.66 tile tall, so the tile around it stays visible.
## Commanders keep their gold / crimson glow behind them.
const FIG_INK := Color(0.07, 0.04, 0.03)
const FOOT := 0.30 # figure's feet below the tile centre, tiles (rig feet + board pose pivot match it)
const ART := 1.12 # full-colour art is drawn this much taller than a silhouette

## standing figure height, px (the 256 SVG square's side); colour = full-colour art
static func fig_h(type: String, T: float, colour := true) -> float:
	var h := T * (0.74 if type == "hero" else 0.66)
	return h * ART if colour else h

## ground shadow under a standing figure whose feet are at `base`; squash < 1 = smaller (in the air)
static func draw_shadow(ci: CanvasItem, base: Vector2, T: float, al := 1.0, squash := 1.0) -> void:
	Draw.ellipse(ci, base + Vector2(T * 0.02, T * 0.01), T * 0.24 * squash, T * 0.075 * squash, Color(0, 0, 0, 0.42 * al))

static func _standee(ci: CanvasItem, c: Vector2, T: float, side: String, hero: bool, foe: bool, fac: Dictionary, fig: Texture2D, o: Dictionary) -> void:
	var al: float = o.get("alpha", 1.0)
	var base := c + Vector2(0, T * FOOT)
	if o.get("shadow", true):
		draw_shadow(ci, base, T, al)
	var bob: float = o.get("bob", 0.0)
	if (hero or o.get("glow", false)) and o.get("halo", true):
		halo(ci, c - Vector2(0, bob), T, (FOE_GLOW if foe else HERO_GLOW) if hero else fac.glow, al)
	var colour: bool = o.get("color", false) # full-colour art: drawn as is, no faction fill / ink outline
	var h := fig_h("hero" if hero else "", T, colour)
	var flip := -1.0 if side == "e" and o.get("mirror", true) else 1.0
	var col: Color = Color.WHITE if colour else fac.get("fig", fac.body2)
	col *= o.get("tint", Color.WHITE)
	col.a *= al
	var ink := FIG_INK
	ink.a *= al
	var foot := base - Vector2(0, bob)
	var rpx := 0.0
	if colour:
		# y scale too: an edge-on turn (x ~ 0) must not rasterise a tiny texture per frame
		rpx = h * float(o.get("rs", Baked.screen_scale(ci))) * maxf(absf(Draw.xf.get_scale().x), absf(Draw.xf.get_scale().y))
		fig = raster(o.svg, rpx)
		if fig == null:
			return
	var r := Rect2(-h / 2.0, -h, h, h)
	ci.draw_set_transform_matrix(Draw.xf * Transform2D(0.0, Vector2(flip, 1.0), 0.0, foot))
	var w := maxf(1.0, T * 0.03)
	for d: Vector2 in ([] if colour else [Vector2(-w, 0), Vector2(w, 0), Vector2(0, -w), Vector2(0, w), Vector2(-w, -w) * 0.7, Vector2(w, -w) * 0.7, Vector2(-w, w) * 0.7,
		Vector2(w, w) * 0.7]):
		ci.draw_texture_rect(fig, Rect2(r.position + d, r.size), false, ink)
	ci.draw_texture_rect(fig, r, false, col)
	var fl: float = o.get("flash", 0.0)
	if fl > 0: # white silhouette at alpha = flash (engine.js drawTarget)
		var wt: Texture2D = raster(o.svg, rpx, true) if colour else fig
		ci.draw_texture_rect(wt if wt != null else fig, r, false, Color(1, 1, 1, minf(1.0, fl) * al))
	ci.draw_set_transform_matrix(Draw.xf)

## raster a figure ahead at `rs` px per unit, as _standee will ask for it (+ a breathing step up)
static func warm(T: float, p_side: String, p_type: String, rs: float) -> void:
	var alt := "res://assets/units/styles/%s/%s_%s.svg" % [fig_style, p_type, p_side]
	if fig_style == "" or not exists(alt):
		return
	var px := fig_h(p_type, T) * rs
	raster(alt, px)
	raster(alt, px * 1.02)

## the commander's soft gold glow behind the disc
static func halo(ci: CanvasItem, bc: Vector2, T: float, gc: Color, al := 1.0) -> void:
	var R := T * 0.4
	Draw.radial(ci, bc, R * 1.5, [[0.0, Color(gc, 0.4 * al)], [0.4, Color(gc, 0.4 * al)], [1.0, Color(gc, 0.0)]], 28)

## every token the board can show (both sides x every unit type, plus the two commanders) rendered once at the
## board's tile size: a unit then costs one textured quad per frame. Shadow has its own cell (pure black, so the
## render target's premultiplied alpha draws back exactly); the commander glow stays live (translucent colour).
class Atlas extends RefCounted:
	var vp: Baked
	var T := 0.0
	var key := ""
	var cells := {} # "side|type" -> Rect2 in texels
	var unit := 0.0 # canvas units per cell side
	var _list := [] # [[cell key, side, type, hero]]
	var _cpx := 0 # texels per cell side
	var _cols := 1

	func _init(host: Node) -> void:
		vp = Baked.new(_paint)
		host.add_child(vp)

	## (re)render when tile size, screen scale, commanders or chapter changed; cheap no-op otherwise
	func ensure(p_T: float, scale: float, hero_keys: Dictionary) -> void:
		var k := "%s|%s|%s|%.3f|%.3f" % [Content.active_chapter, hero_keys.get("p"), hero_keys.get("e"), p_T, scale]
		if k == key:
			return
		key = k
		T = p_T
		_list = [["shadow", "p", "", null]]
		for side: String in ["p", "e"]:
			for type: String in Content.theme().units[side]:
				if type != "hero":
					_list.append(["%s|%s" % [side, type], side, type, null])
			if hero_keys.get(side) != null:
				_list.append(["%s|hero" % side, side, "hero", hero_keys[side]])
		_cpx = ceili(T * 1.04 * scale) + 2
		unit = (_cpx - 2) / scale
		_cols = clampi(int(4096.0 / _cpx), 1, 8)
		var rows := ceili(float(_list.size()) / _cols)
		cells.clear()
		for i in _list.size():
			cells[_list[i][0]] = Rect2((i % _cols) * _cpx + 1, (i / _cols) * _cpx + 1, _cpx - 2, _cpx - 2)
		vp.bake(Vector2(_cols * _cpx, rows * _cpx) / scale, scale)

	func _paint(ci: CanvasItem) -> void:
		var scale: float = vp.canvas_transform.get_scale().x
		for i in _list.size():
			var it: Array = _list[i]
			var c := (Vector2(i % _cols, i / _cols) * _cpx + Vector2(_cpx, _cpx) / 2.0) / scale
			if it[0] == "shadow":
				var R := T * 0.4
				Draw.ellipse(ci, c, R * 0.62, R * 0.2, Color(0, 0, 0, 0.42))
			else:
				Token.paint(ci, c, T, it[1], it[2], it[3], { "shadow": false, "halo": false })

	func texture() -> Texture2D:
		return vp.get_texture()

	## shadow at c, disc bobbed up by `bob`; scale / alpha for fading corpses. False when not baked for this unit.
	## st = ci.get_screen_transform(): unscaled cells land on whole screen pixels, so the texels map 1:1 (no blur)
	## the ground shadow alone (it stays on the ground while the figure hops / leans); squash < 1 = smaller (figure in the air)
	func draw_shadow(ci: CanvasItem, c: Vector2, sc: float, alpha: float, squash := 1.0) -> void:
		if not cells.has("shadow"):
			return
		var half := unit * sc / 2.0 * squash
		var R := T * sc * 0.4
		ci.draw_texture_rect_region(vp.get_texture(), Rect2(c + Vector2(-half, R * 0.78 - half), Vector2(half, half) * 2.0), cells.shadow, Color(1, 1, 1, alpha))

	## shadow = false: figure only (drawn under a pose transform); snap = false when that transform is not a pure offset
	func draw(ci: CanvasItem, st: Transform2D, c: Vector2, side: String, type: String, bob: float, sc: float, alpha: float, tint := Color.WHITE, shadow := true, snap := true) -> bool:
		var r: Variant = cells.get("%s|%s" % [side, type])
		if r == null:
			return false
		var tex := vp.get_texture()
		var half := unit * sc / 2.0
		var R := T * sc * 0.4
		var bc := c - Vector2(0, bob)
		var sh := c + Vector2(-half, R * 0.78 - half)
		var tl := bc - Vector2(half, half)
		if sc == 1.0 and snap:
			var inv := st.affine_inverse()
			sh = inv * (st * sh).round()
			tl = inv * (st * tl).round()
		if shadow:
			ci.draw_texture_rect_region(tex, Rect2(sh, Vector2(half, half) * 2.0), cells.shadow, Color(1, 1, 1, alpha))
		if type == "hero":
			Token.halo(ci, tl + Vector2(half, half), T * sc, Token.FOE_GLOW if side == "e" else Token.HERO_GLOW, alpha)
		ci.draw_texture_rect_region(tex, Rect2(tl, Vector2(half, half) * 2.0), r, Color(tint, alpha))
		return true
