extends RefCounted
## free-play maps (pick any hero). Built into a def by Content.skirmish_def(map_id, hero, easy).
## Optional per map: "chapter" (enemy skin / wording, default c1).
## New maps are 180° rotations of themselves so both sides start equal.

const MAPS := {
	"dong_bang": {
		"name": "Đồng bằng sông Cái",
		"blurb": "Đồng lúa, hai cây cầu, quân Đông Hán của Tô Định.",
		"rows": [
			"......hf......",
			"....ffmh....c.",
			"..c.hfhf...rv.",
			"..r.hmrvrrrrrh",
			"..rrhfrrrrrvrf",
			".~~=~~rr~~=~~.",
			"frvrrrrrfhrr..",
			"hrrrrrvrmh.r..",
			".vr...fhfh.c..",
			".c....hmff....",
			"......fh......",
		],
		"owner": [[1, 9, "p"], [12, 1, "e"]],
		"units": [["p", "hero", 2, 9], ["p", "soldier", 1, 8], ["e", "hero", 11, 1], ["e", "soldier", 12, 2]],
	},
	"cua_bien": {
		"name": "Cửa biển Lãng Bạc",
		"blurb": "Lạch nước chia cắt, cầu hẹp, đối đầu Mã Viện.",
		"chapter": "c2",
		"rows": [
			"~~~h.v.....rc.",
			"~~.f.rrrrrrvr.",
			"f=~~.r..~~=rff",
			"hf~~rc..~~.rhh",
			"fvrrr...~~.vrf",
			".r....==....r.",
			"frv.~~...rrrvf",
			"hhr.~~..cr~~fh",
			"ffr=~~..r.~~=f",
			".rvrrrrrr.f.~~",
			".cr.....v.h~~~",
		],
		"owner": [[1, 10, "p"], [12, 0, "e"]],
		"units": [["p", "hero", 2, 10], ["p", "soldier", 1, 9], ["e", "hero", 11, 0], ["e", "soldier", 12, 1]],
	},
	"nui_rung": {
		"name": "Núi rừng Cửu Chân",
		"blurb": "Đèo núi, rừng rậm, quân Đông Hán của Tô Định chặn ải.",
		"chapter": "c1",
		"rows": [
			"..........vrc.",
			".rrrvrrrrrr.h.",
			".r..r..fh.crhf",
			".vrrr.hmm.rrmm",
			".rrhfffhmfrvrf",
			".rrffmhhmffrr.",
			"frvrfmhfffhrr.",
			"mmrr.mmh.rrrv.",
			"fhrc.hf..r..r.",
			".h.rrrrrrvrrr.",
			".crv..........",
		],
		"owner": [[1, 10, "p"], [12, 0, "e"]],
		"units": [["p", "hero", 2, 10], ["p", "soldier", 1, 9], ["e", "hero", 11, 0], ["e", "soldier", 12, 1]],
	},
}
