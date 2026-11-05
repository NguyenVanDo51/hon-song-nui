class_name Store
extends RefCounted
## persistence in user://: settings + campaign progress (ConfigFile), the running game (var_to_str keeps ints + Vector2i keys)

static var CFG := "user://hsn.cfg"
static var SAVE := "user://hsn_save_v1.txt"
const STATE_V := 2 # Game.new_game writes "v"; bump both when the saved state shape changes
const WIN_TYPES := ["castles", "rout", "hero", "survive", "reach"]
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

static func tips_hidden(scenario: String) -> bool:
	return Array(get_v("tips_hidden", [])).has(scenario)

static func hide_tips(scenario: String) -> void:
	var h: Array = Array(get_v("tips_hidden", [])).duplicate()
	if not h.has(scenario):
		h.append(scenario)
		set_v("tips_hidden", h)

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
		if fits_content(v):
			return v
		clear_game() # written by an older content set (removed mission / commander): drop it instead of crashing
	return null

## a save still matches the shipped content: its mission exists and every commander key is still a hero in the theme
static func fits_content(v: Dictionary) -> bool:
	var st: Dictionary = v.state
	if int(st.get("v", 0)) != STATE_V:
		return false
	for k: String in ["units", "tiles", "owner", "gold", "heroKey", "allowed", "win", "unitCap", "graves", "heroDead"]:
		if not st.has(k):
			return false
	if not WIN_TYPES.has(str(st.win.get("type", ""))):
		return false
	for u: Variant in st.units:
		if not (u is Dictionary) or not Rules.UNITS.has(u.get("type")):
			return false
	for side: String in st.allowed:
		for t: Variant in st.allowed[side]:
			if not Rules.UNITS.has(t):
				return false
	var ctx: Dictionary = v.get("ctx", {}) if v.get("ctx") is Dictionary else {}
	if ctx.get("kind") == "campaign" and Content.mission(str(ctx.get("id", ""))) == null:
		return false
	if ctx.get("kind") == "skirmish" and not Content.heroes_of("p").has(ctx.get("hero")):
		return false
	var hk: Variant = v.state.get("heroKey")
	if hk is Dictionary:
		for side: String in hk:
			if hk[side] != null and not (Content.theme().heroes.has(hk[side]) and Rules.HEROES.has(hk[side])):
				return false
	for row: Variant in v.state.get("tiles", []):
		for t: String in row:
			if not Rules.TERRAIN.has(t):
				return false
	return true

static func clear_game() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
