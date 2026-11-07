extends RefCounted
# prose / map rows: one line each reads better
# gdlint: disable=max-line-length
## mission m13: Phùng Thị Chính. Format: docs/content.md

const DEF := {
	"id": "m13",
	"order": 130,
	"title": "Địu Con Phá Vây",
	"hero": "anhhung",
	"enemyHero": null,
	"newUnits": ["shaman"],
	"allowed": { "p": [], "e": [] },
	"gold": { "p": 0, "e": 0 },
	"tier": "easy",
	"ai": "normal",
	"win": { "type": "reach", "at": [[12, 1]], "turns": 16 },
	"stars": { "turns": 6 },
	"map": {
		"rows": [
			"f....f.....fhf",
			"....hm....f.v.",
			"....fh......r.",
			"........f...r.",
			".fhff...mhfhr.",
			".hhfm...f..hr.",
			".fmhh.f.....r.",
			"..fmf.hf....r.",
			".vrrrrrrrrrrr.",
			"......h.......",
		]
	},
	"owner": [[12, 1, "p"]],
	"units": [
		["p", "hero", 1, 8],
		["p", "soldier", 2, 8],
		["p", "archer", 0, 8],
		["p", "elephant", 1, 9],
		["p", "soldier", 0, 7],
		["p", "shaman", 1, 7],
		["e", "soldier", 5, 4],
		["e", "soldier", 11, 5, { "hp": 80 }],
		["e", "archer", 10, 1],
		["e", "elephant", 10, 6, { "hp": 50 }],
		["e", "soldier", 11, 1, { "guard": true, "hp": 70 }],
		["e", "archer", 13, 2, { "guard": true, "hp": 70 }],
	],
	"waves": [
		{ "turn": 3, "units": [["soldier", 0, 5]] },
		{ "turn": 5, "units": [["wolf", 0, 2], ["soldier", 5, 9]] },
		{ "turn": 9, "units": [["soldier", 0, 0], ["archer", 6, 9]] },
	],
}
