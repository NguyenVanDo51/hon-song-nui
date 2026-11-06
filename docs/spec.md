# Hồn Sông Núi — spec (luật AE2, 2026-11-06)

Chiến thuật theo lượt trên lưới ô. Hai Bà Trưng (ta) vs Đông Hán. Luật = Ancient Empires II (đối chiếu: `docs/review/rules_compare.html`); tên / bản đồ / hình / truyện = tự làm. Số liệu trong `scripts/core/rules.gd`.

## Lượt
- Chọn lính -> đi (xuyên quân mình, không xuyên địch) -> 1 hành động: Đánh / Chiếm / Sửa làng / Phá làng / Gọi hồn / Chờ.
- Đầu lượt mỗi phe: +30 vàng/làng, +50/thành. Lính đứng trên làng/thành của mình hoặc trên **Đền** (mọi phe): +20 máu.
- Mua lính (`RULES.buyAE2`): ở thành mình, đi + đánh ngay lượt đó. Thành có quân ta: chọn quân đó -> "Mộ quân"; lính mới đứng chồng, phải bước ra (không đứng yên, không hết lượt tới khi ra); tối đa 2 quân / ô; hết ô trống -> không mua. Mua nhiều lần / thành / lượt. AI chỉ mua khi thành trống.
- Trần quân (`unitCap`, đấu tự do chọn 10/15/20/30): âm binh không tính.

## Đánh
- Sát thương = `(công lăn ngẫu nhiên [min, max] + thưởng − thủ − 2·cấp_địch − thủ địa hình − thưởng thủ) × máu_người_đánh / 100`, làm tròn xuống, 0..máu. Lăn có seed theo ván (`s.rng`); xem trước hiện khoảng min–max.
  - Thưởng công: +2·cấp; trống đồng +10 (đóng dấu); nỏ vs rồng +15; trống vs âm binh +15; thủy binh dưới sông +10; bị chó cắn −10.
  - Thưởng thủ: thủy binh dưới sông +15; bị chó cắn −10.
- Đánh trả: chỉ khi kề nhau (khoảng cách 1) và bên bị đánh có tầm min 1 (không phải máy bắn đá). Bắn từ 2 ô không bị đáp.
- Kinh nghiệm: mỗi đòn = sát thương × (công min + công max + thủ của nạn nhân). Cấp kế = (công min + max + thủ của mình) × 200/3; dư mang sang; tối đa 1 cấp / trận; cấp tối đa 9; mỗi cấp +2 công (cả min, max), +2 thủ. Tên cấp đổi mỗi 2 cấp (lão luyện / tinh nhuệ / dũng mãnh / huyền thoại).
- Trống đồng: sau mọi lệnh của nó, quân ta trong 2 ô +10 công tới đầu lượt sau của ta (giữ cả khi đánh trả lượt địch).
- Chó săn: cắn trúng (không phải đánh trả) -> mục tiêu −10 công, −10 thủ tới đầu lượt sau của phe chó.
- Chết (trừ tướng, âm binh) -> mộ (ttl 3, trừ 1 mỗi đầu lượt của mỗi bên; có quân bước lên là mất). Thầy mo đứng cạnh -> Gọi hồn -> âm binh (cả lính địch ngã).
- Máy bắn đá: chưa đi mới bắn / phá làng (2–4 ô). Phá làng địch / chưa ai chiếm -> làng hỏng; bộ binh / tướng sửa (1 lượt) -> làng trống, lượt sau chiếm.

## Tướng
- Hai tướng cùng chỉ số (55–65 / 20 / 5 / 1), chiếm được làng + thành.
- Chết -> mua lại ở thành: 200 + 200 × số lần đã chết (tối đa 1000), giữ cấp + KN.

## Thắng / thua
- Một phe bị loại khi: hết thành **và** tướng đã chết; hoặc hết quân **và** hết thành. Phe chưa từng có thành (một số màn) chỉ thua khi hết quân.
- Màn chiến dịch thêm mục tiêu: `hero` (hạ tướng địch), `survive` N lượt, `reach` (đưa tướng tới ô), `rout`; `waves` = quân phục kích theo lượt.

## Địa hình (thủ +, giá đi)
Đồng 5/1 · Đường 0/1 · Rừng 10/2 · Đồi 10/2 · Núi 15/3 (mọi quân) · Sông 0/3 (thủy binh 1) · Cầu 5/1 · Làng 15/1 · Thành 15/1 · Làng hỏng 15/1 · Đền 15/1 (không chiếm, hồi máu mọi phe). Rồng: mọi ô 1.

## Lính (giá · công / thủ / đi / tầm)
| Lính | AE2 | Giá | C / T / Đi / Tầm | Đặc biệt |
|---|---|---|---|---|
| Bộ binh | Soldier | 150 | 50–55 / 5 / 5 / 1 | chiếm, sửa làng |
| Nỏ thủ | Archer | 250 | 50–55 / 5 / 5 / 1–2 | +15 vs rồng |
| Thủy binh | Elemental | 300 | 50–55 / 10 / 5 / 1 | sông giá 1, dưới sông +10 / +15 |
| Thầy mo | Sorceress | 400 | 40–45 / 5 / 5 / 1 | gọi hồn |
| Trống đồng | Wisp | 500 | 35–40 / 10 / 5 / 1 | hào quang tầm 2, +15 vs âm binh |
| Chó săn | Dire Wolf | 600 | 60–65 / 15 / 6 / 1 | cắn: −10 / −10 |
| Voi chiến | Golem | 600 | 60–70 / 30 / 5 / 1 | |
| Máy bắn đá | Catapult | 700 | 50–70 / 10 / 4 / 2–4 | công thành, phá làng |
| Rồng | Dragon | 1000 | 70–80 / 25 / 7 / 1 | bay |
| Âm binh | Skeleton | — | 40–50 / 2 / 5 / 1 | gọi từ mộ, không tính trần |

## Chưa xác nhận bản gốc (lấy theo mã bản mod AE2 Revolution)
Công thức KN (×200/3), +15 nỏ vs bay, rồng được thủ địa hình, độc không giảm bước đi, tầm hào quang 1–2, tướng hồi sinh giữ cấp.

## Để sau
3–4 phe + đồng minh, nhiều tướng / phe, tinh thể chiến dịch.
