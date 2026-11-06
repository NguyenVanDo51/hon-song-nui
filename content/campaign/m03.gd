extends RefCounted
## mission m03: Giữ Làng Hạ Lôi. Format: docs/content.md

const DEF := {
	"id": "m03",
	"order": 3,
	"title": "Giữ Làng Hạ Lôi",
	"place": "Hạ Lôi · Mê Linh, Hà Nội",
	"region": "Hạ Lôi",
	"pos": [41, 13],
	"history": "Đền Hạ Lôi (Mê Linh) thờ Hai Bà Trưng. Tương truyền Hai Bà sinh ra ở làng này, mẹ là bà Man Thiện.",
	"hero": "anhhung",
	"enemyHero": null,
	"newUnits": ["drum"],
	"allowed": { "p": ["soldier", "archer"], "e": [] },
	"gold": { "p": 500, "e": 0 },
	"win": { "type": "survive", "turns": 10 },
	"map": {
		"rows": [
			"~~~~~~~~~~~~",
			"..f......f.~",
			"fhhhff.rrrv~",
			"fhrvrrtr...~",
			"..r.rcrv....",
			"..v.r.......",
			"....r..fh...",
			"....v..fhf..",
			".......hfhf.",
		],
	},
	"owner": [[5, 4, "p"], [7, 4, "p"], [3, 3, "p"]],
	"units": [["p", "hero", 5, 5], ["p", "soldier", 4, 4], ["p", "drum", 6, 5], ["p", "archer", 5, 3]],
	"waves": [
		{ "turn": 2, "units": [["soldier", 1, 1], ["soldier", 6, 1], ["soldier", 10, 1]] },
		{ "turn": 4, "units": [["soldier", 11, 4], ["soldier", 11, 5], ["archer", 8, 1]] },
		{ "turn": 6, "units": [["soldier", 0, 1], ["soldier", 4, 1], ["soldier", 11, 6], ["archer", 7, 1]] },
		{
			"turn": 8,
			"units": [
				["soldier", 11, 4],
				["soldier", 11, 7],
				["soldier", 3, 1],
				["archer", 9, 1],
				["soldier", 6, 1, { "rank": 1 }],
			],
		},
	],
	"story": {
		"intro": [
			["bamanthien", "Quân Hán từ bến sông kéo lên từng đợt, muốn đánh úp làng Hạ Lôi."],
			["trungnhi", "Đánh trống đồng lên! Trống vang tới đâu, nghĩa binh mạnh tay tới đó."],
			["bamanthien", "Giữ thành và làng đủ 10 lượt. Chị con sẽ đem quân về tiếp ứng."],
		],
		"outro": [["trungnhi", "Quân Hán rút rồi. Trống đồng còn vang, lòng dân còn vững."]],
	},
	"tips": [
		"Mục tiêu: [b]giữ vững 10 lượt[/b]. Địch đổ bộ từ sông ở các lượt 2, 4, 6, 8.",
		"[b]Trống đồng[/b] đánh yếu, nhưng ra lệnh xong (đánh hoặc chờ) thì quân ta trong 2 ô [b]+10 công[/b] tới lượt sau. Cho trống đi trước, cả đội đánh sau. Trận này chưa mua thêm trống được: giữ nó sau hàng lính.",
		"Đứng trên làng, thành, đền, đồi, rừng để được thêm thủ khi địch tràn lên. [b]Đền[/b] còn hồi 20 máu mỗi lượt cho bất kỳ ai đứng đó.",
		"Mất thành mà tướng cũng ngã là thua. Đừng để tướng một mình phía trước.",
	],
}
