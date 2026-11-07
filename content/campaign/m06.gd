extends RefCounted
## mission m06: Trận Bãi Sông. Format: docs/content.md

const DEF := {
	"id": "m06",
	"order": 6,
	"title": "Trận Bãi Sông",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "elephant"], "e": ["soldier", "archer", "drum", "elephant"] },
	"gold": { "p": 750, "e": 100 },
	"tier": "mid",
	"ai": "normal",
	"win": { "type": "hero" },
	"stars": { "turns": 8 },
	"map": {
		"rows": [
			"...v.~~~~.....",
			"...r~~~~~.vrc.",
			"..rr~~vr=rrr..",
			"~~=~~.r.~~~=~~",
			"hfr.~.r..~frfh",
			"hvrr=rrt.=hrvh",
			"hfr.~.r..~.ffh",
			"~~=~~~v.~~~=~~",
			".cr.~~~~~...f.",
			"..v.~~~~~..hhf",
		],
	},
	"owner": [[1, 8, "p"], [12, 1, "e"]],
	"units": [
		["p", "hero", 2, 8],
		["p", "elephant", 3, 9],
		["p", "archer", 0, 8],
		["p", "soldier", 3, 8],
		["e", "hero", 11, 1, { "guard": true }],
		["e", "archer", 12, 2],
		["e", "soldier", 10, 0],
		["e", "soldier", 10, 2],
		["e", "archer", 11, 2],
		["e", "elephant", 13, 2],
	],
}
