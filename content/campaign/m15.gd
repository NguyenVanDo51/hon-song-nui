extends RefCounted
## mission m15: Thành Cấm Khê. Format: docs/content.md

const DEF := {
	"id": "m15",
	"order": 15,
	"chapter": "c2",
	"title": "Thành Cấm Khê",
	"place": "Cấm Khê · Ba Vì, Hà Nội",
	"region": "Cấm Khê",
	"pos": [14, 50],
	"history": "Quân Hai Bà giữ Cấm Khê qua mùa đông năm 42. Mã Viện vây đánh nhiều lần, có cả máy bắn đá.",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": ["bird"],
	"allowed": { "p": ["soldier", "archer", "drum", "shaman", "wolf", "elephant"], "e": [] },
	"gold": { "p": 1000, "e": 0 },
	"win": { "type": "survive", "turns": 10 },
	"stars": { "lost": 10 },
	"map": {
		"rows": [
			".f............",
			"fh..v....hm...",
			"....rfmmhmmf..",
			"...cr.hm.h....",
			".f..rrvf......",
			".hmhr......h..",
			".ffmv...hmmm..",
			".mmf.....f.f..",
			"fmh.........h.",
			".h............",
		]
	},
	"owner": [[3, 3, "p"], [4, 1, "p"], [6, 4, "p"], [4, 6, "p"]],
	"units": [["p", "hero", 3, 4], ["p", "elephant", 4, 3], ["p", "archer", 2, 3], ["p", "soldier", 5, 4, { "hp": 70 }], ["p", "bird", 2, 4]],
	"waves": [
		{ "turn": 1, "units": [["soldier", 12, 4], ["archer", 13, 6], ["soldier", 12, 7]] },
		{ "turn": 2, "units": [["soldier", 13, 1], ["soldier", 13, 5], ["soldier", 13, 8], ["archer", 12, 3]] },
		{ "turn": 3, "units": [["elephant", 13, 4], ["soldier", 12, 0], ["wolf", 13, 9]] },
		{ "turn": 4, "units": [["catapult", 13, 2], ["soldier", 13, 7, { "rank": 1 }], ["archer", 12, 9], ["soldier", 13, 3, { "rank": 1 }]] },
		{ "turn": 5, "units": [["drum", 13, 5], ["soldier", 12, 1], ["archer", 13, 8]] },
		{
			"turn": 6,
			"units": [
				["hero", 13, 4],
				["soldier", 13, 1],
				["soldier", 13, 6],
				["elephant", 12, 8],
				["catapult", 13, 9],
				["archer", 12, 2, { "rank": 1 }],
			],
		},
		{
			"turn": 8,
			"units": [
				["soldier", 13, 2, { "rank": 2 }],
				["soldier", 13, 5, { "rank": 1 }],
				["wolf", 13, 0],
				["archer", 13, 7],
				["elephant", 13, 3],
				["catapult", 12, 9],
			],
		},
	],
	"story": {
		"intro": [
			["trungtrac", "Cấm Khê dựa lưng vào núi. Giặc chỉ đánh được từ phía đông."],
			["lactuong", "Thám tử báo: Mã Viện chở máy bắn đá tới. Đá ném xa bốn ô, tường thành khó chịu nổi."],
			["truyenthuyet", "Người Việt nhận mình là con Rồng cháu Tiên. Giữa lúc nguy nan, rồng bay về đậu trên thành Cấm Khê."],
			["trungtrac", "Giữ thành mười lượt. Giặc đói, giặc mệt, giặc sẽ phải lui."],
		],
		"outro": [["trungtrac", "Giặc lui rồi. Nhưng lương thực trong thành cũng cạn. Ta phải tính đường cuối."]],
	},
	"tips": [
		"Mục tiêu: [b]giữ thành 10 lượt[/b]. Mất thành mà Anh hùng cũng ngã là thua.",
		"[b]Máy bắn đá[/b] của giặc không đánh trả, nhưng đã đi thì không ném được. Cho voi lao ra phá ngay khi chúng vừa đặt xuống.",
		"[b]Rồng[/b] bay qua núi chỉ 1 bước, đi 7 ô, mạnh nhất trận. Chỉ có một con, không mua thêm được. Nỏ thủ bắn rồng +15 công: giữ rồng xa "
		+ "nỏ thủ giặc.",
		"Tướng giặc tới ở lượt 6. Lượt 8 giặc có cả [b]sói[/b]: bị cắn thì −10 công, −10 thủ, kéo quân đó về gần thành mà hồi máu.",
	],
}
