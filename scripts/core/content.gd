class_name Content
extends RefCounted
## content registry: campaign missions (every content/campaign/*.gd, sorted by `order`), skirmish maps, theme lookups.
## All name / icon resolution goes through here.

const THEME_SCRIPT := preload("res://content/theme.gd")
const SKIRMISH := preload("res://content/skirmish_maps.gd")
const CAMPAIGN_DIR := "res://content/campaign"

static var _campaign: Array = []

static func theme() -> Dictionary:
	return THEME_SCRIPT.THEME

static func campaign() -> Array:
	if _campaign.is_empty():
		var seen := {}
		for f in DirAccess.get_files_at(CAMPAIGN_DIR):
			f = f.trim_suffix(".remap")
			if not f.ends_with(".gd") or seen.has(f):
				continue
			seen[f] = true
			_campaign.append(load(CAMPAIGN_DIR + "/" + f).DEF)
		_campaign.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.order < b.order)
	return _campaign

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
