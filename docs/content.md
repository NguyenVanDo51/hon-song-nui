# Thêm nội dung

## Đổi tên / hình / màu
- `content/theme.gd`: tên game, lời dẫn, chữ trên giao diện (`text`), tên + icon lính mỗi phe, tướng (`side: "p"|"e"` quyết định phe nào dùng), người kể chuyện, màu phe, màu địa hình.
- Có ảnh thật: thêm `"img": "res://assets/…png"` vào lính / tướng / địa hình -> bàn cờ dùng ảnh thay emoji / hình vẽ code.
- Chỉ số, luật: `scripts/core/rules.gd` (không chứa tên).

## Level (Thử thách)
Mỗi level = 1 file `content/levels/*.gd` (`DEF`), xếp theo `order`; số hiện cho người chơi = thứ tự trong danh sách. Mở khóa: mọi level tới level xa nhất đã thắng, + level kế (`Store.unlocked_index`). Màn chọn: `scripts/ui/level_select.gd` (20 ô / trang, màu theo `tier`, sao tốt nhất, khóa). Không chương (bỏ 2026-11-07).

## Bản đồ đấu tự do
`content/skirmish_maps.gd`: `name`, `blurb`, `rows`, `owner`, `units`, tùy chọn `enemyHero`. Nên vẽ đối xứng xoay 180° (test kiểm tra cho các bản đồ mới).

## Bố trí bản đồ
Theo lối bản đồ chiến thuật cổ điển: **đường mòn** (`r`) nối thành với làng thành một mạng liền, qua sông bằng cầu; rừng / đồi / núi gom thành **khối** (núi lõi, đồi quanh, rừng mép), khoảng 30% đất; chừa vòng trống quanh thành. Mọi quân lội được sông (3 bước, thủ 0) và lên được núi (3 bước), nên sông / núi là chỗ chậm chứ không phải tường. **Đền** (`t`): 1–2 ô giữa hai phe, không đặt dưới quân / thành / làng, không có chủ (không ghi vào `owner`); quân phe nào đứng đó cũng hồi máu, thủ +15. Bản đồ đấu tự do: đền đặt thành cặp đối xứng xoay 180°. Vẽ tay xong có thể cho `sim/mapgen.gd` sắp lại địa hình (giữ thành, làng, sông, cầu, chỗ quân đứng / tiếp viện / ô đích): chạy nó, rồi chép các dòng `MAP` vào file màn.

## Quân và chỉ huy
Hai phe dùng chung một bộ lính (`UNITS` trong `content/theme.gd`, chỉ khác màu). Khóa lính: `soldier` Bộ binh, `archer` Nỏ thủ, `boat` Thủy binh, `shaman` Thầy mo, `drum` Trống đồng, `wolf` Sói, `elephant` Voi chiến, `catapult` Máy bắn đá, `bird` Rồng, `ghost` Âm binh (chỉ do thầy mo gọi hồn, không mua được, không đưa vào `allowed`). Trọng số AI mua = `aiWeight` trong `Rules.UNITS` (thiếu -> `AI.DEFAULT_WEIGHT` 1.0, không crash; test vẫn đòi khai báo cho quân mua được). Chỉ có 2 tướng cho mọi chiến dịch: `anhhung` (Anh hùng, phe ta) và `tuonggiac` (Tướng giặc, phe địch). Hình và chỉ số không bao giờ đổi. Lối chơi từng loại quân: `content/guide.gd`.

## Thêm loại quân
Luật + AI chỉ đọc dữ liệu (`scripts/core/rules.gd` `UNITS`), không còn danh sách tên quân trong code.
1. `rules.gd` `UNITS`: chỉ số bắt buộc (`cost atk atkMax def mv rmin rmax move`) + cờ tùy chọn: `capV`/`capC`, `antiAir`, `vsType {loại: +công}`, `aura N`, `poison N`, `waterAtk`/`waterDef`, `raise "loại"`, `siege`, `raze`, `noGrave`, `noCap`, `buyable: false`, `heavy` (hiệu ứng đòn nặng), `shot` (`arrow`/`rock`), `aiWeight` (AI mua), `aiValue` (AI định giá, mặc định = `cost`). Mua được -> thêm vào `BUY_ORDER`.
2. `content/theme.gd` `units.p` + `units.e`: tên, icon, `fig`; `content/guide.gd` `ROLE` / `PLAY` (thẻ ⓘ). Đặc tính tự sinh từ cờ (`Content.traits`).
3. Hình: `assets/units/styles/chibi/<loại>_p|e.svg`. Tùy chọn (thiếu thì dùng mặc định): rig đòn đánh `scripts/ui/rig/rigs.gd` + `specs/<loại>.gd`, nét chém `fx.gd` `_signature`, âm thanh `audio.gd`.
4. Màn: `allowed` / `units` / `waves`; `sim/tests.gd` (bảng chỉ số = spec) + `docs/spec.md` bảng lính.

Trước (2026-11-06): thêm cả `AI.WEIGHTS` (thiếu = crash), danh sách quân nặng ở `fx.gd` / `rigs.gd`, `"ghost"` cứng trong `game.gd` (gọi hồn, +công vs âm binh), +10 hào quang / độc cứng, danh sách quân không mua được trong `menus.gd`, thưởng mua của AI theo tên quân.

## Thêm công trình / ô đất
Luật đọc mô tả trong `scripts/core/rules.gd` `TERRAIN`, không đọc ký tự ô (`Game.ter / income_of / sells / cap_flag / can_take / heals_at`).
1. `TERRAIN["<ký tự>"]`: `def`, `cost`, tùy chọn `water`; công trình thêm `building` (tên, có chủ), `income` (vàng/lượt), `cap` (cờ quân cần để chiếm: `capV` / `capC` / cờ mới), `heals` (`"owner"` | `"any"`), `sells` (mua lính ở đây; tính là thành cho luật thua), `razeTo` (máy bắn đá phá thành ô gì), `repairTo` + `repairBy` (ô hỏng: sửa thành gì, cờ quân sửa được).
2. `content/theme.gd` `terrain`: tên + màu; ghi chú ô `Content.tile_note` (tùy chọn).
3. Hình: `scripts/ui/board.gd` `_draw_building` / `_tile_art` + `assets/terrain/chibi/`.
4. Thu nhập = tổng `income` các ô đang giữ; thành = ô `sells` đang giữ (`Game.castle_tiles`).

Trước: `Game` / `AI` / UI so ký tự `v` / `c` / `x` / `t` ở ~15 chỗ, thu nhập = (ô sở hữu − thành) × 30 + thành × 50 trong `RULES`.

## Thêm kiểu mục tiêu (win.type)
1. `scripts/core/objectives.gd` `TYPES`: 1 mục, mọi khóa tùy chọn (hàm static): `loss(s, side)` -> lý do thua | null (xét trước luật AE2 chung), `on_round(s)` -> `[phe thắng, lý do]` | null (đầu mỗi vòng), `ai_goals(s, u)` (ô AI nhắm thay đích thường), `ai_tile(s, u, x, y)` (điểm cộng AI khi đứng ô đó), `marks(s)` (ô cờ vàng trên bàn 2D + 3D), `bar_n(s)` (`{n}` trên thanh mục tiêu), `check(s)` (lỗi nội dung, test tự gọi).
2. `content/theme.gd`: `goals[type]` (`brief` mô tả mục tiêu, `bar` thanh trên), `ends[phe][lý do]`, `text.loseTip_<lý do>`.
3. Màn: `"win": { "type": "<type>", ... }`.

Trước: sửa 7 chỗ (`Game.loss_reason` + `end_turn`, `AI.goals_for` + `best_for_unit`, `board.gd` + `board3d.gd` vẽ ô đích, `game_screen._goal_line`, `Content.WIN_TYPES`, validator trong `sim/tests.gd`) + theme.

## Thêm level
Tạo `content/levels/<id>.gd` (game tự gom mọi file trong thư mục, xếp theo `order`):

```gdscript
extends RefCounted

const DEF := {
	"id": "m09", "order": 9,
	"title": "Tên level",
	"hero": "anhhung",                    # luôn là anhhung
	"enemyHero": "tuonggiac",             # luôn là tuonggiac; null = địch không có tướng
	"newUnits": ["wolf"],                 # ghi chú: màn ra mắt loại lính đó (thẻ giới thiệu quân tự bật theo quân trên bản đồ, xem dưới)
	"allowed": { "p": [...], "e": [...] },  # lính được mua mỗi phe (soldier archer boat shaman drum wolf elephant catapult bird)
	"gold": { "p": 300, "e": 400 },       # vàng đầu trận (độ khó). Thu nhập: làng 30, thành 50 mỗi lượt
	"tier": "mid",                        # nhãn độ khó: easy (Dễ) | mid (Trung bình) | hard (Khó). m01–m16: tạm (m01–m04 easy, m14 hard, còn lại mid), đo lại bằng sim sau khi bot V2-hard xong
	"ai": "normal",                       # bot phe địch: normal | hard (không dùng easy). normal = không ghi ctrl vào state
	"win": { "type": "castles" },         # Objectives.TYPES: castles (chiếm hết thành + hạ tướng địch) | rout | hero | survive (+ "turns") | reach (+ "at": [[x, y]], tùy chọn "turns")
	"stars": { "turns": 12 },             # sao thứ 3: thắng trong ≤ N lượt; màn survive dùng { "lost": K } (mất ≤ K lính). Bắt buộc (test)
	"unitCap": 15,                        # trần quân mỗi phe (mặc định Rules.RULES.unitCap; âm binh không tính)
	"night": false,                       # phủ màn đêm
	"map": { "rows": ["..f~..", ...] },   # . đồng  r đường mòn  f rừng  h đồi  m núi  ~ sông  = cầu  v làng  x làng hỏng  c thành  t đền
	"owner": [[x, y, "p"], ...],          # làng/thành có chủ lúc đầu
	"units": [["p", "hero", x, y], ["e", "soldier", x, y, { "guard": true, "hp": 70, "rank": 1 }], ...],
	"waves": [{ "turn": 3, "units": [["soldier", x, y], ...] }],   # địch kéo đến đầu lượt địch
}
```

Vào màn: thẳng bàn cờ, rồi thẻ giới thiệu quân mới (nếu có). Không thoại / sử tích (bỏ 2026-11-07).

Khóa đã bỏ (engine bỏ qua, đừng dùng lại): `incomeMul`, `graves` (lính ngã chỉ sinh ra khi có quân chết), `heroMustLive` (thua khi mất hết thành và tướng đã ngã, hoặc hết quân lẫn thành; tướng ngã thì mua lại ở thành), `story`, `history`, `tips`, `chapter`, `region`, `pos`, `place` (bỏ cốt truyện + chương 2026-11-07).

## Nhịp ra quân mới (2026-11-06)
Theo cách AE2 gốc mở quân (m0–m7: màn không mua xen kẽ, quân mới thấy ở phe địch / kịch bản trước khi mua được):
- Mỗi loại 3 bước: **thấy** (phe địch, hoặc đặt sẵn) -> **cầm** (đặt sẵn cho ta, chưa có trong `allowed.p`) -> **mua** (màn sau).
- Không 2 màn ra mắt liền nhau; không ra quân mới ở màn khó (sim < ~75%) .
- Thẻ giới thiệu bật theo quân trên bản đồ + `waves` + `allowed` (cả 2 phe), không theo `newUnits` -> dời màn ra mắt phải sửa cả 4 chỗ.

Kiểm tra: `sim/tests.gd` (validator: hàng đều dài, quân đứng ô đi được, không chồng ô...) + `sim/sim.gd -- mission m09 20` (AI phía ta thắng bao nhiêu %, trung vị số lượt). Lệnh đầy đủ ở README.

## Nhịp ra mắt (Thử thách, 2026-11-07)
Thứ tự = `order`. Màn `mNN` = làm tay (giữ nhịp thấy -> cầm -> mua), `gNN` = vẽ bằng `sim/levelgen.gd` (luyện thứ vừa ra mắt, không thêm thứ mới). Nhãn độ khó đo lại bằng sim (cột "Khó"), xem HANDOFF.

| # | id | Tên | Khó | Bot | Thắng | Mới |
|---|---|---|---|---|---|---|
| 1 | m01 | Lời Thề Hát Môn | Dễ | normal | rout | bộ binh, tướng |
| 2 | m02 | Về Lại Mê Linh | Dễ | normal | castles | nỏ thủ (mua), chiếm thành |
| 3 | m03 | Giữ Làng Hạ Lôi | Dễ | normal | survive | trống đồng (cầm), giữ vững |
| 4 | m04 | Phá Đồn Cổ Loa | Dễ | normal | hero | trống (mua), voi (thấy), hạ tướng |
| 5 | g01 | Bến Đò | Dễ | normal | castles | — |
| 6 | m05 | Đêm Hồ Tây | TB | normal | castles | voi (mua), đêm |
| 7 | g02 | Đồi Sim | TB | normal | rout | — |
| 8 | m06 | Trận Bãi Sông | TB | normal | hero | — |
| 9 | g03 | Ngã Ba Sông | TB | normal | castles | — |
| 10 | g04 | Giữ Đồn | TB | normal | survive | — |
| 11 | m07 | Vây Thành Long Biên | TB | normal | castles | máy bắn đá (cầm) |
| 12 | g05 | Rừng Lim | TB | normal | hero | — |
| 13 | m08 | Trị Sở Luy Lâu | TB | normal | castles | máy bắn đá (mua) |
| 14 | g06 | Bãi Bồi | TB | normal | rout | — |
| 15 | m09 | Tin Dữ Hợp Phố | TB | normal | survive | thủy binh (thấy) |
| 16 | g07 | Cửa Sông | TB | normal | hero | — |
| 17 | m10 | Sóng An Biên | TB | normal | hero | thủy binh (mua), làng hỏng |
| 18 | g08 | Sông Đáy | TB | normal | castles | — |
| 19 | g09 | Làng Ven Đê | TB | normal | hero | — |
| 20 | m11 | Bát Nàn Giữ Ải | TB | normal | castles | sói (thấy) |
| 21 | g10 | Rừng Đêm | TB | normal | rout · đêm | — |
| 22 | m12 | Trận Lãng Bạc | TB | normal | castles | sói (mua) |
| 23 | g11 | Thành Đá | Khó | hard | castles | — |
| 24 | g12 | Bãi Lau | Dễ | normal | rout | — |
| 25 | m13 | Địu Con Phá Vây | TB | normal | reach | thầy mo + âm binh (cầm), tới ô đích |
| 26 | g13 | Miếu Cổ | TB | normal | castles | — |
| 27 | m14 | Rút Về Cấm Khê | Khó | normal | reach | thầy mo (mua) |
| 28 | g14 | Đầm Lầy | Dễ | normal | survive | — |
| 29 | g15 | Thành Mới | TB | normal | castles | — |
| 30 | m15 | Thành Cấm Khê | TB | normal | survive | rồng (1 con) |
| 31 | g16 | Núi Rồng | TB | normal | hero | — |
| 32 | m16 | Đêm Sông Hát | TB | normal | survive | — |
| 33 | g17 | Lũy Tre | Khó | hard | castles | — |
| 34 | g18 | Trăng Khuyết | TB | normal | rout · đêm | — |
| 35 | g19 | Giữ Thành | TB | normal | survive | — |
| 36 | g20 | Trận Cuối | Khó | hard | castles | — |

## Sao màn (2026-11-06)
- 3 sao / màn chiến dịch (`scripts/core/stars.gd`): thắng · tướng ta không ngã lần nào (`heroDeaths.p == 0`) · mốc riêng `stars` của màn: `turns` (thắng trong ≤ N lượt) hoặc `lost` (mất ≤ K lính; không tính tướng, âm binh; đếm ở `s.lost`).
- Lưu sao cao nhất mỗi màn (`Store.stars_of`, khóa `campaign_stars`); thua / đấu tự do / 1v1 không ghi. Thắng trước khi có sao -> 0 sao, chơi lại để lấy.
- Đặt mốc: lấy trung vị khi AI phe ta thắng: `bash tools/sim_many.sh "m01 … m16" 12 6` (cột `win: turns med …, lost med …`, kèm `stars 0-3 [..]` = số ván được 0/1/2/3 sao). Màn survive kết thúc lượt cố định -> dùng `lost`.
