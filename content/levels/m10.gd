extends RefCounted
## m10: Vịnh Bão. Format: docs/content.md

const DEF := {
	"id": "m10",
	"order": 100,
	"title": "Vịnh Bão",
	"lore": "Đế Quốc đốt làng dọc vịnh. Dựng lại làng, rồi hạ Vorn.",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "boat", "drum", "elephant"], "e": ["soldier", "archer", "boat", "elephant"] },
	"gold": { "p": 600, "e": 400 },
	"tier": "easy",
	"ai": "normal",
	"win": { "type": "hero" },
	"stars": { "turns": 16 },
	"quests": [{ "do": "repair" }],
	"map": {
		"rows": [
			".c.....~~~.....",
			".rrv...~~~rrrrv",
			"hfrrrrr===rhfff",
			"ffr....~~~rxrfh",
			"..xr...~~~..rfh",
			"...r...~~~..r.f",
			"..rvhf.~~~..r..",
			"..r.f..===..v..",
			"..r.f..~~~hfrrc",
			"f.v.hf.~~~fhf..",
		]
	},
	"owner": [[1, 0, "p"], [3, 1, "p"], [14, 8, "e"], [12, 7, "e"]],
	"units": [
		["p", "hero", 2, 1],
		["p", "soldier", 1, 1],
		["p", "archer", 0, 0],
		["p", "elephant", 2, 2],
		["p", "boat", 7, 1],
		["e", "hero", 13, 8, { "guard": true }],
		["e", "soldier", 12, 6],
		["e", "archer", 14, 7],
		["e", "boat", 9, 5],
		["e", "elephant", 13, 9],
	],
}
