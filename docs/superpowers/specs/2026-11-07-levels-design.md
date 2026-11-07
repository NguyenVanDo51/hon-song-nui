# Chế độ Level (bỏ cốt truyện + chương) — thiết kế

Ngày: 2026-11-07. Trạng thái: nháp, chờ người dùng duyệt.
Ký hiệu: **(user)** = người dùng quyết · **(Claude)** = Claude tự quyết, người dùng xem lại được.

## 1. Ý định
- Game = **game cờ chiến thuật**: người chơi chỉ tập trung bàn cờ. (user)
- Cốt truyện tốn công làm, không đáng. (user)
- Chiến dịch có truyện + chương -> **chuỗi level đánh số, mở lần lượt**. MVP 30–50 level, lâu dài ~100. (user)
- Người dùng chỉ chơi thử + góp ý; Claude làm hết: level, công cụ tạo level, cân bằng. (user)

## 2. Mục tiêu
1. Level 1..N, thắng level k -> mở k+1.
2. Mỗi level = trận đánh thường như màn hiện nay (mua quân, chiếm làng / thành, đánh), **bản đồ cỡ hiện tại, không thu nhỏ**. (user)
3. Độ khó tăng dần nhưng **linh động**: xen level nhẹ sau level khó; mỗi level gắn nhãn Dễ / Trung bình / Khó. (user: "khó dần hoặc linh động"; nhịp răng cưa = Claude)
4. Càng về sau càng nhiều thứ mới: quân, tướng, địa hình, hiệu ứng, kiểu thắng — gặp từng thứ một. (user)
5. Nhiều kiểu thắng để đa dạng. (user)
6. Công cụ + skill tạo level **nhanh, hay, hấp dẫn**, có máy lọc chất lượng. (user)

## 3. Không làm (non-goals)
- Không thoại, truyện, sử tích, nhân vật, thẻ tên màn, lời kết, **không chương**, không bản đồ chiến dịch. (user)
- Không sinh level lúc chơi. Level sinh sẵn bằng công cụ, lưu file, ai chơi cũng như nhau, sửa tay được. (Claude, user đồng ý)
- Không đổi luật đánh (`rules.gd`, `game.gd` combat).
- **Không sửa logic bot** (`scripts/core/ai.gd`, `ai_plan.gd`, `AI.DEFAULT` / `PRESETS`, các hook `ai_goals` / `ai_tile` trong `objectives.gd`) cho tới khi bot V2-hard huấn luyện xong. Lên kế hoạch được, làm sau. (user)
- MVP không thêm quân / tướng / địa hình / hiệu ứng mới (xem §8). (Claude)

## 4. Thất bại dù chạy được (anti-goals)
- Level na ná nhau: cùng khung, chỉ đổi số vàng.
- Level thắng một chiều, hoặc kéo lê thê (trung vị > ~25 lượt).
- Độ khó nhảy vọt, hoặc khó / dễ vì bot ngớ ngẩn (vd địch không chặn ô đích).
- Làm vỡ việc huấn luyện bot đang chạy (cùng repo, cùng máy).

## 5. Hiện trạng (đã đọc code, master `20fae2e`)
- 16 màn `content/campaign/m01–m16.gd` (`DEF`), 2 chương `content/chapters/c1.gd`, `c2.gd`. Định dạng `DEF`: `docs/content.md` § "Thêm màn chiến dịch".
- Phần truyện: `scripts/ui/story_overlay.gd`, khóa `story` / `history` / `tips`, `people` trong theme, `outro` chương. Chương hiện **không** ghi đè theme (c1, c2 cùng skin địch). Bản đồ chiến dịch: `scripts/ui/camp_map.gd`. Registry: `scripts/core/content.gd` (`campaign()`, `chapters()`, `use_chapter`, `chapter_unlocked`…).
- Nội dung có sẵn: 9 quân mua được + rồng + âm binh; ô `. r f h m ~ = v x c t`; đêm; `waves`; quân `guard`; `unitCap`; `gold`.
- 5 kiểu thắng (`objectives.gd`): `castles`, `rout`, `hero`, `survive`, `reach`.
- Nhịp ra quân kiểu AE2: thấy -> cầm -> mua (`docs/content.md` § "Nhịp ra quân mới").
- Sao màn: nhánh `feat/stars-threat` (chưa merge): 3 sao = thắng · tướng không ngã · mốc `turns` / `lost`. `Stars.check_def` kiểm mốc.
- Sim: `sim/sim.gd -- mission <id> N` (bot cả 2 phe -> % thắng phe ta, trung vị lượt), `tools/sim_many.sh`, `sim/mapgen.gd` (sắp lại địa hình: đường nối, cụm rừng/đồi/núi, vòng trống quanh thành, đối xứng), `sim/tests.gd` (validator nội dung), `sim/golden.txt` (trace hồi quy).
- Bot: chiến dịch dùng bot mặc định (tham lam v1). Preset `easy` / `normal` / `hard` (`hard` = planner v2, chậm hơn). Huấn luyện bot (`sim/tune.gd`) chỉ dùng **bản đồ đấu tự do** -> đổi màn / level không ảnh hưởng dữ liệu huấn luyện.
- Tốc độ sim: ~1 ván/s/tiến trình khi máy rảnh, bot v1 (`docs/ai.md`).
- Nhánh `feat/stars-threat` + `chore/drop-3d` tách từ `84d6c2c`; master đã đi tiếp (AI v2, formatter) -> cần rebase trước khi làm.

## 6. Dữ liệu level
- Thư mục mới `content/levels/LNNN.gd` (`const DEF`), định dạng = `DEF` màn hiện nay, **bỏ**: `chapter`, `region`, `pos`, `place`, `history`, `story`, `tips`. (Claude)
- Giữ: `id` (`"L001"`), `order`, `title` (tên ngắn, chỉ là nhãn, vd "Bến sông"), `hero`, `enemyHero`, `newUnits`, `allowed`, `gold`, `win`, `stars`, `unitCap`, `night`, `map`, `owner`, `units`, `waves`.
- Thêm:
  - `tier`: `"easy" | "mid" | "hard"` -> nhãn Dễ / Trung bình / Khó.
  - `ai`: preset bot phe địch (`"easy" | "normal"`; mặc định `normal`). Chỉ **chọn** preset có sẵn qua `s.aiParams`, không đổi logic bot. Hiện `Game.new_game` chỉ điền `aiParams` khi def có `ctrl` (1 đấu 1) -> nối thêm cho level (ngoài logic bot); sim tự dùng theo. MVP không dùng `hard` (đang huấn luyện, chậm, sẽ đổi). (Claude)
  - `gen` (tùy chọn): `{ recipe, seed, sim: { win, turnsMed, n, ai_rev } }` — công thức + kết quả sim lúc chọn, để tái tạo / biết khi nào phải đo lại. (Claude)
- `Content.levels()` thay `Content.campaign()`; bỏ API chương.

## 7. Nguồn level MVP
- 16 màn cũ -> bỏ truyện / chương, đổi thành level (đã cân bằng, có nhịp dạy chơi m01–m04). (Claude, user đồng ý)
- Màn cũ giữ nguyên nội dung: chỉ sim đo + gắn `tier` theo band. Chỉ sửa màn lệch hẳn luật mới (trung vị > 25 lượt như m08 = 30): bớt vàng / `waves` / quân địch tới khi vào khoảng. (Claude)
- 14–34 level còn lại: sinh bằng công cụ (§10). Thứ tự (Claude):
  - m01–m04 (dạy chơi) giữ liền nhau ở đầu, **được miễn** luật "không 2 level ra mắt liền nhau".
  - Từ sau m04: màn cũ giữ thứ tự tương đối, level sinh **chèn xen giữa** (sau mỗi lần ra mắt ≥ 1 level luyện thứ vừa ra mắt, không có thứ mới) -> thứ mới trải đều trên 30–50 level thay vì dồn vào 16 level đầu. Luật nhịp §8 áp cho mọi chỗ trừ m01–m04.

## 8. Thứ mới theo level
- MVP chỉ dùng nội dung đã có, ra dần theo luật hiện hành: thấy -> cầm -> mua; không 2 level ra mắt liền nhau; level ra mắt không bao giờ là Khó.
- Cần ra mắt: 9 quân mua được, rồng (đặt sẵn), địa hình (rừng, đồi, núi, sông + cầu, làng hỏng, đền), đêm, 5 kiểu thắng, hiệu ứng (hào quang trống, độc sói, gọi hồn, máy bắn đá phá làng).
- Bảng nhịp chi tiết cho N level: builder lập, ghi vào `docs/content.md` thay bảng m01–m16.
- Sau MVP: quân / tướng / địa hình / hiệu ứng mới, mỗi thứ 1 đợt thiết kế riêng, rồi kéo dài lên ~100 level. Hiện chỉ có 2 tướng cố định (`anhhung`, `tuonggiac`); "tướng mới" = việc thiết kế riêng.

## 9. Độ khó
- Đo: % thắng phe ta khi bot (mặc định) chơi phe ta vs bot preset `ai` của level, K ván seed cố định (`sim/sim.gd`).
- Ngưỡng ban đầu (Claude, chỉnh sau khi user chơi thử): Dễ ≥ 80% · Trung bình 55–80% · Khó 30–55%. Bot phe ta ≠ người -> chỉ là thước tương đối; playtest của user là nguồn thật.
- Nhịp răng cưa (Claude): mỗi khối ~5 level đi lên, level ngay sau Khó là Dễ / Trung bình ("thở"), level ra mắt thứ mới ≤ Trung bình. Khó dần theo khối.
- Đòn bẩy (không đụng logic bot): vàng 2 phe, quân ban đầu, `waves`, `unitCap`, preset bot địch, số thành / làng mỗi bên, khoảng cách, địa hình chắn, đêm, giới hạn lượt.
- Bot đổi (V2-hard xong, hoặc đổi bot mặc định) -> chạy lại sim mọi level, sửa `tier` / mốc sao (`gen.sim.ai_rev` cho biết level nào đo bằng bot cũ).

## 10. Công cụ tạo level (`sim/levelgen.gd`)
Chạy headless, ngoài game. Quy trình:
1. **Công thức** (Dictionary): `w`, `h` (cỡ màn hiện nay), số thành mỗi phe, số làng, sông (có / không, số cầu), tỉ lệ đất khó (~30%), đền 0–2, đối xứng hay lệch, kiểu thắng (+ tham số), quân cho phép mỗi phe, vàng, quân ban đầu, `waves`, đêm, preset bot địch, tier đích.
2. **Dựng khung**: đặt thành 2 phe, làng (chia vùng ảnh hưởng), sông + cầu, đền; dùng lại `mapgen.gd` (`relayout`) cho mạng đường + cụm địa hình.
3. **Đặt quân** ban đầu + `waves` theo công thức.
4. **Kiểm hợp lệ**: validator của `sim/tests.gd`, `Objectives.check`, `Stars.check_def`, liên thông (quân nặng tới được mọi thành).
5. **Sim**: K ván (đề xuất 12) -> % thắng phe ta, trung vị lượt, % ván chạm giới hạn lượt, chỉ số giằng co (vd số lần đổi bên dẫn điểm theo thế cờ; định nghĩa cụ thể = builder).
6. **Lọc + chấm**: đúng band tier, trung vị lượt trong khoảng (~8–25), giằng co ≥ ngưỡng, không trùng khung với level đã chọn. Giữ top vài bản / công thức.
7. **Xuất**: `content/levels/LNNN.gd` (+ `gen`), ảnh bàn cờ (probe có cửa sổ — cần màn hình máy bật) -> Claude xem, chọn bản hay nhất. Mốc sao = trung vị như `Stars` hiện nay.
- Làm công cụ + sinh level **không cần chờ** bot V2-hard (chỉ chạy sim, không sửa bot). Bot mới xong -> chạy lại sim mọi level 1 lần (§9). (Claude)
- Ngân sách: 50 level × ~5 ứng viên × 12 ván ≈ 3000 ván ≈ 15–25 phút với 2–4 tiến trình (bot v1). Bot huấn luyện chạy cùng máy -> giới hạn số tiến trình; đo thực tế trước khi chạy đại trà.

## 11. Skill tạo level
- `.claude/skills/level-maker/SKILL.md` **trong repo** (Claude: đi cùng công cụ, cùng phiên bản): cách viết công thức, chạy `levelgen`, đọc kết quả sim, tiêu chí chọn, luật nhịp ra mắt, checklist trước khi giao user (tests, sim, ảnh, chơi thử bằng click driver). Mục đích: phiên sau làm thêm level nhanh (50 -> 100+).

## 12. Giao diện
- Menu chính: nút "Chiến dịch" -> **"Thử thách"** (Claude; user gọi "100 thử thách").
- Màn chọn level (thay bản đồ chiến dịch): lưới ô số, mỗi ô = số level + màu theo tier + 0–3 sao + khóa nếu chưa mở; trang ~20–30 ô; nút "Tiếp" vào level chưa thắng đầu tiên. Rê / nhấn ô: tên, kiểu thắng, 3 mục tiêu sao. Bố cục chi tiết = builder (dựng ảnh cho user xem trước khi chốt).
- Vào level: thẳng bàn cờ. Giữ: dòng mục tiêu ở thanh trên, thẻ giới thiệu quân mới. Bỏ: thẻ tên màn, thoại.
- Kết thúc: thẻ thắng / thua + sao (đã có) + nút "Level tiếp" / "Đánh lại".
- Một skin phe địch duy nhất (skin c1) cho mọi level, đấu tự do, 1 đấu 1. (Claude)

## 13. Xoá / dọn
- Xoá: `story_overlay.gd`, `camp_map.gd`, `content/chapters/`, `content/campaign/` (sau khi chuyển sang `content/levels/`), khóa `story` / `history` / `people` / outro, API chương trong `Content`, theme ghi đè theo chương, cờ debug `story`. Docs: `README.md`, `docs/content.md`, `docs/spec.md`.
- Tiến độ đã lưu: `campaign_done` / `campaign_stars` theo id màn -> đổi sang id level tương ứng của 16 màn cũ, người đã chơi không mất tiến độ. (Claude)
  - Mở khóa sau khi đổi: mở mọi level có thứ tự ≤ level (đổi từ màn cũ) xa nhất đã thắng, kể cả level sinh chèn xen chưa chơi -> người đã xong m16 không bị đẩy về level sớm. Hiện `Store.unlocked_index()` = level chưa thắng đầu tiên -> đổi cách tính (vd lưu `levels_open` = thứ tự cao nhất đã mở). (Claude) Ván đang dở của màn cũ: builder chọn (đổi id hoặc bỏ có báo).
- Đấu tự do + 1 đấu 1 giữ nguyên (bỏ phụ thuộc chương nếu có, vd `skirmish_def` gắn `chapter`).
- `sim/golden.txt`: thêm / đổi level -> tạo lại. Nhánh huấn luyện bot cũng có thể tạo lại golden -> merge tuần tự, tạo lại golden sau merge.

## 14. Thứ tự làm
- **P0**: rebase `feat/stars-threat` + `chore/drop-3d` lên master mới, merge (chờ user OK).
- **P1**: chế độ level, bỏ truyện + chương, 16 màn cũ -> L-level, màn chọn level, đổi tiến độ đã lưu. Không đụng bot.
- **P2**: `levelgen` + skill; sinh thêm tới 30–50 level; user chơi thử.
- **P3** (sau bot V2-hard): phe thủ chặn ô đích (`reach`); kiểu thắng mới "chiếm N làng" (thắng khi đầu lượt ta giữ ≥ N làng; hook bot cho cả phe chiếm lẫn phe giữ); đo lại độ khó mọi level bằng bot mới. Trước P3: MVP dùng `reach` ít (≤ 3 level) vì địch chưa biết chặn đích.
- **P4**: nội dung mới (quân / tướng / địa hình / hiệu ứng) -> ~100 level.

## 15. Kiểm chứng
- `sim/tests.gd`: validator mọi level, `Stars.check_def`, mở khóa k -> k+1, đổi tiến độ cũ đúng.
- Sim mọi level nằm trong band tier đã ghi.
- Click driver: Thử thách -> level 1 -> thắng -> level 2.
- Ảnh: màn chọn level, vài level sinh bằng máy.
- Playtest của user = thước thật cho độ khó + "hay".

## 16. Để builder tự quyết
- Thuật toán dựng khung bản đồ, chỉ số giằng co, bảng nhịp chi tiết, bố cục UI chi tiết, số ứng viên / ván sim mỗi công thức, tên level.
