extends "res://sim/tests/test_base.gd"
## session log tests (run by sim/tests.gd): off in headless, real engine capture into a temp dir, crash marker, prune

func game_log_tests() -> void:
	run(
		"headless run: logger stays off",
		func() -> void:
			check(not GameLog.enabled_here(), "enabled_here() in headless")
			GameLog.boot("", [])
			check(not GameLog.active(), "boot() must not open a log headless"),
	)
	run(
		"open_at: push_warning / push_error / print / crumb land in the file, flushed",
		func() -> void:
			var dir := _tmp()
			var p := GameLog.open_at(dir, "info=t")
			check(p != "" and GameLog.active(), "opened")
			push_warning("gamelog probe W")
			push_error("gamelog probe E")
			print("gamelog probe P")
			GameLog.crumb("crumb x")
			var live := FileAccess.get_file_as_string(p) # read while still open: flushed per line
			GameLog.stop()
			check(live.contains(" == session open pid="), "open marker")
			check(live.contains(" W gamelog probe W @ "), "warning line: " + live)
			check(live.contains(" E gamelog probe E @ "), "error line")
			check(live.contains(" P gamelog probe P"), "print line")
			check(live.contains(" B crumb x"), "breadcrumb")
			check(live.contains("game_log.gd:"), "file:line of the push_* call")
			_rm(dir),
	)
	run(
		"repeated text: first REPEAT_FULL lines only",
		func() -> void:
			var dir := _tmp()
			var p := GameLog.open_at(dir)
			for _i in GameLog.REPEAT_FULL + 3:
				push_warning("gamelog flood")
			GameLog.stop()
			eq(FileAccess.get_file_as_string(p).count("gamelog flood"), GameLog.REPEAT_FULL, "flood lines")
			_rm(dir),
	)
	run(
		"check_previous: clean / paused / crash (-> crash_<name> + tail) / resumed = crash",
		func() -> void:
			var dir := _tmp()
			eq(GameLog.check_previous(dir).status, "none", "empty dir")
			_put(dir, "2026-01-01_10-00-00.log", ["t == session open pid=1", "t B screen title", "t == clean exit"])
			var r := GameLog.check_previous(dir)
			eq(r.status, "clean", "clean")
			check(FileAccess.file_exists(dir.path_join("2026-01-01_10-00-00.log")), "clean log stays")
			_put(dir, "2026-01-02_10-00-00.log", ["t == session open pid=2", "t B turn 3", "t == paused"])
			eq(GameLog.check_previous(dir).status, "paused", "paused")
			_put(dir, "2026-01-03_10-00-00.log", ["t == session open pid=3", "t == paused", "t == resumed", "t E boom @ a.gd:1 f()"])
			r = GameLog.check_previous(dir)
			eq(r.status, "crash", "resumed then silence")
			eq(r.kept, "crash_2026-01-03_10-00-00.log", "kept name")
			check(FileAccess.file_exists(dir.path_join("crash_2026-01-03_10-00-00.log")), "renamed")
			check(not FileAccess.file_exists(dir.path_join("2026-01-03_10-00-00.log")), "original gone")
			var tail: PackedStringArray = r.tail
			check(tail.size() > 0 and tail[-1].contains("boom"), "tail ends at the last line")
			# latest session is now the paused one again: crash_ files never count as the previous session
			eq(GameLog.check_previous(dir).status, "paused", "crash_ ignored")
			_rm(dir),
	)
	run(
		"open_at after a crash: new log names the crash file + its last lines",
		func() -> void:
			var dir := _tmp()
			_put(dir, "2026-01-04_10-00-00.log", ["t == session open pid=4", "t B act infantry", "t E Message queue out of memory"])
			var p := GameLog.open_at(dir)
			GameLog.stop()
			var txt := FileAccess.get_file_as_string(p)
			check(txt.contains("previous session CRASHED (no clean exit) -> kept as crash_2026-01-04_10-00-00.log"), txt)
			check(txt.contains(" | t E Message queue out of memory"), "tail copied")
			_rm(dir),
	)
	run(
		"prune: newest KEEP - 1 sessions + KEEP_CRASH crash logs stay, other files untouched",
		func() -> void:
			var dir := _tmp()
			for i in 25:
				_put(dir, "2026-02-%02d_10-00-00.log" % (i + 1), ["t == clean exit"])
			for i in 12:
				_put(dir, "crash_2026-03-%02d_10-00-00.log" % (i + 1), ["x"])
			_put(dir, "notes.txt", ["x"])
			GameLog.prune(dir)
			var s := GameLog.list(dir, false)
			var c := GameLog.list(dir, true)
			eq(s.size(), GameLog.KEEP - 1, "sessions")
			eq(c.size(), GameLog.KEEP_CRASH, "crash logs")
			eq(s[-1], "2026-02-25_10-00-00.log", "newest session kept")
			eq(s[0], "2026-02-%02d_10-00-00.log" % (25 - GameLog.KEEP + 2), "oldest kept")
			eq(c[0], "crash_2026-03-03_10-00-00.log", "oldest crash kept")
			check(FileAccess.file_exists(dir.path_join("notes.txt")), "other file kept")
			_rm(dir),
	)

## temp dir under user:// (never the real logs/game/)
func _tmp() -> String:
	var d := "user://tmp_gamelog_test_%d_%d" % [Time.get_ticks_usec(), randi()]
	DirAccess.make_dir_recursive_absolute(d)
	return d

func _put(dir: String, file_name: String, lines: Array) -> void:
	var f := FileAccess.open(dir.path_join(file_name), FileAccess.WRITE)
	f.store_string("\n".join(PackedStringArray(lines)) + "\n")

func _rm(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
