# Bối cảnh — nguồn duy nhất

Cập nhật 2026-11-09 (bối cảnh v2 vào game, nhánh `feat/setting-v2`). Đổi bối cảnh / tên phe / màu / tông -> sửa file này cùng commit.

## Nguyên tắc (user, 2026-11-08)
- Người chơi luôn bỏ qua truyện -> không truyện để đọc, không thoại, không cutscene. Bối cảnh phải hiểu qua hình.
- Ra App Store toàn cầu: giả tưởng chung (hiệp sĩ + pháp sư). Tông nghiêm túc. Chữ: Tiếng Việt + English (`docs/i18n.md`).
- Hai phe dùng chung bộ quân, cùng dáng (dễ làm quen); chỉ khác màu. Không lối đánh riêng cho từng tướng địch.

## Đang có trong game: Đế Quốc vs Ma Vương (user chốt 2026-11-09)
- Cốt (không có chữ kể, chỉ lộ qua hình + 1 câu mỗi level): đế quốc từng hùng mạnh; **Tướng quân Vorn** + bè phái cấu kết **Ma Vương**, chiếm **Kinh Đô**, tự xưng vua, nửa đế quốc theo hắn. Quân Đế Quốc (ta) đánh từ Biên Giới -> Vùng Sông -> Vùng Núi -> bị phản công, lùi về Pháo Đài -> tiến về Kinh Đô. Tháp Ma Vương sau Kinh Đô (trang trí; trận trùm cuối chưa làm).
- Lý do đổi (bỏ "Ngọn Lửa Lâu Đài"): 2 phe đều là người, không rõ thiện / ác -> "chiến tranh vô nghĩa".
- Phe (`content/theme.gd` `factions`):
  - `p` = **Quân Đế Quốc** / EN Imperial Army (ngắn "Quân ta", 1 đấu 1 "Đế Quốc"): **xanh dương** `#4f74c9` + bóng `#32508f` + viền vàng `#e2c36e`.
  - `e` = **Quân Ma Vương** / EN Demon Lord's Host (ngắn + 1 đấu 1 "Ma Vương"): bảng **A Máu & Đêm** = đỏ rượu `#8c1f3a` + tím đêm `#3d1238` + viền tím `#a77bd6`.
  - Đổi màu = `RigData.TEAM_SWAP` (= `tools/rig_export.mjs`): hình gốc là màu ta, địch = thay 3 màu đó; lâu đài / làng cũng vậy. Tên phe trên UI: `Style.P_NAME` (xanh) / `Style.E_NAME` (đỏ). 1 đấu 1: "Bên Xanh · đi trước" / "Bên Đỏ".
- Tướng: `anhhung` **Hiệp Sĩ Chỉ Huy** (áo choàng xanh viền vàng); `tuonggiac` **Vorn**, Tướng quân phản loạn (dáng V1: Hắc Hiệp Sĩ mũ sừng, áo choàng màu Ma Vương, **hào quang tím** = `Token.FOE_GLOW #b46bff`).
- Lính ngã: giữ như cũ (để còn gọi hồn), không tan khói (user).
- Bản đồ vương quốc: đất chưa lấy lại = tím tro, đất đã thắng = xanh lại, vùng chưa mở = mây giông tím, mái đỏ rượu = của Ma Vương, mái xanh = đã thắng.
- Bỏ: lửa / khói trên lâu đài (bàn cờ + màn tiêu đề), lửa bùng khi chiếm lâu đài.
- Chữ: câu dưới logo "Nửa đế quốc đã theo Ma Vương. Giành lại từng lâu đài."; 1 câu `lore` mỗi level (4 câu khiêu khích của Vorn: m02, m12, g16, g20); level đổi tên: m01 Lời Thề Biên Giới, m02 Trận Đầu Tiên, m08 Phủ Thành Cũ, g20 Ngai Vàng Kinh Đô.
- Icon iOS (`tools/make_ios_icon.gd`): lâu đài + tướng ta -> giờ màu xanh.
- Store (EN, chưa vào game): "Once a mighty empire. Its own general sold it to the Demon Lord — half the land has fallen. Take it back, castle by castle."

## Đã bỏ
- "Ngọn Lửa Lâu Đài" (2026-11-08 -> 2026-11-09): Quân Khởi Nghĩa (đỏ) vs Đế Quốc (xanh), lửa / khói trên lâu đài. Spec cũ `docs/superpowers/specs/2026-11-08-flame-premise-design.md`.
- Hai Bà Trưng / Đông Hán, chương, thoại, sử tích (bỏ 2026-11-07); tên địa danh Việt (bỏ 2026-11-08).
