extends RefCounted
## mission m06: Thủy Binh Bãi Sông. Format: docs/content.md

const DEF := {
	"id": "m06",
	"order": 6,
	"title": "Thủy Binh Bãi Sông",
	"place": "Đồng Nhân · quận Hai Bà Trưng, Hà Nội",
	"region": "Hai Bà Trưng",
	"pos": [57, 54],
	"history": "Đền Hai Bà Trưng ở Đồng Nhân nằm trong quận Hai Bà Trưng, quận mang tên Hai Bà.",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": ["boat"],
	"allowed": {
		"p": ["soldier", "archer", "boat", "drum", "elephant", "shaman"],
		"e": ["soldier", "archer", "boat", "drum", "shaman"],
	},
	"gold": { "p": 750, "e": 100 },
	"win": { "type": "castles" },
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
		["p", "boat", 4, 9],
		["p", "archer", 0, 8],
		["p", "soldier", 3, 8],
		["e", "hero", 11, 1, { "guard": true }],
		["e", "boat", 12, 3],
		["e", "soldier", 10, 0],
		["e", "soldier", 10, 2],
		["e", "archer", 11, 2],
	],
	"story": {
		"intro": [
			["todinh", "Hai người đàn bà mà dám chống triều đình? Lội qua bãi sông, giẫm nát chúng!"],
			["trungtrac", "Bãi sông này nhiều nhánh nước. Giặc lội thì chậm, đứng dưới nước lại không chỗ nấp. Thủy binh của ta quen sông, cứ theo lối nước mà đánh."],
			["lactuong", "Giữa bãi có ngôi đền cổ. Ai đứng ở đó thì mau lành vết thương, ta hay giặc cũng vậy."],
		],
		"outro": [["trungtrac", "Bãi sông đã yên. Tô Định rút về Long Biên."]],
	},
	"tips": [
		"[b]Thủy binh[/b] đi trên sông chỉ tốn 1 bước, đứng dưới sông +10 công, +15 thủ. Quân khác lội sông tốn 3 bước và không được thủ: đánh chúng lúc đang lội.",
		"[b]Đền[/b] giữa bãi: quân phe nào đứng đó cũng hồi 20 máu mỗi lượt, thủ +15. Không ai chiếm được.",
		"Cầu đi nhanh hơn lội. Một con voi chặn đầu cầu là địch phải xuống nước mà vòng.",
		"Phải chiếm thành địch [b]và[/b] hạ Tướng giặc mới thắng.",
	],
}
