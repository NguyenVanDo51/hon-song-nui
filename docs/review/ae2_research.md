# AE2 bản gốc — xác minh 5 luật (2026-11-06)

## Nguồn
- **Bản gốc**: `AE2-en.jar` (Macrospace, MIDlet-Version 1.0.2, class đề ngày 2005-06-03, sha256 `98f6af1d…50ba7f4`)
  https://github.com/ancient-empires/games-download/blob/main/Java/AE2-en.jar
  -> tự viết disassembler (javap mini, python) + giải nén `1.pak` -> đọc bytecode + `units.bin`, `tiles0.prop`, ảnh tile.
  Tên lớp bị làm rối: `c` = Unit, `i` = MainDisplayable, `e` = Renderer. Ghép tên theo mã RM (cùng cấu trúc, cùng hằng số).
  Trích dẫn dạng `c.class a()Z @pc N` = lớp / chữ ký hàm / offset bytecode.
- **Chữ trong game gốc**: `lang.txt` https://github.com/ancient-empires/Java-tools/blob/main/AE2lang/data/AE2/lang.txt
- **RM** (https://github.com/ProjectD8/Ancient-Empires-II-RM): chỉ 2 commit, cả hai 2021-10-10, đã là bản mod v2.5 -> **không có bản gốc trong lịch sử git**.
  enefry/AncientEmpiresII `reference/AEIIRM_SOURCE_COMPARISON.md` xác nhận mã RM = Fernflower decompile của jar RM 2.5, không phải bản gốc.
- Không dùng wiki/forum: bytecode bản gốc mạnh hơn mọi nguồn phụ. Không dùng AE Reloaded.
- Dữ liệu đơn vị gốc (`units.bin`) = y hệt `*.unit` của RM (12 loại, công/thủ/đi/tầm/giá/thuộc tính).

Ký hiệu thuộc tính đơn vị (bit `HasProperty`): 1 = bay (Wyvern/Rồng), 2 = nước (Elemental), 8 = chiếm làng (Lính, Vua), 16 = chiếm thành (Vua),
32 = gọi hồn (Pháp sư), 64 = +15 công vs bay (Cung), 128 = độc (Sói), 256 = hào quang (Wisp), 512 = công thành (Catapult).

Số dòng code ta dưới đây = lúc viết; agent khác đang sửa song song -> có thể lệch, tìm theo tên hàm.

---

## 1. Mua lính — **xác nhận bản gốc**

| Câu hỏi | Bản gốc | Bằng chứng |
|---|---|---|
| Lính mua xong đi + đánh ngay lượt đó? | **Có**. Lính mới `unitState=0`; mua xong vào ngay chế độ đi, **không huỷ được** (phải chọn ô đến ngay, không làm việc khác trước). Đứng yên trên thành trống được (ô đích = chính nó). Sau khi đi: menu có Tấn công (trừ Catapult: không đi + đánh). | `c.class <init> @pc 27–29` (state=0); `i.class` xác nhận mua `@pc 313–347`: `i.k=true` -> `b(Lc;)V` đặt `i.d = !i.k` (cờ cho huỷ = false); `a(Lc;B)[B @pc 123–134` (loại 7 = catapult không đánh sau đi) |
| Mua khi quân ta đứng trên thành? | **Có**. Quân ta chưa hành động -> menu của nó có "Mua" (mục 0). Quân ta đã hành động -> bấm vào ô mở thẳng cửa hàng. Lính mới đứng chồng, phải bước ra ô trống. | `i.class a(Lc;B)[B @pc 11–71` (ô loại 9 + thành của phe -> thêm mục 0); `@pc 4969–5127` (nhánh else-if loại 9 + `isBuildingOfFraction`) |
| Điều kiện mua | đủ vàng, chưa chạm trần quân (âm binh không tính), loại được phép, **và** từ thành có đường tới ≥1 ô trống trong tầm đi của loại đó (`fillMoveRangeDataEx(..., expand=true)`). | `i.class a(BII)Z`, `a(Lc;II)Z` |
| Nhiều lần / thành / lượt? | **Có**, không có bộ đếm theo thành. Chỉ bị chặn bởi vàng, trần quân, ô trống. Vì lính mới phải đi ngay -> không bao giờ quá 2 quân / ô. | như trên |
| Địch đứng trên thành ta? | **Có mua được** (đúng bản gốc, không phải lỗi mod). Ô có địch -> nhánh "quân ta chưa đi" sai -> rơi vào else-if "thành của phe" -> mở cửa hàng; `isBuildingOfFraction` chỉ xét chủ, không xét ai đứng. Lính mới chồng lên địch, phải bước ra. (Vua địch đứng đó thì thường đã chiếm thành -> hết là thành ta.) | `i.class @pc 4969–5127`; RM `MainDisplayable.java:6554` (chỉ so chủ) |

**Code ta**: `game.gd:488 buy_options` / `:514 buy` / `:170 reachable` (+ `stacked`), `rules.gd:59 buyAE2`.
- Khớp: đi + đánh ngay (`buy` -> `spawn(..., acted=false)`), mua khi quân ta trên thành (đã/chưa đi), chồng tối đa 2, phải bước ra, mua nhiều lần, cần ô trống (`_can_step_off`).
- **Lệch**: `game.gd:492–493` chặn mua khi **địch** đứng trên thành; comment "looks like a mod quirk" **sai** — bản gốc cho mua.
- Lệch nhỏ (UI): gốc bắt lính mới đi **ngay** (không huỷ); ta chỉ cấm hết lượt khi chưa bước ra (spec.md). Chấp nhận được.

## 2. KN / cấp — **xác nhận bản gốc** (RM khác 1 chỗ)

Công thức gốc (`c.class`):
- `quality = offMin + offMax + def` với chỉ số **đã cộng cấp** (`a()I`). `setRank(r)`: offMin/offMax/def = gốc + `r*2` (`a(B)V @pc 6–53`).
- Đòn đánh: `hit = (rand[min,max) + bonusCông − (def + bonusThủ)) × hp_người_đánh / 100`, kẹp 0..hp nạn nhân; **KN += quality(nạn nhân) × hit** (`c(Lc;)I @pc 0–96`). Không thưởng thêm khi giết.
- Cần lên cấp: `quality(bản thân) × 100 × 2 / 3` (chia nguyên) (`b()I`).
- `promote`: **chỉ khi rank < 9**; đủ KN -> trừ KN, +1 cấp, dư mang sang; mỗi lần gọi tối đa 1 cấp (`a()Z @pc 0–46`).
- Sau mỗi trận: gọi `promote` 1 lần cho người đánh (nếu còn sống) và 1 lần cho người bị đánh (nếu còn sống) (`i.class h()V @pc 4–46`, `@pc 186–204`). Cả hai đều nhận KN (đánh + phản đòn).
- Tên cấp đổi mỗi 2 cấp, tối đa 4 bậc (`a(B)V @pc 56–95`, lang 139 + loại×4 + min(rank/2,3)).
- Bonus cấp **có** vào cả 2 công thức (qua quality). Bonus tạm (địa hình, hào quang, độc, nước) **không** vào quality.

| Giả định của ta | Gốc |
|---|---|
| KN/đòn = dmg × (công min + max + thủ nạn nhân) | ✓ (tính cả cấp nạn nhân) |
| Cần = (min + max + thủ bản thân) × 200/3, dư mang sang | ✓ (tính cả cấp bản thân) |
| Max cấp 9 | ✓ gốc. **RM bỏ giới hạn** (`Unit.java:267 if(true) // rank < 9`) -> dùng RM ở chỗ này là sai |
| +2 công / +2 thủ mỗi cấp | ✓ (+2 cả công min lẫn max; không cộng bước đi) |
| ≤1 cấp / trận | ✓ |

**Code ta**: `game.gd:350 quality` (+`3×rankBonus×rank`), `:355 _gain_xp`, `:359 xp_need`, `:363 _promote`, `rules.gd:54`. **Khớp hết**.
- `int(quality × 200.0/3.0)` cho cùng kết quả với `q*200/3` nguyên (200/3 double làm tròn lên) — ok.
- Cần sửa comment `rules.gd:51–53` ("From the AE2 mod code, unconfirmed") -> đã xác nhận bản gốc; spec.md "Chưa xác nhận" bỏ mục KN.

## 3. Địa hình — **xác nhận bản gốc**

Bảng cứng trong `i.class <clinit> @pc 677–782` (bản gốc **không** đọc từ file; RM mới đọc `tiles0.prop` text):

| Loại | Tên | Thủ | Bước | Ô tile gốc (`tiles0.prop` trong 1.pak) |
|---|---|---|---|---|
| 0 | đường | 0 | 1 | 20–26, 28 (đống đá/tường đổ) |
| 1 | cỏ | 5 | 1 | 18 |
| 2 | rừng | 10 | 2 | 15–16 |
| 3 | đồi | 10 | 2 | 19, 33, 35, 36 (đá/đồi tuyết) |
| 4 | núi | 15 | 3 | 17 |
| 5 | nước | 0 | 3 | 0–14 |
| 6 | cầu | 5 | 1 | 29–30 |
| 7 | giếng / đền | 15 | 1 | 31 (giếng), 32 (đền), 34 (đài pha lê xanh) |
| 8 | làng | 15 | 1 | 37 (trung lập), 39/41/43/45 (theo phe), **27 = làng đổ** |
| 9 | thành | 15 | 1 | 38 (trung lập), 40/42/44/46 (theo phe) |

Ngoại lệ (`c.class a(IIBB)I` = getRequiredSteps, `a(Lc;II)I` / `b(Lc;II)I` = bonus công / thủ):
- Ô có **địch** = 1000 (chặn); quân **ta** đi xuyên được.
- **Bay** (Wyvern/Rồng): mọi ô 1 bước. **Vẫn nhận thủ địa hình** (hàm thủ không có ngoại lệ bay) -> núi +15, nước 0.
- **Elemental** (thuộc tính nước): ô nước 1 bước; đứng nước **+10 công** (ô người đánh) và **+15 thủ**.
- Mọi quân bộ lội nước được, 3 bước, thủ 0.
- Chỉ **Pha lê** (loại 11) cấm vào núi. **Golem, Catapult vào núi bình thường** (3 bước).
- Loại 7 (giếng/đền/đài): hồi +20 máu đầu lượt cho **mọi phe** đứng trên; làng/thành hồi cho phe chủ (`i.class @pc 1094–1179`, tối đa +20).
- Tile 34 (đài pha lê) thêm **+25 công, +15 thủ** cho bất kỳ ai đứng trên (`a(Lc;II)I @pc 73–88`, `b(Lc;II)I @pc 40–55`) — có lẽ chỉ dùng ở chiến dịch.
- Cung +15 công vs bay; Wisp +15 vs Skeleton; độc: −10 công −10 thủ, **không giảm bước đi** (`moveRangeBonus` luôn 0, `c.class b()V`); hào quang Wisp +10 công, tầm 1–2, áp khi Wisp kết thúc lượt đi (`d()V @pc 29–103`).
- Lang gốc: "mountains add defence points but reduce movement"; "Elementals have greater movement and stronger defence".

**Code ta**: `rules.gd:7–19 TERRAIN`, `game.gd:120 move_cost`, `:231 terrain_def`, `:242 _mods`, `:678` hồi máu.
- Khớp: mọi số thủ/bước (cỏ 5/1, rừng 10/2, đồi 10/2, núi 15/3, nước 0/3, cầu 5/1, đường 0/1, làng/thành/làng đổ/đền 15/1), bay 1 bước + nhận thủ địa hình, nước của boat, đền hồi mọi phe.
- Chưa có: tile 34 (+25/+15) — chỉ ghi nhận, không cần thêm. Không có "giếng" riêng (gộp vào `t`).
- spec.md "Chưa xác nhận": rồng nhận thủ địa hình, +15 cung vs bay, độc không giảm bước, hào quang 1–2 -> **đều xác nhận bản gốc**.

## 4. Mộ — **xác nhận bản gốc** (chữ "1 turn" và số 3 không mâu thuẫn)

- Chết -> `unitState=3` (mộ), `bộ đếm=3` (`i.class @pc 2806–2819`).
- Skeleton, Pha lê: xoá luôn, **không mộ**. Vua: dời ra (−10,−10), **không mộ trên bản đồ**, không đếm ngược (`@pc 2822–2891`).
- Đầu lượt **mỗi phe** (`i.class o()V @pc 77–139`, sau khi đổi phe): mộ (trừ vua) bộ đếm −1, ≤0 -> xoá. 2 phe: chết ở lượt A -> còn hết lượt A, cả lượt B, cả lượt A kế -> mất đầu lượt B kế = "1 lượt" (1 vòng) như lang: "a tombstone appears for 1 turn".
- **Kết thúc đi trên mộ -> mộ mất** (`c.class d()V @pc 5–28` = finishMove: tìm mộ ở ô đứng, xoá). Đi ngang qua không mất; mộ không chặn đường.
- Gọi hồn: Pháp sư đứng **kề** mộ (tầm 1) — lang: "Move a Sorceress next to a tombstone".

**Code ta**: `game.gd:372 _kill` (vua không mộ, `noGrave`), `:426–430` xoá mộ khi đi tới, `:630–638 end_turn` (ttl −1 đầu lượt mỗi phe), `rules.gd:50 graveRounds 3`. **Khớp**.

## 5. Hồi sinh tướng — **xác nhận bản gốc**

- Tướng chết: cùng 1 object, chỉ xoá hiệu ứng (độc/hào quang); **cấp + KN giữ nguyên**.
- Giá: khởi tạo = `UNIT_COST[vua]` = 200 (`c.class a(BBIIZ)Lc; @pc 52–57`); mỗi lần chết `if (cost < 1000) cost += 200` (`i.class @pc 2894–2931`) -> 200 -> **400** (mua lại lần 1) -> 600 -> 800 -> **1000 trần**.
- Mua lại (`i.class a(Lc;II)Lc;`): trừ vàng, `hp=100`, đặt vị trí ở thành, thêm lại vào danh sách — **không** gọi setRank/không xoá KN. Tướng chết đứng đầu danh sách mua. Vẫn xét trần quân + đủ vàng + ô trống.
- Lang: "The more times a Commander is defeated, the more expensive he is to resurrect."

**Code ta**: `game.gd:377 heroSaved {rank, xp}`, `:525` trả lại khi mua, `:532 hero_cost = min(1000, 200 + 200×số lần chết)`, `rules.gd:57`. **Khớp**.

---

## Cần sửa ở code ta
1. `game.gd:492–493 buy_options`: bỏ chặn khi **địch** đứng trên thành ta (bản gốc cho mua; lính mới chồng, phải bước ra). Sửa comment "mod quirk". Nếu giữ chặn -> ghi là lệch có chủ đích.
2. `rules.gd:51–53`: comment KN -> "đã xác nhận bản gốc AE2-en.jar"; spec.md mục "Chưa xác nhận" -> chuyển KN, thủ địa hình cho rồng, +15 cung, độc không giảm bước, hào quang 1–2, tướng giữ cấp sang "đã xác nhận".
3. (Tuỳ) tile 34 (+25 công/+15 thủ): không có ở ta — chỉ ghi nhận.

Phần còn lại (địa hình, KN/cấp, mộ, giá + cấp tướng hồi sinh, mua đi ngay, mua nhiều lần) khớp bản gốc.

---

## So sánh đầy đủ bản gốc vs ta (2026-11-07, 4 agent, cùng jar sha `98f6af1d…`)
Chi tiết + bằng chứng bytecode: `docs/review/ae2cmp/{units,economy,maps,combat}.md`.
- **Quân**: `units.bin` (12 loại) = `rules.gd UNITS` y hệt (giá, công, thủ, tầm, loại di chuyển; đi: ta lưu gốc − 1 từ 2026-11-08); mọi thưởng (chống bay +15, Wisp vs Skeleton +15, nước +10/+15, độc −10/−10, hào quang +10 tầm 1–2, cấp +2/+2/+2, tối đa cấp 9, vua 200 +200/lần chết tối đa 1000) khớp. Lính rẻ mà mạnh = có từ bản gốc (công / 100 vàng 34,7 vs cung 20,8). Lệch nhỏ: ghost cost 150 (gốc −1), thiếu Crystal (chỉ chiến dịch), hào quang ta tính cả khoảng cách 0.
- **Kinh tế**: làng 30, thành 50 (đầu lượt mình), hồi 20 trên làng / thành mình + đền mọi phe, trần quân không tính Skeleton, không có nguồn vàng khác -> khớp. **Lệch: đấu tự do gốc mặc định 500 vàng / trần 10** (chọn 500/1000/2000, 10/20/25); ta 300 / 15 (+ chế độ "dễ" nửa vàng = của ta).
- **Bản đồ**: 1v1 ta ít làng / người hơn ~21% (gốc cho sẵn 2 làng ở s0, s5), nhiều thành hơn (2 vs 1,5 / người); gốc 32–45% nước, không đền ở đấu tự do, mỗi bên chỉ vua đứng trên thành; ta 5–11% nước, 2 đền / bản đồ, tướng + 1 lính.
- **Chiến đấu**: công thức sát thương, phản đòn, độc (sau phản đòn), hào quang, KN / cấp, địa hình, mộ, máy bắn đá -> khớp. **Lệch lớn: tầm đi gốc = chỉ số − 1** (ô đến cần còn dư > 0 bước: `c.class a([[BIIIIBBZ)Z` lưu bước dư, lưới khởi tạo 0, ô đích kiểm `ifle` ở `i.class c()V @pc 4106`; AI gốc cũng dùng mv − 1). Ta dùng đủ mv (`game.gd` `_reach_all` `nc > mv`) -> mọi quân +1 bước (lính 5 thay vì 4: +49% ô tới được). Đã tự đọc lại bytecode xác nhận (2026-11-07); chưa thử trên máy giả lập. **Đã sửa 2026-11-08**: `rules.gd` `mv` = gốc − 1 (UI hiện số bước thật; gốc hiện số thô).
