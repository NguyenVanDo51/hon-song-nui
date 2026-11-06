extends SceneTree
## all chibi unit SVGs (p row, e row) on grass at 128 px + 64 px -> one PNG. -- <out.png>
func _init() -> void:
	var types := ["hero", "soldier", "archer", "boat", "shaman", "drum", "wolf", "elephant", "catapult", "bird", "ghost"]
	var big := 128
	var img := Image.create(types.size() * big, big * 2 + 80, false, Image.FORMAT_RGBA8)
	img.fill(Color("#86ab57"))
	for i in types.size():
		for r in 2:
			var side := "p" if r == 0 else "e"
			var src := FileAccess.get_file_as_string("res://assets/units/styles/chibi/%s_%s.svg" % [types[i], side])
			var a := Image.new()
			if a.load_svg_from_string(src, big / 256.0) != OK:
				push_error("roster_sheet: bad svg %s_%s" % [types[i], side])
			img.blend_rect(a, Rect2i(0, 0, big, big), Vector2i(i * big, r * big))
			var s := Image.new()
			s.load_svg_from_string(src, 0.25)
			img.blend_rect(s, Rect2i(0, 0, 64, 64), Vector2i(i * big + r * 64, big * 2 + 8))
	var err := img.save_png(OS.get_cmdline_user_args()[0])
	if err != OK:
		push_error("roster_sheet: save -> %s" % error_string(err))
	quit()
