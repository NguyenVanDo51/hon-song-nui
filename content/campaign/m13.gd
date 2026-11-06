extends RefCounted
# prose / map rows: one line each reads better
# gdlint: disable=max-line-length
## mission m13: Phùng Thị Chính. Format: docs/content.md

const DEF := {
	"id": "m13", "order": 13, "chapter": "c2",
	"title": "Địu Con Phá Vây",
	"place": "Lãng Bạc · Bắc Ninh",
	"region": "Phá vây", "pos": [64, 46],
	"history": "Tương truyền nữ tướng Phùng Thị Chính sinh con ngay giữa trận Lãng Bạc, rồi địu con sau lưng, cầm gươm mở đường thoát vây.",
	"hero": "anhhung", "enemyHero": null,
	"newUnits": ["shaman"],
	"allowed": { "p": [], "e": [] },
	"gold": { "p": 0, "e": 0 },
	"win": { "type": "reach", "at": [[12, 1]], "turns": 16 },
	"map": { "rows": [
		"f....f.....fhf",
		"....hm....f.v.",
		"....fh......r.",
		"........f...r.",
		".fhff...mhfhr.",
		".hhfm...f..hr.",
		".fmhh.f.....r.",
		"..fmf.hf....r.",
		".vrrrrrrrrrrr.",
		"......h.......",
	] },
	"owner": [[12, 1, "p"]],
	"units": [
		["p", "hero", 1, 8], ["p", "soldier", 2, 8], ["p", "archer", 0, 8], ["p", "elephant", 1, 9], ["p", "soldier", 0, 7], ["p", "shaman", 1, 7],
		["e", "soldier", 5, 4], ["e", "soldier", 11, 5, { "hp": 80 }], ["e", "archer", 10, 1],
		["e", "elephant", 10, 6], ["e", "soldier", 11, 1, { "guard": true, "hp": 70 }], ["e", "archer", 13, 2, { "guard": true, "hp": 70 }],
	],
	"waves": [
		{ "turn": 3, "units": [["soldier", 0, 5]] },
		{ "turn": 5, "units": [["wolf", 0, 2], ["soldier", 5, 9]] },
		{ "turn": 9, "units": [["soldier", 0, 0], ["archer", 6, 9]] },
	],
	"story": {
		"intro": [
			["truyenthuyet", "Giữa trận Lãng Bạc, nữ tướng Phùng Thị Chính trở dạ. Bà sinh con ngay trên chiến địa."],
			["phungthichinh", "Con ơi, bám chặt lưng mẹ. Mẹ đưa con về chỗ quân ta."],
			["danlang", "Làng phía đông bắc còn nghĩa quân giữ! Chạy về đó là thoát!"],
			["danlang", "Thầy mo làng tôi đi cùng. Ai ngã xuống, thầy gọi hồn dậy đánh tiếp."],
		],
		"outro": [["phungthichinh", "Mẹ con ta đã về tới làng. Con trai ta sinh ra giữa trận, lớn lên sẽ không biết sợ."]],
	},
	"tips": [
		"Mục tiêu: đưa [b]Anh hùng[/b] tới [b]ô cờ vàng[/b] (làng góc đông bắc) trong 16 lượt, mở đường cho Phùng Thị Chính. Không cần diệt địch.",
		"Bà ngã là hết đường thoát: không có thành để gọi bà về. Cho voi và lính đi trước hút đòn, bà đi sau.",
		"Quân ngã để lại [b]lính ngã[/b]. [b]Thầy mo[/b] đứng cạnh rồi bấm [b]Gọi hồn[/b]: thêm một [b]âm binh[/b] miễn phí (lính ngã của giặc cũng gọi được). Không có thành để mua lính: âm binh là quân thêm duy nhất.",
		"Rừng, đồi +10 thủ. Giặc từ phía sau đuổi tới ở lượt 3, 5, 9; lượt 5 có sói chạy rất nhanh.",
	],
}
