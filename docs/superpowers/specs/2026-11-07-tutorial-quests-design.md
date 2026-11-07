# Hướng dẫn cầm tay + Nhiệm vụ + Popup quân bằng cảnh diễn — thiết kế

Ngày: 2026-11-07. Nhánh `feat/tutorial-quests` (từ master 28e2920). Trạng thái: user duyệt hướng đi trong chat ("ok làm đi").
Ký hiệu: **(user)** = người dùng quyết · **(Claude)** = Claude tự quyết, user xem lại được.
Mockup (local, không commit): `.superpowers/brainstorm/84976-1794038226/content/` — `guided-step.html`, `quest-display.html`, `unit-intro.html`.

## 1. Ý định
- Người mới vào game phải hiểu: vùng xanh = vùng đi, mục tiêu thắng, lợi thế địa hình, cách mua quân, làng cho vàng + hồi máu… **qua làm và xem, không qua đọc**. (user)
- Bỏ phần lớn chữ. Giới thiệu quân = **cảnh diễn** (đi, đánh, hiệu ứng), không phải thẻ chữ. Ví dụ cung thủ đi + bắn địch; sói cắn -> hiện mác giảm chỉ số. (user)
- Mỗi màn có **nhiệm vụ**; xong cái nào có hiệu ứng -> vui hơn. Màn đầu nhiệm vụ rất dễ (đi tướng, chiếm thành, đánh lần đầu, mua quân, đứng thành hồi máu, sửa làng…). (user)
- Sau này user sẽ thêm loại quân / địa hình mới -> nhiệm vụ "lần đầu" phải **gắn vào loại quân / địa hình**, không viết tay từng màn. (user)

## 2. Mục tiêu
1. **2 màn hướng dẫn** (Claude: chia 2 cho đỡ dài; user: "cân nhắc 1 màn chuyên") đặt trước m01, mỗi bước **khoá chỉ cho làm đúng 1 việc**, gợi ý = tối phần còn lại + vòng sáng + bàn tay chỉ + **1 dòng chữ ngắn**. (user: step-by-step, chỉ click được tướng, kèm note; tối + vòng + tay = Claude)
2. **Hệ nhiệm vụ ở mọi màn**: danh sách nhiệm vụ, dòng cuối in đậm = mục tiêu thắng. (user)
3. **Nhiệm vụ "lần đầu"** tự sinh từ loại quân / địa hình mà màn đó đem ra lần đầu. (user)
4. **Thắng mà còn nhiệm vụ chưa xong -> vẫn thắng, mất sao.** (user: "cho thắng nhưng mất sao. chốt")
5. **Popup giới thiệu quân = cảnh diễn**, bật đúng lúc như hiện giờ (vào màn có quân lần đầu gặp). (user)

## 3. Không làm (non-goals)
- **Không sửa logic bot**: `scripts/core/ai.gd`, `ai_plan.gd`, `AI.DEFAULT` / `PRESETS`, hook `ai_goals` / `ai_tile` trong `objectives.gd`. (user, lệnh cũ còn hiệu lực)
- Cảnh diễn **không dạy mẹo** (gọi hồn, hào quang tu sĩ, thuyền dưới nước, rồng bay qua sông, golem lên núi…): bot dùng mẹo, người chơi tự hiểu. Cảnh chỉ diễn **đi + đòn đánh cơ bản + hiệu ứng có sẵn của đòn đó**. (user)
- Không cuộn / zoom map. (user: "thôi ko scroll")
- Không thưởng gì ngoài sao cho nhiệm vụ. (Claude)
- Không cốt truyện, không thoại. Không 3D.
- Không đổi luật đánh / chỉ số.

## 4. Thất bại dù chạy được (anti-goals)
- Màn hướng dẫn vẫn là tường chữ / hộp thoại dài.
- Bảng nhiệm vụ che quân / ô người chơi cần bấm.
- Nhiệm vụ không thể làm được trong màn (vd "bắn bằng cung thủ" mà phe ta không có / không mua được cung thủ).
- Người chơi cũ mất tiến độ mở khoá vì 2 màn mới chèn vào đầu.
- Kẹt ở bước hướng dẫn (bước chờ việc không thể xảy ra, vd địch không bao giờ tới đánh).

## 5. Bảng nhiệm vụ (UI)
- **Vị trí: góc trên phải**, ngay dưới cụm ⏩ ⚙ (`hud_tr`). (user: góc trên phải; dưới ⏩⚙ = Claude)
- **Bỏ ô mục tiêu cũ góc trên trái** (`_goal` trong `game_hud.gd`): mục tiêu thắng giờ là dòng in đậm cuối bảng. Lượt / vàng giữa trên giữ nguyên. (Claude)
- **A — thu gọn 1 dòng**: bình thường hiện `📜 <nhiệm vụ đang làm>  1/5`. Chạm -> bung cả danh sách (✓ gạch ngang / ▢ / ★ dòng thắng in đậm), tự gập sau ~4 s hoặc chạm lại. (user chọn A+B)
- **B — tự mờ khi bị che**: lúc bảng đang hiện mà dưới nó có quân, ô đang rê / chạm, vùng xanh, đường đi -> alpha ~0.2 + bấm xuyên (MOUSE_FILTER_IGNORE). Hết che -> hiện lại.
- **Ẩn khi chọn quân / ô**, giống hệt nút Hết lượt (`place_hud`: `unit_card`). (user)
- "Nhiệm vụ đang làm" = nhiệm vụ đầu tiên chưa xong (thứ tự trong danh sách). Hết nhiệm vụ phụ -> dòng thắng.
- **Xong 1 nhiệm vụ**: dấu ✓ to đóng giữa màn (scale 0 -> 1.6 -> 1) + tiếng "tách" (sfx UI có sẵn) -> thu nhỏ bay vào bảng -> dòng gạch ngang -> bảng chuyển sang nhiệm vụ kế. Không chặn input quá ~0.8 s. Lượt bot: hiệu ứng chỉ chơi cho nhiệm vụ của người chơi.
- Màn chơi tự do / đấu (skirmish / duel / hotseat): không có bảng nhiệm vụ; dòng mục tiêu vẫn cần chỗ -> builder giữ hành vi cũ cho các chế độ đó hoặc hiện bảng chỉ có dòng thắng. (Claude: hiện bảng chỉ có dòng thắng, 1 kiểu UI cho mọi chế độ)

## 6. Nhiệm vụ (dữ liệu + luật)
### 6.1 Động từ (verb) dùng chung
File mới `scripts/core/quests.gd` (game.gd đã chạm trần 1000 dòng gdlint). Mỗi nhiệm vụ = `{ "do": <verb>, "what": <loại quân | ký tự ô | null>, "n": 1 }`. Verb tối thiểu (Claude):

| verb | xong khi (phe ta) | nguồn |
|---|---|---|
| `select` | chọn 1 quân `what` (chỉ dùng trong hướng dẫn) | UI |
| `move` | 1 quân `what` (null = bất kỳ) đi tới ô khác | event `move` |
| `end_turn` | bấm Hết lượt | UI / end turn |
| `capture` | chiếm ô loại `what` (`v` / `c`) | event `capture` |
| `stand_on` | 1 quân ta kết thúc hành động trên ô loại `what` | sau `do_action` |
| `attack_with` | quân `what` (null = bất kỳ) đánh 1 đòn | event `hit` (người đánh = ta) |
| `kill_with` | quân `what` hạ 1 địch | event `die` |
| `buy` | mua 1 quân `what` (null = bất kỳ) | `Game.buy` thành công |
| `heal_on` | quân ta được hồi máu trên ô loại `what` | event `heal` |
| `repair` | sửa làng hỏng | event `repair` |
| `raze` | phá 1 làng | event `raze` |
| `raise` | gọi dậy 1 bộ xương | event `raise` |
| `hit_type` | quân ta đánh trúng 1 địch loại `what` | event `hit` (bị đánh = địch) |
| `kill_type` | quân ta hạ 1 địch loại `what` | event `die` |

- `what` của `attack_with` / `kill_with` = **quân ta đánh**; của `hit_type` / `kill_type` = **địch bị đánh**. (Claude, builder check)

- Thêm verb = thêm 1 mục registry (giống `objectives.gd` `TYPES`): hàm khớp event + hàm "còn làm được không" (cho test).
- Chữ nhiệm vụ sinh từ mẫu theo verb trong `content/theme.gd` `text` (vd `quest_attack_with`: "Đánh bằng {unit}") + tên quân / ô từ theme. Ghi đè được bằng `"text"` trong nhiệm vụ.
- Tiến độ lưu trong state: `s.quests = [{ do, what, n, have, done }]`, ghi theo event của phe người chơi (`p`). Không tăng `STATE_V`: thiếu khoá `quests` (bản lưu cũ) -> `GameScreen.start` khởi tạo lười.
- Nơi gọi: sau `Game.do_action` / `Game.buy` / end turn, một hàm thuần `Quests.observe(s, ev)` (không đổi RNG / kết quả ván). **`sim/golden.txt` phải y hệt.**

### 6.2 Nhiệm vụ "lần đầu" gắn vào loại quân (không có cho địa hình)
- **Chỉ quân có nhiệm vụ lần đầu. Địa hình: không** — ít loại, để người chơi tự hiểu. (user: "chưa cần nhiệm vụ cho địa hình đâu"). Không có trường `newTerrain`. Thiết kế giữ chỗ để sau này gắn được cho ô (cùng cơ chế `DEBUT`, khoá theo ký tự ô), nhưng không làm bây giờ.
- Khai báo trong `content/guide.gd`, dict mới `DEBUT` theo loại quân (Claude: guide.gd đã là nội dung theo từng loại; `rules.gd` giữ thuần luật):
  - `soldier` -> `move`; `archer` `wolf` `elephant` `bird` `boat` `catapult` `shaman` `drum` -> `attack_with` loại đó; `hero` -> `move`; `ghost` -> không (không mua được, do mẹo gọi hồn).
  - **Quân mới chỉ phe địch có** (vd m04 golem, m09 thuỷ binh, m11 sói: không có trong quân ta / `allowed.p`) -> nhiệm vụ đổi sang `kill_type <loại>` ("Hạ 1 Golem đá"). `Quests.for_level` tự chọn: phe ta có / mua được -> `attack_with`, không -> `kill_type`. (Claude, builder check)
- `Quests.for_level(def)` = `def.quests` (tay, tuỳ chọn) + DEBUT của mỗi loại trong `newUnits` (bỏ trùng) + dòng thắng (chỉ hiển thị, không tính vào sao nhiệm vụ).
- **"Lần đầu" tính theo màn, không theo người chơi**: màn ra mắt cung thủ luôn có nhiệm vụ cung thủ, chơi lại vẫn có. (Claude, đã nói user)
- Test (`sim/tests.gd`): mỗi nhiệm vụ của mỗi màn phải **làm được** — `attack_with X` cần X có sẵn phe ta hoặc trong `allowed.p`; `kill_type X` cần địch X trên map / trong waves / `allowed.e`; `capture v` cần làng không thuộc ta; `repair` cần ô `x`; `heal_on v` cần làng; v.v.

### 6.3 Sao
- Giữ 3 mục sao hiện có (`stars.gd`: thắng / tướng không ngã / mốc lượt hoặc mốc quân mất).
- **Luật thêm: thắng mà còn nhiệm vụ (không tính dòng thắng) chưa xong -> trừ 1 sao, tối thiểu 1.** (user: thắng nhưng mất sao; trừ 1 + sàn 1 = Claude)
- Thẻ thắng thêm dòng `Nhiệm vụ 3/4` (✓ khi đủ, đỏ khi thiếu) để người chơi biết vì sao mất sao.
- Sim cân bằng: bot phe ta không cố làm nhiệm vụ (không sửa bot) -> khi đo mốc sao, **coi nhiệm vụ đã xong**. Ghi rõ trong `docs/content.md`.

### 6.4 Màn nào có nhiệm vụ (user chọn (a))
- **Chỉ**: t01, t02 (bước hướng dẫn), m01–m04 (tay), m10 (tay: `repair` — sửa làng, user liệt kê), và các màn có `newUnits` (DEBUT tự sinh). Màn khác (phần lớn m05–m16, g01–g20): bảng chỉ có dòng thắng, không mất sao vì nhiệm vụ. (user: "a")
- Vì vậy **không sửa levelgen**.
- Nhiệm vụ tay (Claude, builder chỉnh theo map thật; mỗi màn 2–4, dễ, làm được trong vài lượt đầu; trần 4 mềm):
  - m01: `move hero`, `capture v`, `attack_with soldier`, `kill_with` bất kỳ.
  - m02: `buy archer`, `capture c` (+ DEBUT archer `attack_with archer`).
  - m03: `heal_on v` hoặc `heal_on c` (đứng làng / thành hồi máu).
  - m04: `buy drum`, `hit_type hero` (đánh tướng địch).
  - m10: `repair`.

## 7. Hai màn hướng dẫn
- File `content/levels/t01.gd`, `t02.gd`, `order` 1 và 2 (trước m01 = 10). Hiện là level 1, 2 trong lưới Thử thách. `tier: "easy"`, `ai: "normal"`.
- Trường mới `"tutorial": [bước…]` — chỉ 2 màn này có. Mỗi bước: `{ quest (verb như §6.1), allow (ô / nút được bấm), point (ô | "end_turn" | "buy:<loại>"), say (1 dòng, tuỳ chọn) }`. Bước xong khi quest của nó xong -> sang bước kế. Hết bước -> chơi tự do tới khi thắng, bảng nhiệm vụ vẫn hiện.
- **Khoá input**: trong bước, mọi click ô / nút ngoài `allow` bị nuốt (không âm thanh lỗi; vòng sáng nháy lại). Phím tắt (Space, Tab, E, H) tắt trong bước. Hint (H) tắt.
- **Overlay**: lớp tối toàn màn có lỗ tròn quanh ô / nút đang chỉ; vòng vàng nhấp nháy; bàn tay 👆 nhún; 1 bong bóng chữ ngắn cạnh lỗ (font + màu giấy F1). Tránh che lỗ khác.
- t02 **không có quân địch** (chỉ thành địch) để lính bị thương không chết giữa bước hồi máu; t01: địch cờ `guard` có sẵn (giữ chỗ tới khi quân ta tới gần `mv + rmax + 1`, xem `ai.gd` ~682) + máu thấp. Không sửa bot.
- **t01** (map nhỏ, 1 tướng ta, 1–2 địch gác máu thấp, 1 làng trống, 1 ô rừng sát vùng địch; thắng `rout`):
  1. `select hero` — "Chọn tướng"
  2. `capture v` — vùng xanh hiện, chỉ ô làng bấm được; chiếm xong bay "+30 🪙" + ❤. say: "Làng: vàng mỗi lượt, đứng trên thì hồi máu"
  3. `end_turn` — tay chỉ nút Hết lượt; sang lượt, số vàng nhảy (hiệu ứng thu nhập có sẵn).
  4. `stand_on f` — chỉ ô rừng; đứng xong bay "🛡 +" trên quân. Lượt địch: địch thức dậy đánh -> máu mất ít. (Builder: đảm bảo địch tới đánh được trong 1 lượt; nếu không, bước 5 vẫn chạy được.)
  5. `attack_with hero` — chỉ địch; dự báo sát thương hiện như thường; đánh.
  Sau đó tự do: hạ hết địch.
- **t02** (1 tướng + 1 lính bị thương sẵn, thành ta, làng ta gần, thành địch; thắng `castles`):
  1. `buy soldier` — chỉ thành ta -> chỉ nút mua lính.
  2. `stand_on v` bằng lính bị thương -> `end_turn` -> `heal_on v` (hiện "+20 ❤" — pop hồi máu có sẵn).
  3. `capture c` (thành địch) bằng tướng — dòng thắng.
- **Khoá bước chạy mọi lần vào t01/t02** (kể cả chơi lại sau khi thắng); bước đang ở lưu trong state (`s.tut_step`) để Đánh tiếp không về bước 1. Muốn khỏi hướng dẫn thì Bỏ qua. (Claude, builder check)
- **Bỏ qua**: menu ⚙ (pause) trong t01 / t02 có nút "Bỏ qua hướng dẫn" -> ghi thắng 1 sao (`Store.record_result`) -> về lưới / sang màn kế. (Claude, giải cho câu cụt "(người chơi có thể)" của user)
- **Người chơi cũ**: `Store.unlocked_index` = level xa nhất đã thắng + 1 -> chèn t01/t02 trước không khoá gì (đã thắng m-gì đó thì mọi level trước mở). Builder kiểm bằng test.
- t01/t02 `newUnits`: `hero`, `soldier` (DEBUT trùng bước thì bỏ trùng). m01 hiện có `newUnits: [hero, soldier]` -> chuyển sang t01/t02, m01 bỏ. (Claude)

## 8. Popup giới thiệu quân = cảnh diễn
- Thời điểm + nhớ "đã gặp": giữ `GameCards.intro_new_units` (vào màn, mỗi loại 1 lần / người chơi, `Store "seen_units"`, tắt khi bot / nointro). Chỉ thay **nội dung** `intro_card`. (user)
- Thẻ còn lại: nhãn nhỏ "QUÂN MỚI" / "QUÂN ĐỊCH MỚI" / "TƯỚNG …" (đã có), **tên quân**, **sân khấu**, **hàng icon chỉ số** `⚔ công 🛡 thủ 👣 đi 🎯 tầm` (icon có sẵn ở `Icons`), nút **↻ Xem lại** + **Đã hiểu**. Bỏ role / mô tả / đặc tính / "Cách dùng" (vẫn ở ⓘ + Sách lính). (user: bỏ chữ càng nhiều càng tốt)
- **Sân khấu**: 1 hàng 6 ô đồng cỏ (vẽ bằng art địa hình thật), quân diễn = token + rig tấn công có sẵn (`scripts/ui/rig/`), địch bù nhìn = vệ binh phe kia. Cảnh lặp lại khi bấm Xem lại; tự chạy 1 lần khi mở.
- Kịch bản sinh **từ dữ liệu quân** (không viết tay theo tên — để quân mới tự có cảnh) (Claude):
  1. Hiện vùng xanh = `mv` ô (cắt theo sân khấu) -> quân đi tới ô đánh.
     - `siege` (đứng yên mới bắn): đi trước -> "lượt sau" (chớp mờ) -> bắn.
  2. Đánh: `rmax > 1` -> khung vàng tầm `rmin..rmax`, bắn từ xa, đạn theo `shot`; địch **không đánh trả** -> 🚫 hiện ở chỗ đáng lẽ phản đòn. Cận chiến -> địch đánh trả nhẹ (số nhỏ).
  3. Số sát thương bay lên (giống trên bàn cờ). Có `poison` -> 2 mác đỏ `⚔ −N 🛡 −N` bật lên địch.
  4. Không diễn aura / raise / water / bay qua sông / núi (mẹo — §3).
- Popup tướng: cùng kiểu (đi + đánh).
- Tối đa ~4 s / cảnh. Space / Enter = Đã hiểu.

## 9. Ràng buộc kỹ thuật
- Godot 4.7, GDScript, gdlint (`gdlintrc`: trần 1000 dòng / file). `game.gd` đã 1000 -> logic mới vào file mới.
- Golden `sim/golden.txt` y hệt; `sim/tests.gd` xanh; `sim/click_driver.gd` 0 lỗi (chạy với `nointro` / không có hướng dẫn chặn); nếu driver vào t01 thì phải đi đúng bước.
- Không sửa bot (§3). Sim chạy được trên t01/t02 (bot phe ta không cần theo bước: hướng dẫn chỉ bật khi người chơi thật).
- Chữ hiển thị qua `content/theme.gd` `text`.
- Chạy Godot: headless khi không có màn hình; script ngoài project (`godot -s /abs.gd` không `--path`) không tự thoát -> dùng `timeout`.
- Ảnh kiểm tra: probe kiểu `sim/probes/hud_shot.gd` cho bảng nhiệm vụ (1280x720 + 1500x675 + 960x720), cảnh popup (chụp vài khung), bước hướng dẫn.

## 10. Để builder quyết
- Cấu trúc file UI (vd `quest_panel.gd`, `tutorial.gd`, `intro_stage.gd`), API giữa chúng.
- Vẽ overlay tối có lỗ (shader / StyleBox / `_draw`).
- Thời gian / easing hiệu ứng, cỡ chữ (theo `Style`).
- Bản đồ t01/t02 (nhỏ, ~9×7, theo quy tắc bố trí `docs/content.md`).
- Câu chữ bong bóng (≤ ~6 từ, trừ câu làng).
