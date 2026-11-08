extends RefCounted
## level g01: drawn by sim/levelgen.gd (recipe g01, seed 1). Format: docs/content.md

const DEF := {
	"id": "g01",
	"order": 45,
	"title": "Bến Đò",
	"tier": "mid",
	"ai": "normal",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum"], "e": ["soldier", "archer"] },
	"gold": { "p": 650, "e": 200 },
	"win": { "type": "castles" },
	"stars": { "turns": 16 },
	"unitCap": 15,
	"night": false,
	"map": {
		"rows": [
			"vrrrrv~rrrrvf",
			"r....r~rfffhm",
			"r....r=rhhfhh",
			"r....~~vmhhhf",
			"rrc.~~.rf....",
			"r...~..rrrc..",
			"r...~..rf....",
			"r.fh=..vh....",
			"v..f~fhhmf...",
		],
	},
	"owner": [[2, 4, "p"], [10, 5, "e"], [0, 8, "p"], [7, 3, "e"]],
	"units": [
		["p", "hero", 2, 5],
		["p", "soldier", 3, 5],
		["p", "drum", 1, 5],
		["e", "hero", 10, 4],
		["e", "soldier", 10, 6],
		["e", "soldier", 11, 6],
		["e", "archer", 9, 5],
	],
	"waves": [],
	"gen": { "recipe": "g01", "seed": 1 },
}
