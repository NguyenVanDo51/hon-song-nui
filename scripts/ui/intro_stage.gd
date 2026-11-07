class_name IntroStage
extends Control
## new-unit intro scene: one row of 6 plains tiles on a real Board + its own FX. The unit shows its move zone, walks
## into range and attacks an enemy-side soldier with its attack rig; the dummy strikes back, or 🚫 when it cannot.
## Script built only from Rules.UNITS flags (mv, rmin / rmax, siege, poison): a new unit type gets a scene for free.

signal finished
signal phase_changed(phase: String)

const COLS := 6
const DUMMY_X := COLS - 1
const DUMMY := "soldier"
const TILE := 92.0
const HEAD := 0.4 # headroom over the row for the figures, rigs and damage numbers (tiles)
const STEP_MS := 95.0 # one tile of walking (EventPlayer "move")
const A_ID := 1
const D_ID := 2

var board: Board
var fx: FX
var s: Dictionary = { }
var side := "p"
var type := "soldier"
var hero_key: Variant = null
var phase := ""
var _marks: Marks
var _gen := 0
var _live := 0 # running play() coroutines

## range frame, 🚫 and the poison chips, in board px (the Board itself draws everything else)
class Marks extends Control:
	var T := 64.0
	var range_x := Vector2i(-1, -1) # first..last tile of the yellow range frame (-1 = none)
	var ban_at := Vector2.ZERO
	var ban_k := 0.0
	var chips_at := Vector2.ZERO
	var chips_k := 0.0
	var poison := 0

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(FX.now() / 180.0)
		if range_x.x >= 0:
			var r := Rect2(range_x.x * T, 0.0, (range_x.y - range_x.x + 1) * T, T).grow(-3.0)
			draw_rect(r, Color(Board.TARGET, 0.12 + 0.08 * pulse))
			draw_rect(r, Color(Board.TARGET, 0.75 + 0.25 * pulse), false, maxf(3.0, T * 0.045))
		if ban_k > 0.0:
			var sz := T * 0.46 * ban_k
			draw_texture_rect(Icons.tex("ban"), Rect2(ban_at - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), false)
		if chips_k > 0.0:
			_chips()

	func _chips() -> void:
		var fs := roundi(T * 0.2)
		var ic := T * 0.22
		var txt := "−%d" % poison
		var tw := Style.xbold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cw := ic + tw + T * 0.14
		var ch := T * 0.3
		var gap := T * 0.06
		var x0 := clampf(chips_at.x - cw - gap / 2.0, 2.0, size.x - 2.0 * cw - gap - 2.0)
		draw_set_transform(chips_at, 0.0, Vector2(chips_k, chips_k))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Board.POISON
		sb.border_color = Board.POISON_INK
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(roundi(T * 0.07))
		for k in 2:
			var tl := Vector2(x0 + k * (cw + gap), chips_at.y - ch) - chips_at
			draw_style_box(sb, Rect2(tl, Vector2(cw, ch)))
			var icon := Icons.tex("sword" if k == 0 else "shield")
			draw_texture_rect(icon, Rect2(tl + Vector2(T * 0.05, (ch - ic) / 2.0), Vector2(ic, ic)), false)
			Draw.text_a(self, Style.xbold, tl + Vector2(T * 0.07 + ic, ch / 2.0 + fs * 0.36), txt, fs, Color.WHITE)
		draw_set_transform(Vector2.ZERO)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false

## side / type / hero key of the unit to show (hero_key only for type "hero")
func setup(p_side: String, p_type: String, p_hero_key: Variant) -> void:
	side = p_side
	type = p_type
	hero_key = p_hero_key
	fx = FX.new()
	fx.fixed_speed = 1.0
	add_child(fx)
	board = Board.new()
	board.fx = fx
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.position = Vector2(0.0, TILE * HEAD)
	add_child(board)
	_marks = Marks.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.position = board.position
	add_child(_marks)
	_reset()
	board.fit(Vector2(TILE * COLS, TILE))
	_marks.T = board.T
	_marks.size = board.size
	custom_minimum_size = Vector2(board.size.x, board.size.y + TILE * HEAD)

## plays the scene once from the start (a running one is dropped); awaitable
func play() -> void:
	_gen += 1
	var g := _gen
	_live += 1
	await _script(g)
	_live -= 1
	if g == _gen:
		_phase("end")
		finished.emit()

## drop the running scene; returns once its coroutine has let go (safe to free after)
func stop() -> void:
	_gen += 1
	if fx != null:
		fx.clear()
	while _live > 0: # no frame cap: a coroutine still awaiting FX.attack must not outlive the free
		await get_tree().process_frame

func _phase(p: String) -> void:
	phase = p
	phase_changed.emit(p)

func _foe() -> String:
	return "e" if side == "p" else "p"

## fresh state: actor on tile 0, dummy on the last tile, nothing selected / hidden / hurt
func _reset() -> void:
	fx.clear()
	var st := Game.new_game(Content.skirmish_def("dong_bang", "anhhung", false))
	var row := []
	for x in COLS:
		row.append(".")
	st.tiles = [row]
	st.w = COLS
	st.h = 1
	st.owner = { }
	st.graves = []
	st.night = false
	st.side = side
	var hk: Dictionary = st.heroKey
	if type == "hero":
		hk[side] = hero_key
	st.units = [_unit(A_ID, side, type, 0), _unit(D_ID, _foe(), DUMMY, DUMMY_X)]
	st.nextId = 3
	s = st
	board.set_state(s)
	board.view.hide = { }
	board.view.sprites = []
	board.view.hp = { }
	board.view.reach = null
	board.view.sel = null
	board.view.selMine = false
	board.set_face(A_ID, 1.0)
	board.set_face(D_ID, -1.0)
	_marks.range_x = Vector2i(-1, -1)
	_marks.ban_k = 0.0
	_marks.chips_k = 0.0

static func _unit(id: int, p_side: String, p_type: String, x: int) -> Dictionary:
	return { "id": id, "side": p_side, "type": p_type, "x": x, "y": 0, "hp": 100, "xp": 0, "rank": 0, "acted": false }

## frame-polled sleep (a timer would resume after the stage is freed); false = scene dropped
func _wait(ms: float, g: int) -> bool:
	var t0 := FX.now()
	while FX.now() - t0 < fx.sp(ms):
		await get_tree().process_frame
		if g != _gen:
			return false
	return g == _gen

func _script(g: int) -> void:
	_reset()
	var a: Dictionary = s.units[0]
	var d: Dictionary = s.units[1]
	var st := Content.type_stat(type, hero_key)
	var mv: int = st.mv
	var rmin: int = st.rmin
	var rmax: int = st.rmax
	var ax := DUMMY_X - clampi(rmax, rmin, DUMMY_X - 1) # attack from max range, at least one step to walk
	var x0 := maxi(0, ax - mv)
	a.x = x0
	if not await _wait(100.0, g):
		return
	# 1. move zone, then walk to the attack tile
	var reach := { }
	for x in range(x0, mini(x0 + mv, DUMMY_X - 1) + 1):
		reach[Vector2i(x, 0)] = { "x": x, "y": 0 }
	board.view.reach = reach
	board.view.selMine = true
	# no view.sel: a selected drum would also tint its aura tiles (no tricks in the intro)
	_phase("reach")
	if not await _wait(550.0, g):
		return
	board.view.reach = null
	_phase("walk")
	if not await _walk(a, ax, g):
		return
	if st.get("siege", false): # no move + attack in one turn: greyed out ("done"), then the next turn
		a.acted = true
		_phase("next")
		if not await _wait(400.0, g):
			return
		a.acted = false
		if not await _wait(100.0, g):
			return
	# 2. attack: range frame for ranged units, the rig strike, then the counter or 🚫
	if rmax > 1:
		_marks.range_x = Vector2i(ax + rmin, mini(ax + rmax, DUMMY_X))
		_phase("aim")
		if not await _wait(400.0, g):
			return
	_phase("attack")
	var amount := Game.damage(s, a, ax, 0, 100, d, 0.5)
	if not await _strike(a, d, amount, false, g):
		return
	_marks.range_x = Vector2i(-1, -1)
	if Game.can_counter(s, d, ax, 0):
		_phase("counter")
		var d_hp: int = d.hp
		var back := Game.damage(s, d, DUMMY_X, 0, d_hp, a, 0.5)
		if not await _strike(d, a, back, true, g):
			return
	else:
		_phase("nocounter")
		_marks.ban_at = Vector2((ax + DUMMY_X + 1) * board.T / 2.0, board.T * 0.42)
		await _pop("ban_k", g)
	# 3. poison: the target is marked -N atk / -N def (Board draws the red arrow, the chips spell it out)
	var pa: int = st.get("poison", 0)
	if pa > 0 and g == _gen:
		d.poison = side
		d.poisonAmt = pa
		fx.ring(DUMMY_X, 0, "#e0503f", 600.0, 0.7, 0.08)
		_marks.poison = pa
		_marks.chips_at = Vector2((DUMMY_X + 0.5) * board.T, -board.T * 0.06)
		_phase("poison")
		await _pop("chips_k", g)
	await _wait(400.0, g)

## tile by tile like a real move (sprite + dust), u ends on tile x
func _walk(u: Dictionary, to: int, g: int) -> bool:
	var from: int = u.x
	if to == from:
		return true
	var copy := u.duplicate()
	var hidden_ids: Dictionary = board.view.hide
	var sprites: Array = board.view.sprites
	var sp := { "u": copy }
	hidden_ids[u.id] = true
	sprites.append(sp)
	if fx.audio:
		fx.audio.play("move")
	fx.dust(from, 0)
	for x in range(from + 1, to + 1):
		var t0 := FX.now()
		var k := 0.0
		while k < 1.0:
			await get_tree().process_frame
			if g != _gen:
				return false
			k = minf(1.0, (FX.now() - t0) / fx.sp(STEP_MS))
			copy.x = x - 1 + k
		fx.dust(x, 0)
	u.x = to
	sprites.erase(sp)
	hidden_ids.erase(u.id)
	return g == _gen

## one blow with the unit's attack rig (or the plain FX attack without one); the hp bar drops at its hit
func _strike(a: Dictionary, d: Dictionary, amount: int, counter: bool, g: int) -> bool:
	var hp: Dictionary = board.view.hp
	var did: int = d.id
	var dhp: int = d.hp
	var on_hit := func() -> void:
		if g == _gen:
			d.hp = dhp - amount
			hp[did] = d.hp
			_phase("hit" if not counter else "counter_hit")
	var a_type: String = a.type
	var a_side: String = a.side
	var r := Rigs.make(a_type, a_side)
	if r != null:
		await fx.rig_attack(board, r, a, d, amount, { "counter": counter, "on_hit": on_hit })
	else:
		await fx.attack(a, d, amount, { "counter": counter })
		on_hit.call()
	return g == _gen

## scale-in with a little overshoot for a Marks field (ban_k / chips_k)
func _pop(field: String, g: int) -> void:
	var t0 := FX.now()
	var k := 0.0
	while k < 1.0:
		await get_tree().process_frame
		if g != _gen:
			return
		k = minf(1.0, (FX.now() - t0) / fx.sp(260.0))
		_marks.set(field, k / 0.6 * 1.2 if k < 0.6 else lerpf(1.2, 1.0, (k - 0.6) / 0.4))

func _process(_dt: float) -> void:
	if _marks != null:
		_marks.queue_redraw()
