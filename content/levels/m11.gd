extends RefCounted
## mission m11: Bát Nàn Giữ Ải. Format: docs/content.md

const DEF := {
	"id": "m11",
	"order": 110,
	"title": "Bát Nàn Giữ Ải",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": ["wolf"],
	"allowed": { "p": ["soldier", "archer", "drum", "elephant"], "e": ["soldier", "archer", "drum", "wolf", "elephant"] },
	"gold": { "p": 550, "e": 250 },
	"tier": "mid",
	"ai": "normal",
	"win": { "type": "castles" },
	"stars": { "turns": 10 },
	"map": {
		"rows": [
			"...hmmmmf.....",
			"..rrvrrrrrrrc.",
			"..r.........r.",
			"h.rh......vrrf",
			"m.rmm..f...rmm",
			"mrvmmmfhmmhrmm",
			"mr.hmmhtmmmxhm",
			".r..mmf.mf..fm",
			".crv.mmmmh...m",
			"...hmmmmhf..hm",
		]
	},
	"owner": [[1, 8, "p"], [3, 8, "p"], [12, 1, "e"], [10, 3, "e"]],
	"units": [
		["p", "hero", 2, 8],
		["p", "soldier", 1, 7],
		["p", "archer", 2, 7],
		["p", "drum", 3, 7],
		["p", "soldier", 4, 8],
		["e", "hero", 11, 1],
		["e", "soldier", 10, 2],
		["e", "archer", 12, 2, { "guard": true }],
		["e", "soldier", 9, 4],
		["e", "wolf", 11, 4],
	],
}
