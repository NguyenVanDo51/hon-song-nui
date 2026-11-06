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
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": [],
	"allowed": {
		"p": ["soldier", "archer", "drum", "elephant", "catapult"],
		"e": ["soldier", "archer", "drum", "elephant", "catapult"],
	},
	"gold": { "p": 900, "e": 350 },
	"win": { "type": "castles" },
	"map": {
		"rows": [
			"...........~~v..",
			".c.h.......~~rc.",
			".r.rrrvrrrr=rrr.",
			"hrrv.......~~.r.",
			".r..hff.t..~~.v.",
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
		["p", "drum", 3, 1],
		["e", "hero", 13, 1],
		["e", "elephant", 13, 2],
		["e", "archer", 14, 2, { "rank": 1 }],
		["e", "elephant", 15, 0, { "rank": 1 }],
		["e", "drum", 13, 9],
		["e", "soldier", 14, 9],
		["e", "catapult", 15, 10, { "guard": true }],
	],
	"story": {
		"intro": [
			["todinh", "Luy Lâu là trị sở Giao Chỉ! Quân triều đình còn đông, các ngươi đừng mơ!"],
			["trungtrac", "Các quận đã nổi lên theo ta. Còn mỗi Luy Lâu. Toàn quân, tiến!"],
			["trungnhi", "Thành giữa đồng bỏ trống. Ai chiếm trước, người đó giữ được thế."],
			["danlang", "Thợ làng đóng thêm máy bắn đá. Nay ở thành nào của ta cũng mua được."],
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
		"Trận cuối: Tướng giặc có 2 thành. Phải chiếm cả hai [b]và[/b] hạ hắn. Chiếm thành trống giữa bản đồ để tăng thu nhập.",
		"[b]Máy bắn đá[/b] nay mua được. Ném làng địch cho hỏng để giặc hụt vàng; lính hoặc tướng đứng trên làng hỏng bấm [b]Sửa làng[/b] để lấy lại.",
		"Phối hợp: voi đi đầu, trống đồng ở giữa, nỏ thủ và máy bắn đá phía sau. Đền giữa đồng hồi máu cho bất kỳ ai đứng đó.",
	],
}
