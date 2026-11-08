# Hướng dẫn v2: 3 màn t01–t03 kiểu LoL — thiết kế

Ngày: 2026-11-08. Nhánh `feat/tutorial-v2` (từ master 01efeb1). Thay §7 của `2026-11-07-tutorial-quests-design.md` (cơ chế khoá bước, nhiệm vụ, sao giữ nguyên).
**(user)** = user quyết · **(Claude)** = Claude tự quyết (user nói "cứ làm", xem lại được).

## 1. Vì sao
- Bạn user chơi thử t01/t02: mãi không biết đi quân, không biết mục tiêu game. (user)
- Học theo LoL: thao tác cơ bản trước, mục tiêu lộ dần + rõ ràng. (user)
- Người mới hay quên Hết lượt; không biết 1 lượt điều khiển được mọi quân. Cần giải thích: quân đi rồi -> xám, mỗi quân đi 1 lần / lượt, sau đó tới đối thủ. (user)
- Không chỉ là hướng dẫn: phải có chút chiến thuật. (user)

## 2. 3 màn (chỉ tướng + vệ binh, chưa cung thủ) (user)
| màn | dạy | thắng |
|---|---|---|
| t01 Bài Học Đầu | chọn + đi quân, quân xám, Hết lượt; địch xuất hiện -> đánh; mẹo: dồn 2 quân hạ 1 tên | `rout` (user: diệt hết quân) |
| t02 Lâu Đài Trống | tướng chiếm lâu đài trống (thủ + hồi máu), rừng thủ, giữ chỗ cao, hạ hết địch | `rout` (user: chiếm thành + đánh bại hết quân). Bản đầu `castles` + lính gác: bot đưa gác ra khỏi lâu đài lượt 2 (8/8 seed) -> chiếm không cần đánh -> bỏ (Claude) |
| t03 Chiêu Binh | thành ta mua quân, chiếm làng (vàng + hồi máu), đưa quân yếu về làng hồi máu, rồi đánh thắng | `castles` (chiếm lâu đài địch = cách thắng chính, 15/39 màn); đợt địch lượt 1 + không làng mồi -> không thắng trước lượt 4 |
- t01 chưa có làng (user: chưa cần chiếm làng). t02 không làng (Claude: 1 bài 1 ý).
- Mốc sao lượt nới cho người mới (Claude): t01 6, t02 7, t03 9.
- Địch không mua quân (`allowed.e []`, `gold.e 0`); địch tới = `waves` (Claude: đoán trước được, không sửa bot).
- `order` 1/2/3 (m01 = 10, không khoá ai).

## 3. Cơ chế mới (Claude)
1. **Thẻ giải thích** (bước `card`): `{ "card": "<tiêu đề>", "say": "1–2 câu", "point": [x,y] | "end_turn" | null }`. Bàn tối + vòng sáng ở `point` (không bàn tay), bong bóng tiêu đề + chữ + nút **Đã hiểu ▶** (Space / Enter cũng được). Khoá mọi click khác (trừ ⚙). Dùng ở khoảnh khắc khái niệm: mục tiêu, quân xám, địch đánh trả…
2. Bước nhiệm vụ cũ: `say` dài hơn được (bong bóng tự xuống dòng, rộng tối đa ~360 px) + `title` tuỳ chọn.
3. **Nhắc Hết lượt** (chỉ t01 + t02, `nudgeEnd`; user), sau khi hết bước: lượt ta, mọi quân đã đi (xám), 2,5 s không bấm gì -> bàn tay + bong bóng chỉ Hết lượt, không tối, không khoá.

## 4. Không làm
- Không sửa bot (`ai.gd`, `ai_plan.gd`, presets, ai hook của objectives). (user, lệnh cũ)
- Không đổi luật / chỉ số. Không cốt truyện.
- Không đụng m01+ (nhiệm vụ m01–m04 giữ).

## 5. Kiểm
- `sim/tests` xanh (quests feasibility, bước đi hết trên map thật với bot thật nhiều seed), golden tạo lại (t01–t03 đổi), click driver đi hết bước t01–t03 qua click thật, ảnh chụp 1280x720 từng bước.
