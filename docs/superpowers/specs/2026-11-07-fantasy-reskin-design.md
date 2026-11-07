# Fantasy reskin (chỉ giao diện) · design

Ngày: 2026-11-07 · Trạng thái: đã làm (nhánh `feat/fantasy-reskin`, kết quả `docs/review/fantasy_result.html`) · Nhánh nền: **`feat/levels`** (user chốt) · Nguồn hình: `docs/review/ui_direction_fantasy.html` (mockup + mẫu SVG), `docs/review/ui_direction.html` (nghiên cứu gốc, kế hoạch P0–P5).

## Vì sao
- Bỏ bối cảnh lịch sử Việt (Hai Bà Trưng, Đông Hán, trống đồng, triện…) → fantasy kỵ sĩ / pháp sư, người chơi mọi nước hiểu ngay.
- UI hiện tại "giống app" (viền 1 px, nền mờ, emoji). User thích hướng C · Đông Hồ (nét mực dày, bóng in lệch, nút "đóng dấu") → giữ khung đó, thay họa tiết sang fantasy.

## Mục tiêu
1. Da UI mới **F1 · Truyện Kỵ Sĩ** cho mọi màn đang có.
2. Hình quân mới (22 SVG = 11 loại × 2 phe) theo bảng quân bên dưới.
3. Hình công trình / ô mới (lâu đài, làng, làng cháy, cầu gỗ, giếng thần, đồng cỏ).
4. Chữ hiển thị mới: tên quân / tướng / ô / phe, mô tả thẻ ⓘ, chữ UI có từ lịch sử Việt.
5. Âm thanh UI mới (dấu sáp, lật giấy, kèn) thay trống đồng / chiêng.
6. **Nhạc nền mới** (user chốt): thay nhạc ngũ cung kiểu đàn bầu (`audio.gd` `recipes()`, ~30 `m_*.wav`) bằng nhạc tổng hợp chất trung cổ châu Âu (thang âm Dorian / Mixolydian, tiếng lute / kèn / trống trận), cùng cơ chế bake.

## Không làm (non-goals)
- Cốt truyện, thoại, nhân vật trong `people`, logic chế độ màn số.
- **Tên riêng nội dung giữ nguyên** (user chốt): tên màn / chương / địa danh, nhãn bản đồ, tên bản đồ đấu tự do, `THEME.tagline` / `lede`, credits. Chỉ đổi chữ UI (nút, thẻ, HUD, menu), tên + mô tả quân / tướng / ô / phe.
- Luật + chỉ số (`scripts/core/rules.gd`), khóa quân (`soldier archer boat shaman drum wolf elephant catapult bird ghost hero`), `ai.gd` / `ai_plan` / preset bot (đang train bot V2-hard).
- Logic phe / mục tiêu / thắng thua.

## Anti-goals (làm vậy là hỏng dù chạy được)
- Đổi bất kỳ số / cờ luật nào → kết quả sim khác. Sim + test phải ra y như trước.
- UI bóng bẩy hơn quân (gradient kim loại, phát sáng tràn lan) → lệch chất với chibi màu phẳng.
- Chữ gô-tích / font khó đọc dấu tiếng Việt.
- Còn sót emoji, hoặc từ lịch sử Việt trong chữ UI / quân / ô / phe (vd "giặc", "Hán", "Thầy mo", "trống đồng", "Thành", "Đền").

## Đã chốt (user)
| Mục | Quyết định |
|---|---|
| Hướng UI | **F1 · Truyện Kỵ Sĩ** (giấy da, dấu sáp đỏ, băng rôn huy hiệu, góc khung hình thoi vàng) |
| Font | **Giữ font C**: Paytone One (tiêu đề, nút, số, tên) + Be Vietnam Pro (thân). Không dùng Grenze / gô-tích |
| Voi chiến (`elephant`) | **Golem Đá** · rig mới |
| Máy bắn đá (`catapult`) | **Giữ Máy Bắn Đá**, vẽ lại kiểu trung cổ (khung gỗ + đai sắt, cờ màu phe). Đạn đá giữ |
| Phe (tên tạm) | Phe ta **Quân Khởi Nghĩa** (đỏ thẫm + vàng, huy hiệu vương miện) · phe địch **Đế Quốc** (lam + bạc, huy hiệu đại bàng). Không dùng "Sư Tử / Quạ" |
| Tướng | `anhhung` → **Hiệp Sĩ Chỉ Huy** · `tuonggiac` → **Hắc Hiệp Sĩ** |
| Dáng chỉ huy | **B · cắm kiếm**: 2 tay trên chuôi, đại kiếm cắm đất, áo choàng xòe viền vàng, giáp vai 2 lớp, mũ vương miện + cánh lông vũ; Hắc Hiệp Sĩ: thép đen, mũ sừng, mắt đỏ. Đòn đánh = nhổ kiếm rồi chém |
| Mẫu đã duyệt | Vệ Binh, Pháp Sư Gọi Hồn (mẫu trong trang review = chuẩn hình) |
| Cốt truyện | Chỉ tham khảo (Đế Quốc chiếm phần lớn vương quốc → quân khởi nghĩa chiếm lại). **Không** đưa vào game lần này |

## Bảng quân (khóa giữ nguyên)
| Khóa | Cũ | Mới | Rig | Hình |
|---|---|---|---|---|
| hero (p/e) | Anh hùng / Tướng giặc | Hiệp Sĩ Chỉ Huy / Hắc Hiệp Sĩ | sửa (cắm kiếm) | như dòng "Dáng chỉ huy" |
| soldier | Bộ binh | Vệ Binh | giữ | nón sắt thanh mũi, áo xích + áo khoác màu phe, giáo có cờ, khiên tam giác chữ V |
| archer | Nỏ thủ | Cung Thủ | sửa (kéo cung) | mũ trùm, cung dài, ống tên |
| boat | Thủy binh | Hải Tặc | giữ | khăn trùm màu phe, mái chèo / móc, thuyền nhỏ khi ở nước |
| shaman | Thầy mo | Pháp Sư Gọi Hồn | giữ | mũ trùm màu phe tối, gậy đầu lâu lửa xanh, hồn ma nhỏ |
| ghost | Âm binh | Bộ Xương | giữ | bộ xương kiếm gỉ, khiên vỡ, vải màu phe, mắt lửa xanh |
| drum | Trống đồng | Tu Sĩ Ánh Sáng | sửa (giơ đèn → vòng sáng) | áo trắng viền màu phe, chùy ngắn + đèn / đĩa mặt trời trơn (không hoa văn Đông Sơn) |
| wolf | Sói | Sói Bóng Đêm | giữ | sói đen to, khói tím ở chân, vòng cổ màu phe |
| elephant | Voi chiến | Golem Đá | mới (2 chân, đấm xuống đất) | khối đá, rêu, rune phát sáng màu phe |
| catapult | Máy bắn đá | Máy Bắn Đá | giữ | khung gỗ + đai sắt, cờ màu phe, lính kéo dây mũ sắt |
| bird | Rồng | Rồng | giữ | rồng phương Tây 4 chân 2 cánh, vảy màu phe, sừng vàng / bạc |

Màu phe giữ nguyên số hiện tại: p `#c9503f` / `#93362b` + vàng `#e2c36e`; e `#4f74c9` / `#34509a` + bạc `#d9dee3` (điểm nhấn e đổi vàng → bạc). Nét: viền `#2b2220` 7 px, khung 256×256, đầu tròn r 54 tại (130, 84) như quân hiện tại.

## Ô / công trình (luật giữ)
`.` Đồng lúa → **Đồng cỏ** · `=` Cầu tre → **Cầu gỗ** · `v` Làng (giữ tên; nhà mái rơm vách gỗ + cối xay nhỏ, cờ phe) · `x` Làng hỏng → **Làng cháy** · `c` Thành → **Lâu đài** (2 tháp tròn + cổng, cờ phe) · `t` Đền → **Giếng Thần** · `r f h m ~` giữ.

## Da UI F1 (token chốt từ mockup)
- Màu: giấy `#f2e3c0` / `#dcc596`, mực `#231a15`, đỏ thẫm `#b3262e` / `#7d1720`, vàng lá `#e3b345`, lam `#27477a`, xanh máu `#4f8a3a`.
- Hình: viền mực 3 px, bo "khắc tay" không đều, bóng cứng lệch xuống phải 4 px; nhấn = dịch đúng bằng bóng; rê = nghiêng −1.5°.
- Panel: giấy da + khung đôi + hình thoi vàng ở 4 góc.
- Hết lượt: **dấu sáp đỏ** in vương miện; sẵn sàng = lắc nhẹ.
- Nhãn lượt / tên người nói: băng rôn lam 2 đuôi. Chữ cái đầu đoạn thoại to đỏ.
- Icon: màu phẳng + nét mực dày; đồng vàng tròn dập sao (không lỗ vuông). Thay toàn bộ emoji trên UI.
- Điểm yếu đã biết: panel giấy sáng chìm trên đường đất / làng màu kem → thêm bóng mờ đen ~35% quanh panel nổi trên bàn cờ (đo bằng probe chụp).
- Hiệu ứng phép (gọi hồn, hào quang tu sĩ) được dùng ánh sáng lam / tím; UI thì không.

## Ràng buộc
- Godot 4.7, web export (Compatibility renderer) + điện thoại 844×390: texture bake 1 lần lúc boot, ít shader.
- `style.gd` = nơi duy nhất định nghĩa token / theme; giữ tên theme variation + chữ nút mà click driver / probe đang tìm (hoặc sửa driver cùng lúc).
- Font mới: Paytone One (SIL OFL 1.1, có subset tiếng Việt) vào `assets/fonts` kèm file OFL.
- Tự vẽ SVG trong repo, không tải asset ngoài.
- Repo không có remote ở máy này: commit local, user push từ máy khác.
- Nhánh nền `feat/levels`: tạo worktree mới từ commit đã commit của nhánh này; **không đụng** worktree `.claude/worktrees/stars-threat` (đang có 21 file sửa chưa commit của việc khác). Nhánh này đã bỏ 3D, màn thoại, chương, bản đồ chiến dịch → không cần skin các màn đó.

## Quyết định kỹ thuật (Claude chốt, user xem lại)
- **Rig dùng chính hình SVG cũ**: mỗi rig chép nguyên markup từ `assets/units/styles/chibi/*.svg` vào `docs/anim_demo/<unit>.spec.js` → `tools/rig_export.mjs` → `assets/units/rig/*.json`. → Thay SVG thì **cả 11 rig** phải cắt lại parts từ hình mới (rig "giữ" = giữ xương + nhịp, chỉ thay parts / chỉnh pivot); hero, archer, drum sửa nhịp; elephant (golem) xương mới. Lần này được sửa `docs/anim_demo/*` + `assets/units/styles/*` (luật "không sửa" trong `docs/rig_port.md` dành cho đợt port, không áp cho reskin); vẫn chạy parity + `rig_smoke` sau mỗi rig.
- **Giữ tên thư mục style `chibi`** (thay file tại chỗ): `Rigs.has()` + `board_paint.art_path()` phụ thuộc tên này; đổi tên = tắt toàn bộ rig.
- **Màu phe trong SVG phải đúng hex** mà `TEAM_SWAP` (`scripts/ui/rig/rig_data.gd`) đổi: đỏ `#c9503f` → `#4f74c9`, đỏ tối `#93362b` → `#32508f`. Thêm cặp vàng `#e2c36e` → bạc `#d9dee3` cho điểm nhấn phe địch. Đỏ tối phe địch dùng `#32508f` (không phải `#34509a` như mockup).
- **Hải Tặc** = người trên thuyền nhỏ ở mọi ô (như hình thủy binh hiện tại) → không thêm logic đổi hình theo ô.
- **Emoji**: đang hiện qua font fallback (`EmojiFont`), không phải ảnh. Thay bằng bộ icon SVG tự vẽ (bake lúc boot → `Button.icon` / `TextureRect`); chữ nút giữ nguyên phần chữ mà click driver tìm (`begins_with`): "Hết lượt", "Xuất quân", "Đánh", "Hủy"… → nếu bỏ ký tự emoji đầu chuỗi thì sửa `sim/click_driver.gd` cùng commit.
- **Test nhạy chữ**: `sim/tests/content.gd` (skin mỗi loại quân, khóa màu từng kiểu ô), `rules_2.gd` (`unit_title("Bộ binh")`), `rules.gd` (chuỗi đặc tính "+10 công") → cập nhật kỳ vọng khi đổi chữ, không đổi logic.
- **"Sim giống trước"** = test + `sim/sim.gd` cho cùng kết quả trên cùng seed trước / sau (so trên nhánh nền đã chọn).

## Chia 2 đợt (vì `feat/levels` đang được làm dở ở phiên khác)
`feat/levels` đang chạy kế hoạch level mode (đầu nhánh = `5f4dde4` "wip … UI callers still broken"); kế hoạch đó sửa `game_screen.gd`, `main.gd`, `menus.gd`, `content/theme.gd`, `content.gd`, `token.gd`, `draw.gd`, thêm `level_select.gd`. Không sửa: `assets/units/**`, `assets/terrain/**`, `docs/anim_demo/**`, `scripts/ui/rig/**`, `board_paint.gd`, `audio.gd`, `tools/bake_sfx.gd`.
- **Đợt A · tài sản (làm ngay, không đụng file của levels)**: 22 SVG quân + cắt lại parts 11 rig + sửa rig hero / archer / drum + rig golem mới; SVG ô / công trình; âm thanh UI + nhạc nền mới. Nhánh `feat/fantasy-assets` từ `1a73512` (commit chạy được cuối của `feat/levels`), worktree mới. Sau này rebase lên `feat/levels` hoàn chỉnh (file tách rời → không xung đột).
- **Đợt B · da UI + chữ (sau khi levels xong phần UI, Task 3–4)**: `style.gd` token / nút / panel / dấu sáp, HUD, info panel, menus, màn chọn level, icon thay emoji, chữ trong `theme.gd` / `guide.gd` / `content.gd`, test + click driver. Nhánh từ `feat/levels` mới nhất lúc đó.

## Để builder tự quyết
- Thứ tự làm, cách chia commit, cách bake nine-patch.
- Chi tiết hình 18 SVG còn lại (theo bảng + nét chibi), chi tiết nhịp rig.
- Cách dời / sửa chữ UI ngoài `content/` (giữ nghĩa).

## Xong khi
- Mọi màn có trên nhánh nền dùng da F1; không còn emoji; chữ UI / quân / ô / phe không còn từ lịch sử Việt (tên riêng nội dung giữ, xem Không làm).
- 22 SVG mới + 4 rig (hero, archer, drum, elephant) chạy; probe chụp 1280×720 + 844×390 cho user duyệt.
- Test + lint + click driver xanh; sim cho kết quả giống trước (không đổi luật).
