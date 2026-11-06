extends RefCounted
## mission m06: Trận Bãi Sông. Format: docs/content.md

const DEF := {
	"id": "m06",
	"order": 6,
	"title": "Trận Bãi Sông",
	"place": "Đồng Nhân · quận Hai Bà Trưng, Hà Nội",
	"region": "Hai Bà Trưng",
	"pos": [57, 54],
	"history": "Đền Hai Bà Trưng ở Đồng Nhân nằm trong quận Hai Bà Trưng, quận mang tên Hai Bà.",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "elephant"], "e": ["soldier", "archer", "drum", "elephant"] },
	"gold": { "p": 750, "e": 100 },
	"win": { "type": "hero" },
	"map": {
		"rows": [
			"...v.~~~~.....",
			"...r~~~~~.vrc.",
			"..rr~~vr=rrr..",
			"~~=~~.r.~~~=~~",
			"hfr.~.r..~frfh",
			"hvrr=rrt.=hrvh",
			"hfr.~.r..~.ffh",
			"~~=~~~v.~~~=~~",
			".cr.~~~~~...f.",
			"..v.~~~~~..hhf",
		],
	},
	"owner": [[1, 8, "p"], [12, 1, "e"]],
	"units": [
		["p", "hero", 2, 8],
		["p", "elephant", 3, 9],
		["p", "archer", 0, 8],
		["p", "soldier", 3, 8],
		["e", "hero", 11, 1, { "guard": true }],
		["e", "archer", 12, 2],
		["e", "soldier", 10, 0],
		["e", "soldier", 10, 2],
		["e", "archer", 11, 2],
		["e", "elephant", 13, 2],
	],
	"story": {
		"intro": [
			["todinh", "Hai người đàn bà mà dám chống triều đình? Lội qua bãi sông, giẫm nát chúng!"],
			[
				"trungtrac",
				"Bãi sông này nhiều nhánh nước. Giặc lội thì chậm, đứng dưới nước lại không chỗ nấp. Ta giữ đầu cầu, đợi giặc lội sang mà đánh.",
			],
			["lactuong", "Giữa bãi có ngôi đền cổ. Ai đứng ở đó thì mau lành vết thương, ta hay giặc cũng vậy."],
		],
		"outro": [["trungtrac", "Bãi sông đã yên. Tô Định rút về Long Biên."]],
	},
	"tips": [
		"Lội sông tốn 3 bước và [b]không được thủ[/b]: đánh giặc lúc chúng đang lội, đừng để quân ta đứng dưới nước.",
		"[b]Đền[/b] giữa bãi: quân phe nào đứng đó cũng hồi 20 máu mỗi lượt, thủ +15. Không ai chiếm được.",
		"Cầu đi nhanh hơn lội. Một con voi chặn đầu cầu là địch phải xuống nước mà vòng.",
		"Mục tiêu: [b]hạ Tướng giặc[/b]. Hắn giữ thành bên kia sông: phá hàng lính quanh hắn trước rồi mới vây.",
	],
}
