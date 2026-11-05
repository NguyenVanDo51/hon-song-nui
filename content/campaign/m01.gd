extends RefCounted
## mission m01: Lời Thề Hát Môn. Format: docs/content.md

const DEF := {
	"id": "m01",
	"order": 1,
	"title": "Lời Thề Hát Môn",
	"place": "Hát Môn · Phúc Thọ, Hà Nội",
	"region": "Phúc Thọ",
	"pos": [16, 30],
	"history": "Mùa xuân năm 40, Hai Bà Trưng dựng cờ khởi nghĩa chống nhà Đông Hán. Tương truyền lễ thề diễn ra ở Hát Môn, nay thuộc Phúc Thọ, Hà Nội.",
	"hero": "anhhung",
	"enemyHero": null,
	"newUnits": ["hero", "soldier"],
	"allowed": { "p": [], "e": [] },
	"gold": { "p": 0, "e": 0 },
	"win": { "type": "rout" },
	"heroMustLive": true,
	"map": {
		"rows": [
			"......fff~~",
			".rv...fhf.~",
			".rrrrrrv..~",
			".rfhf..r.~~",
			".r.f...rh~~",
			"fv.....rf.~",
			"hf.....vf.~",
			".......fh~~",
		],
	},
	"units": [
		["p", "hero", 1, 3],
		["p", "soldier", 1, 2],
		["p", "soldier", 2, 4],
		["e", "soldier", 7, 2, { "guard": true, "hp": 70 }],
		["e", "soldier", 8, 4, { "hp": 80 }],
		["e", "soldier", 7, 6, { "guard": true, "hp": 70 }],
		["e", "soldier", 6, 3, { "hp": 60 }],
	],
	"story": {
		"intro": [
			[
				"truyenthuyet",
				"Thái thú Tô Định tham bạo, giết Thi Sách, chồng bà Trưng Trắc. Thuế nặng, dân Giao Chỉ oán hận.",
			],
			["trungtrac", "Một xin rửa sạch nước thù, hai xin dựng lại nghiệp xưa họ Hùng."],
			["danlang", "Lính Hán đang lùa thóc thuế ra bến sông Hát! Dân Hát Môn xin theo Hai Bà!"],
			["trungnhi", "Chị cứ lo việc lớn. Toán lính thu thuế này để em dẹp."],
		],
		"outro": [["trungnhi", "Cờ đã dựng ở Hát Môn. Tin truyền đi, nghĩa binh các làng kéo về."]],
	},
	"tips": [
		"Bấm [b]Trưng Trắc[/b] (viền vàng): ô xanh là chỗ đi được, kẻ địch viền đỏ là đánh được.",
		"Rê chuột lên lính Hán viền đỏ: bàn cờ hiện đường đi và [b]⚔ gây · ↩ nhận[/b]. [b]Bấm là đánh.[/b] Muốn chọn chỗ đứng: bấm ô xanh trước rồi bấm địch.",
		"Lính đứng trên làng rồi bấm [b]Chiếm[/b]: làng của ta hồi 20 máu mỗi lượt.",
		"Trưng Trắc ngã là thua. Ra lệnh xong cho cả đội thì bấm [b]Hết lượt[/b].",
	],
}
