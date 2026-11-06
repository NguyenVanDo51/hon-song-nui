extends RefCounted
## mission m02: Về Lại Mê Linh. Format: docs/content.md

const DEF := {
	"id": "m02",
	"order": 2,
	"title": "Về Lại Mê Linh",
	"place": "Mê Linh, Hà Nội",
	"region": "Mê Linh",
	"pos": [30, 19],
	"history": "Mê Linh là quê của Hai Bà. Đuổi được quân Hán rồi, Trưng Trắc lên ngôi vua, đóng đô ở Mê Linh.",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": ["archer"],
	"allowed": { "p": ["soldier", "archer"], "e": ["soldier", "archer"] },
	"gold": { "p": 400, "e": 100 },
	"win": { "type": "castles" },
	"stars": { "turns": 13 },
	"map": {
		"rows": [
			".fffhhf~.v...",
			".rrvfhh~.r...",
			".c.rrrr=rrv..",
			".r.....~..r..",
			".vr....~.rrrc",
			"..r....=.rf..",
			"ffv....~.rhhf",
			"hhf....~.vhf.",
			"fhf....~..f..",
		],
	},
	"owner": [[1, 2, "p"], [12, 4, "e"], [3, 1, "p"]],
	"units": [
		["p", "hero", 2, 2],
		["p", "soldier", 1, 3],
		["p", "archer", 2, 3],
		["e", "hero", 11, 4],
		["e", "soldier", 10, 3],
		["e", "archer", 11, 5, { "guard": true }],
	],
	"story": {
		"intro": [
			["lactuong", "Huyện lệnh người Hán chiếm thành bên kia sông, giữ kho thóc của dân Mê Linh."],
			["trungtrac", "Mê Linh là đất cha ông ta. Qua cầu, lấy lại thành. Nỏ thủ đi sau yểm trợ."],
			["huyenlenh", "Cầm giáo tre mà đòi đánh quan triều đình sao? Bước lên cầu là chết đuối cả lũ!"],
		],
		"outro": [["trungtrac", "Mê Linh đã về tay ta. Từ đây, ta lấy Mê Linh làm gốc."]],
	},
	"tips": [
		"Mục tiêu mới: [b]chiếm thành[/b] địch và [b]hạ Tướng giặc[/b]. Chỉ tướng chiếm được thành.",
		"Bấm vào [b]thành[/b] của ta để [b]mua lính[/b]; lính mới đi và đánh được ngay. Thành đang có quân: bấm quân đó 2 lần rồi chọn [b]Mộ "
		+ "quân[/b], lính mới phải bước ra ô khác.",
		"[b]Nỏ thủ[/b] bắn cách 2 ô thì địch không đánh trả được. Sông lội được nhưng tốn 3 bước, đứng dưới nước không được thủ: đi cầu nhanh hơn.",
		"Làng +30 vàng, thành +50 vàng mỗi lượt. Tướng ngã thì mua lại ở thành (200 vàng, mỗi lần ngã +200), vẫn giữ cấp.",
	],
}
