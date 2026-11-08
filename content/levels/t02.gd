extends RefCounted
# map rows: one line each reads better
# gdlint: disable=max-line-length
## tutorial t02: an empty castle mid-map (only the hero takes it: def +15, heals 20 a turn), forest cover, then hold the
## castle and beat every enemy (win rout). Enemy: 3 soldiers that come at us (cannot take castles), cannot buy.
## Format: docs/content.md

const DEF := {
	"id": "t02",
	"order": 2,
	"title": "Lâu Đài Trống",
	"hero": "anhhung",
	"enemyHero": null,
	"newUnits": [],
	"allowed": { "p": [], "e": [] },
	"gold": { "p": 0, "e": 0 },
	"tier": "easy",
	"ai": "normal",
	"win": { "type": "rout" },
	"stars": { "turns": 7 },
	"map": { "rows": ["hf.....fh", "f.......f", "...f.....", "....c....", "...f.....", "f.......f", "ff.....hf"] },
	"units": [
		["p", "hero", 1, 3],
		["p", "soldier", 1, 2],
		["p", "soldier", 1, 4],
		["e", "soldier", 8, 2, { "hp": 80 }],
		["e", "soldier", 8, 4, { "hp": 80 }],
		["e", "soldier", 7, 3, { "hp": 70 }],
	],
	"quests": [{ "do": "capture", "what": "c" }, { "do": "stand_on", "what": "f" }, { "do": "kill_with" }],
	"tutorial": [
		{ "card": "Mục tiêu", "say": "Hạ hết quân địch để thắng. Giữa bản đồ có 1 lâu đài trống: chiếm nó trước!" },
		{ "card": "Lâu đài", "point": [4, 3], "say": "Chỉ Tướng chiếm được lâu đài. Quân đứng trên lâu đài thủ rất cao và hồi 20 máu mỗi lượt." },
		{ "q": 0, "point": [4, 3], "allow": [[4, 3], [1, 3]], "say": "Đưa Tướng lên lâu đài rồi bấm 🏯 Chiếm lâu đài" },
		{ "card": "Địa hình", "point": [3, 2], "say": "Rừng, đồi, làng cũng giúp thủ: đứng trên đó bị mất ít máu hơn." },
		{ "q": 1, "point": [3, 2], "allow": [[3, 2], [3, 4], [1, 2]], "say": "Đưa Vệ binh vào rừng cạnh lâu đài, chờ địch tới" },
		{ "card": "Tự chỉ huy", "say": "Giữ lâu đài + rừng, để địch đánh vào chỗ thủ cao. Dồn quân hạ từng tên. Hạ hết để thắng!" },
	],
}
