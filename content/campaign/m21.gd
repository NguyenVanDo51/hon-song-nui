extends RefCounted
## mission m21: Lục Dận Kéo Quân. Format: docs/content.md

const DEF := {
	"id": "m21", "order": 21, "chapter": "c3",
	"title": "Lục Dận Kéo Quân",
	"place": "Bồ Điền · Hậu Lộc, Thanh Hóa",
	"region": "Giữ Bồ Điền", "pos": [70, 36],
	"history": "Nhà Ngô sai Lục Dận làm Thứ sử Giao Châu, đem quân sang dẹp. Lục Dận vừa đánh vừa dùng vàng bạc mua chuộc các hào trưởng.",
	"hero": "batrieu", "enemyHero": "lucdan",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "shaman", "elephant"], "e": [] },
	"gold": { "p": 150, "e": 0 },
	"win": { "type": "survive", "turns": 10 },
	"map": { "rows": [
		"..f...h...mmmm",
		".h..v..f..mhmm",
		"...f.....h..cm",
		"f....h..f....m",
		"..v.....h.v..m",
		".h...f.......m",
		"...f...h..f..h",
		"f..v.....h....",
		"..h...f.....v.",
		".f...h...f....",
	] },
	"owner": [[12, 2, "p"], [10, 4, "p"], [12, 8, "p"]],
	"units": [
		["p", "hero", 11, 2], ["p", "elephant", 12, 3], ["p", "archer", 11, 3], ["p", "soldier", 11, 4, { "hp": 70 }],
	],
	"waves": [
		{ "turn": 1, "units": [["soldier", 4, 2], ["soldier", 5, 6], ["archer", 3, 4]] },
		{ "turn": 2, "units": [["soldier", 0, 1], ["soldier", 0, 5], ["soldier", 4, 9], ["archer", 0, 3], ["elephant", 0, 6]] },
		{ "turn": 3, "units": [["bird", 0, 7], ["soldier", 2, 9, { "rank": 1 }], ["bird", 0, 2]] },
		{ "turn": 4, "units": [["elephant", 0, 4], ["catapult", 1, 9], ["soldier", 0, 0, { "rank": 1 }], ["archer", 5, 9], ["drum", 0, 5]] },
		{ "turn": 5, "units": [["soldier", 0, 8], ["archer", 3, 9], ["elephant", 0, 1]] },
		{ "turn": 6, "units": [["hero", 0, 5], ["soldier", 0, 2, { "rank": 1 }], ["soldier", 3, 9], ["elephant", 0, 8], ["catapult", 0, 6], ["archer", 0, 3, { "rank": 1 }]] },
		{ "turn": 8, "units": [["soldier", 0, 1, { "rank": 2 }], ["soldier", 0, 7, { "rank": 1 }], ["bird", 6, 9], ["archer", 0, 4], ["elephant", 2, 9], ["catapult", 0, 0]] },
	],
	"story": {
		"intro": [
			["lucdan", "Ta đem tám nghìn quân sang. Kẻ nào theo Triệu Ẩu sẽ mất đầu, kẻ nào bỏ về sẽ được thưởng."],
			["trieuquocdat", "Nhiều hào trưởng đã nhận vàng của Lục Dận mà bỏ đi. Quân ta mỏng lắm rồi."],
			["batrieu", "Người ở lại là người thật lòng. Giữ Bồ Điền mười lượt, cho dân kịp gặt lúa lên núi."],
		],
		"outro": [["batrieu", "Bồ Điền vẫn đứng. Nhưng Lục Dận còn đông quân, và hắn đang dồn về núi Tùng."]],
	},
	"tips": [
		"Mục tiêu: [b]giữ thành 10 lượt[/b]. Giặc đến từ phía tây và phía nam.",
		"[b]Lục Dận[/b] tới ở lượt 6: hắn thủ dày, lính đứng cạnh hắn +10 thủ. Đánh hắn bằng nhiều lính một lúc.",
		"Thành nằm sát núi phía đông: dựa lưng vào núi để chỉ bị đánh từ hai mặt.",
	],
}
