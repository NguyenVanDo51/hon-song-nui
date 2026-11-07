extends RefCounted
## level g04: drawn by sim/levelgen.gd (recipe g04, seed 1). Format: docs/content.md

const DEF := {
	"id": "g04",
	"order": 67,
	"title": "Giữ Đồn",
	"tier": "easy",
	"ai": "normal",
	"hero": "anhhung",
	"enemyHero": null,
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "elephant"], "e": [] },
	"gold": { "p": 400, "e": 0 },
	"win": { "type": "survive", "turns": 9 },
	"stars": { "lost": 5 },
	"unitCap": 15,
	"night": false,
	"map": {
		"rows": [
			".vrrrrvfmhhf..",
			"......rfhhf...",
			"......rrrrrrrv",
			"......r.t....r",
			"...f..r......r",
			"...hf.r...fh.r",
			"f.rrrrvhf..h.r",
			"h.c.fhfh..ff.r",
			"f...hmhm.....r",
			"....fhfhf....v",
		],
	},
	"owner": [[2, 7, "p"], [6, 6, "p"]],
	"units": [
		["p", "hero", 1, 8],
		["p", "soldier", 3, 7],
		["p", "archer", 1, 7],
		["p", "drum", 3, 6],
		["e", "soldier", 12, 5],
		["e", "soldier", 13, 6],
	],
	"waves": [
		{ "turn": 2, "units": [["soldier", 12, 8], ["soldier", 13, 8], ["archer", 12, 7]] },
		{ "turn": 4, "units": [["soldier", 13, 7], ["elephant", 12, 6], ["archer", 12, 4]] },
		{ "turn": 6, "units": [["soldier", 13, 4], ["soldier", 13, 3], ["elephant", 11, 8], ["archer", 12, 9]] },
	],
	"gen": { "recipe": "g04", "seed": 1 },
}
