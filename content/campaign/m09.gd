extends RefCounted
## mission m09: Tin Dữ Hợp Phố. Format: docs/content.md

const DEF := {
	"id": "m09", "order": 9, "chapter": "c2",
	"title": "Tin Dữ Hợp Phố",
	"place": "Hợp Phố · bờ biển phía đông bắc",
	"region": "Hợp Phố", "pos": [88, 12],
	"history": "Năm 42, Mã Viện tập hợp hai vạn quân và hai nghìn thuyền ở Hợp Phố. Tương truyền nữ tướng Thánh Thiên được Trưng Vương giao "
		+ "giữ vùng này.",
	"hero": "anhhung", "enemyHero": null,
	"newUnits": ["boat"],
	"allowed": { "p": ["soldier", "archer", "drum", "elephant"], "e": [] },
	"gold": { "p": 500, "e": 0 },
	"win": { "type": "survive", "turns": 9 },
	"map": { "rows": [
		"~~~~~~~~~~~~~~",
		"~~~.......~~~~",
		"~~.vrr......~~",
		"~....rrrrrv.~~",
		"~....rc...r..~",
		".vrrrr....r..~",
		"....rv....v..~",
		"f...rhhf.....~",
		"hf.fvff..ff..~",
		"fh.hhf...fhhf~",
	] },
	"owner": [[6, 4, "p"], [3, 2, "p"], [5, 6, "p"], [1, 5, "p"]],
	"units": [["p", "hero", 6, 5], ["p", "soldier", 5, 4], ["p", "archer", 7, 4], ["p", "drum", 6, 3]],
	"waves": [
		{ "turn": 2, "units": [["soldier", 4, 1], ["soldier", 9, 1], ["soldier", 12, 4]] },
		{ "turn": 3, "units": [["archer", 12, 6], ["boat", 12, 2]] },
		{ "turn": 5, "units": [["soldier", 2, 2], ["boat", 13, 8], ["elephant", 8, 1], ["archer", 3, 1]] },
		{ "turn": 7, "units": [["soldier", 6, 1, { "rank": 1 }], ["soldier", 12, 5], ["boat", 0, 3], ["soldier", 11, 8], ["archer", 12, 7]] },
	],
	"story": {
		"intro": [
			["truyenthuyet", "Năm 42, nhà Hán sai Phục Ba tướng quân Mã Viện đem đại quân sang. Thuyền giặc che kín mặt biển Hợp Phố."],
			["thanhthien", "Giặc đổ bộ từng đợt. Giữ thành, giữ làng, để Trưng Vương kịp điểm quân ở Mê Linh!"],
			["danlang", "Nghĩa binh làng biển đã sẵn. Có bà đứng giữa, anh em đánh hăng gấp bội."],
		],
		"outro": [["thanhthien", "Đợt đổ bộ đã bị đẩy lui. Mau báo về Mê Linh: Mã Viện đến thật rồi."]],
	},
	"tips": [
		"Mục tiêu: [b]giữ vững 9 lượt[/b]. Giặc đổ bộ từ biển ở các lượt 2, 3, 5, 7.",
		"Giữ đội hình sát nhau quanh thành. [b]Trống đồng[/b] ra lệnh trước: quân ta trong 2 ô +10 công tới lượt sau.",
		"[b]Thủy binh[/b] giặc đi sông 1 bước, đứng dưới nước +10 công, +15 thủ: rất khó hạ. Đợi chúng lên bờ rồi hãy đánh, đừng lội xuống đuổi.",
		"Mất thành mà tướng cũng ngã là thua. Đừng để tướng đứng ở mép biển.",
	],
}
