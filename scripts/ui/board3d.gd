class_name Board3D
extends BoardBase
## tabletop 3D board (Store.board_3d). Same surface as Board (BoardBase + set_state / fit / refresh_terrain /
## tile_rect) and it reads the same view + fx state, so GameScreen's playback (move tweens,
## lunges, flashes, deaths) animates the figurines unchanged.
## Layers: 3D SubViewport shown as one texture (table, terrain mesh, buildings, figurines, flat overlay quads textured
## by a 2D SubViewport painted with Board's own overlay code) | 2D screen layers (fx, hp bars, ⓘ, forecast, numbers).

const PITCH := 45.0 # camera tilt below the horizon, degrees (fixed: no free camera)
const OT := 40.0 # overlay texture px per tile
const FXH := 0.32 # height of the plane fx (sparks, arrows, rocks) are drawn on: mid-body
const TF := 48.0 # nominal tile size fx is painted at (then mapped onto the board)
const MARGIN := 0.55 # table border around the map, tiles
## top of each terrain kind (tiles); figures stand on it
const TOP := { ".": 0.0, "r": 0.0, "v": 0.0, "c": 0.0, "x": 0.0, "t": 0.0, "f": 0.0, "h": 0.12, "m": 0.22, "~": -0.1, "=": 0.0 }
const WATER_Y := -0.05
const FIG := 1.3 # code-built figurine scale (only units KayKit has no model for, e.g. the catapult)
const CHAR := 0.33 # KayKit character scale (~2.4 units tall -> ~0.8 tile)
const W := "assets/kaykit/weapons/"
## unit type -> [KayKit character, [[hand bone, model]], attack clip, scale]. Both sides field the same troops
## (cloth recoloured red / blue); the two commanders differ. Types not listed use the code-built piece.
const ROSTER := {
	"soldier": ["Rogue_Hooded.glb", [["handslot.r", W + "sword_1handed.gltf"], ["handslot.l", W + "shield_round_color.gltf"]],
		"Melee_1H_Attack_Chop", 1.0],
	"archer": ["Ranger.glb", [["handslot.l", W + "bow_withString.gltf"]], "Ranged_Bow_Release", 1.0],
	"drum": ["Rogue.glb", [["handslot.r", "assets/kaykit/hex/decoration/props/flag_%s.gltf"]], "Melee_1H_Attack_Stab", 1.0],
	"shaman": ["Mage.glb", [["handslot.r", W + "staff.gltf"]], "Ranged_Magic_Shoot", 1.0],
	"elephant": ["Barbarian.glb", [["handslot.r", W + "axe_2handed.gltf"]], "Melee_2H_Attack_Chop", 1.12],
	"bird": ["Rogue.glb", [["handslot.r", W + "dagger.gltf"], ["handslot.l", W + "dagger.gltf"]], "Melee_Dualwield_Attack_Chop", 1.0],
	"boat": ["Rogue_Hooded.glb", [["handslot.r", W + "staff.gltf"], ["handslot.l", W + "shield_round_color.gltf"]], "Melee_1H_Attack_Stab", 1.0],
	"wolf": ["Barbarian.glb", [["handslot.r", W + "dagger.gltf"]], "Melee_1H_Attack_Chop", 0.95],
	"ghost": ["Skeleton_Minion.glb", [], "Melee_Unarmed_Attack_Punch_A", 0.95],
	"hero_p": ["Knight.glb", [["handslot.r", W + "sword_1handed.gltf"], ["handslot.l", W + "shield_badge_color.gltf"]], "Melee_1H_Attack_Chop", 1.15],
	"hero_e": ["Skeleton_Warrior.glb", [["handslot.r", W + "Skeleton_Axe.gltf"], ["handslot.l", W + "Skeleton_Shield_Large_A.gltf"]],
		"Melee_1H_Attack_Chop", 1.2],
}
const SITE_COLOR := { "p": "red", "e": "blue", "n": "yellow" }
const SITE_BACK := 0.1 # villages / castles sit at the back of their tile, the unit stands in front
const WOOD_TABLE := Color("#5b3a22")
const WOOD_TABLE2 := Color("#6e4a2c")
const EARTH := Color("#4a3a28")
const SAND := Color("#e0b98a")
## KayKit hexagon texture colours, so the square tiles match the models standing on them
const KK_GRASS := Color("#c0c537")
const KK_GRASS_SIDE := Color("#8a8e0f")
const KK_WATER := Color("#2583c1")
const KK_WATER_DEEP := Color("#1f3d86")
const KK_ROAD := Color("#dfb787")
const KK_ROAD2 := Color("#d4a471")
const WATER_SHADER := preload("res://shaders/water3d.gdshader")

var _flat: Board # never in the tree: paints overlays / buffs / ⓘ / forecast with Board's own code
var _vp: SubViewport
var _cam: Camera3D
var _sun: DirectionalLight3D
var _env: Environment
var _world: Node3D
var _static: MeshInstance3D
var _water: MeshInstance3D
var _overlay: MeshInstance3D
var _ov: SubViewport
var _ov_paint: Baked.Painter
var _top: Control
var _top_add: Control
var _sites := {} # Vector2i -> { "mi", "own", "flag" }
var _graves_key := ""
var _graves := []
var _lights := []
var _pieces := {} # key -> MeshInstance3D (code-built piece) or Node3D (KayKit actor)
var _props := [] # [tile, x, y, top] waiting for their KayKit model (forest, hill, mountain, bridge)
var _anim := {} # key -> { cur, lock, attacking, knock } animation state of a KayKit actor
var _ov_flash: StandardMaterial3D
var _ov_dim: StandardMaterial3D
var _facing := {} # unit id -> yaw
var _last_pos := {} # unit id -> Vector2 (to face the way it walks)
var _shown := [] # this frame's figures: { key, u, x, y, h, ghost_k, off }
var _sc := 1.0
var _built := false
var _base_center := Vector3.ZERO
var _base_size := 10.0
var _focus := 0.0
var _focus_center := Vector3.ZERO
var _focus_size := 4.0
var _mat: StandardMaterial3D
var _mat_dim: StandardMaterial3D
var _mat_flash: StandardMaterial3D
var _night_on := false

func _init() -> void:
	super()
	clip_contents = true
	_flat = Board.new()
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true # theme hex colours are sRGB
	_mat.roughness = 0.9
	_mat_dim = _mat.duplicate()
	_mat_dim.albedo_color = Color(0.45, 0.45, 0.48)
	_ov_flash = StandardMaterial3D.new()
	_ov_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ov_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ov_flash.albedo_color = Color(1, 0.97, 0.9, 0.75)
	_ov_dim = _ov_flash.duplicate()
	_ov_dim.albedo_color = Color(0.05, 0.05, 0.08, 0.5)
	_mat_flash = StandardMaterial3D.new()
	_mat_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_flash.albedo_color = Color(1, 0.97, 0.9)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = false # a transparent 3D viewport skips the linear -> sRGB step in Compatibility (washed-out colours)
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.gui_disable_input = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.rotation_degrees = Vector3(-PITCH, 0, 0)
	_cam.near = 0.05
	_cam.far = 200.0
	_vp.add_child(_cam)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-58, -32, 0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 80.0
	_sun.shadow_bias = 0.03
	_vp.add_child(_sun)
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color("#1a0f0b") # the game screen's backdrop around the table
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 0.95
	we.environment = _env
	_vp.add_child(we)
	_day_light()
	_ov = SubViewport.new()
	_ov.transparent_bg = true
	_ov.disable_3d = true
	_ov.gui_disable_input = true
	_ov.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_ov_paint = Baked.Painter.new()
	_ov_paint.fn = _paint_overlay
	_ov_paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ov.add_child(_ov_paint)
	add_child(_ov)
	_top = _layer(_draw_top)
	_top_add = _layer(_draw_add)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_top_add.material = add
	move_child(_top_add, _top.get_index()) # additive glows under the numbers / hp bars

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_flat):
		_flat.free()

func _layer(fn: Callable) -> Control:
	var l := Board.Layer.new()
	l.fn = fn
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _day_light() -> void:
	_sun.light_color = Color("#fff3e0")
	_sun.light_energy = 0.3
	_env.ambient_light_color = Color("#b8c6e0")
	_env.ambient_light_energy = 0.22

func _night_light() -> void:
	_sun.light_color = Color("#9fb4ff")
	_sun.light_energy = 0.1
	_env.ambient_light_color = Color("#27304f")
	_env.ambient_light_energy = 0.25

# ---------- Board surface ----------
func set_state(state: Dictionary) -> void:
	s = state
	_flat.s = state
	_flat.fx = fx
	_flat.view = view
	_built = false
	for mi: Node in _pieces.values():
		mi.queue_free()
	_pieces.clear()
	_facing.clear()
	_last_pos.clear()

func refresh_terrain() -> void:
	_built = false

func fit(avail: Vector2) -> void:
	if s.is_empty():
		return
	var basis := Basis.from_euler(Vector3(deg_to_rad(-PITCH), 0, 0))
	var inv := basis.inverse()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for x: float in [-MARGIN, s.w + MARGIN]:
		for z: float in [-MARGIN, s.h + MARGIN]:
			for y: float in [-0.5, 1.15]:
				var l := inv * Vector3(x, y, z)
				lo = lo.min(Vector2(l.x, l.y))
				hi = hi.max(Vector2(l.x, l.y))
	var ext := hi - lo
	T = clampf(floorf(minf(avail.x / ext.x, avail.y / ext.y)), 18.0, 120.0)
	var px := (ext * T).floor()
	custom_minimum_size = px
	size = px
	_base_size = ext.y
	var mid := (lo + hi) / 2.0
	_base_center = basis * Vector3(mid.x, mid.y, 0.0)
	for l: Control in [_top, _top_add]:
		l.size = px
	_layout_vp()

func _draw() -> void:
	if not s.is_empty():
		draw_texture_rect(_vp.get_texture(), Rect2(Vector2.ZERO, size), false)

func _layout_vp() -> void:
	_sc = Baked.screen_scale(self)
	_vp.size = Vector2i(maxi(1, roundi(size.x * _sc)), maxi(1, roundi(size.y * _sc)))
	_apply_camera(Vector2.ZERO)
	queue_redraw()

## where the popup / Hết lượt may not go: the tile's projected footprint + its figure, in the parent's coordinates
func tile_rect(x: int, y: int) -> Rect2:
	var h := _top_at(x, y)
	var r := Rect2(_proj(Vector3(x, h, y)), Vector2.ZERO)
	for p: Vector3 in [Vector3(x + 1, h, y), Vector3(x, h, y + 1), Vector3(x + 1, h, y + 1), Vector3(x + 0.5, h + 0.9, y + 0.5)]:
		r = r.expand(_proj(p))
	return Rect2(position + r.position, r.size)

## camera dive onto an exchange (replaces the cut-away duel on this board): awaitable
func focus(a: Vector2i, b: Vector2i) -> void:
	_focus_center = Vector3((a.x + b.x) / 2.0 + 0.5, 0.3, (a.y + b.y) / 2.0 + 0.5)
	_focus_size = clampf(_base_size * 0.42, 3.2, _base_size)
	await _ease_focus(320.0, _focus, 1.0, func(v: float) -> void: _focus = v)

func unfocus() -> void:
	await _ease_focus(280.0, _focus, 0.0, func(v: float) -> void: _focus = v)

func _apply_camera(shake: Vector2) -> void:
	var c := _base_center.lerp(_focus_center, _focus)
	_cam.size = lerpf(_base_size, _focus_size, _focus)
	_cam.position = c + _cam.basis.z * 40.0
	_cam.h_offset = shake.x
	_cam.v_offset = -shake.y

func _proj(p: Vector3) -> Vector2:
	return _cam.unproject_position(p) / _sc

## tile coords (x right, y down the map) on the plane at height hy -> control px
func _ground_xf(hy: float) -> Transform2D:
	var o := _proj(Vector3(0, hy, 0))
	return Transform2D(_proj(Vector3(1, hy, 0)) - o, _proj(Vector3(0, hy, 1)) - o, o)

func _zoom() -> float:
	return _base_size / maxf(0.01, _cam.size)

func _top_at(x: int, y: int) -> float:
	var t: Variant = Game.tile_at(s, x, y)
	return TOP.get(t, 0.0) if t != null else 0.0

## where a figure's feet are: water walkers wade at the surface, bridges carry them on the planks
func _stand(x: int, y: int) -> float:
	var t: Variant = Game.tile_at(s, x, y)
	if t == "~":
		return WATER_Y - 0.02
	if t == "=":
		return 0.12
	return _top_at(x, y)

# ---------- input ----------
func _pick(p: Vector2) -> Variant:
	var q := p * _sc
	var o := _cam.project_ray_origin(q)
	var d := _cam.project_ray_normal(q)
	if absf(d.y) < 1e-4:
		return null
	var best: Variant = null
	var best_t := INF
	for lvl: float in [0.22, 0.12, 0.0, -0.1]:
		var t := (lvl - o.y) / d.y
		if t <= 0.0 or t >= best_t:
			continue
		var hit := o + d * t
		var tx := floori(hit.x)
		var ty := floori(hit.z)
		if Game.tile_at(s, tx, ty) != null and is_equal_approx(_top_at(tx, ty), lvl):
			best = Vector2i(tx, ty)
			best_t = t
	return best

func _info_at(p: Vector2) -> int:
	return _flat._info_at(p)

# ---------- per frame ----------
func _process(dt: float) -> void:
	if s.is_empty() or not is_visible_in_tree():
		return
	var t := FX.now()
	fx.update(t) # projectiles finish on this (playback awaits them)
	if not _built:
		_build_world()
	if not is_equal_approx(Baked.screen_scale(self), _sc):
		_layout_vp()
	_apply_camera(fx.shake_offset(t))
	_sync_sites(t)
	_sync_graves()
	_collect(t, dt)
	_sync_pieces(t)
	if s.night != _night_on:
		_night_on = s.night
		if s.night:
			_night_light()
		else:
			_day_light()
	if s.night:
		_sync_lights()
	_ov_paint.queue_redraw()
	_top.queue_redraw()
	_top_add.queue_redraw()

# ---------- world ----------
func _build_world() -> void:
	_built = true
	for n: Node in _world.get_children():
		n.queue_free()
	_sites.clear()
	_graves.clear()
	_graves_key = ""
	_lights.clear()
	_pieces.clear()
	var pal := Draw.pal()
	var k := Kit.new()
	var sw: int = s.w
	var sh: int = s.h
	var cx: float = sw / 2.0
	var cz: float = sh / 2.0
	k.box(Vector3(cx, -0.46, cz), Vector3(sw + MARGIN * 2.0, 0.12, sh + MARGIN * 2.0), WOOD_TABLE, WOOD_TABLE2)
	k.box(Vector3(cx, -0.28, cz), Vector3(sw + 0.06, 0.24, sh + 0.06), KK_GRASS_SIDE.darkened(0.2))
	var water := Kit.new()
	var ter: Dictionary = pal.terrain
	for y: int in sh:
		for x: int in sw:
			var tt: String = s.tiles[y][x]
			_tile_mesh(k, water, tt, x, y, ter)
	for pr: Array in _props:
		var pt: String = pr[0]
		var px: int = pr[1]
		var py: int = pr[2]
		var ptop: float = pr[3]
		_place_prop(pt, px, py, ptop)
	_props.clear()
	_static = _mi(k.commit(), _mat)
	_static.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var wm := ShaderMaterial.new()
	wm.shader = WATER_SHADER
	_water = _mi(water.commit(), wm)
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# flat overlay quads on every tile top, textured by the overlay viewport
	_ov.size = Vector2i(int(sw * OT), int(sh * OT))
	_ov_paint.size = Vector2(sw * OT, sh * OT)
	var ok := Kit.new(true)
	for y: int in sh:
		for x: int in sw:
			var t: String = s.tiles[y][x]
			var h := (WATER_Y + 0.025) if t == "~" else (0.135 if t == "=" else _top_at(x, y) + 0.008)
			var u0 := Vector2(float(x) / sw, float(y) / sh)
			var u1 := Vector2(float(x + 1) / sw, float(y + 1) / sh)
			ok.uv_quad(Vector3(x, h, y), Vector3(x, h, y + 1), Vector3(x + 1, h, y + 1), Vector3(x + 1, h, y),
				[u0, Vector2(u0.x, u1.y), u1, Vector2(u1.x, u0.y)])
	var om := StandardMaterial3D.new()
	om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	om.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	om.cull_mode = BaseMaterial3D.CULL_DISABLED
	om.albedo_texture = _ov.get_texture()
	om.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_overlay = _mi(ok.commit(), om)
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	_world.add_child(mi)
	return mi

func _tile_mesh(k: Kit, water: Kit, t: String, x: int, y: int, ter: Dictionary) -> void:
	var top := _top_at(x, y)
	var X := x + 0.5
	var Z := y + 0.5
	var j := (Board.hash01(x, y, 7) - 0.5) * 0.05
	var base: Color = KK_GRASS
	base = base.lightened(j) if j > 0 else base.darkened(-j)
	var wet := t == "~" or t == "="
	# sides buried against an equal-or-taller neighbour are dropped: they z-fight through the shared edge (1 px seams)
	var skip := []
	for d: Vector3 in [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]:
		var nt: Variant = Game.tile_at(s, x + int(d.x), y + int(d.z))
		if nt != null and (nt == "~" or nt == "=") == wet and (wet or _top_at(x + int(d.x), y + int(d.z)) >= top):
			skip.append(d)
	if wet:
		k.box(Vector3(X, (-0.16 - 0.4) / 2.0, Z), Vector3(1, 0.24, 1), KK_WATER_DEEP.darkened(0.3), KK_WATER_DEEP, false, skip)
		for i in 2:
			for jj in 2:
				var a := Vector3(x + i * 0.5, WATER_Y, y + jj * 0.5)
				water.quad(a, a + Vector3(0, 0, 0.5), a + Vector3(0.5, 0, 0.5), a + Vector3(0.5, 0, 0), KK_WATER, Vector3.UP)
	else:
		k.box(Vector3(X, (top - 0.4) / 2.0, Z), Vector3(1, top + 0.4, 1), KK_GRASS_SIDE, base, false, skip)
		_shore(k, x, y, top)
	match t:
		".", "v", "c", "x", "t":
			for i in 5:
				var q := Vector3(x + 0.1 + Board.hash01(x, y, i) * 0.8, top, y + 0.1 + Board.hash01(x, y, i + 20) * 0.8)
				k.cone(q, 0.022, 0.05 + Board.hash01(x, y, i + 9) * 0.04, KK_GRASS_SIDE if Board.hash01(x, y, i + 9) > 0.5 else KK_GRASS.darkened(0.15), 4)
		"r":
			var road: Dictionary = ter.r
			_road(k, x, y, road)
		"f", "h", "m", "=":
			_props.append([t, x, y, top])

## KayKit scenery: tree clumps, rolling hills, grassy peaks, a plank bridge across the river
func _place_prop(t: String, x: int, y: int, top: float) -> void:
	var ab := "A" if Board.hash01(x, y, 1) < 0.5 else "B"
	var path := ""
	var fit_k := 1.0
	var max_h := 0.0 # height cap, tiles: tall scenery must not hide the row behind
	match t:
		"f":
			path = "hex/decoration/nature/trees_%s_%s.gltf" % [ab, "large" if Board.hash01(x, y, 2) < 0.5 else "medium"]
			fit_k = 1.05
			max_h = 0.55
		"h":
			path = "hex/decoration/nature/hills_%s%s.gltf" % [["A", "B", "C"][int(Board.hash01(x, y, 3) * 3.0) % 3],
				"_trees" if Board.hash01(x, y, 4) < 0.35 else ""]
			fit_k = 1.0
		"m":
			path = "hex/decoration/nature/mountain_%s_grass%s.gltf" % [["A", "B", "C"][int(Board.hash01(x, y, 5) * 3.0) % 3],
				"_trees" if Board.hash01(x, y, 6) < 0.4 else ""]
			fit_k = 1.05
			max_h = 0.7
		"=":
			path = "hex/buildings/neutral/building_bridge_A.gltf"
			fit_k = 1.0
	var n := KK.prop(path, fit_k, max_h)
	n.position = Vector3(x + 0.5, top, y + 0.5)
	if t == "=":
		var horiz: bool = (Game.tile_at(s, x - 1, y) != "~" or Game.tile_at(s, x + 1, y) != "~") and Game.tile_at(s, x, y - 1) == "~"
		n.rotation.y = PI / 2.0 if horiz else 0.0
		n.position.y = -0.02
	else:
		n.rotation.y = floorf(Board.hash01(x, y, 7) * 6.0) * PI / 3.0
	_world.add_child(n)

## sand rim where land meets water
func _shore(k: Kit, x: int, y: int, top: float) -> void:
	var w := 0.12
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if Game.tile_at(s, x + d.x, y + d.y) != "~":
			continue
		var c := Vector3(x + 0.5 + d.x * (0.5 - w / 2), top + 0.004, y + 0.5 + d.y * (0.5 - w / 2))
		var sz := Vector3(w, 0.01, 1.0) if d.x != 0 else Vector3(1.0, 0.01, w)
		k.box(c, sz, SAND, SAND, false)

## dirt track joining path / village / castle / bridge neighbours (same links as the 2D board)
func _road(k: Kit, x: int, y: int, _p: Dictionary) -> void:
	var links := { "r": 0.5, "v": 0.5, "c": 0.5, "x": 0.5, "t": 0.5, "=": 0.5 }
	var w := 0.3
	var c := Vector3(x + 0.5, 0.006, y + 0.5)
	k.box(c, Vector3(w, 0.012, w), KK_ROAD2, KK_ROAD, false)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nt: Variant = Game.tile_at(s, x + d.x, y + d.y)
		if nt == null or not links.has(nt):
			continue
		var seg_len: float = links[nt]
		var m := c + Vector3(d.x, 0, d.y) * seg_len / 2.0
		var sz := Vector3(seg_len, 0.012, w) if d.x != 0 else Vector3(w, 0.012, seg_len)
		k.box(m, sz, KK_ROAD2, KK_ROAD, false)
	for i in 4:
		var q := Vector3(x + 0.35 + Board.hash01(x, y, i + 40) * 0.3, 0.014, y + 0.35 + Board.hash01(x, y, i + 50) * 0.3)
		k.box(q, Vector3(0.03, 0.012, 0.03), KK_ROAD2, KK_ROAD2, false)

# ---------- buildings / graves / night lights (rebuilt only when they change) ----------
func _sync_sites(time: float) -> void:
	var sw: int = s.w
	var sh: int = s.h
	var owners: Dictionary = s.owner
	var hold: Dictionary = view.hold
	for y: int in sh:
		for x: int in sw:
			var t: String = s.tiles[y][x]
			if t != "v" and t != "c" and t != "x" and t != "t":
				continue
			var at := Vector2i(x, y)
			var own: String = owners.get(at, "n")
			var held: Variant = hold.get(at) # [tile, owner] until its raze / repair event plays
			if held != null:
				t = held[0]
				own = held[1] if held[1] != null else "n"
			var site: Variant = _sites.get(at)
			if site == null or site.own != own or site.t != t:
				if site != null:
					var old: Dictionary = site
					var old_mi: Node3D = old.mi
					old_mi.queue_free()
					if old.flag != null:
						var old_flag: Node3D = old.flag
						old_flag.queue_free()
				var col: String = SITE_COLOR.get(own, "yellow")
				var path := "hex/buildings/yellow/building_church_yellow.gltf" if t == "t" else "hex/buildings/neutral/building_destroyed.gltf" if t == "x" \
					else ("hex/buildings/%s/building_home_%s_%s.gltf" % [col, "A" if Board.hash01(x, y, 3) < 0.5 else "B", col]) if t == "v" \
					else ("hex/buildings/%s/building_castle_%s.gltf" % [col, col])
				var mi := KK.prop(path, 0.62 if t != "c" else 0.78, 0.5 if t != "c" else 0.75)
				mi.position = Vector3(x + 0.5, 0.0, y + 0.5 - SITE_BACK)
				_world.add_child(mi)
				site = { "mi": mi, "own": own, "flag": null, "t": t }
				_sites[at] = site
			if site.flag != null:
				site.flag.rotation.y = sin(time / 300.0 + x + y) * 0.35

func _sync_graves() -> void:
	var key := ""
	for g: Dictionary in s.graves:
		key += "%d,%d;" % [g.x, g.y]
	if key == _graves_key:
		return
	_graves_key = key
	for n: Node in _graves:
		n.queue_free()
	_graves.clear()
	for g: Dictionary in s.graves:
		var gx: int = g.x
		var gy: int = g.y
		var mi := _mi(Pieces.grave(), _mat)
		mi.position = Vector3(gx + 0.5, _top_at(gx, gy), gy + 0.5)
		_graves.append(mi)

func _sync_lights() -> void:
	var want := []
	for u: Dictionary in s.units:
		if u.side == "p" and want.size() < 6:
			var ux: int = u.x
			var uy: int = u.y
			want.append(Vector3(ux + 0.5, _stand(ux, uy) + 0.8, uy + 0.5))
	for at: Vector2i in s.owner:
		if s.owner[at] == "p" and want.size() < 8:
			want.append(Vector3(at.x + 0.5, 0.7, at.y + 0.5))
	while _lights.size() < want.size():
		var l := OmniLight3D.new()
		l.light_color = Color("#ffc27a")
		l.light_energy = 0.6
		l.omni_range = 2.6
		_world.add_child(l)
		_lights.append(l)
	for i in _lights.size():
		var l: OmniLight3D = _lights[i]
		l.visible = i < want.size()
		if l.visible:
			l.position = want[i]

# ---------- figures ----------
## same list the 2D board draws (BoardBase._figures); a stacked pair is shifted after the feet height is found
func _collect(time: float, _dt: float) -> void:
	_shown.clear()
	var v := view
	var sel_id: int = v.sel.id if v.sel != null else -1
	for f: Dictionary in _figures(time):
		var id: int = f.u.id
		var key := "u%d" % id
		if f.kind != "u":
			if f.kind == "s":
				key = "s%d" % id
			else:
				var t0: float = f.t0
				key = "g%d_%d" % [id, int(t0)]
		_shown.append({ "key": key, "u": f.u, "x": f.x, "y": f.y, "ghost": f.k, "stack": f.stack })
	for it: Dictionary in _shown:
		var u: Dictionary = it.u
		var stack: Vector2 = it.stack
		if u.id == sel_id and v.dest != null and it.ghost < 0:
			var dx: float = v.dest[0]
			var dy: float = v.dest[1]
			it.x = dx
			it.y = dy
			stack = Vector2.ZERO
		var off: Variant = fx.offsets.get(u.id)
		it.off = off
		var bx: float = it.x
		var by: float = it.y
		if off != null:
			it.x += off.x
			it.y += off.y
		# feet height: blend between the two tiles a walker is crossing, hop on each step
		var x0 := floori(bx)
		var y0 := floori(by)
		var fxr := bx - x0
		var fyr := by - y0
		var h0 := _stand(x0, y0)
		var h1 := _stand(x0 + (1 if fxr > 0.001 else 0), y0 + (1 if fyr > 0.001 else 0))
		var frac := fxr + fyr
		it.h = lerpf(h0, h1, frac)
		it.moving = frac > 0.001 and frac < 0.999
		it.x += stack.x
		it.y += stack.y

func _roster_key(u: Dictionary) -> String:
	return ("hero_" + u.side) if u.type == "hero" else u.type

## a KayKit actor for this unit (or null: no model for its type -> code-built piece)
func _make_actor(u: Dictionary) -> Node3D:
	var rv: Variant = ROSTER.get(_roster_key(u))
	if rv == null:
		return null
	var r: Array = rv
	var weapons := []
	for w: Array in r[1]:
		weapons.append([w[0], (w[1] % SITE_COLOR[u.side]) if "%s" in w[1] else w[1]])
	var char_file: String = r[0]
	var side: String = u.side
	var tint: bool = not (u.type == "hero" and u.side == "e")
	var r_scale: float = r[3]
	var a := KK.actor(char_file, weapons, side, tint)
	a.set_meta("scale", CHAR * r_scale)
	a.set_meta("attack", r[2])
	return a

func _sync_pieces(time: float) -> void:
	var used := {}
	var sel_id: int = view.sel.id if view.sel != null else -1
	for it: Dictionary in _shown:
		var u: Dictionary = it.u
		var key: String = it.key
		var node: Node3D = _pieces.get(key)
		if node == null:
			node = _make_actor(u)
			if node == null:
				var mi := MeshInstance3D.new()
				var side: String = u.side
				var type: String = u.type
				mi.mesh = Pieces.unit(side, type)
				node = mi
			_world.add_child(node)
			_pieces[key] = node
			_anim[key] = { "cur": "", "lock": 0.0, "attacking": false, "knock": 0.0 }
		node.visible = true
		used[key] = true
		# facing: walk direction, strike direction, else last facing (both sides start facing each other)
		var id: int = u.id
		var yaw: float = _facing.get(id, 0.0 if u.side == "p" else PI)
		var ix: float = it.x
		var iy: float = it.y
		var ih: float = it.h
		var cur := Vector2(ix, iy)
		var last: Variant = _last_pos.get(id)
		var lp := cur
		if last != null:
			lp = last
		if it.off != null and fx.aim.has(id):
			var ad: Vector2 = fx.aim[id]
			yaw = atan2(-ad.y, ad.x)
		elif last != null and cur.distance_to(lp) > 0.01 and it.ghost < 0:
			var d: Vector2 = cur - lp
			yaw = atan2(-d.y, d.x)
		_last_pos[id] = cur
		var cyaw: float = _facing.get(id, yaw)
		cyaw = lerp_angle(cyaw, yaw, 0.3)
		_facing[id] = cyaw
		var pos := Vector3(ix + 0.5, ih, iy + 0.5)
		var fl: float = fx.flash_until.get(id, 0.0)
		var flash: bool = fl > time and it.ghost < 0
		var acted: bool = u.get("acted", false) and s.side == u.side and not view.busy and it.ghost < 0
		if node.has_meta("ap"):
			var sc: float = node.get_meta("scale")
			node.transform = Transform3D(Basis(Vector3.UP, cyaw).scaled(Vector3.ONE * sc), pos)
			_animate(key, node, u, it, time, id == sel_id)
			var ov: Material = _ov_flash if flash else (_ov_dim if acted else null)
			for mi: MeshInstance3D in node.get_meta("meshes"):
				mi.material_overlay = ov
		else:
			var bas := Basis(Vector3.UP, cyaw)
			var sc2 := FIG
			if it.ghost >= 0: # dying: topple sideways and sink
				var k: float = it.ghost
				bas = bas * Basis(Vector3.RIGHT, -k * k * 1.45)
				pos.y -= k * 0.22
			elif it.off != null:
				var off_v: Vector2 = it.off
				bas = bas * Basis(Vector3.BACK, -off_v.length() * 1.1)
			if id == sel_id and it.ghost < 0:
				pos.y += 0.06 + sin(time / 160.0) * 0.03
			node.transform = Transform3D(bas.scaled(Vector3.ONE * sc2), pos)
			(node as MeshInstance3D).material_override = _mat_flash if flash else (_mat_dim if acted else _mat)
	for key: String in _pieces.keys():
		if used.has(key):
			continue
		if key.begins_with("u"):
			_pieces[key].visible = false
		else:
			var gone: Node3D = _pieces[key]
			gone.queue_free()
			_pieces.erase(key)
			_anim.erase(key)

## pick the clip: death (corpse), strike (when the lunge starts), hit (new knock), run (moving), else idle.
## One-shot clips hold the actor until they finish (sped up with the playback speed).
func _animate(key: String, node: Node3D, u: Dictionary, it: Dictionary, time: float, selected: bool) -> void:
	var ap: AnimationPlayer = node.get_meta("ap")
	var st: Dictionary = _anim[key]
	var sp := FX.speed
	var play := func(clip: String, speed: float, blend := 0.12) -> void:
		ap.play(clip, blend, speed * sp)
		st.cur = clip
		var a := ap.get_animation(clip)
		st.lock = time + (a.length / (speed * sp)) * 1000.0 if a.loop_mode == Animation.LOOP_NONE else 0.0
	if it.ghost >= 0:
		if st.cur != "Death_A":
			play.call("Death_A", 1.4, 0.05)
		return
	if it.off != null:
		if not st.attacking:
			st.attacking = true
			play.call(node.get_meta("attack"), 1.7, 0.05)
	else:
		st.attacking = false
	var kn: Variant = fx.knock.get(u.id)
	if kn != null:
		var kn_t0: float = kn.t0
		var seen_t0: float = st.knock
		if kn_t0 != seen_t0:
			st.knock = kn.t0
			play.call("Hit_A", 1.5, 0.05)
	var lock: float = st.lock
	if time < lock:
		return
	var want := "Running_A" if it.get("moving", false) else ("Idle_B" if selected else "Idle_A")
	if st.cur != want:
		play.call(want, 1.25 if want == "Running_A" else 1.0)

# ---------- overlay texture (flat on the tiles) ----------
func _paint_overlay(ci: CanvasItem) -> void:
	if s.is_empty():
		return
	var time := FX.now()
	_flat.T = OT
	_flat.hover = hover
	_flat._draw_overlays(ci, time)
	for at: Array in Objectives.marks(s):
		var ax: float = at[0]
		var ay: float = at[1]
		_flat._draw_goal(ci, ax * OT, ay * OT, time)
	fx.draw_under(ci, OT, time)
	if view.sel != null:
		var at: Array = view.dest if view.dest != null else [view.sel.x, view.sel.y]
		var ax: float = at[0]
		var ay: float = at[1]
		var c := Vector2((ax + 0.5) * OT, (ay + 0.5) * OT)
		ci.draw_arc(c, OT * 0.42, 0, TAU, 32, sel_color(time), OT * 0.07, true)

# ---------- screen layers ----------
func _draw_add(ci: CanvasItem) -> void:
	if s.is_empty():
		return
	Draw.set_xf(ci, _ground_xf(FXH) * Transform2D(0.0, Vector2.ONE / TF, 0.0, Vector2.ZERO))
	fx.draw_add(ci, TF, FX.now())
	Draw.set_xf(ci, Transform2D.IDENTITY)

func _draw_top(ci: CanvasItem) -> void:
	if s.is_empty():
		return
	var time := FX.now()
	Draw.set_xf(ci, _ground_xf(FXH) * Transform2D(0.0, Vector2.ONE / TF, 0.0, Vector2.ZERO))
	fx.draw_over(ci, TF, time)
	Draw.set_xf(ci, Transform2D.IDENTITY)
	var te := T * _zoom()
	_flat.T = te
	_flat.hover = hover
	_flat._info_spots.clear()
	for it: Dictionary in _shown:
		if it.ghost >= 0:
			continue
		var u: Dictionary = it.u
		var ix: float = it.x
		var iy: float = it.y
		var ih: float = it.h
		var c := _proj(Vector3(ix + 0.5, ih + 0.36, iy + 0.5))
		Board.draw_unit_badges(ci, view, u, c, te, 0.62)
		var key: String = it.key
		if it.off == null and not view.busy and key.begins_with("u"):
			var ux: int = u.x
			var uy: int = u.y
			_flat._draw_buffs(ci, u, c, ux, uy, time)
	# floating numbers / labels, upright on screen
	for f: Dictionary in fx.floats:
		var k: float = (time - f.t0) / f.dur
		var pop := 0.6 + (k / 0.15) * 0.7 if k < 0.15 else 1.3 - minf(0.3, (k - 0.15) * 1.5)
		var col: Color = f.color
		col.a = 1.0 - (k - 0.7) / 0.3 if k > 0.7 else 1.0
		var fs := maxi(6, roundi(te * (0.46 if f.big else 0.34) * 1.3))
		var fx_x: float = f.x
		var fx_y: float = f.y
		var tx := roundi(fx_x)
		var ty := roundi(fx_y)
		var pos := _proj(Vector3(fx_x + 0.5, _stand(tx, ty) + 0.95, fx_y + 0.5)) - Vector2(0, k * te * 0.55)
		var txt: String = f.text
		Draw.text_c(ci, Style.xbold, pos, txt, fs, col, maxi(3, int(te * 0.08 * 1.3)), Color(0.1, 0.047, 0.024, col.a), pop / 1.3)
	# hover forecast above the target's head (Board's painter, shifted onto the projected spot)
	var p: Variant = view.get("preview")
	if p != null:
		var ppx: int = p.x
		var ppy: int = p.y
		var q := _proj(Vector3(ppx + 0.5, _stand(ppx, ppy) + 1.1, ppy + 0.5))
		Draw.set_xf(ci, Transform2D(0.0, Vector2.ONE, 0.0, q - Vector2((ppx + 0.5) * te, ppy * te)))
		_flat._draw_preview(ci)
		Draw.set_xf(ci, Transform2D.IDENTITY)

