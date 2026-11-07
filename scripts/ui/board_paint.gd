class_name BoardPaint
extends RefCounted
## Board part: terrain painting (cached bake: tiles / SVG art, roads, shore, grid, static buildings), water mask,
## building / goal / grave drawing (static + per-frame), raster cache. Reads / calls the board (bd) directly.

var bd: Board
var art_tex := { } # "path@texels" -> terrain / building raster, kept here so a close-up bake never re-rasterises

func _init(host: Board) -> void:
	bd = host

## art set (Token.fig_style, e.g. chibi): SVG tiles in assets/terrain/<style>/ replace the procedural terrain
func art_path(art_id: String) -> String:
	if Token.fig_style == "":
		return ""
	var p := "res://assets/terrain/%s/%s.svg" % [Token.fig_style, art_id]
	return p if Token.exists(p) else ""

## tile x, y -> its art file (two looks per kind, picked by position); "" = no art for it
func _tile_art(t: String, x: int, y: int) -> String:
	var ab := "_a" if Board.hash01(x, y, 11) < 0.5 else "_b"
	var base: String = {
		".": "grass",
		"r": "grass",
		"v": "grass",
		"c": "grass",
		"x": "grass",
		"t": "grass",
		"f": "forest",
		"h": "hill",
		"m": "mountain",
	}.get(t, "")
	if base != "":
		var p := art_path(base + ab)
		return p if p != "" else art_path(base + "_a")
	var other: String = { "~": "water", "=": "bridge" }.get(t, "-")
	return art_path(other)

## an SVG drawn over tile x, y (rasterised at the on-screen size), turned by rot around the tile centre
func _art_draw(ci: CanvasItem, path: String, x: int, y: int, rot := 0.0) -> bool:
	var tex := _art_raster(path, bd.T * Baked.screen_scale(ci))
	if tex == null:
		return false
	if rot == 0.0:
		ci.draw_texture_rect(tex, Rect2(x * bd.T, y * bd.T, bd.T, bd.T), false)
	else:
		ci.draw_set_transform(Vector2((x + 0.5) * bd.T, (y + 0.5) * bd.T), rot)
		ci.draw_texture_rect(tex, Rect2(-bd.T / 2.0, -bd.T / 2.0, bd.T, bd.T), false)
		ci.draw_set_transform_matrix(Draw.xf)
	return true

func _art_raster(path: String, px: float) -> Texture2D:
	var key := "%s@%d" % [path, Token.bucket(px)]
	if not art_tex.has(key):
		art_tex[key] = Token.raster(path, px)
	return art_tex[key]

## rasterise the close-up's terrain, building and figure art ahead (~60 SVGs): the first zoom then has no stall
func warm_hi_art() -> void:
	for side: String in ["p", "e"]:
		for type: String in Content.theme().units[side]:
			Token.warm(bd.T, side, type, bd._zoom_rs())
	var px := bd.T * bd._hi_scale()
	var sw: int = bd.s.w
	var sh: int = bd.s.h
	for y: int in sh:
		for x: int in sw:
			var t: String = bd.s.tiles[y][x]
			var ap := _tile_art(t, x, y)
			if ap != "":
				_art_raster(ap, px)
	for b: Array in _bld_list():
		var bt: String = b[0]
		var own: String = b[3]
		var ap := _bld_art(bt, own)
		if ap != "":
			_art_raster(ap, px)

func _bridge_horiz(x: int, y: int) -> bool:
	return (Game.tile_at(bd.s, x - 1, y) != "~" or Game.tile_at(bd.s, x + 1, y) != "~") and Game.tile_at(bd.s, x, y - 1) == "~"

func draw_terrain(ci: CanvasItem) -> void:
	if bd.s.is_empty():
		return
	var art := art_path("grass_a") != ""
	var sw: int = bd.s.w
	var sh: int = bd.s.h
	for y: int in sh:
		for x: int in sw:
			var t: String = bd.s.tiles[y][x]
			var p: Dictionary = Content.terrain(t)
			var ap := _tile_art(t, x, y) if art else ""
			if ap != "" and _art_draw(ci, ap, x, y, PI / 2.0 if t == "=" and _bridge_horiz(x, y) else 0.0):
				continue
			var tex := Token.image(p.get("img"))
			if tex:
				ci.draw_texture_rect(tex, Rect2(x * bd.T, y * bd.T, bd.T, bd.T), false)
			else:
				var kind: String = p.paint
				_paint(ci, kind, x * bd.T, y * bd.T, p, x, y)
	_draw_roads(ci)
	# shorelines: sand on land edges touching water
	for y: int in sh:
		for x: int in sw:
			var t: String = bd.s.tiles[y][x]
			var rt: Dictionary = Rules.TERRAIN[t]
			if rt.get("water", false) or t == "=":
				continue
			var X: float = x * bd.T
			var Y: float = y * bd.T
			var w := bd.T * 0.12
			var sand := Color("#e3cf9a", 0.85) if art else Color(0.788, 0.718, 0.541, 0.53)
			if Game.tile_at(bd.s, x + 1, y) == "~":
				ci.draw_rect(Rect2(X + bd.T - w, Y, w, bd.T), sand)
			if Game.tile_at(bd.s, x - 1, y) == "~":
				ci.draw_rect(Rect2(X, Y, w, bd.T), sand)
			if Game.tile_at(bd.s, x, y + 1) == "~":
				ci.draw_rect(Rect2(X, Y + bd.T - w, bd.T, w), sand)
			if Game.tile_at(bd.s, x, y - 1) == "~":
				ci.draw_rect(Rect2(X, Y, bd.T, w), sand)
	# soft grid
	var gc := Color(0, 0, 0, 0.13)
	for x in range(1, sw):
		ci.draw_line(Vector2(x * bd.T + 0.5, 0), Vector2(x * bd.T + 0.5, sh * bd.T), gc, 1.0)
	for y in range(1, sh):
		ci.draw_line(Vector2(0, y * bd.T + 0.5), Vector2(sw * bd.T, y * bd.T + 0.5), gc, 1.0)
	_draw_static_buildings(ci)

## buildings with art are static: baked here (re-baked when an owner / tile / held tile changes, see _process)
func _draw_static_buildings(ci: CanvasItem) -> void:
	for b: Array in _bld_list():
		var t: String = b[0]
		var x: int = b[1]
		var y: int = b[2]
		var own: String = b[3]
		var ap := _bld_art(t, own)
		if ap != "" and not _art_draw(ci, ap, x, y):
			draw_building(ci, t, x * bd.T, y * bd.T, own, 0.0, x, y)

## [t, x, y, owner] of every building as shown now (a raze / repair keeps the old tile until its event plays)
func _bld_list() -> Array:
	var out := []
	var sw: int = bd.s.w
	var sh: int = bd.s.h
	var owners: Dictionary = bd.s.owner
	var hold: Dictionary = bd.view.hold
	for y: int in sh:
		for x: int in sw:
			var t: String = bd.s.tiles[y][x]
			var own: String = owners.get(Vector2i(x, y), "n")
			var held: Variant = hold.get(Vector2i(x, y)) # [tile, owner] shown until its event plays (raze / repair)
			if held != null:
				t = held[0]
				own = held[1] if held[1] != null else "n"
			if t == "v" or t == "c" or t == "x" or t == "t":
				out.append([t, x, y, own])
	return out

func _bld_art(t: String, own: String) -> String:
	return art_path("temple" if t == "t" else ("village_x" if t == "x" else "%s_%s" % ["village" if t == "v" else "castle", own]))

func prep_buildings() -> void:
	bd._live_bld = _bld_list().filter(
		func(b: Array) -> bool:
			var t: String = b[0]
			var own: String = b[3]
			return _bld_art(t, own) == "",
	)

## water mask for shaders/water.gdshader: r = water tile, g / b = its sparkle spot
func update_water_mask() -> void:
	var sw: int = bd.s.w
	var sh: int = bd.s.h
	var img := Image.create(sw, sh, false, Image.FORMAT_RGBA8) # 8-bit: sparkle spot off by < 0.2 px, safe on every GPU
	var any := false
	for y: int in sh:
		for x: int in sw:
			var w: bool = bd.s.tiles[y][x] == "~"
			any = any or w
			img.set_pixel(x, y, Color(1.0 if w else 0.0, Board.hash01(x, y, 3), Board.hash01(x, y, 4), 1.0))
	bd._water.visible = any
	var m: ShaderMaterial = bd._water.material
	m.set_shader_parameter("mask", ImageTexture.create_from_image(img))
	m.set_shader_parameter("tile", bd.T)
	m.set_shader_parameter("width", maxf(1.0, bd.T / 28.0))

## dirt tracks: every path tile joins its path / village / castle / bridge neighbours with a worn band (two tones +
## pebbles), so the roads read as one network leading to the buildings and over the bridges
func _draw_roads(ci: CanvasItem) -> void:
	var p: Dictionary = Content.terrain("r")
	if art_path("grass_a") != "":
		p = p.merged({ "dirt": Color("#d2b07a"), "dirt2": Color("#b48e58"), "pebble": Color("#e9d9ad") }, true)
	# how far from this tile's centre the band runs toward each kind of neighbour (tile units):
	# path -> the shared edge (the neighbour draws its own half), village / castle -> up to the building, bridge -> onto the planks
	var links := { "r": 0.5, "v": 1.0, "c": 1.0, "x": 1.0, "t": 1.0, "=": 0.62 }
	var w := bd.T * 0.30
	var sw: int = bd.s.w
	var sh: int = bd.s.h
	for pass_i in 2:
		var col := Draw.to_col(p.dirt2) if pass_i == 0 else Draw.to_col(p.dirt)
		var ww := w + (bd.T * 0.07 if pass_i == 0 else 0.0)
		for y: int in sh:
			for x: int in sw:
				if bd.s.tiles[y][x] != "r":
					continue
				var c := Vector2((x + 0.5) * bd.T, (y + 0.5) * bd.T)
				ci.draw_circle(c, ww / 2, col)
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nt: Variant = Game.tile_at(bd.s, x + d.x, y + d.y)
					if nt == null or not links.has(nt):
						continue
					var reach: float = links[nt]
					var e := c + Vector2(d) * bd.T * reach
					ci.draw_line(c, e, col, ww)
					if nt != "r":
						ci.draw_circle(e, ww / 2, col)
	var pebble := Color(Draw.to_col(p.pebble), 0.8)
	for y: int in sh:
		for x: int in sw:
			if bd.s.tiles[y][x] != "r":
				continue
			for i in 4:
				var q := Vector2((x + 0.3 + Board.hash01(x, y, i + 40) * 0.4) * bd.T, (y + 0.3 + Board.hash01(x, y, i + 50) * 0.4) * bd.T)
				ci.draw_circle(q, maxf(1.0, bd.T * 0.018), pebble)

## polygon filled with a linear gradient from p0 (c0) to p1 (c1)
static func _grad_poly(ci: CanvasItem, pts: PackedVector2Array, p0: Vector2, p1: Vector2, c0: Color, c1: Color) -> void:
	var axis := p1 - p0
	var len2 := axis.length_squared()
	var cols := PackedColorArray()
	for p in pts:
		cols.append(c0.lerp(c1, clampf((p - p0).dot(axis) / len2, 0.0, 1.0)))
	ci.draw_polygon(pts, cols)

func _paint(ci: CanvasItem, kind: String, X: float, Y: float, p: Dictionary, x: int, y: int) -> void:
	match kind:
		"road":
			ci.draw_rect(Rect2(X, Y, bd.T, bd.T), Draw.to_col(p.base)) # grass under the track (_draw_roads paints the dirt)
			for i in 4:
				ci.draw_rect(
					Rect2(X + Board.hash01(x, y, i) * bd.T, Y + Board.hash01(x, y, i + 20) * bd.T, maxf(1.0, bd.T / 30.0), maxf(2.0, bd.T / 14.0)),
					Board.GRASS_A if Board.hash01(x, y, i + 9) > 0.5 else Board.GRASS_B,
				)
		"field", "village":
			ci.draw_rect(Rect2(X, Y, bd.T, bd.T), Draw.to_col(p.base))
			for i in range(1, 5):
				var yy := Y + bd.T * i / 5.0
				ci.draw_polyline(
					Draw.quad(
						Vector2(X + 2, yy),
						Vector2(X + bd.T / 2, yy + (Board.hash01(x, y, i) - 0.5) * bd.T * 0.12),
						Vector2(X + bd.T - 2, yy),
						8,
					),
					Draw.to_col(p.line),
					maxf(1.0, bd.T / 40.0),
					true,
				)
			for i in 6:
				ci.draw_rect(
					Rect2(X + Board.hash01(x, y, i) * bd.T, Y + Board.hash01(x, y, i + 20) * bd.T, maxf(1.0, bd.T / 30.0), maxf(2.0, bd.T / 14.0)),
					Board.GRASS_A if Board.hash01(x, y, i + 9) > 0.5 else Board.GRASS_B,
				)
		"forest":
			ci.draw_rect(Rect2(X, Y, bd.T, bd.T), Draw.to_col(p.base))
			var trees := [[0.25, 0.42], [0.72, 0.38], [0.5, 0.68], [0.2, 0.86], [0.8, 0.84]]
			for i in trees.size():
				var cx: float = X + bd.T * (trees[i][0] + (Board.hash01(x, y, i) - 0.5) * 0.08)
				var by: float = Y + bd.T * trees[i][1]
				var h := bd.T * (0.36 + Board.hash01(x, y, i + 5) * 0.1)
				Draw.ellipse(ci, Vector2(cx + bd.T * 0.04, by + bd.T * 0.02), h * 0.38, h * 0.12, Color(0, 0, 0, 0.2), 0.0, 14)
				ci.draw_rect(Rect2(cx - bd.T * 0.015, by - h * 0.15, bd.T * 0.03, h * 0.18), Board.TRUNK)
				ci.draw_colored_polygon(
					PackedVector2Array([Vector2(cx, by - h), Vector2(cx - h * 0.36, by - h * 0.12), Vector2(cx + h * 0.36, by - h * 0.12)]),
					Draw.to_col(p.tree),
				)
				ci.draw_colored_polygon(
					PackedVector2Array([Vector2(cx, by - h), Vector2(cx - h * 0.05, by - h * 0.12), Vector2(cx + h * 0.36, by - h * 0.12)]),
					Draw.to_col(p.tree2),
				)
		"hill":
			ci.draw_rect(Rect2(X, Y, bd.T, bd.T), Draw.to_col(p.base))
			for m: Array in [[0.36, 0.8, 0.34, 0.36], [0.7, 0.86, 0.26, 0.26]]:
				var mx: float = m[0]
				var my: float = m[1]
				var c := Vector2(X + bd.T * mx, Y + bd.T * my)
				var rx: float = bd.T * m[2]
				var ry: float = bd.T * m[3]
				_grad_poly(
					ci,
					Draw.arc_points(c, rx, ry, PI, TAU, 0.0, 18),
					c - Vector2(rx, ry),
					c + Vector2(rx, 0),
					Draw.to_col(p.hill2),
					Draw.to_col(p.hill),
				)
		"mountain":
			ci.draw_rect(Rect2(X, Y, bd.T, bd.T), Draw.to_col(p.base))
			for pk: Array in [[0.32, 0.3, 0.55], [0.62, 0.36, 0.82]]:
				var px: float = pk[0]
				var w: float = pk[1]
				var h: float = pk[2]
				ci.draw_colored_polygon(
					PackedVector2Array([_at(X, Y, px - w, 0.92), _at(X, Y, px, 0.92 - h), _at(X, Y, px + w, 0.92)]),
					Draw.to_col(p.rock),
				)
				ci.draw_colored_polygon(
					PackedVector2Array([_at(X, Y, px, 0.92 - h), _at(X, Y, px + w, 0.92), _at(X, Y, px + w * 0.2, 0.92)]),
					Draw.to_col(p.rock2),
				)
				ci.draw_colored_polygon(
					PackedVector2Array(
						[
							_at(X, Y, px - w * 0.28, 0.92 - h * 0.72),
							_at(X, Y, px, 0.92 - h),
							_at(X, Y, px + w * 0.28, 0.92 - h * 0.72),
							_at(X, Y, px, 0.92 - h * 0.62),
						]
					),
					Draw.to_col(p.snow),
				)
		"water":
			Draw.gradient_rect(ci, Rect2(X, Y, bd.T, bd.T), [[0.0, Draw.to_col(p.base)], [1.0, Draw.to_col(p.get("deep", p.base))]])
		"bridge":
			Draw.gradient_rect(ci, Rect2(X, Y, bd.T, bd.T), [[0.0, Draw.to_col(p.base)], [1.0, Draw.to_col(p.get("deep", p.base))]])
			var horiz: bool = (Game.tile_at(bd.s, x - 1, y) != "~" or Game.tile_at(bd.s, x + 1, y) != "~") and Game.tile_at(bd.s, x, y - 1) == "~"
			if horiz:
				ci.draw_rect(Rect2(X, Y + bd.T * 0.22, bd.T, bd.T * 0.62), Color(0, 0, 0, 0.27))
				ci.draw_rect(Rect2(X, Y + bd.T * 0.18, bd.T, bd.T * 0.6), Draw.to_col(p.plank))
			else:
				ci.draw_rect(Rect2(X + bd.T * 0.18, Y, bd.T * 0.68, bd.T), Color(0, 0, 0, 0.27))
				ci.draw_rect(Rect2(X + bd.T * 0.14, Y, bd.T * 0.68, bd.T), Draw.to_col(p.plank))
			for i in range(1, 7):
				if horiz:
					ci.draw_line(
						Vector2(X + bd.T * i / 7.0, Y + bd.T * 0.18),
						Vector2(X + bd.T * i / 7.0, Y + bd.T * 0.78),
						Draw.to_col(p.plank2),
						maxf(1.0, bd.T / 40.0),
					)
				else:
					ci.draw_line(
						Vector2(X + bd.T * 0.14, Y + bd.T * i / 7.0),
						Vector2(X + bd.T * 0.82, Y + bd.T * i / 7.0),
						Draw.to_col(p.plank2),
						maxf(1.0, bd.T / 40.0),
					)
		"castle":
			ci.draw_rect(Rect2(X, Y, bd.T, bd.T), Draw.to_col(p.base))
			ci.draw_rect(Rect2(X + bd.T * 0.06, Y + bd.T * 0.08, bd.T * 0.88, bd.T * 0.86), Color(0, 0, 0, 0.13))

static func _join(parts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: PackedVector2Array in parts:
		for i in p.size():
			if out.size() and out[out.size() - 1].is_equal_approx(p[i]):
				continue
			out.append(p[i])
	return out

## point (a, b) tiles into the tile whose top-left is X, Y
func _at(X: float, Y: float, a: float, b: float) -> Vector2:
	return Vector2(X + bd.T * a, Y + bd.T * b)

## procedural building (no art set): the castle flag waves, so these stay in the per-frame layer
func draw_building(ci: CanvasItem, t: String, X: float, Y: float, own: String, time: float, x: int, y: int) -> void:
	if t == "t": # shrine without the art set: drawn as a neutral village
		t = "v"
		own = "n"
	var pal := Draw.pal()
	var facs: Dictionary = pal.factions
	var fac: Dictionary = facs.get(own, facs.n)
	var p: Dictionary = pal.terrain[t]
	var roof_col: Color = fac.get("roof", Color.BLACK) # only v / c read it
	if t == "x": # ruined village (no art set): broken wall stubs + rubble
		var ruin: Color = p.wall
		Draw.ellipse(ci, _at(X, Y, 0.52, 0.84), bd.T * 0.34, bd.T * 0.08, Color(0, 0, 0, 0.22))
		ci.draw_rect(Rect2(_at(X, Y, 0.26, 0.62), Vector2(bd.T * 0.14, bd.T * 0.2)), ruin)
		ci.draw_rect(Rect2(_at(X, Y, 0.6, 0.68), Vector2(bd.T * 0.16, bd.T * 0.14)), ruin)
		for i in 5:
			ci.draw_circle(_at(X, Y, 0.3 + Board.hash01(x, y, i) * 0.45, 0.78 + Board.hash01(x, y, i + 9) * 0.1), bd.T * 0.035, Color("#8a8073"))
		return
	if t == "v":
		Draw.ellipse(ci, _at(X, Y, 0.52, 0.84), bd.T * 0.34, bd.T * 0.08, Color(0, 0, 0, 0.27))
		var wall: Color = p.wall
		ci.draw_rect(Rect2(_at(X, Y, 0.26, 0.5), Vector2(bd.T * 0.5, bd.T * 0.32)), wall)
		ci.draw_rect(Rect2(_at(X, Y, 0.46, 0.62), Vector2(bd.T * 0.1, bd.T * 0.2)), Board.DOOR)
		# straight gable roof (cottage)
		var roof := PackedVector2Array([_at(X, Y, 0.16, 0.54), _at(X, Y, 0.34, 0.28), _at(X, Y, 0.68, 0.28), _at(X, Y, 0.88, 0.54)])
		ci.draw_colored_polygon(roof, roof_col)
		ci.draw_rect(Rect2(_at(X, Y, 0.2, 0.5), Vector2(bd.T * 0.64, bd.T * 0.04)), Color(0, 0, 0, 0.2))
		if own != "n":
			Draw.glow(ci, _at(X, Y, 0.51, 0.72), bd.T * 0.12, Color(1, 0.85, 0.54, 0.8))
	elif t == "c":
		var wall: Color = p.wall
		var wall2: Color = p.wall2
		ci.draw_rect(Rect2(_at(X, Y, 0.12, 0.42), Vector2(bd.T * 0.76, bd.T * 0.46)), wall2)
		ci.draw_rect(Rect2(_at(X, Y, 0.12, 0.42), Vector2(bd.T * 0.76, bd.T * 0.06)), wall)
		for i in 4:
			ci.draw_rect(Rect2(_at(X, Y, 0.12 + 0.21 * i, 0.32), Vector2(bd.T * 0.13, bd.T * 0.12)), wall)
		# gate tower roof: straight cone
		var roof := PackedVector2Array([_at(X, Y, 0.28, 0.34), _at(X, Y, 0.5, 0.14), _at(X, Y, 0.72, 0.34)])
		ci.draw_colored_polygon(roof, roof_col)
		ci.draw_colored_polygon(Draw.arc_points(_at(X, Y, 0.5, 0.88), bd.T * 0.14, bd.T * 0.14, PI, TAU, 0.0, 12), Board.GATE)
		# flag
		var wave := sin(time / 260.0 + x + y) * bd.T * 0.03
		ci.draw_line(_at(X, Y, 0.5, 0.18), _at(X, Y, 0.5, -0.06), Board.POLE, maxf(1.0, bd.T / 30.0))
		var flag_col: Color = Board.FLAG_N if own == "n" else fac.glow
		var top: Vector2 = _at(X, Y, 0.5, -0.06)
		var tip := Vector2(X + bd.T * 0.8, Y + wave * 1.5)
		var flag := _join(
			[
				Draw.quad(top, Vector2(X + bd.T * 0.64, Y - bd.T * 0.06 + wave), tip, 6),
				Draw.quad(tip, Vector2(X + bd.T * 0.64, Y + bd.T * 0.06 + wave), _at(X, Y, 0.5, 0.08), 6),
			]
		)
		ci.draw_colored_polygon(flag, flag_col)

## objective goal tile (Objectives.marks): pulsing gold frame + a tall gold banner
func draw_goal(ci: CanvasItem, X: float, Y: float, time: float) -> void:
	var pulse := 0.5 + 0.5 * sin(time / 300.0)
	ci.draw_rect(Rect2(X + 2, Y + 2, bd.T - 4, bd.T - 4), Color(1, 0.84, 0.4, 0.12 + 0.12 * pulse))
	ci.draw_rect(Rect2(X + 2, Y + 2, bd.T - 4, bd.T - 4), Color(1, 0.84, 0.4, 0.6 + 0.4 * pulse), false, maxf(2.0, bd.T * 0.06))
	var wave := sin(time / 240.0) * bd.T * 0.03
	ci.draw_line(Vector2(X + bd.T * 0.22, Y + bd.T * 0.92), Vector2(X + bd.T * 0.22, Y + bd.T * 0.08), Board.POLE, maxf(1.5, bd.T / 26.0))
	ci.draw_colored_polygon(
		PackedVector2Array(
			[Vector2(X + bd.T * 0.22, Y + bd.T * 0.08), Vector2(X + bd.T * 0.5, Y + bd.T * 0.14 + wave), Vector2(X + bd.T * 0.22, Y + bd.T * 0.28)]
		),
		Board.GOAL,
	)

## fallen soldier: spear planted in the ground, dropped round shield, slow breathing red cloth
func draw_grave(ci: CanvasItem, X: float, Y: float, time: float) -> void:
	Draw.ellipse(ci, _at(X, Y, 0.5, 0.8), bd.T * 0.32, bd.T * 0.1, Color(0, 0, 0, 0.33))
	ci.draw_line(_at(X, Y, 0.62, 0.8), _at(X, Y, 0.7, 0.18), Board.SPEAR, maxf(1.5, bd.T / 22.0), true)
	ci.draw_colored_polygon(PackedVector2Array([_at(X, Y, 0.705, 0.06), _at(X, Y, 0.745, 0.2), _at(X, Y, 0.67, 0.19)]), Board.BLADE)
	var sway := sin(time / 520.0) * bd.T * 0.03
	var cloth := _join(
		[
			PackedVector2Array([_at(X, Y, 0.69, 0.24)]),
			Draw.quad(_at(X, Y, 0.69, 0.24), Vector2(X + bd.T * 0.82 + sway, Y + bd.T * 0.28), Vector2(X + bd.T * 0.86 + sway, Y + bd.T * 0.38), 6),
			PackedVector2Array([_at(X, Y, 0.68, 0.34)]),
		]
	)
	ci.draw_colored_polygon(cloth, Board.CLOTH)
	Draw.ellipse(ci, _at(X, Y, 0.4, 0.7), bd.T * 0.2, bd.T * 0.11, Board.SHIELD, -0.2)
	Draw.ellipse_line(ci, _at(X, Y, 0.4, 0.7), bd.T * 0.13, bd.T * 0.07, Board.SHIELD_RIM, maxf(1.0, bd.T / 36.0), -0.2, 20)
	ci.draw_circle(_at(X, Y, 0.4, 0.7), bd.T * 0.03, Board.SHIELD_RIM)
	ci.draw_circle(_at(X, Y, 0.5, 0.62), bd.T * 0.05, Color(1, 0.86, 0.63, 0.25 + 0.2 * sin(time / 700.0)))
