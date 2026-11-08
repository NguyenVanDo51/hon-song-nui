extends RefCounted
## mission m08: Trị Sở Luy Lâu. Format: docs/content.md

const DEF := {
	"id": "m08",
	"order": 80,
	"title": "Trị Sở Luy Lâu",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "elephant", "catapult"], "e": ["soldier", "archer", "drum", "elephant", "catapult"] },
	"gold": { "p": 2200, "e": 0 },
	"tier": "easy",
	"ai": "normal",
	"win": { "type": "castles" },
	"stars": { "turns": 17 }, # AI win median 30: AI-vs-AI drags here, a player should be faster
	"map": {
		"rows": [
			"...........~~v..",
			".c.h.......~~rc.",
			".r.rrrvrrrr=rrr.",
			"hrrv.......~~.r.",
			".r..hff.t..~~.v.",
			".vr.mhhf...=hfr.",
			"..r...mh..~~fhr.",
			".frrcrhf.~~..fr.",
			"fhv..rf..~~.vrr.",
			"mh...rhh=~~.f.r.",
			"hf...vmf~~fhm.c.",
			"......f.~~fhh...",
		],
	},
	"owner": [[1, 1, "p"], [14, 1, "e"], [14, 10, "e"]],
	"units": [
		["p", "hero", 2, 1],
		["p", "elephant", 1, 2],
		["p", "archer", 2, 2],
		["p", "catapult", 0, 3],
		["p", "drum", 3, 1],
		["e", "hero", 13, 1],
		["e", "elephant", 13, 2],
		["e", "archer", 14, 2, { "rank": 1 }],
		["e", "elephant", 15, 0, { "rank": 1 }],
		["e", "drum", 13, 9],
		["e", "soldier", 14, 9],
		["e", "catapult", 15, 10, { "guard": true }],
	],
}
