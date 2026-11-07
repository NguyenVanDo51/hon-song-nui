# TODO

## Đang dở (dừng 2026-11-07, user ngắt mạng)
- Giao diện: phiên khác của user có spec `docs/superpowers/specs/2026-11-07-fantasy-reskin-design.md` (F1 Truyện Kỵ Sĩ, bỏ bối cảnh lịch sử; chờ duyệt, chưa track) -> không làm hướng B; hỏi user ai làm reskin.
- Kinh nghiệm chơi của user -> **Khó v3** (2026-11-07, docs/ai.md "Kinh nghiệm người chơi"): mỗi mẹo = 1 knob `AI.DEFAULT` (tắt mặc định). Ship vào `AI.PRESETS.hard`: không sang lẻ (`lone_w`), giết quân hỗ trợ / quân nguy hiểm trước (`tgt_*`), không đổi lỗ (`trade_w`), cung trước (`order_w`), không nuôi địch lên cấp (`feed_w`). Seed giữ riêng: 0,744 vs Khó v2 (768 ván), 0,949 vs Khó v1, 0,925 vs Thường. Để tắt: tướng có hộ tống / chỉ nhắm thành (`escort_w`, `hero_cgoal`: thua Khó v1 ở núi rừng; `hero_cgoal` có lỗi bỏ qua thành trung lập, đã sửa, chưa đo lại), về hồi máu theo cấp / giá (`home_*`, `bld_w`: không đổi sức, hành vi đổi ít). Chưa làm: giữ điểm hẹp (đầu cầu), đua làng sớm. Chờ: **user chơi thử Khó v3**.
- Câu hỏi chờ user: mẹo màn (`def.tips`) hiện ở đâu (màn chuẩn bị đã bỏ)? Đoạn kết màn có đổi sang hội thoại như mở màn không?
- File lạ chưa track, không phải của Claude, để nguyên: `docs/review/genre_hooks.html` (sửa), `docs/review/ui_direction_fantasy.html`, `docs/superpowers/`.

## Cân bằng / nhịp chơi
- [x] **m14 Rút Về Cấm Khê quá khó**: đã hết (sim AI-vs-AI ta thắng 12/12 ở AI `fe83a5d`, 10/12 ngay trước; bảng `31a006e` từng là 3/12, phần lớn `timeUp`). Người thật chơi thử để chắc.
- [ ] **Chơi thử nhịp ra quân mới** (`docs/content.md` mục "Nhịp ra quân mới"): người thật chơi m03–m05 + m09–m13, xem có kịp quen quân cũ trước khi gặp quân mới không. Sim AI không đo được việc học quân.
- [ ] Sau mỗi lần đổi AI (`scripts/core/ai.gd`): chạy lại `bash tools/sim_many.sh "m01 … m16" 12 8` + cập nhật bảng cân bằng README (số hiện tại đo với AI `fe83a5d`).

## Tính năng
- [ ] **Giao diện "chất game"** (`docs/review/ui_direction.html`, 2026-11-07): 3 hướng (Trống Đồng / Sơn Mài / Đông Hồ) + mockup, đề xuất B Sơn Mài; chờ chọn hướng -> làm P0–P5 sau khi tách `game_screen.gd` merge.
- [x] **Chế độ 1 đấu 1** (`docs/1v1.md`, 2026-11-06): người–người chung máy (màn chuyển tay) + người–máy; bước 1–3 xong.
  - [x] Bước 4: Dễ / Thường / Khó = `AI.PRESETS` -> `s.aiParams` (docs/1v1.md "Độ khó"; tỉ lệ thắng docs/ai.md). Khó v1 chỉ hơn Thường ~55% -> xong bằng Khó v2.
  - [x] **Khó v2** (2026-11-07, `scripts/core/ai_plan.gd`, docs/ai.md "Khó v2"): lập kế hoạch cả lượt (portfolio style + dồn đòn giết + giữ thành, địch đáp 1 lượt, chấm thế cờ). Seed giữ riêng: 0,896 vs Khó v1 (396 ván).
  - [x] **Khó v3** (2026-11-07): Khó v2 + kinh nghiệm người chơi (docs/ai.md "Kinh nghiệm người chơi"): 0,744 vs Khó v2 seed giữ riêng (768 ván).
  - [ ] Khó v3 tiếp (v4): người thật chơi thử (AI-vs-AI ≠ người); giữ đầu cầu, đua làng; mua theo đội hình (để dành cho trống / sói / chim, phản quân); tìm sâu có địch đáp (ply 4) ở lượt quyết định. **Đã thử 2026-11-07** (docs/ai.md "Mẹo người chơi trên mạng = Khó v4"): mẹo trên mạng T1 tầm quân địch mua (`buy_threat`), T2 XP (`promo_w`), T5 trống / sói trước (`pl_chain`), T6–T8 tìm sâu ở lượt quyết định (`pl_dp`), T9 ngưỡng rút theo giáp (`ret_terr`), T12 để dành mua trống / sói (`buy_sup`) + chỉnh lại v3 (`lone_w` 0,6, `lone_n` 2, `hero_cgoal` đã sửa, `escort_w` 10): dev đều trong nhiễu; `hard_v4` (= v3 + `buy_threat` 1) seed giữ riêng 0,497 ± 0,018 vs v3 (768 ván) -> **không ship**, knob để tắt. Cũ (Khó v2 tiếp): đo thời gian trên điện thoại thật (Mac: lượt TB ~0,15 s, tệ nhất ~0,45 s); chọn loại lính theo đội hình địch. Đã thử 2026-11-07 (docs/ai.md "Luyện thêm"): tune trọng số hàm điểm (quét 2×, Texel), "mua trước" (`pl_buy`), địch đáp dồn đòn (`pl_opp_kill`) -> seed giữ riêng 0,517 ± 0,026 vs `hard_v2_0` = **không khôn hơn**, không ship. Tiếp cho "Siêu khó": tìm sâu hơn ở lượt quyết định / đánh giá học từ ≥ 2000 ván / chấp vàng; mỗi lần đo ≥ 400 ván.
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
- [ ] scripts/core/ai.gd:849 (2026-11-07) — `buy_step` / `choose_buy` mua ngay khi đủ vàng, không bao giờ để dành -> AI không mua trống / sói / voi / chim (tự đấu: 0), mẹo T4 / T5 / T13 không có đất dùng (thử `buy_sup` ở docs/ai.md "Mẹo người chơi trên mạng"; mua theo đội hình địch).
- [ ] scripts/core/ai.gd (2026-11-07) — 917 dòng, sát giới hạn 1000 (`tools/lint.sh`) -> tách `buy_threats` / `promo_gain` / `_support_want` / `choose_buy` sang file mới (vd `scripts/core/ai_tactics.gd`) trước khi thêm knob.
- [ ] scripts/core/ai_plan.gd:248 (2026-11-07) — `kill_prefixes` gọi `AI.tvalue` 2 lần trong mỗi so sánh của `sort_custom` -> O(n log n) tvalue mỗi lần lập + mỗi lời đáp `pl_opp_kill` (nhỏ, nhưng trong vòng nóng): tính trước 1 dict id -> tvalue.
- [ ] scripts/core/ai.gd `buy_threats` (2026-11-07) — tướng chuộc lại dùng cấp 0, thật ra giữ cấp / XP (`s.heroSaved`) -> đánh giá thấp tướng chuộc cấp cao (chỉ khi `buy_threat` > 0).
- [ ] scripts/core/ai_plan.gd `pl_ms` (2026-11-07) — phanh 4 s theo đồng hồ thật: máy tải ~10–20 (nhiều sim song song) -> chạm (2 lần / 432 ván ở Khó v4 vs Thường) -> ván sim không tất định tuyệt đối. Cân nhắc phanh theo số bước rollout thay vì ms.
