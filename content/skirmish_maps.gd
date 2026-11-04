extends RefCounted
## free-play maps (pick any hero). Built into a def by Content.skirmish_def(map_id, hero, easy).
## Optional per map: "chapter" (enemy skin / wording, default c1), "enemyHero" (default: first enemy hero in the theme).
## New maps are 180° rotations of themselves so both sides start equal.

const MAPS := {
	"dong_bang": {
		"name": "Đồng bằng sông Cái",
		"blurb": "Đồng lúa, hai cây cầu, quân Đông Hán của Tô Định.",
		"rows": [
			"..hm...f....hm",
			".....h....f.c.",
			"..c.f...h...v.",
			"h..f...v..f..h",
			"......h..f.v..",
			"f~~=~~..~~=~~f",
			"..v.f..h......",
			"h..f..v...f..h",
			".v...h...f.c..",
			".c.f....h.....",
			"mh....f...mh..",
		],
		"owner": [[1, 9, "p"], [12, 1, "e"]],
		"units": [["p", "hero", 2, 9], ["p", "soldier", 1, 8], ["e", "hero", 11, 1], ["e", "soldier", 12, 2]],
	},
	"cua_bien": {
		"name": "Cửa biển Lãng Bạc",
		"blurb": "Lạch nước chia cắt, cầu hẹp, đối đầu Mã Viện.",
		"chapter": "c2", "enemyHero": "mavien",
		"rows": [
			"~~~..v...f..c.",
			"~~..f..h...v..",
			".=~~....~~=...",
			"..~~.c..~~...f",
			".v..h...~~.v..",
			"f.....==.....f",
			"..v.~~...h..v.",
			"f...~~..c.~~..",
			"...=~~....~~=.",
			"..v...h..f..~~",
			".c..f...v..~~~",
		],
		"owner": [[1, 10, "p"], [12, 0, "e"]],
		"units": [["p", "hero", 2, 10], ["p", "soldier", 1, 9], ["e", "hero", 11, 0], ["e", "soldier", 12, 1]],
	},
	"nui_rung": {
		"name": "Núi rừng Cửu Chân",
		"blurb": "Đèo núi, rừng rậm, quân Đông Ngô của Lục Dận.",
		"chapter": "c1", "enemyHero": "todinh",
		"rows": [
			"mmh.f..h..v.c.",
			"mh..v....f..h.",
			"...f..mm..c...",
			".v...f.mm..f..",
			"..h....f...v.h",
			"f..f..hh..f..f",
			"h.v...f....h..",
			"..f..mm.f...v.",
			"...c..mm..f...",
			".h..f....v..hm",
			".c.v..h..f.hmm",
		],
		"owner": [[1, 10, "p"], [12, 0, "e"]],
		"units": [["p", "hero", 2, 10], ["p", "soldier", 1, 9], ["e", "hero", 11, 0], ["e", "soldier", 12, 1]],
	},
}
