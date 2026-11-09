extends SceneTree
## writes docs/design/data.js (window.DESIGN) from the real game data, so the design-system pages stay 1:1:
## sounds + music (Audio), heroes, units, terrain, every display string, levels, skirmish maps, style tokens, asset lists.
## run: godot --headless --path . -s tools/design_dump.gd     (after changing a sound recipe, theme, unit, level or style)

const OUT := "res://docs/design/data.js"
const GUIDE := preload("res://content/guide.gd")
const THEME_SCRIPT := preload("res://content/theme.gd")
## attack sound per rig spec (scripts/ui/rig/specs/<type>.gd `a.sound(...)`); impact = rig.gd hit(): heavy if unit heavy or dmg >= 35
const RIG_SOUND := {
	"hero": "slash",
	"soldier": "slash",
	"archer": "arrow",
	"boat": "slash",
	"shaman": "orb",
	"drum": "orb",
	"wolf": "",
	"elephant": "heavy",
	"catapult": "rock",
	"bird": "orb",
	"ghost": "slash",
}
## terrain key -> art files in assets/terrain/<style>/ (scripts/ui/board_paint.gd _tile_art / _bld_art)
const TERRAIN_ART := {
	".": ["grass_a", "grass_b"],
	"r": ["grass_a", "grass_b"],
	"f": ["forest_a", "forest_b"],
	"h": ["hill_a", "hill_b"],
	"m": ["mountain_a", "mountain_b"],
	"~": ["water"],
	"=": ["bridge"],
	"v": ["village_p", "village_e", "village_n"],
	"c": ["castle_p", "castle_e", "castle_n"],
	"x": ["village_x"],
	"t": ["temple"],
}

func _files(dir: String, ext: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.get_extension() == ext:
			out.append(dir.trim_prefix("res://") + "/" + f)
	out.sort()
	return out

## locale/<code>.po -> { code: { Vietnamese source: translation } } (docs/design/chu.html shows them side by side)
func _catalogs() -> Dictionary:
	var out := { }
	for f: String in DirAccess.get_files_at("res://locale"):
		if not f.ends_with(".po"):
			continue
		var cat: Translation = load("res://locale/" + f)
		var m := { }
		for k: StringName in cat.get_message_list():
			m[str(k)] = str(cat.get_message(k))
		out[f.get_basename()] = m
	return out

## raw SVG text of the player-side art (file:// pages can't fetch): previews recolour it the way RigData.TEAM_SWAP does
func _svg_texts(fig: String) -> Dictionary:
	var out := { }
	var paths := ["assets/units/styles/%s/hero_e.svg" % fig]
	for p: String in _files("res://assets/units/styles/" + fig, "svg"):
		if p.ends_with("_p.svg"):
			paths.append(p)
	for b: String in ["castle_p", "castle_n", "village_p", "village_n"]:
		paths.append("assets/terrain/%s/%s.svg" % [fig, b])
	for p: String in paths:
		out[p] = FileAccess.get_file_as_string("res://" + p)
	return out

func _initialize() -> void:
	var th: Dictionary = Content.theme()
	var music := { }
	var rec := Audio.recipes()
	for k: String in rec:
		if k.begins_with("m:"):
			music[k.substr(2)] = rec[k]
	var fig := Token.fig_style
	var heroes := { }
	var th_heroes: Dictionary = th.heroes
	for id: String in th_heroes:
		var src: Dictionary = th_heroes[id]
		var h := src.duplicate()
		h["fig"] = "assets/units/styles/%s/hero_%s.svg" % [fig, h.side]
		h["traits"] = Content.traits("hero", id)
		heroes[id] = h
	# units: theme look + rules + guide + art + sounds
	var unit_order: Array = ["hero"] + Array(Rules.BUY_ORDER) + ["ghost"]
	var units := { }
	for t: String in unit_order:
		var look: Variant = THEME_SCRIPT.UNITS.get(t)
		if look == null:
			look = { "name": "Tướng", "icon": "👑" }
		var hk: Variant = null
		if t == "hero":
			hk = "anhhung"
		units[t] = {
			"look": look,
			"rules": Rules.UNITS[t],
			"role": Content.role(t),
			"play": Content.how_to_play(t),
			"traits": Content.traits(t, hk),
			"figP": "assets/units/styles/%s/%s_p.svg" % [fig, t],
			"figE": "assets/units/styles/%s/%s_e.svg" % [fig, t],
			"rigDemo": "docs/anim_demo/%s.html" % ("hero_p" if t == "hero" else t),
			"sound": RIG_SOUND.get(t, ""),
			"buyable": t in Rules.BUY_ORDER,
		}
	# terrain
	var terrain_order := [".", "r", "f", "h", "m", "~", "=", "v", "c", "x", "t"]
	var terrain := { }
	for k: String in terrain_order:
		var arts := []
		for a: String in TERRAIN_ART.get(k, []):
			var p := "assets/terrain/%s/%s.svg" % [fig, a]
			if FileAccess.file_exists("res://" + p):
				arts.append(p)
		terrain[k] = { "look": th.terrain[k], "rules": Rules.TERRAIN[k], "note": Content.tile_note(k), "art": arts }
	# levels (+ objective wording) and skirmish maps
	var levels := []
	for m: Dictionary in Content.levels():
		var hkeys := { "p": m.get("hero", "anhhung"), "e": m.get("enemyHero", "tuonggiac") }
		var win: Dictionary = m.get("win", { "type": "castles" })
		var rows: Array = m.map.rows
		levels.append(
			{
				"id": m.id,
				"order": m.order,
				"title": m.get("title", ""),
				"lore": m.get("lore", ""),
				"tier": m.get("tier", ""),
				"ai": m.get("ai", ""),
				"win": win,
				"short": Content.goal_text(win, "short", hkeys),
				"brief": Content.goal_text(win, "brief", hkeys),
				"size": [str(rows[0]).length(), rows.size()],
				"newUnits": m.get("newUnits", []),
				"gold": m.get("gold", { }),
				"stars": m.get("stars", { }),
				"tutorial": m.has("tutorial"),
				"quests": m.has("quests"),
			}
		)
	var skirmish := []
	var sk_src: Dictionary = preload("res://content/skirmish_maps.gd").MAPS
	for k: String in sk_src:
		var sm: Dictionary = sk_src[k]
		var srows: Array = sm.rows
		skirmish.append({ "id": k, "name": sm.get("name", k), "blurb": sm.get("blurb", ""), "size": [str(srows[0]).length(), srows.size()] })
	# style tokens: every Color const in scripts/ui/style.gd
	var colors := { }
	var style_scr: GDScript = load("res://scripts/ui/style.gd")
	var cmap: Dictionary = style_scr.get_script_constant_map()
	for k: String in cmap:
		if cmap[k] is Color:
			var c: Color = cmap[k]
			colors[k] = "#" + c.to_html(c.a < 1.0)
	var data := {
		"version": ProjectSettings.get_setting("application/config/version"),
		"sfx": Audio.SFX,
		"sfxGain": Audio.SFX_GAIN * Audio.MASTER,
		"musicGain": Audio.MUSIC_GAIN * Audio.MASTER,
		"music": music,
		"musicConst": {
			"scale": Audio.SCALE,
			"base": Audio.BASE,
			"beat": Audio.BEAT,
			"degrees": Audio.DEGREES,
			"resolve": Audio.RESOLVE,
			"pool": Audio.MUSIC_POOL,
			"sfxPool": Audio.POOL,
			"sr": Audio.SR,
		},
		"factions": th.factions,
		"heroes": heroes,
		"heroStats": Rules.UNITS.hero,
		"figStyle": fig,
		"unitOrder": unit_order,
		"units": units,
		"rankTitles": THEME_SCRIPT.RANK_TITLES,
		"terrainOrder": terrain_order,
		"terrain": terrain,
		"texts": { "title": th.title, "tagline": th.tagline, "lede": th.get("lede", ""), "text": th.text, "goals": th.goals, "ends": th.ends },
		"levels": levels,
		"skirmish": skirmish,
		"colors": colors,
		"fonts": _files("res://assets/fonts", "ttf"),
		"icons": _files("res://assets/ui/icons", "svg"),
		"emoji": _files("res://assets/emoji", "png"),
		"teamSwap": RigData.TEAM_SWAP,
		"i18n": _catalogs(),
		"svgText": _svg_texts(fig),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/design"))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f == null:
		push_error("design_dump: %s" % error_string(FileAccess.get_open_error()))
		quit(1)
		return
	f.store_string("// generated by tools/design_dump.gd — do not edit\nwindow.DESIGN = %s;\n" % JSON.stringify(data, "  ", false))
	f.close()
	print(
		"design_dump: %d sfx, %d units, %d terrain, %d levels, %d skirmish, %d colours -> %s"
		% [Audio.SFX.size(), units.size(), terrain.size(), levels.size(), skirmish.size(), colors.size(), OUT]
	)
	quit()
