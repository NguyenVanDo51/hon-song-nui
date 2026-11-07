extends RefCounted
# prose / map rows: one line each reads better
# gdlint: disable=max-line-length
## mission m07: Vây Thành Long Biên. Format: docs/content.md

const DEF := {
	"id": "m07",
	"order": 7,
	"title": "Vây Thành Long Biên",
	"place": "Long Biên, Hà Nội",
	"region": "Long Biên",
	"pos": [70, 44],
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": ["catapult"],
	"allowed": { "p": ["soldier", "archer", "drum", "elephant"], "e": ["soldier", "archer", "drum", "elephant", "catapult"] },
	"gold": { "p": 1200, "e": 0 },
	"tier": "mid",
	"ai": "normal",
	"win": { "type": "castles" },
	"stars": { "turns": 13 },
	"map": {
		"rows": [
			"~~~~~.......c.f",
			"~~~...vrrrrrrvh",
			"~~........hf.r.",
			"~f....f...fh.c.",
			"fhv...h=.....r.",
			"..r..fh~~...rv.",
			"..r...~~....r..",
			".crrrvr=rrrrr..",
			".r....fhfhmhvhf",
			".v...fhmhffhff.",
		],
	},
	"owner": [[1, 7, "p"], [12, 0, "e"], [13, 3, "e"], [13, 1, "e"]],
	"units": [
		["p", "hero", 2, 7],
		["p", "catapult", 1, 8],
		["p", "elephant", 2, 6],
		["p", "archer", 0, 7],
		["p", "soldier", 3, 8],
		["e", "hero", 12, 2],
		["e", "archer", 11, 3, { "guard": true, "rank": 1 }],
		["e", "archer", 9, 1, { "guard": true }],
		["e", "elephant", 11, 4],
		["e", "soldier", 12, 4],
		["e", "catapult", 13, 2, { "guard": true }],
	],
}
