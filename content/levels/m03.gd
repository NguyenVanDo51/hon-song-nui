extends RefCounted
# prose / map rows: one line each reads better
# gdlint: disable=max-line-length
## mission m03: Giữ Làng Hạ Lôi. Format: docs/content.md

const DEF := {
	"id": "m03",
	"order": 30,
	"title": "Giữ Làng Hạ Lôi",
	"hero": "anhhung",
	"enemyHero": null,
	"newUnits": ["drum"],
	"allowed": { "p": ["soldier", "archer"], "e": [] },
	"gold": { "p": 500, "e": 0 },
	"tier": "easy",
	"ai": "normal",
	"win": { "type": "survive", "turns": 10 },
	"stars": { "lost": 0 },
	"map": {
		"rows": [
			"~~~~~~~~~~~~",
			"..f......f.~",
			"fhhhff.rrrv~",
			"fhrvrrtr...~",
			"..r.rcrv....",
			"..v.r.......",
			"....r..fh...",
			"....v..fhf..",
			".......hfhf.",
		],
	},
	"owner": [[5, 4, "p"], [7, 4, "p"], [3, 3, "p"]],
	"units": [["p", "hero", 5, 5], ["p", "soldier", 4, 4], ["p", "drum", 6, 5], ["p", "archer", 5, 3]],
	"waves": [
		{ "turn": 2, "units": [["soldier", 1, 1], ["soldier", 6, 1], ["soldier", 10, 1]] },
		{ "turn": 4, "units": [["soldier", 11, 4], ["soldier", 11, 5], ["archer", 8, 1]] },
		{ "turn": 6, "units": [["soldier", 0, 1], ["soldier", 4, 1], ["soldier", 11, 6], ["archer", 7, 1]] },
		{ "turn": 8, "units": [["soldier", 11, 4], ["soldier", 11, 7], ["soldier", 3, 1], ["archer", 9, 1], ["soldier", 6, 1, { "rank": 1 }]] },
	],
}
