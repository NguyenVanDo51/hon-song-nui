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

## 2026-11-05 — cảnh giao chiến (máy macOS)
- Người dùng muốn "đánh thì chuyển màn khác giống game gốc (bật/tắt được)" + nhiều hiệu ứng hơn.
- (Đã xoá 2026-11-06: cảnh cắt ngang `battle_view.gd` + cài đặt 3 chế độ; mọi đòn đánh chơi trên bàn cờ, có zoom + rig.)
- macOS: `tools/run_guarded.sh` thay cho run_guarded.ps1. Đã chạy: tests 43/43, click_driver 35/35, bot có cửa sổ m05 (đêm) / m07 / m12 / m15 chụp màn hình. Chưa thử bản web (web_smoke cần Edge trên Windows).
- Máy này không có remote: người dùng tự đẩy từ máy khác.

## 2026-11-05 — review 4 mảng + sửa (máy macOS)
4 agent review (lõi/AI, vẽ/hiệu năng, cấu trúc UI, luồng/UX). Đã sửa + commit:
- UI: thắng rồi thoát ngay vẫn giữ kết quả; đầu lượt input chỉ mở sau hoạt cảnh; lưu ngay sau mỗi lệnh / bước AI; `_clear_sel`; chữ giao diện + kiểu thắng / kết thúc / ghi chú ô từ theme; kiểm bản lưu theo phiên bản + loại quân; driver dùng hồ sơ `driver`.
- Lõi: `Game.use_tables` + `sim/legacy/rules.gd` + `sim/legacy/golden.txt` (194 ván) + `sim/parity.gd`; `do_action` không làm dở; AI nhớ bản đồ khoảng cách (nhanh ~25–55%, nước đi y hệt); RNG riêng cho AI theo ván/lượt; `raiseCap`.
- UX: khung 1280x720 + tỉ lệ tối thiểu 0.8 + màn xoay ngang; Đánh tiếp lên đầu; hỏi trước khi ghi đè ván; cảnh đánh 3 chế độ; tua lượt địch; Space giữ chỗ; Hết lượt nhắc khi còn việc; Đánh lại; số liệu ta/địch rõ; mẹo khi thua; Sách lính có Địa hình.
- Vẽ: agent riêng (bake địa hình, cache token, cỡ chữ cố định, âm thanh dựng sẵn, sửa icon mất trong cảnh đánh, màn dọc cho cảnh đánh) — xem commit sau.
Còn để dành: ô thông tin chiến dịch bấm được + nhãn dự báo "→ còn X" (đụng file vẽ, làm sau khi agent vẽ xong).

## 2026-11-05 — bộ hình chibi 2D (máy macOS)
- 2D mặc định (`Store.board_3d` = false); 3D vẫn bật được ở ⚙. 3D: camera 45°, hạ chiều cao thành / núi / cây.
- Bộ chibi tự vẽ (SVG tay, 15 sub-agent theo `scratchpad/chibi_style.md`): 9 loại quân x 2 phe + 2 tướng, địa hình đồng / sông / cầu / rừng / đồi / núi, làng + thành x 3 chủ (n/p/e).
- Vẽ: `Token.raster(path, px)` dựng SVG đúng cỡ điểm ảnh (bậc 8 px, cache) -> không mờ mipmap, kể cả lúc zoom đánh. `Board._tile_art`: 2 biến thể / loại theo hash ô, cầu xoay 90° khi qua sông ngang; đường mòn + bờ cát + sóng vẫn vẽ code.
- Đã chạy: tests 51/51, click_driver fails=0, bot m02 có zoom chụp màn hình.

## 2026-11-05 — làng hỏng (theo AE2 bản Java)
- Ô `x` = làng hỏng: không chủ, không vàng, không hồi máu, thủ 15 như làng. Đặt sẵn: m10 (2), m11, m12 (2), m14, m16, skirmish dong_bang (cặp đối xứng).
- Máy bắn đá (`raze`): chưa đi trong lượt, phá làng địch / chưa ai chiếm trong tầm 2–4, không có quân đứng -> `x`. Thành không phá được.
- Bộ binh / tướng (`capV`) đứng trên `x` -> "Sửa làng" (hết lượt) -> làng chưa ai chiếm, lượt sau mới chiếm.
- AI: máy bắn đá chỉ phá làng của đối phương khi không có đòn tốt hơn; lính coi làng hỏng là đích, sửa rồi chiếm.
- UI: chọn máy bắn đá -> làng phá được viền cam; bấm làng = nhắm (viền vàng) + popup "💥 Phá làng"; bấm lần nữa = phá. Đá bay, làng chỉ đổ khi đá rơi (`view.hold`).
- Kiểm: tests 54/54, click_driver fails=0, kịch bản bấm phá + sửa (scratchpad p_raze.gd) 0 lỗi, AI-vs-AI m07/m08/m10/m12/m16 có raze + repair, trace 160 ván chiến dịch y hệt trước khi đổi.
- Báo cáo (scratchpad, local): `rules_compare.html` (56 khác biệt với AE2), `ip_review.html` (rủi ro bản quyền).

## Bố cục HUD không che bản đồ
- `GameHud._layout()` / `place_hud()` (game_hud.gd): bản đồ full màn, HUD nổi trên bản đồ. Không chọn gì -> lượt/vàng/mục tiêu (trên trái), ⏩ ⚙ (trên phải), Hết lượt (dưới phải). Chọn quân / ô -> ẩn hết, chỉ còn thẻ; thẻ ở góc trên trái, đổi sang trên phải (rồi dưới trái, dưới phải) nếu che ô đang chọn / ô đích (`card_avoid`). Probe: `sim/probes/hud_shot.gd`.
- Chỉ popup lệnh + menu ⚙ còn nổi trên bản đồ. 1280x720: ô 64–68px (trước ~71).
- Kiểm: 1280x720 / 1500x675 (điện thoại ngang) / dọc, 2D + 3D: 0 ô HUD đè bản đồ; tests 54/54, click_driver fails=0.

## 2026-11-06 — luật đưa về AE2 (yêu cầu: "sửa hết mọi điểm khác")
- Nguồn: `docs/review/rules_compare.html` (82 điểm). Quyết định của chủ game: Kỵ binh -> **Rồng** (chỉ số Dragon, bay); thêm **Thủy binh** (Elemental) + **Chó săn** (Dire Wolf); bỏ phần tự thêm không có ở gốc (incomeMul, mộ đặt sẵn, heroMustLive, cách đi riêng của tướng); thêm ô **Đền** `t`; 3–4 phe + nhiều tướng: đợt sau.
- Giữ kiểu màn chiến dịch (castles/rout/hero/survive/reach + waves): AE2 chiến dịch cũng có mục tiêu theo kịch bản + quân phục kích (mục L3).
- Đã làm: chỉ số + giá theo AE2 (công min–max), địa hình (đồng 5, đồi 10, núi 15/3 cho mọi quân, sông lội 3 / thủ 0, cầu 5, thành 15), thu nhập 30/50, sát thương ngẫu nhiên có seed (`s.rng`, `Game.fixed_roll` cho test) + sàn 0, đánh trả chỉ khi kề + rmin 1, KN/cấp (tối đa 9, +2/+2, 1 cấp/trận, dư mang sang), tên cấp mỗi 2 cấp, hào quang trống đóng dấu 1 lượt tầm 2, độc chó săn, thưởng vs rồng / vs âm binh / dưới nước, âm binh không tính trần, mộ ttl 3 trừ mỗi đầu lượt mỗi bên + bước lên là mất, tướng mua lại 200+200/lần chết (tối đa 1000) giữ cấp, thua = mất hết thành + tướng chết (hoặc hết quân + hết thành), mua xong đi ngay + mua trên thành có quân (`buyAE2`), đấu tự do chọn vàng / trần quân.
- Chưa xác nhận bản gốc (lấy theo mã bản mod): công thức KN (×200/3), +15 nỏ vs bay, rồng được thủ địa hình, độc không giảm bước đi, Wisp tầm 1–2.
- Hồi quy: `sim/legacy` + parity JS bỏ; `sim/golden.txt` mới. Lưu ván cũ (v2) bị từ chối (STATE_V 3).
- Tiện ích dò lỗi: `sim/probes/stall.gd <màn>` (ván AI-vs-AI kẹt), `sim/probes/units_shot.gd` (ảnh đủ quân mới).

## 2026-11-06 — mở rộng (review E7 / E3 / E2 / E4), hành vi giữ nguyên
- E7: xoá `battle_view.gd` + cài đặt cảnh đánh 3 chế độ; mọi đòn đánh trên bàn cờ (zoom + rig).
- E3: cờ dữ liệu trong `UNITS`: `heavy`, `aiWeight` (thiếu -> `AI.DEFAULT_WEIGHT`), `aiValue`, `aura` / `poison` (lượng lưu trên quân: `auraAtk` / `poisonAmt`, lưu ván v4, v3 tự nâng), `raise: "ghost"`, `vsType`. Thưởng mua của AI theo cờ.
- E2: công trình theo mô tả `TERRAIN` (`income`, `cap`, `heals`, `sells`, `razeTo`, `repairTo`/`repairBy`); thu nhập = tổng ô đang giữ.
- E4: `scripts/core/objectives.gd` (registry kiểu mục tiêu).
- Cách thêm quân / công trình / mục tiêu: `docs/content.md`. Golden y hệt sau mỗi bước.
- Chưa làm (để sau): E1 N phe / đồng minh, E6 i18n. Tầm hào quang (2) vẫn cứng ở `game.gd` + `board.gd` (AE2 cố định).

## 2026-11-06 — sao màn + vùng địch đánh tới (nhánh `feat/stars-threat`)
- Nguồn: research thể loại `docs/review/genre_hooks.html` (main checkout, chưa commit) -> đợt 1 chọn: sao màn + vùng địch.
- Sao: `scripts/core/stars.gd`, `s.lost`, `Store.stars_of`, thẻ thắng + bản đồ chiến dịch. Mốc sao 3 = trung vị sim AI-vs-AI 12 ván (m08 hạ 30 -> 25).
- Vùng địch: `Game.threat_tiles` + `board.gd` (tô đỏ / viền / dấu !); thẻ thắng ở `game_cards.gd`, tính sao ở `turn_driver.gd` `finish`. Chỉ 2D.
- Kiểm: tests 96/96 (sau rebase lên master 20fae2e), click driver 0 lỗi, ảnh probe `sim/probes/stars_threat_shot.gd` (3 sao + cung / máy bắn đá / rồng). Chưa chụp được thẻ 1–2 sao (màn hình tắt -> cửa sổ Godot treo).
