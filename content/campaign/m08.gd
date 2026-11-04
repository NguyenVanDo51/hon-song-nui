extends RefCounted
## mission m08: Trị Sở Luy Lâu. Format: docs/content.md

const DEF := {
	"id": "m08",
	"order": 8,
	"title": "Trị Sở Luy Lâu",
	"place": "Luy Lâu · Thuận Thành, Bắc Ninh",
	"region": "Luy Lâu",
	"pos": [88, 45],
	"history": "Luy Lâu (Thuận Thành, Bắc Ninh), sát phía đông Hà Nội ngày nay, là trị sở quận Giao Chỉ thời Hán.",
	"hero": "trungtrac",
	"enemyHero": "todinh",
	"newUnits": [],
	"allowed": {
		"p": ["soldier", "archer", "drum", "shaman", "elephant", "bird", "catapult"],
		"e": ["soldier", "archer", "drum", "shaman", "elephant", "bird", "catapult"],
	},
	"gold": { "p": 900, "e": 300 },
	"incomeMul": { "e": 0.6 },
	"win": { "type": "castles" },
	"map": {
		"rows": [
			"...........~~v..",
			".c.h.......~~rc.",
			".r.rrrvrrrr=rrr.",
			"hrrv.......~~.r.",
			".r..hff....~~.v.",
			".vr.mhhf...=hfr.",
			"..r...mh..~~fhr.",
			".frrcrhf.~~..fr.",
			"fhv..rf..~~.vrr.",
			"mh...rhh=~~.f.r.",
			"hf...vmf~~fhm.c.",
			"......f.~~fhh...",
		],
	},
	"owner": [[1, 1, "p"], [14, 1, "e"], [14, 10, "e"]],
	"units": [
		["p", "hero", 2, 1],
		["p", "elephant", 1, 2],
		["p", "archer", 2, 2],
		["p", "catapult", 0, 3],
		["p", "bird", 3, 1],
		["e", "hero", 13, 1],
		["e", "elephant", 13, 2],
		["e", "archer", 14, 2, { "rank": 1 }],
		["e", "bird", 15, 0],
		["e", "shaman", 13, 9],
		["e", "soldier", 14, 9],
		["e", "catapult", 15, 10, { "guard": true }],
	],
	"story": {
		"intro": [
			["todinh", "Luy Lâu là trị sở Giao Chỉ! Quân triều đình còn đông, các ngươi đừng mơ!"],
			["trungtrac", "Các quận đã nổi lên theo ta. Còn mỗi Luy Lâu. Toàn quân, tiến!"],
			["trungnhi", "Thành giữa đồng bỏ trống. Ai chiếm trước, người đó giữ được thế."],
		],
		"outro": [
			[
				"truyenthuyet",
				"Tô Định bỏ thành, cắt tóc cạo râu trốn về Nam Hải. Hai Bà lấy lại 65 thành ở Lĩnh Nam.",
			],
			["trungtrac", "Đất này lại là của người Việt. Ta đóng đô ở Mê Linh."],
		],
	},
	"tips": [
		"Trận cuối: Tô Định có 2 thành, nhiều vàng hơn. Chiếm thành trống giữa bản đồ để tăng thu nhập.",
		"Phối hợp: voi đi đầu, trống đồng ở giữa, nỏ thủ và nỏ liên châu phía sau.",
	],
}
