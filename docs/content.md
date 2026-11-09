# Thêm nội dung

## Đổi tên / hình / màu
- `content/theme.gd`: tên game, lời dẫn, chữ trên giao diện (`text`), tên + icon lính mỗi phe, tướng (`side: "p"|"e"` quyết định phe nào dùng), người kể chuyện, màu phe, màu địa hình.
- Có ảnh thật: thêm `"img": "res://assets/…png"` vào lính / tướng / địa hình -> bàn cờ dùng ảnh thay emoji / hình vẽ code.
- Chỉ số, luật: `scripts/core/rules.gd` (không chứa tên).

## Level (Thử thách)
Mỗi level = 1 file `content/levels/*.gd` (`DEF`), xếp theo `order`; số hiện cho người chơi = thứ tự trong danh sách. Mở khóa: mọi level tới level xa nhất đã thắng, + level kế (`Store.unlocked_index`). Màn chọn = bản đồ vương quốc (2026-11-08, user): `scripts/ui/world_map.gd`; vị trí từng màn + 5 vùng + sông / biển / núi ở `content/world_map.gd` (**thêm màn = thêm vị trí + vùng**, test đòi: trong bản đồ, cách nhau ≥ 8, đúng 1 vùng). Mỗi màn = 1 công trình: làng = Dễ / Trung bình, lâu đài = Khó (`tier`); mái xanh = đã thắng (đất xanh lại), mái đỏ rượu = quân Ma Vương (đất tím tro); chưa mở = mờ; cả vùng chưa mở = mây giông tím (ẩn); tháp Ma Vương sau Kinh Đô (`DEMON_TOWER`, trang trí, không phải level). Bối cảnh: `docs/setting.md`. Huy hiệu tròn góc dưới trái ghi số 2 chữ số; 3 sao nổi phía trên (vàng = đạt, nâu sẫm = chưa; màn chưa mở không có sao) — theo ảnh mẫu user 2026-11-09. 1 con đường lớn (Catmull-Rom qua mọi màn theo thứ tự), dải đất sáng + vạch đứt giữa, nhạt sau màn kế; cầu gỗ chỗ đường cắt sông. Cảnh: ảnh núi / rừng / đồi của bàn cờ bỏ nền cỏ (`WorldMap.strip_ground`), vị trí sinh sẵn trong `content/world_map.gd` (tránh lâu đài, đường, sông). Lúc mở: không thẻ, màn kế nhấp nháy; chạm công trình = thẻ giữa màn hình trên lớp tối (tên, `lore`, mục tiêu dạng `short`, sao), "Xuất quân" = vào trận; chạm ngoài thẻ = đóng. Chạm không bao giờ cuộn bản đồ. Kéo / lăn chuột để xem; dọc = phóng to theo chiều cao. Không chương (bỏ 2026-11-07).

## Bản đồ đấu tự do
`content/skirmish_maps.gd`: `name`, `blurb`, `rows`, `owner`, `units`, tùy chọn `enemyHero`. Mọi bản đối xứng xoay 180° (địa hình + chủ + quân; test kiểm tra). Mở đầu kiểu AE2: mỗi bên chỉ 1 tướng đứng trên thành mình. Tỉ lệ theo bản 2 người gốc AE2 (`docs/review/ae2cmp/maps.md`): 121–225 ô, ~3 thành / bản (0–2 trung lập), ~8–9 làng (làng / thành ≈ 3), không đền; địa hình ~32% nước, 10% núi, 15% rừng, 6% đồi, 8% cỏ, 20% đường. Bố cục tự vẽ, không chép bản gốc.

## Bố trí bản đồ
Theo lối bản đồ chiến thuật cổ điển: **đường mòn** (`r`) nối thành với làng thành một mạng liền, qua sông bằng cầu; rừng / đồi / núi gom thành **khối** (núi lõi, đồi quanh, rừng mép), khoảng 30% đất; chừa vòng trống quanh thành. Mọi quân lội được sông (3 bước, thủ 0) và lên được núi (3 bước), nên sông / núi là chỗ chậm chứ không phải tường. **Đền** (`t`): 1–2 ô giữa hai phe, không đặt dưới quân / thành / làng, không có chủ (không ghi vào `owner`); quân phe nào đứng đó cũng hồi máu, thủ +15. Bản đồ đấu tự do: không đền (như AE2). Vẽ tay xong có thể cho `sim/mapgen.gd` sắp lại địa hình (giữ thành, làng, sông, cầu, chỗ quân đứng / tiếp viện / ô đích): chạy nó, rồi chép các dòng `MAP` vào file màn.

## Quân và chỉ huy
Hai phe dùng chung một bộ lính (`UNITS` trong `content/theme.gd`, chỉ khác màu). Khóa lính (tên hiển thị sau reskin fantasy 2026-11-07): `soldier` Vệ binh, `archer` Cung thủ, `boat` Hải tặc, `shaman` Pháp sư gọi hồn, `drum` Tu sĩ ánh sáng, `wolf` Sói bóng đêm, `elephant` Golem đá, `catapult` Máy bắn đá, `bird` Rồng, `ghost` Bộ xương (chỉ do pháp sư gọi hồn dựng dậy, không mua được, không đưa vào `allowed`). Trọng số AI mua = `aiWeight` trong `Rules.UNITS` (thiếu -> `AI.DEFAULT_WEIGHT` 1.0, không crash; test vẫn đòi khai báo cho quân mua được). Chỉ có 2 tướng cho mọi chiến dịch: `anhhung` (Hiệp Sĩ Chỉ Huy, phe ta) và `tuonggiac` (Vorn, Hắc Hiệp Sĩ, phe địch; tên đổi 2026-11-08). Hình và chỉ số không bao giờ đổi. Lối chơi từng loại quân: `content/guide.gd`.

## Thêm loại quân
Luật + AI chỉ đọc dữ liệu (`scripts/core/rules.gd` `UNITS`), không còn danh sách tên quân trong code.
1. `rules.gd` `UNITS`: chỉ số bắt buộc (`cost atk atkMax def mv rmin rmax move`) + cờ tùy chọn: `capV`/`capC`, `antiAir`, `vsType {loại: +công}`, `aura N`, `poison N`, `waterAtk`/`waterDef`, `raise "loại"`, `siege`, `raze`, `noGrave`, `noCap`, `buyable: false`, `heavy` (hiệu ứng đòn nặng), `shot` (`arrow`/`rock`), `aiWeight` (AI mua), `aiValue` (AI định giá, mặc định = `cost`). Mua được -> thêm vào `BUY_ORDER`.
2. `content/theme.gd` `units.p` + `units.e`: tên, icon, `fig`; `content/guide.gd` `ROLE` / `PLAY` (thẻ ⓘ). Đặc tính tự sinh từ cờ (`Content.traits`).
3. Hình: vẽ trong `docs/anim_demo/<loại>.spec.js` (parts), rồi `node tools/rig_export.mjs --svg <loại>` sinh `assets/units/styles/chibi/<loại>_p|e.svg` (phe địch = đổi màu TEAM_SWAP) + `node tools/rig_export.mjs <loại>` sinh rig JSON. Tùy chọn (thiếu thì dùng mặc định): rig đòn đánh `scripts/ui/rig/rigs.gd` + `specs/<loại>.gd`, nét chém `fx.gd` `_signature`, âm thanh = tên âm có sẵn (`assets/sfx/s_<tên>*.wav`); âm mới: thêm công thức vào `tools/sfx/synth.mjs` rồi `node tools/sfx/synth.mjs`.
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
	"lore": "1 câu bối cảnh",            # tiền đề "Ngọn Lửa Lâu Đài": hiện trên thẻ màn ở bản đồ Thử thách; câu khiêu khích của Vorn = cùng khóa (`Vorn: «…»`)
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
	"quests": [{ "do": "capture", "what": "v" }, ...],   # nhiệm vụ tay (tuỳ chọn), verb = Quests.VERBS; + DEBUT của newUnits tự thêm
	"tutorial": [{ "card": "Mục tiêu", "say": "..." }, { "q": 0, "point": [x, y], "allow": [[x, y], "end_turn", "buy:soldier"], "say": "Chạm Tướng" }, ...],  # chỉ t01–t03
}
```

### Nhiệm vụ (`quests`, 2026-11-07)
- Mỗi mục `{ "do": verb, "what": loại quân | ký tự ô | null, "n": 1 }`; verb + điều kiện xong + "làm được không" ở `scripts/core/quests.gd` `VERBS`. Chữ từ `content/theme.gd` `text.quest_<verb>`.
- `Quests.for_level(def)` = `quests` + nhiệm vụ "lần đầu" (`content/guide.gd` `DEBUT`) của mỗi loại trong `newUnits` (màn có `tutorial`: không thêm DEBUT). Dòng thắng không tính.
- Thắng mà còn nhiệm vụ chưa xong -> −1 sao (sàn 1). Test: mọi nhiệm vụ của mọi màn `Quests.feasible == ""`.
- Có nhiệm vụ tay: m01–m04, m10 (+ t01–t03). Màn khác chỉ có DEBUT (nếu `newUnits`).
- **Sim cân bằng coi nhiệm vụ đã xong**: bot phe ta không cố làm nhiệm vụ -> mốc sao (`stars`) đo như cũ, không trừ sao nhiệm vụ.

### Hướng dẫn (`tutorial`, chỉ t01–t03; spec `docs/superpowers/specs/2026-11-08-tutorial-v2-design.md`)
- Mỗi bước: `q` = chỉ số trong `quests` (bước xong khi nhiệm vụ đó xong), `point` = ô `[x, y]` | `"end_turn"` | `"buy:<loại>"` (vòng sáng + tay chỉ), `allow` = ô / nút bấm được trong bước (phải chứa `point` và mọi ô cần bấm, vd ô quân + ô đích), `say` = 1 dòng ngắn (tuỳ chọn).
- Bước `card` = thẻ giải thích: `{ "card": tiêu đề, "say": 1–2 câu, "point": [x, y] | "end_turn" | không có (= giữa màn) }`. Bàn tối + vòng ở `point` (không tay), nút **▶ Đã hiểu** (Space / Enter); không `q` / `allow`. Bước nhiệm vụ: `say` dài tự xuống dòng (~360 px), `title` tuỳ chọn.
- Hết bước -> chơi tự do; màn có `nudgeEnd`: lượt ta mọi quân đã đi + 2,5 s không bấm gì -> tay + bong bóng chỉ Hết lượt (không tối, không khoá). Guide chờ banner lượt tắt rồi mới hiện.
- Nhiệm vụ sau bước cuối = làm trong chơi tự do (vd t02 `kill_with`). Thẻ có thể thêm `"also": [[x, y]]` = ô sáng thêm (không vòng), vd t01 "Quân đã đi": tướng xám cạnh vệ binh sáng.
- Thẻ giới thiệu quân **không** hiện ở màn có `tutorial` (user 2026-11-08): bắt đầu từ m01 (danh sách "đã gặp" vẫn trống sau t01–t03).
- `"nudgeEnd": true` = bật nhắc Hết lượt; chỉ t01 + t02 (user 2026-11-08: "nhắc lượt ở 2 màn hướng dẫn đầu tiên"; test).
- Thắng `rout`: dòng mục tiêu đếm cả quân địch chưa tới (`waves` chưa ra) -> t01 lượt 1 hiện "còn 2", không "còn 0".
- Test (`sim/tests/quests.gd` `quest_content_tests`): bước hợp lệ (card / `point` ∈ `allow` / `q` tăng dần), mở bằng thẻ mục tiêu + kết bằng thẻ "Tự chỉ huy", chỉ tướng + vệ binh, địch không mua; đi hết bước trên bản đồ thật rồi bot chơi phe ta tới thắng (8 seed / màn). UI: `sim/tut_driver.gd -- mission=t0N fresh` (click thật từng bước, ảnh `shots=`).
- t01: không làng / thành; địch tới bằng `waves` lượt 1 (A (7,3) 80 máu, B (8,1) 60): Tướng 45–55 + Vệ binh 40–45 luôn hạ A -> bài "dồn quân". t02: lâu đài trống giữa bản đồ (chỉ tướng chiếm; thủ +15, hồi 20), 3 vệ binh địch tự tới (không chiếm được lâu đài), thắng rout. Bản đầu (lính gác trên lâu đài địch, thắng castles) bỏ: bot luôn đưa lính gác ra khỏi lâu đài lượt 2 -> chiếm không cần đánh. t03: lâu đài + làng ta, mua được ngay (AE2), lính 40 máu về làng hồi; địch: 1 gác + `waves` lượt 1 (2 vệ binh cạnh lâu đài địch), 2 làng phía đông của địch (không có làng trống làm mồi kéo lính gác đi). Test: đi theo hướng dẫn thì không thắng trước lượt 4.

Vào màn: thẳng bàn cờ, rồi thẻ giới thiệu quân mới (nếu có). Không thoại / sử tích (bỏ 2026-11-07).

## Bối cảnh -> `docs/setting.md`
- Phe, tên, màu, tướng, `lede`, `lore`: xem `docs/setting.md` (nguồn duy nhất).
- Chữ trong level (`title`, `lore`, nhiệm vụ, hướng dẫn) viết tiếng Việt; bản dịch ở `locale/*.po` (`docs/i18n.md`): sửa / thêm chữ -> `python3 tools/i18n_extract.py` rồi dịch dòng mới.
- Bản đồ Thử thách: trên cùng chỉ nút "‹ Trở lại" (bỏ tiêu đề + đếm "🔥 N/39", user 2026-11-08).
- Tên màn: giả tưởng chung, không địa danh / sử Việt. Màn g*: sửa cả `sim/level_recipes.gd` (`title` + `lore`).

Khóa đã bỏ (engine bỏ qua, đừng dùng lại): `incomeMul`, `graves` (lính ngã chỉ sinh ra khi có quân chết), `heroMustLive` (thua khi mất hết thành và tướng đã ngã, hoặc hết quân lẫn thành; tướng ngã thì mua lại ở thành), `story`, `history`, `tips`, `chapter`, `region`, `pos`, `place` (bỏ cốt truyện + chương 2026-11-07).

## Nhịp ra quân mới (2026-11-06)
Theo cách AE2 gốc mở quân (m0–m7: màn không mua xen kẽ, quân mới thấy ở phe địch / kịch bản trước khi mua được):
- Mỗi loại 3 bước: **thấy** (phe địch, hoặc đặt sẵn) -> **cầm** (đặt sẵn cho ta, chưa có trong `allowed.p`) -> **mua** (màn sau).
- Không 2 màn ra mắt liền nhau; không ra quân mới ở màn khó (sim < ~75%) .
- Thẻ giới thiệu bật theo quân trên bản đồ + `waves` + `allowed` (cả 2 phe), không theo `newUnits` -> dời màn ra mắt phải sửa cả 4 chỗ.

Kiểm tra: `sim/tests.gd` (validator: hàng đều dài, quân đứng ô đi được, không chồng ô...) + `sim/sim.gd -- mission m09 20` (AI phía ta thắng bao nhiêu %, trung vị số lượt). Lệnh đầy đủ ở README.

## Nhịp ra mắt (Thử thách, 2026-11-07)
Thứ tự = `order`. Màn `mNN` = làm tay (giữ nhịp thấy -> cầm -> mua), `gNN` = vẽ bằng `sim/levelgen.gd` (luyện thứ vừa ra mắt, không thêm thứ mới). Cột "Khó" = đo bằng sim 2026-11-07 (bot phe ta thắng ≥ 10/12 Dễ · 7–9 TB · 4–6 Khó, 12 ván), xem HANDOFF.

| # | id | Tên | Khó | Bot | Thắng | Mới |
|---|---|---|---|---|---|---|
| 1 | t01 | Bài Học Đầu | Dễ | normal | rout | tướng + vệ binh; hướng dẫn: mục tiêu, chọn + đi quân, quân xám, hết lượt, địch tới, đánh, đánh trả, dồn quân |
| 2 | t02 | Lâu Đài Trống | Dễ | normal | rout | hướng dẫn: tướng chiếm lâu đài (thủ + hồi máu), rừng thủ, giữ chỗ cao, hạ hết địch |
| 3 | t03 | Chiêu Binh | Dễ | normal | castles | vệ binh (mua); hướng dẫn: lâu đài mua quân, làng (vàng + hồi máu), hết lượt sớm |
| 4 | m01 | Lời Thề Bên Tro Tàn | Dễ | normal | rout | — (bộ binh, tướng ra mắt ở t01–t03) |
| 5 | m02 | Ngọn Lửa Đầu Tiên | Dễ | normal | castles | nỏ thủ (mua), chiếm thành |
| 6 | m03 | Giữ Làng Biên Giới | Dễ | normal | survive | trống đồng (cầm), giữ vững |
| 7 | m04 | Đồn Gác Phương Bắc | TB | normal | hero | trống (mua), voi (thấy), hạ tướng |
| 8 | g01 | Bến Phà Cũ | TB | normal | castles | — |
| 9 | m05 | Đêm Hồ Gương | Dễ | normal | castles | voi (mua), đêm |
| 10 | g02 | Đồi Gió | Dễ | normal | rout | — |
| 11 | m06 | Bãi Sông Xám | Dễ | normal | hero | — |
| 12 | g03 | Ngã Ba Sông | Khó | normal | castles | — |
| 13 | g04 | Giữ Đồn | Dễ | normal | survive | — |
| 14 | m07 | Vây Lâu Đài Đá Trắng | Dễ | normal | castles | máy bắn đá (cầm) |
| 15 | g05 | Rừng Sồi Già | TB | normal | hero | — |
| 16 | m08 | Phủ Thành Đế Quốc | Dễ | normal | castles | máy bắn đá (mua) |
| 17 | g06 | Bãi Cát Giữa Sông | TB | normal | rout | — |
| 18 | m09 | Tin Dữ Từ Biển | Dễ | normal | survive | thủy binh (thấy) |
| 19 | g07 | Cửa Sông | TB | normal | hero | — |
| 20 | m10 | Vịnh Bão | Dễ | normal | hero | thủy binh (mua), làng hỏng |
| 21 | g08 | Sông Bạc | TB | normal | castles | — |
| 22 | g09 | Làng Cối Xay | TB | normal | hero | — |
| 23 | m11 | Ải Sói | Dễ | normal | castles | sói (thấy) |
| 24 | g10 | Rừng Đêm | Dễ | normal | rout · đêm | — |
| 25 | m12 | Hồ Sương Mù | Dễ | normal | castles | sói (mua) |
| 26 | g11 | Thành Đá | Khó | hard | castles | — |
| 27 | g12 | Bãi Sậy | Dễ | normal | rout | — |
| 28 | m13 | Phá Vòng Vây | Dễ | normal | reach | thầy mo + âm binh (cầm), tới ô đích |
| 29 | g13 | Đền Cổ | Dễ | normal | castles | — |
| 30 | m14 | Rút Lên Núi | Dễ | normal | reach | thầy mo (mua) |
| 31 | g14 | Đầm Lầy | Dễ | normal | survive | — |
| 32 | g15 | Thành Mới Xây | Dễ | normal | castles | — |
| 33 | m15 | Pháo Đài Trên Núi | Dễ | normal | survive | rồng (1 con) |
| 34 | g16 | Núi Rồng | Dễ | normal | hero | — |
| 35 | m16 | Đêm Dài Nhất | TB | normal | survive | — |
| 36 | g17 | Tường Gai | Khó | hard | castles | — |
| 37 | g18 | Trăng Khuyết | Dễ | normal | rout · đêm | — |
| 38 | g19 | Cổng Kinh Đô | Dễ | normal | survive | — |
| 39 | g20 | Ngọn Lửa Kinh Đô | Khó | hard | castles | — |

## Sao màn (2026-11-06)
- 3 sao / màn chiến dịch (`scripts/core/stars.gd`): thắng · tướng ta không ngã lần nào (`heroDeaths.p == 0`) · mốc riêng `stars` của màn: `turns` (thắng trong ≤ N lượt) hoặc `lost` (mất ≤ K lính; không tính tướng, âm binh; đếm ở `s.lost`).
- Lưu sao cao nhất mỗi màn (`Store.stars_of`, khóa `campaign_stars`); thua / đấu tự do / 1v1 không ghi. Thắng trước khi có sao -> 0 sao, chơi lại để lấy.
- Đặt mốc: lấy trung vị khi AI phe ta thắng: `bash tools/sim_many.sh "m01 … m16" 12 6` (cột `win: turns med …, lost med …`, kèm `stars 0-3 [..]` = số ván được 0/1/2/3 sao). Màn survive kết thúc lượt cố định -> dùng `lost`.
