class_name Credits
extends RefCounted
## "Giới thiệu" page content: who made what + licence notices the bundled assets require (CC BY attribution, OFL / Apache /
## Godot MIT notices). Full licence texts come from the engine (Engine.get_license_info has OFL-1.1, Apache-2.0, ...).

const AUTHOR := "Nguyen Van Do"
const CONTACT := "nguyenvando510@gmail.com"

## [heading, body lines]; body = plain text, one paragraph per entry
static func sections() -> Array:
	return [
		["Làm game", ["Thiết kế, lập trình, hình ảnh, âm thanh: %s" % AUTHOR, "Liên hệ: %s" % CONTACT]],
		[
			"Hình ảnh",
			[
				"Quân lính, địa hình, công trình, biểu tượng giao diện: vẽ riêng cho game.",
				"Biểu tượng quân từ game-icons.net, giấy phép CC BY 3.0 (creativecommons.org/licenses/by/3.0): "
				+ "Pikeman, Archer, Drum, Sun priest, Elephant, Cavalry, Brute — Delapouite; Catapult — HeavenlyDog; "
				+ "Bandaged — Lorc; Swordwoman — Cathelineau. Đã bỏ nền vuông, còn lại giữ nguyên.",
				"Emoji: Noto Emoji © Google LLC, giấy phép Apache 2.0.",
			],
		],
		["Âm thanh", ["Hiệu ứng và nhạc: tổng hợp bằng code trong game."]],
		[
			"Phông chữ (SIL Open Font License 1.1)",
			[
				"Be Vietnam Pro — Copyright 2021 The Be Vietnam Pro Project Authors (github.com/bettergui/BeVietnamPro)",
				"Alegreya SC — Copyright 2011 The Alegreya Project Authors (github.com/huertatipografica/Alegreya)",
				"Paytone One — Copyright 2011 The Paytone Project Authors (github.com/googlefonts/paytoneFont), "
				+ "Reserved Font Names \"Paytone\" and \"Paytone One\"",
				"Noto Sans Symbols 2 — Copyright 2022 The Noto Project Authors (github.com/notofonts/symbols)",
			],
		],
		["Engine", ["Làm bằng Godot Engine %s (godotengine.org), giấy phép MIT." % Engine.get_version_info().string]],
	]

## Godot's own MIT notice (must ship with the game)
static func godot_notice() -> String:
	return Engine.get_license_text()

## full texts page: [title, text] per block — the licences named above, then Godot's third-party components
## (copyright lines) and every licence text the engine carries
static func full_texts() -> Array:
	var info := Engine.get_license_info()
	var out: Array = []
	for key: String in ["OFL-1.1", "Apache-2.0"]:
		if info.has(key):
			out.append([key, str(info[key])])
	var lines := PackedStringArray()
	for comp: Dictionary in Engine.get_copyright_info():
		var comp_name := str(comp["name"])
		if comp_name == "Godot Engine":
			continue
		var parts: Array = comp["parts"]
		for part: Dictionary in parts:
			var who: Array = part["copyright"]
			lines.append("%s — © %s (%s)" % [comp_name, ", ".join(PackedStringArray(who)), str(part["license"])])
	out.append(["Thành phần bên thứ ba trong Godot Engine", "\n".join(lines)])
	for key: String in info:
		if key in ["OFL-1.1", "Apache-2.0"]:
			continue
		out.append([key, str(info[key])])
	return out
