# HANDOFF — trạng thái làm việc (đọc trước khi làm tiếp)

Yêu cầu người dùng (2026-11-04 tối): làm tiếp phần đang dở, rồi **tự thiết kế + làm thêm cho đủ chương, đủ game**, và khi họ quay lại (vài tiếng) game phải **sẵn sàng release bản web**. Không hỏi lại, tự quyết.


> 2026-11-07 · Reskin fantasy (kỵ sĩ & pháp sư, bỏ bối cảnh lịch sử Việt ở UI / quân / ô / âm thanh): nhánh `feat/fantasy-reskin` (từ `1a73512` của `feat/levels`), chưa merge. Spec + plan `docs/superpowers/{specs,plans}/2026-11-07-fantasy-reskin*`, kết quả `docs/review/fantasy_result.html`. Hình quân sinh từ `docs/anim_demo/*.spec.js` bằng `node tools/rig_export.mjs --svg`.

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
- Ô `x` = làng hỏng: không chủ, không vàng, không hồi máu, thủ 15 như làng. Đặt sẵn: m10 (2), m11, m12 (2), m14, m16, skirmish dong_bang, cua_bien (cặp đối xứng).
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
- Vùng địch: `Game.threat_tiles` + `board.gd` (tô đỏ / viền / dấu !); thẻ thắng ở `game_cards.gd`, tính sao ở `turn_driver.gd` `finish`.
- Kiểm: tests 96/96 (sau rebase lên master 20fae2e), click driver 0 lỗi, ảnh probe `sim/probes/stars_threat_shot.gd` (3 sao + cung / máy bắn đá / rồng). Chưa chụp được thẻ 1–2 sao (màn hình tắt -> cửa sổ Godot treo).

## 2026-11-07 — xoá bàn 3D
- Yêu cầu: "xoá hẳn code của màn 3D". Chỉ còn bàn 2D.
- Xoá: `board3d.gd`, `kit.gd`, `pieces.gd`, `kk.gd`, `shaders/water3d` + `team_tint`, `assets/kaykit/` (~19 MB, chỉ 3D dùng), nút "Bàn cờ 2D/3D" (menu chính + ⚙), cờ debug `3d=`, `Store.board_3d`, `FX.aim`, dòng ghi công KayKit.
- `BoardBase` giữ (gộp vào `board.gd` sẽ vượt trần 1000 dòng); chỉ còn `Board` kế thừa. Khoá cài đặt `board3d` cũ trong `user://hsn.cfg` bị bỏ qua.
- Lấy lại: git history.

## 2026-11-07 — Thử thách (nhánh `feat/levels`, chưa merge)
- Yêu cầu user: bỏ cốt truyện + chương, game cờ chơi theo level (MVP 30–50), Claude làm hết, user chỉ chơi thử. Thiết kế `docs/superpowers/specs/2026-11-07-levels-design.md`, kế hoạch `docs/superpowers/plans/2026-11-07-levels.md`.
- Đã làm: bỏ thoại / sử tích / nhân vật / chương / bản đồ chiến dịch; lưới "Thử thách" (`scripts/ui/level_select.gd`: chạm 1 lần = xem, chạm lại / "Vào trận" = chơi); `content/levels/` (m01–m16 giữ id, order ×10; g01–g20 vẽ bằng `sim/levelgen.gd`); `tier` + `ai` (normal / hard) mỗi level; mở khóa = level xa nhất đã thắng + 1; skill `.claude/skills/level-maker`.
- Không sửa logic bot (user đang đo bot).
- Cân bằng (bot phe ta vs bot level, 12 ván / level, 4 lượt): Dễ ≥ 10/12 · TB 7–9 · Khó 4–6. Kết quả 36 level: 24 Dễ, 8 TB, 4 Khó (g03, g11, g17, g20). Chỉnh bằng vàng: m02 / m12 (màn ra mắt đo ra Khó) + m08 (27 lượt, 3 ván hòa) dễ lại; g01–g20 theo nhãn định đặt. Mốc sao = trung vị lượt thắng / lính mất. Bảng đầy đủ: `docs/content.md` § "Nhịp ra mắt".
- Bot Khó v3 (merge 3ef121a) mạnh hơn v2: đo lại g11 / g17 / g20 (bot hard) -> g11 2/12, g20 3/12 -> tăng vàng phe ta (g11 950, g20 1500) -> 5/12, 6/12; g17 4/12 giữ nguyên. Vàng phe địch gần như không đổi kết quả với v3. 2026-11-08: `hard` += `AI.HERO_FIX` (sửa lỗi tướng) -> đo lại g11 / g17 / g20, số ở `docs/TODO.md`.
- Lưu ý: bot phe ta được lợi thế vàng vốn cho người -> màn tay hầu hết ra "Dễ"; nhãn thật cần user chơi thử.
- Việc sau: `docs/TODO.md` § "Thử thách".

## 2026-11-07 — hướng dẫn cầm tay + nhiệm vụ + popup quân bằng cảnh diễn (nhánh `feat/tutorial-quests`, chưa merge)
- Spec `docs/superpowers/specs/2026-11-07-tutorial-quests-design.md`, plan `docs/superpowers/plans/2026-11-07-tutorial-quests.md`.
- Nhiệm vụ: `scripts/core/quests.gd` (verb registry, `for_level` = `def.quests` + DEBUT quân mới trong `content/guide.gd`, chỉ campaign + ván mới). Thiếu nhiệm vụ -> thắng nhưng −1 ★ (sàn 1) qua `Stars.final`. Không có nhiệm vụ địa hình (user). Chỉ t01 t02 m01–m04 m10 + màn có `newUnits` có nhiệm vụ.
- UI: `quest_panel.gd` góc trên phải (1 dòng, chạm bung, mờ + bấm xuyên khi che, ẩn khi chọn quân); `intro_stage.gd` popup quân = 6 ô diễn đi + đánh (sinh từ cờ quân, không dạy mẹo); `tutorial.gd` + `shaders/tut_hole.gdshader` tối + lỗ + tay + 1 dòng, ⚙ Bỏ qua hướng dẫn.
- Màn: `content/levels/t01.gd` (order 1), `t02.gd` (order 2, không quân địch). Vòng "màn tiếp" = màn chưa thắng sau màn xa nhất đã thắng.
- Kiểm: tests 156/0, lint ok, click_driver m02 (có / không intro) / t01 / t02 fails=0; ảnh probe `intro_shot.gd`, `hud_shot.gd`.
- Nợ mở: `docs/TODO.md` § Nợ kỹ thuật (golden cũ, tên màn m01–m16 còn sử Việt, `_eff` hết địch trong tầm, font thiếu ❤🪙…).

## 2026-11-08 — hướng dẫn v2: t01–t03 kiểu LoL (nhánh `feat/tutorial-v2`, merged master 2026-11-08)
- Lý do (user): bạn chơi thử không biết đi quân / mục tiêu; hay quên Hết lượt; không biết 1 lượt đi được mọi quân. Spec `docs/superpowers/specs/2026-11-08-tutorial-v2-design.md`.
- 3 màn chỉ tướng + vệ binh: t01 Bài Học Đầu (đi quân, quân xám, Hết lượt, địch tới bằng `waves`, đánh, đánh trả, dồn quân; thắng rout), t02 Lâu Đài Trống (tướng chiếm lâu đài trống, rừng thủ, hạ hết địch = thắng), t03 Chiêu Binh (mua ở lâu đài, chiếm làng, hồi máu, Hết lượt sớm). Chi tiết `docs/content.md` § Hướng dẫn.
- `tutorial.gd`: bước `card` (thẻ tiêu đề + chữ + ▶ Đã hiểu / Space), chữ dài tự xuống dòng, chờ banner lượt, nhắc Hết lượt khi mọi quân xám + 2,5 s.
- Kiểm: tests 190/0 (đi hết bước + bot thắng 8 seed / màn), golden tạo lại (chỉ dòng t01–t03 đổi), lint ok, click_driver m02 0 fail, `sim/tut_driver.gd` t01/t02/t03 0 fail (1280x720 + 1688x780). `sim/probes/tut_shot.gd` xoá (tut_driver chụp từng bước).
- Sau đó (user): t01–t03 không hiện thẻ giới thiệu quân (bắt đầu từ m01); nhắc Hết lượt chỉ ở t01 + t02 (`nudgeEnd`). Driver: `mission=m01 fresh tutcheck`.

## 2026-11-08 — màn dọc (nhánh `feat/portrait`, merged master 2026-11-08)
- Yêu cầu user: màn dọc trên mobile = xoay bàn như cờ tướng (quân đỏ tiến lên trên), không vẽ lại bản đồ.
- Cách làm: `Board.rot` (màn cao > rộng + `auto_rotate`, chỉ bàn trận chính) -> Board `rotation = -90°`; hình học (cỏ, sông, đường, vùng tô, đường đi, mũi tên bay) xoay theo bàn; vật đứng (lính, nhà, cây / đồi / núi, chữ, huy hiệu) dựng thẳng bằng `up_xf(tâm ô)`; rig tấn công đặt trên ô màn hình (`vis_tile`) + vẽ qua `vis_xf()` (rig compose `Draw.xf`). Hướng mặt / đòn lao / knock đổi qua `scr()`. Chạm ô: Godot tự đổi toạ độ; `tile_rect` = `get_transform() * rect`.
- HUD: `Board.place / visual_size / visual_rect`. Tỉ lệ UI dọc = như khung 720x1280 (`Main._fit_scale`). Bỏ màn "xoay ngang". `orientation=6` (sensor), PWA any.
- Menu dọc: lưới Thử thách xếp chi tiết dưới lưới (`BoxContainer.vertical`; HBox không đổi hướng được), Sách lính tab xuống dòng, đấu tự do / 1 đấu 1 hàng tự xuống dòng (`HFlowContainer`).
- Kiểm: tests 189/0; click_driver có cửa sổ 540x1170 m02 / m02 intro / t01 fails=0 (headless bỏ qua --resolution); `sim/probes/portrait_shot.gd` (chọn ô khớp 100% + xoay máy giữa trận ngang <-> dọc), safe_shot dọc 15/15.
- Còn lại: `docs/TODO.md` § Tính năng "Màn dọc" (đá máy bắn đá cong ngang, fx bay lên, màn tiêu đề).

## 2026-11-08 — tiền đề "Ngọn Lửa Lâu Đài" (nhánh `feat/flame-premise`)
- User: luôn bỏ qua truyện; ra store toàn cầu; giả tưởng chung, bỏ chất Việt; nghiêm túc, khởi nghĩa vs Đế Quốc; không làm lối đánh riêng cho tướng địch. Spec `docs/superpowers/specs/2026-11-08-flame-premise-design.md`.
- Làm: `lede` dưới logo; `lore` 1 câu / màn ở lưới chọn màn (+ 4 câu khiêu khích của Vorn); tướng địch tên Vorn; đổi tên 36 màn m*/g* (+ `sim/level_recipes.gd`); lửa / khói trên lâu đài (bàn cờ + tranh tiêu đề); "🔥 N/39 ngọn lửa đã thắp".
- Kiểm: tests 190/0, lint ok, golden không đổi (172 dòng), click_driver m02 0 fail, tut_driver t02 0 fail; ảnh 1280x720 + 540x1170 (bàn cờ, tiêu đề, lưới chọn màn).
- Chưa: câu store tiếng Anh chỉ ở spec (dịch = việc riêng); tên game "Công Thành Chiến" chưa đổi.
- Sau đó (user): màn Thử thách = bản đồ vương quốc như bản đồ chiến dịch cũ (`camp_map.gd` xoá 2026-11-07 làm mẫu): vùng đã chiếm lại / chưa, chạm = thẻ ít chữ, "Xuất quân" vào thẳng (vẫn hỏi nếu đang dở ván khác). `scripts/ui/world_map.gd` + `content/world_map.gd`; `LevelSelect` chỉ còn helper tĩnh. Kiểm: tests 191/0 (+ test địa lý), click_driver m02 (bấm chuột thật: chạm điểm, kéo) + tut_driver t02 0 fail; ảnh `sim/probes/levels_shot.gd -- ... done=12 sizes=1280x720,844x390,540x1170`.
- Vòng 2 (user: "chưa chọn đã hiện popup", "chọn thì bị cuộn xuống dưới cùng", "map đẹp, chi tiết hơn"): không thẻ lúc mở; lỗi cuộn = thẻ dựng khi đang ẩn -> nhãn tự xuống dòng đo ở bề rộng 0 -> thẻ cao 1139 px -> `_reveal` đẩy bản đồ lên; sửa: dựng khi hiện + đặt thẻ theo `get_combined_minimum_size` (click_driver kiểm lâu đài vừa chạm vẫn trong khung). Bản đồ: lâu đài thật mỗi màn, ảnh núi / rừng / đồi / làng, biển + gợn sóng + thuyền + la bàn, sông thon, khung viền, mây che vùng chưa mở; K_MIN 7.5, lăn chuột = kéo.
- Vòng 3 (user): "màn 8 sao xanh" = g01 chưa thắng trong hồ sơ user (g* chèn sau khi user đã thắng m*), đúng dữ liệu. Thẻ giữa màn hình + lớp tối (chạm ngoài = đóng, bản đồ không bao giờ tự cuộn); bỏ lâu đài + lửa -> khiên có số, sao to trên dải giấy; mây = hình mây hoạt hình (múi tròn + đế phẳng + viền mực), vùng chưa mở không hiện khiên.
- Vòng 4 (user): sao vào trong khiên, trên số, chỉ hiện sao đạt; đường nối = lối mòn; làng = màn Dễ / TB, lâu đài = màn Khó (4 màn: g03 g11 g17 g20) -> công trình mái đỏ / xanh + khiên dưới chân; bỏ làng trang trí (dễ nhầm với màn); K_MIN 8.5.
- Vòng 5 (user): đầu bản đồ chỉ còn nút "‹ Trở lại" (bỏ tiêu đề + đếm lửa); `BackBtn` to hơn (bold 18, đệm 18/10) -> mọi trang dùng chung. Hỏi "có UI chung không": có theme `Style.make_theme` + `Style.button(text, variation)` ~20 kiểu nhưng mỗi kiểu gói cả màu + cỡ -> chưa có bậc cỡ chung (đề xuất ở TODO).

