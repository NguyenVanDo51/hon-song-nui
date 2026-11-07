class_name QuestPanel
extends Control
## top-right quest slip under ⏩ ⚙ (spec §5): collapsed = 📜 current quest + done/total, tap = whole list (✓ struck / ▢ /
## ★ win line bold), shuts after 4 s. Fades + clicks through while it covers board content (set_covered). A quest done:
## ✓ stamp pops mid-screen, flies into the slip, the line strikes, next quest. Never blocks input. No quests: win line only.
## GameHud places it (place_hud) and hides it like Hết lượt; GameScreen / TurnDriver feed celebrate() from Quests.

const W_MAX := 270.0 # longer lines wrap
const AUTO_CLOSE := 4.0
const FADED := 0.2
const STAMP := Vector2(320, 170)

var s: Dictionary = { }
var win_line := "" # bbcode, no icon
var open := false
var covered := false
var sfx: Callable = func() -> void:
	pass

var _slip: PanelContainer
var _icon: TextureRect
var _head: RichTextLabel
var _pill: Label
var _list: VBoxContainer
var _key := ""
var _queue: Array = []
var _held: Array = [] # done, stamp comes after the action plays (hold): still shown open
var _busy := false
var _flash := -1 # quest shown struck in the collapsed line while its stamp lands
var _flying := -1 # quest whose stamp is in the air: still shown open
var _stamp: Control = null
var _tw: Tween = null
var _close_tw: Tween = null
var _fade_tw: Tween = null
var _tags := RegEx.create_from_string("\\[[^\\]]*\\]")

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	_slip = PanelContainer.new()
	var b := Style.paper(8.0, 6.0)
	b.frame = false
	b.content_margin_top = 6
	b.content_margin_bottom = 8
	_slip.add_theme_stylebox_override("panel", b)
	_slip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_slip.gui_input.connect(_on_input)
	_slip.minimum_size_changed.connect(update_minimum_size)
	add_child(_slip)
	var v := Style.vbox(4)
	_slip.add_child(v)
	var head := Style.hbox(6)
	v.add_child(head)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(18, 18)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_icon)
	_head = Style.rich("", 14, Style.INK, Style.CRIMSON_D)
	_head.add_theme_font_override("normal_font", Style.semi)
	_head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_head)
	_pill = Style.lbl("", 12, Style.PAPER_HI, Style.bold)
	_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_pill)
	_list = Style.vbox(3)
	_list.visible = false
	v.add_child(_list)

func _get_minimum_size() -> Vector2:
	return _slip.get_combined_minimum_size() if _slip != null else Vector2.ZERO

## new game / loaded save: drop any running stamp, show s
func bind(state: Dictionary, win: String) -> void:
	s = state
	win_line = win
	open = false
	_queue.clear()
	_held.clear()
	_busy = false
	_flash = -1
	_flying = -1
	for tw: Tween in [_tw, _close_tw]:
		if tw != null:
			tw.kill()
	if _stamp != null:
		_stamp.queue_free()
		_stamp = null
	set_covered(false)
	_key = ""
	refresh()

func refresh() -> void:
	var qs := _quests()
	var shown: Array[bool] = [] # done and its stamp has landed
	var done := 0
	var cur := -1
	for i in qs.size():
		shown.append(qs[i].done and not _queue.has(i) and not _held.has(i) and i != _flying)
		done += 1 if shown[i] else 0
		if cur < 0 and not shown[i]:
			cur = i
	var key := "%s|%s|%d|%s" % [win_line, open, _flash, shown]
	if key == _key:
		return
	_key = key
	_icon.texture = Icons.tex("target" if qs.is_empty() else "scroll")
	if _flash >= 0:
		_set_text(_head, "[color=#%s][s]%s[/s][/color]" % [Style.GOOD.to_html(false), _text(_flash)])
	elif cur >= 0:
		_set_text(_head, _text(cur))
	else:
		_set_text(_head, win_line)
	_pill.visible = not qs.is_empty()
	_pill.text = "%d/%d" % [done, qs.size()]
	var pb := Style.box(Style.GOOD if done == qs.size() else Style.BRONZE_2, Color.TRANSPARENT, 8, 0.0)
	pb.content_margin_left = 6
	pb.content_margin_right = 6
	pb.content_margin_top = 1
	pb.content_margin_bottom = 2
	_pill.add_theme_stylebox_override("normal", pb)
	for c in _list.get_children():
		c.queue_free()
		_list.remove_child(c)
	_list.visible = open and not qs.is_empty()
	if not _list.visible:
		return
	var hr := ColorRect.new()
	hr.color = Color(Style.INK_D, 0.25)
	hr.custom_minimum_size.y = 1
	hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(hr)
	for i in qs.size():
		var t := _text(i)
		_row("done" if shown[i] else "todo", "[color=#%s][s]%s[/s][/color]" % [Style.MUTED.to_html(false), t] if shown[i] else t)
	_row("win", "[b]%s[/b]" % win_line)

## quests done in one go (Quests.observe / note): one stamp each, in turn
func celebrate(indexes: Array) -> void:
	if indexes.is_empty() or _quests().is_empty():
		return
	for i: int in indexes:
		_held.erase(i)
	_queue.append_array(indexes)
	if not _busy:
		_next()
	else:
		refresh()

## done while its action is still playing: keep them open until celebrate()
func hold(indexes: Array) -> void:
	_held.append_array(indexes)
	refresh()

## covering board content: almost transparent and clicks fall through to the map
func set_covered(on: bool) -> void:
	if covered == on:
		return
	covered = on
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slip.mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP
	if _fade_tw != null:
		_fade_tw.kill()
	_fade_tw = create_tween()
	_fade_tw.tween_property(self, "modulate:a", FADED if on else 1.0, 0.15)

## B: any unit, the hovered tile, reach or path tile under the slip -> covered
func update_cover(board: Board, origin: Vector2) -> void:
	if s.is_empty() or not visible:
		set_covered(false)
		return
	var v: Dictionary = board.view
	var tiles: Array[Vector2i] = []
	for u: Dictionary in s.units:
		var ux: int = u.x
		var uy: int = u.y
		tiles.append(Vector2i(ux, uy))
	if v.hover != null:
		var hv: Vector2i = v.hover
		tiles.append(hv)
	if v.reach != null:
		var reach: Dictionary = v.reach
		for k: Vector2i in reach:
			tiles.append(k)
	if v.path != null:
		var path: Array = v.path
		for p: Array in path:
			var px: int = p[0]
			var py: int = p[1]
			tiles.append(Vector2i(px, py))
	var me := get_rect()
	var hit := false
	for t: Vector2i in tiles:
		var r := board.tile_rect(t.x, t.y)
		r.position += origin
		if r.grow(-r.size.x * 0.15).intersects(me): # a sliver under the edge does not count
			hit = true
			break
	set_covered(hit)

# ---------- inside ----------
func _quests() -> Array:
	return s.get("quests", [])

func _text(i: int) -> String:
	var q: Dictionary = _quests()[i]
	return Quests.text(q)

func _on_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or _quests().is_empty():
		return
	_slip.accept_event()
	sfx.call()
	open = not open
	refresh()
	if _close_tw != null:
		_close_tw.kill()
	if open:
		_close_tw = create_tween()
		_close_tw.tween_interval(AUTO_CLOSE)
		_close_tw.tween_callback(
			func() -> void:
				open = false
				refresh(),
		)

## one line in the open list: drawn mark + text
func _row(kind: String, bb: String) -> void:
	var h := Style.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Mark.new(kind))
	var r := Style.rich("", 13, Style.INK, Style.CRIMSON_D)
	h.add_child(r)
	_set_text(r, bb)
	_list.add_child(h)

## text on one line up to W_MAX, wrapped past it
func _set_text(r: RichTextLabel, bb: String) -> void:
	var px: int = r.get_theme_font_size("normal_font_size")
	r.text = Icons.bb_text(Style.bold_in(bb, Style.CRIMSON_D), px + 3)
	var w := Style.bold.get_string_size(_tags.sub(bb, "", true), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 4.0
	r.autowrap_mode = TextServer.AUTOWRAP_OFF if w <= W_MAX else TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size.x = minf(w, W_MAX)

func _next() -> void:
	_flash = -1
	_busy = not _queue.is_empty()
	refresh()
	if not _busy:
		return
	var idx: int = _queue.pop_front()
	_flying = idx
	var host := get_parent() as Control
	var st := Control.new()
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.z_index = 45 # over the HUD, under the orders popup / end card
	st.size = STAMP
	st.pivot_offset = STAMP / 2
	st.position = ((host.size - STAMP) / 2).floor()
	var disc := Stamp.new()
	disc.size = Vector2(STAMP.x, 112)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(disc)
	var l := Style.lbl(_text(idx), 22, Style.PAPER_HI, Style.display_x)
	Style.ink_outline(l, 7)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, 118)
	l.size = Vector2(STAMP.x, 40)
	st.add_child(l)
	host.add_child(st)
	_stamp = st
	st.scale = Vector2.ZERO
	sfx.call()
	var dest := position + Vector2(size.x / 2.0, 18.0) - STAMP / 2
	_tw = create_tween()
	_tw.tween_property(st, "scale", Vector2(1.6, 1.6), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(st, "scale", Vector2.ONE, 0.14)
	_tw.tween_interval(0.35)
	_tw.tween_property(st, "position", dest, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.parallel().tween_property(st, "scale", Vector2(0.15, 0.15), 0.38)
	_tw.parallel().tween_property(st, "modulate:a", 0.4, 0.38)
	_tw.tween_callback(_land.bind(idx))
	_tw.tween_interval(0.7)
	_tw.tween_callback(_next)

func _land(idx: int) -> void:
	if _stamp != null:
		_stamp.queue_free()
		_stamp = null
	_flying = -1
	_flash = idx
	refresh()
	pivot_offset = size / 2
	var bump := create_tween()
	bump.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08)
	bump.tween_property(self, "scale", Vector2.ONE, 0.16)

static func check(ci: CanvasItem, r: Rect2, col: Color, w: float) -> void:
	var pts := PackedVector2Array(
		[r.position + r.size * Vector2(0.1, 0.55), r.position + r.size * Vector2(0.4, 0.85), r.position + r.size * Vector2(0.92, 0.15)],
	)
	ci.draw_polyline(pts, Style.INK_D, w + 3.0, true)
	ci.draw_polyline(pts, col, w, true)

## row mark, drawn (no bundled font has ✓ / ▢): done = check, todo = empty box, win = star, miss = red box
class Mark extends Control:
	var kind := "todo"

	func _init(k := "todo", px := 16.0) -> void:
		kind = k
		custom_minimum_size = Vector2(px, px)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size).grow(-1.5)
		match kind:
			"win":
				Draw.star(self, size / 2, size.x * 0.55, Style.LEAF, Style.INK_D, 1.2)
			"done":
				QuestPanel.check(self, r, Style.GOOD, 2.5)
			_:
				draw_rect(r, Style.PAPER_HI)
				draw_rect(r, Style.BAD if kind == "miss" else Style.INK_D, false, 1.5)

## the big ✓ seal of a finished quest
class Stamp extends Control:
	func _draw() -> void:
		var c := Vector2(size.x / 2, size.y / 2)
		var r := size.y * 0.46
		draw_circle(c + Vector2(4, 5), r + 3, Color(Style.INK_D, 0.35))
		draw_circle(c, r + 3, Style.INK_D)
		draw_circle(c, r, Style.PAPER_HI)
		draw_arc(c, r - 7, 0.0, TAU, 48, Style.GOOD, 2.5, true)
		QuestPanel.check(self, Rect2(c - Vector2(r, r) * 0.55, Vector2(r, r) * 1.1), Style.GOOD, 9.0)
