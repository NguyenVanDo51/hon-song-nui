# Công Thành Chiến — spec (luật AE2, cập nhật 2026-11-09)

Chiến thuật theo lượt trên lưới ô. Bối cảnh / tên phe: `docs/setting.md`. Luật = Ancient Empires II (đối chiếu: `docs/review/rules_compare.html`); tên / bản đồ / hình / truyện = tự làm. Số liệu trong `scripts/core/rules.gd`.

## Lượt
- Chọn lính -> đi (xuyên quân mình, không xuyên địch) -> 1 hành động: Đánh / Chiếm / Sửa làng / Phá làng / Gọi hồn / Chờ.
- Đầu lượt mỗi phe: +30 vàng/làng, +50/thành. Lính đứng trên làng/thành của mình hoặc trên **Đền** (mọi phe): +20 máu.
- Mua lính (`RULES.buyAE2`): ở thành mình, đi + đánh ngay lượt đó. Thành có 1 quân (ta hoặc địch): quân ta chưa đi -> chọn nó -> "Mộ quân"; quân ta đã đi hoặc quân địch -> bấm thẳng vào thành mở bảng mua (đúng mã gốc); lính mới đứng chồng, phải bước ra (không đứng yên, không hết lượt tới khi ra); tối đa 2 quân / ô; hết ô trống -> không mua. Lính mới chưa bước ra -> bấm ra ngoài vùng đi (hoặc Hủy / Esc) = hủy mua, hoàn đủ vàng (mod: phòng thành bị vây kín). Mua nhiều lần / thành / lượt. AI mua cả khi thành có 1 quân (ta đã đi / địch), miễn lính mới có ô bước ra; mua sau khi mọi quân đã đi; tướng chết -> để dành vàng mua lại (khi còn ≥ 4 quân); không mua thủy binh nếu bản đồ không có sông.
- Trần quân (`unitCap`): chiến dịch 100 (màn có thể đặt riêng), đấu tự do / 1 đấu 1 chọn 10/20/25 (mặc định 10, như AE2); vàng khởi đầu 500/1000/2000 (mặc định 500); âm binh không tính.

## Đánh
- Sát thương = `(công lăn ngẫu nhiên [min, max−1] + thưởng − thủ − 2·cấp_địch − thủ địa hình − thưởng thủ) × máu_người_đánh / 100`, làm tròn xuống, 0..máu. AE2 không bao giờ lăn ra đúng công max của bảng (vd bộ binh 50–55 -> lăn 50–54); UI hiện khoảng lăn được. Lăn có seed theo ván (`s.rng`); xem trước hiện đúng min–max thật.
  - Thưởng công: +2·cấp; trống đồng +10 (đóng dấu); nỏ vs rồng +15; trống vs âm binh +15; thủy binh dưới sông +15; bị sói cắn −10.
  - Thưởng thủ: thủy binh dưới sông +25; bị sói cắn −10.
  - Máy bắn đá xuyên giáp: mục tiêu không được thủ địa hình (`pierce`).
- Đánh trả: chỉ khi kề nhau (khoảng cách 1) và bên bị đánh có tầm min 1 (không phải máy bắn đá). Bắn từ 2 ô không bị đáp.
- Kinh nghiệm: "chất lượng" = công min + công max + thủ, **tính cả thưởng cấp** (+6 / cấp). Mỗi đòn = sát thương × chất lượng nạn nhân. Cấp kế = chất lượng của mình × 200/3; dư mang sang; tối đa 1 cấp / trận; cấp tối đa 9; mỗi cấp +2 công (cả min, max), +2 thủ. Tên cấp 4 bậc: cấp 0–1 không tên, 2–3 lão luyện, 4–5 tinh nhuệ, 6–9 dũng mãnh; tướng không có tên cấp (chỉ LvN). "Lên cấp N" to chỉ khi đổi tên (cấp chẵn ≤ 6, không phải tướng); cấp khác: LvN nhỏ.
- Trống đồng: sau mọi lệnh của nó, quân ta trong 2 ô +10 công tới đầu lượt sau của ta (giữ cả khi đánh trả lượt địch). Trống chết vì bị đánh trả vẫn đánh trống từ ô nó ngã.
- Trống hồi máu (`healAura` 10): đầu lượt ta, quân ta trong 2 ô (không tính chính nó) hồi 10 máu. Không cộng dồn: đứng làng / thành ta (20) hoặc cạnh 2 trống -> lấy mức cao nhất.
- Sói: cắn (không phải đánh trả) mà mục tiêu còn sống -> **sau** đòn đánh trả (đáp đủ sức), mục tiêu −10 công, −10 thủ tới đầu lượt sau của phe sói. Cắn 0 sát thương vẫn tính; sói chết vì đánh trả vẫn tính.
- Chết (trừ tướng, âm binh) -> mộ (ttl 3, trừ 1 mỗi đầu lượt của mỗi bên; có quân bước lên là mất). Thầy mo đứng cạnh -> Gọi hồn -> âm binh (cả lính địch ngã).
- Máy bắn đá: chưa đi mới bắn / phá làng (2–4 ô). Phá làng địch / chưa ai chiếm -> làng hỏng; bộ binh / tướng sửa (1 lượt) -> làng trống, lượt sau chiếm.

## Tướng
- Hai tướng cùng chỉ số (55–65 / 20 / 4 / 1), chiếm được làng + thành.
- Chết -> mua lại ở thành: 200 + 200 × số lần đã chết (tối đa 1000), giữ cấp + KN.
- AI né đòn: máu mất = giá bộ binh / máu (mọi quân, máu hồi được); giá trị đầy đủ của quân chỉ tính theo nguy cơ chết (tổng đòn địch tới ô: ≤ 0.6 máu -> 0, = máu -> ½, ≥ 1.4 máu -> đủ) -> tướng khoẻ tiến lên đánh, không lùi về ô an toàn; tướng yếu tránh ô có thể chết. Thưởng đứng làng hồi máu tính tối đa giá 300 (tướng 60 máu không bám làng).

## Thắng / thua
- Một phe bị loại khi: hết thành **và** tướng đã chết; hoặc hết quân **và** hết thành. Phe chưa từng có thành (một số màn) chỉ thua khi hết quân.
- 1 đấu 1 / đấu tự do: ⚙ Đầu hàng trong lượt mình -> bên kia thắng ngay (lý do `surrender`).
- Màn chiến dịch thêm mục tiêu: `hero` (hạ tướng địch), `survive` N lượt, `reach` (đưa tướng tới ô), `rout`; `waves` = quân phục kích theo lượt. Mỗi kiểu = 1 mục trong `scripts/core/objectives.gd`.

## Sao màn (chiến dịch)
1 thắng · 2 tướng ta không ngã lần nào · 3 mốc của màn: thắng trong ≤ N lượt, hoặc (màn giữ vững) mất ≤ K lính (không tính tướng, âm binh). Giữ số sao cao nhất. Mốc = trung vị lượt / lính mất khi AI phe ta thắng (sim 12 ván, 2026-11-06), chờ chơi thử.

## Vùng địch đánh tới (UI, không đổi luật)
Bấm 1 quân địch: ô trắng mờ = ô nó đi tới được; ô đỏ = chỉ đánh tới được (máy bắn đá: cả vòng 2–4 quanh chỗ đứng, vì đi rồi không ném được); viền đỏ = mọi ô nó đánh được lượt sau nếu không ai di chuyển (`Game.threat_tiles`). Quân ta đứng trong vùng có dấu "!" đỏ.

## Địa hình (thủ +, giá đi)
Đồng 5/1 · Đường 0/1 · Rừng 10/2 · Đồi 10/2 · Núi 15/3 (mọi quân; sói: rừng / đồi / núi 1) · Sông 0/3 (thủy binh 1) · Cầu 5/1 · Làng 15/1 · Thành 15/1 · Làng hỏng 15/1 · Đền 15/1 (không chiếm, hồi máu mọi phe). Rồng: mọi ô 1.
Công trình = mô tả trong `TERRAIN` (`income`, `cap`, `heals`, `sells`, `razeTo`, `repairTo`/`repairBy`): làng 30 vàng, chiếm `capV`, phá -> làng hỏng; thành 50 vàng, chiếm `capC`, mua lính; làng hỏng sửa (`capV`) -> làng; đền hồi máu mọi phe.

## Lính (giá · công / thủ / đi / tầm; tên hiện = `content/theme.gd` `UNITS`)
Đi = số bước thật = số trong `units.bin` gốc − 1 (gốc: ô đích phải còn dư > 0 bước; màn thông tin gốc hiện số thô).
| Khóa | Tên hiện | AE2 | Giá | C / T / Đi / Tầm | Đặc biệt |
|---|---|---|---|---|---|
| `soldier` | Vệ binh | Soldier | 150 | 50–55 / 5 / 4 / 1 | chiếm, sửa làng |
| `archer` | Cung thủ | Archer | 250 | 50–55 / 5 / 4 / 1–2 | +15 vs rồng |
| `boat` | Hải tặc | Elemental | 300 | 50–55 / 10 / 4 / 1 | sông giá 1, dưới sông +15 / +25 |
| `shaman` | Pháp sư gọi hồn | Sorceress | 400 | 40–45 / 5 / 4 / 1 | gọi hồn |
| `drum` | Tu sĩ ánh sáng | Wisp | 500 | 35–40 / 10 / 4 / 1 | hào quang tầm 2, hồi 10 máu tầm 2, +15 vs âm binh |
| `wolf` | Sói bóng đêm | Dire Wolf | 500 | 60–65 / 15 / 5 / 1 | cắn: −10 / −10; rừng / đồi / núi giá 1 |
| `elephant` | Golem đá | Golem | 600 | 60–70 / 30 / 4 / 1 | |
| `catapult` | Máy bắn đá | Catapult | 700 | 50–70 / 10 / 3 / 2–4 | công thành, phá làng, xuyên giáp (bỏ thủ địa hình) |
| `bird` | Rồng | Dragon | 750 | 70–80 / 25 / 6 / 1 | bay |
| `ghost` | Bộ xương | Skeleton | — | 40–50 / 2 / 4 / 1 | gọi từ mộ, không tính trần |

Số liệu đặc biệt (hào quang, độc, thưởng vs loại, gọi hồn ra loại gì) là cờ trong `UNITS`; quân bị đóng dấu giữ phe đóng dấu (`aura` / `poison`) + lượng (`auraAtk` / `poisonAmt`). Lưu ván v4 (v3 tự nâng, lượng = 10).

## Đã xác nhận từ mã gốc AE2 (`docs/review/ae2_research.md`, 2026-11-06)
Luật mua (đi ngay, mua dưới quân ta / quân địch đứng trên thành, không giới hạn số lần), công thức KN (chỉ số gồm cả thưởng cấp, ×200/3), cấp tối đa 9, bảng địa hình + rồng vẫn được thủ địa hình, voi / máy bắn đá lên núi, +15 nỏ vs bay, độc không giảm bước đi, hào quang tầm 1–2, mộ (đếm 3, bước lên là mất), tướng hồi sinh giữ cấp + giá 200/+200/tối đa 1000.

## Khác AE2 gốc có chủ ý (2026-11-09, user: mỗi quân 1 việc riêng để người chơi mua đa dạng)
Trống hồi máu, sói đi rừng / đồi / núi 1 bước + giá 600 -> 500, rồng 1000 -> 750, thủy binh dưới sông +10 / +15 -> +15 / +25, máy bắn đá xuyên giáp. Bản thử chờ user đánh tay; lý do + số đo `docs/ai.md` "Trận người thật", `docs/TODO.md` "Kinh tế + cân bằng".

## Còn theo mã bản mod (chưa đối chiếu gốc)
Lăn sát thương không ra giá trị max (`[min, max−1]`), thứ tự độc sau đánh trả, trống chết vẫn thúc quân, trần quân chiến dịch 100.

## Để sau
3–4 phe + đồng minh, nhiều tướng / phe, tinh thể chiến dịch.
