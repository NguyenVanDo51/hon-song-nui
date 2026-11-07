class_name MatchRec
extends RefCounted
## match recorder: every game played on screen -> user://replays/<profile>/<YYYY-MM-DD_HH-MM-SS>_<kind>_<id>.replay
## (format: scripts/core/replay.gd). One-line hooks: main (boot), game_screen (start / act / buy / unbuy),
## turn_driver (AI step, end turn, finish). Only steps that changed s are written (hash before != after).
## Continue from a save: ctx.replay + ctx.replayHash match the loaded state -> same file; else a new file (head.prev).
## Same on/off rule as GameLog (off headless, in -s scripts, on web). Analyze: tools/review_match.sh.

const KEEP := 200
const ROOT := "user://replays"
const NAME_RE := "^\\d{4}-\\d\\d-\\d\\d_\\d\\d-\\d\\d-\\d\\d.*\\.replay$"

static var profile := ""
static var bot := false
static var path := ""
static var _f: FileAccess
static var _ctx: Dictionary = { }
static var _h := ""
static var _turn := 0
static var _side := ""

## main.gd: profile name (replay dir) + `bot` flag (our side played by the default AI)
static func boot(profile_name: String, bot_flag: bool) -> void:
	profile = profile_name
	bot = bot_flag

static func dir_for(profile_name: String) -> String:
	return ROOT.path_join(profile_name if profile_name != "" else "default")

static func active() -> bool:
	return _f != null

## GameScreen.start: new game or continued save
static func begin(s: Dictionary, ctx: Dictionary) -> void:
	stop()
	if GameLog.enabled_here():
		open_in(dir_for(profile), s, ctx)

## start / continue recording s into dir (tests call this directly: no on/off rule). Returns the file path ("" = failed)
static func open_in(dir: String, s: Dictionary, ctx: Dictionary) -> String:
	stop()
	var h := Replay.state_hash(s)
	var prev: String = ctx.get("replay", "")
	if prev != "" and FileAccess.file_exists(prev) and ctx.get("replayHash") == h:
		var fa := FileAccess.open(prev, FileAccess.READ_WRITE)
		if fa != null:
			fa.seek_end()
			_attach(fa, prev, s, ctx, h)
			_write({ "t": "resume", "date": _now(), "turn": s.turn, "side": s.side, "h": h })
			return prev
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return ""
	var units: Array = s.units
	var moved := units.any(
		func(u: Dictionary) -> bool:
			return u.acted,
	)
	if s.turn == 1 and s.side == "p" and not moved:
		prev = "" # a fresh game (retry / play again copy the old ctx): nothing earlier to link
	prune(dir)
	var kind: String = ctx.get("kind", "game")
	var id := str(ctx.get("id", ctx.get("map", "")))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var p := dir.path_join("%s_%s_%s%s" % [stamp, kind, id.validate_filename(), Replay.EXT])
	var n := 2
	while FileAccess.file_exists(p):
		p = dir.path_join("%s_%s_%s_%d%s" % [stamp, kind, id.validate_filename(), n, Replay.EXT])
		n += 1
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return ""
	var head_ctx := ctx.duplicate()
	head_ctx.erase("replay")
	head_ctx.erase("replayHash")
	var ai := { }
	for side: String in ["p", "e"]:
		ai[side] = Content.ai_level(s, side) if Content.is_ai(s, side) else "human"
	var head := {
		"t": "head",
		"format": Replay.FORMAT,
		"date": _now(),
		"kind": kind,
		"id": id,
		"profile": profile,
		"bot": bot,
		"ctx": head_ctx,
		"ai": ai,
		"turn": s.turn,
		"side": s.side,
		"prev": prev,
		"state": var_to_str(s),
		"h": h,
	}
	_attach(f, p, s, ctx, h)
	_write(head)
	return p

## after any change to s by a move: writes it when s really changed (refused / undone paths change nothing)
static func step(s: Dictionary, st: Dictionary) -> void:
	if _f == null:
		return
	var h := Replay.state_hash(s)
	if h == _h:
		return
	var who := "ai" if Content.is_ai(s, _side) else "human"
	_write({ "t": "step", "turn": _turn, "side": _side, "who": who, "step": st, "h": h })
	_h = h
	_turn = s.turn
	_side = s.side
	_ctx.replayHash = h

## game over: result line, file closed
static func finish(s: Dictionary) -> void:
	if _f == null:
		return
	_write({ "t": "finish", "winner": s.winner, "reason": s.get("reason"), "turns": s.turn, "h": Replay.state_hash(s) })
	stop()

static func stop() -> void:
	_f = null
	path = ""
	_ctx = { }

## keep the newest KEEP - 1 replays (+ the one about to open); their review files go with them
static func prune(dir: String) -> void:
	var files := list(dir)
	for i in maxi(0, files.size() - (KEEP - 1)):
		var base := files[i].trim_suffix(Replay.EXT)
		for f: String in [files[i], base + ".review.md", base + ".review.json"]:
			if FileAccess.file_exists(dir.path_join(f)):
				DirAccess.remove_absolute(dir.path_join(f))

## replay file names in dir, oldest first
static func list(dir: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string(NAME_RE)
	for f in DirAccess.get_files_at(dir):
		if re.search(f) != null:
			out.append(f)
	out.sort()
	return out

static func _attach(f: FileAccess, p: String, s: Dictionary, ctx: Dictionary, h: String) -> void:
	_f = f
	path = p
	_ctx = ctx
	_h = h
	_turn = s.turn
	_side = s.side
	ctx.replay = p # saved with the game (Store.save_game): continue finds the file
	ctx.replayHash = h

## one record per line, flushed (a crash keeps every step before it)
static func _write(rec: Dictionary) -> void:
	_f.store_line(Replay.encode(rec))
	_f.flush()

static func _now() -> String:
	return Time.get_datetime_string_from_system(false, true)
