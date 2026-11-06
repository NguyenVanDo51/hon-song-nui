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
## AE2 lets the player set starting gold and the unit cap; easy = the enemy starts with half the gold
static func skirmish_def(map_id: String, hero_key: String, easy: bool, gold := 300, cap := 15) -> Dictionary:
	var m: Dictionary = SKIRMISH.MAPS.get(map_id, SKIRMISH.MAPS.dong_bang)
	return {
		"id": "skirmish:" + map_id, "title": m.name, "hero": hero_key, "enemyHero": m.get("enemyHero", heroes_of("e")[0]),
		"chapter": m.get("chapter", "c1"),
		"map": { "rows": m.rows }, "owner": m.owner, "units": m.units,
		"gold": { "p": gold, "e": gold / 2 if easy else gold }, "unitCap": cap,
		"win": { "type": "castles" }, "skirmish": { "mapId": map_id, "easy": easy },
	}

# ---------- looks ----------
static func unit_look(s: Dictionary, u: Dictionary) -> Dictionary:
	return unit_type_look(u.side, u.type, s.heroKey[u.side])

static func unit_type_look(side: String, type: String, hero_key: Variant) -> Dictionary:
	if type == "hero":
		return theme().heroes.get(hero_key, { "name": "?", "icon": "?", "blurb": "" })
	return theme().units[side][type]

## AE2 renames a unit every 2 levels: "Bộ binh" -> "Bộ binh lão luyện ★2" ...; commanders keep their name (RM Unit.java:96)
static func unit_title(name: String, rank: int, hero := false) -> String:
	if rank <= 0:
		return name
	if hero:
		return "%s ★%d" % [name, rank]
	var titles: Array = THEME_SCRIPT.RANK_TITLES
	var t: String = titles[mini(rank / 2, titles.size() - 1)]
	return "%s%s ★%d" % [name, (" " + t) if t != "" else "", rank]

## level-up worth the big "Lên cấp N": a rename (RM MainDisplayable:4355)
static func rank_announced(type: String, rank: int) -> bool:
	return type != "hero" and rank % 2 == 0 and rank <= 6

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
		out.append("Chiếm được làng (+%d vàng mỗi lượt)." % Rules.TERRAIN.v.income)
	var lo: int = st.atk
	var hi: int = maxi(lo, st.get("atkMax", st.atk) - 1) # AE2 never rolls atkMax (same as Game.atk_range)
	if hi > lo:
		out.append("Công %d–%d: mỗi đòn lăn ngẫu nhiên trong khoảng này." % [lo, hi])
	if st.rmax > 1:
		out.append("Đánh xa %d–%d ô. Chỉ quân đứng kề mới đánh trả được." % [st.rmin, st.rmax] if not st.get("siege", false)
			else "Bắn xa %d–%d ô, nhưng đã di chuyển thì lượt đó không bắn được." % [st.rmin, st.rmax])
	if st.get("siege", false):
		out.append("Không bao giờ đánh trả: bị áp sát là nguy.")
	if st.get("aura", 0):
		out.append("Sau mỗi lệnh: quân ta trong 2 ô +%d công tới lượt sau của ta." % st.aura)
	if st.get("antiAir", 0):
		out.append("+%d công khi đánh rồng." % st.antiAir)
	var vs: Dictionary = st.get("vsType", {})
	for t: String in vs:
		out.append("+%d công khi đánh %s." % [vs[t], theme().units.p[t].name.to_lower()])
	if st.get("poison", 0):
		out.append("Cắn trúng: địch −%d công, −%d thủ tới lượt sau của ta." % [st.poison, st.poison])
	if st.get("waterAtk", 0):
		out.append("Đứng dưới sông: +%d công, +%d thủ." % [st.waterAtk, st.get("waterDef", 0)])
	if st.get("raise", false):
		out.append("Gọi hồn: đứng cạnh lính ngã (cả địch) để dựng thành âm binh của ta.")
	match st.move:
		"fly": out.append("Bay: mọi ô chỉ tốn 1 bước, vượt cả sông núi.")
		"water": out.append("Đi trên sông chỉ tốn 1 bước (quân khác tốn 3).")
	if st.get("noCap", false):
		out.append("Không tính vào giới hạn quân.")
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
static func goal_text(win: Dictionary, form: String, hero_keys: Dictionary, vars := {}) -> String:
	var w := { "type": "castles" }
	w.merge(win, true)
	var v := _names(hero_keys)
	v.merge(vars, true)
	v.turns = str(w.get("turns", ""))
	v.within = (" trong %d lượt" % int(w.turns)) if w.has("turns") else ""
	v.left_txt = (": còn %s lượt" % str(v.get("left", ""))) if w.has("turns") else ""
	var g: Dictionary = theme().get("goals", {}).get(w.type, {})
	return str(g.get(form, w.type)).format(v)

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
				names.append(theme().units.p[type].name if type != "hero" else "Tướng")
		return " hoặc ".join(names)
	match t:
		"v":
			return text("tileVillage").format({ "capV": who.call(func(st: Dictionary, _t: String) -> bool: return st.get("capV", false)), "income": Rules.TERRAIN.v.income })
		"x":
			return text("tileRuin").format({ "capV": who.call(func(st: Dictionary, _t: String) -> bool: return st.get("capV", false)),
				"raze": who.call(func(st: Dictionary, _t: String) -> bool: return st.get("raze", false)) })
		"c":
			var cc: String = who.call(func(st: Dictionary, _t: String) -> bool: return st.get("capC", false))
			return text("tileCastle").format({ "capC": cc, "capC_l": cc.to_lower(), "income": Rules.TERRAIN.c.income })
		"~":
			return text("tileWater").format({ "water": who.call(func(st: Dictionary, _t: String) -> bool: return st.move == "water") })
		"t":
			return text("tileTemple").format({ "heal": Rules.RULES.heal })
	return ""


# ---------- saves ----------
const STATE_V := 4 # Game.new_game writes it as "v"; bump + migrate_save when the saved state shape changes
## v3 -> v4: aura / poison stamps carry their amount (auraAtk / poisonAmt); v3 had them fixed at 10
const V3_STAMP := 10

## saves from before the two-commander change named the commander per mission; same stats, so map onto the fixed ones
const OLD_HEROES := { "trungtrac": "anhhung", "todinh": "tuonggiac", "mavien": "tuonggiac" }
static func migrate_save(v: Dictionary) -> void:
	var st: Variant = v.get("state")
	if st is Dictionary and int(st.get("v", 0)) == 3 and st.get("units") is Array:
		for u: Variant in st.units:
			if u is Dictionary and u.get("aura") != null and not u.has("auraAtk"):
				u.auraAtk = V3_STAMP
			if u is Dictionary and u.get("poison") != null and not u.has("poisonAmt"):
				u.poisonAmt = V3_STAMP
		st.v = 4
	var hk: Variant = v.get("state", {}).get("heroKey") if v.get("state") is Dictionary else null
	if hk is Dictionary:
		for side: String in hk:
			hk[side] = OLD_HEROES.get(hk[side], hk[side])
	if v.get("ctx") is Dictionary and v.ctx.has("hero"):
		v.ctx.hero = OLD_HEROES.get(v.ctx.hero, v.ctx.hero)

## a save still matches the shipped content: same state version + shape, known win type / unit types, its mission
## still exists, every commander key is still a hero in theme and rules, every tile is known
static func save_fits(v: Dictionary) -> bool:
	var st: Variant = v.get("state")
	if not (st is Dictionary) or int(st.get("v", 0)) != STATE_V:
		return false
	for k: String in ["units", "tiles", "owner", "gold", "heroKey", "allowed", "win", "unitCap", "graves", "heroDead", "heroDeaths", "heroSaved", "rng"]:
		if not st.has(k):
			return false
	if not Objectives.has(str(st.win.get("type", ""))):
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
