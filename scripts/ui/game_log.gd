class_name GameLog
extends Logger
## per-session play log: engine errors / warnings / prints + breadcrumbs, flushed every line (a crash keeps all up to it).
## user://logs/game/<profile>/<YYYY-MM-DD_HH-MM-SS>.log, last KEEP kept; a session without "== clean exit" = crashed
## -> renamed crash_<its name> on the next launch. Real windowed runs only (not headless / sim scripts / web).
## read: tools/game_logs.sh; README "Log lỗi / crash".

const KEEP := 20
const KEEP_CRASH := 10
const MARK := " == "
const OPEN := "session open"
const CLEAN := "clean exit"
const PAUSED := "paused"
const RESUMED := "resumed"
const REPEAT_FULL := 20 # same text: first N written in full, then every REPEAT_EVERY-th with a count
const REPEAT_EVERY := 1000
const MAX_BYTES := 8 * 1024 * 1024 # past this only markers / breadcrumbs (a flood must not fill the disk)
const SESSION_RE := "^\\d{4}-\\d\\d-\\d\\d_\\d\\d-\\d\\d-\\d\\d(_\\d+)?\\.log$"

static var _inst: GameLog

var path := ""
var _f: FileAccess
var _mu := Mutex.new()
var _busy := false
var _seen := { }
var _last_mark := ""

## main.gd: start logging if this is a real play session
static func boot(profile: String, args: Array) -> void:
	if not enabled_here():
		return
	var dir := "user://logs/game".path_join(profile if profile != "" else "default")
	var info := "godot=%s os=%s %s model=%s debug=%s gpu=%s screen=%s args=%s" % [
		Engine.get_version_info().string,
		OS.get_name(),
		OS.get_version(),
		OS.get_model_name(),
		OS.is_debug_build(),
		RenderingServer.get_video_adapter_name(),
		DisplayServer.screen_get_size(),
		" ".join(args),
	]
	open_at(dir, info)

## headless (tests, sims), a -s script main loop (probes / drivers, even windowed) and web (IndexedDB, tab close = no exit) skip
static func enabled_here() -> bool:
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		return false
	var ml := Engine.get_main_loop()
	return ml == null or ml.get_script() == null

static func active() -> bool:
	return _inst != null

## check the previous session, prune, open a new file, hook the engine loggers. Returns the new log path ("" = failed)
static func open_at(dir: String, info := "") -> String:
	stop()
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		return ""
	var prev := check_previous(dir)
	prune(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var p := dir.path_join(stamp + ".log")
	var n := 2
	while FileAccess.file_exists(p):
		p = dir.path_join("%s_%d.log" % [stamp, n])
		n += 1
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return ""
	var g := GameLog.new()
	g.path = p
	g._f = f
	_inst = g
	g._write("=", "%s pid=%d %s" % [OPEN, OS.get_process_id(), info])
	var st: String = prev.status
	if st == "crash":
		g._write("=", "previous session CRASHED (no clean exit) -> kept as %s" % prev.kept)
		var tail: PackedStringArray = prev.tail
		for l in tail:
			g._write("|", l)
	elif st == "paused":
		g._write("=", "previous session ended while paused (OS killed it in background?): %s" % prev.file)
	OS.add_logger(g)
	return p

## unhook + close (tests; a quitting game keeps logging until exit: leaks at shutdown land too)
static func stop() -> void:
	if _inst == null:
		return
	OS.remove_logger(_inst)
	_inst._mu.lock()
	_inst._f = null
	_inst._mu.unlock()
	_inst = null

static func crumb(text: String) -> void:
	if _inst != null:
		_inst._write("B", text)

## marker lines: OPEN / CLEAN / PAUSED / RESUMED; the last one decides how the session ended
static func mark(what: String) -> void:
	if _inst != null and _inst._last_mark != what: # close request + tree exit both fire on quit
		_inst._last_mark = what
		_inst._write("=", what)

## latest session file in dir: ended clean / paused / crashed (-> renamed crash_<name>). {status, file, kept, tail}
static func check_previous(dir: String) -> Dictionary:
	var res := { "status": "none", "file": "", "kept": "", "tail": PackedStringArray() }
	var files := list(dir, false)
	if files.is_empty():
		return res
	var last_file: String = files[-1]
	var p := dir.path_join(last_file)
	res.file = last_file
	var lines := tail_lines(p, 65536) # shutdown output (leaks) can follow the clean-exit marker
	var last := ""
	for l in lines:
		var i := l.find(MARK)
		if i >= 0:
			last = l.substr(i + MARK.length())
	if last.begins_with(CLEAN):
		res.status = "clean"
	elif last.begins_with(PAUSED):
		res.status = "paused"
	else:
		var kept := "crash_" + last_file
		if DirAccess.rename_absolute(p, dir.path_join(kept)) != OK:
			kept = last_file
		res.status = "crash"
		res.kept = kept
		res.tail = lines.slice(maxi(0, lines.size() - 15))
	return res

## session logs (crash = false) or crash_* copies, oldest first
static func list(dir: String, crash: bool) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string(SESSION_RE)
	for f in DirAccess.get_files_at(dir):
		var base := f.trim_prefix("crash_") if crash else f
		if (f.begins_with("crash_") == crash) and re.search(base) != null:
			out.append(f)
	out.sort()
	return out

## keep the newest KEEP - 1 sessions (+ the one about to open) and KEEP_CRASH crash logs
static func prune(dir: String) -> void:
	for crash: bool in [false, true]:
		var files := list(dir, crash)
		var keep := KEEP_CRASH if crash else KEEP - 1
		for i in maxi(0, files.size() - keep):
			DirAccess.remove_absolute(dir.path_join(files[i]))

## last ~bytes of a file as lines (no partial first line)
static func tail_lines(p: String, bytes: int) -> PackedStringArray:
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	var size := f.get_length()
	var from := maxi(0, size - bytes)
	f.seek(from)
	var txt := f.get_buffer(size - from).get_string_from_utf8()
	var lines := txt.split("\n", false)
	if from > 0 and lines.size() > 0:
		lines.remove_at(0)
	return lines

# ---------- engine hooks (any thread: no Node / tree access, never print / push_* here) ----------
func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	_editor_notify: bool,
	error_type: int,
	script_backtraces: Array[ScriptBacktrace],
) -> void:
	var lv := "E"
	if error_type == ERROR_TYPE_WARNING:
		lv = "W"
	elif error_type == ERROR_TYPE_SCRIPT:
		lv = "S"
	elif error_type == ERROR_TYPE_SHADER:
		lv = "H"
	var msg := rationale if rationale != "" else code
	if rationale != "" and code != "":
		msg += " [%s]" % code
	var txt := "%s @ %s:%d %s()" % [msg, file, line, function]
	for bt in script_backtraces:
		if bt != null and not bt.is_empty():
			txt += "\n" + bt.format(4, 6).rstrip("\n")
	_write(lv, txt, msg)

func _log_message(message: String, error: bool) -> void:
	_write("X" if error else "P", message.rstrip("\n"))

## one line "HH:MM:SS +uptime L text"; key = dedupe text (errors in a loop repeat thousands of times)
func _write(lv: String, text: String, key := "") -> void:
	_mu.lock()
	if _busy or _f == null:
		_mu.unlock()
		return
	_busy = true
	var plain := lv == "=" or lv == "B" or lv == "|"
	var out := text
	if not plain:
		var k := key if key != "" else text
		var c: int = _seen.get(k, 0)
		c += 1
		if _seen.size() < 2000 or _seen.has(k):
			_seen[k] = c
		if c > REPEAT_FULL:
			out = "" if c % REPEAT_EVERY != 0 else "(x%d) %s" % [c, k]
		if _f.get_length() > MAX_BYTES:
			out = ""
	if out != "":
		var t := "%s +%.3f %s %s" % [Time.get_time_string_from_system(), Time.get_ticks_msec() / 1000.0, lv, out]
		if lv == "=":
			t = "%s +%.3f%s%s" % [Time.get_time_string_from_system(), Time.get_ticks_msec() / 1000.0, MARK, out]
		_f.store_line(t)
		_f.flush()
	_busy = false
	_mu.unlock()
