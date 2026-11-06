class_name Pieces
extends RefCounted
## code-built figurines + buildings for the 3D board. Local frame: origin = centre of the base on the ground,
## 1 unit = 1 tile, the figure faces +X. Colours come from the theme palette (faction body / ring / roof).

const SKIN := Color("#e2b48c")
const WOOD := Color("#6b4a2b")
const WOOD2 := Color("#8a6438")
const METAL := Color("#cfc8b8")
const STRAW := Color("#d9c48a")
const DARK := Color("#2a201a")
const TROUSER := Color("#3b2a20")
const GOLD := Color("#e0b24a")
const GOLD_RING := Color("#f3c95c")
const VILLAIN := Color("#2b2630")
const CRIMSON := Color("#a3201a")
const BONE := Color("#e8dcc8")

static var _cache := { }

static func unit(side: String, type: String) -> ArrayMesh:
	var key := "%s|%s|%s" % [Content.active_chapter, side, type]
	if not _cache.has(key):
		_cache[key] = _build(side, type)
	return _cache[key]

static func _build(side: String, type: String) -> ArrayMesh:
	var fac: Dictionary = Draw.pal().factions[side]
	var k := Kit.new()
	var body: Color = fac.body2
	var dark: Color = fac.body
	var ring: Color = fac.ring
	if type == "hero":
		ring = GOLD_RING if side == "p" else CRIMSON
	# base disc in faction colours (reads like the 2D token from above)
	k.cyl(Vector3.ZERO, 0.3, 0.29, 0.05, ring, 18, dark)
	match type:
		"hero":
			if side == "p":
				_hero(k, body, dark)
			else:
				_villain(k)
		"elephant":
			_elephant(k, body, dark)
		"bird":
			_rider(k, body, dark)
		"catapult":
			_catapult(k, body)
		_:
			_foot(k, type, body, dark)
	return k.commit()

## common foot figure: legs, tunic, head; then the kit of its type
static func _foot(k: Kit, type: String, body: Color, dark: Color) -> void:
	var ghost := type == "ghost"
	var tunic: Color = Color("#9fb3bf") if ghost else body
	var skin: Color = Color("#c9d6dc") if ghost else SKIN
	k.box(Vector3(0, 0.12, 0), Vector3(0.11, 0.14, 0.15), TROUSER)
	var robe := 0.26 if type == "shaman" else 0.2
	k.cyl(Vector3(0, 0.19 - (robe - 0.2), 0), 0.13, 0.095, robe, tunic, 10, tunic)
	k.cyl(Vector3(0, 0.37, 0), 0.1, 0.06, 0.04, tunic.darkened(0.2), 8)
	k.ball(Vector3(0, 0.47, 0), 0.075, skin)
	# arms
	k.box(Vector3(0.02, 0.3, 0.12), Vector3(0.06, 0.14, 0.05), tunic.darkened(0.1))
	k.box(Vector3(0.02, 0.3, -0.12), Vector3(0.06, 0.14, 0.05), tunic.darkened(0.1))
	match type:
		"soldier", "ghost":
			k.cone(Vector3(0, 0.5, 0), 0.15, 0.08, Color("#a9b6bb") if ghost else STRAW, 12) # nón lá
			k.cyl(Vector3(0.05, 0.06, 0.15), 0.014, 0.014, 0.66, WOOD, 6) # spear
			k.cone(Vector3(0.05, 0.72, 0.15), 0.028, 0.09, METAL, 6)
			k.xf = Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(0.12, 0.28, -0.08))
			k.cyl(Vector3.ZERO, 0.1, 0.1, 0.025, WOOD2 if not ghost else Color("#b8c4c8"), 10, dark) # round shield
			k.xf = Transform3D.IDENTITY
			if ghost:
				k.cyl(Vector3(0, 0.44, 0), 0.08, 0.08, 0.03, Color.WHITE, 8) # bandage
		"archer":
			k.cone(Vector3(0, 0.5, 0), 0.15, 0.08, STRAW, 12)
			# crossbow held forward: stock + bow arms + string
			k.box(Vector3(0.16, 0.3, 0), Vector3(0.22, 0.03, 0.04), WOOD)
			k.box(Vector3(0.24, 0.31, 0), Vector3(0.03, 0.03, 0.3), WOOD2)
			k.box(Vector3(0.2, 0.31, 0), Vector3(0.006, 0.01, 0.28), BONE)
			k.xf = Transform3D(Basis(Vector3.FORWARD, -0.35), Vector3(-0.1, 0.22, 0.04))
			k.cyl(Vector3.ZERO, 0.035, 0.04, 0.2, DARK, 6) # quiver
			k.xf = Transform3D.IDENTITY
		"drum":
			k.cyl(Vector3(0, 0.5, 0), 0.085, 0.07, 0.05, dark, 8) # turban
			k.xf = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0.17, 0.24, -0.08))
			k.cyl(Vector3.ZERO, 0.12, 0.12, 0.16, Color("#8a3a22"), 12, Color("#e8d7b0"), true) # bronze drum
			k.xf = Transform3D.IDENTITY
			k.box(Vector3(0.12, 0.38, 0.1), Vector3(0.16, 0.02, 0.02), WOOD2)
		"shaman":
			k.cone(Vector3(0, 0.51, 0), 0.1, 0.12, Color("#5a4632"), 8)
			k.cyl(Vector3(0.1, 0.05, 0.14), 0.014, 0.012, 0.62, WOOD, 6) # staff
			k.ball(Vector3(0.1, 0.7, 0.14), 0.055, Color("#5fa04a"), 6, 4) # herbs
			k.ball(Vector3(0.14, 0.66, 0.12), 0.035, Color("#8cc56a"), 6, 3)

static func _hero(k: Kit, body: Color, dark: Color) -> void:
	k.box(Vector3(0, 0.13, 0), Vector3(0.12, 0.16, 0.16), TROUSER)
	k.cyl(Vector3(0, 0.2, 0), 0.15, 0.11, 0.22, body, 10, body)
	k.cyl(Vector3(0, 0.3, 0), 0.135, 0.12, 0.1, GOLD, 10) # breastplate
	k.box(Vector3(-0.11, 0.3, 0), Vector3(0.03, 0.38, 0.26), dark) # cape
	k.ball(Vector3(0, 0.52, 0), 0.08, SKIN)
	k.cyl(Vector3(0, 0.57, 0), 0.075, 0.08, 0.05, GOLD, 10) # crown band
	for i in 5:
		var a := TAU * i / 5.0
		k.cone(Vector3(cos(a) * 0.065, 0.62, sin(a) * 0.065), 0.02, 0.05, GOLD, 4)
	k.box(Vector3(0.04, 0.34, 0.14), Vector3(0.06, 0.16, 0.05), body.darkened(0.1)) # arm
	k.box(Vector3(0.06, 0.6, 0.16), Vector3(0.025, 0.5, 0.04), METAL) # raised sword
	k.box(Vector3(0.06, 0.36, 0.16), Vector3(0.08, 0.025, 0.06), GOLD) # guard

static func _villain(k: Kit) -> void:
	k.box(Vector3(0, 0.13, 0), Vector3(0.13, 0.16, 0.17), DARK)
	k.cyl(Vector3(0, 0.2, 0), 0.16, 0.12, 0.24, VILLAIN, 10, VILLAIN)
	k.cyl(Vector3(0, 0.36, 0), 0.15, 0.14, 0.05, CRIMSON, 10) # trim
	k.box(Vector3(-0.12, 0.3, 0), Vector3(0.03, 0.42, 0.32), CRIMSON.darkened(0.25)) # cape
	k.box(Vector3(0, 0.44, 0.15), Vector3(0.1, 0.08, 0.08), VILLAIN) # pauldrons
	k.box(Vector3(0, 0.44, -0.15), Vector3(0.1, 0.08, 0.08), VILLAIN)
	k.ball(Vector3(0, 0.53, 0), 0.08, Color("#c99a78"))
	k.cyl(Vector3(0, 0.55, 0), 0.09, 0.07, 0.07, VILLAIN, 10, VILLAIN) # helmet
	for zs: float in [1.0, -1.0]: # horns
		k.xf = Transform3D(Basis(Vector3.RIGHT, -zs * 0.7), Vector3(0, 0.6, zs * 0.06))
		k.cone(Vector3.ZERO, 0.025, 0.14, BONE, 5)
	k.xf = Transform3D.IDENTITY
	k.cyl(Vector3(0.08, 0.05, 0.17), 0.016, 0.016, 0.7, WOOD, 6) # axe haft
	k.box(Vector3(0.14, 0.66, 0.17), Vector3(0.12, 0.14, 0.02), METAL.darkened(0.25)) # axe head
	k.box(Vector3(0.2, 0.66, 0.17), Vector3(0.02, 0.17, 0.025), CRIMSON)

static func _elephant(k: Kit, body: Color, dark: Color) -> void:
	var g := Color("#8b8a86")
	k.xf = Transform3D(Basis().scaled(Vector3(1.0, 0.62, 0.6)), Vector3(-0.02, 0.38, 0))
	k.ball(Vector3.ZERO, 0.3, g, 10, 6)
	k.xf = Transform3D.IDENTITY
	for p: Vector2 in [Vector2(0.15, 0.1), Vector2(0.15, -0.1), Vector2(-0.17, 0.1), Vector2(-0.17, -0.1)]:
		k.cyl(Vector3(p.x, 0.04, p.y), 0.055, 0.05, 0.26, g.darkened(0.1), 8)
	k.ball(Vector3(0.28, 0.45, 0), 0.12, g, 8, 5)
	k.xf = Transform3D(Basis().scaled(Vector3(0.35, 1.0, 1.0)), Vector3(0.24, 0.47, 0))
	k.ball(Vector3(0, 0, 0.12), 0.1, g.darkened(0.08), 6, 4)
	k.ball(Vector3(0, 0, -0.12), 0.1, g.darkened(0.08), 6, 4)
	k.xf = Transform3D(Basis(Vector3.BACK, -2.6), Vector3(0.36, 0.42, 0))
	k.cyl(Vector3.ZERO, 0.04, 0.025, 0.28, g, 6) # trunk
	for zs: float in [1.0, -1.0]:
		k.xf = Transform3D(Basis(Vector3.BACK, -1.9), Vector3(0.36, 0.38, zs * 0.06))
		k.cone(Vector3.ZERO, 0.02, 0.14, BONE, 5) # tusks
	k.xf = Transform3D.IDENTITY
	k.box(Vector3(-0.04, 0.6, 0), Vector3(0.22, 0.08, 0.24), body, dark) # howdah
	k.cyl(Vector3(-0.04, 0.64, 0), 0.05, 0.04, 0.12, body.lightened(0.1), 8)
	k.ball(Vector3(-0.04, 0.8, 0), 0.05, SKIN, 6, 4)
	k.cone(Vector3(-0.04, 0.83, 0), 0.08, 0.05, STRAW, 8)

static func _rider(k: Kit, body: Color, dark: Color) -> void:
	var hc := Color("#7a5636")
	k.xf = Transform3D(Basis().scaled(Vector3(1.0, 0.5, 0.45)), Vector3(0, 0.34, 0))
	k.ball(Vector3.ZERO, 0.24, hc, 8, 5)
	k.xf = Transform3D.IDENTITY
	for p: Vector2 in [Vector2(0.13, 0.06), Vector2(0.13, -0.06), Vector2(-0.14, 0.06), Vector2(-0.14, -0.06)]:
		k.cyl(Vector3(p.x, 0.04, p.y), 0.028, 0.024, 0.26, hc.darkened(0.15), 6)
	k.xf = Transform3D(Basis(Vector3.BACK, -0.7), Vector3(0.18, 0.38, 0))
	k.box(Vector3(0, 0.1, 0), Vector3(0.08, 0.22, 0.07), hc) # neck
	k.xf = Transform3D.IDENTITY
	k.box(Vector3(0.3, 0.52, 0), Vector3(0.15, 0.07, 0.07), hc) # head
	k.box(Vector3(0.24, 0.55, 0), Vector3(0.1, 0.04, 0.02), DARK) # mane
	k.xf = Transform3D(Basis(Vector3.BACK, 0.9), Vector3(-0.23, 0.36, 0))
	k.cone(Vector3.ZERO, 0.035, 0.18, DARK, 5) # tail
	k.xf = Transform3D.IDENTITY
	k.box(Vector3(-0.02, 0.45, 0), Vector3(0.16, 0.04, 0.2), dark) # saddle cloth
	k.cyl(Vector3(-0.02, 0.46, 0), 0.075, 0.06, 0.17, body, 8)
	k.ball(Vector3(-0.02, 0.69, 0), 0.06, SKIN, 6, 4)
	k.cone(Vector3(-0.02, 0.72, 0), 0.12, 0.06, STRAW, 10)
	k.xf = Transform3D(Basis(Vector3.BACK, -0.5), Vector3(0.02, 0.45, 0.1))
	k.cyl(Vector3.ZERO, 0.012, 0.012, 0.5, WOOD, 5)
	k.cone(Vector3(0, 0.5, 0), 0.024, 0.08, METAL, 5)
	k.xf = Transform3D.IDENTITY

static func _catapult(k: Kit, body: Color) -> void:
	k.box(Vector3(0, 0.14, 0), Vector3(0.46, 0.05, 0.26), WOOD)
	for p: Vector2 in [Vector2(0.15, 0.15), Vector2(0.15, -0.15), Vector2(-0.15, 0.15), Vector2(-0.15, -0.15)]:
		k.xf = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(p.x, 0.1, p.y - signf(p.y) * 0.01))
		k.cyl(Vector3.ZERO, 0.075, 0.075, 0.03, DARK, 8, WOOD2, true)
	k.xf = Transform3D.IDENTITY
	k.box(Vector3(0, 0.3, 0.09), Vector3(0.04, 0.28, 0.035), WOOD2)
	k.box(Vector3(0, 0.3, -0.09), Vector3(0.04, 0.28, 0.035), WOOD2)
	k.box(Vector3(0, 0.43, 0), Vector3(0.05, 0.03, 0.22), WOOD)
	k.xf = Transform3D(Basis(Vector3.BACK, 0.55), Vector3(0, 0.43, 0))
	k.box(Vector3(-0.08, 0, 0), Vector3(0.42, 0.035, 0.05), WOOD)
	k.box(Vector3(-0.28, 0.03, 0), Vector3(0.08, 0.05, 0.09), WOOD2)
	k.ball(Vector3(-0.28, 0.09, 0), 0.045, Color("#8a7a64"), 6, 4)
	k.xf = Transform3D.IDENTITY
	k.box(Vector3(0.18, 0.3, -0.12), Vector3(0.012, 0.32, 0.012), WOOD)
	k.box(Vector3(0.18, 0.4, -0.07), Vector3(0.008, 0.1, 0.1), body) # pennant

# ---------- buildings ----------
static func village(roof: Color, wall: Color) -> ArrayMesh:
	var k := Kit.new()
	k.box(Vector3(0, 0.025, 0), Vector3(0.62, 0.05, 0.46), Color("#8c7a5a"), Color("#a08d68")) # yard
	k.box(Vector3(0.02, 0.15, 0.0), Vector3(0.44, 0.22, 0.28), wall)
	k.box(Vector3(0.02, 0.11, 0.142), Vector3(0.08, 0.14, 0.01), DARK) # door
	k.roof(Vector3(0.02, 0.26, 0.0), 0.56, 0.42, 0.17, roof)
	k.box(Vector3(-0.2, 0.08, 0.18), Vector3(0.1, 0.12, 0.08), Color("#b89a6a"), Color("#c8aa7a")) # rice bin
	return k.commit()

static func castle(roof: Color, wall: Color, wall2: Color) -> ArrayMesh:
	var k := Kit.new()
	var h := 0.24
	k.box(Vector3(0, 0.02, 0), Vector3(0.86, 0.04, 0.86), wall2.darkened(0.2))
	k.box(Vector3(0, h / 2, -0.34), Vector3(0.8, h, 0.1), wall2, wall)
	k.box(Vector3(-0.35, h / 2, 0), Vector3(0.1, h, 0.78), wall2, wall)
	k.box(Vector3(0.35, h / 2, 0), Vector3(0.1, h, 0.78), wall2, wall)
	k.box(Vector3(-0.23, h / 2, 0.34), Vector3(0.34, h, 0.1), wall2, wall)
	k.box(Vector3(0.23, h / 2, 0.34), Vector3(0.34, h, 0.1), wall2, wall)
	for i in 4: # crenellations
		var t := -0.3 + 0.2 * i
		k.box(Vector3(t, h + 0.03, -0.34), Vector3(0.08, 0.06, 0.11), wall)
		k.box(Vector3(-0.35, h + 0.03, t), Vector3(0.11, 0.06, 0.08), wall)
		k.box(Vector3(0.35, h + 0.03, t), Vector3(0.11, 0.06, 0.08), wall)
	# gate tower over the front (camera side) wall
	k.box(Vector3(0, 0.2, 0.34), Vector3(0.22, 0.4, 0.16), wall, wall)
	k.box(Vector3(0, 0.09, 0.42), Vector3(0.1, 0.16, 0.01), DARK)
	k.roof(Vector3(0, 0.4, 0.34), 0.34, 0.26, 0.14, roof)
	k.box(Vector3(0, 0.08, -0.02), Vector3(0.36, 0.16, 0.3), wall.darkened(0.1)) # keep inside
	k.roof(Vector3(0, 0.16, -0.02), 0.44, 0.38, 0.13, roof.darkened(0.1))
	k.cyl(Vector3(0.0, 0.54, 0.34), 0.012, 0.012, 0.32, DARK, 5) # flag pole
	return k.commit()

static func flag(col: Color) -> ArrayMesh:
	var k := Kit.new()
	k.box(Vector3(0.11, 0, 0), Vector3(0.22, 0.12, 0.012), col)
	return k.commit()

## fallen soldier: earth mound, planted spear with a red cloth, dropped shield
static func grave() -> ArrayMesh:
	var k := Kit.new()
	k.xf = Transform3D(Basis().scaled(Vector3(1, 0.35, 0.8)), Vector3(-0.04, 0, 0))
	k.ball(Vector3.ZERO, 0.2, Color("#6b5a40"), 8, 4)
	k.xf = Transform3D(Basis(Vector3.BACK, -0.15), Vector3(0.12, 0, -0.05))
	k.cyl(Vector3.ZERO, 0.013, 0.013, 0.55, WOOD, 5)
	k.cone(Vector3(0, 0.55, 0), 0.026, 0.08, METAL, 5)
	k.box(Vector3(0.06, 0.44, 0), Vector3(0.1, 0.08, 0.01), Color("#b8322a"))
	k.xf = Transform3D(Basis(Vector3.RIGHT, -1.25), Vector3(-0.1, 0.05, 0.1))
	k.cyl(Vector3.ZERO, 0.1, 0.1, 0.02, WOOD2, 10, Color("#c9a35e"))
	k.xf = Transform3D.IDENTITY
	return k.commit()
