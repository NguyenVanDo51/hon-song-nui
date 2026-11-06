extends RefCounted
## mission m12: Trận Lãng Bạc. Format: docs/content.md

const DEF := {
	"id": "m12", "order": 12, "chapter": "c2",
	"title": "Trận Lãng Bạc",
	"place": "Lãng Bạc · Tiên Du, Bắc Ninh (có thuyết là Hồ Tây)",
	"region": "Lãng Bạc", "pos": [56, 32],
	"history": "Năm 42, quân Hai Bà và quân Mã Viện đánh lớn ở Lãng Bạc. Sách cũ chép trận này rất ác liệt, hai bên tổn thất nặng.",
	"hero": "anhhung", "enemyHero": "tuonggiac",
	"newUnits": ["bird"],
	"allowed": { "p": ["soldier", "archer", "boat", "drum", "shaman", "wolf", "elephant", "catapult", "bird"], "e": ["soldier", "archer", "boat", "drum", "shaman", "wolf", "elephant", "catapult", "bird"] },
	"gold": { "p": 900, "e": 300 },
	"win": { "type": "castles" },
	"map": { "rows": [
		"ffhfffhhf....c..",
		"hvrrrrrrrxrrrrv.",
		"f.rfh.fffhh.r...",
		"..rfh~~~~hh.r...",
		"..vr~~~~~~f.c...",
		"...r~~~~~~~.rv..",
		"..rc.~~~~~fffr..",
		"..r...~~~..hhr..",
		".vr......t.fhx..",
		"..c.........f...",
		"..rrrrrv........",
	] },
	"owner": [[2, 9, "p"], [1, 8, "p"], [7, 10, "p"], [13, 0, "e"], [12, 4, "e"], [14, 1, "e"], [13, 5, "e"]],
	"units": [
		["p", "hero", 3, 9], ["p", "bird", 2, 8], ["p", "archer", 1, 9], ["p", "soldier", 4, 9], ["p", "drum", 3, 8], ["p", "shaman", 2, 10],
		["e", "hero", 12, 3], ["e", "soldier", 11, 4], ["e", "soldier", 13, 4], ["e", "archer", 12, 5], ["e", "elephant", 11, 2],
		["e", "archer", 13, 1], ["e", "wolf", 14, 2], ["e", "soldier", 12, 1],
	],
	"story": {
		"intro": [
			["truyenthuyet", "Mã Viện men theo bờ biển tiến vào, đóng quân ở Lãng Bạc. Trưng Vương đem toàn quân ra đón đánh."],
			["mavien", "Ta đánh trận từ thời trai trẻ. Đàn bà xứ Giao Chỉ thì biết gì binh pháp?"],
			["trungtrac", "Binh pháp của ta là lòng dân. Hai thành bên hồ, lấy cả hai, Mã Viện sẽ phải lùi!"],
			["phungthichinh", "Thiếp xin đi trước mở đường, dù đang mang nặng."],
			["truyenthuyet", "Người Việt nhận mình là con Rồng cháu Tiên. Trận này, rồng cũng bay ra giữa hồ."],
		],
		"outro": [
			["trungtrac", "Mã Viện đã bỏ hai đồn bên hồ. Nhưng quân Hán còn đông, viện binh vẫn đến."],
		],
	},
	"tips": [
		"Trận lớn: được mua mọi loại quân. Địch có [b]2 thành[/b], phải lấy cả hai [b]và[/b] hạ Tướng giặc.",
		"[b]Rồng[/b] bay qua hồ, núi chỉ 1 bước, đi 7 ô, mạnh nhất trận nhưng giá 1000 vàng. Nỏ thủ bắn rồng +15 công: giữ rồng xa nỏ thủ giặc.",
		"[b]Tướng giặc[/b] đánh rất đau. Đánh lính lẻ trước, đừng lao vào giữa đội hình hắn.",
		"Thành trống phía tây hồ: chiếm sớm để có thêm vàng và chỗ mua lính.",
	],
}
