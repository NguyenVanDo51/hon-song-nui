extends RefCounted
## mission m14: Rút Về Cấm Khê. Format: docs/content.md

const DEF := {
	"id": "m14",
	"order": 14,
	"chapter": "c2",
	"title": "Rút Về Cấm Khê",
	"place": "Từ Lãng Bạc về chân núi Ba Vì",
	"region": "Rút quân",
	"pos": [36, 42],
	"history": "Sau Lãng Bạc, quân Hai Bà rút về Cấm Khê, vùng núi thuộc Ba Vì ngày nay, để giữ lực lượng. Mã Viện bám theo không rời.",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "boat", "drum", "shaman"], "e": [] },
	"gold": { "p": 400, "e": 0 },
	"win": { "type": "reach", "at": [[1, 2]], "turns": 13 },
	"map": {
		"rows": [
			"..h.....~~..fmh.",
			"....f...~~..hmm.",
			".c.hmm..==...hm.",
			".r..hm..~~....f.",
			".rrv.hf.~~rrrxr.",
			"mmrrrrrr==r.f.r.",
			"fhr...mm~~f...r.",
			"..v...hm==mmm.r.",
			".......h~~.hh.c.",
			"......hf~~......",
		]
	},
	"owner": [[1, 2, "p"], [14, 8, "p"]],
	"units": [
		["p", "hero", 14, 7],
		["p", "soldier", 13, 8],
		["p", "archer", 15, 8],
		["p", "soldier", 14, 9],
		["e", "hero", 15, 4],
		["e", "soldier", 12, 5],
		["e", "soldier", 11, 2],
		["e", "elephant", 10, 4],
		["e", "archer", 12, 1],
		["e", "archer", 3, 2, { "guard": true }],
		["e", "soldier", 4, 4],
		["e", "soldier", 5, 6],
	],
	"waves": [
		{ "turn": 4, "units": [["wolf", 15, 0], ["soldier", 15, 2]] },
		{ "turn": 7, "units": [["elephant", 15, 6], ["soldier", 2, 0], ["archer", 4, 1]] },
		{ "turn": 10, "units": [["wolf", 15, 9], ["soldier", 6, 9]] },
	],
	"story": {
		"intro": [
			["trungtrac", "Em đi trước dẫn quân về Cấm Khê. Núi Ba Vì hiểm, giặc khó theo."],
			["trungnhi", "Mã Viện bám sát sau lưng, còn có toán lính chặn đường phía tây. Phải qua cầu thật nhanh."],
			["mavien", "Đuổi theo! Bắt được một trong hai chị em, Giao Chỉ sẽ rã."],
		],
		"outro": [["trungnhi", "Đã về tới Cấm Khê. Ở đây có núi làm thành, ta còn đánh được lâu."]],
	},
	"tips": [
		"Mục tiêu: đưa [b]Anh hùng[/b] về [b]thành Cấm Khê[/b] (cờ vàng, góc tây bắc) trong 13 lượt.",
		"Có 3 cây cầu. Lội sông cũng được nhưng tốn 3 bước, dưới nước không được thủ. Cầu hẹp: một lính đứng chặn là cả đoàn phải chờ hoặc xuống nước.",
		"Mua lính ở thành phía đông để cản hậu, nhưng đừng để Anh hùng chờ quá lâu. Sói của giặc chạy rất nhanh.",
	],
}
