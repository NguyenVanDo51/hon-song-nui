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

## Thêm kiểu mục tiêu (win.type)
1. `scripts/core/objectives.gd` `TYPES`: 1 mục, mọi khóa tùy chọn (hàm static): `loss(s, side)` -> lý do thua | null (xét trước luật AE2 chung), `on_round(s)` -> `[phe thắng, lý do]` | null (đầu mỗi vòng), `ai_goals(s, u)` (ô AI nhắm thay đích thường), `ai_tile(s, u, x, y)` (điểm cộng AI khi đứng ô đó), `marks(s)` (ô cờ vàng trên bàn 2D + 3D), `bar_n(s)` (`{n}` trên thanh mục tiêu), `check(s)` (lỗi nội dung, test tự gọi).
2. `content/theme.gd`: `goals[type]` (`brief` dòng "Mục tiêu" cuối thoại mở màn, `bar` thanh trên), `ends[phe][lý do]`, `text.loseTip_<lý do>`.
3. Màn: `"win": { "type": "<type>", ... }`.

Trước: sửa 7 chỗ (`Game.loss_reason` + `end_turn`, `AI.goals_for` + `best_for_unit`, `board.gd` + `board3d.gd` vẽ ô đích, `game_screen._goal_line`, `Content.WIN_TYPES`, validator trong `sim/tests.gd`) + theme.

## Thêm màn chiến dịch
Tạo `content/campaign/mNN.gd` (game tự gom mọi file trong thư mục, xếp theo `order`; `"chapter": "c2"` gắn màn vào chương, mặc định c1):

```gdscript
extends RefCounted

const DEF := {
	"id": "m09", "order": 9,
	"title": "Tên màn", "place": "Địa danh",
	"region": "Tên vùng", "pos": [x, y],   # điểm trên bản đồ chiến dịch (khung 100 x 70)
	"history": "Một câu sử tích",         # dòng "Sử tích" đầu thoại mở màn
	"hero": "anhhung",                    # luôn là anhhung
	"enemyHero": "tuonggiac",             # luôn là tuonggiac; null = địch không có tướng
	"newUnits": ["wolf"],                 # ghi chú: màn ra mắt loại lính đó (thẻ giới thiệu quân tự bật theo quân trên bản đồ, xem dưới)
	"allowed": { "p": [...], "e": [...] },  # lính được mua mỗi phe (soldier archer boat shaman drum wolf elephant catapult bird)
	"gold": { "p": 300, "e": 400 },       # vàng đầu trận (độ khó). Thu nhập: làng 30, thành 50 mỗi lượt
	"win": { "type": "castles" },         # Objectives.TYPES: castles (chiếm hết thành + hạ tướng địch) | rout | hero | survive (+ "turns") | reach (+ "at": [[x, y]], tùy chọn "turns")
	"stars": { "turns": 12 },             # sao thứ 3: thắng trong ≤ N lượt; màn survive dùng { "lost": K } (mất ≤ K lính). Bắt buộc (test)
	"unitCap": 15,                        # trần quân mỗi phe (mặc định Rules.RULES.unitCap; âm binh không tính)
	"night": false,                       # phủ màn đêm
	"map": { "rows": ["..f~..", ...] },   # . đồng  r đường mòn  f rừng  h đồi  m núi  ~ sông  = cầu  v làng  x làng hỏng  c thành  t đền
	"owner": [[x, y, "p"], ...],          # làng/thành có chủ lúc đầu
	"units": [["p", "hero", x, y], ["e", "soldier", x, y, { "guard": true, "hp": 70, "rank": 1 }], ...],
	"waves": [{ "turn": 3, "units": [["soldier", x, y], ...] }],   # địch kéo đến đầu lượt địch
	"story": { "intro": [["trungtrac", "thoại..."], ...], "outro": [...] },
	"tips": ["mẹo, [b]in đậm[/b]", ...],   # hiện chưa hiện ở đâu (dải mẹo bỏ từ 3beb8aa)
}
```

**Thoại mở màn** (không còn màn giới thiệu): bấm màn trên bản đồ chiến dịch / "Màn tiếp" -> vào thẳng bản đồ, hiện thẻ tên màn (chương · màn, `title`, `place`), rồi thoại từng người một ở dải dưới (`scripts/ui/story_overlay.gd`):
- Thứ tự: `["sutich", history]` (nếu có) -> `story.intro` -> `["muctieu", goal brief]`. Người nói = khóa trong `heroes` / `people` của theme (`sutich`, `muctieu` cũng nằm ở `people`); `"side": "e"` -> khung xanh, chân dung bên phải.
- Chạm / Space / Enter: hiện hết câu, rồi câu sau · giữ chuột / Space hoặc nút **»» Tua**: tự chạy nhanh · **Bỏ qua** / Esc: vào trận. Sau đó: thẻ giới thiệu quân mới (nếu có), rồi chơi.
- Không chiếu lại khi "Đánh tiếp ván đang dở", "Đánh lại", "Chơi lại"; chơi lại màn đã thắng từ bản đồ thì có (bỏ qua được). Cờ `bot` / `nointro` tắt; cờ `story` bật lại (`mission=m03 story`).
- `story.outro` (+ `outro` của chương ở màn cuối chương) vẫn hiện trên thẻ kết thúc.

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

## Sao màn (2026-11-06)
- 3 sao / màn chiến dịch (`scripts/core/stars.gd`): thắng · tướng ta không ngã lần nào (`heroDeaths.p == 0`) · mốc riêng `stars` của màn: `turns` (thắng trong ≤ N lượt) hoặc `lost` (mất ≤ K lính; không tính tướng, âm binh; đếm ở `s.lost`).
- Lưu sao cao nhất mỗi màn (`Store.stars_of`, khóa `campaign_stars`); thua / đấu tự do / 1v1 không ghi. Thắng trước khi có sao -> 0 sao, chơi lại để lấy.
- Đặt mốc: lấy trung vị khi AI phe ta thắng: `bash tools/sim_many.sh "m01 … m16" 12 6` (cột `win: turns med …, lost med …`, kèm `stars 0-3 [..]` = số ván được 0/1/2/3 sao). Màn survive kết thúc lượt cố định -> dùng `lost`.
