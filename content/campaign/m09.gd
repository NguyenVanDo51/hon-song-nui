extends RefCounted
## mission m09: Tin Dữ Hợp Phố. Format: docs/content.md

const DEF := {
	"id": "m09", "order": 9, "chapter": "c2",
	"title": "Tin Dữ Hợp Phố",
	"place": "Hợp Phố · bờ biển phía đông bắc",
	"region": "Hợp Phố", "pos": [88, 12],
	"history": "Năm 42, Mã Viện tập hợp hai vạn quân và hai nghìn thuyền ở Hợp Phố. Tương truyền nữ tướng Thánh Thiên được Trưng Vương giao giữ vùng này.",
	"hero": "thanhthien", "enemyHero": null,
	"newUnits": ["hero"],
	"allowed": { "p": ["soldier", "archer", "drum", "shaman"], "e": [] },
	"gold": { "p": 400, "e": 0 },
	"win": { "type": "survive", "turns": 9 },
	"heroMustLive": true,
	"map": { "rows": [
		"~~~~~~~~~~~~~~",
		"~~~..f....~~~~",
		"~~.v...h..f.~~",
		"~...f.....v.~~",
		"~..h..c..f...~",
		".v.....f..h..~",
		"...f.v....v..~",
		".h....f..h...~",
		"..f.v.....f..~",
		".....h..f....~",
	] },
	"owner": [[6, 4, "p"], [3, 2, "p"], [5, 6, "p"], [1, 5, "p"]],
	"units": [["p", "hero", 6, 5], ["p", "soldier", 5, 4], ["p", "archer", 7, 4], ["p", "drum", 6, 3]],
	"waves": [
		{ "turn": 2, "units": [["soldier", 4, 1], ["soldier", 9, 1], ["soldier", 12, 4]] },
		{ "turn": 3, "units": [["archer", 12, 6], ["soldier", 11, 2]] },
		{ "turn": 5, "units": [["soldier", 2, 2], ["soldier", 12, 8], ["elephant", 8, 1], ["archer", 3, 1]] },
		{ "turn": 7, "units": [["soldier", 6, 1, { "rank": 1 }], ["soldier", 12, 5], ["soldier", 1, 3], ["shaman", 11, 8], ["archer", 12, 7]] },
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
		"[b]Thánh Thiên[/b] như một trống đồng biết đánh: lính đứng sát bà được [b]+10 công[/b]. Đặt bà giữa đội hình.",
		"Thánh Thiên ngã là thua. Đừng để bà đứng ở mép biển.",
	],
}
