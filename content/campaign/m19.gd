extends RefCounted
## mission m19: Đồn Bồ Điền. Format: docs/content.md

const DEF := {
	"id": "m19", "order": 19, "chapter": "c3",
	"title": "Đồn Bồ Điền",
	"place": "Bồ Điền · Hậu Lộc, Thanh Hóa",
	"region": "Bồ Điền", "pos": [56, 30],
	"history": "Bồ Điền (Hậu Lộc ngày nay) là căn cứ lớn của Bà Triệu. Đền Bà Triệu được dựng ở đây.",
	"hero": "batrieu", "enemyHero": "hieuuy",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "shaman", "elephant", "bird"], "e": ["soldier", "archer", "bird", "elephant"] },
	"gold": { "p": 650, "e": 250 }, "incomeMul": { "e": 0.7 },
	"win": { "type": "hero" },
	"map": { "rows": [
		"f.h..f..h..f.c.",
		"..f...v..f..f..",
		"h...f....h.f..v",
		"..f..h.ff..h...",
		".v....fff..f...",
		"...h...f.....h.",
		".f..f.....v....",
		"...v..h...f..f.",
		".c..f...h....h.",
		"h...h..f....f..",
	] },
	"owner": [[1, 8, "p"], [3, 7, "p"], [1, 4, "p"], [13, 0, "e"], [14, 2, "e"], [6, 1, "e"]],
	"units": [
		["p", "hero", 2, 8], ["p", "elephant", 1, 7], ["p", "archer", 0, 8], ["p", "soldier", 2, 9], ["p", "drum", 1, 9], ["p", "shaman", 0, 7],
		["e", "hero", 12, 1, { "guard": true }], ["e", "bird", 13, 1], ["e", "bird", 11, 2], ["e", "soldier", 12, 0],
		["e", "archer", 14, 0], ["e", "soldier", 10, 3], ["e", "elephant", 12, 3],
	],
	"story": {
		"intro": [
			["thamtu", "Hiệu úy nhà Ngô đem kỵ binh đóng ở Bồ Điền, ngày ngày cướp lúa của dân."],
			["batrieu", "Kỵ binh mạnh ở chỗ trống. Ta đánh ở rừng, nơi ngựa không phi được."],
			["hieuuy", "Đàn bà cưỡi voi? Kỵ binh của ta sẽ vòng ra sau lưng mà chém."],
		],
		"outro": [["batrieu", "Hiệu úy đã ngã. Bồ Điền là của ta, từ đây đánh ra khắp Cửu Chân."]],
	},
	"tips": [
		"Mục tiêu: [b]hạ Hiệu úy[/b]. Hắn gác trong rừng gần thành địch.",
		"Kỵ binh địch đi mọi ô tốn 1 nhưng không được địa hình che. [b]Nỏ thủ[/b] bắn kỵ binh +20 công.",
		"Mua được [b]khinh kỵ[/b] của ta để đuổi kịp kỵ binh địch.",
	],
}
