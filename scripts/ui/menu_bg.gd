class_name MenuBg
extends Control
## animated menu backdrop: parchment page with a woodcut landscape (shader), drifting gold-leaf flecks, toasted edges.
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
	fx.draw.connect(_draw_fx)
	add_child(fx)
	vig = _rect(VIG_SHADER)
	resized.connect(_fit)
	visibility_changed.connect(
		func() -> void:
			set_process(is_visible_in_tree()),
	)
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
		var ep: float = e.p
		e.y -= e.v * k
		e.x += sin(t / 800.0 + ep) * 0.4 * k
	embers = embers.filter(
		func(e: Dictionary) -> bool:
			return e.y > -10,
	)
	fx.queue_redraw()

func _draw_fx() -> void:
	var H := size.y
	# (the JS version also drew sun glints on the river; removed: they showed through between the campaign cards as stray dashes)
	for e: Dictionary in embers:
		var ex: float = e.x
		var ey: float = e.y
		var ep: float = e.p
		var er: float = e.r
		var a := clampf(ey / H, 0.0, 1.0) * (0.5 + 0.5 * sin(t / 200.0 + ep))
		fx.draw_circle(Vector2(ex, ey), er, Color(0.78, 0.56, 0.18, a * 0.7), true, -1.0, true)
