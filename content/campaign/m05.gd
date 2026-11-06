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
	"newUnits": ["shaman"],
	"allowed": {
		"p": ["soldier", "archer", "drum", "elephant", "shaman"],
		"e": ["soldier", "archer", "drum", "elephant", "shaman"],
	},
	"gold": { "p": 600, "e": 150 },
	"win": { "type": "castles" },
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
		["p", "shaman", 2, 7],
		["p", "soldier", 1, 7],
		["p", "elephant", 3, 8],
		["e", "hero", 11, 1],
		["e", "soldier", 10, 2],
		["e", "soldier", 9, 3],
		["e", "shaman", 12, 2],
		["e", "archer", 11, 3],
	],
	"story": {
		"intro": [
			["lechan", "Đêm nay bãi ven hồ sẽ thành bãi chiến. Ai ngã xuống cũng chưa hết phần."],
			["danlang", "Thầy mo trong làng biết gọi hồn. Hồn người ngã đứng dậy, lại cầm giáo cho ta."],
			["hieuuy", "Đêm tối, đánh úp cho nhanh. Đừng để thầy mo của chúng kịp gọi hồn!"],
		],
		"outro": [["lechan", "Trời sáng rồi. Âm binh đã về yên nghỉ, Hồ Tây lại lặng sóng."]],
	},
	"tips": [
		"Trời tối: chỉ thấy rõ quanh quân ta và làng, thành của ta.",
		"Quân ngã để lại [b]lính ngã[/b]. [b]Thầy mo[/b] đứng cạnh rồi bấm [b]Gọi hồn[/b]: thêm một [b]âm binh[/b] miễn phí, lính ngã của giặc cũng gọi được.",
		"Lính ngã mất sau lượt kế của mỗi bên, hoặc khi có quân bước lên. Giữ thầy mo sau hàng lính, gần chỗ đang đánh. [b]Trống đồng[/b] đánh âm binh +15 công.",
	],
}
