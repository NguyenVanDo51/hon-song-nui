class_name RigSpec
extends RefCounted
## the hand-ported functions of one docs/anim_demo/<unit>.spec.js. Data (parts, bones, tracks, points, consts) comes
## from the exported JSON (`data`); subclass this in scripts/ui/rig/specs/<unit>.gd and override what the JS defines.
## Every override mirrors the JS 1:1 — see docs/rig_port.md for the API mapping.

var data: RigData

## attack `ev`: [[t_ms, func(a: Rig) -> void], ...] for r.A.id. Built when the attack starts, so timings may read
## r.target().front etc. (real distance) instead of the demo's range constant.
func events(_r: Rig) -> Array:
	return []

## springs[name].drive(p, vx, {idle, clock}) -> target angle
func drive(_name: String, _p: Dictionary, _vx: float, _ctx: Dictionary) -> float:
	return 0.0

## idle(p, breath, clock): only for rest-pose checks (the game shows the token between attacks)
func idle(_p: Dictionary, _breath: float, _clock: float) -> void:
	pass

## order(p, list) -> list: per-pose z swaps (only called when the JS spec has order())
func order(_p: Dictionary, list: Array) -> Array:
	return list

## attack.draw(ctx, cam, api, layer, t): stateless per-layer drawing (layer back | mid | front)
func draw(_ctx: RigCtx, _cam: RigCam, _r: Rig, _layer: String, _t: float) -> void:
	pass

## channels that are not plain tracks in the JS (exported as 5 ms samples): recompute exactly here if needed
func channels(_p: Dictionary, _t: float, _attack: String) -> void:
	pass

## extra drawing in the character frame after the parts (rarely needed)
func draw_char_extra(_ctx: RigCtx, _cam: RigCam, _r: Rig) -> void:
	pass
