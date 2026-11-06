class_name Store
extends RefCounted
## persistence in user://: settings + campaign progress (ConfigFile), the running game (var_to_str keeps ints + Vector2i keys)

static var CFG := "user://hsn.cfg"
static var SAVE := "user://hsn_save_v1.txt"
static var _cfg: ConfigFile
static var board3d_flag := -1 # debug flag 3d=1/0 for one run; -1 = use the setting

## test runs (click driver, tests) keep their settings / progress / save apart from the player's
static func use_profile(name: String) -> void:
	CFG = "user://hsn_%s.cfg" % name
	SAVE = "user://hsn_%s_save.txt" % name
	_cfg = null

static func _c() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		var err := _cfg.load(CFG)
		if err != OK and err != ERR_FILE_NOT_FOUND: # no file yet = first run
			push_warning("store: load %s failed (%s)" % [CFG, error_string(err)])
	return _cfg

static func get_v(key: String, def: Variant) -> Variant:
	return _c().get_value("hsn", key, def)

static func set_v(key: String, v: Variant) -> void:
	_c().set_value("hsn", key, v)
	var err := _c().save(CFG)
	if err != OK:
		push_warning("store: save %s failed (%s)" % [CFG, error_string(err)])

# ---------- settings ----------
## flat 2D map (default) or the 3D tabletop board; `board3d_flag` (debug flag 3d=1/0) overrides it for one run
static func board_3d() -> bool:
	var on: bool = get_v("board3d", false)
	return on if board3d_flag < 0 else board3d_flag == 1

static func set_board_3d(on: bool) -> void:
	board3d_flag = -1
	set_v("board3d", on)

# ---------- campaign progress ----------
static func done_list() -> Array:
	return get_v("campaign_done", [])

static func is_done(id: String) -> bool:
	return done_list().has(id)

static func mark_done(id: String) -> void:
	var d := done_list().duplicate()
	if not d.has(id):
		d.append(id)
		set_v("campaign_done", d)

## index of the first mission not yet won
static func unlocked_index() -> int:
	var c := Content.campaign()
	var i := 0
	while i < c.size():
		var mid: String = c[i].id
		if not is_done(mid):
			break
		i += 1
	return i

# ---------- running game ----------
static func save_game(s: Dictionary, ctx: Dictionary, title: String) -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f == null:
		push_warning("store: open %s failed (%s)" % [SAVE, error_string(FileAccess.get_open_error())])
	elif not f.store_string(var_to_str({ "state": s, "ctx": ctx, "title": title })):
		push_warning("store: write %s failed" % SAVE)

static func load_game() -> Variant:
	if not FileAccess.file_exists(SAVE):
		return null
	var v: Variant = str_to_var(FileAccess.get_file_as_string(SAVE))
	if not (v is Dictionary):
		return null
	var d: Dictionary = v
	var st: Variant = d.get("state")
	if not (st is Dictionary):
		return null
	var sd: Dictionary = st
	if sd.get("winner") == null:
		Content.migrate_save(d)
		if fits_content(d):
			return d
		clear_game() # written by an older content set (removed mission / commander): drop it instead of crashing
	return null

## a save still matches the shipped content (logic lives in core: Content.save_fits)
static func fits_content(v: Dictionary) -> bool:
	return Content.save_fits(v)

static func clear_game() -> void:
	if FileAccess.file_exists(SAVE):
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
		if err != OK:
			push_warning("store: remove %s failed (%s)" % [SAVE, error_string(err)])
