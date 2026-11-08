extends RefCounted
# map rows: one line each reads better
# gdlint: disable=max-line-length
## tutorial t02: terrain cover (forest), a guard on the enemy castle (castle def +15: it takes focus fire), only the
## hero takes a castle -> win. Enemy: no commander, cannot buy -> taking its castle ends the game. Format: docs/content.md
## Roamer (6,5) hp 70 comes at us on enemy turn 1; guards hold until we come near (ai.gd).

const DEF := {
	"id": "t02",
	"order": 2,
	"title": "Công Thành",
	"hero": "anhhung",
	"enemyHero": null,
	"newUnits": [],
	"allowed": { "p": [], "e": [] },
	"gold": { "p": 0, "e": 0 },
	"tier": "easy",
	"ai": "normal",
	"win": { "type": "castles" },
	"stars": { "turns": 6 },
	"map": { "rows": ["hf.....fh", "f..f.....", "...f...c.", ".........", ".....f...", "f......hf", "ff.....ff"] },
	"owner": [[7, 2, "e"]],
	"units": [
		["p", "hero", 1, 3],
		["p", "soldier", 1, 2],
		["p", "soldier", 1, 4],
		["e", "soldier", 7, 2, { "guard": true, "hp": 70 }],
		["e", "soldier", 8, 3, { "guard": true, "hp": 60 }],
		["e", "soldier", 6, 5, { "hp": 70 }],
	],
	"quests": [{ "do": "stand_on", "what": "f" }, { "do": "kill_with" }],
	"tutorial": [
		{
			"card": "Mục tiêu",
			"point": [7, 2],
			"say": "Đây là lâu đài địch. Tướng đứng lên lâu đài rồi bấm 🏯 Chiếm lâu đài là thắng. Chỉ Tướng chiếm được lâu đài.",
		},
		{
			"card": "Lính giữ lâu đài",
			"point": [7, 2],
			"say": "Có lính đứng trên lâu đài thì phải hạ nó trước. Đứng trên lâu đài thì thủ rất cao: dồn 2–3 quân mới hạ được.",
		},
		{ "card": "Địa hình", "point": [3, 2], "say": "Rừng, đồi, lâu đài, làng: quân đứng trên bị mất ít máu hơn khi bị đánh." },
		{ "q": 0, "point": [3, 2], "allow": [[3, 2], [3, 1], [1, 2]], "say": "Đưa Vệ binh vào rừng, chờ địch tới" },
		{ "card": "Tự chỉ huy", "say": "Giờ bạn tự chỉ huy. Đi hết quân rồi bấm Hết lượt. Hạ lính giữ lâu đài, rồi đưa Tướng lên lâu đài." },
	],
}
