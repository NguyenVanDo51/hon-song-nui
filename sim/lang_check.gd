extends SceneTree
## shown-text language check (docs/i18n.md "Kiểm"): boot in one language, switch to the other the way the language
## button does (statics + TranslationServer survive the reload), open the main screens, read what every visible
## Label / Button / RichTextLabel really shows (atr = Godot's auto-translate) and fail on the wrong language.
##   vi: nothing may show an English catalog line (2026-11-09: locale/fallback "en" turned Controls English)
##   en: nothing may show untranslated Vietnamese, except KEEP (brand)
## Blind spot: text drawn with draw_string / Draw.text_c (board, map) is not a Control -> not read here.
## <godot> --headless --path . -s sim/lang_check.gd       (tools/lint.sh runs it)

const KEEP := ["Công Thành Chiến"] # game name stays Vietnamese in English (docs/i18n.md)
const VI := "àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ"

var main: Main
var fails := 0

func _init() -> void:
	Store.use_profile("lang_check") # never touch the player's save / settings
	_run.call_deferred()

func boot(code: String) -> void:
	Store.set_v("lang", code)
	if main != null:
		main.queue_free()
		await process_frame
	var scn: PackedScene = load("res://main.tscn")
	main = scn.instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout

static func has_vi(s: String) -> bool:
	for c in s.to_lower():
		if VI.contains(c):
			return true
	return false

func scan(n: Node, code: String, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	var txt := ""
	if n is Label:
		txt = (n as Label).text
	elif n is Button:
		txt = (n as Button).text
	elif n is RichTextLabel:
		txt = (n as RichTextLabel).text
	if txt.strip_edges() != "":
		var shown := n.atr(txt)
		var bad := shown != txt if code == "vi" else (shown == txt and has_vi(txt) and not KEEP.has(txt))
		if bad:
			out.append("%s -> %s" % [txt.replace("\n", " "), shown.replace("\n", " ")])
	for c: Node in n.get_children():
		scan(c, code, out)

func check(where: String, code: String) -> void:
	await process_frame
	var out := []
	scan(main, code, out)
	var ok := out.is_empty() and Lang.current == code and TranslationServer.get_locale() == code
	print(("ok   " if ok else "FAIL ") + "%s [%s] locale %s, %d wrong-language texts" % [where, code, TranslationServer.get_locale(), out.size()])
	for line: String in out.slice(0, 8):
		print("       " + line)
	if not ok:
		fails += 1

func screens(code: String) -> void:
	await check("title", code)
	main.show_levels()
	await check("levels map", code)
	main.show_duel()
	await check("1 vs 1 setup", code)
	main.show_title()
	main.menus.show_credits()
	await check("credits", code)
	main.show_title()
	main.menus.open_codex("p")
	await check("unit book", code)
	main.show_title()
	var hp: String = Content.heroes_of("p")[0]
	var he: String = Content.heroes_of("e")[0]
	var ctx := { "kind": "duel", "map": "dong_bang", "hero": hp, "heroE": he, "ctrlE": "ai:normal", "gold": 300, "cap": 15 }
	main.start_game(Game.new_game(Content.duel_def("dong_bang", hp, he, "ai:normal")), ctx)
	await create_timer(0.8).timeout
	await check("in game", code)
	main.game.hud.show_menu(true)
	await check("⚙ menu", code)
	main.game.hud.show_menu(false)
	Objectives.surrender(main.game.s, "p")
	main.game.turns.finish()
	await create_timer(1.2).timeout
	await check("end card", code)
	main.show_title()

func _run() -> void:
	for pair: Array in [["en", "vi"], ["vi", "en"]]: # second language = after a switch, like the button
		var first: String = pair[0]
		var then: String = pair[1]
		await boot(first)
		await boot(then)
		await screens(then)
	print("LANG CHECK fails=%d" % fails)
	quit(1 if fails else 0)
