class_name Token
extends Control
## unit token: lacquered disc in faction colours + the unit's emoji (or `img` from the theme).
## The board paints tokens with Token.paint(); menus / panel use a Token control.

var side := "p"
var type := "soldier"
var hero_key: Variant = null
var px := 56.0
static var _tex := {}

static func make(p_side: String, p_type: String, p_hero: Variant, size := 56.0) -> Token:
	var t := Token.new()
	t.side = p_side
	t.type = p_type
	t.hero_key = p_hero
	t.px = size
	t.custom_minimum_size = Vector2(size, size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _draw() -> void:
	paint(self, Vector2(px / 2.0, px / 2.0 - px * 0.04), px * 0.95, side, type, hero_key, { "mirror": false })

static func image(path: Variant) -> Texture2D:
	if path == null or path == "":
		return null
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]

## o: alpha, bob (px up), glow, flash (0..1), mirror (false = never flip enemy icon)
static func paint(ci: CanvasItem, c: Vector2, T: float, p_side: String, p_type: String, p_hero: Variant, o := {}) -> void:
	var fac: Dictionary = Content.theme().factions[p_side]
	var look := Content.unit_type_look(p_side, p_type, p_hero)
	var hero := p_type == "hero"
	var R := T * 0.4
	var al: float = o.get("alpha", 1.0)
	# shadow
	Draw.ellipse(ci, c + Vector2(0, R * 0.95), R * 0.85, R * 0.28, Color(0, 0, 0, 0.4 * al))
	var bc := Vector2(c.x, c.y - float(o.get("bob", 0.0)))
	if hero or o.get("glow", false):
		var gc := Color("#ffd76a") if hero else Color(fac.glow)
		Draw.radial(ci, bc, R * 1.5, [[0.0, Color(gc, 0.4 * al)], [0.4, Color(gc, 0.4 * al)], [1.0, Color(gc, 0.0)]], 28)
	var b1 := Color(fac.body2)
	var b0 := Color(fac.body)
	b1.a *= al
	b0.a *= al
	Draw.radial(ci, bc, R, [[0.0, b1], [0.55, b1.lerp(b0, 0.6)], [1.0, b0]], 32, Vector2.ONE, Vector2(-R * 0.35, -R * 0.45))
	var ring := Color("#f3c95c") if hero else Color(fac.ring)
	ring.a *= al
	ci.draw_arc(bc, R, 0, TAU, 40, ring, maxf(2.5, T * 0.09) if hero else maxf(1.5, T * 0.05), true)
	if hero:
		ci.draw_arc(bc, R - T * 0.06, 0, TAU, 40, Color(1, 0.953, 0.753, al), 1.0, true)
	# gloss
	Draw.ellipse(ci, bc + Vector2(-R * 0.2, -R * 0.5), R * 0.55, R * 0.25, Color(1, 1, 1, 0.13 * al), -0.3, 20)
	var tex := image(look.get("img"))
	if tex:
		ci.draw_texture_rect(tex, Rect2(bc - Vector2(R * 0.85, R * 0.85), Vector2(R * 1.7, R * 1.7)), false, Color(1, 1, 1, al))
	else:
		var icon: String = look.get("icon", "?")
		var fs := int(round(T * 0.46))
		if p_side == "e" and o.get("mirror", true):
			ci.draw_set_transform(bc, 0.0, Vector2(-1, 1))
			Draw.text_c(ci, Style.body, Vector2(0, T * 0.02), icon, fs, Color(1, 1, 1, al))
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		else:
			Draw.text_c(ci, Style.body, bc + Vector2(0, T * 0.02), icon, fs, Color(1, 1, 1, al))
	var fl: float = o.get("flash", 0.0)
	if fl > 0:
		ci.draw_circle(bc, R, Color(1, 1, 1, minf(1.0, fl) * 0.85))
