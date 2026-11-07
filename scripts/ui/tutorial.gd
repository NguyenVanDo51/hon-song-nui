class_name Tutorial
extends Control
## step-locked guide of a tutorial level (def.tutorial, spec §7): screen dimmed except a hole on the step's target (tile,
## Hết lượt, buy button) + the ⚙, pulsing gold ring, bouncing hand, one paper line. Clicks outside the holes are swallowed
## (ring flashes); the screen asks allows() before tile clicks, orders, buys and end turn. Step i is done when
## s.quests[step.q].done; s.tut_step keeps it in the save. Off for `bot` runs. Tokens: Vector2i tile, "end_turn",
## "buy:<type>", "act:<order kind>".

## quests the turn start completes by itself: no hole / lock, their line pops up once when done
const PASSIVE := ["heal_on"]
## orders that can finish a step's quest (anything else, e.g. ⏳ Chờ on the village, would burn the unit)
const ACTS := {
	"capture": ["capture"],
	"stand_on": ["wait"],
	"move": ["wait", "capture"],
	"attack_with": ["attack"],
	"hit_type": ["attack"],
	"kill_with": ["attack"],
	"kill_type": ["attack"],
	"repair": ["repair"],
	"raze": ["raze"],
	"raise": ["raise"],
}
## quests done by walking somewhere: staying put never counts
const MOVES := ["stand_on", "move"]
## attack quests: the pointed enemy may not come (AI noise) -> aim at one in reach, or wait turns for one
const ATTACKS := ["attack_with", "hit_type", "kill_with", "kill_type"]
const SHOW_DELAY := 0.9 # s after entering: the turn banner goes first
const CELEBRATE_MAX := 3.0 # s the guide waits for a quest stamp before showing anyway
const TOAST_S := 2.6
const HAND_UP := preload("res://assets/emoji/emoji_u1f446.png")
const HAND_DOWN := preload("res://assets/emoji/emoji_u1f447.png")
const HAND_PX := 50.0
const TIP_X := 0.42 # fingertip across the hand picture
const MAX_HOLES := 8

var step := 0
var gs: GameScreen
var steps: Array = []

var _on := false
var _since := 0.0
var _t := 0.0
var _flash := 0.0
var _toast := 0.0
var _toast_at := Rect2()
var _toast_say := ""
var _target := Rect2()
var _round := true
var _holes: Array[Rect2] = [] # other allowed tiles: lit, smaller, no ring
var _btn_holes: Array[Rect2] = [] # orders popup buttons that finish the step (🏠 Chiếm, ⚔ Đánh…)
var _cel_t := 0.0
var _ring_sb: StyleBoxFlat
var _pass: Array[Rect2] = [] # clicks go through here (target, holes, ⚙)
var _dim: ColorRect
var _mat: ShaderMaterial
var _ring: Control
var _hand: TextureRect
var _bubble: PanelContainer
var _say: Label

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 52 # over the orders / buy popup (50): it shows through a hole only
	visible = false
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/tut_hole.gdshader")
	_dim.material = _mat
	_mat.set_shader_parameter("dim", Color(0.08, 0.05, 0.02, 0.7))
	add_child(_dim)
	_ring = Control.new()
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	_ring_sb = StyleBoxFlat.new()
	_ring_sb.draw_center = false
	_ring_sb.corner_detail = 16
	_ring_sb.anti_aliasing = true
	add_child(_ring)
	_hand = TextureRect.new()
	_hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.size = Vector2(HAND_PX, HAND_PX)
	add_child(_hand)
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", Style.paper(10.0, 4.0))
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble)
	_say = Style.lbl("", 18, Style.INK, Style.bold)
	_bubble.add_child(_say)

func bind(screen: GameScreen, list: Array) -> void:
	gs = screen
	steps = list
	_on = not list.is_empty() and not gs.main.flags.has("bot")
	_since = 0.0
	_toast = 0.0
	_pass.clear()
	visible = false
	step = 0
	if _on:
		var saved: int = gs.s.get("tut_step", 0)
		step = clampi(saved, 0, steps.size())
		gs.s.tut_step = step
	advance()

## a step locks input (passive steps and the free play after the last step do not)
func active() -> bool:
	return _on and step < steps.size() and not _passive(_st())

func allows(token: Variant) -> bool:
	return not active() or _allowed().has(token)

## a swallowed click / key: the ring flashes (no error sound)
func refuse() -> void:
	_flash = 1.0

## skip the steps whose quest is done (screen refresh calls this after every change)
func advance() -> void:
	if not _on:
		return
	var was := step
	while step < steps.size() and _quest(_st()).done:
		if _passive(_st()):
			_pop_line(_st())
		step += 1
	if active() and gs.ui.sel != null and _allowed() == ["end_turn"]: # a unit card would hide Hết lượt
		gs._clear_sel()
	if step == was:
		return
	gs.s.tut_step = step
	if active(): # a unit picked for the last step (e.g. the one just bought) must not act for this one
		var sel: Variant = gs._sel_unit()
		var su: Dictionary = sel if sel != null else { }
		if sel != null and not _tiles(_st()).has(_at(su)):
			gs._clear_sel()
	gs.save()

## where the ring is, in screen (GameScreen) coords
func target_rect() -> Rect2:
	return _target

# ---------- rules ----------
func _st() -> Dictionary:
	return steps[step]

static func _xy(a: Variant) -> Vector2i:
	var arr: Array = a
	var x: int = arr[0]
	var y: int = arr[1]
	return Vector2i(x, y)

static func _at(u: Dictionary) -> Vector2i:
	var x: int = u.x
	var y: int = u.y
	return Vector2i(x, y)

func _quest(st: Dictionary) -> Dictionary:
	var qs: Array = gs.s.get("quests", [])
	var q: int = st.get("q", -1)
	return qs[q] if q >= 0 and q < qs.size() else { "do": "", "done": true }

func _passive(st: Dictionary) -> bool:
	return PASSIVE.has(_quest(st).do)

func _tiles(st: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var allow: Array = st.get("allow", [])
	for a: Variant in allow:
		if a is Array:
			out.append(_xy(a))
	return out

## allowed tiles holding one of our units that can still act
func _unit_tiles(st: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t: Vector2i in _tiles(st):
		var u: Variant = Game.unit_at(gs.s, t.x, t.y)
		if u != null and u.side == gs._me() and not u.acted:
			out.append(t)
	return out

## the step's own unit is picked (ours, can act, on an allowed tile)
func _picked(st: Dictionary) -> bool:
	var sel: Variant = gs._sel_unit()
	var su: Dictionary = sel if sel != null else { }
	return sel != null and su.side == gs._me() and not su.acted and _tiles(st).has(_at(su))

## the step's unit: the picked one, else the first that can act on an allowed tile; {} = none
func _step_unit(st: Dictionary) -> Dictionary:
	if _picked(st):
		var su: Dictionary = gs._sel_unit()
		return su
	var tiles := _unit_tiles(st)
	if tiles.is_empty():
		return { }
	var u: Dictionary = Game.unit_at(gs.s, tiles[0].x, tiles[0].y)
	return u

## the step as it stands now: an attack step whose pointed enemy the unit cannot hit this turn aims at the nearest
## enemy it can hit (tile swapped in allow); none in reach -> { spent } so Hết lượt passes turns until one comes
func _eff(st: Dictionary) -> Dictionary:
	if not ATTACKS.has(_quest(st).do):
		return st
	var u := _step_unit(st)
	if u.is_empty():
		return st
	var foes: Array = gs._attackable_anywhere(u, gs._reach(u))
	if foes.is_empty():
		return st.merged({ "spent": true }, true)
	var p: Variant = st.get("point")
	var pt := _xy(p) if p is Array else _at(u)
	var best: Dictionary = { }
	for f: Dictionary in foes:
		if _at(f) == pt:
			return st
		if best.is_empty() or _dist(_at(f), pt) < _dist(_at(best), pt):
			best = f
	var allow0: Array = st.get("allow", [])
	var allow: Array = allow0.filter(
		func(a: Variant) -> bool:
			return not (a is Array and _xy(a) == pt),
	)
	var to := [_at(best).x, _at(best).y]
	allow.append(to)
	return st.merged({ "point": to, "allow": allow }, true)

static func _dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

## no unit of the step can act this turn (e.g. t01 step 5 before the enemy came, or no enemy in reach): only Hết lượt
func _spent(st: Dictionary) -> bool:
	if _eff(st).get("spent", false):
		return true
	var allow: Array = st.get("allow", [])
	var tokens := allow.any(
		func(a: Variant) -> bool:
			return a is String,
	)
	return not tokens and _unit_tiles(st).is_empty() and not _picked(st)

func _allowed() -> Array:
	if _spent(_st()):
		return ["end_turn"]
	var st := _eff(_st())
	var units := _unit_tiles(st)
	var picked := _picked(st)
	var out: Array = []
	var allow: Array = st.get("allow", [])
	var own := _own_tile(st) if picked else Vector2i(-1, -1)
	for a: Variant in allow:
		if a is Array:
			var v := _xy(a)
			if v != own and (picked or units.is_empty() or units.has(v)): # pick the unit first, then where it goes
				out.append(v)
		else:
			out.append(a)
	var acts: Array = ACTS.get(_quest(st).do, [])
	for k: String in acts:
		out.append("act:" + k)
	return out

## a move step's picked unit: its own tile is no destination (unless pointed); (-1,-1) = keep every tile
func _own_tile(st: Dictionary) -> Vector2i:
	if not MOVES.has(_quest(st).do):
		return Vector2i(-1, -1)
	var su: Dictionary = gs._sel_unit()
	var at := _at(su)
	var p: Variant = st.get("point")
	return Vector2i(-1, -1) if p is Array and _xy(p) == at else at

# ---------- view ----------
func _process(dt: float) -> void:
	if not _on or gs == null:
		visible = false
		return
	_t += dt
	_since += dt
	_flash = maxf(0.0, _flash - dt * 2.5)
	_toast = maxf(0.0, _toast - dt)
	_cel_t = _cel_t + dt if gs.hud.quests.celebrating() else 0.0
	if active() and not gs.s.is_empty():
		_aim()
	var live := _live()
	visible = live or _toast > 0.0
	if not visible:
		modulate.a = 0.0
		return
	modulate.a = minf(1.0, modulate.a + dt * 5.0)
	mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE
	_dim.visible = live
	_ring.visible = live
	_hand.visible = live
	if not live:
		_target = _toast_at
		_say.text = _toast_say
	_place()
	_ring.queue_redraw()

## input is open for the player and nothing else covers the board
func _live() -> bool:
	if not active() or _since < SHOW_DELAY or not gs.visible or gs.s.is_empty():
		return false
	return (
		gs.s.winner == null and gs._human_turn() and not gs.ui.busy and not gs._intro_on
		and gs.turns.handoff_layer == null and not gs.hud.menu.visible and not gs.cards.end_layer.visible
		and not gs.main.menus.is_codex_open() and (_cel_t == 0.0 or _cel_t > CELEBRATE_MAX) # the quest ✓ stamp plays undimmed first
	)

func _tile_r(t: Vector2i) -> Rect2:
	var r: Rect2 = gs.board.tile_rect(t.x, t.y)
	r.position += gs.hud.map_wrap.position
	return r

func _ctrl_r(c: Control) -> Rect2:
	return Rect2(c.global_position - global_position, c.size)

## target / holes / click-through rects for the step and the current selection, then the shader holes
func _aim() -> void:
	var st := _eff(_st())
	var allowed := _allowed()
	var say: String = st.get("say", "")
	var tiles: Array[Vector2i] = []
	for a: Variant in allowed:
		if a is Vector2i:
			tiles.append(a)
	var aim_tile := Vector2i(-1, -1)
	_round = true
	if allowed.has("end_turn") and gs.hud.btn_end.is_visible_in_tree():
		_target = _ctrl_r(gs.hud.btn_end)
		if _spent(_st()):
			say = Content.text("tutEndTurn")
	else:
		var btn := _buy_button(allowed)
		if btn != null:
			_target = _ctrl_r(btn)
			_round = false
		else:
			var p: Variant = st.get("point")
			aim_tile = _xy(p) if p is Array else (tiles[0] if tiles.size() else Vector2i.ZERO)
			if not tiles.has(aim_tile) and tiles.size():
				aim_tile = tiles[0] # point not open yet (unit not picked): the unit to pick
			_target = _tile_r(aim_tile)
	_say.text = say
	_holes.clear()
	for t: Vector2i in tiles:
		if t != aim_tile:
			_holes.append(_tile_r(t))
	_btn_holes.clear()
	for b: Button in _act_buttons(allowed):
		_btn_holes.append(_ctrl_r(b))
	_pass = [_target]
	_pass.append_array(_holes)
	_pass.append_array(_btn_holes)
	var gear := _ctrl_r(gs.hud.gear) if gs.hud.gear.is_visible_in_tree() else Rect2()
	if gear.has_area():
		_pass.append(gear)
	var boxes := PackedVector4Array()
	var radii := PackedFloat32Array()
	var rr := _ring_r(_target, _round, 0.0)
	_add_box(boxes, radii, rr, rr.size.x / 2.0 if _round else 10.0)
	for h: Rect2 in _holes:
		var hr := h.grow(-h.size.x * 0.06)
		_add_box(boxes, radii, hr, hr.size.x / 2.0)
	for h: Rect2 in _btn_holes:
		_add_box(boxes, radii, h.grow(3.0), 9.0)
	if gear.has_area():
		var gr := gear.grow(4.0)
		_add_box(boxes, radii, gr, minf(gr.size.x, gr.size.y) / 2.0)
	_mat.set_shader_parameter("size", size)
	_mat.set_shader_parameter("count", mini(boxes.size(), MAX_HOLES))
	boxes.resize(MAX_HOLES)
	radii.resize(MAX_HOLES)
	_mat.set_shader_parameter("boxes", boxes)
	_mat.set_shader_parameter("radii", radii)

static func _add_box(boxes: PackedVector4Array, radii: PackedFloat32Array, r: Rect2, rad: float) -> void:
	var c := r.get_center()
	boxes.append(Vector4(c.x, c.y, r.size.x / 2.0, r.size.y / 2.0))
	radii.append(rad)

## the shop's button for the step's buy token, once the shop is open and laid out
func _buy_button(allowed: Array) -> Button:
	if gs.ui.buyAt == null or not gs.panel.pop.visible or gs.panel.pop.modulate.a < 1.0:
		return null
	for a: Variant in allowed:
		if a is String and str(a).begins_with("buy:"):
			var b := _find_buy(gs.panel.actions, str(a).substr(4))
			if b != null and b.is_visible_in_tree() and b.size.x > 0.0:
				return b
	return null

## orders popup buttons (meta "act") whose order is allowed in this step
func _act_buttons(allowed: Array) -> Array[Button]:
	var out: Array[Button] = []
	if gs.ui.buyAt != null or not gs.panel.pop.visible or gs.panel.pop.modulate.a < 1.0:
		return out
	for c: Node in gs.panel.actions.get_children():
		var b := c as Button
		if b != null and b.has_meta("act") and allowed.has("act:" + str(b.get_meta("act"))) and b.size.x > 0.0:
			out.append(b)
	return out

static func _find_buy(n: Node, type: String) -> Button:
	var b := n as Button
	if b != null and str(b.get_meta("buy", "")) == type:
		return b
	for c: Node in n.get_children():
		var f := _find_buy(c, type)
		if f != null:
			return f
	return null

## ring around a target: a circle for tiles / the round seal, a rounded box for a wide button
static func _ring_r(r: Rect2, is_round: bool, grow: float) -> Rect2:
	if not is_round:
		return r.grow(5.0 + grow)
	var rad := maxf(r.size.x, r.size.y) * 0.62 + grow
	return Rect2(r.get_center() - Vector2(rad, rad), Vector2(rad, rad) * 2.0)

## hand under the target pointing up (above it pointing down near the bottom edge); bubble where it covers neither
func _place() -> void:
	var rr := _ring_r(_target, _round, 0.0)
	var bob := absf(sin(_t * TAU / 1.1)) * 8.0
	var below := rr.end.y + HAND_PX * 0.9 < size.y - 4.0
	_hand.texture = HAND_UP if below else HAND_DOWN
	_hand.size = Vector2(HAND_PX, HAND_PX)
	var hx := rr.get_center().x - HAND_PX * TIP_X
	_hand.position = Vector2(hx, rr.end.y - 6.0 + bob) if below else Vector2(hx, rr.position.y - HAND_PX + 6.0 - bob)
	var hand_r := Rect2(Vector2(hx, rr.end.y - 6.0), Vector2(HAND_PX, HAND_PX + 8.0)) if below \
			else Rect2(Vector2(hx, rr.position.y - HAND_PX - 2.0), Vector2(HAND_PX, HAND_PX + 8.0))
	if not _hand.visible:
		hand_r = Rect2()
	_bubble.reset_size()
	var bs := _bubble.get_combined_minimum_size()
	var c := rr.get_center()
	var gap := 12.0
	var cands: Array[Vector2] = [
		Vector2(c.x - bs.x / 2.0, rr.position.y - bs.y - gap) if below else Vector2(c.x - bs.x / 2.0, rr.end.y + gap),
		Vector2(rr.end.x + gap, c.y - bs.y / 2.0),
		Vector2(rr.position.x - bs.x - gap, c.y - bs.y / 2.0),
		Vector2(c.x - bs.x / 2.0, hand_r.end.y + 4.0) if below else Vector2(c.x - bs.x / 2.0, hand_r.position.y - bs.y - 4.0),
	]
	var e := Style.safe_insets(self) # phone notch / rounded corners
	var lim := Rect2(Vector2(8 + e.x, 8 + e.y), size - Vector2(16 + e.x + e.z, 16 + e.y + e.w))
	var avoid: Array[Rect2] = [rr.grow(2.0)]
	if _hand.visible:
		avoid.append(hand_r)
	avoid.append_array(_holes)
	for c2: Control in [gs.panel.pop, gs.hud.card, gs.hud.gear]: # shop / orders text, unit card, ⚙ stay readable
		if c2.is_visible_in_tree():
			avoid.append(_ctrl_r(c2))
	var best := Vector2(-1, -1)
	for p0: Vector2 in cands:
		var p := Vector2(clampf(p0.x, lim.position.x, lim.end.x - bs.x), clampf(p0.y, lim.position.y, lim.end.y - bs.y))
		var r := Rect2(p, bs)
		if avoid.any(
			func(a: Rect2) -> bool:
				return r.intersects(a),
		):
			continue
		best = p
		break
	if best.x < 0.0:
		best = Vector2(clampf(cands[0].x, lim.position.x, lim.end.x - bs.x), clampf(cands[0].y, lim.position.y, lim.end.y - bs.y))
	_bubble.position = best.floor()
	_bubble.visible = _say.text != ""

func _draw_ring() -> void:
	if not _dim.visible:
		return
	var pulse := 0.5 + 0.5 * sin(_t * TAU / 1.1)
	var r := _ring_r(_target, _round, 2.0 + pulse * 5.0 + _flash * 8.0)
	_ring_sb.set_border_width_all(int(4.0 + _flash * 4.0))
	_ring_sb.set_corner_radius_all(int(r.size.x / 2.0) if _round else 12)
	_ring_sb.border_color = Color(Style.LEAF.lerp(Color.WHITE, _flash * 0.6), 1.0 - pulse * 0.4 + _flash * 0.4)
	_ring.draw_style_box(_ring_sb, r)

## a passive step done (heal at turn start): its line over the target for a moment, no dim
func _pop_line(st: Dictionary) -> void:
	var p: Variant = st.get("point")
	var say: String = st.get("say", "")
	if not (p is Array) or say == "":
		return
	_toast_at = _tile_r(_xy(p))
	_toast_say = say
	_toast = TOAST_S
	_round = true

func _has_point(p: Vector2) -> bool:
	return not _pass.any(
		func(r: Rect2) -> bool:
			return r.has_point(p),
	)

func _gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed:
		refuse()
	if ev is InputEventMouse or ev is InputEventScreenTouch:
		accept_event()
