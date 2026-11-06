class_name StoryOverlay
extends Control
## mission opening over the map: title card, then the story one speaker line at a time (typewriter) in a bottom band.
## tap / Space / Enter: finish the line, then next · hold (mouse / Space) or »» Tua: fast auto-play · Bỏ qua / Esc: skip all.
## Emits done once (finished, skipped or closed); the caller awaits it.

signal done

const CPS := 45.0 # typewriter chars / s
const FAST := 5.0 # typewriter x while held / Tua on
const AUTO_HOLD := 0.55 # s a finished line stays up while fast
const TITLE_SEC := 2.6
const BAND_W := 940.0
const PORTRAIT := 64.0

var audio: Audio = null
var _lines: Array = []
var _i := -1
var _shown := 0.0
var _total := 0
var _phase := "" # title | talk | out
var _t := 0.0
var _born := 0
var _auto := false
var _held := false
var _done := false
var _dim: ColorRect
var _title: PanelContainer
var _band: PanelContainer
var _band_box: StyleBoxFlat
var _row: HBoxContainer
var _who: PanelContainer
var _who_box: StyleBoxFlat
var _icon: Label
var _name: Label
var _count: Label
var _text: Label
var _cue: Label
var _btn_auto: Button

## [speaker, text] lines a mission opens with: history (narrator), the story intro, then the goal
static func lines_for(def: Dictionary) -> Array:
	var out: Array = []
	var history: String = def.get("history", "")
	if history != "":
		out.append(["sutich", history])
	var story: Dictionary = def.get("story", {})
	var intro: Array = story.get("intro", [])
	out.append_array(intro)
	out.append(["muctieu", Menus.goal_text(def)])
	return out

## ctx.story is set only when a campaign mission is entered fresh (map / next mission), never on continue / restart
static func should_play(ctx: Dictionary, flags: Dictionary) -> bool:
	var want: bool = ctx.get("story", false)
	if not want or ctx.get("kind") != "campaign":
		return false
	return flags.has("story") or not (flags.has("bot") or flags.has("nointro"))

static func eyebrow(def: Dictionary) -> String:
	var cid := Content.chapter_of(def)
	var ms := Content.missions_of(cid)
	return "Chương %d · Màn %d/%d" % [Content.chapters().find(Content.chapter(cid)) + 1, ms.find(def) + 1, ms.size()]

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100 # over the HUD (40), popup (50), end card (60); same layer as the new-unit card
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.01, 0.0, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	gui_input.connect(_on_gui_input)
	resized.connect(_place)

## title card (title, place, chapter / mission) then lines; returns at once, await done
func start(def: Dictionary, lines: Array) -> void:
	_lines = lines
	_born = Time.get_ticks_msec()
	_build_title(def)
	_build_band()
	_place()
	_phase = "title"
	_t = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.42, 0.35)
	_title.modulate.a = 0.0
	tw.tween_property(_title, "modulate:a", 1.0, 0.35)

## drop everything now (leaving the game mid-story)
func close() -> void:
	_finish(false)

func skip() -> void:
	if audio:
		audio.play("ui")
	_finish(true)

func _finish(fade: bool) -> void:
	if _done:
		return
	_done = true
	_phase = "out"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	done.emit()
	if not fade or not is_inside_tree():
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)

func _build_title(def: Dictionary) -> void:
	_title = PanelContainer.new()
	var bs := Style.box(Color(0.06, 0.035, 0.025, 0.9), Style.BRONZE_2, 0, 18)
	bs.border_width_left = 0; bs.border_width_right = 0; bs.border_width_top = 2; bs.border_width_bottom = 2
	_title.add_theme_stylebox_override("panel", bs)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	var v := Style.vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_title.add_child(v)
	var eb := Style.lbl(eyebrow(def).to_upper(), 14, Style.BRONZE, Style.xbold)
	var title: String = def.get("title", "")
	var place: String = def.get("place", "")
	var tl := Style.lbl(title, 52, Style.GOLD, Style.display_x)
	tl.add_theme_color_override("font_shadow_color", Color("#4a2c0e"))
	tl.add_theme_constant_override("shadow_offset_y", 3)
	var pl := Style.lbl(place, 17, Style.MUTED)
	for l: Label in [eb, tl, pl]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)

func _build_band() -> void:
	_band = PanelContainer.new()
	_band_box = Style.box(Color(0.075, 0.045, 0.03, 0.95), Style.BRONZE_2, 14, 14, 2)
	_band_box.shadow_color = Color(0, 0, 0, 0.55); _band_box.shadow_size = 18; _band_box.shadow_offset = Vector2(0, 6)
	_band_box.content_margin_left = 16; _band_box.content_margin_right = 16
	_band.add_theme_stylebox_override("panel", _band_box)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.visible = false
	add_child(_band)
	_row = Style.hbox(14)
	_band.add_child(_row)
	_who = PanelContainer.new()
	_who.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	_who.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_who.pivot_offset = Vector2(PORTRAIT, PORTRAIT) / 2
	_who_box = Style.box(Style.LACQUER_3, Style.BRONZE_2, 99, 0, 2)
	_who.add_theme_stylebox_override("panel", _who_box)
	_icon = Style.lbl("", 32)
	_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_who.add_child(_icon)
	_row.add_child(_who)
	var v := Style.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(v)
	var head := Style.hbox(8)
	v.add_child(head)
	_name = Style.lbl("", 20, Style.GOLD, Style.display)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_name)
	_count = Style.lbl("", 13, Style.MUTED, Style.semi)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count)
	_btn_auto = Style.button("»» Tua", "SegBtn")
	_btn_auto.tooltip_text = "Tự chạy nhanh hết thoại (giữ chuột / Space cũng tua)"
	_btn_auto.toggle_mode = true
	_btn_auto.focus_mode = Control.FOCUS_NONE
	_btn_auto.toggled.connect(func(on: bool) -> void:
		_auto = on
		_btn_auto.theme_type_variation = "SegOn" if on else "SegBtn")
	head.add_child(_btn_auto)
	var sk := Style.button("Bỏ qua ›", "ActBtn")
	sk.tooltip_text = "Bỏ qua cốt truyện, vào trận (Esc)"
	sk.focus_mode = Control.FOCUS_NONE
	sk.pressed.connect(skip)
	head.add_child(sk)
	_text = Style.lbl("", 18, Style.INK, null, true)
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING # wrap fixed up front: words never jump lines
	_text.custom_minimum_size.y = 50 # 2 lines: the band keeps its height line to line
	v.add_child(_text)
	_cue = Style.lbl("Chạm / Space: tiếp  ›", 12, Style.MUTED)
	_cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_cue)

## title band across the middle; talk band at the bottom, centred, ≤ BAND_W wide (phone: full width minus a gutter)
func _place() -> void:
	if _title == null:
		return
	_title.size = Vector2(size.x, _title.get_combined_minimum_size().y)
	_title.position = Vector2(0, (size.y - _title.size.y) * 0.42)
	var w := minf(BAND_W, size.x - 24.0)
	var h := _band.get_combined_minimum_size().y
	_band.size = Vector2(w, h)
	_band.position = Vector2((size.x - w) / 2, size.y - h - 12.0)

func _to_talk() -> void:
	_phase = "talk"
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void: _title.visible = false)
	_band.visible = true
	_band.modulate.a = 0.0
	var tb := create_tween()
	tb.tween_property(_band, "modulate:a", 1.0, 0.2)
	_next()

func _next() -> void:
	_i += 1
	if _i >= _lines.size():
		_finish(true)
		return
	var line: Array = _lines[_i]
	var key: String = line[0]
	var text: String = line[1]
	var prev := ""
	if _i > 0:
		var pl: Array = _lines[_i - 1]
		prev = pl[0]
	var sp := Content.speaker(key)
	var foe := Content.is_foe(key)
	var sname: String = sp.name
	var icon: String = sp.icon
	var narrator := key == "sutich"
	var goal := key == "muctieu"
	var accent := Style.SEA_HI if foe else (Style.BRONZE if narrator else Style.GOLD)
	_icon.text = icon
	_name.text = sname
	_name.add_theme_color_override("font_color", accent)
	_text.text = text
	_text.add_theme_color_override("font_color", Style.GOLD_HI if goal else (Style.MUTED if narrator else Style.INK))
	_count.text = "%d/%d" % [_i + 1, _lines.size()]
	_who_box.bg_color = Color("#10353a") if foe else Style.LACQUER_3
	_who_box.border_color = Style.SEA_HI if foe else Style.BRONZE_2
	_band_box.border_color = Color(Style.SEA, 0.9) if foe else (Style.GOLD if goal else Style.BRONZE_2)
	_row.move_child(_who, -1 if foe else 0) # enemy speaks from the right
	_cue.text = "Chạm / Space: vào trận  ›" if _i == _lines.size() - 1 else "Chạm / Space: tiếp  ›"
	_shown = 0.0
	_total = _text.get_total_character_count()
	_text.visible_characters = 0
	_t = 0.0
	if key != prev:
		_who.scale = Vector2(0.75, 0.75)
		var tw := create_tween()
		tw.tween_property(_who, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_place.call_deferred()

func _tap() -> void:
	if Time.get_ticks_msec() - _born < 250: # the click that opened the mission
		return
	if _phase == "title":
		_to_talk()
	elif _phase == "talk":
		if _shown < _total:
			_shown = _total
			_text.visible_characters = -1
		else:
			if audio:
				audio.play("ui")
			_next()

func _process(dt: float) -> void:
	if _phase == "title":
		_t += dt
		if _t >= TITLE_SEC or _auto or _held:
			_to_talk()
	elif _phase == "talk":
		var fast := _auto or _held
		if _shown < _total:
			_shown = minf(_total, _shown + dt * CPS * (FAST if fast else 1.0))
			_text.visible_characters = -1 if _shown >= _total else int(_shown)
			_t = 0.0
		elif fast:
			_t += dt
			if _t >= AUTO_HOLD:
				_next()
		_cue.modulate.a = (0.55 + 0.45 * sin(Time.get_ticks_msec() / 260.0)) if _shown >= _total else 0.0

func _on_gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_held = mb.pressed
	if mb.pressed:
		_tap()
	accept_event()

## keys before the game screen / main see them (they would act on the board or cancel)
func _input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k == null or _done or _phase == "":
		return
	match k.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_held = k.pressed
			if k.pressed and not k.echo:
				_tap()
		KEY_ESCAPE:
			if k.pressed and not k.echo:
				skip()
		_:
			return
	get_viewport().set_input_as_handled()
