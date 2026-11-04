extends RefCounted
## mission m22: Núi Tùng (final). Format: docs/content.md

const DEF := {
	"id": "m22", "order": 22, "chapter": "c3",
	"title": "Núi Tùng",
	"place": "Núi Tùng · Hậu Lộc, Thanh Hóa",
	"region": "Núi Tùng", "pos": [84, 20],
	"history": "Bà Triệu đánh hơn ba mươi trận. Trận cuối ở núi Tùng năm 248, Bà hy sinh khi mới hai mươi ba tuổi.",
	"hero": "batrieu", "enemyHero": "lucdan",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "shaman", "elephant", "bird", "catapult"], "e": ["soldier", "archer", "drum", "shaman", "elephant", "bird", "catapult"] },
	"gold": { "p": 900, "e": 350 }, "incomeMul": { "e": 0.6 },
	"win": { "type": "castles" },
	"map": { "rows": [
		"mmh...f...h...c.",
		"mh..v....f..v...",
		"m...f..h......f.",
		"h.....f...h..v..",
		"..v..h...~~~....",
		".f......~~~.f.c.",
		"...h..f..~~...h.",
		".v.....f......f.",
		"..f..h...f..v...",
		"h...v.....h.....",
		".c..f..h...f..h.",
		"...h....f.......",
	] },
	"owner": [[1, 10, "p"], [1, 7, "p"], [4, 9, "p"], [14, 0, "e"], [14, 5, "e"], [12, 1, "e"], [13, 3, "e"]],
	"units": [
		["p", "hero", 2, 10], ["p", "elephant", 1, 9], ["p", "elephant", 2, 9], ["p", "archer", 0, 10], ["p", "catapult", 1, 11],
		["p", "soldier", 3, 10], ["p", "drum", 2, 11],
		["e", "hero", 13, 0], ["e", "elephant", 14, 1], ["e", "archer", 13, 1], ["e", "soldier", 15, 0], ["e", "catapult", 15, 1, { "guard": true }],
		["e", "soldier", 13, 5], ["e", "archer", 15, 5], ["e", "bird", 15, 6], ["e", "elephant", 12, 4], ["e", "shaman", 14, 6],
	],
	"story": {
		"intro": [
			["lucdan", "Triệu Ẩu đã cùng đường. Hai đồn núi Tùng là mồ chôn ả."],
			["trieuquocdat", "Em à, quân Ngô gấp mấy lần ta. Hay ta lui vào rừng sâu?"],
			["batrieu", "Lui thì dân lại khổ. Đánh trận này cho Lục Dận biết đất Cửu Chân không dễ cai trị."],
		],
		"outro": [
			["batrieu", "Hai đồn núi Tùng đã vỡ. Lục Dận phải lui về giữ thành."],
			["truyenthuyet", "Sử chép Bà Triệu hy sinh ở núi Tùng năm ấy. Nhưng câu ca vẫn còn: \"Muốn coi lên núi mà coi, coi Bà Triệu tướng cưỡi voi đánh cồng\"."],
		],
	},
	"tips": [
		"Trận cuối: Lục Dận có [b]2 thành[/b] và nhiều vàng. Chiếm làng sớm để mua đủ quân.",
		"Máy bắn đá của ta bắn 2–4 ô, đặt sau voi rồi bắn liên tục.",
		"Hồ giữa bản đồ chia đôi chiến trường: đánh một thành trước, đừng chia quân.",
	],
}
