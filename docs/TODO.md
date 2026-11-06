# TODO

## Cân bằng / nhịp chơi
- [ ] **m14 Rút Về Cấm Khê quá khó** (2026-11-06: một phần do bug AI đứng mãi trên ô đích khi tướng mua lại ở đó — đã sửa, golden 3 ván m14 timeUp -> reached; đo lại): sim AI-vs-AI ta thắng 3/12 (AI `31a006e`; trước đổi nhịp quân, AI cũ: 1/12), phần lớn `timeUp` (hết 13 lượt, tướng chưa tới ô đích). Thử: tăng `turns`, bớt đợt địch, hoặc xem AI phe ta có đi thẳng tới đích không. Có từ trước, không do đổi nhịp quân.
- [ ] **Chơi thử nhịp ra quân mới** (`docs/content.md` mục "Nhịp ra quân mới"): người thật chơi m03–m05 + m09–m13, xem có kịp quen quân cũ trước khi gặp quân mới không. Sim AI không đo được việc học quân.
- [ ] Sau mỗi lần đổi AI (`scripts/core/ai.gd`): chạy lại `bash tools/sim_many.sh "m01 … m16" 12 8` + cập nhật bảng cân bằng README (số hiện tại đo với AI `31a006e`).

## Chất lượng code
- [x] Lint (2026-11-06): gdtoolkit 4.5.0 `gdlint` + Godot warnings = error + `tools/lint.sh` + pre-commit (`tools/install_hooks.sh`). README "Lint".
- [ ] **Siết lint theo giai đoạn** (mỗi giai đoạn 1 commit; sau mỗi bước: tests + click_driver + rig_smoke + golden giống hệt):
  1. **Kiểu chặt cho `scripts/core`** (luật / AI, ít UI, lỗi kiểu ở đây = sai luật): sửa `untyped_declaration`, `unsafe_call_argument`, `unsafe_method_access`, `unsafe_property_access` trong core -> bật mức error chỉ cho core (`@warning_ignore` / bật theo thư mục nếu Godot cho, không thì check riêng core trong `tools/lint.sh`).
  2. Cảnh báo ít, dễ sửa -> error toàn repo: `integer_division` (18), `incompatible_ternary` (19), `narrowing_conversion` đã bật; `shadowed_variable` (29), `shadowed_global_identifier` (11), `shadowed_variable_base_class` (44).
  3. Kiểu chặt cho `content/`, `sim/`, rồi `scripts/ui/rig`, cuối cùng `scripts/ui` còn lại (game_screen sau khi tách = E5).
  4. `return_value_discarded` (~292): xem từng loại (tween / connect / erase thường bỏ qua có chủ đích) -> chỉ bật nếu ồn ít.
  5. `gdlintrc`: `max-line-length` 180 -> 150 -> 120 (sửa dần file đang đụng); bật lại `class-definitions-order`; `max-file-lines` 2200 -> 1000 sau khi tách game_screen / board.
  - Số hiện tại (2026-11-06, toàn repo): unsafe_call_argument ~1655, unsafe_method_access ~411, return_value_discarded ~292, unsafe_property_access ~173, untyped_declaration 162 dòng lỗi, shadowed_* ~84, unsafe_cast 20, incompatible_ternary 19, integer_division 18. Đếm lại: bật 1 cảnh báo = 2 trong `project.godot` [debug] rồi `tools/lint.sh`.
- [ ] Formatter: `gdformat` 4.5.0 hỏng với lambda nhiều dòng -> thử GDScript Formatter (GDQuest, Rust; cần build / tải binary, hỏi user) hoặc đợi gdtoolkit sửa.
- [x] Code review 2026-11-06 backlog: hiệu năng P1–P8 (trừ P9), mở rộng E2/E3/E4/E7, tái sử dụng R1–R5 — merged e5a3520.
- [ ] Còn lại từ review (`docs/review/code_review_2026-11-06.md`): E1 nhiều phe / đồng minh, E5 tách `game_screen.gd`, E6 i18n; P9 vẽ lại khi idle; spike ~18 ms khi rig đánh lần đầu (raster phần rig); test UI phá/sửa làng/gọi hồn qua click, phím tắt, save giữa ván; đo hiệu năng trên điện thoại thật (web/iOS).
- [ ] Cờ `nobattle` không còn tác dụng (battle_view đã xoá) nhưng còn trong lệnh probe / docs/rig_port.md: dọn.
