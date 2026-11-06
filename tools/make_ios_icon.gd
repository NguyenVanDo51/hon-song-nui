extends SceneTree
## iOS app icon: 1024x1024 RGB (App Store rejects alpha). Castle + commander on a warm sky.
## godot --headless --path . -s tools/make_ios_icon.gd  -> assets/ios/icon_1024.png

const N := 1024

func _svg(path: String, px: int) -> Image:
	var txt := FileAccess.get_file_as_string(path)
	var probe := Image.new()
	probe.load_svg_from_string(txt, 1.0)
	var img := Image.new()
	img.load_svg_from_string(txt, float(px) / max(probe.get_width(), probe.get_height()))
	img.convert(Image.FORMAT_RGBA8)
	return img

func _init() -> void:
	var out := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		var t := float(y) / N
		var c := Color("#f6c56b").lerp(Color("#b8432f"), t)
		for x in N:
			out.set_pixel(x, y, c)
	var castle := _svg("res://assets/terrain/chibi/castle_p.svg", 900)
	@warning_ignore("integer_division")
	out.blend_rect(castle, Rect2i(Vector2i.ZERO, castle.get_size()), Vector2i((N - castle.get_width()) / 2, N - castle.get_height() - 10))
	var hero := _svg("res://assets/units/styles/chibi/hero_p.svg", 620)
	@warning_ignore("integer_division")
	out.blend_rect(hero, Rect2i(Vector2i.ZERO, hero.get_size()), Vector2i((N - hero.get_width()) / 2, N - hero.get_height() - 40))
	out.convert(Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute("res://assets/ios")
	out.save_png("res://assets/ios/icon_1024.png")
	print("icon ", out.get_size(), " format ", out.get_format())
	quit()
