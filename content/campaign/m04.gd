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
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": ["elephant"],
	"allowed": { "p": ["soldier", "archer", "drum"], "e": ["soldier", "archer", "drum", "elephant"] },
	"gold": { "p": 650, "e": 150 },
	"win": { "type": "hero" },
	"stars": { "turns": 9 },
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
		["p", "drum", 2, 7],
		["p", "archer", 0, 8],
		["p", "soldier", 3, 8],
		["e", "hero", 11, 1, { "guard": true }],
		["e", "soldier", 8, 2],
		["e", "soldier", 10, 3],
		["e", "archer", 12, 2, { "guard": true }],
		["e", "elephant", 11, 2, { "guard": true }],
	],
	"story": {
		"intro": [
			["lechan", "Đô úy người Hán đóng đồn ở Cổ Loa, nấp trong rừng rậm quanh thành cũ."],
			["lactuong", "Giặc có voi chiến giữ đồn. Da voi dày, giáo ta đâm không thủng, phải dùng mẹo."],
			["douy", "Thành cũ của An Dương Vương nay là đồn của ta. Cứ vào rừng mà nộp mạng!"],
		],
		"outro": [["lechan", "Tô Định trúng thương, bỏ đồn mà chạy. Cổ Loa lại về tay người Việt."]],
	},
	"tips": [
		"Mục tiêu: [b]hạ Tướng giặc[/b]. Hắn đích thân giữ đồn giữa rừng: dụ hắn ra chỗ trống rồi hãy đánh.",
		"[b]Voi chiến[/b] của giặc thủ rất dày, đánh mạnh. Đừng đánh tay đôi: nỏ thủ bắn từ 2 ô (voi không đánh trả được), [b]trống đồng[/b] +10 "
		+ "công cho cả đội rồi mới xông vào.",
		"Rừng, đồi +10 thủ, núi +15 thủ nhưng tốn 3 bước. Ai đứng dưới sông thì không được thủ.",
	],
}
