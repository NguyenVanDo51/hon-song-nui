# TODO

## Cân bằng / nhịp chơi
- [ ] **m14 Rút Về Cấm Khê quá khó** (2026-11-06: một phần do bug AI đứng mãi trên ô đích khi tướng mua lại ở đó — đã sửa, golden 3 ván m14 timeUp -> reached; đo lại): sim AI-vs-AI ta thắng 3/12 (AI `31a006e`; trước đổi nhịp quân, AI cũ: 1/12), phần lớn `timeUp` (hết 13 lượt, tướng chưa tới ô đích). Thử: tăng `turns`, bớt đợt địch, hoặc xem AI phe ta có đi thẳng tới đích không. Có từ trước, không do đổi nhịp quân.
- [ ] **Chơi thử nhịp ra quân mới** (`docs/content.md` mục "Nhịp ra quân mới"): người thật chơi m03–m05 + m09–m13, xem có kịp quen quân cũ trước khi gặp quân mới không. Sim AI không đo được việc học quân.
- [ ] Sau mỗi lần đổi AI (`scripts/core/ai.gd`): chạy lại `bash tools/sim_many.sh "m01 … m16" 12 8` + cập nhật bảng cân bằng README (số hiện tại đo với AI `31a006e`).

## Chất lượng code
- [ ] **Lint + format GDScript** (chốt 2026-11-06; làm SAU khi xử lý xong 5 báo cáo review, vì format lệch số dòng):
  1. Cài `pipx install "gdtoolkit==4.*"` (gdlint + gdformat; hỏi user trước khi cài lên máy).
  2. Chạy thử toàn repo, đếm lỗi theo loại -> viết `gdlintrc` (nới `max-file-lines` / `max-function-length` lúc đầu, siết dần).
  3. Bật cảnh báo Godot = error trong `project.godot` (`debug/gdscript/warnings/*`: untyped_declaration, unused_variable, unused_parameter, ...).
  4. `gdformat` toàn repo trong 1 commit riêng, chỉ style -> chạy lại tests + click_driver + rig_smoke.
  5. `tools/lint.sh` + git pre-commit hook (`gdformat --check` + `gdlint`); ghi cách dùng vào README "Kiểm tra".
  - Phương án khác nếu gdtoolkit chậm / thiếu cú pháp 4.7: GDScript Formatter của GDQuest (Rust, có linter).
- [x] Code review 2026-11-06 backlog: hiệu năng P1–P8 (trừ P9), mở rộng E2/E3/E4/E7, tái sử dụng R1–R5 — merged e5a3520.
- [ ] Còn lại từ review (`docs/review/code_review_2026-11-06.md`): E1 nhiều phe / đồng minh, E5 tách `game_screen.gd`, E6 i18n; P9 vẽ lại khi idle; spike ~18 ms khi rig đánh lần đầu (raster phần rig); test UI phá/sửa làng/gọi hồn qua click, phím tắt, save giữa ván; đo hiệu năng trên điện thoại thật (web/iOS).
- [ ] Cờ `nobattle` không còn tác dụng (battle_view đã xoá) nhưng còn trong lệnh probe / docs/rig_port.md: dọn.
