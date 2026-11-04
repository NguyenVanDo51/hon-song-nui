extends RefCounted
## mission m18: Hai Anh Em. Format: docs/content.md

const DEF := {
	"id": "m18", "order": 18, "chapter": "c3",
	"title": "Hai Anh Em Họ Triệu",
	"place": "Quan Yên · Yên Định, Thanh Hóa",
	"region": "Quan Yên", "pos": [40, 22],
	"history": "Triệu Quốc Đạt là hào trưởng huyện Quan Yên, anh của Bà Triệu. Ông khởi binh trước, Bà đem quân núi Nưa tới hợp sức.",
	"hero": "trieuquocdat", "enemyHero": "douy",
	"newUnits": ["hero"],
	"allowed": { "p": ["soldier", "archer", "drum", "shaman", "elephant"], "e": ["soldier", "archer", "drum", "elephant"] },
	"gold": { "p": 450, "e": 200 }, "incomeMul": { "e": 0.8 },
	"win": { "type": "castles" },
	"map": { "rows": [
		"mmh...f..h..c.",
		"mh..v.....f...",
		"m..f..h.v....h",
		"h....mm....f..",
		"..v..mm..h....",
		".f.....f...v..",
		"...h.......f..",
		".v...f..h.....",
		"c...h....f..h.",
		"..f.....h...f.",
	] },
	"owner": [[0, 8, "p"], [1, 7, "p"], [12, 0, "e"], [8, 2, "e"]],
	"units": [
		["p", "hero", 1, 8], ["p", "soldier", 0, 9], ["p", "archer", 1, 9], ["p", "elephant", 2, 8], ["p", "drum", 0, 7],
		["e", "hero", 11, 0, { "guard": true }], ["e", "soldier", 10, 1], ["e", "soldier", 12, 2], ["e", "archer", 13, 1], ["e", "elephant", 11, 3],
	],
	"story": {
		"intro": [
			["trieuquocdat", "Em gái ta đã dẹp toán lính trên núi. Giờ đến lượt đồn Ngô ở Quan Yên."],
			["douy", "Bọn Lạc dân dám động tới đồn của triều đình? Quân ta núp rừng mà đánh!"],
			["trieuquocdat", "Chiếm đồn rồi, dân cả huyện sẽ theo ta."],
		],
		"outro": [["trieuquocdat", "Đồn Quan Yên đã về tay ta. Em gái, cờ của em sẽ phấp phới khắp Cửu Chân."]],
	},
	"tips": [
		"[b]Triệu Quốc Đạt[/b] đi đồi núi chỉ tốn 1, lính đứng cạnh ông +10 thủ.",
		"Đô úy đứng trong rừng thêm +15 thủ. Dụ hắn ra chỗ trống rồi mới đánh.",
		"Mục tiêu: [b]chiếm thành[/b] địch ở góc đông bắc.",
	],
}
