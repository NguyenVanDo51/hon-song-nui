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
	"hero": "trungtrac",
	"enemyHero": "todinh",
	"newUnits": ["archer"],
	"allowed": { "p": ["soldier", "archer"], "e": ["soldier", "archer"] },
	"gold": { "p": 400, "e": 100 },
	"incomeMul": { "e": 0.6 },
	"win": { "type": "castles" },
	"map": {
		"rows": [
			".f..h..~.v..h",
			"...v...~...f.",
			".c..f..=..v..",
			"....h..~.....",
			".v.....~..h.c",
			"...f...=.....",
			"..v..h.~..f..",
			".f.....~.v...",
			"...h..f~...f.",
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
		"Mục tiêu mới: [b]chiếm thành[/b] của địch. Chỉ tướng chiếm được thành.",
		"Bấm vào [b]thành[/b] của ta khi ô trống để [b]mua lính[/b]. Lính mới đi được từ lượt sau.",
		"[b]Nỏ thủ[/b] bắn cách 2 ô thì địch cận chiến không đánh trả được.",
		"Làng cho thêm vàng mỗi lượt. Chiếm làng sớm để mua được nhiều quân.",
	],
}
