# TODO

## Cân bằng / nhịp chơi
- [x] **m14 Rút Về Cấm Khê quá khó**: đã hết (sim AI-vs-AI ta thắng 12/12 ở AI `fe83a5d`, 10/12 ngay trước; bảng `31a006e` từng là 3/12, phần lớn `timeUp`). Người thật chơi thử để chắc.
- [ ] **Chơi thử nhịp ra quân mới** (`docs/content.md` mục "Nhịp ra quân mới"): người thật chơi m03–m05 + m09–m13, xem có kịp quen quân cũ trước khi gặp quân mới không. Sim AI không đo được việc học quân.
- [ ] Sau mỗi lần đổi AI (`scripts/core/ai.gd`): chạy lại `bash tools/sim_many.sh "m01 … m16" 12 8` + cập nhật bảng cân bằng README (số hiện tại đo với AI `fe83a5d`).

## Tính năng
- [x] **Chế độ 1 đấu 1** (`docs/1v1.md`, 2026-11-06): người–người chung máy (màn chuyển tay) + người–máy; bước 1–3 xong.
  - [x] Bước 4: Dễ / Thường / Khó = `AI.PRESETS` -> `s.aiParams` (docs/1v1.md "Độ khó"; tỉ lệ thắng docs/ai.md). Khó chỉ hơn Thường ~55%: luyện thêm (`tools/tune.sh`, chạy lâu hơn) hoặc cho máy Khó thêm vàng.
  - [ ] Điện thoại ngang: màn thiết lập phải cuộn mới thấy "Xuất quân"; popup mua 9 loại quân tràn ~844x390 (có từ đấu tự do). Nút "Đánh tiếp ván đang dở" chưa ghi rõ 1 đấu 1 hay đấu tự do.
  - [ ] Online: relay chuỗi step + hash.
- [x] **AI luyện bằng tự đấu** (2026-11-06): `AI.DEFAULT` + `sim/tune.gd` + `tools/tune.sh` (docs/ai.md); lính ít máu về hồi máu (hết nằm góc). Theo dõi: m08 hòa 1 -> 4/24 sau sửa.

## Chất lượng code
- [x] Lint (2026-11-06): gdtoolkit 4.5.0 `gdlint` + Godot warnings = error + `tools/lint.sh` + pre-commit (`tools/install_hooks.sh`). README "Lint".
- [x] **Siết lint theo giai đoạn** (2026-11-06, xong): 1 core kiểu chặt; 2 int division / ternary / shadowing = error; 3 kiểu chặt content / sim / tools / ui (5 agent song song); 4 `return_value_discarded` quyết định TẮT (267 chỗ, >90% chủ ý; lỗi IO đã kiểm tay: save_png / FileAccess / store_string / load_svg); 5 gdlintrc dòng ≤ 150 + class-definitions-order bật. `tools/warn_count.sh` = 0 toàn repo; tests 80/80, golden giống hệt, driver 0 fail, rig smoke 132/0.
  - [ ] Còn: `max-file-lines` 2300 -> 1000 sau khi tách game_screen (E5, ~2260 dòng sau 1 đấu 1 + thoại; đã tách widget HUD ra `hud_widgets.gd`, thoại ra `story_overlay.gd`; agent đã gộp ~50 cặp biến bằng `;` để vừa giới hạn cũ -> tách xong thì bỏ), board.gd ~1150, tests.gd ~1050.
  - [ ] Click driver dùng chung profile "driver" -> chạy song song nhiều worktree thì 2 check save/thoại mở màn lỗi ngẫu nhiên: cho profile theo tham số (vd `profile=driver_<pid>`).
- [ ] Formatter: `gdformat` 4.5.0 hỏng với lambda nhiều dòng -> thử GDScript Formatter (GDQuest, Rust; cần build / tải binary, hỏi user) hoặc đợi gdtoolkit sửa.
- [x] Code review 2026-11-06 backlog: hiệu năng P1–P8 (trừ P9), mở rộng E2/E3/E4/E7, tái sử dụng R1–R5 — merged e5a3520.
- [ ] Còn lại từ review (`docs/review/code_review_2026-11-06.md`): E1 nhiều phe / đồng minh, E5 tách `game_screen.gd`, E6 i18n; P9 vẽ lại khi idle; spike ~18 ms khi rig đánh lần đầu (raster phần rig); test UI phá/sửa làng/gọi hồn qua click, phím tắt, save giữa ván; đo hiệu năng trên điện thoại thật (web/iOS).
- [ ] Cờ `nobattle` không còn tác dụng (battle_view đã xoá) nhưng còn trong lệnh probe / docs/rig_port.md: dọn.
