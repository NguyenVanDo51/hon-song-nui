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
	"incomeMul": { "e": 0.8 },
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
	"graves": [[6, 5], [7, 5], [8, 3], [3, 6], [9, 4]],
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
			["lechan", "Bãi ven hồ còn ngổn ngang lính ngã từ trận trước. Nhiều người còn thở."],
			["danlang", "Thầy lang trong làng biết thuốc. Cứu được ai, người ấy lại cầm giáo."],
			["hieuuy", "Đêm tối, kỵ binh ta đánh úp. Đừng để chúng kịp cứu ai!"],
		],
		"outro": [["lechan", "Trời sáng rồi. Người bị thương đã được cứu về làng."]],
	},
	"tips": [
		"Trời tối: chỉ thấy rõ quanh quân ta và làng, thành của ta.",
		"[b]Thầy lang[/b] đứng cạnh [b]lính ngã[/b] rồi bấm [b]Cứu thương[/b]: thêm một thương binh miễn phí. Tên độc bỏ qua thủ địa hình.",
		"Lính ngã nằm lại 2 vòng. Phe nào cứu trước thì được.",
	],
}
