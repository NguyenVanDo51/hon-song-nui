class_name Lang
extends RefCounted
## UI language (docs/i18n.md). Source text = Vietnamese, written straight in the code / content; every other language
## is a gettext catalog in locale/<code>.po keyed by that Vietnamese text (tools/i18n_extract.py keeps them in sync).
## Default = the device language when supported, else English; the player's pick (Store "lang") wins; debug flag lang=vi|en.

const SUPPORTED := ["vi", "en"]
const NAMES := { "vi": "Tiếng Việt", "en": "English" }
const SOURCE := "vi"

static var current := SOURCE

## device language if we have it, else English (the store build is global)
static func device_default() -> String:
	var dev := OS.get_locale_language()
	return dev if dev in SUPPORTED else "en"

## switch language: TranslationServer (Controls auto-translate their text) + drop the translated content caches
static func apply(code: String) -> void:
	current = code if code in SUPPORTED else SOURCE
	TranslationServer.set_locale(current)
	Content.reset_cache()

## one string (any value is str()-ed); Vietnamese (the source) needs no lookup
static func t(v: Variant) -> String:
	var s := str(v)
	if current == SOURCE or s == "":
		return s
	return str(TranslationServer.translate(s))

## every String value inside dictionaries / arrays (keys untouched); text with no catalog entry stays as it is
static func deep(v: Variant) -> Variant:
	if current == SOURCE:
		return v
	if v is String:
		return t(v)
	if v is Dictionary:
		var d: Dictionary = v
		for k: Variant in d:
			d[k] = deep(d[k])
		return d
	if v is Array:
		var a: Array = v
		for i in a.size():
			a[i] = deep(a[i])
		return a
	return v
