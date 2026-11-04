extends RefCounted
## mission m11: Bát Nàn Giữ Ải. Format: docs/content.md

const DEF := {
	"id": "m11", "order": 11, "chapter": "c2",
	"title": "Bát Nàn Giữ Ải",
	"place": "Tiên Phong · Phú Thọ",
	"region": "Phú Thọ", "pos": [14, 20],
	"history": "Bát Nàn, quê ở Tiên Phong (Phú Thọ), là nữ tướng của Hai Bà. Tương truyền bà giỏi cung nỏ, giữ các ải núi phía tây.",
	"hero": "batnan", "enemyHero": "luulong",
	"newUnits": ["hero"],
	"allowed": { "p": ["soldier", "archer", "drum", "shaman", "elephant"], "e": ["soldier", "archer", "drum", "elephant"] },
	"gold": { "p": 500, "e": 250 }, "incomeMul": { "e": 0.8 },
	"win": { "type": "castles" },
	"map": { "rows": [
		"mmh...f....hmm",
		"m...v...h...cm",
		"mh.f..mmm..f.m",
		"m...h.mmm.v..m",
		"mm.....h.....m",
		"m.v.f.mmm.h..m",
		"m...h.mmm..v.m",
		"mh..f....f..hm",
		"mc.v..h.....mm",
		"mmm...f..h.mmm",
	] },
	"owner": [[1, 8, "p"], [3, 8, "p"], [12, 1, "e"], [10, 3, "e"]],
	"units": [
		["p", "hero", 2, 8], ["p", "soldier", 1, 7], ["p", "archer", 2, 7], ["p", "drum", 3, 7], ["p", "soldier", 4, 8],
		["e", "hero", 11, 1], ["e", "soldier", 10, 2], ["e", "archer", 12, 2, { "guard": true }], ["e", "soldier", 9, 4], ["e", "elephant", 11, 4],
	],
	"story": {
		"intro": [
			["lactuong", "Lưu Long, phó tướng của Mã Viện, đem quân vòng qua núi định đánh vào lưng Mê Linh."],
			["batnan", "Ải này hẹp, núi hai bên. Cung nỏ trên cao, giặc dưới thấp. Chiếm luôn đồn của chúng!"],
			["luulong", "Một nữ tướng giữ ải? Quân ta qua núi còn nhanh hơn ngựa."],
		],
		"outro": [["batnan", "Đồn của Lưu Long đã cháy. Phía tây yên rồi, ta về Lãng Bạc hợp quân."]],
	},
	"tips": [
		"[b]Bát Nàn[/b] bắn xa 1–2 ô như nỏ thủ, đi đồi núi chỉ tốn 1. Bắn từ trên núi, địch cận chiến khó với tới.",
		"Hai dãy núi giữa bản đồ chặn voi. Đi đường giữa hoặc vòng hai bên.",
		"Mục tiêu: [b]chiếm thành[/b] của Lưu Long. Chỉ tướng chiếm được thành.",
	],
}
