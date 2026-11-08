class_name LevelSelect
extends RefCounted
## "Thử thách" helpers shared by the kingdom map (scripts/ui/world_map.gd), the title menu and the tests: next level to
## play, tier colour / name. (The 20-cell grid it used to draw was replaced by the map 2026-11-08.)

const TIER_COL := { "easy": Color("#3f7a2e"), "mid": Color("#c98a1e"), "hard": Color("#b3262e") }
const TIER_NAME := { "easy": "Dễ", "mid": "Trung bình", "hard": "Khó" }

## next level to play: the first not won after the furthest win (`open`), so levels inserted in front (t01/t02) never
## pull a veteran back; past the last level -> the first one not won; all won -> lv.size()
static func first_unwon(lv: Array, open: int) -> int:
	for i in range(maxi(open, 0), lv.size()):
		var def: Dictionary = lv[i]
		if not Store.is_done(str(def.id)):
			return i
	for i in lv.size():
		var def: Dictionary = lv[i]
		if not Store.is_done(str(def.id)):
			return i
	return lv.size()

static func tier_of(def: Dictionary) -> String:
	var t: String = def.get("tier", "mid")
	return t if TIER_COL.has(t) else "mid"
