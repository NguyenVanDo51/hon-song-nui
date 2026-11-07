extends RefCounted
## mission m01: Lời Thề Hát Môn. Format: docs/content.md

const DEF := {
	"id": "m01",
	"order": 1,
	"title": "Lời Thề Hát Môn",
	"hero": "anhhung",
	"enemyHero": null,
	"newUnits": ["hero", "soldier"],
	"allowed": { "p": [], "e": [] },
	"gold": { "p": 0, "e": 0 },
	"tier": "easy",
	"ai": "normal",
	"win": { "type": "rout" },
	"stars": { "turns": 6 },
	"map": { "rows": ["......fff~~", ".rv...fhf.~", ".rrrrrrv..~", ".rfhf..r.~~", ".r.f...rh~~", "fv.....rf.~", "hf.....vf.~", ".......fh~~"] },
	"units": [
		["p", "hero", 1, 3],
		["p", "soldier", 1, 2],
		["p", "soldier", 2, 4],
		["e", "soldier", 7, 2, { "guard": true, "hp": 70 }],
		["e", "soldier", 8, 4, { "hp": 80 }],
		["e", "soldier", 7, 6, { "guard": true, "hp": 70 }],
		["e", "soldier", 6, 3, { "hp": 60 }],
	],
}
