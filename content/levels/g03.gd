extends RefCounted
## level g03: drawn by sim/levelgen.gd (recipe g03, seed 1). Format: docs/content.md

const DEF := {
	"id": "g03",
	"order": 63,
	"title": "Ngã Ba Sông",
	"tier": "mid",
	"ai": "normal",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "elephant"], "e": ["soldier", "archer", "drum", "elephant"] },
	"gold": { "p": 700, "e": 350 },
	"win": { "type": "castles" },
	"stars": { "turns": 16 },
	"unitCap": 15,
	"night": false,
	"map": {
		"rows": [
			"hf.....~.fhhhfv",
			"vrrc..~~..fhf.r",
			".r....~~vfhh..r",
			".rfhf..=rrrrrcr",
			".rhh...~r..r...",
			".r.hhf.~r..r.ff",
			"rc.fhfr=r..r.hh",
			"rrrrrrv~...r...",
			"r.ffhhh~~..crrv",
			"v...fhf~~......",
		],
	},
	"owner": [[3, 1, "p"], [11, 8, "e"], [1, 6, "p"], [13, 3, "e"], [0, 1, "p"], [14, 8, "e"]],
	"units": [
		["p", "hero", 3, 0],
		["p", "soldier", 2, 1],
		["p", "archer", 4, 1],
		["e", "hero", 11, 9],
		["e", "soldier", 12, 8],
		["e", "archer", 10, 8],
	],
	"waves": [],
	"gen": { "recipe": "g03", "seed": 1 },
}
