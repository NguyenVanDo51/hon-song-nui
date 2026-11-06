# Thêm nội dung

## Đổi tên / hình / màu
- `content/theme.gd`: tên game, lời dẫn, chữ trên giao diện (`text`), bản đồ chiến dịch (`chapter`: sông là đường SVG `M x,y C … S …` trong khung 100 × 70, hồ, nhãn), tên + icon lính mỗi phe, tướng (`side: "p"|"e"` quyết định phe nào dùng), người kể chuyện, màu phe, màu địa hình.
- Có ảnh thật: thêm `"img": "res://assets/…png"` vào lính / tướng / địa hình -> bàn cờ dùng ảnh thay emoji / hình vẽ code.
- Chỉ số, luật: `scripts/core/rules.gd` (không chứa tên).

## Chương
`content/chapters/cN.gd` (`DEF`): `id`, `order`, `title`, `years`, `subtitle`, `blurb` (tab chương), `note`, `rivers` / `lakes` / `labels` (bản đồ sơ đồ, khung 100 × 70, sông là đường SVG `M x,y C … S …`), `theme` (ghi đè lên `content/theme.gd` khi chơi chương này, ví dụ đổi tên + màu phe địch, chữ "Lượt quân …"), `outro` (thoại hiện khi thắng màn cuối chương). Chương sau mở khi đã thắng mọi màn trước nó.

## Bản đồ đấu tự do
`content/skirmish_maps.gd`: `name`, `blurb`, `rows`, `owner`, `units`, tùy chọn `chapter` (skin địch) và `enemyHero`. Nên vẽ đối xứng xoay 180° (test kiểm tra cho các bản đồ mới).

## Bố trí bản đồ
Theo lối bản đồ chiến thuật cổ điển: **đường mòn** (`r`) nối thành với làng thành một mạng liền, qua sông bằng cầu; rừng / đồi / núi gom thành **khối** (núi lõi, đồi quanh, rừng mép), khoảng 30% đất; chừa vòng trống quanh thành. Mọi quân lội được sông (3 bước, thủ 0) và lên được núi (3 bước), nên sông / núi là chỗ chậm chứ không phải tường. **Đền** (`t`): 1–2 ô giữa hai phe, không đặt dưới quân / thành / làng, không có chủ (không ghi vào `owner`); quân phe nào đứng đó cũng hồi máu, thủ +15. Bản đồ đấu tự do: đền đặt thành cặp đối xứng xoay 180°. Vẽ tay xong có thể cho `sim/mapgen.gd` sắp lại địa hình (giữ thành, làng, sông, cầu, chỗ quân đứng / tiếp viện / ô đích): chạy nó, rồi chép các dòng `MAP` vào file màn.

## Quân và chỉ huy
Hai phe dùng chung một bộ lính (`UNITS` trong `content/theme.gd`, chỉ khác màu). Khóa lính: `soldier` Bộ binh, `archer` Nỏ thủ, `boat` Thủy binh, `shaman` Thầy mo, `drum` Trống đồng, `wolf` Sói, `elephant` Voi chiến, `catapult` Máy bắn đá, `bird` Rồng, `ghost` Âm binh (chỉ do thầy mo gọi hồn, không mua được, không đưa vào `allowed`). Trọng số AI mua = `aiWeight` trong `Rules.UNITS` (thiếu -> `AI.DEFAULT_WEIGHT` 1.0, không crash; test vẫn đòi khai báo cho quân mua được). Chỉ có 2 tướng cho mọi chiến dịch: `anhhung` (Anh hùng, phe ta) và `tuonggiac` (Tướng giặc, phe địch). Hình và chỉ số không bao giờ đổi; chỉ lời thoại mở đầu đổi theo trận (tên người trong truyện như Trưng Trắc, Tô Định, Mã Viện nằm ở `people`). Nhân vật khác nói trong thoại khai báo ở `people` (thêm `"side": "e"` nếu là người phe địch). Lối chơi từng loại quân: `content/guide.gd`.

## Thêm loại quân
Luật + AI chỉ đọc dữ liệu (`scripts/core/rules.gd` `UNITS`), không còn danh sách tên quân trong code.
1. `rules.gd` `UNITS`: chỉ số bắt buộc (`cost atk atkMax def mv rmin rmax move`) + cờ tùy chọn: `capV`/`capC`, `antiAir`, `vsType {loại: +công}`, `aura N`, `poison N`, `waterAtk`/`waterDef`, `raise "loại"`, `siege`, `raze`, `noGrave`, `noCap`, `buyable: false`, `heavy` (hiệu ứng đòn nặng), `shot` (`arrow`/`rock`), `aiWeight` (AI mua), `aiValue` (AI định giá, mặc định = `cost`). Mua được -> thêm vào `BUY_ORDER`.
2. `content/theme.gd` `units.p` + `units.e`: tên, icon, `fig`; `content/guide.gd` `ROLE` / `PLAY` (thẻ ⓘ). Đặc tính tự sinh từ cờ (`Content.traits`).
3. Hình: `assets/units/styles/chibi/<loại>_p|e.svg`. Tùy chọn (thiếu thì dùng mặc định): rig đòn đánh `scripts/ui/rig/rigs.gd` + `specs/<loại>.gd`, nét chém `fx.gd` `_signature`, mô hình 3D `board3d.gd` `ROSTER`, âm thanh `audio.gd`.
4. Màn: `allowed` / `units` / `waves`; `sim/tests.gd` (bảng chỉ số = spec) + `docs/spec.md` bảng lính.

Trước (2026-11-06): thêm cả `AI.WEIGHTS` (thiếu = crash), danh sách quân nặng ở `fx.gd` / `rigs.gd`, `"ghost"` cứng trong `game.gd` (gọi hồn, +công vs âm binh), +10 hào quang / độc cứng, danh sách quân không mua được trong `menus.gd`, thưởng mua của AI theo tên quân.

## Thêm công trình / ô đất
Luật đọc mô tả trong `scripts/core/rules.gd` `TERRAIN`, không đọc ký tự ô (`Game.ter / income_of / sells / cap_flag / can_take / heals_at`).
1. `TERRAIN["<ký tự>"]`: `def`, `cost`, tùy chọn `water`; công trình thêm `building` (tên, có chủ), `income` (vàng/lượt), `cap` (cờ quân cần để chiếm: `capV` / `capC` / cờ mới), `heals` (`"owner"` | `"any"`), `sells` (mua lính ở đây; tính là thành cho luật thua), `razeTo` (máy bắn đá phá thành ô gì), `repairTo` + `repairBy` (ô hỏng: sửa thành gì, cờ quân sửa được).
2. `content/theme.gd` `terrain`: tên + màu; ghi chú ô `Content.tile_note` (tùy chọn).
3. Hình: `scripts/ui/board.gd` `_draw_building` / `_tile_art` + `assets/terrain/chibi/`; 3D `board3d.gd` (`TOP`, công trình).
4. Thu nhập = tổng `income` các ô đang giữ; thành = ô `sells` đang giữ (`Game.castle_tiles`).

Trước: `Game` / `AI` / UI so ký tự `v` / `c` / `x` / `t` ở ~15 chỗ, thu nhập = (ô sở hữu − thành) × 30 + thành × 50 trong `RULES`.

## Thêm màn chiến dịch
Tạo `content/campaign/mNN.gd` (game tự gom mọi file trong thư mục, xếp theo `order`; `"chapter": "c2"` gắn màn vào chương, mặc định c1):

```gdscript
extends RefCounted

const DEF := {
	"id": "m09", "order": 9,
	"title": "Tên màn", "place": "Địa danh",
	"region": "Tên vùng", "pos": [x, y],   # điểm trên bản đồ chiến dịch (khung 100 x 70)
	"history": "Một câu sử tích",         # hiện ở màn giới thiệu
	"hero": "anhhung",                    # luôn là anhhung
	"enemyHero": "tuonggiac",             # luôn là tuonggiac; null = địch không có tướng
	"newUnits": ["wolf"],                 # thẻ "Lính mới" ở màn giới thiệu (màn đầu tiên có loại lính đó)
	"allowed": { "p": [...], "e": [...] },  # lính được mua mỗi phe (soldier archer boat shaman drum wolf elephant catapult bird)
	"gold": { "p": 300, "e": 400 },       # vàng đầu trận (độ khó). Thu nhập: làng 30, thành 50 mỗi lượt
	"win": { "type": "castles" },         # castles (chiếm hết thành + hạ tướng địch) | rout | hero | survive (+ "turns") | reach (+ "at": [[x, y]], tùy chọn "turns")
	"unitCap": 15,                        # trần quân mỗi phe (mặc định Rules.RULES.unitCap; âm binh không tính)
	"night": false,                       # phủ màn đêm
	"map": { "rows": ["..f~..", ...] },   # . đồng  r đường mòn  f rừng  h đồi  m núi  ~ sông  = cầu  v làng  x làng hỏng  c thành  t đền
	"owner": [[x, y, "p"], ...],          # làng/thành có chủ lúc đầu
	"units": [["p", "hero", x, y], ["e", "soldier", x, y, { "guard": true, "hp": 70, "rank": 1 }], ...],
	"waves": [{ "turn": 3, "units": [["soldier", x, y], ...] }],   # địch kéo đến đầu lượt địch
	"story": { "intro": [["trungtrac", "thoại..."], ...], "outro": [...] },
	"tips": ["mẹo hiện trên dải hướng dẫn, [b]in đậm[/b]", ...],
}
```

Khóa đã bỏ (engine bỏ qua, đừng dùng lại): `incomeMul`, `graves` (lính ngã chỉ sinh ra khi có quân chết), `heroMustLive` (thua khi mất hết thành và tướng đã ngã, hoặc hết quân lẫn thành; tướng ngã thì mua lại ở thành).

## Nhịp ra quân mới (2026-11-06)
Theo cách AE2 gốc mở quân (m0–m7: màn không mua xen kẽ, quân mới thấy ở phe địch / kịch bản trước khi mua được):
- Mỗi loại 3 bước: **thấy** (phe địch, hoặc đặt sẵn) -> **cầm** (đặt sẵn cho ta, chưa có trong `allowed.p`) -> **mua** (màn sau).
- Không 2 màn ra mắt liền nhau; không ra quân mới ở màn khó (sim < ~75%) hay trận cuối chương.
- Thẻ giới thiệu bật theo quân trên bản đồ + `waves` + `allowed` (cả 2 phe), không theo `newUnits` -> dời màn ra mắt phải sửa cả 4 chỗ.

| Loại | Thấy | Cầm | Mua |
|---|---|---|---|
| Bộ binh, tướng | m01 | m01 | m02 |
| Nỏ thủ | m02 | m02 | m02 |
| Trống đồng | m03 | m03 | m04 |
| Voi chiến | m04 (địch) | m05 | m05 |
| Máy bắn đá | m07 | m07 | m08 |
| Thủy binh | m09 (địch) | m10 | m10 |
| Sói | m11 (địch) | m12 | m12 |
| Thầy mo + âm binh | m13 | m13 (đội cố định) | m14 |
| Rồng | m15 | m15 (1 con) | — (chỉ đấu tự do) |

Kiểm tra: `sim/tests.gd` (validator: hàng đều dài, quân đứng ô đi được, không chồng ô...) + `sim/sim.gd -- mission m09 20` (AI phía ta thắng bao nhiêu %, trung vị số lượt). Lệnh đầy đủ ở README.
