extends RefCounted
## mission m10: Sóng An Biên. Format: docs/content.md

const DEF := {
	"id": "m10", "order": 10, "chapter": "c2",
	"title": "Sóng An Biên",
	"place": "An Biên · Hải Phòng",
	"region": "An Biên", "pos": [80, 44],
	"history": "Nữ tướng Lê Chân lập trang An Biên, luyện thủy binh ở cửa biển. Thành phố Hải Phòng ngày nay thờ bà như người mở đất.",
	"hero": "lechan", "enemyHero": "doanchi",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "shaman", "elephant"], "e": ["soldier", "archer", "elephant"] },
	"gold": { "p": 500, "e": 200 }, "incomeMul": { "e": 0.8 },
	"win": { "type": "hero" },
	"map": { "rows": [
		".c..f..~~~..h..",
		"...v...~~~..f.v",
		".f...h.===.....",
		"....f..~~~.v...",
		"..v....~~~...f.",
		".h..f..~~~..h..",
		"...v...~~~.f...",
		".f.....===..v..",
		"...h..f~~~..f.c",
		"..v....~~~.....",
	] },
	"owner": [[1, 0, "p"], [3, 1, "p"], [14, 8, "e"], [12, 7, "e"]],
	"units": [
		["p", "hero", 2, 1], ["p", "soldier", 1, 1], ["p", "archer", 0, 0], ["p", "elephant", 2, 2],
		["e", "hero", 13, 8, { "guard": true }], ["e", "soldier", 12, 6], ["e", "archer", 14, 7], ["e", "soldier", 11, 4], ["e", "elephant", 13, 9],
	],
	"story": {
		"intro": [
			["lechan", "Thủy binh Hán của Đoàn Chí vào cửa sông, định đánh thọc lên Lãng Bạc."],
			["doanchi", "Đàn bà luyện thủy quân? Lâu thuyền của ta sẽ nghiền nát thuyền nan của chúng!"],
			["lechan", "Sông nước là nhà của ta. Hạ được Đoàn Chí, thủy binh giặc sẽ rối loạn."],
		],
		"outro": [["lechan", "Đoàn Chí đã ngã. Thủy binh giặc phải quay về Hợp Phố chờ lệnh Mã Viện."]],
	},
	"tips": [
		"Mục tiêu: [b]hạ Đoàn Chí[/b]. Hắn đứng gác gần thành địch phía đông nam.",
		"Lê Chân đi được trên sông, lính đứng cạnh bà +10 thủ. Bộ binh và voi phải qua [b]cầu[/b].",
		"Đoàn Chí cũng đi được trên sông. Đừng để Lê Chân một mình giữa dòng.",
	],
}
