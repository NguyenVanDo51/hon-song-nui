class_name Baked
extends SubViewport
## draws `paint` once into an offscreen texture (re-armed by bake()), so static art costs one textured quad per frame
## instead of replaying thousands of canvas commands. Rendered at screen resolution (canvas_items stretch scale).

var painter: Painter

class Painter extends Control:
	var fn: Callable

	func _draw() -> void:
		Draw.xf = Transform2D.IDENTITY
		if fn.is_valid():
			fn.call(self)

func _init(paint: Callable) -> void:
	transparent_bg = true
	disable_3d = true
	gui_disable_input = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	painter = Painter.new()
	painter.fn = paint
	painter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(painter)

## render `px` canvas units of art at `scale` screen px per unit; the texture is ready this frame
func bake(px: Vector2, scale: float) -> void:
	var sz := Vector2i(maxi(1, ceili(px.x * scale)), maxi(1, ceili(px.y * scale)))
	size = sz
	# exact texel : canvas-unit ratio so the texture maps 1:1 onto the screen
	canvas_transform = Transform2D(0.0, Vector2(sz.x / px.x, sz.y / px.y), 0.0, Vector2.ZERO)
	painter.size = px
	painter.queue_redraw()
	render_target_update_mode = SubViewport.UPDATE_ONCE

## screen px per canvas unit for a control (window stretch included)
static func screen_scale(c: CanvasItem) -> float:
	return clampf(c.get_viewport().get_final_transform().get_scale().x * c.get_global_transform_with_canvas().get_scale().x, 0.5, 4.0)
