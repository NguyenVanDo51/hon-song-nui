# Thêm nội dung

## Đổi tên / hình / màu
- `content/theme.gd`: tên game, lời dẫn, chữ trên giao diện (`text`), bản đồ chiến dịch (`chapter`: sông là đường SVG `M x,y C … S …` trong khung 100 × 70, hồ, nhãn), tên + icon lính mỗi phe, tướng (`side: "p"|"e"` quyết định phe nào dùng), người kể chuyện, màu phe, màu địa hình.
- Có ảnh thật: thêm `"img": "res://assets/…png"` vào lính / tướng / địa hình -> bàn cờ dùng ảnh thay emoji / hình vẽ code.
- Chỉ số, luật: `scripts/core/rules.gd` (không chứa tên).

## Thêm màn chiến dịch
Tạo `content/campaign/mNN.gd` (game tự gom mọi file trong thư mục, xếp theo `order`):

```gdscript
extends RefCounted

const DEF := {
	"id": "m09", "order": 9,
	"title": "Tên màn", "place": "Địa danh",
	"region": "Tên vùng", "pos": [x, y],   # điểm trên bản đồ chiến dịch (khung 100 x 70)
	"history": "Một câu sử tích",         # hiện ở màn giới thiệu
	"hero": "trungtrac",                  # key trong Rules.HEROES
	"enemyHero": "todinh",                # null = địch không có tướng
	"newUnits": ["bird"],                 # thẻ "Lính mới" ở màn giới thiệu
	"allowed": { "p": [...], "e": [...] },  # lính được mua mỗi phe
	"gold": { "p": 300, "e": 400 }, "incomeMul": { "e": 1.2 },   # độ khó
	"win": { "type": "castles" },         # castles | rout | hero | survive (+ "turns")
	"heroMustLive": false,                # true = tướng ta ngã là thua
	"unitCap": 15,                        # trần quân mỗi phe (mặc định Rules.RULES.unitCap)
	"night": false,                       # phủ màn đêm
	"map": { "rows": ["..f~..", ...] },   # . đồng  f rừng  h đồi  m núi  ~ sông  = cầu  v làng  c thành
	"owner": [[x, y, "p"], ...],          # làng/thành có chủ lúc đầu
	"units": [["p", "hero", x, y], ["e", "soldier", x, y, { "guard": true, "hp": 70, "rank": 1 }], ...],
	"graves": [[x, y]],
	"waves": [{ "turn": 3, "units": [["soldier", x, y], ...] }],   # địch kéo đến đầu lượt địch
	"story": { "intro": [["trungtrac", "thoại..."], ...], "outro": [...] },
	"tips": ["mẹo hiện trên dải hướng dẫn, [b]in đậm[/b]", ...],
}
```

Kiểm tra: `sim/tests.gd` (validator: hàng đều dài, quân đứng ô đi được, không chồng ô...) + `sim/sim.gd -- mission m09 20` (AI phía ta thắng bao nhiêu %, trung vị số lượt). Lệnh đầy đủ ở README.
