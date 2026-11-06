class_name RigCam
extends RefCounted
## spec world (side view: hero tile x 0..256, target tile at TX = 256 * real distance, ground y = feet) -> board px.
## Two upright frames, blended by a weight w per point (0 = hero frame, 1 = target frame):
##   H: origin = attacker's feet, x = facing f (+1 right / -1 left), scale ca (the attacker token's px per art unit)
##   G: origin = target's feet, x = along the real attack direction u, scale cd (the target token's px per art unit)
## In both, world y stays screen-vertical, so the art, tornadoes, numbers and gravity stay upright. For a target
## straight left / right H and G are parallel and only differ by the token-vs-tile size gap.
## Default w for a bare world x = ramp from the hero's front (cx + 64) to the target's front (xt - 64);
## travelling FX (wave, projectile) carry their own w from launch (0) to impact (1). See docs/rig_port.md.

var Fa := Vector2.ZERO # attacker feet (world (cx, feet)) in board px
var Fd := Vector2.ZERO # target feet (world (xt, feet))
var u := Vector2.RIGHT # attack direction (board px, unit)
var f := 1.0 # facing of the art
var ca := 0.25 # px per world unit at the attacker
var cd := 0.25 # px per world unit at the target
var CX := 128.0
var FEET := 244.0
var TX := 256.0 # target tile left edge, world
var xt := 384.0 # target centre x, world (TX + 128)
var xhf := 192.0 # ramp start
var xtf := 320.0 # ramp end
var T := 64.0 # tile px

func w_of(x: float) -> float:
	if xtf <= xhf:
		return 0.0 if x < xhf else 1.0
	return clampf((x - xhf) / (xtf - xhf), 0.0, 1.0)

## world point -> board px; w < 0 = default ramp by x
func map(x: float, y: float, w := -1.0) -> Vector2:
	if w < 0.0:
		w = w_of(x)
	var h := Fa + Vector2(f * (x - CX), y - FEET) * ca
	if w <= 0.0:
		return h
	var g := Fd + u * ((x - xt) * cd) + Vector2(0.0, (y - FEET) * cd)
	return h.lerp(g, w)

func mapv(p: Vector2, w := -1.0) -> Vector2:
	return map(p.x, p.y, w)

## px per world unit at weight w
func k(w := 0.0) -> float:
	return lerpf(ca, cd, clampf(w, 0.0, 1.0))

## upright local frame at a world point: 1 local unit = 1 world unit, local +x = the art's forward (mirrored for f = -1).
## Use like the engine's cam.translate(x, y): ctx.set_xf(cam.frame(x, y).rotated_local(deg_to_rad(a)))
func frame(x: float, y: float, w := -1.0) -> Transform2D:
	if w < 0.0:
		w = w_of(x)
	var s := k(w)
	return Transform2D(Vector2(f * s, 0.0), Vector2(0.0, s), map(x, y, w))

## frame whose local +x points along a board-space direction (directional shapes: wave crescent, flying blade)
func aimed(at: Vector2, dir: Vector2, s: float) -> Transform2D:
	var ang := atan2(dir.y, f * dir.x)
	return Transform2D(Vector2(f * s, 0.0), Vector2(0.0, s), at) * Transform2D(ang, Vector2.ZERO)

## where the character's root stands for root channels (px, py): the lunge / leap goes along the real attack line
func root(px: float, py: float) -> Vector2:
	var x := CX + px
	var w := w_of(x)
	var h := Fa + u * (px * ca)
	if w > 0.0:
		h = h.lerp(Fd + u * ((x - xt) * cd), w)
	return h + Vector2(0.0, py * ca)

## character-local (art units, root translation excluded) -> board px
func char_xf(px: float, py: float) -> Transform2D:
	return Transform2D(Vector2(f * ca, 0.0), Vector2(0.0, ca), root(px, py)) * Transform2D(0.0, Vector2(-CX, -FEET))
