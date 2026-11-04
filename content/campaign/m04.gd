extends RefCounted
## mission m04: Phá Đồn Cổ Loa. Format: docs/content.md

const DEF := {
	"id": "m04",
	"order": 4,
	"title": "Phá Đồn Cổ Loa",
	"place": "Cổ Loa · Đông Anh, Hà Nội",
	"region": "Đông Anh",
	"pos": [63, 23],
	"history": "Cổ Loa (Đông Anh, Hà Nội) là kinh thành của An Dương Vương, nổi tiếng với thành hình xoáy ốc và nỏ thần.",
	"hero": "trungtrac",
	"enemyHero": "todinh",
	"newUnits": ["elephant"],
	"allowed": { "p": ["soldier", "archer", "drum", "elephant"], "e": ["soldier", "archer", "drum", "elephant"] },
	"gold": { "p": 500, "e": 250 },
	"incomeMul": { "e": 0.9 },
	"win": { "type": "hero" },
	"map": {
		"rows": [
			"fhf...........",
			"hfv........fcr",
			"ffrff...vrrrrr",
			"f.rfhfff...r.v",
			"~~=~~~..~~~=~~",
			"..r..f..fh.r..",
			".vr.fhf..fvrr.",
			".r.fffvrrrr.r.",
			".crrrrrff...v.",
			"...ffhff......",
		],
	},
	"owner": [[1, 8, "p"], [12, 1, "e"], [8, 2, "e"]],
	"units": [
		["p", "hero", 2, 8],
		["p", "soldier", 1, 7],
		["p", "elephant", 2, 7],
		["p", "archer", 0, 8],
		["e", "hero", 11, 1, { "guard": true }],
		["e", "soldier", 8, 2],
		["e", "soldier", 10, 3],
		["e", "archer", 12, 2, { "guard": true }],
		["e", "elephant", 7, 3],
	],
	"story": {
		"intro": [
			["lechan", "Đô úy người Hán đóng đồn ở Cổ Loa, nấp trong rừng rậm quanh thành cũ."],
			["lactuong", "Voi rừng đã thuần. Da voi dày, kích Hán đâm không thủng."],
			["douy", "Thành cũ của An Dương Vương nay là đồn của ta. Cứ vào rừng mà nộp mạng!"],
		],
		"outro": [["lechan", "Tô Định trúng thương, bỏ đồn mà chạy. Cổ Loa lại về tay người Việt."]],
	},
	"tips": [
		"Mục tiêu: [b]hạ Tô Định[/b]. Hắn đích thân giữ đồn giữa rừng: dụ hắn ra chỗ trống rồi hãy đánh.",
		"[b]Voi chiến[/b] thủ 25, công 65 nhưng chỉ đi 3 ô và không lên núi. Cho voi đi đầu hút đòn.",
		"Trưng Trắc đi đồi núi chỉ tốn 1 bước, đứng trên đồi, núi +10 thủ.",
	],
}
