class_name Store
extends RefCounted
## persistence in user://: settings + campaign progress (ConfigFile), the running game (var_to_str keeps ints + Vector2i keys)

static var CFG := "user://hsn.cfg"
static var SAVE := "user://hsn_save_v1.txt"
static var _cfg: ConfigFile

## test runs (click driver, tests) keep their settings / progress / save apart from the player's
static func use_profile(name: String) -> void:
	CFG = "user://hsn_%s.cfg" % name
	SAVE = "user://hsn_%s_save.txt" % name
	_cfg = null

static func _c() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(CFG)
	return _cfg

static func get_v(key: String, def: Variant) -> Variant:
	return _c().get_value("hsn", key, def)

static func set_v(key: String, v: Variant) -> void:
	_c().set_value("hsn", key, v)
	_c().save(CFG)

# ---------- settings ----------
## flat 2D map (default) or the 3D tabletop board; `board3d_flag` (debug flag 3d=1/0) overrides it for one run
static var board3d_flag := -1
static func board_3d() -> bool:
	return bool(get_v("board3d", false)) if board3d_flag < 0 else board3d_flag == 1

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
	while i < c.size() and is_done(c[i].id):
		i += 1
	return i

# ---------- running game ----------
static func save_game(s: Dictionary, ctx: Dictionary, title: String) -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(var_to_str({ "state": s, "ctx": ctx, "title": title }))

static func load_game() -> Variant:
	if not FileAccess.file_exists(SAVE):
		return null
	var v: Variant = str_to_var(FileAccess.get_file_as_string(SAVE))
	if v is Dictionary and v.has("state") and v.state is Dictionary and v.state.get("winner") == null:
		Content.migrate_save(v)
		if fits_content(v):
			return v
		clear_game() # written by an older content set (removed mission / commander): drop it instead of crashing
	return null

## a save still matches the shipped content (logic lives in core: Content.save_fits)
static func fits_content(v: Dictionary) -> bool:
	return Content.save_fits(v)

static func clear_game() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
