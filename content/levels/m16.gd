extends RefCounted
## mission m16: Sông Hát. Format: docs/content.md

const DEF := {
	"id": "m16",
	"order": 160,
	"title": "Đêm Sông Hát",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "boat", "drum", "shaman", "wolf", "elephant"], "e": [] },
	"gold": { "p": 200, "e": 0 },
	"tier": "mid",
	"ai": "normal",
	"win": { "type": "survive", "turns": 8 },
	"stars": { "lost": 7 },
	"night": true,
	"map": {
		"rows": [
			"~~~~~~~~~~~~~~",
			"~~~......~~~~~",
			"~hf.rrrv...~~~",
			".h..c..r.....~",
			".frvr.rrrvrrr.",
			".fr...rfhhf.r.",
			"..r...xffhf.r.",
			"f.r....hff..r.",
			"..v....hf...v.",
			".f..h..f...f..",
		]
	},
	"owner": [[4, 3, "p"], [7, 2, "p"], [3, 4, "p"]],
	"units": [
		["p", "hero", 4, 4],
		["p", "elephant", 5, 3, { "hp": 70 }],
		["p", "archer", 3, 3],
		["p", "soldier", 4, 2, { "hp": 60 }],
		["p", "shaman", 3, 2],
	],
	"waves": [
		{ "turn": 1, "units": [["soldier", 0, 6], ["soldier", 13, 4], ["soldier", 6, 9]] },
		{ "turn": 2, "units": [["soldier", 0, 9], ["soldier", 13, 5], ["soldier", 8, 9], ["archer", 12, 3], ["wolf", 13, 8]] },
		{ "turn": 3, "units": [["wolf", 13, 7], ["soldier", 0, 6, { "rank": 1 }], ["archer", 4, 9]] },
		{ "turn": 4, "units": [["elephant", 13, 4], ["catapult", 12, 9], ["soldier", 0, 4, { "rank": 1 }], ["archer", 6, 9], ["drum", 13, 6]] },
		{ "turn": 5, "units": [["hero", 13, 6], ["soldier", 13, 8, { "rank": 1 }], ["soldier", 1, 9, { "rank": 1 }], ["elephant", 10, 9]] },
		{
			"turn": 6,
			"units": [
				["soldier", 0, 7, { "rank": 2 }],
				["soldier", 12, 3, { "rank": 1 }],
				["bird", 13, 9],
				["elephant", 9, 9],
				["archer", 0, 5],
				["catapult", 0, 8],
			],
		},
		{ "turn": 7, "units": [["soldier", 13, 4, { "rank": 1 }], ["soldier", 0, 8], ["catapult", 13, 6], ["shaman", 11, 9], ["elephant", 0, 3]] },
	],
}
