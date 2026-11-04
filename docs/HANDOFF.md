# HANDOFF — trạng thái làm việc (đọc trước khi làm tiếp)

Yêu cầu người dùng (2026-11-04 tối): làm tiếp phần đang dở, rồi **tự thiết kế + làm thêm cho đủ chương, đủ game**, và khi họ quay lại (vài tiếng) game phải **sẵn sàng release bản web**. Không hỏi lại, tự quyết.

## Kế hoạch
1. [x] Kiểm tra đường bấm chuột người chơi (driver giả lập click: chọn lính, Chờ/Hủy/Đánh/Mua, gợi ý, hết lượt, đánh tiếp, màn tiếp). Driver ở scratchpad `click_driver.gd`; sửa lỗi tìm được.
2. [ ] Font cho web: web không có font hệ thống -> bundle font emoji + ký hiệu (subset Noto Color Emoji / Noto Sans Symbols 2 chỉ các glyph game dùng) làm fallback cho mọi font.
3. [ ] Hệ chương: nội dung chia chương (mỗi chương: tiêu đề, bản đồ sơ đồ, phe địch có thể đổi tên/skin, chữ "Lượt quân …"). Menu chiến dịch chọn chương; chương sau mở khi xong chương trước.
4. [ ] Chương 2 "Chống Mã Viện" (năm 42–43): ~8 màn, tướng mới (Thánh Thiên, Bát Nàn, Phùng Thị Chính), địch Mã Viện / Lưu Long / Đoàn Chí. Kiểu thắng mới `reach` (đưa tướng tới ô) cho màn rút quân. Kết bi tráng ở Hát Giang + lời kết.
5. [ ] Chương 3 "Bà Triệu" (năm 248): ~6–8 màn, phe địch Đông Ngô (đổi skin địch theo chương), tướng Bà Triệu (cưỡi voi), Triệu Quốc Đạt; địch Lục Dận.
6. [ ] Cân bằng mọi màn mới bằng `sim/sim.gd` (AI phe ta thắng ~40–95% tùy độ khó, trung vị lượt hợp lý), test nội dung qua `sim/tests.gd`.
7. [ ] Web export: templates 4.7.2 (đang tải về `%TEMP%\hsn_dl\tpl.tpz`, giải nén web_* vào `%APPDATA%\Godot\export_templates\4.7.2.stable\`), preset Web không thread (host được ở itch.io / GitHub Pages không cần header COOP/COEP), xuất `build/web/`, chạy thử bằng http server + Chrome, đóng gói zip.
8. [ ] README + docs cập nhật, commit từng bước.

## Ghi chú
- Lệnh dài (trace, sim nhiều màn, tải file) chạy tách rời (Start-Process) để sống qua restart phiên.
- Parity với JS chỉ áp dụng cho m01–m08 (chương 1). Thay luật không được đổi hành vi chương 1: chạy `sim/trace.gd -- only=m01` (vài phút) sau mỗi lần sửa core.
- **Nguyên nhân treo máy (đã sửa):** `Board._dashed` (đường đi nét đứt khi rê chuột) có `while` kẹt do bước số thực quá nhỏ, mỗi vòng thêm 1 lệnh vẽ -> tiến trình Godot 59.7 GB (Windows event 2004 lúc 19:30). Đã viết lại có trần vòng lặp; `camp_map._dashed` cùng lỗi, đã chặn. Mọi lần chạy Godot dùng `tools/run_guarded.ps1` (kill khi >1.5 GB hoặc quá giờ).
- `sim/click_driver.gd -- mission=m02 fresh` (chạy có cửa sổ): 22 bước bấm chuột qua, đỉnh 301 MB.
