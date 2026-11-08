extends RefCounted
# map rows: one line each reads better
# gdlint: disable=max-line-length
## tutorial t03: our castle (gold, buy), a bought unit acts at once, villages (gold + heal), a hurt soldier back to our
## village, end turn early, heal at turn start; then win by taking the enemy castle. Enemy cannot buy: a wave of 2
## soldiers on turn 2 (spawned done, they act from enemy turn 3). Format: docs/content.md

const DEF := {
	"id": "t03",
	"order": 3,
	"title": "Chiêu Binh",
	"hero": "anhhung",
	"enemyHero": null,
	"newUnits": [],
	"allowed": { "p": ["soldier"], "e": [] },
	"gold": { "p": 200, "e": 0 },
	"tier": "easy",
	"ai": "normal",
	"win": { "type": "castles" },
	"stars": { "turns": 8 },
	"map": { "rows": ["hf......fh", "f.v....v.f", "....f.....", ".c......c.", ".....f....", "f.v....v.f", "hf......fh"] },
	"owner": [[1, 3, "p"], [2, 5, "p"], [8, 3, "e"], [7, 5, "e"]],
	"units": [["p", "hero", 2, 3], ["p", "soldier", 3, 4, { "hp": 40 }], ["e", "soldier", 8, 3, { "guard": true, "hp": 80 }]],
	"waves": [{ "turn": 2, "units": [["soldier", 8, 1], ["soldier", 8, 5]] }],
	"quests": [
		{ "do": "stand_on", "what": "v" },
		{ "do": "buy", "what": "soldier" },
		{ "do": "capture", "what": "v" },
		{ "do": "end_turn" },
		{ "do": "heal_on", "what": "v" },
	],
	"tutorial": [
		{ "card": "Mục tiêu", "point": [8, 3], "say": "Thắng khi Tướng chiếm lâu đài địch bên phải. Địch sắp kéo tới: cần thêm quân." },
		{ "q": 0, "point": [2, 5], "allow": [[2, 5], [3, 4]], "say": "Vệ binh này chỉ còn 40 máu. Đưa về làng ta: đầu lượt sau được hồi máu" },
		{ "card": "Lâu đài của bạn", "point": [1, 3], "say": "Lâu đài ta: mỗi lượt +50 vàng. Mua quân ở đây." },
		{ "q": 1, "point": [1, 3], "allow": [[1, 3], "buy:soldier"], "say": "Chạm lâu đài, mua 1 Vệ binh (150 vàng)" },
		{ "q": 2, "point": [2, 1], "allow": [[2, 1], [1, 3]], "say": "Quân mới mua đi được ngay. Đưa Vệ binh vào làng rồi bấm 🏠 Chiếm làng" },
		{ "card": "Làng", "point": [2, 1], "say": "Làng của bạn: +30 vàng mỗi lượt. Quân ta đứng trên làng / lâu đài được hồi 20 máu đầu lượt." },
		{
			"q": 3,
			"point": "end_turn",
			"allow": ["end_turn"],
			"title": "Hết lượt",
			"say": "Tướng chưa đi cũng được: quân chưa đi thì đứng yên. Bấm Hết lượt",
		},
		{ "q": 4, "point": [2, 5], "allow": [[2, 5]], "say": "Làng hồi máu đầu lượt: +20" },
		{ "card": "Vàng", "say": "Lâu đài + mỗi làng cho vàng mỗi lượt. Càng nhiều làng, càng mua được nhiều quân." },
		{ "card": "Tự chỉ huy", "say": "Mua quân, chiếm thêm làng, quân yếu về làng hồi máu, rồi đưa Tướng chiếm lâu đài địch!" },
	],
}
