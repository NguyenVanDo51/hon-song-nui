# TODO

## Thử thách (nhánh `feat/levels`, 2026-11-07)
- [ ] P3 (cần sửa bot, chờ user cho phép): phe thủ chặn ô đích (`reach`); kiểu thắng "chiếm N làng" + hook bot 2 phía; đo lại m13 / m14.
- [ ] Nhãn độ khó đo bằng bot phe ta (12 ván): bot không phải người -> chờ user chơi thử, chỉnh `tier` / vàng.
- [ ] Thẻ kết thúc: "quân ta ngã" (đếm phiên này, gồm tướng + âm binh) có thể khác "(mất N)" của sao (`s.lost`, cả ván) sau khi "Đánh tiếp".
- [ ] `LevelGen.problems()` chưa kiểm chủ ô trên công trình / skin quân như validator trong tests; `install=` ghi đè không hỏi.
- [ ] Sót chữ: `menus.gd` "Màn này đang đánh dở"; `tools/web_smoke.*` còn `?screen=campaign`; `draw.gd` chú thích `text_c` nằm trên `star()`.
- Câu hỏi "mẹo màn `def.tips` hiện ở đâu" (mục dưới) hết hiệu lực: nhánh này bỏ `tips` / truyện.

## Đang dở (dừng 2026-11-07, user ngắt mạng)
- Giao diện: phiên khác của user có spec `docs/superpowers/specs/2026-11-07-fantasy-reskin-design.md` (F1 Truyện Kỵ Sĩ, bỏ bối cảnh lịch sử; chờ duyệt, chưa track) -> không làm hướng B; hỏi user ai làm reskin.
- Kinh nghiệm chơi của user -> **Khó v3** (2026-11-07, docs/ai.md "Kinh nghiệm người chơi"): mỗi mẹo = 1 knob `AI.DEFAULT` (tắt mặc định). Ship vào `AI.PRESETS.hard`: không sang lẻ (`lone_w`), giết quân hỗ trợ / quân nguy hiểm trước (`tgt_*`), không đổi lỗ (`trade_w`), cung trước (`order_w`), không nuôi địch lên cấp (`feed_w`). Seed giữ riêng: 0,744 vs Khó v2 (768 ván), 0,949 vs Khó v1, 0,925 vs Thường. Để tắt: tướng có hộ tống / chỉ nhắm thành (`escort_w`, `hero_cgoal`: thua Khó v1 ở núi rừng; `hero_cgoal` có lỗi bỏ qua thành trung lập, đã sửa, chưa đo lại), về hồi máu theo cấp / giá (`home_*`, `bld_w`: không đổi sức, hành vi đổi ít). Chưa làm: giữ điểm hẹp (đầu cầu), đua làng sớm. Chờ: **user chơi thử Khó v3**.
- Câu hỏi chờ user: mẹo màn (`def.tips`) hiện ở đâu (màn chuẩn bị đã bỏ)? Đoạn kết màn có đổi sang hội thoại như mở màn không?
- File lạ chưa track, không phải của Claude, để nguyên: `docs/review/genre_hooks.html` (sửa), `docs/review/ui_direction_fantasy.html`, `docs/superpowers/`.

## Cân bằng / nhịp chơi
- [x] **m14 Rút Về Cấm Khê quá khó**: đã hết (sim AI-vs-AI ta thắng 12/12 ở AI `fe83a5d`, 10/12 ngay trước; bảng `31a006e` từng là 3/12, phần lớn `timeUp`). Người thật chơi thử để chắc.
- [ ] **Chơi thử nhịp ra quân mới** (`docs/content.md` mục "Nhịp ra quân mới"): người thật chơi m03–m05 + m09–m13, xem có kịp quen quân cũ trước khi gặp quân mới không. Sim AI không đo được việc học quân.
- [ ] **Chơi thử mốc sao** (2026-11-06): mốc sao 3 = trung vị khi AI phe ta thắng (`docs/content.md` mục "Sao màn"). Người thật thấy quá dễ / quá khó thì chỉnh `stars` trong file màn. Đáng xem: m08 (25, trung vị AI 30), m03 / m09 (`lost: 0`), m14 (AI thắng thì tướng ngã 11/12 ván -> sao 2 có thể quá khó).
- [ ] Sau mỗi lần đổi AI (`scripts/core/ai.gd`): chạy lại `bash tools/sim_many.sh "m01 … m16" 12 8` + cập nhật bảng cân bằng README (số hiện tại đo với AI `fe83a5d`).

## Tính năng
- [ ] **Giao diện "chất game"** (`docs/review/ui_direction.html`, 2026-11-07): 3 hướng (Trống Đồng / Sơn Mài / Đông Hồ) + mockup, đề xuất B Sơn Mài; chờ chọn hướng -> làm P0–P5 sau khi tách `game_screen.gd` merge.
- [ ] Vùng địch đánh tới: có thể thêm nút bật vùng gộp mọi quân địch + cảnh báo khi chọn ô đích nằm trong vùng.
- [x] **Chế độ 1 đấu 1** (`docs/1v1.md`, 2026-11-06): người–người chung máy (màn chuyển tay) + người–máy; bước 1–3 xong.
  - [x] Bước 4: Dễ / Thường / Khó = `AI.PRESETS` -> `s.aiParams` (docs/1v1.md "Độ khó"; tỉ lệ thắng docs/ai.md). Khó v1 chỉ hơn Thường ~55% -> xong bằng Khó v2.
  - [x] **Khó v2** (2026-11-07, `scripts/core/ai_plan.gd`, docs/ai.md "Khó v2"): lập kế hoạch cả lượt (portfolio style + dồn đòn giết + giữ thành, địch đáp 1 lượt, chấm thế cờ). Seed giữ riêng: 0,896 vs Khó v1 (396 ván).
  - [x] **Khó v3** (2026-11-07): Khó v2 + kinh nghiệm người chơi (docs/ai.md "Kinh nghiệm người chơi"): 0,744 vs Khó v2 seed giữ riêng (768 ván).
  - [ ] Khó v3 tiếp (v4): người thật chơi thử (AI-vs-AI ≠ người); thử lại tướng có hộ tống (`escort_w` riêng, `hero_cgoal` đã sửa), `lone_w` mạnh hơn (0,6 / `lone_n` 2), giữ đầu cầu, đua làng; threat map chưa tính quân địch mua ngay lượt sau. Cũ (Khó v2 tiếp): đo thời gian trên điện thoại thật (Mac: lượt TB ~0,15 s, tệ nhất ~0,45 s); chọn loại lính theo đội hình địch. Đã thử 2026-11-07 (docs/ai.md "Luyện thêm"): tune trọng số hàm điểm (quét 2×, Texel), "mua trước" (`pl_buy`), địch đáp dồn đòn (`pl_opp_kill`) -> seed giữ riêng 0,517 ± 0,026 vs `hard_v2_0` = **không khôn hơn**, không ship. Tiếp cho "Siêu khó": tìm sâu hơn ở lượt quyết định / đánh giá học từ ≥ 2000 ván / chấp vàng; mỗi lần đo ≥ 400 ván.
  - [ ] Điện thoại ngang: màn thiết lập phải cuộn mới thấy "Xuất quân"; popup mua 9 loại quân tràn ~844x390 (có từ đấu tự do). Nút "Đánh tiếp ván đang dở" chưa ghi rõ 1 đấu 1 hay đấu tự do.
  - [ ] Online: relay chuỗi step + hash.
- [x] **AI luyện bằng tự đấu** (2026-11-06): `AI.DEFAULT` + `sim/tune.gd` + `tools/tune.sh` (docs/ai.md); lính ít máu về hồi máu (hết nằm góc). Theo dõi: m08 hòa 1 -> 4/24 sau sửa.

## Chất lượng code
- [x] Lint (2026-11-06): gdtoolkit 4.5.0 `gdlint` + Godot warnings = error + `tools/lint.sh` + pre-commit (`tools/install_hooks.sh`). README "Lint".
- [x] **Siết lint theo giai đoạn** (2026-11-06, xong): 1 core kiểu chặt; 2 int division / ternary / shadowing = error; 3 kiểu chặt content / sim / tools / ui (5 agent song song); 4 `return_value_discarded` quyết định TẮT (267 chỗ, >90% chủ ý; lỗi IO đã kiểm tay: save_png / FileAccess / store_string / load_svg); 5 gdlintrc dòng ≤ 150 + class-definitions-order bật. `tools/warn_count.sh` = 0 toàn repo; tests 80/80, golden giống hệt, driver 0 fail, rig smoke 132/0.
  - [x] `max-file-lines` 2650 -> 1000 (2026-11-07): tách game_screen (E5: game_hud / info_panel / event_player / turn_driver / game_cards), board -> board_paint, fx -> fx_strikes, tests.gd -> runner + `sim/tests/*.gd`. Dài nhất: game.gd 972.
  - [ ] Click driver dùng chung profile "driver" -> chạy song song nhiều worktree thì 2 check save/thoại mở màn lỗi ngẫu nhiên: cho profile theo tham số (vd `profile=driver_<pid>`).
- [x] Formatter (2026-11-07): gdscript-formatter 0.27 (GDQuest) format toàn repo + `--check` trong `tools/lint.sh` (README Lint). Code dài ra ~3000 dòng (lambda / dict bung nhiều dòng).
- [x] Code review 2026-11-06 backlog: hiệu năng P1–P8 (trừ P9), mở rộng E2/E3/E4/E7, tái sử dụng R1–R5 — merged e5a3520.
- [ ] Còn lại từ review (`docs/review/code_review_2026-11-06.md`): E1 nhiều phe / đồng minh, E6 i18n (E5 tách `game_screen.gd` xong 2026-11-07); P9 vẽ lại khi idle; spike ~18 ms khi rig đánh lần đầu (raster phần rig); test UI phá/sửa làng/gọi hồn qua click, phím tắt, save giữa ván; đo hiệu năng trên điện thoại thật (web/iOS).
- [ ] Cờ `nobattle` không còn tác dụng (battle_view đã xoá) nhưng còn trong lệnh probe / docs/rig_port.md: dọn.

## Nợ kỹ thuật
Quy tắc: `CLAUDE.md` — đọc code thấy nợ / rủi ro lỗi / hiệu năng (dù nhỏ, dù ngoài task) -> ghi ở đây.
- [ ] 2026-11-07 `scripts/ui/game_hud.gd:326` `_side_w()` không ai gọi -> code chết (xoá).
- [ ] 2026-11-07 `scripts/ui/quest_panel.gd` bảng nhiệm vụ chặn chuột (khi không mờ) -> ô trống nằm trọn dưới bảng không rê / bấm được bằng chuột (chỉ mờ khi ô rê lấn mép bảng / có quân dưới); cân nhắc mờ khi chuột vào bảng từ phía bàn cờ.
- [ ] (2026-11-07) `sim/golden.txt` cũ so với code: trace mới ra `m02 0..3` khác golden (từ 59bd10a chỉnh vàng m02), g01–g20 chưa từng có trong golden, trace đủ > 600 s khi máy bận -> regen đủ không còn "chỉ thêm dòng"; test parity chỉ replay 4 key nên không bắt được. Sửa: 1 commit riêng regen golden (`only=` theo lô nếu chậm) + replay thêm 1 key mỗi loại (m, g, t).
- [ ] (2026-11-07) Tên màn m01–m16 + bảng "Nhịp ra mắt" (`docs/content.md`) vẫn là địa danh / sử Việt (Lời Thề Hát Môn, Mê Linh…) sau reskin fantasy -> lệch giọng với t01/t02 + quân hiệp sĩ. Đặt lại tên trung tính.
- [ ] (2026-11-07) `tools/build_fonts.py:12` URL `2D/png/128` 404 cho 👆 👇 (Noto 2D chỉ có svg / bản có tông da) -> `assets/emoji/emoji_u1f446/7.png` rasterize tay từ `2D/svg` bằng Godot; build lại từ thư mục rỗng sẽ mất 2 file này. Sửa: script fallback svg -> png.
- [ ] (2026-11-07) `content/levels/t01.gd` bước 5 (đánh) không có bước "Hết lượt" trước (tướng đã đi ở bước 4) -> `Tutorial._spent` tự chỉ nút Hết lượt; nếu thêm màn hướng dẫn khác, ghi bước end_turn rõ trong content thay vì dựa luật ngầm.
- [x] (2026-11-07) `scripts/ui/game_hud.gd:348` màn hướng dẫn: ⚙ giữ hiện cả khi thẻ quân mở -> thẻ quân chọn góc trên phải (t01 bước 2: đích làng góc trái trên) đè ⚙. Đã sửa: bỏ góc TR khỏi `cands` khi `gs.tutorial.active()`.
- [ ] (2026-11-07) `scripts/ui/tutorial.gd` `_eff` bước đánh: không địch nào trong tầm -> chỉ Hết lượt; nếu địch gác không bao giờ tới gần (guard chỉ thức khi ta tới gần) thì người chơi hết lượt mãi, lối ra duy nhất = ⚙ Bỏ qua. t01 hiện địch thức (khoảng cách 6). Sửa nếu gặp: cho tướng đi (act:wait + ô trong tầm đi) khi spent quá 2 lượt.
- [x] (2026-11-07) `sim/tests/quests.gd` (Task 1, 7eca24a) chưa qua `gdscript-formatter` -> `tools/lint.sh` đỏ trên commit đó (đã format ở nhánh feat/tq-content) -> chạy `tools/lint.sh` trước mỗi commit task, kể cả khi hook pre-commit chưa cài.
