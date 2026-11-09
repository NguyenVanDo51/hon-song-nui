# Công Thành Chiến — quy tắc cho Claude

## Tài liệu: luôn đúng bản hiện tại
- `docs/STATUS.md` = game đang có gì (1 màn hình) + bảng "File sự thật" (mỗi mảng 1 file: bối cảnh `docs/setting.md`, luật `docs/spec.md`, nội dung `docs/content.md`, AI `docs/ai.md`, 1v1 `docs/1v1.md`, hình `docs/rig_port.md`, việc còn lại `docs/TODO.md`).
- Đổi thiết kế / thêm chế độ / đổi luật, tên, màu / phát hành build -> sửa `docs/STATUS.md` + file sự thật của mảng đó **trong cùng commit**. Merge vào master mà chưa sửa = chưa xong.
- `docs/HANDOFF.md` (nhật ký), `docs/superpowers/` (thiết kế theo ngày), `docs/review/` (phân tích) = lịch sử, không sửa lại cho khớp; điều đúng hiện tại phải nằm ở file sự thật.

## Chữ hiện ra: luôn 2 ngôn ngữ
- Câu mới / sửa câu hiện cho người chơi: viết tiếng Việt, trong `scripts/` bọc `Lang.t("…")` (khuôn có `%d` dịch trước, điền số sau) -> `python3 tools/i18n_extract.py` -> dịch `locale/en.po` theo thuật ngữ `docs/i18n.md`. Lint fail nếu thiếu.

## Nợ kỹ thuật: luôn ghi lại
- Mọi lần đọc code (bất kỳ task nào) thấy nợ kỹ thuật / rủi ro lỗi / rủi ro hiệu năng, dù nhỏ nhất, dù không liên quan task -> ghi ngay vào `docs/TODO.md` mục **"Nợ kỹ thuật"**.
- 1 dòng / mục: `- [ ] file:dòng — vấn đề -> hậu quả (cách sửa gợi ý nếu có)`. Ghi ngày phát hiện.
- Chỉ ghi, không tự sửa ngoài phạm vi task. Trùng mục cũ -> bổ sung mục cũ, không thêm dòng mới.
- Đã sửa -> đánh `[x]` + commit sửa.
- Báo user các mục mới ghi trong lần trả lời cuối của task.
