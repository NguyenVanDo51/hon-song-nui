extends RefCounted
## free-play maps (pick any hero). Built into a def by Campaign.skirmish_def(map_id, hero, easy)

const MAPS := {
	"dong_bang": {
		"name": "Đồng bằng sông Cái",
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
}
