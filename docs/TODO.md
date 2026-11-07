# TODO

## Đang dở (dừng 2026-11-07, user ngắt mạng)
- Giao diện: phiên khác của user có spec `docs/superpowers/specs/2026-11-07-fantasy-reskin-design.md` (F1 Truyện Kỵ Sĩ, bỏ bối cảnh lịch sử; chờ duyệt, chưa track) -> không làm hướng B; hỏi user ai làm reskin.
- Đang làm (user "làm tiếp" 2026-11-07): cài kinh nghiệm chơi của user vào Khó v2, mỗi điểm = 1 knob bật/tắt, đo ≥ 400 ván seed mới vs `hard_v2_0` + user chơi thử. Thứ tự đề xuất:
  1. tập kết, không sang lẻ (không vào vùng địch đánh tới trừ khi đủ quân cùng vào / cùng đánh lượt đó; đứng ngoài tầm rồi ập vào)
  2. giá trị mục tiêu cao cho quân hỗ trợ phiền (thầy mo, sói, trống) + ưu tiên giết theo sát thương nó gây lượt sau (hiện chỉ tướng có `aiValue`, quân khác = giá tiền)
  3. ngưỡng rút về hồi máu theo cấp + giá (hiện `home_hp` 50 cho mọi quân); cẩn thận theo từng quân, không cả đội (bản "tướng về chỗ an toàn" từng làm bot rụt rè, thua)
  4. tướng đi chiếm thành có hộ vệ
  5. cung đánh trước cả khi không nhằm giết; phạt đòn đổi máu lỗ 1:1; giữ điểm hẹp (đầu cầu); không nuôi quân địch lên cấp; đua làng sớm
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
  - [ ] Khó v2 tiếp: người thật chơi thử (AI-vs-AI ≠ người); đo thời gian trên điện thoại thật (Mac: lượt TB ~0,15 s, tệ nhất ~0,45 s); chọn loại lính theo đội hình địch. Đã thử 2026-11-07 (docs/ai.md "Luyện thêm"): tune trọng số hàm điểm (quét 2×, Texel), "mua trước" (`pl_buy`), địch đáp dồn đòn (`pl_opp_kill`) -> seed giữ riêng 0,517 ± 0,026 vs `hard_v2_0` = **không khôn hơn**, không ship. Tiếp cho "Siêu khó": tìm sâu hơn ở lượt quyết định / đánh giá học từ ≥ 2000 ván / chấp vàng; mỗi lần đo ≥ 400 ván.
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
