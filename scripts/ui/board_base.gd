class_name BoardBase
extends Control
## what the 2D Board and the 3D Board3D share: GameScreen's surface (signals, s, fx, T, view, hover), mouse input
## (only the tile picker differs), close-up easing, the list of figures to draw, the selected-unit pulse.

signal tile_clicked(x: int, y: int)
signal hover_changed(tile: Variant)
signal cancel_requested
signal info_requested(id: int)

var s: Dictionary = { }
var fx: FX
var T := 48.0
## what the game screen wants shown (see GameScreen.build_view)
var view := {
	"hide": { },
	"hold": { },
	"razable": [],
	"razeAt": null,
	"sprites": [],
	"hp": null,
	"busy": false,
	"sel": null,
	"selMine": false,
	"reach": null,
	"attackable": [],
	"dest": null,
	"targets": [],
	"target": null,
	"path": null,
	"info": null,
	"buyAt": null,
	"hover": null,
	"preview": null,
	"threat": null,
	"threatFill": null,
	"danger": [],
}
var hover: Variant = null
var _info_hit_id := -1

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

## tile under p (control px), null = off the map
func _pick(_p: Vector2) -> Variant:
	return null

## a tile's rectangle in the parent's coordinates (popup placement)
func tile_rect(_x: int, _y: int) -> Rect2:
	return Rect2()

## board API used by GameScreen; Board / Board3D override
func set_state(_state: Dictionary) -> void:
	pass

func refresh_terrain() -> void:
	pass

func fit(_avail: Vector2) -> void:
	pass

## close-up on an exchange (awaitable); unfocus() eases back
func focus(_a: Vector2i, _b: Vector2i) -> void:
	await get_tree().process_frame

func unfocus() -> void:
	await get_tree().process_frame

## unit id whose ⓘ dot is under p, else -1
func _info_at(_p: Vector2) -> int:
	return -1

func _gui_input(ev: InputEvent) -> void:
	if s.is_empty():
		return
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var info_id := _info_at(mb.position)
			if info_id >= 0:
				info_requested.emit(info_id)
			else:
				var tl: Variant = _pick(mb.position)
				if tl != null:
					var c: Vector2i = tl
					tile_clicked.emit(c.x, c.y)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			cancel_requested.emit()
		accept_event()
	elif ev is InputEventMouseMotion:
		var mm: InputEventMouseMotion = ev
		var ih := _info_at(mm.position)
		if ih != _info_hit_id:
			_info_hit_id = ih
			tooltip_text = "Xem thông tin quân" if ih >= 0 else ""
		var tl: Variant = _pick(mm.position)
		if tl != hover:
			hover = tl
			hover_changed.emit(tl)

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hover != null:
		hover = null
		hover_changed.emit(null)

## awaitable close-up amount from -> to over ms: going in eases out (cubic), going back is a smoothstep
func _ease_focus(ms: float, from: float, to: float, apply: Callable) -> void:
	var going_in := to > 0.0
	await fx.tween(
		ms,
		func(k: float) -> void:
			apply.call(lerpf(from, to, 1.0 - pow(1.0 - k, 3.0) if going_in else k * k * (3.0 - 2.0 * k))),
	)

## this frame's figures: live units (minus hidden), moving / dying sprites, fading corpses.
## Each { u, x, y, kind "u" | "s" | "g", alpha (-1 = opaque), k (corpse fade 0..1, -1 = not a corpse),
## stack (offset of a 2nd unit on one tile, just bought on an occupied castle; the first one moves aside) }
func _figures(time: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := { } # tile -> the unit already there
	var hidden_ids: Dictionary = view.hide
	for u: Dictionary in s.units:
		if hidden_ids.has(u.id):
			continue
		var ux: int = u.x
		var uy: int = u.y
		var at := Vector2i(ux, uy)
		var it := { "u": u, "x": float(ux), "y": float(uy), "kind": "u", "alpha": -1.0, "k": -1.0, "stack": Vector2.ZERO }
		if seen.has(at):
			it.stack = Vector2(0.24, 0.06)
			var first: Dictionary = seen[at]
			first.stack.x -= 0.2
		seen[at] = it
		out.append(it)
	for sp: Dictionary in view.sprites:
		if not sp.get("hidden", false):
			var su: Dictionary = sp.u
			var sx: float = su.x # tweened: fractional mid-move
			var sy: float = su.y
			out.append({ "u": su, "x": sx, "y": sy, "kind": "s", "alpha": sp.get("alpha", -1.0), "k": -1.0, "stack": Vector2.ZERO })
	for g: Dictionary in fx.ghosts:
		var gu: Dictionary = g.u
		var gx: float = gu.x
		var gy: float = gu.y
		var t0: float = g.t0
		var dur: float = g.dur
		var kk: float = clampf((time - t0) / dur, 0.0, 1.0)
		out.append({ "u": gu, "x": gx, "y": gy, "kind": "g", "t0": g.t0, "alpha": 1.0 - kk * kk, "k": kk, "stack": Vector2.ZERO })
	return out

## ring / glow colour under the selected unit, pulsing
static func sel_color(time: float) -> Color:
	return Color(1, 0.878, 0.541, 0.6 + sin(time / 160.0) * 0.4)
