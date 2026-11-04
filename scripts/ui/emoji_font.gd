class_name EmojiFont
extends RefCounted
## bitmap colour-emoji font built at boot from assets/emoji/*.png (Noto Emoji, Apache 2.0).
## Web builds can't reach system fonts, so every font falls back to this + a symbols subset instead
## (and desktop does the same, so all platforms look alike). Regenerate the PNGs: tools/build_fonts.py.

const MANIFEST := preload("res://assets/emoji/manifest.gd")
const STRIKE := 128
static var _font: FontFile

static func get_font() -> FontFile:
	if _font:
		return _font
	var f := FontFile.new()
	f.fixed_size = STRIKE
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	var asc := STRIKE * 0.86
	# line metrics kept inside Be Vietnam Pro's so fallback glyphs never make a line taller
	f.set_cache_ascent(0, STRIKE, STRIKE * 0.6)
	f.set_cache_descent(0, STRIKE, STRIKE * 0.1)
	var sz := Vector2i(STRIKE, 0)
	var idx := 0
	for code: int in MANIFEST.CODES:
		var tex: Texture2D = load("res://assets/emoji/emoji_u%x.png" % code)
		if tex == null:
			continue
		var img := tex.get_image()
		img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var w := float(img.get_width()) * STRIKE / img.get_height()
		if img.get_height() != STRIKE:
			img.resize(int(w), STRIKE, Image.INTERPOLATE_LANCZOS)
		f.set_texture_image(0, sz, idx, img)
		f.set_glyph_texture_idx(0, sz, code, idx)
		f.set_glyph_uv_rect(0, sz, code, Rect2(0, 0, img.get_width(), STRIKE))
		f.set_glyph_size(0, sz, code, Vector2(img.get_width(), STRIKE))
		f.set_glyph_offset(0, sz, code, Vector2(STRIKE * 0.04, -asc))
		f.set_glyph_advance(0, STRIKE, code, Vector2(img.get_width() + STRIKE * 0.08, 0))
		idx += 1
	_font = f
	return f

## give every bundled font the same fallback chain: emoji bitmaps, then the symbols subset
static func attach(fonts: Array) -> void:
	var sym: FontFile = load("res://assets/fonts/SymbolsSubset.ttf")
	var chain: Array[Font] = [get_font(), sym]
	for f: FontFile in fonts:
		f.fallbacks = chain
		f.allow_system_fallback = false
