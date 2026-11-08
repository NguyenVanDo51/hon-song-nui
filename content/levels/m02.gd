extends RefCounted
## mission m02: Về Lại Mê Linh. Format: docs/content.md

const DEF := {
	"id": "m02",
	"order": 20,
	"title": "Về Lại Mê Linh",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": ["archer"],
	"allowed": { "p": ["soldier", "archer"], "e": ["soldier", "archer"] },
	"gold": { "p": 550, "e": 100 },
	"tier": "easy",
	"ai": "normal",
	"nudgeEnd": true,
	"win": { "type": "castles" },
	"stars": { "turns": 11 },
	"quests": [{ "do": "buy", "what": "archer" }, { "do": "capture", "what": "c" }],
	"map": {
		"rows": [
			".fffhhf~.v...",
			".rrvfhh~.r...",
			".c.rrrr=rrv..",
			".r.....~..r..",
			".vr....~.rrrc",
			"..r....=.rf..",
			"ffv....~.rhhf",
			"hhf....~.vhf.",
			"fhf....~..f..",
		],
	},
	"owner": [[1, 2, "p"], [12, 4, "e"], [3, 1, "p"]],
	"units": [
		["p", "hero", 2, 2],
		["p", "soldier", 1, 3],
		["p", "archer", 2, 3],
		["e", "hero", 11, 4],
		["e", "soldier", 10, 3],
		["e", "archer", 11, 5, { "guard": true }],
	],
}
