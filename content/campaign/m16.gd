extends RefCounted
## mission m16: Sông Hát. Format: docs/content.md

const DEF := {
	"id": "m16", "order": 16, "chapter": "c2",
	"title": "Đêm Sông Hát",
	"place": "Hát Môn · Phúc Thọ, Hà Nội",
	"region": "Hát Giang", "pos": [26, 34],
	"history": "Năm 43, Hai Bà thua trận cuối ở Cấm Khê, lui về Hát Môn. Tương truyền Hai Bà gieo mình xuống sông Hát chứ không chịu để giặc bắt.",
	"hero": "trungtrac", "enemyHero": "mavien",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "shaman", "elephant"], "e": [] },
	"gold": { "p": 0, "e": 0 },
	"win": { "type": "survive", "turns": 8 },
	"heroMustLive": true,
	"night": true,
	"map": { "rows": [
		"~~~~~~~~~~~~~~",
		"~~~......~~~~~",
		"~hf.rrrv...~~~",
		".h..c..r.....~",
		".frvr.rrrvrrr.",
		".fr...rfhhf.r.",
		"..r...vffhf.r.",
		"f.r....hff..r.",
		"..v....hf...v.",
		".f..h..f...f..",
	] },
	"owner": [[4, 3, "p"], [7, 2, "p"], [3, 4, "p"]],
	"units": [
		["p", "hero", 4, 4], ["p", "elephant", 5, 3, { "hp": 70 }], ["p", "archer", 3, 3], ["p", "soldier", 4, 2, { "hp": 60 }], ["p", "shaman", 3, 2],
	],
	"waves": [
		{ "turn": 1, "units": [["soldier", 0, 6], ["soldier", 13, 4], ["soldier", 6, 9]] },
		{ "turn": 2, "units": [["soldier", 0, 9], ["soldier", 13, 5], ["soldier", 8, 9], ["archer", 13, 3], ["bird", 13, 8]] },
		{ "turn": 3, "units": [["bird", 13, 7], ["soldier", 0, 6, { "rank": 1 }], ["archer", 4, 9]] },
		{ "turn": 4, "units": [["elephant", 13, 4], ["catapult", 12, 9], ["soldier", 0, 4, { "rank": 1 }], ["archer", 6, 9], ["drum", 13, 6]] },
		{ "turn": 5, "units": [["hero", 13, 6], ["soldier", 13, 8, { "rank": 1 }], ["soldier", 1, 9, { "rank": 1 }], ["elephant", 10, 9]] },
		{ "turn": 6, "units": [["soldier", 0, 7, { "rank": 2 }], ["soldier", 13, 2, { "rank": 1 }], ["bird", 13, 9], ["elephant", 9, 9], ["archer", 0, 5], ["catapult", 0, 8]] },
		{ "turn": 7, "units": [["soldier", 13, 4, { "rank": 1 }], ["soldier", 0, 8], ["catapult", 13, 6], ["shaman", 11, 9], ["elephant", 0, 3]] },
	],
	"story": {
		"intro": [
			["trungnhi", "Chị ơi, quân ta chỉ còn chừng này. Giặc vây kín ba mặt, sau lưng là sông Hát."],
			["trungtrac", "Dân làng đang xuống thuyền qua sông. Ta giữ bờ này tám lượt, cho họ đi hết."],
			["danlang", "Hai Bà ơi, cùng đi với chúng tôi!"],
			["trungtrac", "Nước còn thì người còn. Đi đi, mang theo tên Hai Bà mà sống."],
		],
		"outro": [
			["truyenthuyet", "Dân làng đã sang sông an toàn. Đêm ấy, Hai Bà gieo mình xuống dòng Hát Giang."],
			["truyenthuyet", "Từ đó, mỗi năm vào ngày mùng sáu tháng hai âm lịch, dân Hát Môn mở hội tưởng nhớ Hai Bà."],
		],
	},
	"tips": [
		"Trận cuối của chương: [b]giữ 8 lượt[/b] cho dân qua sông. Trưng Trắc ngã là thua.",
		"Đêm tối, giặc đến từ cả phía đông lẫn phía tây. Giữ đội hình quanh thành, đừng đuổi theo địch.",
		"Thầy lang cứu thương binh từ lính ngã: thêm quân miễn phí giữa trận dài.",
	],
}
