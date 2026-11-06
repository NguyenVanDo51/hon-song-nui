# TODO

## Cân bằng / nhịp chơi
- [ ] **m14 Rút Về Cấm Khê quá khó** (2026-11-06: một phần do bug AI đứng mãi trên ô đích khi tướng mua lại ở đó — đã sửa, golden 3 ván m14 timeUp -> reached; đo lại): sim AI-vs-AI ta thắng 3/12 (AI `31a006e`; trước đổi nhịp quân, AI cũ: 1/12), phần lớn `timeUp` (hết 13 lượt, tướng chưa tới ô đích). Thử: tăng `turns`, bớt đợt địch, hoặc xem AI phe ta có đi thẳng tới đích không. Có từ trước, không do đổi nhịp quân.
- [ ] **Chơi thử nhịp ra quân mới** (`docs/content.md` mục "Nhịp ra quân mới"): người thật chơi m03–m05 + m09–m13, xem có kịp quen quân cũ trước khi gặp quân mới không. Sim AI không đo được việc học quân.
- [ ] Sau mỗi lần đổi AI (`scripts/core/ai.gd`): chạy lại `bash tools/sim_many.sh "m01 … m16" 12 8` + cập nhật bảng cân bằng README (số hiện tại đo với AI `31a006e`).

## Tính năng
- [x] **Chế độ 1 đấu 1** (`docs/1v1.md`, 2026-11-06): người–người chung máy (màn chuyển tay) + người–máy; bước 1–3 xong.
  - [ ] Bước 4: gắn preset Dễ / Thường / Khó vào `Content.ai_params_for` (1 dòng, xem `docs/1v1.md` "Móc độ khó") + đo tỉ lệ thắng.
  - [ ] Online: relay chuỗi step + hash.
- [ ] **AI luyện bằng tự đấu**: bảng tham số AI + `sim/tune.gd` (agent đang làm, kèm sửa lính ít máu nằm góc không về hồi máu).

## Chất lượng code
- [x] Lint (2026-11-06): gdtoolkit 4.5.0 `gdlint` + Godot warnings = error + `tools/lint.sh` + pre-commit (`tools/install_hooks.sh`). README "Lint".
- [x] **Siết lint theo giai đoạn** (2026-11-06, xong): 1 core kiểu chặt; 2 int division / ternary / shadowing = error; 3 kiểu chặt content / sim / tools / ui (5 agent song song); 4 `return_value_discarded` quyết định TẮT (267 chỗ, >90% chủ ý; lỗi IO đã kiểm tay: save_png / FileAccess / store_string / load_svg); 5 gdlintrc dòng ≤ 150 + class-definitions-order bật. `tools/warn_count.sh` = 0 toàn repo; tests 80/80, golden giống hệt, driver 0 fail, rig smoke 132/0.
  - [ ] Còn: `max-file-lines` 2300 -> 1000 sau khi tách game_screen (E5, ~2220 dòng sau 1 đấu 1; đã tách widget HUD ra `hud_widgets.gd`; agent đã gộp ~50 cặp biến bằng `;` để vừa giới hạn cũ -> tách xong thì bỏ), board.gd ~1150, tests.gd ~1050.
  - [ ] Click driver dùng chung profile "driver" -> chạy song song nhiều worktree thì 2 check save/briefing lỗi ngẫu nhiên: cho profile theo tham số (vd `profile=driver_<pid>`).
- [ ] Formatter: `gdformat` 4.5.0 hỏng với lambda nhiều dòng -> thử GDScript Formatter (GDQuest, Rust; cần build / tải binary, hỏi user) hoặc đợi gdtoolkit sửa.
- [x] Code review 2026-11-06 backlog: hiệu năng P1–P8 (trừ P9), mở rộng E2/E3/E4/E7, tái sử dụng R1–R5 — merged e5a3520.
- [ ] Còn lại từ review (`docs/review/code_review_2026-11-06.md`): E1 nhiều phe / đồng minh, E5 tách `game_screen.gd`, E6 i18n; P9 vẽ lại khi idle; spike ~18 ms khi rig đánh lần đầu (raster phần rig); test UI phá/sửa làng/gọi hồn qua click, phím tắt, save giữa ván; đo hiệu năng trên điện thoại thật (web/iOS).
- [ ] Cờ `nobattle` không còn tác dụng (battle_view đã xoá) nhưng còn trong lệnh probe / docs/rig_port.md: dọn.
