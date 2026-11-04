extends RefCounted
## mission m11: Bát Nàn Giữ Ải. Format: docs/content.md

const DEF := {
	"id": "m11", "order": 11, "chapter": "c2",
	"title": "Bát Nàn Giữ Ải",
	"place": "Tiên Phong · Phú Thọ",
	"region": "Phú Thọ", "pos": [14, 20],
	"history": "Bát Nàn, quê ở Tiên Phong (Phú Thọ), là nữ tướng của Hai Bà. Tương truyền bà giỏi cung nỏ, giữ các ải núi phía tây.",
	"hero": "trungtrac", "enemyHero": "mavien",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "shaman", "elephant"], "e": ["soldier", "archer", "drum", "elephant"] },
	"gold": { "p": 500, "e": 250 }, "incomeMul": { "e": 0.8 },
	"win": { "type": "castles" },
	"map": { "rows": [
		"...hmmmmf.....",
		"..rrvrrrrrrrc.",
		"..r.........r.",
		"h.rh......vrrf",
		"m.rmm..f...rmm",
		"mrvmmmfhmmhrmm",
		"mr.hmmh.mmmvhm",
		".r..mmf.mf..fm",
		".crv.mmmmh...m",
		"...hmmmmhf..hm",
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
		"Đặt [b]nỏ thủ[/b] trên đồi núi: thủ cao, bắn từ 2 ô thì địch cận chiến không đánh trả được.",
		"Hai dãy núi giữa bản đồ chặn voi. Đi đường giữa hoặc vòng hai bên.",
		"Mục tiêu: [b]chiếm thành[/b] địch. Chỉ tướng chiếm được thành.",
	],
}
