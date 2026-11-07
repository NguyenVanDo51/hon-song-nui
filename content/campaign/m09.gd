extends RefCounted
## mission m09: Tin Dữ Hợp Phố. Format: docs/content.md

const DEF := {
	"id": "m09",
	"order": 9,
	"chapter": "c2",
	"title": "Tin Dữ Hợp Phố",
	"place": "Hợp Phố · bờ biển phía đông bắc",
	"region": "Hợp Phố",
	"pos": [88, 12],
	"hero": "anhhung",
	"enemyHero": null,
	"newUnits": ["boat"],
	"allowed": { "p": ["soldier", "archer", "drum", "elephant"], "e": [] },
	"gold": { "p": 500, "e": 0 },
	"win": { "type": "survive", "turns": 9 },
	"stars": { "lost": 0 },
	"map": {
		"rows": [
			"~~~~~~~~~~~~~~",
			"~~~.......~~~~",
			"~~.vrr......~~",
			"~....rrrrrv.~~",
			"~....rc...r..~",
			".vrrrr....r..~",
			"....rv....v..~",
			"f...rhhf.....~",
			"hf.fvff..ff..~",
			"fh.hhf...fhhf~",
		]
	},
	"owner": [[6, 4, "p"], [3, 2, "p"], [5, 6, "p"], [1, 5, "p"]],
	"units": [["p", "hero", 6, 5], ["p", "soldier", 5, 4], ["p", "archer", 7, 4], ["p", "drum", 6, 3]],
	"waves": [
		{ "turn": 2, "units": [["soldier", 4, 1], ["soldier", 9, 1], ["soldier", 12, 4]] },
		{ "turn": 3, "units": [["archer", 12, 6], ["boat", 12, 2]] },
		{ "turn": 5, "units": [["soldier", 2, 2], ["boat", 13, 8], ["elephant", 8, 1], ["archer", 3, 1]] },
		{ "turn": 7, "units": [["soldier", 6, 1, { "rank": 1 }], ["soldier", 12, 5], ["boat", 0, 3], ["soldier", 11, 8], ["archer", 12, 7]] },
	],
}
