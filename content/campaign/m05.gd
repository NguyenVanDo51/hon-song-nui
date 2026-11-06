extends RefCounted
## mission m05: Đêm Hồ Tây. Format: docs/content.md

const DEF := {
	"id": "m05",
	"order": 5,
	"title": "Đêm Hồ Tây",
	"place": "Hồ Tây · Tây Hồ, Hà Nội",
	"region": "Tây Hồ",
	"pos": [45, 46],
	"history": "Một thuyết cho rằng hồ Lãng Bạc, nơi Hai Bà sau này đánh quân Mã Viện năm 42, chính là Hồ Tây.",
	"hero": "anhhung",
	"enemyHero": "tuonggiac",
	"newUnits": [],
	"allowed": { "p": ["soldier", "archer", "drum", "elephant"], "e": ["soldier", "archer", "drum", "elephant"] },
	"gold": { "p": 600, "e": 150 },
	"win": { "type": "castles" },
	"stars": { "turns": 10 },
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
	"story": {
		"intro": [
			["lechan", "Đêm nay bãi ven hồ sẽ thành bãi chiến. Tối trời, giặc không thấy ta, ta cũng không thấy giặc."],
			["lactuong", "Voi chiến bắt được ở Cổ Loa đã thuần, nay theo quân ta. Thợ làng còn dắt thêm voi rừng về."],
			["hieuuy", "Đêm tối, đánh úp cho nhanh. Đừng để chúng kịp dàn quân!"],
		],
		"outro": [["lechan", "Trời sáng rồi. Đồn giặc bên hồ đã về tay ta, Hồ Tây lại lặng sóng."]],
	},
	"tips": [
		"Trời tối: chỉ thấy rõ quanh quân ta và làng, thành của ta.",
		"Đi chậm, đi thành khối: quân đi lẻ vào chỗ tối dễ bị đánh úp. Chiếm làng trên đường để soi rõ thêm.",
		"[b]Voi chiến[/b] nay là của ta, mua được ở thành: thủ rất dày, đánh mạnh. Cho voi đi đầu hút đòn, [b]trống đồng[/b] đứng sau +10 công.",
	],
}
