extends RefCounted
## mission m05: Đêm Hồ Tây. Format: docs/content.md

const DEF := {
	"id": "m05",
	"order": 50,
	"title": "Đêm Hồ Tây",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "elephant"], "e": ["soldier", "archer", "drum", "elephant"] },
	"gold": { "p": 800, "e": 150 },
	"tier": "easy",
	"ai": "normal",
	"win": { "type": "castles" },
	"stars": { "turns": 8 },
	"night": true,
	"map": {
		"rows": [
			"..rrvrrrr.....",
			"..r.....vrrrc.",
			"..r....hf.r...",
			"frv..ffh..r...",
			"hr..fhfhf.rfhf",
			"hr.fhh....rhf.",
			"fr.hhf....vf..",
			".v..hff...r...",
			".c..f..vrrr...",
			"..............",
		],
	},
	"owner": [[1, 8, "p"], [12, 1, "e"], [8, 1, "e"]],
	"units": [
		["p", "hero", 2, 8],
		["p", "drum", 2, 7],
		["p", "soldier", 1, 7],
		["p", "elephant", 3, 8],
		["e", "hero", 11, 1],
		["e", "soldier", 10, 2],
		["e", "soldier", 9, 3],
		["e", "drum", 12, 2],
		["e", "archer", 11, 3],
	],
}
