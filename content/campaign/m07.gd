extends RefCounted
# prose / map rows: one line each reads better
# gdlint: disable=max-line-length
## mission m07: Vây Thành Long Biên. Format: docs/content.md

const DEF := {
	"id": "m07",
	"order": 7,
	"title": "Vây Thành Long Biên",
	"place": "Long Biên, Hà Nội",
	"region": "Long Biên",
	"pos": [70, 44],
	"history": "Long Biên là tên một huyện của quận Giao Chỉ thời Hán. Quận Long Biên ngày nay mang tên ấy.",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": ["catapult"],
	"allowed": { "p": ["soldier", "archer", "drum", "elephant"], "e": ["soldier", "archer", "drum", "elephant", "catapult"] },
	"gold": { "p": 1200, "e": 0 },
	"win": { "type": "castles" },
	"map": {
		"rows": [
			"~~~~~.......c.f",
			"~~~...vrrrrrrvh",
			"~~........hf.r.",
			"~f....f...fh.c.",
			"fhv...h=.....r.",
			"..r..fh~~...rv.",
			"..r...~~....r..",
			".crrrvr=rrrrr..",
			".r....fhfhmhvhf",
			".v...fhmhffhff.",
		],
	},
	"owner": [[1, 7, "p"], [12, 0, "e"], [13, 3, "e"], [13, 1, "e"]],
	"units": [
		["p", "hero", 2, 7],
		["p", "catapult", 1, 8],
		["p", "elephant", 2, 6],
		["p", "archer", 0, 7],
		["p", "soldier", 3, 8],
		["e", "hero", 12, 2],
		["e", "archer", 11, 3, { "guard": true, "rank": 1 }],
		["e", "archer", 9, 1, { "guard": true }],
		["e", "elephant", 11, 4],
		["e", "soldier", 12, 4],
		["e", "catapult", 13, 2, { "guard": true }],
	],
	"story": {
		"intro": [
			["trungtrac", "Long Biên có hai đồn, nấp sau đồi núi. Đánh thẳng vào là mất nhiều quân."],
			["lactuong", "Thợ làng đã dựng máy bắn đá, ném xa tới 4 ô."],
			["todinh", "Đá của các ngươi không phá nổi tường thành!"],
		],
		"outro": [["trungtrac", "Long Biên đã vỡ. Tô Định chỉ còn trị sở Luy Lâu."]],
	},
	"tips": [
		"[b]Máy bắn đá[/b] ném 2–4 ô nhưng [b]đã đi thì không ném[/b] trong lượt đó, và không đánh trả. Đặt chỗ an toàn rồi ném liên tục. Ném được cả làng địch cho hỏng. Trận này chỉ có một máy, chưa mua thêm được: giữ nó sau voi.",
		"Địch có 2 thành: phải chiếm cả hai [b]và[/b] hạ Tướng giặc mới thắng.",
		"Đồi +10 thủ, núi +15 thủ cho mọi quân. Đứng sau đồi núi mà ném đá.",
	],
}
