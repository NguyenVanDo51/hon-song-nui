extends RefCounted
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
	"allowed": {
		"p": ["soldier", "archer", "drum", "shaman", "elephant", "bird", "catapult"],
		"e": ["soldier", "archer", "drum", "shaman", "elephant", "bird", "catapult"],
	},
	"gold": { "p": 700, "e": 300 },
	"incomeMul": { "e": 0.55 },
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
			["lactuong", "Thợ làng đã đóng nỏ liên châu, một lần bắn nhiều mũi, xa 4 ô."],
			["todinh", "Tên của các ngươi không xuyên nổi tường thành!"],
		],
		"outro": [["trungtrac", "Long Biên đã vỡ. Tô Định chỉ còn trị sở Luy Lâu."]],
	},
	"tips": [
		"[b]Nỏ liên châu[/b] bắn 2–4 ô nhưng [b]đã đi thì không bắn[/b] trong lượt đó, và không đánh trả. Đặt chỗ an toàn rồi bắn liên tục.",
		"Địch có 2 thành: phải chiếm cả hai mới thắng.",
		"Đứng trên đồi, núi, Anh hùng được +10 thủ.",
	],
}
