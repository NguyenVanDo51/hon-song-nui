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
	# sort_custom is not stable: break ties by id so equal `order` values never shuffle (tests flag duplicates)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.order < b.order or (a.order == b.order and str(a.get("id", "")) < str(b.get("id", ""))))
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
	return theme().heroes.get(key, { "name": key, "icon": "?", "blurb": "", "side": "e" }) # never hard-crash on a stale key

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
	return str(theme().text.get(key, key)) # a missing key shows itself instead of crashing

static func _names(hero_keys: Dictionary) -> Dictionary:
	var e: Variant = hero_keys.get("e")
	return { "hero": hero_look(str(hero_keys.get("p", ""))).name, "eh": hero_look(str(e)).name if e != null else text("noEnemyHero") }

## objective wording for a win spec; form "brief" (briefing) or "bar" (top bar). Unknown win types fall back to the type name.
static func goal_text(win: Dictionary, form: String, hero_keys: Dictionary, vars := {}, must_live := false) -> String:
	var w := { "type": "castles" }
	w.merge(win, true)
	var v := _names(hero_keys)
	v.merge(vars, true)
	v.turns = str(w.get("turns", ""))
	v.within = (" trong %d lượt" % int(w.turns)) if w.has("turns") else ""
	v.left_txt = (": còn %s lượt" % str(v.get("left", ""))) if w.has("turns") else ""
	var g: Dictionary = theme().get("goals", {}).get(w.type, {})
	var t := str(g.get(form, w.type)).format(v)
	if must_live:
		t += text("mustLiveBrief" if form == "brief" else "mustLiveBar").format(v)
	return t

## end card line: winner side + engine reason ("" when there is nothing to add)
static func end_text(winner: Variant, reason: String, hero_keys: Dictionary) -> String:
	var line: String = theme().get("ends", {}).get(str(winner), {}).get(reason, "")
	return line.format(_names(hero_keys))

## rule note for a terrain tile, built from the rules (who captures, who crosses) so it never restates them wrongly
static func tile_note(t: String) -> String:
	var who := func(pred: Callable) -> String:
		var names := []
		for type: String in Rules.UNITS:
			var st: Dictionary = Rules.UNITS[type]
			if st.get("buyable", true) and pred.call(st, type):
				names.append(theme().units.p[type].name if type != "hero" else "tướng")
		return ", ".join(names)
	match t:
		"v":
			return text("tileVillage").format({ "capV": who.call(func(st: Dictionary, _t: String) -> bool: return st.get("capV", false)), "income": Rules.RULES.incomeVillage })
		"c":
			return text("tileCastle").format({ "capC": who.call(func(st: Dictionary, _t: String) -> bool: return st.get("capC", false)), "income": Rules.RULES.incomeCastle })
		"~":
			var crossers: String = who.call(func(st: Dictionary, _t: String) -> bool: return st.move == "fly" or st.move == "water")
			var water_heroes := []
			for hk: String in Rules.HEROES:
				if Rules.HEROES[hk].get("move", "") == "water" and theme().heroes.has(hk):
					water_heroes.append(theme().heroes[hk].name)
			var all := ", ".join([crossers] + water_heroes) if crossers != "" else ", ".join(water_heroes)
			return text("tileWater").format({ "water": all }) if all != "" else ""
	return ""


# ---------- saves ----------
const STATE_V := 2 # Game.new_game writes "v"; bump both when the saved state shape changes
const WIN_TYPES := ["castles", "rout", "hero", "survive", "reach"]

## a save still matches the shipped content: same state version + shape, known win type / unit types, its mission
## still exists, every commander key is still a hero in theme and rules, every tile is known
static func save_fits(v: Dictionary) -> bool:
	var st: Variant = v.get("state")
	if not (st is Dictionary) or int(st.get("v", 0)) != STATE_V:
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
	if ctx.get("kind") == "campaign" and mission(str(ctx.get("id", ""))) == null:
		return false
	if ctx.get("kind") == "skirmish" and not heroes_of("p").has(ctx.get("hero")):
		return false
	var hk: Variant = st.get("heroKey")
	if hk is Dictionary:
		for side: String in hk:
			if hk[side] != null and not (theme().heroes.has(hk[side]) and Rules.HEROES.has(hk[side])):
				return false
	for row: Variant in st.get("tiles", []):
		for t: String in row:
			if not Rules.TERRAIN.has(t):
				return false
	return true
