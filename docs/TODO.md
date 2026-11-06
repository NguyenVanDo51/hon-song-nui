# TODO

## Cân bằng / nhịp chơi
- [ ] **m14 Rút Về Cấm Khê quá khó**: sim AI-vs-AI ta thắng 3/12 (AI `31a006e`; trước đổi nhịp quân, AI cũ: 1/12), phần lớn `timeUp` (hết 13 lượt, tướng chưa tới ô đích). Thử: tăng `turns`, bớt đợt địch, hoặc xem AI phe ta có đi thẳng tới đích không. Có từ trước, không do đổi nhịp quân.
- [ ] **Chơi thử nhịp ra quân mới** (`docs/content.md` mục "Nhịp ra quân mới"): người thật chơi m03–m05 + m09–m13, xem có kịp quen quân cũ trước khi gặp quân mới không. Sim AI không đo được việc học quân.
- [ ] Sau mỗi lần đổi AI (`scripts/core/ai.gd`): chạy lại `bash tools/sim_many.sh "m01 … m16" 12 8` + cập nhật bảng cân bằng README (số hiện tại đo với AI `31a006e`).
