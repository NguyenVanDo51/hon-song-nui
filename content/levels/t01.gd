extends RefCounted
# map rows: one line each reads better
# gdlint: disable=max-line-length
## tutorial t01: select, take a village, end turn, forest cover, first attack. Format: docs/content.md
## enemies = low-hp guards (hold until we come near, ai.gd); only one tile next to the forest (5,2) is in reach of
## the first guard, so it strikes from there and step 5 points at it. The second guard stays out of reach.

const DEF := {
	"id": "t01",
	"order": 1,
	"title": "Bài Học Đầu",
	"hero": "anhhung",
	"enemyHero": null,
	"newUnits": ["hero"],
	"allowed": { "p": [], "e": [] },
	"gold": { "p": 0, "e": 0 },
	"tier": "easy",
	"ai": "normal",
	"win": { "type": "rout" },
	"stars": { "turns": 6 },
	"map": { "rows": ["ff...hhf.", "fvrr....f", ".r.rf....", ".r..h....", ".r.......", "ff..ff...", "fh..ffh.."] },
	"units": [["p", "hero", 1, 4], ["e", "soldier", 8, 4, { "guard": true, "hp": 60 }], ["e", "soldier", 8, 6, { "guard": true, "hp": 50 }]],
	"quests": [
		{ "do": "select", "what": "hero" },
		{ "do": "capture", "what": "v" },
		{ "do": "end_turn" },
		{ "do": "stand_on", "what": "f" },
		{ "do": "attack_with", "what": "hero" },
	],
	"tutorial": [
		{ "q": 0, "point": [1, 4], "allow": [[1, 4]], "say": "Chọn tướng" },
		{ "q": 1, "point": [1, 1], "allow": [[1, 1], [1, 4]], "say": "Làng: vàng mỗi lượt, đứng trên thì hồi máu" },
		{ "q": 2, "point": "end_turn", "allow": ["end_turn"], "say": "Hết lượt" },
		{ "q": 3, "point": [4, 2], "allow": [[4, 2], [1, 1]], "say": "Rừng: thủ cao hơn" },
		{ "q": 4, "point": [5, 2], "allow": [[5, 2], [4, 2]], "say": "Đánh địch" },
	],
}
