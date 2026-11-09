extends RefCounted
## m12: Hồ Sương Mù. Format: docs/content.md

const DEF := {
	"id": "m12",
	"order": 120,
	"title": "Hồ Sương Mù",
	"lore": "Vorn: «Mỗi lâu đài ngươi lấy lại, Ma Vương ban cho ta mười đạo quân.»",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": [],
	"allowed": {
		"p": ["soldier", "archer", "boat", "drum", "wolf", "elephant", "catapult"],
		"e": ["soldier", "archer", "boat", "drum", "wolf", "elephant", "catapult"],
	},
	"gold": { "p": 1300, "e": 300 },
	"tier": "easy",
	"ai": "normal",
	"win": { "type": "castles" },
	"stars": { "turns": 17 },
	"map": {
		"rows": [
			"ffhfffhhf....c..",
			"hvrrrrrrrxrrrrv.",
			"f.rfh.fffhh.r...",
			"..rfh~~~~hh.r...",
			"..vr~~~~~~f.c...",
			"...r~~~~~~~.rv..",
			"..rc.~~~~~fffr..",
			"..r...~~~..hhr..",
			".vr......t.fhx..",
			"..c.........f...",
			"..rrrrrv........",
		]
	},
	"owner": [[2, 9, "p"], [1, 8, "p"], [7, 10, "p"], [13, 0, "e"], [12, 4, "e"], [14, 1, "e"], [13, 5, "e"]],
	"units": [
		["p", "hero", 3, 9],
		["p", "wolf", 2, 8],
		["p", "archer", 1, 9],
		["p", "soldier", 4, 9],
		["p", "drum", 3, 8],
		["p", "elephant", 2, 10],
		["e", "hero", 12, 3],
		["e", "soldier", 11, 4],
		["e", "soldier", 13, 4],
		["e", "archer", 12, 5],
		["e", "elephant", 11, 2],
		["e", "archer", 13, 1],
		["e", "wolf", 14, 2],
		["e", "soldier", 12, 1],
	],
}
