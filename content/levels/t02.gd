extends RefCounted
# map rows: one line each reads better
# gdlint: disable=max-line-length
## tutorial t02: buy a soldier, heal a hurt one on our village, then take the enemy castle. Format: docs/content.md
## no enemy units (a hurt soldier must not die mid-lesson): the enemy holds only its castle, so it never loses by
## having no troops (Game.loss_reason: castles > 0) and cannot buy (allowed.e [], gold.e 0).

const DEF := {
	"id": "t02",
	"order": 2,
	"title": "Chiêu Binh",
	"hero": "anhhung",
	"enemyHero": null,
	"newUnits": ["soldier"],
	"allowed": { "p": ["soldier"], "e": [] },
	"gold": { "p": 150, "e": 0 },
	"tier": "easy",
	"ai": "normal",
	"win": { "type": "castles" },
	"stars": { "turns": 4 },
	"map": { "rows": ["hff...ffh", "f.v....f.", "..r......", "..r.rrrc.", ".crrr....", "....ff..h", "hf..fhh.f"] },
	"owner": [[1, 4, "p"], [2, 1, "p"], [7, 3, "e"]],
	"units": [["p", "hero", 2, 4], ["p", "soldier", 3, 2, { "hp": 40 }]],
	"quests": [{ "do": "buy", "what": "soldier" }, { "do": "stand_on", "what": "v" }, { "do": "end_turn" }, { "do": "heal_on", "what": "v" }],
	"tutorial": [
		{ "q": 0, "point": [1, 4], "allow": [[1, 4], "buy:soldier"], "say": "Bấm thành, mua Vệ binh" },
		{ "q": 1, "point": [2, 1], "allow": [[2, 1], [3, 2]], "say": "Đưa lính bị thương về làng" },
		{ "q": 2, "point": "end_turn", "allow": ["end_turn"], "say": "Hết lượt" },
		{ "q": 3, "point": [2, 1], "allow": [[2, 1]], "say": "Làng hồi máu đầu lượt" },
	],
}
