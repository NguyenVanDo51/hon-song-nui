extends RefCounted
## mission m17: Núi Nưa. Format: docs/content.md

const DEF := {
	"id": "m17", "order": 17, "chapter": "c3",
	"title": "Tiếng Gọi Núi Nưa",
	"place": "Núi Nưa · Triệu Sơn, Thanh Hóa",
	"region": "Núi Nưa", "pos": [24, 36],
	"history": "Triệu Thị Trinh lên núi Nưa luyện quân. Năm 248, khi nhà Ngô vơ vét Cửu Chân, Bà cùng anh là Triệu Quốc Đạt dựng cờ khởi nghĩa.",
	"hero": "batrieu", "enemyHero": null,
	"newUnits": ["hero"],
	"allowed": { "p": [], "e": [] },
	"gold": { "p": 0, "e": 0 },
	"win": { "type": "rout" },
	"heroMustLive": true,
	"map": { "rows": [
		"mmh..f..h.mm",
		"mh..f....f.m",
		"m..h..mm...m",
		"h....fmm.h..",
		"..f.......f.",
		".v..h..f....",
		"f.....h...h.",
		"..f.v.....f.",
		"h.....f..h..",
	] },
	"owner": [[1, 5, "p"], [4, 7, "p"]],
	"units": [
		["p", "hero", 2, 6], ["p", "soldier", 1, 5], ["p", "soldier", 3, 7], ["p", "archer", 2, 7],
		["e", "soldier", 8, 3, { "hp": 80 }], ["e", "soldier", 9, 5], ["e", "archer", 10, 2, { "guard": true }],
		["e", "soldier", 8, 6, { "hp": 70 }], ["e", "soldier", 10, 7, { "guard": true }],
	],
	"story": {
		"intro": [
			["truyenthuyet", "Hai trăm năm sau Hai Bà, Giao Châu dưới tay nhà Đông Ngô. Quan Ngô bắt dân vào rừng săn ngà voi, mò ngọc trai."],
			["lenhngo", "Một toán quân Ngô lên núi lùng người trốn thuế!"],
			["batrieu", "Tôi muốn cưỡi cơn gió mạnh, đạp luồng sóng dữ, chém cá kình ở Biển Đông, chứ không chịu khom lưng làm tì thiếp người."],
			["batrieu", "Anh em nghĩa binh, đánh tan toán lính này, cho cả Cửu Chân biết núi Nưa đã có người!"],
		],
		"outro": [["batrieu", "Toán lính Ngô tan rồi. Báo tin cho anh ta ở Quan Yên: đã đến lúc."]],
	},
	"tips": [
		"[b]Bà Triệu[/b] công 72, cao nhất trong các tướng. Bà ngã là thua.",
		"Mục tiêu: [b]diệt hết[/b] toán lính Ngô. Hai tên đứng gác (💤) chỉ ra tay khi ta tới gần.",
		"Bấm lính rồi rê chuột lên kẻ địch: bàn cờ hiện ngay sát thương gây và nhận. Bấm một lần là đánh.",
	],
}
