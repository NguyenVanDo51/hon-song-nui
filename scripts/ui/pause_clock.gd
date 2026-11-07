class_name PauseClock
extends RefCounted
## wall clock (ms) that stands still while the ⚙ menu pauses the game: FX.now() reads it, so every effect, token
## move, rig and intro scene timed by it freezes and resumes where it was (SceneTree.paused alone misses them).

static var _held_at := -1.0 # wall ms the pause began; < 0 = running
static var _lost := 0.0 # wall ms spent paused, in total

static func ms() -> float:
	var wall := Time.get_ticks_usec() / 1000.0
	return (_held_at if _held_at >= 0.0 else wall) - _lost

static func hold(on: bool) -> void:
	var wall := Time.get_ticks_usec() / 1000.0
	if on and _held_at < 0.0:
		_held_at = wall
	elif not on and _held_at >= 0.0:
		_lost += wall - _held_at
		_held_at = -1.0

static func held() -> bool:
	return _held_at >= 0.0
