extends RefCounted
## mission m10: Sóng An Biên. Format: docs/content.md

const DEF := {
	"id": "m10", "order": 10, "chapter": "c2",
	"title": "Sóng An Biên",
	"place": "An Biên · Hải Phòng",
	"region": "An Biên", "pos": [80, 44],
	"history": "Nữ tướng Lê Chân lập trang An Biên, luyện thủy binh ở cửa biển. Thành phố Hải Phòng ngày nay thờ bà như người mở đất.",
	"hero": "anhhung", "enemyHero": "tuonggiac",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "shaman", "elephant"], "e": ["soldier", "archer", "elephant"] },
	"gold": { "p": 500, "e": 250 }, "incomeMul": { "e": 0.85 },
	"win": { "type": "hero" },
	"map": { "rows": [
		".c.....~~~.....",
		".rrv...~~~rrrrv",
		"hfrrrrr===rhfff",
		"ffr....~~~rvrfh",
		"..vr...~~~..rfh",
		"...r...~~~..r.f",
		"..rvhf.~~~..r..",
		"..r.f..===..v..",
		"..r.f..~~~hfrrc",
		"f.v.hf.~~~fhf..",
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
			["lechan", "Mã Viện đích thân cầm thủy binh. Đánh lui được hắn, thủy binh giặc sẽ rối loạn."],
		],
		"outro": [["lechan", "Mã Viện trúng thương, phải lui thuyền về Hợp Phố."]],
	},
	"tips": [
		"Mục tiêu: [b]hạ Tướng giặc[/b]. Hắn đứng gác gần thành địch phía đông nam.",
		"Bộ binh và voi phải qua [b]cầu[/b]; chỉ kỵ binh lội được sông.",
		"Tướng giặc đi được trên sông. Đừng để Anh hùng một mình đầu cầu.",
	],
}
