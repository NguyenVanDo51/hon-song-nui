extends RefCounted
## mission m15: Thành Cấm Khê. Format: docs/content.md

const DEF := {
	"id": "m15", "order": 15, "chapter": "c2",
	"title": "Thành Cấm Khê",
	"place": "Cấm Khê · Ba Vì, Hà Nội",
	"region": "Cấm Khê", "pos": [14, 50],
	"history": "Quân Hai Bà giữ Cấm Khê qua mùa đông năm 42. Mã Viện vây đánh nhiều lần, có cả máy bắn đá.",
	"hero": "trungtrac", "enemyHero": "mavien",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "shaman", "elephant"], "e": [] },
	"gold": { "p": 600, "e": 0 },
	"win": { "type": "survive", "turns": 10 },
	"map": { "rows": [
		"mmmh..f...h...",
		"mm..v...f.....",
		"mh.....h...f..",
		"m..c..f....h..",
		"mh....v..f....",
		"m..f.......h..",
		"mm..v..f......",
		"m.h.....h..f..",
		"mm..f.......h.",
		"mmm...h..f....",
	] },
	"owner": [[3, 3, "p"], [4, 1, "p"], [6, 4, "p"], [4, 6, "p"]],
	"units": [
		["p", "hero", 3, 4], ["p", "elephant", 4, 3], ["p", "archer", 2, 3], ["p", "drum", 3, 2], ["p", "soldier", 5, 4], ["p", "shaman", 2, 4],
	],
	"waves": [
		{ "turn": 2, "units": [["soldier", 13, 1], ["soldier", 13, 5], ["soldier", 13, 8], ["archer", 12, 3]] },
		{ "turn": 3, "units": [["elephant", 13, 4], ["soldier", 12, 0]] },
		{ "turn": 4, "units": [["catapult", 13, 2], ["soldier", 13, 7], ["archer", 12, 9]] },
		{ "turn": 6, "units": [["hero", 13, 4], ["soldier", 13, 1], ["soldier", 13, 6], ["elephant", 12, 8], ["catapult", 13, 9]] },
		{ "turn": 8, "units": [["soldier", 13, 2, { "rank": 1 }], ["soldier", 13, 5, { "rank": 1 }], ["bird", 13, 0], ["archer", 13, 7], ["elephant", 13, 3]] },
	],
	"story": {
		"intro": [
			["trungtrac", "Cấm Khê dựa lưng vào núi. Giặc chỉ đánh được từ phía đông."],
			["lactuong", "Thám tử báo: Mã Viện chở máy bắn đá tới. Đá ném xa bốn ô, tường thành khó chịu nổi."],
			["trungtrac", "Giữ thành mười lượt. Giặc đói, giặc mệt, giặc sẽ phải lui."],
		],
		"outro": [["trungtrac", "Giặc lui rồi. Nhưng lương thực trong thành cũng cạn. Ta phải tính đường cuối."]],
	},
	"tips": [
		"Mục tiêu: [b]giữ thành 10 lượt[/b]. Mất thành là thua.",
		"[b]Máy bắn đá[/b] của giặc không đánh trả, nhưng đã đi thì không ném được. Cho voi lao ra phá ngay khi chúng vừa đặt xuống.",
		"Mã Viện tới ở lượt 6. Hạ được hắn thì những đợt sau yếu hẳn.",
	],
}
