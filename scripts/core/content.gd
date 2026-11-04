class_name Content
extends RefCounted
## content registry: chapters (content/chapters/*.gd), campaign missions (content/campaign/*.gd, sorted by `order`,
## each tagged with its `chapter`), skirmish maps, theme lookups. All name / icon resolution goes through here.
## theme() is the base theme with the active chapter's overrides merged in (enemy faction skin, UI words, chapter map).

const THEME_SCRIPT := preload("res://content/theme.gd")
const SKIRMISH := preload("res://content/skirmish_maps.gd")
const CAMPAIGN_DIR := "res://content/campaign"
const CHAPTER_DIR := "res://content/chapters"

static var _campaign: Array = []
static var _chapters: Array = []
static var _themes := {}
## chapter whose skin / map the UI shows; set by the menus and the game screen
static var active_chapter := "c1"

static func _defs(dir: String) -> Array:
	var out := []
	var seen := {}
	for f in DirAccess.get_files_at(dir):
		f = f.trim_suffix(".remap") # exported builds list scripts as *.gd.remap
		if not f.ends_with(".gd") or seen.has(f):
			continue
		seen[f] = true
		out.append(load(dir + "/" + f).DEF)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.order < b.order)
	return out

static func theme() -> Dictionary:
	if not _themes.has(active_chapter):
		var t: Dictionary = THEME_SCRIPT.THEME.duplicate(true)
		var ch: Variant = chapter(active_chapter)
		if ch != null:
			_deep_merge(t, ch.get("theme", {}))
			t.chapter = ch
		_themes[active_chapter] = t
	return _themes[active_chapter]

static func _deep_merge(into: Dictionary, over: Dictionary) -> void:
	for k: Variant in over:
		if into.get(k) is Dictionary and over[k] is Dictionary:
			_deep_merge(into[k], over[k])
		else:
			into[k] = over[k]

static func campaign() -> Array:
	if _campaign.is_empty():
		_campaign = _defs(CAMPAIGN_DIR)
	return _campaign

static func chapters() -> Array:
	if _chapters.is_empty():
		_chapters = _defs(CHAPTER_DIR)
	return _chapters

static func chapter(id: String) -> Variant:
	for c: Dictionary in chapters():
		if c.id == id:
			return c
	return null

static func chapter_of(m: Dictionary) -> String:
	return m.get("chapter", "c1")

static func missions_of(chapter_id: String) -> Array:
	return campaign().filter(func(m: Dictionary) -> bool: return chapter_of(m) == chapter_id)

static func use_chapter(id: String) -> void:
	active_chapter = id if chapter(id) != null else "c1"

## a chapter opens once every mission before it (campaign order) is won
static func chapter_unlocked(id: String, unlocked_index: int) -> bool:
	var ms := missions_of(id)
	return ms.is_empty() or mission_index(ms[0].id) <= unlocked_index

static func mission(id: String) -> Variant:
	for m: Dictionary in campaign():
		if m.id == id:
			return m
	return null

static func mission_index(id: String) -> int:
	var c := campaign()
	for i in c.size():
		if c[i].id == id:
			return i
	return -1

## free-play def: any hero vs the first enemy hero in the theme
static func skirmish_def(map_id: String, hero_key: String, easy: bool) -> Dictionary:
	var m: Dictionary = SKIRMISH.MAPS[map_id]
	return {
		"id": "skirmish:" + map_id, "title": m.name, "hero": hero_key, "enemyHero": heroes_of("e")[0],
		"map": { "rows": m.rows }, "owner": m.owner, "units": m.units,
		"gold": { "p": 300, "e": 150 if easy else 300 }, "incomeMul": { "e": 0.7 if easy else 1 },
		"win": { "type": "castles" }, "skirmish": { "mapId": map_id, "easy": easy },
	}

# ---------- looks ----------
static func unit_look(s: Dictionary, u: Dictionary) -> Dictionary:
	return unit_type_look(u.side, u.type, s.heroKey[u.side])

static func unit_type_look(side: String, type: String, hero_key: Variant) -> Dictionary:
	if type == "hero":
		return theme().heroes.get(hero_key, { "name": "?", "icon": "?", "blurb": "" })
	return theme().units[side][type]

static func hero_look(key: String) -> Dictionary:
	return theme().heroes[key]

static func heroes_of(side: String) -> Array:
	var out := []
	for k: String in theme().heroes:
		if theme().heroes[k].side == side:
			out.append(k)
	return out

static func speaker(key: String) -> Dictionary:
	var t := theme()
	if t.heroes.has(key):
		return t.heroes[key]
	if t.people.has(key):
		return t.people[key]
	return { "name": key, "icon": "💬" }

static func is_foe(key: String) -> bool:
	return theme().heroes.has(key) and theme().heroes[key].side == "e"

static func terrain(t: String) -> Dictionary:
	return theme().terrain[t]

static func text(key: String) -> String:
	return theme().text[key]
