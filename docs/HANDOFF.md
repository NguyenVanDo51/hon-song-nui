# HANDOFF — trạng thái làm việc (đọc trước khi làm tiếp)

Yêu cầu người dùng (2026-11-04 tối): làm tiếp phần đang dở, rồi **tự thiết kế + làm thêm cho đủ chương, đủ game**, và khi họ quay lại (vài tiếng) game phải **sẵn sàng release bản web**. Không hỏi lại, tự quyết.

## Kế hoạch
1. [x] Kiểm tra đường bấm chuột người chơi (driver giả lập click: chọn lính, Chờ/Hủy/Đánh/Mua, gợi ý, hết lượt, đánh tiếp, màn tiếp). Driver ở scratchpad `click_driver.gd`; sửa lỗi tìm được.
2. [x] Font cho web: web không có font hệ thống -> bundle font emoji + ký hiệu (subset Noto Color Emoji / Noto Sans Symbols 2 chỉ các glyph game dùng) làm fallback cho mọi font.
3. [x] Hệ chương: nội dung chia chương (mỗi chương: tiêu đề, bản đồ sơ đồ, phe địch có thể đổi tên/skin, chữ "Lượt quân …"). Menu chiến dịch chọn chương; chương sau mở khi xong chương trước.
4. [x] Chương 2 "Chống Mã Viện" (năm 42–43): ~8 màn, tướng mới (Thánh Thiên, Bát Nàn, Phùng Thị Chính), địch Mã Viện / Lưu Long / Đoàn Chí. Kiểu thắng mới `reach` (đưa tướng tới ô) cho màn rút quân. Kết bi tráng ở Hát Giang + lời kết.
5. [x] Chương 3 "Bà Triệu" (năm 248): ~6–8 màn, phe địch Đông Ngô (đổi skin địch theo chương), tướng Bà Triệu (cưỡi voi), Triệu Quốc Đạt; địch Lục Dận.
6. [x] Cân bằng mọi màn mới bằng `sim/sim.gd` (AI phe ta thắng ~40–95% tùy độ khó, trung vị lượt hợp lý), test nội dung qua `sim/tests.gd`.
7. [x] Web export: templates 4.7.2 (đang tải về `%TEMP%\hsn_dl\tpl.tpz`, giải nén web_* vào `%APPDATA%\Godot\export_templates\4.7.2.stable\`), preset Web không thread (host được ở itch.io / GitHub Pages không cần header COOP/COEP), xuất `build/web/`, chạy thử bằng http server + Chrome, đóng gói zip.
8. [x] README + docs cập nhật, commit từng bước.

## Ghi chú
- Lệnh dài (trace, sim nhiều màn, tải file) chạy tách rời (Start-Process) để sống qua restart phiên.
- Parity với JS chỉ áp dụng cho m01–m08 (chương 1). Thay luật không được đổi hành vi chương 1: chạy `sim/trace.gd -- only=m01` (vài phút) sau mỗi lần sửa core.
- **Nguyên nhân treo máy (đã sửa):** `Board._dashed` (đường đi nét đứt khi rê chuột) có `while` kẹt do bước số thực quá nhỏ, mỗi vòng thêm 1 lệnh vẽ -> tiến trình Godot 59.7 GB (Windows event 2004 lúc 19:30). Đã viết lại có trần vòng lặp; `camp_map._dashed` cùng lỗi, đã chặn. Mọi lần chạy Godot dùng `tools/run_guarded.ps1` (kill khi >1.5 GB hoặc quá giờ).
- `sim/click_driver.gd -- mission=m02 fresh` (chạy có cửa sổ): 22 bước bấm chuột qua, đỉnh 301 MB.

## Thiết kế đã chốt (phiên 2026-11-04 tối)
**Thao tác di chuyển-tấn công (người dùng yêu cầu):**
- Rê chuột lên địch khi đang chọn lính: vẽ đường tới ô đánh tốt nhất + nhãn xem trước "Gây X · Nhận Y" ngay trên bàn cờ; bấm 1 lần là đánh luôn (không cần bước xác nhận). Không có hover (cảm ứng) thì giữ 2 chạm như cũ.
- Đã đi tới ô (mode moved): bấm địch trong tầm -> đánh từ ô đó; bấm lại chính ô đích -> hành động mặc định (chiếm nếu được, không thì chờ).
- Thanh nút nhỏ nổi cạnh ô đích trên bàn cờ (⚔ / 🏠 / 🩹 / Chờ / Hủy) để khỏi rê sang bảng bên.
- Phím: Space/Enter = hành động mặc định, Tab = lính kế chưa đi, E = hết lượt, H = gợi ý, Esc = hủy.
**Hệ chương:** `content/chapters/cN.gd` (tiêu đề, năm, bản đồ sơ đồ, ghi đè skin phe địch + chữ "Lượt quân …", lời kết chương). Màn có trường `chapter`. Mở khóa vẫn tuần tự theo `order` toàn cục. Menu chiến dịch có tab chương.
**Luật mới (không ảnh hưởng chương 1):** win `reach` = tướng ta tới một ô trong `win.at` (tuỳ chọn `turns`: quá lượt là thua). AI phe ta nhắm ô đích.
**Chương 2 "Chống Mã Viện" (42–43), m09–m16:** Tin dữ Hợp Phố (Thánh Thiên, giữ) · Sóng An Biên (Lê Chân, diệt thủy quân) · Bát Nàn giữ ải (Bát Nàn bắn xa, chiếm thành) · Trận Lãng Bạc (Trưng Trắc vs Mã Viện) · Phùng Thị Chính (reach, thoát vây) · Rút về Cấm Khê (reach, Trưng Nhị) · Thành Cấm Khê (survive) · Sông Hát (survive, kết bi tráng).
**Chương 3 "Bà Triệu" (248), m17–m22:** Núi Nưa · Hai anh em (Triệu Quốc Đạt) · Đồn Bồ Điền · Voi một ngà · Lục Dận kéo quân · Núi Tùng (kết). Địch = Đông Ngô (ghi đè skin địch).
**Tướng mới:** ta: thanhthien (aura +10 công lính cạnh), batnan (bắn 1–2), phungthichinh (đi đồi núi), batrieu (công cao), trieuquocdat (lính cạnh +10 thủ); địch: mavien (aura), luulong (nhanh), doanchi (đi sông), lucdan (guard).
- Web: `powershell -File tools/export_web.ps1` -> build/web + build/hon-song-nui-web.zip (11 MB). `python tools/web_smoke.py --query "?mission=m05&bot&speed=3" --wait 70` chạy thật trong Edge headless (CDP), in console + chụp. Đã thấy tiêu đề + ván m05 (đêm) chạy trên WebGL2, không lỗi.
- Godot có cửa sổ bị kẹt khởi động khi màn hình tắt/máy vắng người -> khi chạy một mình chỉ dùng headless.
- Cân bằng (sim AI-vs-AI 12 ván/màn, `bash tools/sim_many.sh "m09 m10" 12 4`): đang chỉnh vòng 3. Màn "giữ vững" dễ thắng vì chỉ tướng địch chiếm được thành -> đã bớt quân/vàng ta, thêm đợt địch lượt 1.
- Đã thêm: 3 bản đồ đấu tự do (đối xứng), màn Ghi công, icon, tab "Quân địch" trong Sách lính.

## 2026-11-05 — vòng góp ý sau bản web đầu
Người chơi (chủ repo) góp ý, đã làm:
- Màn chiến dịch chỉ còn bản đồ (bỏ lưới thẻ); khung thông tin khi rê chuột lên điểm.
- Bỏ panel phải: mọi thứ trong một popup cạnh ô (lệnh, dự báo, mua lính, thông tin); nút Hết lượt cạnh bàn cờ.
- Buff hiện trên quân (chấm ⚔ cam / 🛡 xanh + vòng sáng), dự báo liệt kê mọi hệ số, ⓘ trên mọi quân, hoạt cảnh giới thiệu quân mới.
- Không còn "đi tại chỗ". Sửa đường đi bị mất đoạn khi đi xuyên quân ta (`Game.path_for`).
- Theo lối Ancient Empires (repo tham khảo: AncientTree/project_aeii): một bộ lính chung hai phe, một chỉ huy ta (Trưng Trắc) cả game, chỉ huy địch một tên mỗi chương cùng hình; bỏ chương 3; bản đồ có đường mòn `r` và địa hình gom khối (`sim/mapgen.gd`).
- Kiểm tra luật khớp JS chuyển sang nội dung đóng băng `sim/legacy/`.
