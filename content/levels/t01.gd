extends RefCounted
# map rows: one line each reads better
# gdlint: disable=max-line-length
## tutorial t01: pick + move a unit, grey = done, every unit each turn, Hết lượt; enemies arrive (wave turn 1, spawned
## done so they only act from enemy turn 2) -> attack, counterattack, focus fire. Format: docs/content.md
## Enemy A (7,3) hp 80: hero 45–55 + soldier 40–45 always kills it (hero first). B (8,1) hp 60 = free play.

const DEF := {
	"id": "t01",
	"order": 1,
	"title": "Bài Học Đầu",
	"lore": "Làng biên giới cuối cùng còn trung thành. Quân Ma Vương đang tới.",
	"hero": "anhhung",
	"enemyHero": null,
	"newUnits": ["hero", "soldier"],
	"allowed": { "p": [], "e": [] },
	"gold": { "p": 0, "e": 0 },
	"tier": "easy",
	"ai": "normal",
	"nudgeEnd": true,
	"win": { "type": "rout" },
	"stars": { "turns": 6 },
	"map": { "rows": ["ff....hff", "f.......f", ".........", "....f....", ".........", ".h......f", "ff....hhf"] },
	"units": [["p", "hero", 1, 2], ["p", "soldier", 1, 4]],
	"waves": [{ "turn": 1, "units": [["soldier", 7, 3, { "hp": 80 }], ["soldier", 8, 1, { "hp": 60 }]] }],
	"quests": [
		{ "do": "select", "what": "hero" },
		{ "do": "move", "what": "hero" },
		{ "do": "move", "what": "soldier" },
		{ "do": "end_turn" },
		{ "do": "attack_with", "what": "hero" },
		{ "do": "kill_with", "what": "soldier" },
	],
	"tutorial": [
		{ "card": "Mục tiêu", "say": "Bạn chỉ huy Tướng và Vệ binh. Thắng khi hạ hết quân địch. Trước hết: tập đi quân." },
		{ "q": 0, "point": [1, 2], "allow": [[1, 2]], "say": "Chạm vào Tướng để chọn" },
		{ "q": 1, "point": [4, 2], "allow": [[4, 2], [1, 2]], "say": "Ô sáng = nơi Tướng đi tới được. Chạm ô có vòng, rồi bấm ⏳ Chờ" },
		{
			"card": "Quân đã đi",
			"point": [4, 2],
			"also": [[1, 4]],
			"say": "Tướng đã ra lệnh nên xám lại. Vệ binh chưa đi nên còn sáng. Mỗi quân chỉ đi 1 lần mỗi lượt.",
		},
		{ "q": 2, "point": [4, 4], "allow": [[4, 4], [1, 4]], "say": "Mỗi lượt bạn điều khiển được TẤT CẢ quân. Giờ tới Vệ binh" },
		{ "q": 3, "point": "end_turn", "allow": ["end_turn"], "title": "Hết lượt", "say": "Mọi quân đã xám. Bấm Hết lượt: địch đi, rồi lại tới bạn" },
		{ "card": "Địch tới!", "point": [7, 3], "say": "Hai Vệ binh địch kéo tới. Hạ hết chúng để thắng." },
		{ "q": 4, "point": [7, 3], "allow": [[7, 3], [4, 2]], "say": "Chọn Tướng, chạm địch có vòng, rồi bấm ⚔ Đánh" },
		{
			"card": "Địch đánh trả",
			"point": [7, 3],
			"say": "Bị đánh, địch đánh trả. Nhưng máu càng ít thì đánh càng yếu. Mẹo: dồn nhiều quân vào 1 tên để hạ gọn.",
		},
		{ "q": 5, "point": [7, 3], "allow": [[7, 3], [4, 4]], "say": "Vệ binh đánh tiếp tên này!" },
		{ "card": "Tự chỉ huy", "say": "Còn 1 tên. Mỗi lượt: đi hết quân rồi bấm Hết lượt. Dồn quân hạ nốt để thắng!" },
	],
}
