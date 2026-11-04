class_name MenuBg
extends Control
## animated menu backdrop: shader sky / sun / ridges / river, CPU rising embers, vignette on top.
## Port of drawBg in src/ui/screens.js. Only animates while visible.

const BG_SHADER := preload("res://shaders/menu_bg.gdshader")
const VIG_SHADER := preload("res://shaders/vignette.gdshader")

var sky: ColorRect
var fx: Control
var vig: ColorRect
var embers: Array = []
var t := 0.0

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky = _rect(BG_SHADER)
	fx = Control.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx.material = add
	fx.draw.connect(_draw_fx)
	add_child(fx)
	vig = _rect(VIG_SHADER)
	resized.connect(_fit)
	visibility_changed.connect(func() -> void: set_process(is_visible_in_tree()))
	_fit()

func _rect(sh: Shader) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	add_child(r)
	return r

func _fit() -> void:
	for r: ColorRect in [sky, vig]:
		if r:
			(r.material as ShaderMaterial).set_shader_parameter("size", size)

func _process(dt: float) -> void:
	t += dt * 1000.0
	var W := size.x
	var H := size.y
	if embers.size() < 40:
		embers.append({ "x": randf() * W, "y": H + 10, "v": 0.2 + randf() * 0.6, "p": randf() * 6, "r": 1 + randf() * 2 })
	var k := dt * 60.0
	for e: Dictionary in embers:
		e.y -= e.v * k
		e.x += sin(t / 800.0 + e.p) * 0.4 * k
	embers = embers.filter(func(e: Dictionary) -> bool: return e.y > -10)
	fx.queue_redraw()

func _draw_fx() -> void:
	var H := size.y
	# (the JS version also drew sun glints on the river; removed: they showed through between the campaign cards as stray dashes)
	for e: Dictionary in embers:
		var a := clampf(e.y / H, 0.0, 1.0) * (0.5 + 0.5 * sin(t / 200.0 + e.p))
		fx.draw_circle(Vector2(e.x, e.y), e.r, Color(1, 0.706, 0.353, a), true, -1.0, true)
