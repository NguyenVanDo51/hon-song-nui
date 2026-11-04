extends RefCounted
## mission m20: Voi Một Ngà. Format: docs/content.md

const DEF := {
	"id": "m20", "order": 20, "chapter": "c3",
	"title": "Voi Một Ngà",
	"place": "Đồng bằng sông Mã · Thanh Hóa",
	"region": "Sông Mã", "pos": [48, 50],
	"history": "Tương truyền Bà Triệu cưỡi một con voi trắng một ngà, mặc áo giáp vàng ra trận. Quân Ngô thấy bóng voi là khiếp vía.",
	"hero": "batrieu", "enemyHero": "douy",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "shaman", "elephant", "bird", "catapult"], "e": ["soldier", "archer", "drum", "shaman", "elephant", "bird", "catapult"] },
	"gold": { "p": 800, "e": 350 }, "incomeMul": { "e": 0.7 },
	"win": { "type": "castles" },
	"map": { "rows": [
		"..h..f...c..f..h",
		".f..v..h.....v..",
		"....f....f..h...",
		"h..~~~~=~~~..f.c",
		"..~~..f..~~~....",
		".~~.v.....h~~.v.",
		"~~..h..f....~~=~",
		"...f....v.....h.",
		".v..h..f....f...",
		"..c....h...v....",
		"f...f.....h...f.",
	] },
	"owner": [[2, 9, "p"], [1, 8, "p"], [9, 0, "e"], [15, 3, "e"], [13, 1, "e"], [14, 5, "e"]],
	"units": [
		["p", "hero", 3, 9], ["p", "elephant", 2, 8], ["p", "elephant", 3, 8], ["p", "archer", 1, 9], ["p", "soldier", 2, 10], ["p", "drum", 4, 9],
		["e", "hero", 10, 1], ["e", "soldier", 9, 1], ["e", "archer", 8, 0], ["e", "bird", 14, 2], ["e", "elephant", 14, 4],
		["e", "soldier", 15, 4], ["e", "archer", 13, 3], ["e", "catapult", 15, 2, { "guard": true }],
	],
	"story": {
		"intro": [
			["batrieu", "Quân Ngô dồn về hai đồn bên sông Mã. Voi của ta đi đầu, nghĩa binh theo sau."],
			["douy", "Bắn tên vào mắt voi! Voi loạn thì đàn bà kia cũng ngã!"],
			["trieuquocdat", "Em cứ tiến. Anh dẫn nỏ thủ giữ hai bên sườn."],
		],
		"outro": [["batrieu", "Hai đồn bên sông Mã đã vỡ. Quân Ngô gọi ta là Lệ Hải Bà Vương, mà run."]],
	},
	"tips": [
		"Trận lớn: được mua mọi loại quân. Địch có [b]2 thành[/b].",
		"Voi thủ dày, đánh mạnh nhưng không lên núi và đi chậm. Đi theo cặp để che cho nhau.",
		"Máy bắn đá địch đứng gác ở thành phía đông: tới gần là nó tỉnh, đánh nhanh trước khi nó ném.",
	],
}
