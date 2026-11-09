extends RefCounted
## m14: Rút Lên Núi. Format: docs/content.md

const DEF := {
	"id": "m14",
	"order": 140,
	"title": "Rút Lên Núi",
	"lore": "Đại quân Ma Vương tràn tới. Rút lên pháo đài trên núi mà giữ quân.",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "boat", "drum", "shaman"], "e": [] },
	"gold": { "p": 400, "e": 0 },
	"tier": "easy",
	"ai": "normal",
	"win": { "type": "reach", "at": [[1, 2]], "turns": 13 },
	"stars": { "turns": 9 },
	"map": {
		"rows": [
			"..h.....~~..fmh.",
			"....f...~~..hmm.",
			".c.hmm..==...hm.",
			".r..hm..~~....f.",
			".rrv.hf.~~rrrxr.",
			"mmrrrrrr==r.f.r.",
			"fhr...mm~~f...r.",
			"..v...hm==mmm.r.",
			".......h~~.hh.c.",
			"......hf~~......",
		]
	},
	"owner": [[1, 2, "p"], [14, 8, "p"]],
	"units": [
		["p", "hero", 14, 7],
		["p", "soldier", 13, 8],
		["p", "archer", 15, 8],
		["p", "soldier", 14, 9],
		["e", "hero", 15, 4],
		["e", "soldier", 12, 5],
		["e", "soldier", 11, 2],
		["e", "elephant", 10, 4],
		["e", "archer", 12, 1],
		["e", "archer", 3, 2, { "guard": true }],
		["e", "soldier", 4, 4],
		["e", "soldier", 5, 6],
	],
	"waves": [
		{ "turn": 4, "units": [["wolf", 15, 0], ["soldier", 15, 2]] },
		{ "turn": 7, "units": [["elephant", 15, 6], ["soldier", 2, 0], ["archer", 4, 1]] },
		{ "turn": 10, "units": [["wolf", 15, 9], ["soldier", 6, 9]] },
	],
}
