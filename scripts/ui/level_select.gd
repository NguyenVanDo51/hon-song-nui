class_name LevelSelect
extends VBoxContainer
## "Thử thách" grid: one cell per level (number, tier colour, best stars, lock), PER_PAGE a page, info for the selected
## level (hover or first tap selects; a tap on the selected cell / "Vào trận" starts it, so phones can read the info first).
## Gold ring = next level to play (first_unwon). Levels open up to the furthest win + 1 (Store.unlocked_index).

signal level_picked(id: String)

const PER_PAGE := 20
const COLS := 5
const TILE := 84.0 # px at full size; shrinks on short screens so the page never scrolls
const TILE_MIN := 52.0
const GAP := 10.0
const CHROME_Y := 120.0 # page margins (2x28) + "Trở lại / Thử thách" header + gap, from Menus._page / _head
const TIER_COL := { "easy": Color("#3f7a2e"), "mid": Color("#c98a1e"), "hard": Color("#b3262e") }
const TIER_NAME := { "easy": "Dễ", "mid": "Trung bình", "hard": "Khó" }

var levels: Array = []
var open_index := 0
var page := 0
var sel := 0 # selected level (info panel); a second tap on it starts it
var _grid: GridContainer
var _info: VBoxContainer
var _pager: HBoxContainer
var _tile := TILE

static func page_of(index: int) -> int:
	@warning_ignore("integer_division")
	return index / PER_PAGE

## next level to play: the first not won after the furthest win (`open`), so levels inserted in front (t01/t02) never
## pull a veteran back; past the last level -> the first one not won; all won -> lv.size()
static func first_unwon(lv: Array, open: int) -> int:
	for i in range(maxi(open, 0), lv.size()):
		var def: Dictionary = lv[i]
		if not Store.is_done(str(def.id)):
			return i
	for i in lv.size():
		var def: Dictionary = lv[i]
		if not Store.is_done(str(def.id)):
			return i
	return lv.size()

static func tier_of(def: Dictionary) -> String:
	var t: String = def.get("tier", "mid")
	return t if TIER_COL.has(t) else "mid"

func setup(lv: Array, open: int, pg: int) -> void:
	levels = lv
	open_index = open
	page = clampi(pg, 0, page_of(maxi(0, levels.size() - 1)))
	var row := Style.hbox(18)
	add_child(row)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", int(GAP))
	_grid.add_theme_constant_override("v_separation", int(GAP))
	row.add_child(_grid)
	var side := Style.vbox(10) # pager above the info: the grid gets the whole page height
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.custom_minimum_size.x = 260
	row.add_child(side)
	_pager = Style.hbox(10)
	side.add_child(_pager)
	_info = Style.vbox(6)
	side.add_child(_info)
	_build()

func _ready() -> void:
	_fit()
	get_viewport().size_changed.connect(_fit)

## tile edge so 4 rows fit the canvas height under the page chrome + safe insets (phone landscape ~487 px tall)
func _fit() -> void:
	var e := Style.safe_insets(self)
	var rows := ceili(float(PER_PAGE) / COLS)
	var room := get_viewport_rect().size.y - e.y - e.w - CHROME_Y - GAP * (rows - 1) - 3.0 # 3: tile hard shadow
	_tile = clampf(floorf(room / rows), TILE_MIN, TILE)
	for c in _grid.get_children():
		(c as Control).custom_minimum_size = Vector2(_tile, _tile)

func _build() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for c in _pager.get_children():
		c.queue_free()
	var pages := page_of(maxi(0, levels.size() - 1)) + 1
	if pages > 1:
		var prev := Style.button("‹", "SegBtn")
		prev.disabled = page == 0
		prev.pressed.connect(
			func() -> void:
				_turn(-1),
		)
		_pager.add_child(prev)
		_pager.add_child(Style.lbl("Trang %d / %d" % [page + 1, pages], 14, Style.MUTED))
		var nxt := Style.button("›", "SegBtn")
		nxt.disabled = page >= pages - 1
		nxt.pressed.connect(
			func() -> void:
				_turn(1),
		)
		_pager.add_child(nxt)
	var first := page * PER_PAGE
	for i in range(first, mini(first + PER_PAGE, levels.size())):
		var cell := Cell.new()
		var def: Dictionary = levels[i]
		cell.index = i
		cell.custom_minimum_size = Vector2(_tile, _tile)
		cell.tier = tier_of(def)
		cell.locked = i > open_index
		cell.stars = Store.stars_of(str(def.id))
		cell.done = Store.is_done(str(def.id))
		cell.next = i == first_unwon(levels, open_index)
		cell.mouse_entered.connect(
			func() -> void:
				_select(i),
		)
		cell.picked.connect(_pick)
		_grid.add_child(cell)
	var want := mini(first_unwon(levels, open_index), levels.size() - 1)
	_select(want if page_of(want) == page else first) # never show a level from another page

func _turn(d: int) -> void:
	page += d
	_build()

## tap / click: on another cell = select it (info); on the selected one = start it (if open)
func _pick(i: int) -> void:
	if i != sel:
		_select(i)
		return
	if i <= open_index:
		var def: Dictionary = levels[i]
		level_picked.emit(str(def.id))

func _select(i: int) -> void:
	sel = i
	for c in _grid.get_children():
		var cell := c as Cell
		if cell != null:
			cell.selected = cell.index == i
			cell.queue_redraw()
	_show_info(i)

## title, tier, goal, the 3 star goals of level i (+ best stars), and the play button
func _show_info(i: int) -> void:
	for c in _info.get_children():
		c.queue_free()
	if i < 0 or i >= levels.size():
		return
	var def: Dictionary = levels[i]
	var tier := tier_of(def)
	var locked := i > open_index
	var head := Style.hbox(10)
	head.add_child(Style.lbl("THỬ THÁCH %d" % (i + 1), 13, Style.MUTED, Style.bold))
	var tc: Color = TIER_COL[tier]
	head.add_child(Style.lbl(str(TIER_NAME[tier]).to_upper(), 13, tc, Style.bold))
	_info.add_child(head)
	_info.add_child(Style.lbl(str(def.get("title", "")), 26, Style.GOLD if not locked else Style.MUTED, Style.display))
	_info.add_child(Style.lbl(Menus.goal_text(def), 15, Style.INK, null, true))
	if def.has("stars"):
		var got := Store.stars_of(str(def.id))
		var goals := Stars.goals(def)
		for k in goals.size():
			var g: Dictionary = goals[k]
			var line := Style.hbox(8)
			var ic := HudWidgets.StarIcon.new()
			ic.custom_minimum_size = Vector2(16, 16)
			ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ic.on = k < got # best count kept, not which goals: light that many
			line.add_child(ic)
			var gl := Style.lbl(str(g.text), 14, Style.MUTED, null, true)
			gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(gl)
			_info.add_child(line)
	var note := "Thắng thử thách trước để mở" if locked else ("Bấm để chơi lại" if Store.is_done(str(def.id)) else "Bấm để vào trận")
	_info.add_child(Style.lbl(note, 13, Style.MUTED))
	if not locked:
		var b := Style.menu_button("Vào trận ›", "", true)
		b.pressed.connect(
			func() -> void:
				_pick(i),
		)
		_info.add_child(b)

## one level: number, tier band, 0–3 stars, lock; "next" = the first not yet won (gold ring)
class Cell extends Control:
	signal picked(index: int)

	var index := 0
	var tier := "mid"
	var locked := false
	var done := false
	var next := false
	var selected := false
	var stars := 0

	func _init() -> void:
		custom_minimum_size = Vector2(LevelSelect.TILE, LevelSelect.TILE)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND

	func _gui_input(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(index)
			accept_event()

	func _draw() -> void:
		var hot := (selected or get_global_rect().has_point(get_global_mouse_position())) and not locked
		var col: Color = LevelSelect.TIER_COL[tier]
		# F1 paper tile: ink edge + hard shadow; next / hovered = gold face, crimson inner line; locked = faded paper
		var box := SkinBox.make(Style.PAPER_HI, Vector4.ZERO, { "shadow": Vector2(3, 3), "radii": Vector4(10, 7, 12, 6), "edge_w": 2.5 })
		if locked:
			box.face = Color("#e6d3a8")
			box.edge = Style.FADED
			box.shadow_col = Style.FADED
		elif next or hot:
			box.face = Color("#f6dc8e")
			box.inner = Style.CRIMSON
		draw_style_box(box, Rect2(Vector2.ZERO, size - Vector2(3, 3)))
		var k := minf(size.x, size.y) / LevelSelect.TILE # content scales with the tile on short screens
		draw_rect(Rect2(7 * k, size.y - 13 * k, size.x - 17 * k, 4 * k), Color(col, 0.9 if not locked else 0.35))
		var c := Vector2((size.x - 3) / 2, size.y * 0.42)
		if locked:
			var lk := 22.0 * k
			draw_texture_rect(Icons.tex("lock"), Rect2(c - Vector2(lk, lk) / 2, Vector2(lk, lk)), false, Color(1, 1, 1, 0.55))
		else:
			Draw.text_c(self, Style.display, c, str(index + 1), roundi(28 * k), Style.CRIMSON_D if done or next else Style.INK)
		if not locked:
			for j in 3:
				var sc := Vector2((size.x - 3) / 2 + (j - 1) * 17 * k, size.y - 24 * k)
				var on := j < stars
				Draw.star(self, sc, 7.0 * k, Style.LEAF if on else Style.PAPER_2, Style.INK_D, 1.0)
