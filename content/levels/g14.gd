extends RefCounted
## level g14: drawn by sim/levelgen.gd (recipe g14, seed 1). Format: docs/content.md

const DEF := {
	"id": "g14",
	"order": 145,
	"title": "Đầm Lầy",
	"tier": "easy",
	"ai": "normal",
	"hero": "anhhung",
	"enemyHero": null,
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "elephant", "boat", "wolf", "shaman"], "e": [] },
	"gold": { "p": 800, "e": 0 },
	"win": { "type": "survive", "turns": 8 },
	"stars": { "lost": 2 },
	"unitCap": 15,
	"night": false,
	"map": {
		"rows": [
			"vrrv..~..fh..",
			"...r..~.fhmf.",
			"...r..=..ff..",
			"ff.r..~~....v",
			"h..rff.~~hf.r",
			"f..rfhf~~h..r",
			"..crfhf~fmf.r",
			"...rrrr=rrrrr",
			".......~v....",
		],
	},
	"owner": [[2, 6, "p"], [3, 0, "p"]],
	"units": [
		["p", "hero", 2, 7],
		["p", "soldier", 3, 7],
		["p", "archer", 3, 6],
		["p", "shaman", 1, 6],
		["p", "drum", 3, 5],
		["e", "soldier", 12, 5],
		["e", "soldier", 10, 5],
	],
	"waves": [
		{ "turn": 2, "units": [["soldier", 11, 3], ["soldier", 12, 1]] },
		{ "turn": 4, "units": [["soldier", 11, 2], ["archer", 11, 5], ["wolf", 12, 6]] },
		{ "turn": 6, "units": [["soldier", 11, 0], ["soldier", 12, 4], ["archer", 11, 6]] },
	],
	"gen": { "recipe": "g14", "seed": 1 },
}
