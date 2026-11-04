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

## free-play def: any hero vs the map's enemy hero (default: the first enemy hero in the theme)
static func skirmish_def(map_id: String, hero_key: String, easy: bool) -> Dictionary:
	var m: Dictionary = SKIRMISH.MAPS.get(map_id, SKIRMISH.MAPS.dong_bang)
	return {
		"id": "skirmish:" + map_id, "title": m.name, "hero": hero_key, "enemyHero": m.get("enemyHero", heroes_of("e")[0]),
		"chapter": m.get("chapter", "c1"),
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

# ---------- unit guide (role, how to play, traits from stats) ----------
const GUIDE := preload("res://content/guide.gd")

## full stats of a unit type (hero overrides merged)
static func type_stat(type: String, hero_key: Variant) -> Dictionary:
	var st: Dictionary = Rules.UNITS[type].duplicate()
	if type == "hero" and hero_key != null and Rules.HEROES.has(hero_key):
		st.merge(Rules.HEROES[hero_key], true)
	return st

static func role(type: String) -> String:
	return GUIDE.ROLE.get(type, "")

static func how_to_play(type: String) -> String:
	return GUIDE.PLAY.get(type, "")

## strengths / quirks as short lines, generated from the stats so they never disagree with the rules
static func traits(type: String, hero_key: Variant) -> Array:
	var st := type_stat(type, hero_key)
	var tn := { "f": "rừng", "h": "đồi", "m": "núi" }
	var out := []
	if st.get("capC", false):
		out.append("Chiếm được cả thành lẫn làng.")
	elif st.get("capV", false):
		out.append("Chiếm được làng (+%d vàng mỗi lượt)." % Rules.RULES.incomeVillage)
	if st.rmax > 1:
		out.append("Đánh xa %d–%d ô. Đứng cách 2 ô thì lính cận chiến không đánh trả được." % [st.rmin, st.rmax] if not st.get("siege", false)
			else "Bắn xa %d–%d ô, nhưng đã di chuyển thì lượt đó không bắn được." % [st.rmin, st.rmax])
	if st.get("siege", false):
		out.append("Không bao giờ đánh trả: bị áp sát là nguy.")
	if st.get("aura", 0):
		out.append("Hào quang: quân ta đứng kề bên +%d công khi ra đòn." % st.aura)
	if st.get("guard", 0):
		out.append("Che chắn: quân ta đứng kề bên +%d thủ khi bị đánh." % st.guard)
	if st.get("antiAir", 0):
		out.append("+%d công khi đánh kỵ binh." % st.antiAir)
	if st.get("magic", false):
		out.append("Đòn đánh bỏ qua thủ địa hình (rừng, đồi, thành...).")
	if st.get("raise", false):
		out.append("Cứu lính ngã: đứng cạnh mộ để dựng thành quân mới.")
	var tb: Dictionary = st.get("tBonus", {})
	if tb.size():
		var parts := []
		for t: String in tb:
			parts.append("%s +%d" % [tn.get(t, t), tb[t]])
		out.append("Quen địa hình: thủ thêm khi đứng ở %s." % ", ".join(parts))
	match st.move:
		"fly": out.append("Mọi ô chỉ tốn 1 bước, vượt cả sông núi; nhưng không được địa hình che chắn.")
		"heavy": out.append("Nặng nề: không lên được núi.")
		"mount": out.append("Đi đồi núi chỉ tốn 1 bước.")
		"water": out.append("Đi được trên sông.")
	if st.mv >= 6:
		out.append("Đi xa %d ô mỗi lượt." % st.mv)
	elif st.mv <= 3:
		out.append("Chậm: chỉ đi %d ô mỗi lượt." % st.mv)
	if st.def >= 25:
		out.append("Thủ rất dày (%d): hợp làm tường chắn." % st.def)
	elif st.def <= 5:
		out.append("Thủ mỏng (%d): luôn giữ sau lưng quân khác." % st.def)
	if st.get("noGrave", false):
		out.append("Ngã xuống thì không để lại mộ.")
	return out

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
	var t := theme()
	if t.heroes.has(key):
		return t.heroes[key].side == "e"
	return t.people.has(key) and t.people[key].get("side", "p") == "e"

static func terrain(t: String) -> Dictionary:
	return theme().terrain[t]

static func text(key: String) -> String:
	return theme().text[key]
