extends RefCounted
## mission m06: Kỵ Binh Bãi Sông. Format: docs/content.md

const DEF := {
	"id": "m06",
	"order": 6,
	"title": "Kỵ Binh Bãi Sông",
	"place": "Đồng Nhân · quận Hai Bà Trưng, Hà Nội",
	"region": "Hai Bà Trưng",
	"pos": [57, 54],
	"history": "Đền Hai Bà Trưng ở Đồng Nhân nằm trong quận Hai Bà Trưng, quận mang tên Hai Bà.",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": ["bird"],
	"allowed": {
		"p": ["soldier", "archer", "drum", "elephant", "shaman", "bird"],
		"e": ["soldier", "archer", "drum", "shaman", "bird"],
	},
	"gold": { "p": 750, "e": 100 },
	"incomeMul": { "e": 0.6 },
	"win": { "type": "castles" },
	"map": {
		"rows": [
			"...v.~~~~.....",
			"...r~~~~~.vrc.",
			"..rr~~vr=rrr..",
			"~~=~~.r.~~~=~~",
			"hfr.~.r..~frfh",
			"hvrr=rr..=hrvh",
			"hfr.~.r..~.ffh",
			"~~=~~~v.~~~=~~",
			".cr.~~~~~...f.",
			"..v.~~~~~..hhf",
		],
	},
	"owner": [[1, 8, "p"], [12, 1, "e"]],
	"units": [
		["p", "hero", 2, 8],
		["p", "bird", 1, 9],
		["p", "archer", 0, 8],
		["p", "soldier", 3, 8],
		["e", "hero", 11, 1, { "guard": true }],
		["e", "bird", 12, 2],
		["e", "bird", 10, 0],
		["e", "soldier", 10, 2],
		["e", "archer", 11, 2],
	],
	"story": {
		"intro": [
			["todinh", "Hai người đàn bà mà dám chống triều đình? Kỵ binh, vượt sông giẫm nát chúng!"],
			["trungtrac", "Bãi sông này nhiều nhánh nước. Khinh kỵ của ta lội chỗ cạn, đi đường tắt mà đánh."],
			["lactuong", "Coi chừng cung thủ Hán. Ngựa trúng tên là đau lắm."],
		],
		"outro": [["trungtrac", "Bãi sông đã yên. Tô Định rút về Long Biên."]],
	},
	"tips": [
		"[b]Khinh kỵ[/b] đi mọi ô chỉ tốn 1, lội qua được sông. Nhưng đứng đâu cũng không được thêm thủ.",
		"Nỏ thủ và cung thủ Hán được +20 công khi bắn kỵ binh. Giữ nỏ thủ gần ngựa của ta.",
		"Cầu tre là chỗ hẹp: một con voi đứng chặn cầu là cả đội bộ binh địch phải dừng.",
	],
}
