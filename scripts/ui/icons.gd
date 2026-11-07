class_name Icons
extends RefCounted
## hand-drawn F1 icons (assets/ui/icons/*.svg, flat fill + ink outline, imported at 2x) replacing colour emoji in the UI.
## Button labels may still be written with a leading emoji ("⚔ Đánh"): Style.button turns it into Button.icon + "Đánh".

const DIR := "res://assets/ui/icons/%s.svg"
## leading glyph -> icon name
const EMOJI := {
	"⚔": "sword",
	"✖": "x",
	"🎯": "target",
	"📜": "scroll",
	"🏯": "castle",
	"🏠": "house",
	"🔨": "hammer",
	"💥": "burst",
	"⏳": "wait",
	"💬": "chat",
	"📖": "book",
	"🔇": "mute",
	"🔊": "sound",
	"💤": "sleep",
	"🔒": "lock",
	"🔄": "rotate",
	"🛡": "shield",
	"🐺": "fang",
	"👑": "crown",
	"↩": "back",
	"☠": "skull",
	"🩹": "skull",
	"⭐": "star",
	"⚙": "gear",
	"🏰": "castle",
	"🚪": "home",
}

static var _cache := { }

static func tex(icon: String) -> Texture2D:
	if not _cache.has(icon):
		_cache[icon] = load(DIR % icon)
	return _cache[icon]

## inline icon for RichTextLabel bbcode
static func bb(icon: String, px := 16) -> String:
	return "[color=#ffffff][img width=%d height=%d]%s[/img][/color]" % [px, px, DIR % icon]

## "⚔ Đánh" -> ["sword", "Đánh"]; text without a known leading glyph -> ["", text]
static func split(text: String) -> Array[String]:
	var t := text.strip_edges(true, false)
	for g: String in EMOJI:
		if t.begins_with(g):
			var rest := t.substr(g.length()).trim_prefix("️").strip_edges()
			var name: String = EMOJI[g]
			return [name, rest]
	return ["", text]

## replace every known glyph inside bbcode / label text by its inline icon
static func bb_text(text: String, px := 16) -> String:
	var out := text.replace("️", "")
	for g: String in EMOJI:
		if out.contains(g):
			var name: String = EMOJI[g]
			out = out.replace(g, bb(name, px))
	return out
