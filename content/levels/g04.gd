extends RefCounted
## level g04: drawn by sim/levelgen.gd (recipe g04, seed 1). Format: docs/content.md

const DEF := {
	"id": "g04",
	"order": 67,
	"title": "Giữ Đồn",
	"tier": "mid",
	"ai": "normal",
	"hero": "anhhung",
	"enemyHero": null,
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "elephant"], "e": [] },
	"gold": { "p": 600, "e": 0 },
	"win": { "type": "survive", "turns": 9 },
	"stars": { "lost": 3 },
	"unitCap": 15,
	"night": false,
	"map": {
		"rows": [
			".vrrrrvfhhhf..",
			"....hfrfmhf...",
			"....h.rrrrrrrv",
			"....m.r......r",
			".f..h.r......r",
			"hf..f.r...f..r",
			"h.rrrrv..fh..r",
			"m.c...f......r",
			"h.....hhf....r",
			"ff..ffhmh....v",
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
