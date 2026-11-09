# Công Thành Chiến — bản hiện tại (đọc đầu tiên)

Cập nhật: 2026-11-09 · nhánh `feat/setting-v2` (từ master `af215a4`, chưa merge) · `config/version` 1.0.6 · iOS TestFlight build 1.0 (6) = bản trước v2, tag `ios-1.0.6`.
Trang này = game **đang có gì**, 1 màn hình. Chi tiết -> file sự thật (bảng cuối). Lịch sử -> `docs/HANDOFF.md`, `docs/superpowers/`.

## Game
- Cờ chiến thuật theo lượt trên lưới ô, luật = Ancient Empires II (`docs/spec.md`). Godot 4.7, GDScript.
- Nền tảng: iOS (TestFlight, ngang + dọc), macOS / Windows (`godot --path .`), web (`tools/export_web.ps1` chạy trên máy Windows; bản trên Vercel không rõ cập nhật tới commit nào).
- Bối cảnh: **Quân Đế Quốc (xanh) vs Quân Ma Vương (đỏ rượu + tím)**, Vorn = tướng quân phản loạn -> `docs/setting.md`.
- Ngôn ngữ: Tiếng Việt + English, mặc định theo máy, đổi ở nút Ngôn ngữ (màn tiêu đề + ⚙) -> `docs/i18n.md`.

## Chế độ (màn tiêu đề)
- **Thử thách**: 39 level = 3 hướng dẫn (t01–t03) + 36 level (m01–m16, g01–g20), Dễ / Trung bình / Khó, 3 sao / level, mở tuần tự. Chọn level trên bản đồ vương quốc (làng = Dễ / TB, lâu đài = Khó). `docs/content.md`.
- ~~Đấu tự do~~: bỏ khỏi menu 2026-11-09 (user: trùng 1 đấu 1 vs máy, cùng 3 bản đồ Đảo Sông Bạc / Quần đảo Sương Mù / Hẻm núi Đá Xám). Save đấu tự do cũ vẫn đánh tiếp được; sim / đo bot vẫn dùng `Content.skirmish_def`.
- **1 đấu 1**: người–người chung máy, hoặc người–máy Dễ / Trung bình / Khó (Siêu khó bỏ 2026-11-09). `docs/1v1.md`, AI `docs/ai.md`.
- **Đầu hàng** (⚙, chỉ 1 đấu 1 + đấu tự do, trong lượt mình): hỏi lại -> bên kia thắng ngay. `docs/1v1.md`.
- **Sách lính**: thẻ từng loại quân (`content/guide.gd`).
- **Đánh tiếp ván đang dở** (1 chỗ lưu). Cài đặt (màn tiêu đề + ⚙): âm thanh, nhạc, tốc độ hoạt cảnh x1/x2/x3, ngôn ngữ VI / EN.

## Nội dung
- Quân (2 phe dùng chung, chỉ khác màu): 9 loại mua được + Bộ xương (pháp sư gọi hồn) + 2 tướng (Hiệp Sĩ Chỉ Huy / Vorn). Bảng chỉ số `docs/spec.md`, số gốc `scripts/core/rules.gd`. Nhánh `feat/drop-superhard` (chờ user đánh thử): mỗi quân 1 việc riêng — Tu sĩ hồi 10 máu quanh 2 ô, Sói đi rừng / đồi / núi 1 bước + 500 vàng, Rồng 750, Hải tặc dưới sông +15 / +25, Máy bắn đá xuyên giáp.
- Địa hình (tên trong game): đồng cỏ, đường mòn, rừng, đồi, núi, sông, cầu gỗ, làng, làng cháy, lâu đài, Giếng Thần.
- Kiểu thắng: chiếm thành · diệt hết · hạ tướng · giữ N lượt · đưa tướng tới ô đích.
- Hướng dẫn cầm tay t01–t03 + nhiệm vụ (quest) ở t01–t03, m01–m04, m10 + thẻ giới thiệu quân mới.
- Hình: 2D vector, rig hoạt cảnh đánh cho mọi loại quân (`docs/rig_port.md`); giao diện giấy da / dấu sáp, font Paytone One.
- Âm thanh: hiệu ứng tự tổng hợp kiểu "nhạc cụ gõ" (chuông / mộc cầm giọng Rê, 1 phòng vang chung; âm hay lặp có 3 biến thể phát ngẫu nhiên). Nhạc = 1 bài trầm, nhẹ "Lord of the Land" (Kevin MacLeod, CC BY 4.0) lặp cho cả menu lẫn trận, ghi công ở trang Giới thiệu.
- Hỗ trợ: vùng địch đánh tới, gợi ý đòn (rê chuột / chạm 2 lần), replay + phân tích trận (`tools/review_match.sh`), log phiên (`logs/game/`).

## Chưa có / đang chờ
- Bối cảnh v2 + tiếng Anh xong trên nhánh `feat/setting-v2`, chờ user chơi thử rồi merge; iOS build mới chưa làm.
- Store listing (tiếng Anh); trận trùm cuối Ma Vương; online.
- Cân bằng kinh tế + đội hình đa dạng cho bot; người chơi thử mốc sao.
- Lật kèo 1 đấu 1 (bên thua hết làng = hết tiền): hoãn tới khi luật ổn định. Lương cố định + thưởng hạ quân đã đo, không giúp -> chưa đổi luật; kế tiếp = Thanh Nộ của Tướng (`docs/1v1.md` "Lật kèo", `docs/TODO.md`, `sim/tune.gd comeback`).
- Toàn bộ danh sách: `docs/TODO.md`.

## File sự thật (mỗi mảng 1 nơi, luôn đúng bản hiện tại)
| Mảng | File |
|---|---|
| Tổng quan bản hiện tại | `docs/STATUS.md` (trang này) |
| Bối cảnh, phe, tên, màu, tông | `docs/setting.md` |
| Ngôn ngữ, bản dịch, thuật ngữ EN | `docs/i18n.md`, `locale/en.po` |
| Luật, chỉ số quân, địa hình | `docs/spec.md` (số gốc `scripts/core/rules.gd`) |
| Level, bản đồ, nhiệm vụ, hướng dẫn, cách thêm nội dung | `docs/content.md` |
| AI / bot | `docs/ai.md` |
| 1 đấu 1 | `docs/1v1.md` |
| Hình quân + hoạt cảnh | `docs/rig_port.md`, `docs/anim_demo/SHARED.md` |
| Âm thanh, nhạc | `scripts/ui/audio.gd` (đầu file) + `tools/sfx/synth.mjs` (công thức từng âm), nghe ở `docs/design/am-thanh.html` |
| Xem tận mắt mọi thành phần (9 trang: tướng, lính, địa hình, âm thanh + cảnh có tiếng, giao diện, màn hình, level & bản đồ, chữ); preview đổi bối cảnh làm ở đây trước | `docs/design/index.html` (sinh từ game: `tools/design_dump.gd`, `tools/design_shots.sh`, `tools/record_sfx_scene.sh`) |
| Việc còn lại, nợ kỹ thuật | `docs/TODO.md` |
| Chạy, build, test, debug | `README.md` |

Không phải sự thật hiện tại: `docs/HANDOFF.md` (nhật ký), `docs/superpowers/specs|plans/` (thiết kế theo ngày), `docs/review/` (phân tích, mockup).
